---
name: speckit-test
description: >-
  Pipeline skill that runs user acceptance testing against the spec.
  Verifies that the implementation satisfies every acceptance scenario, functional requirement,
  and success criterion defined in the GitHub Issue. Receives PipelineContext from the router
  or a bare issue number for standalone invocation. Returns a structured UAT report.
user-invocable: true
---

# Speckit Test Skill

This is the **speckit-test** skill — verification-only UAT against the spec.
When invoked from the pipeline router, you receive a `PipelineContext`.
When invoked standalone, you accept a bare issue number.

## Scope Boundaries (MANDATORY — read before executing)

You are a **verification-only** skill. Your job is to READ code and REPORT findings.

**You MUST NOT:**
- Edit, fix, patch, or modify ANY source file, test file, or configuration file
- Write new tests, test helpers, or test fixtures
- Install packages, update dependencies, or modify `package.json`
- Create branches, commits, or PRs
- Invoke `speckit-implement`, `speckit-plan`, or any other pipeline skill
- Continue the pipeline beyond returning your structured UAT result
- "Helpfully" fix issues you discover — report them and STOP

**You MUST:**
- Return your structured JSON result to the router
- Include all failing scenarios with clear IDs so the router can pass them to implement
- STOP after returning your result — the router decides the next step

## Input

You will receive either:
- **pipelineContext**: A full `PipelineContext` JSON object (see [HANDOFF-SCHEMA.md](../../references/HANDOFF-SCHEMA.md)) — preferred
- **issueNumber**: A bare GitHub issue number (standalone / backward-compat mode)

When `pipelineContext` is provided, extract:
- `issueNumber`, `owner`, `repo`, `branch` from the context
- `livingContext.summary` for constitution principles (skip living-docs-loader invocation)
- `constitutionCompliant` — if `true`, skip the constitution compliance step (Step 4)
- `implementation.prNumber` for PR linkage

**Writes** (PipelineContext fields this skill SHOULD set on completion):
- `phaseVerdicts.test`: `{ "verdict": "pass"|"fail"|"blocked", "notes": "<short reason>" }`. Use `"blocked"` when an acceptance criterion is ambiguous or untestable rather than `"fail"`.
- `uat` block (existing): `verdict`, `passCount`, `failCount`, `report`. The `phaseVerdicts.test` value SHOULD agree with `uat.verdict` (`PASS` → `pass`, `FAIL` → `fail`, `PARTIAL` → `blocked`).

### Backward Compatibility (no PipelineContext)

If only an issue number is provided:
1. Derive `owner`/`repo` from `git config --get remote.origin.url`
2. Read the issue: `gh issue view {number} --repo {owner}/{repo} --json number,title,state,labels,body`
3. Read `docs/constitution.md` directly via `read_file` (or `#codebase` search) for constitution principles
4. Run the full constitution compliance check (Step 4)

## Execution

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

If the spec has no testable items, return an error report: "No acceptance scenarios or requirements found in the spec."

### Step 2 — Determine Verification Strategy per Criterion

| Type | Verification Method |
|------|-------------------|
| **Given/When/Then scenarios** | Trace through the code path: locate the entry point, follow the logic, verify the expected outcome is produced |
| **Functional requirements** | Confirm the capability exists in the codebase — find the implementation and verify it matches the requirement |
| **Success criteria** | Check measurable outcomes — test coverage, performance, accessibility, or whatever the criterion specifies |
| **Edge cases** | Verify the described boundary condition is handled — find guard clauses, error handlers, or validation logic |

### Step 3 — Execute Verification

For each testable item:

1. **Locate the relevant code** using search tools
2. **Trace the scenario** through the implementation:
   - For Given/When/Then: Follow the exact flow described — initial state setup, action trigger, outcome check
   - For FRs: Confirm the capability is implemented end-to-end
   - For success criteria: Verify the measurable target is met
3. **Run existing tests** that cover this scenario (if any):
   ```bash
   # Run the project's test suite — detect test runner from package.json, Makefile, etc.
   ```
4. **Record the result**: `pass`, `fail`, or `partial` with evidence

### Step 4 — Constitution Compliance (skip if `constitutionCompliant` is true in context)

Extract constitution rules and verify the implementation as a whole:

```pwsh
pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/extract-constitution-rules.ps1 -WorkspaceRoot "."
```

Check each NON-NEGOTIABLE and MUST rule against the implementation. Record any violations.

### Step 5 — Generate UAT Report

Produce a structured report:

```markdown
## UAT Report — #{issue-number}: {title}

**Date**: {date}
**Branch**: {branch}
**Verdict**: PASS | FAIL | PARTIAL

### Acceptance Scenarios

| ID | Description | Result | Evidence |
|----|------------|--------|----------|
| US1-SC1 | Given X, When Y, Then Z | PASS | {file:line or test name} |

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

### Summary

- Total: {count}
- Passed: {count}
- Failed: {count}
- Partial: {count}
```

## Return Value

Return a structured result for the router:

```jsonc
{
  "verdict": "PASS",        // "PASS" | "FAIL" | "PARTIAL"
  "passCount": 10,
  "failCount": 0,
  "partialCount": 0,
  "report": "...",           // The full markdown UAT report from Step 5
  "failingScenarios": [],    // Array of IDs that failed (for implement to fix)
  "constitutionViolations": [] // Array of violated rules (if any)
}
```

The router uses this to:
- **All PASS** → proceed to `speckit-e2e` (or stop here if e2e not applicable — `speckit-implement` already handles done-done living-doc updates)
- **Any FAIL on acceptance scenarios or NON-NEGOTIABLE rules** → loop back to `speckit-implement` (subject to circuit breaker)
- **Only SHOULD warnings or partial edge cases** → proceed with warnings noted as TODOs

## Rules

- **NEVER modify, fix, edit, or create ANY file** — not source code, not tests, not configs. You are read-only.
- Do NOT write new tests during UAT — this skill verifies existing implementation, not generate code
- Do NOT invoke the next pipeline phase — return your result and STOP. The router handles orchestration.
- Do NOT attempt to fix failing scenarios — report them with clear IDs in `failingScenarios` so implement can fix them
- Acceptance scenarios are the primary gate — functional requirements and success criteria are secondary
- Spec is the source of truth — if implementation does something the spec didn't ask for, that's neither pass nor fail
- Run existing tests when available — prefer running the actual test suite over code-tracing when tests exist
- **Autonomous** — never prompt the user. If blocked, include it in `## Unresolved Questions`
- **Return structured JSON** — your output MUST end with the structured result JSON. The router depends on parsing it.
