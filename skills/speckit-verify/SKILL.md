---
name: speckit-verify
user-invocable: true
model: Claude Sonnet 4.6 (copilot)
tools: ['search', 'codebase', 'editFiles', 'runCommands', 'githubRepo']
description: >-
  Verify that specs, plans, or implementations comply with the project constitution
  and audit repository hygiene. Run with `--scope pr` (default) for the current PR
  or `--scope repo` for a wider audit (open issues missing spec markers, PRs missing
  Closes/checklist, branches not following the `<issue>-` convention). Use when the
  user says "verify", "check compliance", "audit speckit", "doctor", "validate
  against constitution", or when invoked automatically by other speckit pipeline
  skills as a quality gate.
---

## Next Steps

After verification completes:
- **PASS (constitution + pipeline green)**: "Verification passed. The PR is ready for merge."
- **Constitution PASS, pipeline issues**: "Constitution compliant, but CI has issues. Check the failing checks."
- **FAIL**: "Fix the violations listed above, then re-run `speckit-verify`."

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).
The input should indicate what to verify: a spec (GitHub Issue), plan, or implementation.

## Pre-Execution Checks

**Check for extension hooks (before verify)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_verify`.

## PipelineContext Checks

When a `PipelineContext` is available, `--scope pr` SHOULD additionally:

- **`contextBudget.maxSourceLines` overrun**: warn (do NOT fail) if the cumulative line count of `contextBudget.loadedArtifacts` for any phase exceeds the budget. See [HANDOFF-SCHEMA.md § Context Budget](../../references/HANDOFF-SCHEMA.md#context-budget).
- **`phaseVerdicts` consistency**: fail when any phase reports `"verdict": "blocked"` and the PR is marked ready-for-merge. Warn when a phase listed in the PR checklist has no entry in `phaseVerdicts`.
- **`/memories/repo/` entries written by this PR**: spot-check that each new entry has all five required fields (`subject`, `fact`, `citations`, `reason`, `category`). Fail otherwise.
- **Marker Block Size Limit**: check for oversized marker blocks using `.github/skills/speckit/scripts/verify-marker-budget.ps1`. Warn or fail if any `<!-- speckit-{phase}:start -->` block (e.g. in issue bodies or comments) exceeds the 500 line budget.

## Goal

Check that the current work product (spec, plan, or code) adheres to every MUST and
NON-NEGOTIABLE rule in the project constitution. Report violations, warnings, and a
pass/fail result.

## Scope Argument

`speckit-verify` accepts a `--scope` argument:

| Scope | Default | What it checks |
|-------|---------|----------------|
| `--scope pr` | yes | Constitution compliance for the current PR + CI pipeline status (Steps 1–7 below) |
| `--scope repo` | no  | Repository-wide hygiene audit (open issues missing spec markers, PRs missing `Closes #N`, PRs with unjustified unchecked phases, branches not following `<issue>-` convention) |

If `--scope` is not provided, default to `--scope pr`. If the user says "doctor" or
"audit speckit", treat that as `--scope repo`.

### Repo-Scope Audit (only when `--scope repo`)

When invoked with `--scope repo`, run the following audit instead of Steps 1–7:

1. **Detect the repo**: `gh repo view --json owner,name`.
2. **Audit open issues**:
   ```bash
   gh issue list --repo {owner}/{repo} --state open --limit 100 --json number,title,body,labels
   ```
   Flag issues whose body does NOT contain `<!-- speckit-spec:start -->`.
3. **Audit open PRs**:
   ```bash
   gh pr list --repo {owner}/{repo} --state open --limit 100 --json number,title,body,headRefName
   ```
   For each PR:
   - Check the body for `Closes #N` / `Fixes #N` / `Resolves #N` (case-insensitive).
   - Check each Speckit phase line is `- [x] **{Phase}**` OR has a matching
     `skip-speckit: {phase} — <reason>` line.
   - Check the branch name (`headRefName`) starts with `<issue-number>-`.
4. **Audit recent branches**:
   ```bash
   git for-each-ref --sort=-committerdate --count=20 --format='%(refname:short)' refs/remotes/origin/
   ```
   Flag any non-`main`/`master` branch that does not start with a digit followed by `-`.
5. **Produce the audit report** as a markdown table grouped by category (issues missing
   markers, PRs missing `Closes`, PRs with unjustified unchecked phases, branches not
   matching the convention).
6. **Exit code**: print the summary, then exit 1 if any rule was violated. Suitable for
   running in CI as a scheduled job.

The audit is **read-only** — it never opens issues, comments on PRs, or renames branches.

## Outline (PR scope)

### Step 1: Extract Constitution Rules

Run the extraction script to get structured rules:

```powershell
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "."
```

Parse the JSON output. If `exists` is `false`, report: "No constitution found. Run speckit-constitution first." and stop.

### Step 2: Determine Verification Target

Based on user input and context, determine what to verify:

| Signal | Target | What to Check |
|--------|--------|---------------|
| GitHub Issue number provided | **Spec** | Issue body content against constitution rules |
| Plan exists in issue body | **Plan** | Design notes, task list, ADRs against constitution rules |
| Branch has uncommitted/committed code changes | **Implementation** | Code changes, commit messages, test coverage against constitution rules |
| No specific target | **All available** | Check whatever artifacts exist |

### Step 3: Check Each Rule

For each extracted rule, evaluate whether the target artifact complies:

#### For NON-NEGOTIABLE rules:
- These are blockers. Any violation means **FAIL**.
- Check strictly — no partial credit.

#### For MUST rules:
- These are strong requirements. Violations are **errors**.
- Check against the specific artifact type.

#### For SHOULD rules:
- These are recommendations. Violations are **warnings**.
- Report but do not fail.

### Step 4: Check Common Constitution Patterns

Beyond extracted text rules, verify these common constitution-enforced patterns:

1. **Testing requirements** — If constitution mentions TDD/tests, verify tests exist or are planned
2. **Commit message format** — If constitution requires conventional commits, validate commit messages
3. **Code review requirements** — If constitution mandates reviews, check PR exists
4. **Documentation requirements** — If constitution requires docs, verify living docs are updated
5. **Naming conventions** — If constitution specifies naming patterns, verify branch/file names

### Step 5: Generate Compliance Report

```markdown
## Constitution Compliance Report

**Target**: {spec/plan/implementation} for #{issue-number}
**Constitution Version**: {version from docs/constitution.md}
**Date**: {today}

### Result: {PASS / FAIL}

### NON-NEGOTIABLE ({count})
| Rule | Principle | Status | Detail |
|------|-----------|--------|--------|
| {rule text} | {principle} | PASS/FAIL | {explanation} |

### MUST ({count})
| Rule | Principle | Status | Detail |
|------|-----------|--------|--------|
| {rule text} | {principle} | PASS/FAIL | {explanation} |

### SHOULD ({count})
| Rule | Principle | Status | Detail |
|------|-----------|--------|--------|
| {rule text} | {principle} | PASS/WARN | {explanation} |

### Summary
- **Non-negotiable**: {passed}/{total} passed
- **Must**: {passed}/{total} passed
- **Should**: {passed}/{total} passed (warnings only)
- **Overall**: {PASS/FAIL}

### Violations to Fix
1. {violation with suggested fix}
2. ...
```

### Step 6: Check Pipeline Status

After constitution compliance passes, check the CI pipeline directly:

```bash
gh pr checks {pr_number} --repo {owner}/{repo}
```

Report `green`, `red`, or `pending`. Include any failing check names in the final report.

### Step 7: Report Result

- If **PASS** (constitution + pipeline green): Report the compliance summary. Suggest the PR is ready for merge.
- If **constitution PASS but pipeline FAIL/PENDING**: Report constitution compliance passes but pipeline has issues. List failing/pending checks.
- If **constitution FAIL**: List all violations with suggested fixes. Do not allow proceeding until violations are resolved. Ask the user to fix the violations and re-run verification.

**Check for extension hooks (after verify)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_verify`.

## Gotchas

- A rule containing both MUST and SHOULD should be classified by the stronger severity (MUST).
- Empty constitutions (template placeholders still present) should be treated as "no constitution" — flag this to the user.
- If the constitution references external standards (e.g., "MUST follow OWASP Top 10"), the verifier checks for evidence of compliance (security headers, input validation), not exhaustive audit.
- Constitution version changes between spec and implementation should be flagged — the work may have started under different rules.
