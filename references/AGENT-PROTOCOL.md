# Subagent Autonomy Protocol

This document defines the standard protocol for all speckit subagents.
Subagents operate **autonomously** — they do NOT follow human-in-the-loop patterns.
Instead, they communicate unresolved questions back to their invoking (parent) agent.

## Identity

Every subagent has a codename inspired by a veteran or notable figure.
The codename is part of the agent's identity line in its frontmatter description and opening section.

## Autonomy Rules

1. **No direct user interaction.** Subagents never prompt the user. They never use `askQuestions` or pause for human confirmation.
2. **Resolve what you can.** Use all available tools (search, read, web fetch, terminal) to answer your own questions before escalating.
3. **Escalate via structured response.** When a question genuinely cannot be answered with available tools, include an `## Unresolved Questions` block in your output (see format below).
4. **Single-shot by default.** Subagents aim to complete their work in one invocation. Re-invocation is the exception, not the rule.

## Re-Invocation Request Format

When a subagent cannot complete its work due to missing information, it MUST return its partial results **plus** an unresolved-questions block:

```markdown
## Partial Results

{whatever findings/work completed so far}

## Unresolved Questions

**reinvoke**: true
**tokens_remaining**: {number}
**questions**:
1. {Specific, actionable question}
2. {Specific, actionable question}

**context_carry**: |
  {Summary of work completed so far that the next invocation needs to continue.
   Keep this under 50 lines. Do not repeat raw file contents — summarize.}
```

The parent agent is responsible for:
- Answering the questions (via its own tools, other subagents, or the user)
- Re-invoking the subagent with:  `previous_context` (the `context_carry` block) + `answers` (responses to the questions)

## Token Bucket System

Each subagent has a **token bucket** that limits how many times it can request re-invocation within a single pipeline run. This prevents deadlocks and infinite loops.

### Bucket Rules

| Subagent | Bucket Size | Rationale |
|----------|-------------|-----------|
| `speckit-codebase-scanner` | **2** | Codebase is local — most answers are findable in one pass |
| `speckit-e2e-browser` | **3** | Browser tests may need retry after app-state or config fixes |
| `speckit-e2e-api` | **3** | API tests may need retry after server-state or auth fixes |
| `speckit-living-docs-loader` | **1** | Pure file loading — if docs don't exist, they don't exist |
| `speckit-nexus` | **2** | Reasoning from description + context; one retry if codebase scan needed |
| `speckit-pipeline-checker` | **2** | CI may be pending; one retry after wait is reasonable |
| `speckit-web-researcher` | **3** | Web research may need follow-up queries for depth |
| `speckit-test` | **2** | UAT verification; one retry after implement fixes |
| `speckit-e2e` | **2** | E2E orchestration; one retry after implement fixes |
| `speckit-retro` | **1** | Retro is observational — either it works or it doesn't |

### How It Works

1. **Initialization**: When a parent agent first invokes a subagent for a task, the subagent's bucket starts at its maximum.
2. **Consumption**: Each time the subagent returns `reinvoke: true`, the parent decrements the bucket by 1 before re-invoking.
3. **Exhaustion**: If the bucket reaches **0** and the subagent still has unresolved questions:
   - The parent agent MUST NOT re-invoke the subagent.
   - The parent uses the **partial results** returned so far.
   - Unresolved questions are surfaced to the user or logged as gaps.
4. **Scope**: Buckets are **per-task, per-subagent**. A new pipeline task resets all buckets. Different subagents have independent buckets.
5. **Transparency**: The subagent MUST report `tokens_remaining` in every re-invocation request. The parent verifies this matches its own count.

### Deadlock Prevention

- **No circular invocations**: Subagent A must never invoke Subagent B which invokes Subagent A. The invocation graph is strictly a tree rooted at the parent skill.
- **Bucket ceiling**: Even if a subagent claims it needs more re-invocations, the bucket is a hard cap.
- **Timeout assumption**: If a subagent's output does not contain `reinvoke: true`, the work is considered complete (success or best-effort).
- **Monotonic decrement**: Buckets only go down. No mechanism exists to refill a bucket mid-task.

## Parent Agent Responsibilities

When invoking a subagent, the parent MUST:

1. **Track the bucket** — initialize to the subagent's max, decrement on each `reinvoke: true`.
2. **Carry context** — pass `previous_context` + `answers` on re-invocation.
3. **Enforce the cap** — refuse re-invocation when bucket = 0.
4. **Use partial results** — never discard work done by a subagent, even if incomplete.
5. **Log gaps** — record any unresolved questions that hit the bucket limit for the retro/verify phases.

## Circuit Breaker

The circuit breaker prevents runaway retry loops at the **pipeline phase level** (not individual subagents — those are covered by the token bucket above). It governs the implement → test → implement and implement → e2e → implement feedback cycles.

### How It Works

1. The router maintains a `retryCount` object in the [PipelineContext](./HANDOFF-SCHEMA.md) with one counter per phase.
2. All counters start at `0`.
3. When a phase fails and the pipeline auto-continues back (e.g., test fails → implement), the router increments `retryCount.{phase}` for the phase being re-entered.
4. **Before invoking any phase**, the router checks:
   ```
   if retryCount.{phase} >= 2 → STOP and escalate to user
   ```
5. On escalation, the router presents:
   - Which phase tripped the breaker
   - The failure reason from the last attempt
   - The partial results accumulated so far
   - A suggestion to the user (e.g., "The test phase has failed twice after implement fixes. Please review the failing scenarios manually.")

### Retry Semantics

| Loop | Trigger | Counter Incremented | Max Retries |
|------|---------|-------------------|-------------|
| implement → test → implement | UAT fails | `retryCount.implement` | 2 |
| implement → e2e → implement | E2E tests fail | `retryCount.implement` | 2 |
| test → implement → test | Fix didn't resolve UAT | `retryCount.test` | 2 |
| e2e → implement → e2e | Fix didn't resolve E2E | `retryCount.e2e` | 2 |

### Rules

- Counters are **per pipeline run** — a new `speckit-specify` invocation resets all counters.
- The circuit breaker is orthogonal to the token bucket — a subagent may exhaust its bucket without tripping the breaker, and vice versa.
- The breaker applies to the **router's auto-continue logic only**. A user can always manually re-invoke a phase (the counter is not checked for direct invocations).

## Handoff Protocol

Pipeline phases communicate via the `PipelineContext` JSON schema. See [HANDOFF-SCHEMA.md](./HANDOFF-SCHEMA.md) for the full schema definition, field rules, staleness checks, and backward-compatibility behaviour.

### Key Principles

1. **Incremental enrichment**: Each phase adds its fields to the context and passes it downstream. No phase removes or overwrites fields set by an earlier phase.
2. **Single load**: Living docs are loaded once at specify time and cached in `livingContext`. Downstream phases trust the cache unless the issue body was modified (staleness check).
3. **Graceful degradation**: If an agent receives no `PipelineContext`, it falls back to CLI-based context derivation (see Backward Compatibility in HANDOFF-SCHEMA.md).
