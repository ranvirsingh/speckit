---
name: speckit-specify
user-invocable: true
description: >-
  Create or update a feature specification, bug report, or chore definition as a GitHub
  Issue-backed spec from a natural language description. Use this skill when the user wants to
  define a new feature, report a bug, write requirements, capture user stories, or create a
  spec. Triggers on requests like "I want to build...", "specify a feature for...", "write a
  spec", "fix this bug", or any feature ideation, bug reporting, and scoping task.
---

## Next Steps

After the spec is written, the next step depends on the **complexity signal**:
- **Needs research** (technology unknowns, library selection, unfamiliar APIs): Suggest **speckit-research** — "Research options before planning or implementing."
- **Needs plan** (schema changes, new/changed APIs, or unfamiliar domain): Suggest **speckit-plan** — "Create a technical plan with tasks for this spec."
- **Simple & scoped** (no schema, API, or domain unknowns): Suggest **speckit-implement** — "Implement this directly." (Skips plan.)

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

### Bootstrap

Run the install script to ensure speckit is up-to-date and all skills/agents are linked:

```powershell
powershell -ExecutionPolicy Bypass -File <speckit-root>/install.ps1
```

### Load Living Context

Use the `runSubagent` tool with `agentName: "speckit-living-docs-loader"` and provide:
- **Docs to load**: `docs/retro.md`, `docs/constitution.md`
- **Work context**: The user's feature/bug/chore description from `$ARGUMENTS`

Use the returned summary for retro insights and constitution principles. Do not read these files directly.

**Check for extension hooks (before specification)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_specify`.

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

The AI delegates reasoning to the **Nexus subagent** (Babbage), then confirms with the user in a single focused round. This replaces manual multi-round clarification.

**Step A — Invoke Nexus** (no user interaction):
Use the `runSubagent` tool with `agentName: "speckit-nexus"` and provide:
- **description**: The user's feature/bug/chore description from `$ARGUMENTS`
- **livingContext**: The summary returned by `speckit-living-docs-loader` (from the Pre-Execution step)
- **codebaseRoot**: The workspace root path

Nexus returns a structured pre-reasoning report containing:
- Work type classification with confidence level
- Core problem and value proposition
- Primary actors and affected areas
- Applicable constitution rules and retro patterns
- Anticipated edge cases
- Complexity signal (research/plan/implement recommendation)

If Nexus returns `reinvoke: true` with unresolved questions, answer them using available context and re-invoke (respecting the token bucket of **2**). Use partial results if the bucket is exhausted.

**Step B — Single Confirmation Round** (use `#askQuestions`):
Present the Nexus pre-reasoning as a structured summary and ask the user to confirm, correct, or add to each point. Include these questions:
1. "Nexus classified this as **{type}** ({confidence}) because {reason}. Correct?" — with Feature/Bug/Chore options
2. "Core problem identified: {summary}. Anything to add or correct?"
3. "What is explicitly **out of scope**?" — this is the one question neither AI nor Nexus can infer
4. (Features only) "Nexus identified these actors: {actors}, constraints: {constraints}, edge cases: {edge cases}. Anything missing?"

If Nexus flagged `classification_confidence: low`, elevate question 1 to a required selection (not just a confirmation).

**Step C — Follow-Up Round** (only if Step B reveals significant gaps):
If the user's corrections in Step B reveal complexity that Nexus missed, ask up to 3 targeted follow-up questions. Otherwise, proceed directly to writing the spec.

**Rules**:
- Nexus does the heavy lifting — the skill focuses on user confirmation only
- Use `#askQuestions` with suggested options + a freetext field
- Incorporate answers into the spec — do NOT add `[NEEDS CLARIFICATION]` markers unless the user explicitly defers an answer
- For bugs/chores, only the classification confirmation and out-of-scope question are needed (keep it lightweight)
- Maximum 2 rounds of user interaction total — then write the spec with best available info

Given that feature description, do this:

0. **Classify Work Type**: The Nexus subagent (Step A above) handles classification. Use its result directly.
   If Nexus was not invoked (e.g., empty description), fall back to the heuristic:
   1. Contains words like "fix", "broken", "missing", "wrong", "error", "bug", "incorrect", "crash", "regression" → **Bug**
   2. Contains words like "update", "refactor", "rename", "move", "clean up", "upgrade", "migrate", "deprecate" → **Chore**
   3. Everything else → **Feature**

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
   - Derive a short name (2-4 words, action-noun format, lowercase kebab-case)
   - Get the Git remote: `git config --get remote.origin.url` → extract `owner/repo`
   - **Derive the next spec number (deterministic — use script)**:
     ```powershell
     $specNumber = & "<speckit-root>/skills/speckit-specify/scripts/next-spec-number.ps1" -RepoFlag "{owner}/{repo}"
     ```
     Where `<speckit-root>` is the speckit pipeline root directory (where the main SKILL.md lives).
     Use the output directly — do NOT manually scan branches or do arithmetic.
   - **Validate the branch name (deterministic — use script)**:
     ```powershell
     & "<speckit-root>/skills/speckit-specify/scripts/validate-branch-name.ps1" -Name "{specNumber}-{short-name}"
     ```
     If output is not `VALID`, fix the name and re-validate before proceeding.
   - Create branch: `git checkout -b {specNumber}-{short-name}`

   **Create a GitHub Issue** for project board tracking:
   - **Only proceed if the remote is a GitHub URL**
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

   Then run a **constitution compliance check** on the lightweight spec:
   ```powershell
   powershell -ExecutionPolicy Bypass -File <speckit-root>/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "<workspace-root>"
   ```
   For each MUST and NON-NEGOTIABLE rule, check whether the spec content satisfies it.
   If any NON-NEGOTIABLE rule is violated, fix the issue body before proceeding.

   Then assess the **complexity signal** for the lightweight spec:
   - If the bug/chore involves schema changes, new/changed APIs, or an unfamiliar domain → suggest **speckit-plan** `#{issue-number}`
   - Otherwise → suggest **speckit-implement** `#{issue-number}`

   Skip all remaining steps (1-9) below.

1. **Generate a concise short name** (2-4 words, lowercase kebab-case) for the branch.

2. **Create the feature branch**:
   - Get the Git remote: `git config --get remote.origin.url` → extract `owner/repo`
   - **Derive the next spec number (deterministic — use script)**:
     ```powershell
     $specNumber = & "<speckit-root>/skills/speckit-specify/scripts/next-spec-number.ps1" -RepoFlag "{owner}/{repo}"
     ```
     Where `<speckit-root>` is the speckit pipeline root directory (where the main SKILL.md lives).
     Use the output directly — do NOT manually scan branches or do arithmetic.
   - **Validate the branch name (deterministic — use script)**:
     ```powershell
     & "<speckit-root>/skills/speckit-specify/scripts/validate-branch-name.ps1" -Name "{specNumber}-{short-name}"
     ```
     If output is not `VALID`, fix the name and re-validate before proceeding.
   - Create branch: `git checkout -b {specNumber}-{short-name}`

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

7. **Constitution compliance check**: Extract constitution rules and verify the spec complies:
   ```powershell
   powershell -ExecutionPolicy Bypass -File <speckit-root>/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "<workspace-root>"
   ```
   For each MUST and NON-NEGOTIABLE rule, check whether the spec content satisfies it.
   If any NON-NEGOTIABLE rule is violated, fix the spec before proceeding.
   Report any SHOULD violations as warnings.

8. Report completion with branch name, issue number, and readiness:
   - **Needs plan** (schema changes, new/changed APIs, or unfamiliar domain): Suggest `/speckit-plan #{issue-number}`
   - **Simple & scoped**: Suggest `/speckit-implement #{issue-number}`

9. **Check for extension hooks (after specification)**:
   Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_specify` (post-hook variant).

## Key Rules

- The spec created by **Specify** lives in the GitHub Issue body.
- Later phases append or update plan details beneath the spec; they do not replace it.
- `docs/` is reserved for living documents updated later by **Plan** and **Retro**.
- Never create `specs/`, `spec.md`, or per-feature document folders during **Specify**.
