---
name: speckit-specify
description: >-
  Create or update a feature specification, bug report, or chore definition as a GitHub
  Issue-backed spec from a natural language description. Use this skill when the user wants to
  define a new feature, report a bug, write requirements, capture user stories, or create a
  spec. Triggers on requests like "I want to build...", "specify a feature for...", "write a
  spec", "fix this bug", or any feature ideation, bug reporting, and scoping task.
---

## Next Steps

After the spec is written, the next step depends on the **complexity signal**:
- **Needs plan** (schema changes, new/changed APIs, or unfamiliar domain): Suggest **speckit-plan** — "Create a technical plan with tasks for this spec."
- **Simple & scoped** (no schema, API, or domain unknowns): Suggest **speckit-implement** — "Implement this directly." (Skips plan.)

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

### Load Living Context

Before starting, load these living documents for context (if they exist):
- **`docs/retro.md`**: Scan for recurring pain points, patterns that worked, and process ideas relevant to the current work type. Note any findings that should influence spec quality.
- **`docs/constitution.md`**: Load principles that govern specification writing.

**Check for extension hooks (before specification)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_specify` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

### Artifact Rules

Before writing anything, keep these boundaries explicit:
- The canonical spec created by this step lives in the **GitHub Issue body**.
- **speckit-plan** appends its design notes and task checklist beneath this spec later; it must not replace the spec.
- Never create `specs/`, `spec.md`, or any other local per-feature spec file.
- Do not create or update living docs in `docs/` during **Specify**. Living docs belong to
  **Plan** and **Retro**.

## Outline

The text the user typed after `/speckit-specify` in the triggering message **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

### Interactive Clarification (before writing)

Before writing the spec, use `#askQuestions` to gather essential context in **focused batches of upto 5 questions at once but continue to ask as we must clarify all the necessary details**. This replaces the old approach of writing first and marking `[NEEDS CLARIFICATION]` afterwards.

**Round 1 — Scope & Type** (always ask):
1. Confirm or refine the work type classification (Feature / Bug / Chore)
2. What is the core value / problem being solved?
3. Are there any constraints or non-negotiables?

**Round 2 — Boundaries** (ask for Features only):
1. Who are the primary users / actors?
2. What is explicitly out of scope?
3. Any existing patterns in the codebase to follow? (Check retro insights)

**Round 3 — Edge Cases** (ask if answers from Round 2 reveal complexity):
1. What happens in failure scenarios?
2. Any known edge cases from similar past work? (Reference retro.md findings)

**Rules**:
- Each round uses `#askQuestions` with suggested options + a freetext field
- Incorporate answers into the spec — do NOT add `[NEEDS CLARIFICATION]` markers unless the user explicitly defers an answer
- For bugs/chores, only Round 1 is needed (keep it lightweight)
- Maximum 3 rounds total — then write the spec with best available info

Given that feature description, do this:

0. **Classify Work Type**: Analyze the description and classify as one of:
   - **Feature**: New capability, enhancement, or user-facing change requiring design (multi-step, needs planning)
   - **Bug**: Defect fix, type error, missing field, broken behavior (root cause known or discoverable, fix is scoped)
   - **Chore**: Refactor, dependency update, documentation, CI/CD, tooling (no user-facing change, no design needed)

   **Classification heuristic**:
   - Contains "fix", "broken", "missing", "wrong", "error", "bug", "incorrect" → likely **Bug**
   - Contains "update", "refactor", "rename", "move", "clean up", "upgrade" → likely **Chore**
   - Everything else → **Feature**
   - When ambiguous, ask the user using option tables (Feature / Bug / Chore)

    **If Bug or Chore**: Use a **lightweight issue-backed spec** and create a GitHub Issue directly.

    Compose the lightweight issue body:
   ```markdown
   # {Title}

   **Type**: Bug | Chore
   **Branch**: {branch-name}
   **Created**: {date}

   ## Description
   [What is wrong / What needs to change]

   ## Root Cause (bugs only)
   [Why this happens — reference file paths, line numbers, data model]

   ## Expected Behavior
   [What should happen after the fix]

   ## Affected Files
   - `path/to/file.ts` — [what changes]

   ## Verification
   - [ ] [How to verify the fix works]
   ```

   **Create the feature branch**:
   - Derive a short name (2-4 words, action-noun format)
   - Derive the next available spec number: check existing branches (`git branch -a`) and labels to find the highest `NNN`, then increment
   - Create branch: `git checkout -b {NNN}-{short-name}`

   **Create a GitHub Issue** for project board tracking:
   - Get the Git remote: `git config --get remote.origin.url`
   - **Only proceed if the remote is a GitHub URL**
   - Extract `owner` and `repo` from the remote URL
   - Create issue with: `gh issue create --repo {owner}/{repo} --title "[{Type}] {spec-number} — {title}" --body "{lightweight issue body}" --label "spec:{spec-number},{type}"`
   - Capture the issue number and report it
   - **Add to Project Board**: After creating the issue, check for a matching project:
     ```bash
     gh project list --owner {owner} --format json --limit 10
     ```
     Find the project whose title contains the repo name. If found:
     ```bash
     gh project item-add {project-number} --owner {owner} --url https://github.com/{owner}/{repo}/issues/{issue-number}
     ```

   Then assess the **complexity signal** for the lightweight spec:
   - If the bug/chore involves schema changes, new/changed APIs, or an unfamiliar domain → suggest **speckit-plan** `#{issue-number}`
   - Otherwise → suggest **speckit-implement** `#{issue-number}`

   Skip steps 1-6 below.

1. **Generate a concise short name** (2-4 words) for the branch.

2. **Create the feature branch**:
   - Derive the next available spec number: check existing branches (`git branch -a`) and labels to find the highest `NNN`, then increment
   - Create branch: `git checkout -b {NNN}-{short-name}`

3. Follow this execution flow for the **full feature spec in the GitHub Issue body**:

    1. Parse user description from Input
       If empty: ERROR "No feature description provided"
    2. Extract key concepts: actors, actions, data, constraints
    3. Use answers from the Interactive Clarification rounds to fill the spec.
       - Do NOT use `[NEEDS CLARIFICATION]` markers.
       - If the user deferred an answer, mark it as `[DEFERRED: reason]` (maximum 1 allowed).
    4. Fill User Scenarios & Testing section
    5. Generate Functional Requirements — each must be testable
    6. Define Success Criteria — measurable, technology-agnostic outcomes
    7. Identify Key Entities (if data involved)
    8. **Non-applicable sections**: Write `[NOT APPLICABLE]` with a brief reason. Never leave template placeholders.

4. **Compose the full spec body** for the GitHub Issue. Use the issue-body template structure (from this skill's `assets/issue-body-template.md`) as a guide, but the output goes into the **issue body only** — never a local file.

5. **Create a GitHub Issue** with the spec content:
   - Get the Git remote: `git config --get remote.origin.url`
   - **Only proceed if the remote is a GitHub URL**
   - Extract `owner` and `repo`
   - Create: `gh issue create --repo {owner}/{repo} --title "[Feature] {spec-number} — {title}" --body "{full spec content}" --label "spec:{spec-number},feature"`
   - **Add to Project Board** (same as bug/chore flow above)

6. **Validation**: Review the spec content against quality criteria:
  - No implementation details (languages, frameworks, APIs)
  - All requirements are testable and unambiguous
  - Success criteria are measurable and technology-agnostic
  - Edge cases are identified
  - No `specs/` directory or local `spec.md` file is created
  - No template placeholders or boilerplate remain
  - If validation fails, fix the issue body: `gh issue edit {ISSUE_NUMBER} --body "{fixed content}"`

7. Report completion with branch name, issue number, and readiness:
   - **Needs plan** (schema changes, new/changed APIs, or unfamiliar domain): Suggest `/speckit-plan #{issue-number}`
   - **Simple & scoped**: Suggest `/speckit-implement #{issue-number}`

8. **Check for extension hooks**: After reporting completion, check if `.specify/extensions.yml` exists in the project root.
   - If it exists, read it and look for entries under the `hooks.after_specify` key
   - If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
   - Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
   - For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
     - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
     - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
   - For each executable hook, output the following based on its `optional` flag:
     - **Optional hook** (`optional: true`):
       ```
       ## Extension Hooks

       **Optional Hook**: {extension}
       Command: `/{command}`
       Description: {description}

       Prompt: {prompt}
       To execute: `/{command}`
       ```
     - **Mandatory hook** (`optional: false`):
       ```
       ## Extension Hooks

       **Automatic Post-Hook**: {extension}
       Executing: `/{command}`
       EXECUTE_COMMAND: {command}
       ```
   - If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Key Rules

- The spec created by **Specify** lives in the GitHub Issue body.
- Later phases append or update plan details beneath the spec; they do not replace it.
- `docs/` is reserved for living documents updated later by **Plan** and **Retro**.
- Never create `specs/`, `spec.md`, or per-feature document folders during **Specify**.
