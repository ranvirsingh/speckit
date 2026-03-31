---
name: speckit-implement
description: >-
  Execute the implementation by working through the task checklist in the GitHub Issue,
  or directly implement a bug fix or chore from a lightweight spec. Use this skill when the
  user wants to start coding, implement features, execute tasks, fix bugs, or build out the
  project. Requires a GitHub issue number.
---

## Next Steps

After implementation is complete (including commit and push), run the retrospective to update living documents and triage discovered TODOs.
Suggest: **speckit-retro** — "Update living docs, close issues, and triage any discovered TODOs."

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before implementation)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_implement`.

## GitHub Issue Gate (MANDATORY)

This skill **requires a GitHub issue number** as input. The issue number can be provided via `$ARGUMENTS` (e.g., `#42` or `42`) or will be prompted for.

### Enforcement

1. Parse `$ARGUMENTS` for a GitHub issue reference (number or `#number`).
2. If no issue number is found:
   - **STOP**. Do not proceed.
   - Display: `⛔ speckit-implement requires a GitHub issue number. Use: /speckit-implement #42`
   - Explain: "This ensures work is tracked. Run `/speckit-specify` first to create the spec and issue, then use the issue number here."
   - Exit.
3. Validate the issue exists: `gh issue view {number} --repo {owner}/{repo} --json number,title,state,labels,body`
4. If the issue does not exist or is closed: **STOP** and report.

### Context Loading

Run the **speckit-living-docs-loader** agent as a subagent with:
- **Docs to load**: `docs/retro.md`, `docs/data-model.md`, `docs/contracts/*`
- **Work context**: The issue title and work type

Use the returned summary for retro insights and implementation context. Do not read these files directly.

---

## Outline

### Work Type Detection

Determine the work type and whether a plan exists from the GitHub Issue:

1. Read the issue body and labels: `gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body,labels`
2. Check labels for `bug`, `chore`, `feature`, and `plan`.
3. **If the issue has a `plan` label** (or the body contains a `<!-- speckit-plan:start -->` block, or a `## Design Notes` / `### Tasks` section) → follow the **Full Implementation Flow** below, regardless of work type.
4. **If type is Bug or Chore with no plan** → follow the **Lightweight Implementation Flow** below.
5. **If type is Feature (or no type label)** → follow the **Full Implementation Flow** below.

---

### Lightweight Implementation Flow (Bug / Chore)

For bugs and chores, the issue body contains the fix description, affected files, and verification steps. No plan artifacts are needed.

1. Read the issue body and extract:
   - Description, Root Cause (if bug), Affected Files, Verification steps
2. For each affected file:
   - Read the file and understand the current state
   - Implement the fix as described
   - Verify locally (run tests if applicable)
3. Mark all verification items as complete
4. Report completion and suggest **speckit-retro**

Skip all steps below — they are for the Full Implementation Flow only.

---

### Full Implementation Flow (Feature)

1. **Load the task checklist from the GitHub Issue**:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body
   ```
   Treat the issue body as two layers:
   - the original spec from **speckit-specify** at the top
   - the appended plan block from **speckit-plan** below it

   Parse the task checklist from the appended plan block only.
   Prefer content inside `<!-- speckit-plan:start --> ... <!-- speckit-plan:end -->`.
   For backward compatibility, fall back to the appended `## Design Notes` / `### Tasks` section if
   the markers are absent.

2. **Load implementation context**: Use the living-docs-loader summary from the Context Loading step (Pre-Execution Checks). The data model, contracts, and research findings are already available.
   - **IF EXISTS**: Read `docs/research.md` for technical decisions and constraints (if not already covered by the summary)

3. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the repository is a git repo (create/verify .gitignore if so)
   - Check if Dockerfile* exists → create/verify .dockerignore
   - Check if .eslintrc* or eslint.config.* exists → verify ignores
   - Check if .prettierrc* exists → create/verify .prettierignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

4. Parse the task checklist and extract:
   - **Task phases**: Setup, User Stories, Polish
   - **Task details**: ID, description
   - **Execution flow**: Phase-by-phase order

5. Execute implementation following the task checklist:
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Tasks affecting the same files must run sequentially
   - **Follow TDD approach if tests are listed**: Execute test tasks before their corresponding implementation tasks
   - **Validation checkpoints**: Verify each phase completion before proceeding

6. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, configuration
   - **Tests before code** (if applicable): Write tests for contracts, entities, and integration scenarios
   - **Core development**: Implement models, services, CLI commands, endpoints
   - **Integration work**: Database connections, middleware, logging, external services
   - **Polish and validation**: Unit tests, performance optimization, documentation

7. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if a blocking task fails
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed

8. **Update the GitHub Issue checklist**: After completing tasks, tick them off in the issue:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body
   ```
   Update only the appended plan block with `- [x]` for completed tasks. Preserve the original
   spec above it unchanged. If speckit plan markers are present, modify only the content inside
   `<!-- speckit-plan:start --> ... <!-- speckit-plan:end -->`:
   ```bash
   gh issue edit {ISSUE_NUMBER} --repo {owner}/{repo} --body "{updated body}"
   ```

9. Completion validation:
    - Verify all checklist items are ticked
    - Check that implemented features match the original specification
    - Validate that tests pass and coverage meets requirements
    - Report final status with summary of completed work

10. **Commit & Push** (automated — no user prompt needed):
    - Stage all changes: `git add -A`
    - Generate a conventional commit message based on the changes:
      - **Type**: `feat` for features, `fix` for bugs, `chore` for chores
      - **Scope**: Derive from the primary package or directory changed (scan workspace for top-level packages/directories to determine valid scopes), or omit for cross-cutting changes
      - **Subject**: Imperative mood, lowercase, max 72 chars, no period
      - **Body**: Bullet list of key changes (what was done, not why — the diff shows what)
      - **Footer**: `Closes #{issue_number}`
    - **Validate the commit message (deterministic — use script)** before committing:
      ```powershell
      & "<speckit-skill-path>/skills/speckit-implement/scripts/validate-commit-msg.ps1" -Message "{full commit message}"
      ```
      Where `<speckit-skill-path>` is resolved from the skill's installed location.
      If output is not `VALID`, fix the message and re-validate. Do NOT commit until validated.
    - Commit: `git commit -m "{type}({scope}): {subject}" -m "{body}" -m "Closes #{issue_number}"`
    - Push: `git push origin {branch_name}`
    - Create PR via GitHub CLI:
      ```bash
      gh pr create --repo {owner}/{repo} --title "{type}: {title}" --body "{PR description}" --base main --head {branch_name}
      ```
    - Add PR to project board:
      ```bash
      gh project item-add {project_number} --owner {owner} --url {pr_url}
      ```

---

## TODO Capture Convention

During implementation, when you discover something **out of scope** for the current feature (bug, tech debt, missing capability), capture it for the retrospective to triage:

### Code Comments

Add `TODO(speckit):` markers in the code where you discover the issue:

```typescript
// TODO(speckit): Component doesn't handle RTL languages — needs a spec
// TODO(speckit): Rate limiter uses fixed window instead of sliding — bug
// TODO(speckit): Consider extracting this into a shared utility — chore
```

### Rules for TODO Capture

- **Only capture out-of-scope items** — things that should NOT be fixed as part of the current feature
- **Do NOT stop implementation** to address discovered items — that's the retrospective's job
- **Classify loosely** — feature/bug/chore is enough; the retrospective will create proper specs
- **Include enough context** — file path, what's wrong, why it matters

---

## Post-Execution Hooks

After completion validation, check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.after_implement` key
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

    **Automatic Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently
