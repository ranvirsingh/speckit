---
name: speckit
description: >-
  Spec-driven development pipeline. Routes to the appropriate sub-skill based
  on the current phase: specify → research (optional) → plan (if complex) → implement → test → e2e.
  Verify can be run at any point to check compliance.
  Use this when starting any new feature, bug, or chore — or when unsure which
  pipeline step to enter.
user-invocable: true
argument-hint: Describe what you want to build, fix, or change
---

# Speckit Pipeline

Spec-driven development with a lightweight, right-sized process.
One GitHub Issue per spec — no sub-issues, no intermediate task files.

## Pre-Execution: Path Resolution

All paths in this pipeline use `.github/skills/speckit` as the speckit root.
Script and skill paths are relative to the workspace root (where `.github/` lives).

## Pre-Execution: Ensure Installation

Before routing, run the install script to ensure all skills are linked:

```pwsh
pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

If the script reports all links as `[skip] Already linked`, proceed immediately. Do not wait for user confirmation.

> **Note**: Only the router (this skill) and `speckit-specify` run the installer. Other sub-skills skip bootstrap — they are always invoked via the router or after specify has already bootstrapped.

## Pre-Execution: Constitution Gate

After installation, check whether a project constitution exists:

```pwsh
pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/check-constitution.ps1 -WorkspaceRoot "."
```

- If `exists` is `false`: **Route to `speckit-constitution` immediately** — the project needs governance principles before any pipeline work can begin. Tell the user: "No project constitution found. Let's establish one before proceeding."
- If `exists` is `true` but `valid` is `false`: **Route to `speckit-constitution` immediately** — the constitution still contains template placeholders. Tell the user: "Your constitution has unfilled placeholders. Let's complete it before proceeding."
- If `exists` is `true` and `valid` is `true`: Continue to routing logic below.

This applies to both greenfield and brownfield projects.

## Auto-Freshness Check

**Before starting the first pipeline phase** and **after the last phase completes**, ensure speckit is up to date:

```
run_in_terminal: pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

This always downloads the latest release from GitHub and overwrites existing links (Force + Update are on by default). The command is idempotent — safe to run every time.

Pass `-NoUpdate` if you know the local copy is current (e.g., just installed). Pass `-NoForce` to skip overwriting existing links.

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → research → plan → implement → test → e2e
Needs research only?                   specify → research → implement → test → e2e
Simple & scoped?                       specify → implement → test → e2e
```

> **Auto-continuation**: The entire pipeline runs without stopping to ask the user which step to take. `speckit-specify` auto-routes to the appropriate next phase based on complexity signal. From there, `research → plan → implement → test → e2e` each invoke the next skill on success. Do NOT pause for user confirmation between steps. User interaction occurs only during **specify** (confirmation round) and when a step encounters a failure requiring user action.

## When to Use Each Phase

### Skills (loaded as active skill context)

| Phase | Skill | Use When |
|-------|-------|----------|
| **Specify** | `speckit-specify` | Starting new work — write spec, create GitHub Issue |
| **Research** | `speckit-research` | Technology unknowns — compare libraries, investigate patterns, assess options |
| **Plan** | `speckit-plan` | Work involves schema changes, new/changed APIs, or unfamiliar domain |
| **Implement** | `speckit-implement` | Ready to code — has a GitHub Issue number |
| **Test** | `speckit-test` | Implementation done — verify it satisfies the spec (UAT) |
| **E2E** | `speckit-e2e` | UAT passed — generate e2e test artifacts and attach to PR |
| **Constitution** | `speckit-constitution` | Setting up or updating project governance principles |
| **Verify** | `speckit-verify` | Check compliance of specs, plans, or code against the constitution |
| **PR Description** | `speckit-pr-description` | Fix a red pipeline guard — validates and auto-rewrites the PR body to satisfy `pipeline-guard.yml` |


## Routing Logic

**Issue State Tracking**: Before routing to any phase, advance the Issue State on the GitHub Project board. Read `.speckit-project.json` from the workspace root for `projectNumber` and `owner`. If the file does not exist, skip state tracking silently.

```pwsh
pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/set-issue-state.ps1 -ProjectNumber {projectNumber} -Owner {owner} -IssueNumber {issueNumber} -Repo {owner}/{repo} -State "{phase}"
```

Phase-to-state mapping: specify→Specify, research→Research, plan→Plan, implement→Implement, test→Test, e2e→E2E. After e2e completes successfully (and `speckit-implement` has finished its done-done living-doc updates), advance to "Done".

**Default state**: When an issue is first added to the project (auto-add), it is set to "Parking Lot" before advancing to the requested state. This ensures every issue has a visible starting point on the board.

1. **No issue yet?** → Route to `speckit-specify`
2. **Issue exists, needs technology research?** → Advance state to "Research", route to `speckit-research`
3. **Issue exists, needs design?** → Advance state to "Plan", route to `speckit-plan`
4. **Issue exists, ready to code?** → Advance state to "Implement", route to `speckit-implement`
5. **Code done, needs UAT?** → Advance state to "Test", route to `speckit-test`
6. **UAT passed, need e2e?** → Advance state to "E2E", route to `speckit-e2e`
7. **E2E done?** → Advance state to "Done". (Living-doc updates and TODO triage already happened inside `speckit-implement`.)
8. **Setting up project governance?** → Route to `speckit-constitution`
9. **Checking compliance or auditing repo hygiene?** → Route to `speckit-verify` (default `--scope pr`; pass `--scope repo` for hygiene audits)
10. **Pipeline guard is red / PR description needs fixing?** → Route to `speckit-pr-description` (pass PR number or let skill auto-detect from current branch)

## Pipeline Context (Handoff Protocol)

The router builds a `PipelineContext` JSON object incrementally across phases. See [HANDOFF-SCHEMA.md](references/HANDOFF-SCHEMA.md) for the full schema.

### Context Flow

1. **specify** → creates the context with identity fields, living context, and constitution compliance
2. **research** (optional) → adds `research` summary
3. **plan** (optional) → adds `plan` completion info
4. **implement** → adds `implementation` with PR details, base URL, commit SHA; updates living docs and triages TODOs at done-done
5. **test** → adds `uat` with verdict and report
6. **e2e** → adds `e2e` with project type, pass/fail, artifacts

### Staleness Check

Before passing context to a downstream phase, check:
```
if issue.updatedAt > context.livingContext.loadedAt → reload living context
```

If stale, re-read the relevant living docs directly (via `read_file` / `#codebase`) and replace `livingContext` in the context before proceeding.

## Circuit Breaker

The router tracks retry counts per phase in `retryCount` within the PipelineContext. See [AGENT-PROTOCOL.md § Circuit Breaker](references/AGENT-PROTOCOL.md) for full rules.

**Before invoking any phase**, check:
```
if retryCount.{phase} >= 2 → STOP and escalate to user
```

**When a phase fails and auto-continues back** (e.g., test → implement → test), increment `retryCount.{re-entered phase}` before re-invoking.

On escalation, present:
- Which phase tripped the breaker
- The failure reason from the last attempt
- Suggestion for manual intervention

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
- **Plan** updates living docs in `docs/` only when needed; **Implement** finishes the job at done-done (data-model, contracts, ADR follow-ups, PARKING_LOT, retro line)
- Issue comments are supplementary discussion, not the canonical plan source
- Never create `specs/`, `spec.md`, or per-feature doc folders

## Skill Resolution Protocol

When a phase says "invoke `speckit-X`", resolve using this ordered fallback:


1. **VS Code skill discovery** — if `speckit-X` appears in the available skills list, use it directly.
2. **Direct file read** — if the skill is NOT in the available skills list, read the SKILL.md file:
   ```
   .github/skills/speckit-X/SKILL.md
   ```
   If not found, try inside the bundle:
   ```
   .github/skills/speckit/skills/speckit-X/SKILL.md
   ```
   Then follow the instructions in the loaded file as if it were the active skill.

**CRITICAL**: Never skip a pipeline step because "the skill doesn't exist". The files are always present in the speckit installation directory — use `read_file` to load them directly if VS Code discovery fails.

## Key Principles

- **One issue per spec** — checklist in the issue body, no sub-issues
- **Issue IS the tracker** — no tasks.md file
- **Issue-backed specs only** — the spec lives in the GitHub Issue body, never in `spec.md`
- **Plan appends; it does not replace** — keep the original spec at the top of the issue body and append/update the plan beneath it
- **Living docs live in `docs/`** — update them in plan and at done-done in implement, never create `specs/`
- **Right-sized artifacts** — only generate data-model, contracts, research when needed
- **Human-in-the-loop** — ask the next question at every step
- **Conventional commits** — every commit references the issue (`#N`)
- **PRs close issues** — `Closes #N` in PR description
