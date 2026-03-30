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

## Key Principles

- **One issue per spec** — checklist in the issue body, no sub-issues
- **Issue IS the tracker** — no tasks.md file
- **Right-sized artifacts** — only generate data-model, contracts, research when needed
- **Human-in-the-loop** — ask the next question at every step
- **Conventional commits** — every commit references the issue (`#N`)
- **PRs close issues** — `Closes #N` in PR description
