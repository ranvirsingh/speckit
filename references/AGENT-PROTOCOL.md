# Subagent Autonomy Protocol

This is the short-form reference. Hard enforcement now lives in each
`.agent.md` and `SKILL.md` frontmatter via the `tools:` allowlist —
a subagent without `editFiles` in its tools physically cannot write,
regardless of what its prose says.

## Identity

Every agent and subagent has a codename inspired by a notable figure
(Curie, Turing, Berners-Lee, Lovelace, Nightingale). The codename is part
of the agent's identity line in its frontmatter description and opening
section.

## Roles by tool scope

| Class | Examples | Tools | Purpose |
|---|---|---|---|
| **Read-only subagent** | web-researcher | `search`, `codebase`, `web`, `fetch`, `usages`, `githubRepo` | Investigate, summarise, escalate via `## Unresolved Questions` — never write |
| **Artifact subagent** | e2e-browser, e2e-api | read-only set + `editFiles`, `runCommands`, `runTests` | Generate scoped artifacts under `e2e/`, `screenshots/`, `gifs/`, `test-results/` |
| **Pipeline agent** | speckit-test, speckit-e2e | as needed for the phase | Autonomous (no `vscode_askQuestions`); orchestrates one phase end-to-end |
| **User-invocable skill** | speckit-{specify, plan, research, implement, verify, constitution} | full toolset | Human-in-the-loop allowed; can ask questions |

## Autonomy Rules (still apply, now enforced by frontmatter)

1. **No direct user interaction** for subagents and pipeline agents. They never
   prompt the user. They never use `vscode_askQuestions`. The `tools:` allowlist
   omits the askQuestions capability for these roles.
2. **Resolve what you can.** Use the read-only tools you have to answer your own
   questions before escalating.
3. **Escalate via structured response.** When a question genuinely cannot be
   answered, include an `## Unresolved Questions` block in your output (format
   below).
4. **Single-shot by default.** Subagents complete their work in one invocation.
   Re-invocation is the exception, not the rule.

## Scope Discipline

Each agent stays in its phase's lane. A test agent that finds a bug REPORTS it;
it does NOT fix it. The frontmatter `tools:` allowlist for `speckit-test` lets
it write to `docs/uat-reports/` and that's it; if it tries to edit `src/` the
edit might succeed at the tool level but is a protocol violation that the
parent (router) will reject during handoff.

| Phase | What it does | NEVER does |
|-------|--------------|------------|
| specify | Spec, issue, classify | Write code, create tests |
| research | Investigate options | Write code, decide |
| plan | Design, task list, design docs | Write app code, run tests |
| implement | Code, commit, push, PR, update living docs, triage TODOs | Write specs, modify governance |
| test | UAT verification | Fix code, modify source/test files |
| e2e | Generate proof-of-work artifacts | Fix application code |
| verify | Constitution + repo-hygiene audit (`--scope pr` or `--scope repo`) | Fix code, modify source files |

## Re-Invocation Request Format

```markdown
## Partial Results

{whatever findings/work completed so far}

## Unresolved Questions

**reinvoke**: true
**tokens_remaining**: {number}
**questions**:
1. {Specific, actionable question}

**context_carry**: |
  {Summary of work completed so far. Keep under 50 lines. Summarise; do not
  paste raw file contents.}
```

## Token Bucket

Each subagent has a re-invocation budget per pipeline run. See individual
`.agent.md` files for the bucket size. Buckets reset at the start of each
new `speckit-specify` invocation.

| Subagent | Budget |
|----------|--------|
| web-researcher | 3 |
| e2e-browser | 3 |
| e2e-api | 3 |
| test | 2 |
| e2e | 2 |

## Circuit Breaker

The router maintains `retryCount.{phase}` in the [PipelineContext](./HANDOFF-SCHEMA.md).
If `retryCount.{phase} >= 2`, the router stops and escalates to the user.
Counters reset per pipeline run. See HANDOFF-SCHEMA.md for the full schema.

## Cross-Phase Memory

Phases MAY persist durable, cross-phase facts as `/memories/repo/{slug}.md` entries
using the existing VS Code Copilot repository-memory shape (`subject`, `fact`,
`citations`, `reason`, `category`). VS Code auto-surfaces these to every future
agent invocation as `<repository_memories>`, so they replace the originally
proposed `reuseHints` schema field. See
[HANDOFF-SCHEMA.md § /memories/repo/ Write Convention](./HANDOFF-SCHEMA.md#memoriesrepo-write-convention)
for the full contract.

## Why frontmatter, not prose

This document used to be ~250 lines of MUST/MUST NOT. In practice some models
(particularly creative ones) ignored those rules and started implementing code
during the test phase, or used `vscode_askQuestions` despite "you must not".

`tools:` in agent frontmatter is enforced by VS Code itself — the model cannot
call a tool that is not in the allowlist. So we moved the rules to the place
that actually enforces them. This file is the rationale; the agent files are
the truth.
