# Pipeline Context Handoff Schema

This document defines the `PipelineContext` JSON schema that flows between pipeline phases.
The context is built incrementally — each phase adds its fields and passes the enriched context downstream.

## Purpose

- **Eliminate re-discovery**: Downstream agents receive issue numbers, branch names, PR URLs, and living-doc summaries directly — no need to re-read issues or re-invoke the living-docs-loader.
- **Enable circuit breaker**: The `retryCount` per phase lets the router detect and stop ping-pong loops.
- **Single source of truth**: The context is the authoritative record of what happened in each phase of the current pipeline run.

## Schema

```jsonc
{
  // --- Identity (set by specify) ---
  "issueNumber": 42,
  "issueTitle": "[Feature] 012 — Add login endpoint",
  "workType": "feature",            // "feature" | "bug" | "chore"
  "specNumber": "012",
  "branch": "012-add-login",
  "owner": "acme",
  "repo": "webapp",

  // --- Project board (set by specify, from .speckit-project.json) ---
  "projectNumber": 17,              // GitHub Project number for Issue State tracking

  // --- Living context (set by specify, cached for downstream) ---
  "livingContext": {
    "summary": "Compressed summary from speckit-living-docs-loader...",
    "loadedAt": "2026-04-07T06:30:00Z"
  },

  // --- Constitution (set by specify) ---
  "constitutionCompliant": true,     // false → downstream phases should not proceed

  // --- Complexity signal (set by specify / nexus) ---
  "complexitySignal": "plan",       // "research" | "plan" | "implement"

  // --- Research findings (set by research, optional) ---
  "research": {
    "completedAt": "2026-04-07T07:00:00Z",
    "summary": "Key findings and recommendations..."
  },

  // --- Plan (set by plan, optional) ---
  "plan": {
    "completedAt": "2026-04-07T07:30:00Z",
    "taskCount": 12
  },

  // --- Implementation (set by implement) ---
  "implementation": {
    "completedAt": "2026-04-07T08:00:00Z",
    "prNumber": 15,
    "prUrl": "https://github.com/acme/webapp/pull/15",
    "commitSha": "abc1234",
    "baseUrl": "http://localhost:3000",   // detected dev-server URL (for e2e)
    "authToken": null                      // optional auth token for e2e
  },

  // --- UAT (set by test agent) ---
  "uat": {
    "completedAt": "2026-04-07T08:30:00Z",
    "verdict": "PASS",                    // "PASS" | "FAIL" | "PARTIAL"
    "passCount": 10,
    "failCount": 0,
    "report": "Markdown UAT report..."
  },

  // --- E2E (set by e2e agent) ---
  "e2e": {
    "completedAt": "2026-04-07T09:00:00Z",
    "projectType": "web-ui",             // "web-ui" | "api" | "cli" | "library" | "infrastructure"
    "passed": true,
    "artifacts": ["e2e/e2e-42.spec.ts", "e2e/gifs/e2e-42/sc1.gif"]
  },

  // --- Circuit breaker (managed by router) ---
  "retryCount": {
    "specify": 0,
    "research": 0,
    "plan": 0,
    "implement": 0,
    "test": 0,
    "e2e": 0,
    "retro": 0
  }
}
```

## Field Rules

### Required Fields (set by specify, always present)

| Field | Type | Set By | Description |
|-------|------|--------|-------------|
| `issueNumber` | number | specify | GitHub Issue number |
| `issueTitle` | string | specify | Full issue title |
| `workType` | string | specify | `"feature"` \| `"bug"` \| `"chore"` |
| `specNumber` | string | specify | The three-digit spec number (e.g., `"012"`) |
| `branch` | string | specify | Branch name |
| `owner` | string | specify | Repository owner |
| `repo` | string | specify | Repository name |
| `livingContext` | object | specify | Compressed living-docs summary and load timestamp |
| `constitutionCompliant` | boolean | specify | Whether the spec passed constitution checks |
| `complexitySignal` | string | specify | Nexus-determined routing: `"research"` \| `"plan"` \| `"implement"` |
| `retryCount` | object | router | Per-phase retry counters (all start at `0`) |

### Optional Fields (set by downstream phases)

| Field | Type | Set By | Description |
|-------|------|--------|-------------|
| `research` | object | research | Summary and timestamp of research phase |
| `plan` | object | plan | Completion timestamp and task count |
| `implementation` | object | implement | PR details, commit SHA, dev-server URL |
| `uat` | object | test | UAT verdict, counts, and report |
| `e2e` | object | e2e | Project type, pass/fail, artifact paths |

### Staleness Check

The router checks staleness before passing context to a downstream agent:

```
if issue.updatedAt > context.livingContext.loadedAt → reload living context
```

If the issue body was modified after the living context was loaded, the router re-invokes `speckit-living-docs-loader` and replaces `livingContext` before proceeding.

### Backward Compatibility

When an agent is invoked **without** a `PipelineContext` (standalone / direct invocation):

1. The agent MUST accept a bare issue number as input.
2. It derives the context it needs from `gh` and `git` CLI commands:
   - `gh issue view {number} --json ...` for issue details
   - `git branch --show-current` for branch name
   - `gh pr list --head {branch} --json ...` for PR details
3. It invokes `speckit-living-docs-loader` directly (old behaviour).
4. It does NOT build a full `PipelineContext` — it operates with whatever it can derive.

This ensures agents remain usable outside the full pipeline (e.g., running `speckit-test #42` standalone).

## Circuit Breaker Integration

See [AGENT-PROTOCOL.md](./AGENT-PROTOCOL.md) § Circuit Breaker for the retry-escalation rules.

The router increments `retryCount.{phase}` each time it re-invokes a phase due to failure.
When `retryCount.{phase} >= 2`, the router stops and escalates to the user instead of retrying.
