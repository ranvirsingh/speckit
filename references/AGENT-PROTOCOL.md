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
| `speckit-e2e-recorder` | **3** | Browser tests may need retry after app-state or config fixes |
| `speckit-living-docs-loader` | **1** | Pure file loading — if docs don't exist, they don't exist |
| `speckit-nexus` | **2** | Reasoning from description + context; one retry if codebase scan needed |
| `speckit-pipeline-checker` | **2** | CI may be pending; one retry after wait is reasonable |
| `speckit-web-researcher` | **3** | Web research may need follow-up queries for depth |

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
