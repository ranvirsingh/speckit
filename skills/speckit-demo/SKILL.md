---
name: speckit-demo
description: >-
  Generate a demo artifact that proves the implementation works. For UI projects, creates a
  Playwright test that records a video walkthrough of each acceptance scenario.
  For non-UI projects (APIs, CLIs, libraries), generates equivalent proof-of-work artifacts.
  Attaches the result to the PR description. Use after UAT passes and before retrospective.
  Triggers on requests like "record a demo", "create proof of work", "generate demo for PR",
  or "show the feature working".
---

## Next Steps

After demo artifacts are generated and attached to the PR, suggest:
- **speckit-retro** — "Demo captured. Run the retrospective to update living docs and triage TODOs."

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before demo)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_demo`.

## GitHub Issue Gate (MANDATORY)

This skill **requires a GitHub issue number** as input.

1. Parse `$ARGUMENTS` for a GitHub issue reference (number or `#number`).
2. If no issue number is found:
   - **STOP**. Do not proceed.
   - Display: `speckit-demo requires a GitHub issue number. Use: /speckit-demo #42`
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

Read the spec from the GitHub Issue body and extract the acceptance scenarios (Given/When/Then blocks under `## User Scenarios & Testing`). These become the demo script — each scenario is a scene in the demo.

### Step 3 — Generate Demo Artifact (by project type)

---

#### Web UI Projects — Playwright Video Recording

##### 3a. Ensure Playwright is Available

Check if Playwright is installed:

```powershell
npx playwright --version 2>&1
```

If not available, install it:

```bash
npm install -D @playwright/test
npx playwright install chromium
```

##### 3b. Create Playwright Test File

Create a test file at `e2e/demo-{issue-number}.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';

test.describe('Demo — #{issue-number}: {title}', () => {
  // One test per acceptance scenario
  test('US1-SC1: {scenario description}', async ({ page }) => {
    // Given: {initial state}
    await page.goto('{url}');
    // When: {action}
    await page.{action};
    // Then: {expected outcome}
    await expect(page.{locator}).{assertion};
  });

  // ... additional scenarios
});
```

##### 3c. Configure Video Recording

Create or update `playwright.config.ts` to enable video recording for this test only:

```typescript
// Add to projects or use:
use: {
  video: 'on',
  trace: 'on',
},
```

If a `playwright.config.ts` already exists, do **not** overwrite it. Instead, add video/trace settings only if they're not already present.

##### 3d. Run the Test with Recording

```bash
npx playwright test e2e/demo-{issue-number}.spec.ts --project=chromium
```

Collect the video file(s) from `test-results/` directory.

##### 3e. Capture Screenshots for PR

For each key state in each scenario, capture a screenshot. Store in `e2e/screenshots/demo-{issue-number}/`.

---

#### API Projects — Recorded HTTP Exchange

##### 3a. Start the Server (if not running)

Detect the start command from `package.json` scripts (`start`, `dev`, `serve`) or `Makefile`. Start it in background.

##### 3b. Create Request Script

Create `e2e/demo-{issue-number}.http` with one request per acceptance scenario:

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
  2>&1 | tee e2e/demo-{issue-number}-US1-SC1.txt
```

##### 3d. Generate Summary

Create `e2e/demo-{issue-number}-results.md` with request/response pairs formatted as a readable exchange log.

---

#### CLI Projects — Terminal Session Recording

##### 3a. Create Demo Script

Create `e2e/demo-{issue-number}.ps1` (or `.sh`) that executes each acceptance scenario:

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
powershell -ExecutionPolicy Bypass -File e2e/demo-{issue-number}.ps1 | Tee-Object -FilePath e2e/demo-{issue-number}-output.txt
```

---

#### Library Projects — Executable Code Sample

##### 3a. Create Example File

Create `e2e/demo-{issue-number}.ts` (or `.js`, `.py`) that imports the library and demonstrates each scenario:

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
npx tsx e2e/demo-{issue-number}.ts 2>&1 | tee e2e/demo-{issue-number}-output.txt
```

---

#### Infrastructure Projects — Plan/Diff Output

##### 3a. Generate Plan

```bash
# Terraform
terraform plan -out=e2e/demo-{issue-number}.plan
terraform show -no-color e2e/demo-{issue-number}.plan > e2e/demo-{issue-number}-plan.txt

# CDK
cdk diff > e2e/demo-{issue-number}-diff.txt 2>&1
```

##### 3b. Capture Key Changes

Extract the resource changes, additions, and deletions into a readable summary.

---

### Step 4 — Attach Demo to PR

1. Find the PR for the current branch:
   ```bash
   gh pr view --json number,url --jq '.number'
   ```

2. Format the demo section for the PR body:

   **For UI projects** (with video):
   ```markdown
   ## Demo

   ### Recorded Walkthrough

   Playwright test: `e2e/demo-{issue-number}.spec.ts`

   | Scenario | Screenshot |
   |----------|-----------|
   | US1-SC1: {description} | ![screenshot](e2e/screenshots/demo-{issue-number}/sc1.png) |

   Video recording available in `test-results/` after running:
   ```
   npx playwright test e2e/demo-{issue-number}.spec.ts
   ```
   ```

   **For non-UI projects**:
   ```markdown
   ## Demo

   ### Proof of Work

   Demo script: `e2e/demo-{issue-number}.{ext}`

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
   # Append demo section
   # Update PR
   gh pr edit {pr-number} --body "{updated body with demo section}"
   ```

### Step 5 — Commit Demo Artifacts

Stage and commit only the demo files:

```bash
git add e2e/demo-{issue-number}*
git commit -m "test(demo): add demo artifacts for #{issue-number}"
git push
```

Do not commit video files (`.webm`, `.mp4`) — they belong in test-results and are regenerated on demand. Commit the test files, scripts, HTTP files, and text outputs.

**Check for extension hooks (after demo)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_demo`.

## Gotchas

- **Do not overwrite existing Playwright config** — only add video/trace settings if missing.
- **Do not commit large binary files** — videos stay in `test-results/`, only test scripts and text outputs get committed.
- **Server startup for API demos** — always wait for the server to be ready before sending requests. Check for a health endpoint or port availability.
- **Demo tests are NOT unit tests** — they demonstrate the feature working end-to-end from the user's perspective. Keep them high-level and scenario-driven.
- **Screenshots over videos for PR** — GitHub PR descriptions can render images inline but not videos. Prefer screenshots for the PR body; mention how to run the video locally.
