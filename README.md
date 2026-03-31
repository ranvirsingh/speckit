# Speckit

Spec-driven development pipeline for AI-assisted coding agents.

## What is Speckit?

A set of [Agent Skills](https://agentskills.io/) that implement a lightweight, right-sized development process:

1. **Specify** — Write an issue-backed spec, create a GitHub Issue
2. **Plan** — Design architecture, append the plan beneath the issue-backed spec, and update `docs/` living docs when complex
3. **Implement** — Code, test, commit, push, create PR
4. **Retro** — Update `docs/` living docs, triage TODOs

Plus a **Constitution** skill for setting up project governance.

## Installation

### As a Git submodule (recommended)

```bash
# Add as submodule at the standard skills location
git submodule add https://github.com/ranvirsingh/speckit.git .github/skills/speckit

# Run the installer to link sub-skills and subagents into VS Code default paths
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

The installer creates directory junctions (Windows) or symlinks (macOS/Linux) so VS Code discovers everything automatically:
- Sub-skills → `.github/skills/speckit-specify`, `speckit-plan`, etc.
- Subagents → `.github/agents/speckit-codebase-scanner`, `speckit-living-docs-loader`
- Updates `.gitignore` to exclude the generated links

To uninstall: `powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1 -Uninstall`

### Manual copy

```bash
# Copy the entire folder into your project
cp -r speckit/ your-project/.github/skills/speckit/
# Then run the installer
powershell -ExecutionPolicy Bypass -File your-project/.github/skills/speckit/install.ps1
```

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| speckit | `/speckit` | Pipeline router — routes to the appropriate sub-skill |
| speckit-specify | `/speckit-specify` | Write an issue-backed spec and create a GitHub Issue |
| speckit-plan | `/speckit-plan` | Append design notes and tasks beneath the spec, plus update living docs when needed |
| speckit-implement | `/speckit-implement` | Execute tasks, commit, push, create PR |
| speckit-test | `/speckit-test` | User acceptance testing — verify implementation against the spec |
| speckit-e2e | `/speckit-e2e` | Generate e2e test artifacts proving the implementation works |
| speckit-retro | `/speckit-retro` | Post-implementation retrospective |
| speckit-constitution | `/speckit-constitution` | Project governance setup |
| speckit-verify | `/speckit-verify` | Check compliance against the constitution |

### Internal Subagents

These are custom agents (`.agent.md` files) invoked automatically by the pipeline skills via the `runSubagent` tool — not called directly by users:

| Subagent | Used By | Purpose |
|----------|---------|---------|
| speckit-codebase-scanner | speckit-plan | Read-only codebase exploration for design research |
| speckit-living-docs-loader | All pipeline skills | Compresses living docs into a focused context summary |
| speckit-e2e-recorder | speckit-e2e | Browser automation for UI project e2e testing via Playwright |

> **Note**: The installer links subagents into `.github/agents/` for automatic discovery. No `settings.json` changes are needed.

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → plan → implement → test → e2e → retro
Simple & scoped?                       specify → implement → test → e2e → retro
```

## Process Diagram

```mermaid
flowchart LR
  S([Specify]) --> P([Plan])
  P --> I([Implement])
  I --> T([Test])
  T --> D([E2E])
  D --> R([Retro])
  R --> S

  S -. creates .-> S1[GitHub Issue body<br/>spec]
  P -. appends .-> P1[GitHub Issue body<br/>design notes<br/>tasks]
  P -. updates .-> P2[docs/DATA_MODEL.md<br/>docs/contracts/<br/>docs/RESEARCH.md]
  I -. delivers .-> I1[code<br/>tests<br/>commit<br/>PR]
  T -. verifies .-> T1[UAT report<br/>pass/fail per scenario]
  D -. captures .-> D1[e2e tests<br/>video/screenshots/logs]
  R -. refreshes .-> R1[docs/RETRO.md<br/>LIVING DOCS]
  R -. feeds back .-> R2[docs/PARKING_LOT.md<br/>NEXT WORK]

  classDef phase fill:#1f2937,color:#ffffff,stroke:#111827,stroke-width:2px;
  classDef artifact fill:#f8fafc,color:#0f172a,stroke:#94a3b8,stroke-width:1px,stroke-dasharray: 6 4;

  class S,P,I,T,D,R phase;
  class S1,P1,P2,I1,T1,D1,R1,R2 artifact;
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

## Requirements

- VS Code with GitHub Copilot
- GitHub CLI (`gh`) for issue/PR management
- Git for version control

## License

Private repository. All rights reserved.
