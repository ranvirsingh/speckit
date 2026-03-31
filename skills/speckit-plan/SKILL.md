---
name: speckit-plan
user-invocable: true
description: >-
  Design the architecture and update the GitHub Issue with a task checklist — all in one flow.
  Use this skill when the user wants to plan a feature, design the architecture, create a data model,
   or define API contracts. Requires a GitHub Issue (created by speckit-specify).
   Append design notes and tasks beneath the existing issue-backed spec; do not replace it.
  Generate plan artifacts only when needed — update docs/data-model.md for schema changes,
   docs/contracts/*.md for new APIs, and docs/adr/*.md for significant architecture decisions.
   Skip docs/research.md unless the domain is unfamiliar.
---

## Next Steps

After planning is complete, suggest: **speckit-implement** — "Start implementing the tasks."

## Complexity Gate

This skill applies to **any work type** (feature, bug, or chore) when the spec involves schema changes, new/changed APIs, or an unfamiliar domain. If none of these signals are present, the user should skip directly to **speckit-implement**.

Before proceeding, check the GitHub Issue for labels and body to confirm the complexity signal warrants planning. If the work is simple and scoped (e.g., a typo fix, a one-file bug), suggest skipping to **speckit-implement** instead.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).
The input should include a GitHub Issue number (e.g. `#18`). If not provided, ask the user for it.

## Pre-Execution Checks

### Load Living Context

Use the `runSubagent` tool with `agentName: "speckit-living-docs-loader"` and provide:
- **Docs to load**: `docs/retro.md`, `docs/constitution.md`, `docs/data-model.md`, `docs/contracts/*`
- **Work context**: The spec title and summary from the GitHub Issue

Use the returned summary for retro insights, constitution principles, and current schema understanding. Do not read these files directly.

**Check for extension hooks (before planning)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_plan`.

---

## Pipeline Overview

This skill runs 2 steps sequentially:

```
Step 1: Design (research, data model, contracts) — generate only what's needed
Step 2: Update GitHub Issue — add design notes and task checklist to the existing issue
```

After Step 1 (design complete), pause and ask the user: **"Design is ready for review. Ready to update the GitHub Issue with design notes and task checklist?"** before proceeding to Step 2.

---

## Step 1: Design — Research & Architecture

### Setup

1. **Load the spec**: Read the GitHub Issue body to get the feature specification:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body,title,labels
   ```

2. **Load context**: Constitution principles are already available from the living-docs-loader summary (loaded in Pre-Execution Checks).

3. **Determine current branch**: `git branch --show-current` — use this to identify the feature context.

### Phase 0: Outline & Research

1. **Extract unknowns from the spec**:
   - For each unclear area → research question
   - For each dependency → best practices question
   - For each integration → patterns question

2. **Research**: Use the `runSubagent` tool with `agentName: "speckit-codebase-scanner"` and provide:
   - **Spec body**: The feature specification from the GitHub Issue
   - **Research questions**: The list of unknowns extracted above
   - **Codebase root**: Current working directory

   Use the scanner's structured findings to inform design decisions. Do not manually scan the codebase.

3. **Consolidate findings**: If the domain is unfamiliar or there are significant decisions, update `docs/research.md` with findings. Format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

   If research is trivial (well-known patterns, small scope), skip the file and keep notes inline.

### Phase 1: Design & Contracts

0. **Living docs root** → before writing any living document, ensure `docs/` exists.
   Create `docs/` (and `docs/contracts/` when needed) if missing. Do **not** create `specs/`
   or a local `spec.md`.

1. **Data model changes** → update `docs/data-model.md` (if file doesn't exist, initialize from this skill's `assets/data-model-template.md`):
   - Add or modify entity definitions, fields, relationships
   - Add validation rules from requirements
   - Add state transitions if applicable
   - Preserve existing content — append or update, don't replace

2. **Interface contracts** (if the feature adds/changes external interfaces) → create/update files in `docs/contracts/`:
   - Document the contract format appropriate for the project type
   - Examples: public APIs for libraries, endpoints for web services, SDK interfaces
   - Skip if feature is purely internal

3. **Architecture Decision Records** (if the design introduces a significant architectural choice) → create/update files in `docs/adr/`:
   - Examples: new dependency, cross-cutting pattern, technology swap, major protocol choice
   - If `docs/adr/` does not exist, create it
   - Create `docs/adr/adr-NNN-{topic}.md` using this skill's `assets/adr-template.md`
   - Capture context, decision, consequences, and alternatives during planning while the rationale is fresh

4. Re-evaluate Constitution Check post-design (if constitution exists).

**Output**: Updated living docs in `docs/` (data-model.md, contracts/, adr/, research.md — only those that apply)

---

## Step 2: Update GitHub Issue

### Prerequisites

1. Get the Git remote by running: `git config --get remote.origin.url`

> [!CAUTION]
> ONLY PROCEED IF THE REMOTE IS A GITHUB URL

2. Extract the `owner` and `repo` from the remote URL.

### Find the Existing Issue

1. Use the issue number from the user input. If not provided, find it by label:
   ```bash
   gh issue list --repo {owner}/{repo} --label "spec:{spec-number}" --state open --json number,title
   ```
2. If no issue is found: **STOP**. Display: "No issue found. Run `/speckit-specify` first."
3. Capture the issue number as `ISSUE_NUMBER`.

### Build the Task Checklist

From the spec (issue body) and design artifacts, create a task checklist:

1. Extract user stories / requirements from the issue body
2. Break each into implementable tasks
3. Group tasks into phases:
   - **Setup**: Project initialization, dependencies, configuration
   - **Per User Story**: One group per story in priority order
   - **Polish**: Documentation, cross-cutting concerns
4. Format as a markdown checklist:

   ```markdown
   ### Tasks

   **Setup**
   - [ ] T001 — {description}
   - [ ] T002 — {description}

   **US1 — {story title}**
   - [ ] T003 — {description}
   - [ ] T004 — {description}

   **US2 — {story title}**
   - [ ] T005 — {description}

   **Polish**
   - [ ] T006 — {description}
   ```

### Validate Plan Consistency

Before publishing to the GitHub Issue, run these checks. If any fail, fix them before proceeding.

1. **Task coverage**: Every requirement / acceptance criterion in the spec must map to at least one task. List any uncovered requirements.
2. **No orphan tasks**: Every task must trace back to a requirement, setup need, or polish item. Flag tasks with no clear origin.
3. **Ambiguity check**: Scan the task descriptions for vague terms (`various`, `etc.`, `as needed`, `TBD`, `some`). Rewrite to be specific.
4. **Constitution compliance check**: Extract constitution rules and verify the plan complies:
   ```powershell
   powershell -ExecutionPolicy Bypass -File <speckit-skill-path>/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "<workspace-root>"
   ```
   For each MUST and NON-NEGOTIABLE rule, check whether the design decisions and task list satisfy it. If any NON-NEGOTIABLE rule is violated, fix the plan before proceeding. Report SHOULD violations as warnings.
5. **Dependency order**: Tasks within each phase should be sequenced so no task depends on a later task. Flag circular or misordered dependencies.

If issues are found, fix them inline. Report a brief validation summary (pass/fail with counts) before asking the user to review.

### Update the Issue Description

#### Preservation Rule

Treat the current GitHub Issue body as the canonical spec created by **speckit-specify**.

- Never overwrite or rewrite the original spec sections when adding plan details.
- Append the plan beneath the existing spec in the same issue body.
- If a plan block already exists, replace **only** that appended plan block.
- Issue comments may be used for discussion, but the canonical plan consumed by downstream skills
  must remain in the issue body.

1. Read the current issue body:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body
   ```

2. Compose the updated body by appending design notes and the task checklist beneath the spec.
   Use the existing issue body as-is above the plan block. If a previous speckit plan block exists,
   replace only the text inside that block.

   ```markdown
   {existing issue body without old speckit-plan block}

   ---

   <!-- speckit-plan:start -->
   ## Design Notes

   **Approach**: {key architecture decisions}
   **Living docs updated**: {list — e.g. docs/data-model.md, docs/contracts/api.md}

   {tasks checklist from above}

   ---
   _Plan appended by speckit-plan. Preserve the spec above._
   <!-- speckit-plan:end -->
   ```

3. Update the issue body by appending or replacing only the plan block:
   ```bash
   gh issue edit {ISSUE_NUMBER} --repo {owner}/{repo} --body "{updated body}"
   ```

4. Add the `plan` label (create if it doesn't exist):
   ```bash
   gh label create plan --repo {owner}/{repo} --description "Has a design plan" --color "0E8A16" 2>/dev/null
   gh issue edit {ISSUE_NUMBER} --repo {owner}/{repo} --add-label "plan"
   ```

### Report

Output a summary:
- Issue URL and number
- Task count and phase breakdown
- List of updated living docs
- Suggest next step: `/speckit-implement #{ISSUE_NUMBER}`

---

## Post-Execution Hooks

Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_plan`.

---

## Key Rules

- Use absolute paths when reading/writing files
- ERROR on gate failures or unresolved clarifications
- Update living docs in `docs/` — do not create per-feature artifact folders
- The spec stays in the GitHub Issue body — do not create `specs/` or local `spec.md`
- Append the plan beneath the spec — never replace the original spec sections
- Keep the canonical plan in the issue body, not only in issue comments
- ADRs belong to the plan phase — create or update them here when architecture decisions are made
- Generate plan artifacts only when needed (data-model.md for schema, contracts/ for APIs)
- Skip research.md unless the domain is unfamiliar
- ONE GitHub Issue per spec — no sub-issues
- Task checklist lives in the issue description
