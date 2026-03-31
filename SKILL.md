---
name: speckit
description: >-
  Spec-driven development pipeline. Routes to the appropriate sub-skill based
  on the current phase: specify → plan (if complex) → implement → retro.
  Use this when starting any new feature, bug, or chore — or when unsure which
  pipeline step to enter.
user-invocable: true
argument-hint: Describe what you want to build, fix, or change
---

# Speckit Pipeline

Spec-driven development with a lightweight, right-sized process.
One GitHub Issue per spec — no sub-issues, no intermediate task files.

## Pre-Execution: Ensure Installation

Before routing, run the install script to pull the latest speckit and ensure all skills and agents are linked:

```bash
powershell -ExecutionPolicy Bypass -File <speckit-skill-path>/install.ps1
```

Replace `<speckit-skill-path>` with the resolved path to the speckit skill directory (where this SKILL.md lives).
If the script reports all links as `[skip] Already linked`, proceed immediately. Do not wait for user confirmation.

## Pre-Execution: Constitution Gate

After installation, check whether a project constitution exists:

```powershell
powershell -ExecutionPolicy Bypass -File <speckit-skill-path>/scripts/check-constitution.ps1 -WorkspaceRoot "<workspace-root>"
```

- If `exists` is `false`: **Route to `speckit-constitution` immediately** — the project needs governance principles before any pipeline work can begin. Tell the user: "No project constitution found. Let's establish one before proceeding."
- If `exists` is `true` but `valid` is `false`: **Route to `speckit-constitution` immediately** — the constitution still contains template placeholders. Tell the user: "Your constitution has unfilled placeholders. Let's complete it before proceeding."
- If `exists` is `true` and `valid` is `true`: Continue to routing logic below.

This applies to both greenfield and brownfield projects.

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → plan → implement → test → e2e → retro
Simple & scoped?                       specify → implement → test → e2e → retro
```

## When to Use Each Sub-Skill

| Phase | Skill | Use When |
|-------|-------|----------|
| **Specify** | `speckit-specify` | Starting new work — write spec, create GitHub Issue |
| **Plan** | `speckit-plan` | Work involves schema changes, new/changed APIs, or unfamiliar domain |
| **Implement** | `speckit-implement` | Ready to code — has a GitHub Issue number |
| **Test** | `speckit-test` | Implementation done — verify it satisfies the spec (UAT) |
| **E2E** | `speckit-e2e` | UAT passed — generate e2e test artifacts and attach to PR |
| **Retro** | `speckit-retro` | E2E captured — update living docs, triage TODOs |
| **Constitution** | `speckit-constitution` | Setting up or updating project governance principles |
| **Verify** | `speckit-verify` | Check compliance of specs, plans, or code against the constitution |

### Internal Subagents (`.agent.md` — invoked by skills via the `runSubagent` tool, not directly by users)

| Subagent | Used By | Purpose |
|----------|---------|---------|
| `speckit-codebase-scanner` | `speckit-plan` | Read-only codebase exploration — returns distilled findings for design research |
| `speckit-living-docs-loader` | All pipeline skills | Loads and compresses living docs into a focused context summary |
| `speckit-e2e-recorder` | `speckit-e2e` | Browser automation for UI project e2e testing via Playwright |
| `speckit-pipeline-checker` | `speckit-verify` | Checks PR status checks (CI green/red/pending) |

## Routing Logic

1. **No issue yet?** → Route to `speckit-specify`
2. **Issue exists, needs design?** → Route to `speckit-plan`
3. **Issue exists, ready to code?** → Route to `speckit-implement`
4. **Code done, needs UAT?** → Route to `speckit-test`
5. **UAT passed, need e2e?** → Route to `speckit-e2e`
6. **E2E done, PR created?** → Route to `speckit-retro`
7. **Setting up project governance?** → Route to `speckit-constitution`
8. **Checking compliance?** → Route to `speckit-verify`

## Plan Gate

The plan phase is **complexity-gated, not type-gated**. Any work type (feature, bug, or chore) goes through `speckit-plan` when:

- Schema changes are involved
- New or changed APIs are introduced
- The domain is unfamiliar

Otherwise, skip directly from specify to implement.

## Artifact Boundaries

Keep these artifacts separate:

- **Specify** writes the spec into the **GitHub Issue body only**
- **Plan** appends design notes and a task checklist beneath that spec in the **same issue body**
- **Plan** and **Retro** update living docs in `docs/` only when needed
- Issue comments are supplementary discussion, not the canonical plan source
- Never create `specs/`, `spec.md`, or per-feature doc folders

## Key Principles

- **One issue per spec** — checklist in the issue body, no sub-issues
- **Issue IS the tracker** — no tasks.md file
- **Issue-backed specs only** — the spec lives in the GitHub Issue body, never in `spec.md`
- **Plan appends; it does not replace** — keep the original spec at the top of the issue body and append/update the plan beneath it
- **Living docs live in `docs/`** — update `docs/` in plan/retro, never create `specs/`
- **Right-sized artifacts** — only generate data-model, contracts, research when needed
- **Human-in-the-loop** — ask the next question at every step
- **Conventional commits** — every commit references the issue (`#N`)
- **PRs close issues** — `Closes #N` in PR description
