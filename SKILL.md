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

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → plan → implement → retro
Simple & scoped?                       specify → implement → retro
```

## When to Use Each Sub-Skill

| Phase | Skill | Use When |
|-------|-------|----------|
| **Specify** | `speckit-specify` | Starting new work — write spec, create GitHub Issue |
| **Plan** | `speckit-plan` | Work involves schema changes, new/changed APIs, or unfamiliar domain |
| **Implement** | `speckit-implement` | Ready to code — has a GitHub Issue number |
| **Retro** | `speckit-retro` | Implementation complete — update living docs, triage TODOs |
| **Constitution** | `speckit-constitution` | Setting up or updating project governance principles |

### Internal Subagents (`.agent.md` — invoked by skills via `runSubagent`, not directly by users)

| Subagent | Used By | Purpose |
|----------|---------|---------|
| `speckit-codebase-scanner` | `speckit-plan` | Read-only codebase exploration — returns distilled findings for design research |
| `speckit-living-docs-loader` | All pipeline skills | Loads and compresses living docs into a focused context summary |

## Routing Logic

1. **No issue yet?** → Route to `speckit-specify`
2. **Issue exists, needs design?** → Route to `speckit-plan`
3. **Issue exists, ready to code?** → Route to `speckit-implement`
4. **Code done, PR created?** → Route to `speckit-retro`
5. **Setting up project governance?** → Route to `speckit-constitution`

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
