# Skill Protocol

This is the short-form reference for the speckit skill architecture.
All pipeline phases are implemented as **skills** (SKILL.md files). There are
no subagents — each skill is self-contained and invoked by the router or by
the external agent harness.

## Identity

Every skill has a name matching its directory (`speckit-{phase}`). Skills
are located under `skills/` in the speckit bundle and installed into
`.github/skills/` by `install.ps1`.

## Roles by tool scope

| Class | Examples | Tools | Purpose |
|---|---|---|---|
| **Read-only skill** | speckit-verify | `search`, `codebase`, `web`, `fetch`, `usages`, `githubRepo` | Investigate, audit, report — never write app code |
| **Test skill** | speckit-test | read-only set + `runCommands`, `runTests` | UAT verification — reads code, runs tests, reports findings |
| **Artifact skill** | speckit-e2e | read-only set + `editFiles`, `runCommands`, `runTests` | Generate scoped test artifacts under `e2e/`, `screenshots/`, `test-results/` |
| **Implementation skill** | speckit-implement | full toolset | Code, commit, push, PR, update living docs |
| **User-invocable skill** | speckit-{specify, plan, research, constitution} | full toolset | Human-in-the-loop allowed; can ask questions |

## Autonomy Rules

1. **Skills invoked downstream of implement are autonomous.** They do not
   prompt the user. The router or harness decides the next step.
2. **Resolve what you can.** Use available tools to answer your own
   questions before escalating.
3. **Escalate via structured response.** When a question genuinely cannot be
   answered, include an `## Unresolved Questions` block in your output (format
   below).
4. **Single-shot by default.** Skills complete their work in one invocation.
5. **NEVER use `--no-verify`.** Passing `--no-verify` to `git commit` or
   `git push` bypasses pre-commit and pre-push hooks, including
   `validate-commit-msg.ps1`. This is prohibited without exception. If a
   hook fails, fix the underlying issue — do not bypass it.

## Scope Discipline

Each skill stays in its phase's lane. A test skill that finds a bug REPORTS it;
it does NOT fix it.

| Phase | What it does | NEVER does |
|-------|--------------|------------|
| specify | Spec, issue, classify | Write code, create tests |
| research | Investigate options | Write code, decide |
| plan | Design, task list, design docs | Write app code, run tests |
| implement | Code, commit, push, PR, update living docs, triage TODOs | Write specs, modify governance |
| test | UAT verification | Fix code, modify source/test files |
| e2e | Generate proof-of-work artifacts | Fix application code |
| verify | Constitution + repo-hygiene audit (`--scope pr` or `--scope repo`) | Fix code, modify source files |

## Escalation Format

```markdown
## Partial Results

{whatever findings/work completed so far}

## Unresolved Questions

**questions**:
1. {Specific, actionable question}

**context_carry**: |
  {Summary of work completed so far. Keep under 50 lines. Summarise; do not
  paste raw file contents.}
```

## Circuit Breaker

The router maintains `retryCount.{phase}` in the [PipelineContext](./HANDOFF-SCHEMA.md).
If `retryCount.{phase} >= 2`, the router stops and escalates to the user.
Counters reset per pipeline run. See HANDOFF-SCHEMA.md for the full schema.

## Cross-Phase Memory

Phases MAY persist durable, cross-phase facts as `/memories/repo/{slug}.md` entries
using the existing VS Code Copilot repository-memory shape (`subject`, `fact`,
`citations`, `reason`, `category`). VS Code auto-surfaces these to every future
skill invocation as `<repository_memories>`, so they replace the originally
proposed `reuseHints` schema field. See
[HANDOFF-SCHEMA.md § /memories/repo/ Write Convention](./HANDOFF-SCHEMA.md#memoriesrepo-write-convention)
for the full contract.

## Deterministic Commands

Where possible, pipeline operations should be codified as deterministic scripts
rather than left as free-form instructions for the model. The following scripts
are canonical:

| Script | Purpose |
|--------|---------|
| `scripts/get-pipeline-state.ps1` | Returns JSON with issue state, branch, PR, checklist, phase markers |
| `scripts/set-issue-state.ps1` | Advances issue state on the project board |
| `scripts/check-constitution.ps1` | Validates project constitution exists and is complete |
| `scripts/extract-constitution-rules.ps1` | Extracts MUST/NON-NEGOTIABLE rules for compliance checking |
| `scripts/verify-marker-budget.ps1` | Validates marker block line budgets |

An external harness can use `get-pipeline-state.ps1` to read the current phase
and deterministically decide which skill to invoke next.
