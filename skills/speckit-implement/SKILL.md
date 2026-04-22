---
name: speckit-implement
user-invocable: true
model: Claude Sonnet 4.6 (copilot)
tools: ['search', 'codebase', 'usages', 'editFiles', 'runCommands', 'runTasks', 'runTests', 'web', 'fetch', 'githubRepo', 'problems', 'changes']
agents: ['speckit-test', 'speckit-e2e']
handoffs:
  - label: Run UAT
    agent: speckit-test
    prompt: Run user acceptance testing against the spec for this issue.
    send: false
description: >-
  Execute the implementation by working through the task checklist in the GitHub Issue,
  or directly implement a bug fix or chore from a lightweight spec. Use this skill when the
  user wants to start coding, implement features, execute tasks, fix bugs, or build out the
  project. Requires a GitHub issue number.
---

## Issue State Tracking

On entry, advance the Issue State to "Implement". Read `.speckit-project.json` from the workspace root for `projectNumber` and `owner`. If the file does not exist, skip silently.

```powershell
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/set-issue-state.ps1 -ProjectNumber {projectNumber} -Owner {owner} -IssueNumber {issueNumber} -Repo {owner}/{repo} -State "Implement"
```

## Next Steps (AUTO-CONTINUE)

After implementation is complete (including commit and push), **enrich the PipelineContext** with implementation details and **automatically proceed** to user acceptance testing via `runSubagent`.

### Enrich PipelineContext

After creating the PR, add the `implementation` block to the PipelineContext:

```jsonc
{
  "implementation": {
    "completedAt": "{ISO timestamp}",
    "prNumber": {pr-number},
    "prUrl": "{pr-url}",
    "commitSha": "{commit-sha}",
    "baseUrl": "{detected dev-server URL or null}",
    "authToken": null
  }
}
```

Detect `baseUrl` from `package.json` scripts (the dev server port) or project configuration. If not detectable, leave as `null`.

### Invoke Test Agent

Before invoking the test agent, advance Issue State to "Test":

```powershell
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/set-issue-state.ps1 -ProjectNumber {projectNumber} -Owner {owner} -IssueNumber {issueNumber} -Repo {owner}/{repo} -State "Test"
```

Use `runSubagent` with `agentName: "speckit-test"` and pass the enriched PipelineContext:

```
runSubagent(agentName: "speckit-test", prompt: JSON.stringify({ pipelineContext: ctx }))
```

If no PipelineContext is available (standalone invocation), invoke `speckit-test #{issue-number}` as a skill instead.

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

Read the relevant living docs directly via `read_file` — only what's needed for the work in scope:

- `docs/constitution.md` — MUST/NON-NEGOTIABLE rules to honour
- `docs/data-model.md` — current schema (if implementation touches it)
- `docs/contracts/*` — API contracts (if implementation touches an API)
- (optional) `docs/retro.md` — recent retro insights, if directly relevant
- The issue body, plan comment, and any research comment for this issue

Keep what's relevant to the implementation scope. Skip the rest.

---

## Outline

### Work Type Detection

Determine the work type and whether a plan exists from the GitHub Issue:

1. Read the issue body and labels: `gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body,labels`
2. Check labels for `bug`, `chore`, `feature`, and `plan`.
3. **If the issue has a `plan` label** (or an issue comment contains `<!-- speckit-plan:start -->`, or a comment contains `## Design Notes` / `### Tasks`) → follow the **Full Implementation Flow** below, regardless of work type.
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
4. **Constitution compliance check** before committing:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "."
   ```
   For each MUST and NON-NEGOTIABLE rule, verify the implementation complies.
   If any NON-NEGOTIABLE rule is violated, fix the code before proceeding.
5. Report completion and **automatically proceed** to `speckit-test #{issue-number}` — do NOT stop to ask.

Skip all steps below — they are for the Full Implementation Flow only.

---

### Full Implementation Flow (Feature)

1. **Load the task checklist from the GitHub Issue comments**:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --comments --json comments
   ```
   The plan is posted as an **issue comment** (not in the issue body). Search the comments for
   one containing `<!-- speckit-plan:start --> ... <!-- speckit-plan:end -->` markers and parse the
   task checklist from that comment.
   For backward compatibility, also check the issue body for a `<!-- speckit-plan:start -->` block
   or a `## Design Notes` / `### Tasks` section:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body
   ```

2. **Load implementation context**: The data model, contracts, and research findings were loaded directly during Context Loading (Pre-Execution Checks) — refer back to them as you implement.
   - Also check issue comments for research findings (`<!-- speckit-research:start -->` marker) and `docs/research.md` as a fallback for technical decisions and constraints not already covered.

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

8. **Update the plan comment checklist**: After completing tasks, update the plan comment with `- [x]` for completed tasks:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --comments --json comments
   ```
   Find the comment containing `<!-- speckit-plan:start -->` and update it with checked tasks.
   If the plan was found in the issue body (backward compatibility), update only the plan block
   in the body. Otherwise, update the plan comment:
   ```bash
   gh api repos/{owner}/{repo}/issues/comments/{comment_id} -X PATCH -f body="{updated plan comment}"
   ```

9. Completion validation:
    - Verify all checklist items are ticked
    - Check that implemented features match the original specification
    - Validate that tests pass and coverage meets requirements
    - Report final status with summary of completed work

10. **Constitution compliance check** before committing:
    ```powershell
    powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "."
    ```
    For each MUST and NON-NEGOTIABLE rule, verify the implementation complies (e.g., tests exist if required, naming conventions followed, documentation updated).
    If any NON-NEGOTIABLE rule is violated, fix the code before proceeding to commit.

11. **Commit & Push** (automated — no user prompt needed):
    - Stage all changes: `git add -A`
    - Generate a conventional commit message based on the changes:
      - **Type**: `feat` for features, `fix` for bugs, `chore` for chores
      - **Scope**: Derive from the primary package or directory changed (scan workspace for top-level packages/directories to determine valid scopes), or omit for cross-cutting changes
      - **Subject**: Imperative mood, lowercase, max 72 chars, no period
      - **Body**: Bullet list of key changes (what was done, not why — the diff shows what)
      - **Footer**: `Closes #{issue_number}`
    - **Validate the commit message (deterministic — use script)** before committing:
      ```powershell
      & ".github/skills/speckit-implement/scripts/validate-commit-msg.ps1" -Message "{full commit message}"
      ```
      If the script is not found at that path, try `.github/skills/speckit/skills/speckit-implement/scripts/validate-commit-msg.ps1` (inside the bundle).
      If output is not `VALID`, fix the message and re-validate. Do NOT commit until validated.
    - Commit: `git commit -m "{type}({scope}): {subject}" -m "{body}" -m "Closes #{issue_number}"`
    - Push: `git push origin {branch_name}`
      If the push fails due to merge conflicts:
      1. Pull latest: `git pull origin main --rebase`
      2. Resolve conflicts (prefer the implementation changes for files in scope; keep upstream changes for unrelated files)
      3. Continue rebase: `git rebase --continue`
      4. Push again: `git push origin {branch_name} --force-with-lease`
    - Create PR via GitHub CLI (DRAFT FIRST — `before_pr` hook below):
      ```bash
      gh pr create --repo {owner}/{repo} --title "{type}: {title}" --body "{PR description}" --base main --head {branch_name} --draft
      ```

      **`before_pr` gate** — after the draft PR is created, validate the PR body
      against the bundled `pipeline-guard.yml` regex set BEFORE marking ready.
      Check both rules locally:
        1. Body contains `Closes #N` (or `Fixes` / `Resolves`)
        2. Every Speckit phase line is either `- [x] **{Phase}**` OR there is a matching
           `skip-speckit: {phase} — <reason>` in the body
      If either rule fails, edit the PR body via `gh pr edit {pr_number} --body-file ...`
      until both rules pass. Then run extension hooks:
      Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_pr`.

      Once the body is valid, mark the PR ready for review:
      ```bash
      gh pr ready {pr_number}
      ```

    - Add PR to project board:
      ```bash
      gh project item-add {project_number} --owner {owner} --url {pr_url}
      ```

---

## TODO Capture Convention

During implementation, when you discover something **out of scope** for the current feature (bug, tech debt, missing capability), capture it for triage:

### Code Comments

Add `TODO(speckit):` markers in the code where you discover the issue:

```typescript
// TODO(speckit): Component doesn't handle RTL languages — needs a spec
// TODO(speckit): Rate limiter uses fixed window instead of sliding — bug
// TODO(speckit): Consider extracting this into a shared utility — chore
```

### Rules for TODO Capture

- **Only capture out-of-scope items** — things that should NOT be fixed as part of the current feature
- **Do NOT stop implementation** to address discovered items — triage them at done-done
- **Classify loosely** — feature/bug/chore is enough; the triage step creates proper specs
- **Include enough context** — file path, what's wrong, why it matters

---

## Done-Done: Living Docs + TODO Triage

Before marking the PR ready, update the living documents and triage any discovered TODOs. This replaces the deprecated separate "retro" phase — the cost of keeping docs in sync is tiny when done immediately after the implementation, and impossible weeks later.

### 1. Update living docs

For every change made, update the matching living doc IF it is now out of date:

- **`docs/data-model.md`** — schema changes, new entities, modified relationships
- **`docs/contracts/*.md`** — API changes, new endpoints, modified request/response shapes
- **`docs/adr/adr-NNN-*.md`** — only if the implementation diverged from the plan in a way that needs explaining

If no such doc exists yet and the change warrants one, create it. Use the templates under `agents/assets/` (legacy retro/parking-lot templates are still useful starting points).

### 2. Triage TODO(speckit) markers

```bash
git diff main...HEAD | Select-String -Pattern 'TODO\(speckit\)' -Context 0,2
```

For each marker introduced in this PR:

- If the item is small enough to fit in a chore: open a chore issue immediately via `gh issue create --template chore.yml`.
- Otherwise: append a row to `PARKING_LOT.md` (create the file if missing, using `agents/assets/parking-lot-template.md` as a starting point).

### 3. One-line retro summary

Append a single line to `docs/retro.md` (create if missing):

```markdown
- {date} #{N} — {one-sentence summary of what shipped, what surprised, what's parked}
```

Keep it short. The PR description, commits, and updated docs already capture detail.

---

## Post-Execution Hooks

Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_implement`.
