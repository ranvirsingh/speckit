---
name: speckit-test
user-invocable: true
description: >-
  User acceptance testing against the spec. Verifies that the implementation satisfies every
  acceptance scenario, functional requirement, and success criterion defined in the GitHub Issue.
  Use this skill after implementation is complete and before retrospective — it acts as a UAT gate.
  Triggers on requests like "test against the spec", "verify acceptance criteria", "run UAT",
  or "does the implementation match the spec?"
---

## Next Steps (AUTO-CONTINUE)

After all acceptance scenarios pass, **automatically proceed** — do NOT stop to ask or suggest:
1. Determine if e2e is applicable (project has UI or testable endpoints).
2. If e2e is applicable: invoke `speckit-e2e #{issue-number}` immediately.
3. If e2e is NOT applicable: skip e2e and invoke `speckit-retro #{issue-number}` immediately.

If scenarios fail, **automatically proceed** back to `speckit-implement #{issue-number}` to fix the failing scenarios, then re-run `speckit-test`.

> **Skill resolution**: If a skill is not in your available skills list, use `read_file` to load its SKILL.md directly from `<speckit-root>/skills/{skill-name}/SKILL.md` (or `.github/skills/{skill-name}/SKILL.md`). Never skip a pipeline step because a skill appears unavailable.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

### Load Living Context

Use the `runSubagent` tool with `agentName: "speckit-living-docs-loader"` and provide:
- **Docs to load**: `docs/constitution.md`
- **Work context**: The issue title and UAT verification intent

Use the returned summary for constitution principles. Do not read these files directly.

**Check for extension hooks (before test)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_test`.

## GitHub Issue Gate (MANDATORY)

This skill **requires a GitHub issue number** as input.

1. Parse `$ARGUMENTS` for a GitHub issue reference (number or `#number`).
2. If no issue number is found:
   - **STOP**. Do not proceed.
   - Display: `⛔ speckit-test requires a GitHub issue number. Use: /speckit-test #42`
   - Exit.
3. Validate the issue exists: `gh issue view {number} --repo {owner}/{repo} --json number,title,state,labels,body`
4. If the issue does not exist: **STOP** and report.

---

## Outline

### Step 1 — Extract Testable Criteria from the Spec

Read the GitHub Issue body and extract three categories of testable items:

1. **Acceptance Scenarios** — Every Given/When/Then block under `## User Scenarios & Testing`
2. **Functional Requirements** — Every FR-XXX entry under `## Requirements`
3. **Success Criteria** — Every criterion under `## Success Criteria`
4. **Edge Cases** — Every edge case under `### Edge Cases`

For each item, record:
- **ID**: e.g., `US1-SC1` (User Story 1, Scenario 1), `FR-001`, `SC-001`, `EC-001`
- **Description**: The full criterion text
- **Category**: `acceptance` | `requirement` | `success-criterion` | `edge-case`

If the spec has no testable items, **STOP** and report: "No acceptance scenarios or requirements found in the spec. Run speckit-specify first."

### Step 2 — Determine Verification Strategy per Criterion

For each extracted item, determine the appropriate verification approach:

| Type | Verification Method |
|------|-------------------|
| **Given/When/Then scenarios** | Trace through the code path: locate the entry point, follow the logic, verify the expected outcome is produced |
| **Functional requirements** | Confirm the capability exists in the codebase — find the implementation and verify it matches the requirement |
| **Success criteria** | Check measurable outcomes — test coverage, performance, accessibility, or whatever the criterion specifies |
| **Edge cases** | Verify the described boundary condition is handled — find guard clauses, error handlers, or validation logic |

### Step 3 — Execute Verification

For each testable item:

1. **Locate the relevant code** using the codebase-scanner subagent or direct search
2. **Trace the scenario** through the implementation:
   - For Given/When/Then: Follow the exact flow described — initial state setup, action trigger, outcome check
   - For FRs: Confirm the capability is implemented end-to-end
   - For success criteria: Verify the measurable target is met
3. **Run existing tests** that cover this scenario (if any):
   ```bash
   # Run the project's test suite
   # Detect test runner from package.json, Makefile, etc.
   ```
4. **Record the result**: `pass`, `fail`, or `partial` with evidence

### Step 4 — Constitution Compliance

Extract constitution rules and verify the implementation as a whole:

```powershell
powershell -ExecutionPolicy Bypass -File <speckit-root>/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "<workspace-root>"
```

Check each NON-NEGOTIABLE and MUST rule against the implementation. Record any violations alongside the UAT results.

### Step 5 — Generate UAT Report

Produce a structured report in this format:

```markdown
## UAT Report — #{issue-number}: {title}

**Date**: {date}
**Branch**: {branch}
**Verdict**: PASS | FAIL | PARTIAL

### Acceptance Scenarios

| ID | Description | Result | Evidence |
|----|------------|--------|----------|
| US1-SC1 | Given X, When Y, Then Z | PASS | {file:line or test name} |
| US1-SC2 | Given A, When B, Then C | FAIL | {what's missing or wrong} |

### Functional Requirements

| ID | Requirement | Result | Evidence |
|----|------------|--------|----------|
| FR-001 | System MUST ... | PASS | {implementation location} |

### Success Criteria

| ID | Criterion | Result | Evidence |
|----|----------|--------|----------|
| SC-001 | ... | PASS | {metric or proof} |

### Edge Cases

| ID | Case | Result | Evidence |
|----|------|--------|----------|
| EC-001 | ... | PASS | {guard clause or handler location} |

### Constitution Compliance

| Severity | Rule | Result |
|----------|------|--------|
| NON-NEGOTIABLE | ... | PASS |
| MUST | ... | PASS |

### Summary

- Total: {count}
- Passed: {count}
- Failed: {count}
- Partial: {count}
```

### Step 6 — Verdict and Next Steps

- **All PASS**: Report success and **automatically proceed** to `speckit-e2e #{issue-number}` to generate e2e test artifacts. If e2e is not applicable, **automatically proceed** to `speckit-retro #{issue-number}` instead.
- **Any FAIL on NON-NEGOTIABLE or acceptance scenarios**: Block — **automatically proceed** to `speckit-implement #{issue-number}` to fix, then re-test
- **Only SHOULD warnings or partial edge cases**: Warn but allow proceeding — note as TODOs for triage and **automatically proceed** to the next step

**Check for extension hooks (after test)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_test`.

## Gotchas

- **Do not write new tests during UAT** — this skill verifies existing implementation, it does not generate code. If tests are missing, note it in the report as a gap.
- **Acceptance scenarios are the primary gate** — functional requirements and success criteria are secondary. A failing acceptance scenario always blocks.
- **Spec is the source of truth** — if the implementation does something the spec didn't ask for, that's neither a pass nor a fail. Only spec-defined criteria are tested.
- **Run real tests when available** — prefer running the actual test suite over code-tracing when tests exist. Code tracing is the fallback when no tests cover a scenario.
