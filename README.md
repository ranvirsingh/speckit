# Speckit

Spec-driven development pipeline for AI-assisted coding agents.

## What is Speckit?

A set of [Agent Skills](https://agentskills.io/) that implement a lightweight, right-sized development process:

1. **Specify** — Write an issue-backed spec, create a GitHub Issue
2. **Research** — Investigate technologies, compare libraries, assess patterns (optional)
3. **Plan** — Design architecture, append the plan beneath the issue-backed spec, and update `docs/` living docs when complex
4. **Implement** — Code, test, commit, push, create PR
5. **Test** — User acceptance testing against the spec
6. **E2E** — Generate end-to-end test artifacts proving the implementation works
7. **Retro** — Update `docs/` living docs, triage TODOs

Plus **Constitution** for project governance and **Verify** for compliance checks.

## Installation

### Quick install (recommended)

```powershell
# From the root of your project:
Invoke-RestMethod https://raw.githubusercontent.com/ranvirsingh/speckit/main/install.ps1 | Invoke-Expression
```

This downloads the latest release zip, extracts it to `.github/skills/speckit/`, and links everything for VS Code discovery.

### Manual install

```bash
# 1. Download the latest release zip from GitHub
# 2. Extract to .github/skills/speckit/
# 3. Run the installer
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

### Updating

```powershell
# Re-run the installer — it auto-updates from GitHub and overwrites by default
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

The installer creates directory junctions (Windows) or symlinks (macOS/Linux) so VS Code discovers everything automatically:
- Sub-skills → `.github/skills/speckit-specify`, `speckit-plan`, etc.
- Subagents → `.github/agents/speckit-codebase-scanner`, `speckit-living-docs-loader`
- Updates `.gitignore` to exclude the generated links **and** `.github/skills/speckit/` itself

> **After cloning**: Since speckit is gitignored, each developer runs the install one-liner once after cloning the repo. The installer always pulls the latest release.

To uninstall: `powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1 -Uninstall`

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| speckit | `/speckit` | Pipeline router — routes to the appropriate sub-skill |
| speckit-specify | `/speckit-specify` | Write an issue-backed spec and create a GitHub Issue |
| speckit-research | `/speckit-research` | Investigate technologies, compare libraries, assess patterns — writes to `docs/research.md` |
| speckit-plan | `/speckit-plan` | Append design notes and tasks beneath the spec, plus update living docs when needed |
| speckit-implement | `/speckit-implement` | Execute tasks, commit, push, create PR |
| speckit-constitution | `/speckit-constitution` | Project governance setup |
| speckit-verify | `/speckit-verify` | Check compliance against the constitution |

### Pipeline Agents

These phases are invoked via `runSubagent` with a `PipelineContext` handoff (see [HANDOFF-SCHEMA.md](references/HANDOFF-SCHEMA.md)):

| Agent | Codename | Bucket | Purpose |
|-------|----------|--------|---------|
| speckit-test | **Nightingale** | 2 | User acceptance testing — verify implementation against the spec |
| speckit-e2e | **Lovelace** | 2 | Orchestrate e2e testing — delegates to e2e-browser or e2e-api |
| speckit-retro | **Deming** | 1 | Post-implementation retrospective |

### Internal Subagents

These are custom agents (`.agent.md` files) invoked automatically by the pipeline skills/agents via the `runSubagent` tool — not called directly by users. They operate **autonomously** under the [Subagent Autonomy Protocol](references/AGENT-PROTOCOL.md) with per-agent token buckets to prevent deadlocks.

| Subagent | Codename | Bucket | Used By | Purpose |
|----------|----------|--------|---------|---------|
| speckit-codebase-scanner | **Dijkstra** | 2 | speckit-plan, speckit-research | Read-only codebase exploration for design research |
| speckit-living-docs-loader | **Hypatia** | 1 | speckit-specify | Compresses living docs into a focused context summary |
| speckit-nexus | **Babbage** | 2 | speckit-specify | Pre-reasoning — classifies work type, extracts problem/actors/constraints/edge cases |
| speckit-e2e-browser | **Turing** | 3 | speckit-e2e | Browser automation for UI project e2e testing via Playwright |
| speckit-e2e-api | **Berners-Lee** | 3 | speckit-e2e | API e2e testing via HTTP exchange recording |
| speckit-pipeline-checker | **Hopper** | 2 | speckit-verify | Checks PR status checks (CI green/red/pending) |
| speckit-web-researcher | **Curie** | 3 | speckit-research | External web research for libraries, APIs, and best practices |

> **Note**: The installer links subagents into `.github/agents/` for automatic discovery. No `settings.json` changes are needed.

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → research → plan → implement → test → e2e → retro
Needs research only?                   specify → research → implement → test → e2e → retro
Simple & scoped?                       specify → implement → test → e2e → retro
```

## Process Diagram

```mermaid
flowchart LR
  S([Specify]) --> RE([Research])
  RE --> P([Plan])
  P --> I([Implement])
  I --> T([Test])
  T --> D([E2E])
  D --> R([Retro])
  R --> S

  S -. creates .-> S1[GitHub Issue body<br/>spec]
  RE -. writes .-> RE1[docs/research.md<br/>findings &amp; options]
  P -. appends .-> P1[GitHub Issue body<br/>design notes<br/>tasks]
  P -. updates .-> P2[docs/DATA_MODEL.md<br/>docs/contracts/<br/>docs/RESEARCH.md]
  I -. delivers .-> I1[code<br/>tests<br/>commit<br/>PR]
  T -. verifies .-> T1[UAT report<br/>pass/fail per scenario]
  D -. captures .-> D1[e2e tests<br/>video/screenshots/logs]
  R -. refreshes .-> R1[docs/RETRO.md<br/>LIVING DOCS]
  R -. feeds back .-> R2[docs/PARKING_LOT.md<br/>NEXT WORK]

  classDef phase fill:#1f2937,color:#ffffff,stroke:#111827,stroke-width:2px;
  classDef artifact fill:#f8fafc,color:#0f172a,stroke:#94a3b8,stroke-width:1px,stroke-dasharray: 6 4;

  class S,RE,P,I,T,D,R phase;
  class S1,RE1,P1,P2,I1,T1,D1,R1,R2 artifact;
```

## Artifact Model

Speckit keeps the **issue-backed spec** and **living documents** separate on purpose:

- **GitHub Issue body** — the canonical spec/tracker created during **Specify**; **Plan** appends its design notes and task checklist beneath that spec in the same issue body
- **`docs/`** — living documents updated during **Plan** and **Retro** only

Issue body layout:

1. **Specify** writes the spec at the top of the issue body.
2. **Plan** appends a plan block below it (design notes + task checklist).
3. **Implement** and **Retro** update or read that appended plan block without replacing the original spec.

Issue comments may be used for supplementary discussion, but they are **not** the canonical plan source.
Downstream skills read the issue body.

Rules:

- Do **not** create a `specs/` directory.
- Do **not** create a local `spec.md` file.
- Do **not** create per-feature doc folders.
- Keep living documents in `docs/`, for example:
  - `docs/DATA_MODEL.md`
  - `docs/contracts/`
  - `docs/RETRO.md`

## Extension Hooks

Speckit supports lifecycle hooks via `.specify/extensions.yml` in the project root. Each skill checks for hooks at `before_` and `after_` lifecycle points (e.g., `hooks.before_specify`, `hooks.after_implement`). See [references/HOOKS.md](references/HOOKS.md) for the hook execution procedure.

## Requirements

- VS Code with GitHub Copilot
- GitHub CLI (`gh`) for issue/PR management
- Git for version control

## License

Private repository. All rights reserved.
