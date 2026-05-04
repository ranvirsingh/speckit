---
name: speckit-pr-description
user-invocable: true
tools: ['search', 'codebase', 'runCommands', 'githubRepo']
description: >-
  Validate and auto-fix a PR description so it satisfies the speckit pipeline guard.
  Checks for a `Closes #N` link and that every pipeline phase checkbox is either ticked
  or has a `skip-speckit: <phase> — <reason>` justification. Rewrites the PR body via
  `gh pr edit` and confirms the guard would pass. Use when the pipeline guard is red,
  or after `speckit-implement` creates a PR, to prevent guard failures before review.
---

# Speckit PR Description Skill

This is the **speckit-pr-description** skill — it keeps the pipeline guard green by
ensuring every PR description satisfies the guard rules before the PR is reviewed.

## Scope Boundaries (MANDATORY)

You are a **PR description validator and fixer**. You read the PR body, determine
what needs changing, and rewrite the body in place.

**You MUST NOT:**
- Modify application source code
- Run tests or open new PRs
- Invoke any other pipeline phase
- Skip the local re-validation step

**You MUST:**
- Return a clear summary of what was changed (or confirm nothing needed changing)
- Leave the PR body valid against all pipeline guard rules when done

---

## Input

Accept one of:
- **`$ARGUMENTS`** — a PR number (`#42` or `42`) or nothing (auto-detect from current branch)
- **`pipelineContext`** — a `PipelineContext` JSON object (when invoked from the router or `speckit-implement`)

### Auto-detect PR number (when no argument provided)

```bash
# Get current branch
git branch --show-current

# Find the PR for this branch
gh pr list --head {branch} --repo {owner}/{repo} --json number,url,body --limit 1
```

### Derive owner/repo

```bash
git config --get remote.origin.url
```

Parse `owner` and `repo` from the URL (handles both SSH and HTTPS formats).

---

## Execution

### Step 1 — Load the PR

```bash
gh pr view {pr_number} --repo {owner}/{repo} --json number,title,body,headRefName,baseRefName
```

Extract:
- `body` — the current PR description
- `headRefName` — the feature branch (used to find the issue number)

### Step 2 — Resolve the linked issue number

Parse the PR body for an existing `Closes #N` / `Fixes #N` / `Resolves #N` match.
If none found, extract the issue number from the branch name (pattern: `{number}-{slug}`).
If the `pipelineContext` is available, read `issueNumber` directly from it.

```bash
# Verify the issue exists
gh issue view {issue_number} --repo {owner}/{repo} --json number,title,labels,body,comments
```

### Step 3 — Determine phase completion

Inspect every available signal to decide whether each phase was **done** or **skipped**:

| Phase | Done signal |
|---|---|
| **Specify** | Issue exists (any tracked PR has a spec by definition) |
| **Research** | Issue has a comment with `<!-- speckit-research:start -->` marker OR `docs/research.md` updated in this branch |
| **Plan** | Issue has a comment with `<!-- speckit-plan:start -->` marker OR issue body contains `## Design Notes` / `### Tasks` section |
| **Implement** | PR exists — this phase always done when a PR is open |
| **Test (UAT)** | `pipelineContext.phaseVerdicts.test.verdict == "pass"` OR issue has a comment containing `<!-- speckit-uat:start -->` marker OR branch contains a test summary commit message |
| **E2E** | `pipelineContext.phaseVerdicts.e2e.verdict == "pass"` OR issue has a comment containing `<!-- speckit-e2e:start -->` marker OR PR body already has a non-empty E2E artifact section |
| **Retro** | `pipelineContext.phaseVerdicts.retro.verdict == "pass"` OR branch contains a commit that updated `docs/PARKING_LOT.md` or living docs |

When a signal is absent for Research, Plan, Test (UAT), E2E, or Retro — treat the phase as **skipped** (needs a `skip-speckit:` line).

> Specify and Implement are **always done** for any tracked PR. Never add a skip line for these two phases.

### Step 4 — Validate current body

Run the same checks as `pipeline-guard.yml`:

```text
RULE 1 — Issue link
  Body must match: /\b(?:Closes|Fixes|Resolves)\s+#\d+/i

RULE 2 — Phase checkboxes (for each of the 7 phases)
  Body must have EITHER:
    - [x] **{Phase}**          ← checkbox ticked
    OR
    skip-speckit: {phase-key} — <reason>   ← on its own line (case-insensitive, start of line)
```

Phase keys (must match `pipeline-guard.yml` exactly):

| Display name | phase-key | checkbox pattern |
|---|---|---|
| Specify | `specify` | `- [x] **Specify**` |
| Research | `research` | `- [x] **Research**` |
| Plan | `plan` | `- [x] **Plan**` |
| Implement | `implement` | `- [x] **Implement**` |
| Test (UAT) | `test` | `- [x] **Test (UAT)**` |
| E2E | `e2e` | `- [x] **E2E**` |
| Retro | `retro` | `- [x] **Retro**` |

If all rules pass → skip to **Step 6 (Confirm)**.

### Step 5 — Rewrite the PR body

Use the standard PR template as the target shape (read from
`.github/PULL_REQUEST_TEMPLATE.md` in the target repo if it exists, otherwise
use the inline template below). Populate it with all available context:

```markdown
<!--
  Speckit-tracked PR. Fill EVERY checkbox below. If you must skip a phase,
  add `skip-speckit: <phase> — <reason>` on its own line in this body and CI will allow it.
-->

## Linked issue

Closes #{issue_number}

## What changed

{1–3 sentence summary from PR title / existing body "What changed" section}

## Speckit phases

- [{specify_tick}] **Specify** — issue body contains the spec (acceptance criteria + checklist)
- [{research_tick}] **Research** — needed? if yes, findings recorded in issue or `docs/research.md`
- [{plan_tick}] **Plan** — needed? if yes, design notes + tasks appended to issue
- [{implement_tick}] **Implement** — code complete, conventional commits reference `#{issue_number}`
- [{test_tick}] **Test (UAT)** — every acceptance scenario in the issue passes
- [{e2e_tick}] **E2E** — proof-of-work artifact attached below (gif / video / `.http` / log)
- [{retro_tick}] **Retro** — living docs updated; TODOs triaged into `docs/PARKING_LOT.md`

## Test results

```
{test_results_or_placeholder}
```

## E2E artifact

{e2e_artifact_or_placeholder}

## Skipped phases

{skip_lines_for_each_skipped_phase}
```

#### Substitution rules

- `{tick}` = `x` when the phase is **done**, empty string (``) when skipped
- For each **skipped** phase, append a `skip-speckit:` line in the **Skipped phases** section:
  ```
  skip-speckit: {phase-key} — {reason}
  ```
  Use these default reasons when no better context is available:
  | Phase | Default reason |
  |---|---|
  | research | no library or pattern unknowns |
  | plan | straightforward change, no schema or API design needed |
  | test | {describe what was manually verified, or "manual smoke test passed"} |
  | e2e | pure chore/refactor, no observable behaviour change |
  | retro | no out-of-scope items discovered, living docs unchanged |

- For the **What changed** section: keep the existing content if present; otherwise derive 1–3 sentences from the PR title and the issue summary.
- For **Test results**: keep existing content if present; otherwise use `<!-- paste test summary -->`.
- For **E2E artifact**: keep existing content if present; otherwise use `<!-- gif / video link / e2e-NN-results.md path / .http file path -->`.

#### Body write strategy

1. If the existing body already contains the speckit template structure, **patch only the failing sections** (don't discard the whole body — the user may have added content).
2. If the body is empty or missing the template entirely, **write the full template** populated with all available context.

Write the new body to a temp file:

```powershell
$body = @"
{full PR body text}
"@
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $body -Encoding UTF8
```

Apply via:

```bash
gh pr edit {pr_number} --repo {owner}/{repo} --body-file {tempFile}
```

Clean up the temp file afterwards.

### Step 6 — Confirm (local re-validation)

Re-read the PR body after editing:

```bash
gh pr view {pr_number} --repo {owner}/{repo} --json body
```

Re-run the guard logic (Step 4) against the new body. If any rule still fails:
- Log which rule failed
- Repeat Step 5 with a corrected body
- Maximum 3 attempts — if still failing, report the residual errors and stop

### Step 7 — Report

Output a concise summary:

```
PR #{pr_number}: pipeline guard pre-check
  Issue link   : ✓  (Closes #{issue_number})
  Specify      : ✓  checked
  Research     : ✓  checked  |  ✓  skip-speckit: research — no library or pattern unknowns
  Plan         : ✓  checked  |  ✓  skip-speckit: plan — ...
  Implement    : ✓  checked
  Test (UAT)   : ✓  checked  |  ✓  skip-speckit: test — ...
  E2E          : ✓  checked  |  ✓  skip-speckit: e2e — ...
  Retro        : ✓  checked  |  ✓  skip-speckit: retro — ...

All rules pass — pipeline guard is green.
```

If changes were made, also log what was rewritten.

---

## Invocation from speckit-implement

`speckit-implement` MUST invoke this skill **immediately after creating the draft PR**,
before running extension hooks and before marking the PR ready.

Insert after `gh pr create ... --draft`:

```
Invoke speckit-pr-description with pipelineContext (or pr_number if no context).
Wait for confirmation that all guard rules pass before calling `gh pr ready`.
```

---

## Standalone Invocation

Users can invoke this skill at any time to fix a red pipeline guard:

```
/speckit-pr-description #42
```

Or without an argument when on the feature branch:

```
/speckit-pr-description
```
