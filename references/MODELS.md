# Speckit Model Tier Mapping

Each speckit skill and agent declares a `model:` in its frontmatter. This is
non-binding **guidance** — the parent agent (or `runSubagent` caller) reads
the frontmatter and passes the model via the standard VS Code custom-agent
mechanism, but it can override.

## Tier Definitions

| Tier | Model | Approx. multiplier* | Used by |
|------|-------|---------------------|---------|
| **FAST** | `GPT-5.3-Codex (copilot)` | 1× | Read-only subagents and code-aware artifact subagents |
| **MID** | `Claude Sonnet 4.6 (copilot)` | 1× | Pipeline orchestration agents (test, e2e, verify, doctor) |
| **DEEP** | `Claude Sonnet 4.6 (copilot)` | 1× | User-invocable skills that produce specs, plans, code, retros |
| **TOP** | `Claude Opus 4.7 (copilot)` | 7.5× | Constitution only — high stakes, low frequency |

*Multipliers reflect VS Code Copilot premium request weighting at the time of
writing and may change. The qualitative ordering FAST < MID ≤ DEEP < TOP is
the durable contract.

## Per-Agent Mapping

### FAST tier (read-only or single-shot)
- `speckit-codebase-scanner` (Dijkstra)
- `speckit-living-docs-loader` (Hypatia)
- `speckit-web-researcher` (Curie)
- `speckit-nexus` (Babbage)
- `speckit-pipeline-checker` (Hopper)
- `speckit-e2e-api` (Berners-Lee)
- `speckit-e2e-browser` (Turing)

### MID tier (pipeline orchestration)
- `speckit-test` (Nightingale) — UAT against acceptance scenarios
- `speckit-e2e` (Lovelace) — orchestrates Turing/Berners-Lee
- `speckit-verify` — constitution + pipeline compliance check
- `speckit-doctor` — repo hygiene audit

### DEEP tier (user-invocable, generates significant output)
- `speckit-specify` — spec + issue creation
- `speckit-plan` — architecture, data model, contracts
- `speckit-research` — research synthesis
- `speckit-implement` — code, commits, PR
- `speckit-retro` (Deming) — living-doc updates

### TOP tier (rare, high-leverage)
- `speckit-constitution` — project governance is hard to change later;
  worth the premium model

## Why this mapping

- **Scope-bounded subagents** that return distilled findings don't need a
  reasoning powerhouse — they need a code-aware FAST model that reads/searches
  a lot of files cheaply.
- **Pipeline orchestrators** route between subagents and write structured
  reports; MID is the right balance of speed and reasoning.
- **Skills that produce code, specs, or plans** need DEEP reasoning to avoid
  costly rework.
- **Constitution work** is rare, slow, and decisive — TOP tier earns its
  premium here.

## How parents apply it

When a skill (e.g., `speckit-implement`) calls `runSubagent` to delegate to a
subagent (e.g., `speckit-codebase-scanner`), it reads the subagent's `model:`
frontmatter and passes the qualified name (`Model Name (Vendor)`) to the
`model` parameter of `runSubagent`. The parent may override if it has reason
(e.g., a budget-constrained run that downgrades everything to FAST).

## History

Model routing was originally added in commit 229df16, removed in 9c84c63 to
let the parent dictate model choice without frontmatter coupling, and
reinstated in this v2.0 release as guidance (not enforcement). The reasoning
for the reversal: VS Code custom agents support a `model:` frontmatter field
natively, so we get model selection at the platform level for free, and the
tier mapping documented here gives parent agents a defensible default.
