---
name: speckit-plan
user-invocable: true
model: Claude Sonnet 4.6 (copilot)
tools: ['search', 'codebase', 'web', 'fetch', 'usages', 'editFiles', 'runCommands', 'githubRepo']
agents: ['speckit-web-researcher']
description: >-
  Design the architecture and post the task checklist as a GitHub Issue comment — all in one flow.
  Use this skill when the user wants to plan a feature, design the architecture, create a data model,
   or define API contracts. Requires a GitHub Issue (created by speckit-specify).
   Post design notes and tasks as an issue comment; do not modify the issue body.
  Generate plan artifacts only when needed — update docs/data-model.md for schema changes,
   docs/contracts/*.md for new APIs, and docs/adr/*.md for significant architecture decisions.
   Skip docs/research.md unless the domain is unfamiliar.
---

## Issue State Tracking

On entry, advance the Issue State to "Plan". Read `.speckit-project.json` from the workspace root for `projectNumber` and `owner`. If the file does not exist, skip silently.

```powershell
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/set-issue-state.ps1 -ProjectNumber {projectNumber} -Owner {owner} -IssueNumber {issueNumber} -Repo {owner}/{repo} -State "Plan"
```

## Next Steps (AUTO-CONTINUE — HANDOFF ONLY)

After planning is complete, **hand off** to `speckit-implement #{issue-number}` by loading the implement skill as a new context. Do NOT start implementing within this skill's execution.

> **Critical**: AUTO-CONTINUE means "invoke the next phase as a separate skill load". It does NOT mean "start writing application code here". Plan produces design artifacts and task lists. Implementation is a separate phase with its own scope, context, and accountability. If you find yourself writing application source code, creating components, writing functions, or modifying non-doc files — STOP. You have crossed the scope boundary.

> **Skill resolution**: If a skill is not in your available skills list, use `read_file` to load its SKILL.md directly from `.github/skills/{skill-name}/SKILL.md` (or `.github/skills/speckit/skills/{skill-name}/SKILL.md` inside the bundle). Never skip a pipeline step because a skill appears unavailable.

## Scope Boundaries (MANDATORY — read before executing)

You are a **design and planning** skill. You produce documentation artifacts, task checklists, and architecture decisions. You operate under the [Scope Discipline](../../references/AGENT-PROTOCOL.md) rules.

**You MUST NOT:**
- Write application source code (`.ts`, `.js`, `.py`, `.rs`, `.go`, etc.)
- Create source files, components, modules, or services
- Install packages or run application code
- Modify any file outside `docs/` and the GitHub Issue comments
- Run tests or verify implementation
- Start executing tasks from the checklist you just created

**You MUST:**
- Produce design artifacts in `docs/` (data-model, contracts, ADRs)
- Produce a task checklist as a GitHub Issue comment
- Hand off to `speckit-implement` cleanly with the issue number
- STOP after the handoff — the implement phase takes over from here

## Complexity Gate

This skill applies to **any work type** (feature, bug, or chore) when the spec involves schema changes, new/changed APIs, or an unfamiliar domain. If none of these signals are present, the user should skip directly to **speckit-implement**.

Before proceeding, check the GitHub Issue for labels and body to confirm the complexity signal warrants planning. If the work is simple and scoped (e.g., a typo fix, a one-file bug), **auto-route to speckit-implement** instead — do not ask the user.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).
The input should include a GitHub Issue number (e.g. `#18`). If not provided, ask the user for it.

## Pre-Execution Checks

### Load Living Context

Read the relevant living docs directly via `read_file` / `#codebase` — only what's needed for the design at hand:

- `docs/constitution.md` — principles and constraints
- `docs/data-model.md` — current schema
- `docs/contracts/*` — existing API surface
- (optional) `docs/retro.md` — recent retro insights, if relevant to this work
- The issue body and comments (`gh issue view {N} --repo {owner}/{repo} --comments`)

Keep only what's relevant to the planning scope.

**Check for extension hooks (before planning)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_plan`.

---

## Pipeline Overview

This skill runs 2 steps sequentially:

```
Step 1: Design (research, data model, contracts) — generate only what's needed
Step 2: Post to GitHub Issue — add design notes and task checklist as an issue comment
```

After Step 1 (design complete), pause and ask the user: **"Design is ready for review. Ready to post the plan as a GitHub Issue comment?"** before proceeding to Step 2.

---

## Step 1: Design — Research & Architecture

### Setup

1. **Load the spec**: Read the GitHub Issue body to get the feature specification:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body,title,labels
   ```

2. **Load context**: Read `docs/constitution.md` directly for principles and constraints (loaded in Pre-Execution Checks).

3. **Determine current branch**: `git branch --show-current` — use this to identify the feature context.

### Phase 0: Outline & Research

1. **Extract unknowns from the spec**:
   - For each unclear area → research question
   - For each dependency → best practices question
   - For each integration → patterns question

2. **Research**: Use the built-in `#codebase` semantic search and `grep_search` against the workspace to investigate the unknowns. Look for:
   - Existing patterns and conventions for the area you're touching
   - Cross-cutting concerns and shared utilities
   - Gaps the design needs to fill

   For external/library research, load and follow `.github/skills/speckit-research/SKILL.md` as a sub-skill (it can call `speckit-web-researcher` for web-grounded queries) only when the domain is unfamiliar.

3. **Consolidate findings**: If the domain is unfamiliar or there are significant decisions, post findings as a GitHub Issue comment (with `<!-- speckit-research:start/end -->` markers). Format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

   If research is trivial (well-known patterns, small scope), skip and keep notes inline.

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

## Step 2: Post Plan to GitHub Issue Comment

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
   powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "."
   ```
   For each MUST and NON-NEGOTIABLE rule, check whether the design decisions and task list satisfy it. If any NON-NEGOTIABLE rule is violated, fix the plan before proceeding. Report SHOULD violations as warnings.
5. **Dependency order**: Tasks within each phase should be sequenced so no task depends on a later task. Flag circular or misordered dependencies.

If issues are found, fix them inline. Report a brief validation summary (pass/fail with counts) before asking the user to review.

### Post Plan as Issue Comment

#### Preservation Rule

The GitHub Issue body is the canonical spec created by **speckit-specify**. **Never modify the issue body.**

- Plans are posted as **issue comments**, not appended to the issue body.
- This keeps the spec lean and prevents context bloat that causes agent hangs.
- If a previous plan comment exists (search for `<!-- speckit-plan:start -->`), edit that comment instead of creating a new one.

1. Check for an existing plan comment:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --comments --json comments
   ```
   Search the returned comments for one containing `<!-- speckit-plan:start -->`.

2. Compose the plan comment:

   ```markdown
   <!-- speckit-plan:start -->
   ## Design Notes

   **Approach**: {key architecture decisions}
   **Living docs updated**: {list — e.g. docs/data-model.md, docs/contracts/api.md}

   {tasks checklist from above}

   ---
   _Plan posted by speckit-plan._
   <!-- speckit-plan:end -->
   ```

3. Post or update the plan comment:
   - **If no existing plan comment**: Create a new comment:
     ```bash
     gh issue comment {ISSUE_NUMBER} --repo {owner}/{repo} --body "{plan comment body}"
     ```
   - **If an existing plan comment was found**: Edit that comment:
     ```bash
     gh api repos/{owner}/{repo}/issues/comments/{comment_id} -X PATCH -f body="{plan comment body}"
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
- Note: auto-continuing to `speckit-implement #{ISSUE_NUMBER}`

---

## Post-Execution Hooks

Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_plan`.

---

## Key Rules

- Use absolute paths when reading/writing files
- ERROR on gate failures or unresolved clarifications
- Update living docs in `docs/` — do not create per-feature artifact folders
- The spec stays in the GitHub Issue body — do not create `specs/` or local `spec.md`
- Append the plan as an issue comment — never modify the original issue body
- Keep the canonical plan in an issue comment with `<!-- speckit-plan:start/end -->` markers
- Issue body is the spec only — plans go in comments to prevent context bloat
- ADRs belong to the plan phase — create or update them here when architecture decisions are made
- Generate plan artifacts only when needed (data-model.md for schema, contracts/ for APIs)
- Skip research.md unless the domain is unfamiliar
- ONE GitHub Issue per spec — no sub-issues
- Task checklist lives in an issue comment (not the issue body)
- **NEVER write application source code** — if you are writing `.ts`, `.js`, `.py`, or any non-doc file, you have violated the scope boundary. STOP and hand off to implement.
- **Handoff is a new context** — loading `speckit-implement` is the handoff. Do NOT bleed implementation work into the plan phase.
