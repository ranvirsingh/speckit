---
name: speckit-e2e
description: >-
  Pipeline skill that generates and runs end-to-end test artifacts.
  Detects the project type (web-ui, api, cli, library, infrastructure) and
  generates appropriate e2e tests directly. For UI projects generates Playwright
  browser tests; for API projects generates Playwright request-context tests;
  for CLI/library/infra projects generates framework-native tests.
  Receives PipelineContext from the router or a bare issue number for
  standalone invocation. Returns e2e results and artifact paths.
user-invocable: true
---

# Speckit E2E Skill

This is the **speckit-e2e** skill — end-to-end test generation and execution.
When invoked from the pipeline router, you receive a `PipelineContext`.
When invoked standalone, you accept a bare issue number.

## Scope Boundaries (MANDATORY)

You are an **e2e test generation and execution** skill. You create test artifacts and run them.

**You MUST NOT:**
- Modify application source code to make tests pass
- Fix bugs discovered during testing
- Invoke `speckit-implement` or any other pipeline phase directly
- Continue the pipeline beyond returning your structured result

**You MUST:**
- Return your structured JSON result to the router
- Report all failures clearly so the router can loop back to implement
- Align test artifacts to the project's tech stack — tests must be CI/CD runnable

## Tech-Stack Alignment Principle

All e2e test artifacts MUST align with the project's existing tech stack and be runnable in CI/CD:
- **JS/TS projects**: Use Playwright (both browser and API tests via `request` context)
- **Python projects**: Use pytest with appropriate HTTP/browser libraries
- **Go projects**: Use Go test with appropriate libraries
- **Never** generate raw shell scripts (`.ps1`, `.sh`, `.bat`) as test artifacts — these are not CI/CD friendly and don't integrate with test reporters

## Input

You will receive either:
- **pipelineContext**: A full `PipelineContext` JSON object (see [HANDOFF-SCHEMA.md](../../references/HANDOFF-SCHEMA.md)) — preferred
- **issueNumber**: A bare GitHub issue number (standalone / backward-compat mode)

When `pipelineContext` is provided, extract:
- `issueNumber`, `owner`, `repo`, `branch` from the context
- `implementation.prNumber`, `implementation.prUrl` for PR attachment
- `implementation.baseUrl` for the dev-server URL
- `implementation.authToken` for authenticated endpoints (optional)
- `uat.verdict` to confirm UAT passed before proceeding

**Writes** (PipelineContext fields this skill SHOULD set on completion):
- `phaseVerdicts.e2e`: `{ "verdict": "pass"|"fail"|"blocked", "notes": "<short reason>" }`.
- `artifactIndex.e2eEvidenceDir`: workspace-relative directory containing the e2e evidence (gifs/screenshots/logs) produced this run.
- `e2e` block (existing): `projectType`, `passed`, `artifacts`. The `phaseVerdicts.e2e` value MUST agree with `e2e.passed` (`true` → `pass`, `false` → `fail`).

### Backward Compatibility (no PipelineContext)

If only an issue number is provided:
1. Derive `owner`/`repo` from `git config --get remote.origin.url`
2. Read the issue: `gh issue view {number} --repo {owner}/{repo} --json number,title,state,labels,body`
3. Detect branch: `git branch --show-current`
4. Find PR: `gh pr list --head {branch} --json number,url`

## Execution

### Step 1 — Detect Project Type

Scan the workspace to determine the project type:

| Signal | Project Type |
|--------|-------------|
| `package.json` with React/Vue/Angular/Svelte/Next/Nuxt dependency | **web-ui** |
| `*.html` entry points with JS/CSS references | **web-ui** |
| `package.json` with Express/Fastify/Hono/Koa or `routes/` directory | **api** |
| `Dockerfile` with `EXPOSE` + API framework | **api** |
| `bin/` directory or CLI entry point in `package.json` | **cli** |
| Library with `exports` in `package.json`, no binary or server | **library** |
| `*.tf`, `*.bicep`, `cdk.json`, `serverless.yml` | **infrastructure** |
| Multiple signals present | Prefer web-ui > api > cli > library |

### Step 2 — Extract Acceptance Scenarios

Read the spec from the GitHub Issue body and extract the acceptance scenarios (Given/When/Then blocks under `## User Scenarios & Testing`). These become the e2e test cases.

### Step 3 — Generate Tests by Project Type

#### Web UI Projects → Generate Playwright Browser Tests

Generate a Playwright test file at `e2e/e2e-{issueNumber}.spec.ts` with:
- One test per acceptance scenario
- Viewport capped at `1280x720`
- Video recording enabled (`video: 'on'`)
- Screenshot capture at key states

Ensure Playwright is installed:
```bash
npx playwright --version 2>&1
# If missing:
npm install -D @playwright/test && npx playwright install chromium
```

Run with:
```bash
npx playwright test e2e/e2e-{issueNumber}.spec.ts --project=chromium
```

#### API Projects → Generate Playwright API Tests

Generate a Playwright test file at `e2e/e2e-{issueNumber}.spec.ts` using Playwright's `request` context — NOT curl or shell scripts. This ensures API tests are first-class CI/CD citizens sharing the same test runner as browser tests.

#### CLI Projects → Generate Framework-Native Tests

Detect the project's test framework and generate tests accordingly:

| Signal | Test Approach |
|--------|--------------|
| `package.json` with `vitest`/`jest` | Generate a `.spec.ts` test using `child_process.execSync` |
| `pytest` / Python project | Generate a pytest test using `subprocess.run` |
| `go.mod` / Go project | Generate a Go test using `os/exec` |
| No detectable test framework | Generate a Playwright test that shells out via `child_process` |

```typescript
import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';

test.describe('#{issueNumber}: {title}', () => {
  test('US1-SC1: {scenario description}', () => {
    // Given: {initial state}
    // When: {action}
    const result = execSync('{cli-command} {args}', { encoding: 'utf-8' });
    // Then: {expected outcome}
    expect(result).toContain('{expected}');
  });
});
```

#### Library Projects → Generate Framework-Native Tests

Detect the project's test framework and generate tests that import the library and verify each scenario with assertions.

| Signal | Test Approach |
|--------|--------------|
| `package.json` with `vitest`/`jest`/`playwright` | Generate a `.spec.ts` test using the detected runner |
| `pytest` / Python project | Generate a pytest test |
| `go.mod` / Go project | Generate a Go test |
| Default (JS/TS) | Generate a Playwright test |

#### Infrastructure Projects → Generate Directly

Run `terraform plan` / `cdk diff` and capture the output to `e2e/e2e-{issueNumber}-plan.txt`.

### Step 4 — Handle Failures

1. **If tests passed**: proceed to Step 5.
2. **If any tests failed**: return `passed: false` with failing scenario details. The router will loop back to `speckit-implement` (subject to circuit breaker).

### Step 5 — Attach E2E Results to PR

GIF/screenshot artifacts **must NOT be committed to the feature branch** — they bloat Git history. Instead, push them to a dedicated orphan branch and reference via raw GitHub URLs.

1. Find the PR and derive repo info:
   ```bash
   pr_number=$(gh pr view --json number --jq '.number')
   repo_slug=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
   ```

2. Push e2e assets to the orphan `e2e-assets` branch:
   ```bash
   current_branch=$(git branch --show-current)
   git checkout --orphan e2e-assets 2>/dev/null || git checkout e2e-assets
   git rm -rf --cached . > /dev/null 2>&1
   git add e2e/.tmp/
   git commit -m "e2e: assets for PR #${pr_number}" --allow-empty
   git push origin e2e-assets --force
   git checkout "$current_branch"
   ```

3. Format the e2e evidence section for the PR body using raw GitHub URLs:

   **For UI projects** (GIF recordings):
   ````markdown
   ## E2E Evidence

   | Scenario | Result | Recording |
   |----------|--------|-----------|
   | US1-SC1: {scenario title} | :white_check_mark: Pass | ![US1-SC1](https://raw.githubusercontent.com/{repo_slug}/e2e-assets/e2e/.tmp/gifs/e2e-{issueNumber}/sc1.gif) |
   ````

   **For non-UI projects** (API / CLI / library):
   ````markdown
   ## E2E Evidence

   | Scenario | Result |
   |----------|--------|
   | US1-SC1: {scenario title} | :white_check_mark: Pass |

   <details><summary>Execution output</summary>

   ```
   {paste test runner output here}
   ```

   </details>
   ````

   **Rules for GIF embedding:**
   - Use raw GitHub URLs pointing to the `e2e-assets` branch
   - One GIF per scenario — name them `sc1.gif`, `sc2.gif`, etc.
   - For failing scenarios, use `:x: Fail` and still include the GIF
   - If a GIF exceeds 5 MB after ffmpeg conversion, use a screenshot instead

4. Update PR body — read the existing body, append the evidence section, then write back:
   ```bash
   existing_body=$(gh pr view ${pr_number} --json body --jq '.body')
   gh pr edit ${pr_number} --body "${existing_body}\n\n${evidence_section}"
   ```

5. Commit the test **source files** only (no binary artifacts) to the feature branch:
   ```bash
   git add e2e/e2e-{issueNumber}.* --ignore-missing
   git commit -m "test(e2e): add e2e test for #{issueNumber}"
   git push
   ```

## Return Value

Return a structured result for the router:

```jsonc
{
  "passed": true,
  "projectType": "web-ui",          // "web-ui" | "api" | "cli" | "library" | "infrastructure"
  "artifacts": [                     // Paths to committed e2e test source files
    "e2e/e2e-42.spec.ts"
  ],
  "assetUrls": [                     // Raw GitHub URLs for GIF/screenshot assets (on e2e-assets branch)
    "https://raw.githubusercontent.com/{owner}/{repo}/e2e-assets/e2e/.tmp/gifs/e2e-42/sc1.gif"
  ],
  "scenarioResults": [               // Per-scenario results
    { "id": "US1-SC1", "passed": true },
    { "id": "US1-SC2", "passed": true }
  ],
  "failingScenarios": []             // IDs of failing scenarios (for implement to fix)
}
```

## Rules

- Do NOT overwrite existing Playwright config — only add video/trace settings if missing
- Do NOT commit large binary files — raw videos stay in `test-results/`, only GIFs, test scripts, and text outputs get committed
- GIFs are capped at ~5 MB via ffmpeg settings
- Server startup for API/UI demos — always wait for the server to be ready before sending requests
- E2E tests are NOT unit tests — they verify the feature working end-to-end from the user's perspective
- **Autonomous** — never prompt the user. If blocked, include it in `## Unresolved Questions`
