---
name: speckit-verify
user-invocable: true
description: >-
  Verify that specs, plans, or implementations comply with the project constitution.
  Run this skill to check compliance before completing any pipeline step. Use when
  the user says "verify", "check compliance", "validate against constitution", or
  when invoked automatically by other speckit pipeline skills as a quality gate.
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

## Goal

Check that the current work product (spec, plan, or code) adheres to every MUST and
NON-NEGOTIABLE rule in the project constitution. Report violations, warnings, and a
pass/fail result.

## Outline

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

After constitution compliance passes, check whether the CI pipeline is green using the `runSubagent` tool with `agentName: "speckit-pipeline-checker"` and provide:
- **prNumber**: The PR number (if known from Step 2)

Include the pipeline status in the final report.

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
