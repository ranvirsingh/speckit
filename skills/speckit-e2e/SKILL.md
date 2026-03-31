---
name: speckit-e2e
user-invocable: true
description: >-
  Generate end-to-end test artifacts that prove the implementation works and become part of the
  CI pipeline. For UI projects, creates Playwright tests that exercise each acceptance scenario
  with video recording. For non-UI projects (APIs, CLIs, libraries), generates equivalent
  proof-of-work test artifacts. Attaches results to the PR description. Use after UAT passes
  and before retrospective. Triggers on requests like "write e2e tests", "create proof of work",
  "generate e2e for PR", or "show the feature working".
---

## Next Steps

After e2e test artifacts are generated and attached to the PR, suggest:
- **speckit-retro** — "E2E tests captured. Run the retrospective to update living docs and triage TODOs."

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

### Load Living Context

Use the `runSubagent` tool with `agentName: "speckit-living-docs-loader"` and provide:
- **Docs to load**: `docs/constitution.md`
- **Work context**: The issue title and e2e test generation intent

Use the returned summary for constitution principles. Do not read these files directly.

**Check for extension hooks (before e2e)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_e2e`.

## GitHub Issue Gate (MANDATORY)

This skill **requires a GitHub issue number** as input.

> **Prerequisite**: Ensure `speckit-test` has been run and passed before generating e2e tests. If the issue has no evidence of UAT completion (no UAT report comment or passing test results), warn the user: "UAT has not been verified. Run `speckit-test #{issue-number}` first, or confirm you want to proceed without UAT."

1. Parse `$ARGUMENTS` for a GitHub issue reference (number or `#number`).
2. If no issue number is found:
   - **STOP**. Do not proceed.
   - Display: `speckit-e2e requires a GitHub issue number. Use: /speckit-e2e #42`
   - Exit.
3. Read the issue: `gh issue view {number} --repo {owner}/{repo} --json number,title,state,labels,body`
4. If the issue does not exist: **STOP** and report.

---

## Outline

### Step 1 — Detect Project Type

Determine the project type by scanning the workspace:

| Signal | Project Type |
|--------|-------------|
| `package.json` with React/Vue/Angular/Svelte/Next/Nuxt dependency | **Web UI** |
| `*.html` entry points with JS/CSS references | **Web UI** |
| `package.json` with Express/Fastify/Hono/Koa or `routes/` directory | **API** |
| `Dockerfile` with `EXPOSE` + API framework | **API** |
| `bin/` directory or CLI entry point in `package.json` | **CLI** |
| Library with `exports` in `package.json`, no binary or server | **Library** |
| `*.tf`, `*.bicep`, `cdk.json`, `serverless.yml` | **Infrastructure** |
| Multiple signals present | Prefer UI > API > CLI > Library |

Record the detected type. If uncertain, ask the user.

### Step 2 — Extract Acceptance Scenarios

Read the spec from the GitHub Issue body and extract the acceptance scenarios (Given/When/Then blocks under `## User Scenarios & Testing`). These become the e2e test script — each scenario is a test case.

### Step 3 — Generate E2E Test Artifact (by project type)

---

#### Web UI Projects — Playwright E2E Tests (via subagent)

For UI projects, use the `runSubagent` tool with `agentName: "speckit-e2e-recorder"` and provide:

- **issueNumber**: The GitHub Issue number
- **title**: The issue title
- **scenarios**: The extracted acceptance scenarios (Given/When/Then)
- **baseUrl**: The application URL (detect from dev server config or ask the user)
- **screenshotDir**: `e2e/screenshots/e2e-{issue-number}/`

The subagent will:
1. Ensure Playwright is installed (install if missing)
2. Create `e2e/e2e-{issue-number}.spec.ts` with one test per scenario
3. Configure video recording
4. Run the tests and capture screenshots
5. Return test results, screenshot paths, and video location

If the subagent reports the application server is not running, start it first using the detected dev command from `package.json`.

---

#### API Projects — Recorded HTTP Exchange

##### 3a. Start the Server (if not running)

Detect the start command from `package.json` scripts (`start`, `dev`, `serve`) or `Makefile`. Start it in background.

##### 3b. Create Request Script

Create `e2e/e2e-{issue-number}.http` with one request per acceptance scenario:

```http
### US1-SC1: {scenario description}
# Given: {initial state}
# When: {action}
POST http://localhost:{port}/{endpoint}
Content-Type: application/json

{request body}

### Expected: {expected outcome}
```

##### 3c. Execute and Record

Run each request and capture the response:

```bash
# Execute each scenario and capture output
curl -v -X POST http://localhost:{port}/{endpoint} \
  -H "Content-Type: application/json" \
  -d '{body}' \
  2>&1 | tee e2e/e2e-{issue-number}-US1-SC1.txt
```

##### 3d. Generate Summary

Create `e2e/e2e-{issue-number}-results.md` with request/response pairs formatted as a readable exchange log.

---

#### CLI Projects — Terminal Session Recording

##### 3a. Create E2E Script

Create `e2e/e2e-{issue-number}.ps1` (or `.sh`) that executes each acceptance scenario:

```powershell
Write-Host "=== US1-SC1: {scenario description} ==="
Write-Host "Given: {initial state}"
# Setup initial state
Write-Host "When: {action}"
# Execute CLI command
$result = & {cli-command} {args}
Write-Host "Then: {expected outcome}"
Write-Host $result
Write-Host ""
```

##### 3b. Execute and Capture

Run the script and capture output:

```bash
powershell -ExecutionPolicy Bypass -File e2e/e2e-{issue-number}.ps1 | Tee-Object -FilePath e2e/e2e-{issue-number}-output.txt
```

---

#### Library Projects — Executable Code Sample

##### 3a. Create Example File

Create `e2e/e2e-{issue-number}.ts` (or `.js`, `.py`) that imports the library and demonstrates each scenario:

```typescript
import { feature } from '../src';

// US1-SC1: {scenario description}
console.log('=== US1-SC1: {scenario description} ===');
// Given: {initial state}
const input = { /* ... */ };
// When: {action}
const result = feature(input);
// Then: {expected outcome}
console.log('Result:', result);
console.assert(/* condition */, 'Expected: {outcome}');
console.log('PASS');
```

##### 3b. Execute and Capture

```bash
npx tsx e2e/e2e-{issue-number}.ts 2>&1 | tee e2e/e2e-{issue-number}-output.txt
```

---

#### Infrastructure Projects — Plan/Diff Output

##### 3a. Generate Plan

```bash
# Terraform
terraform plan -out=e2e/e2e-{issue-number}.plan
terraform show -no-color e2e/e2e-{issue-number}.plan > e2e/e2e-{issue-number}-plan.txt

# CDK
cdk diff > e2e/e2e-{issue-number}-diff.txt 2>&1
```

##### 3b. Capture Key Changes

Extract the resource changes, additions, and deletions into a readable summary.

---

### Step 4 — Attach E2E Results to PR

1. Find the PR for the current branch:
   ```bash
   gh pr view --json number,url --jq '.number'
   ```

2. Format the e2e section for the PR body:

   **For UI projects** (with video):
   ```markdown
   ## E2E Tests

   ### Acceptance Scenario Tests

   Playwright test: `e2e/e2e-{issue-number}.spec.ts`

   | Scenario | Screenshot |
   |----------|----------|
   | US1-SC1: {description} | ![screenshot](e2e/screenshots/e2e-{issue-number}/sc1.png) |

   Video recording available in `test-results/` after running:
   ```
   npx playwright test e2e/e2e-{issue-number}.spec.ts
   ```
   ```

   **For non-UI projects**:
   ```markdown
   ## E2E Tests

   ### Proof of Work

   E2E script: `e2e/e2e-{issue-number}.{ext}`

   <details>
   <summary>Execution output</summary>

   ```
   {captured output}
   ```

   </details>
   ```

3. Append to the PR body:
   ```bash
   # Read current PR body
   gh pr view {pr-number} --json body --jq '.body' > /tmp/pr-body.md
   # Append e2e section
   # Update PR
   gh pr edit {pr-number} --body "{updated body with e2e section}"
   ```

### Step 5 — Commit E2E Artifacts

Stage and commit only the e2e files:

```bash
git add e2e/e2e-{issue-number}*
git commit -m "test(e2e): add e2e test artifacts for #{issue-number}"
git push
```

Do not commit video files (`.webm`, `.mp4`) — they belong in test-results and are regenerated on demand. Commit the test files, scripts, HTTP files, and text outputs.

**Check for extension hooks (after e2e)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_e2e`.

## Gotchas

- **Do not overwrite existing Playwright config** — only add video/trace settings if missing.
- **Do not commit large binary files** — videos stay in `test-results/`, only test scripts and text outputs get committed.
- **Server startup for API demos** — always wait for the server to be ready before sending requests. Check for a health endpoint or port availability.
- **E2E tests are NOT unit tests** — they verify the feature working end-to-end from the user's perspective. Keep them high-level and scenario-driven.
- **Screenshots over videos for PR** — GitHub PR descriptions can render images inline but not videos. Prefer screenshots for the PR body; mention how to run the video locally.
