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

  // --- Living context (set by specify) ---
  "livingContext": {
    "summary": "Compressed summary of relevant living docs (read directly via #codebase / read_file)...",
    "loadedAt": "2026-04-07T06:30:00Z"
  },

  // --- Constitution (set by specify) ---
  "constitutionCompliant": true,     // false → downstream phases should not proceed

  // --- Complexity signal (set by specify) ---
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

  // --- Artifact index (set incrementally by each phase, optional) ---
  // See § Artifact Index below for the full contract.
  "artifactIndex": {
    "researchCommentId": 4356928435,            // GitHub Issue comment ID for the research block (null until research runs)
    "planCommentId": 4356953657,                // GitHub Issue comment ID for the plan block (null until plan runs)
    "dataModelPath": "docs/data-model.md",      // Living-doc path (null if not produced)
    "openapiPath": "docs/openapi.yaml",         // Living-doc path (null if not produced)
    "e2eEvidenceDir": "e2e/gifs/e2e-42/",       // Directory of e2e evidence (null until e2e runs)
    "extra": {
      "schemaVersion": 1,                       // Independent version for the extra map
      "entries": {                              // Project-specific named pointers
        "loadTestReport": "docs/perf/load-42.html"
      }
    }
  },

  // --- Context budget (advisory, set by any phase, optional) ---
  // See § Context Budget below for the full contract.
  "contextBudget": {
    "maxSourceLines": 1500,                     // Advisory cap per phase. speckit-verify --scope pr warns on overrun.
    "loadedArtifacts": [                        // Audit trail of what the current phase has read.
      "docs/constitution.md",
      "references/HANDOFF-SCHEMA.md"
    ]
  },

  // --- Phase verdicts (set by each phase, optional) ---
  // See § Phase Verdicts below for the full contract.
  "phaseVerdicts": {
    "specify":   { "verdict": "pass",    "notes": "Spec accepted." },
    "research":  { "verdict": "pass",    "notes": "Decisions recorded." },
    "plan":      { "verdict": "pass",    "notes": "Plan posted to issue." },
    "implement": { "verdict": "pass",    "notes": "PR #99 opened." },
    "test":      { "verdict": "blocked", "notes": "Acceptance criterion 3 ambiguous." },
    "e2e":       { "verdict": "fail",    "notes": "Login flow regressed." }
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
| `artifactIndex` | object | any phase | Pointers to durable artifacts. See § Artifact Index. |
| `contextBudget` | object | any phase | Advisory per-phase context budget. See § Context Budget. |
| `phaseVerdicts` | object | each phase | Machine-readable pass/fail/blocked per phase. See § Phase Verdicts. |

## Artifact Index

The `artifactIndex` object gives downstream phases a stable, named lookup for durable artifacts produced by earlier phases. It replaces ad-hoc string-matching against issue comments and free-form file scans.

### Required keys (fixed-key set)

| Key | Type | Set By | Description |
|-----|------|--------|-------------|
| `researchCommentId` | number \| null | research | GitHub Issue comment ID for the `<!-- speckit-research:start -->` block. `null` until research runs. |
| `planCommentId` | number \| null | plan | GitHub Issue comment ID for the `<!-- speckit-plan:start -->` block. `null` until plan runs. |
| `dataModelPath` | string \| null | plan / implement | Workspace-relative path to the data-model living doc, or `null` if none. |
| `openapiPath` | string \| null | plan / implement | Workspace-relative path to the OpenAPI/contract document, or `null` if none. |
| `e2eEvidenceDir` | string \| null | e2e | Directory containing e2e evidence (gifs/screenshots/logs), or `null` until e2e runs. |

The five required keys cover the artifacts every speckit pipeline phase needs to find. Keep this list small on purpose — discovery of *other* repo content is better served by `search/codebase` (semantic_search) and `search/textSearch` (grep_search), which require no maintenance.

### Extension via `extra`

Project-specific named artifacts go in `artifactIndex.extra`:

```jsonc
"extra": {
  "schemaVersion": 1,                  // Versioned independently of HANDOFF-SCHEMA itself
  "entries": {                         // Free-form name → path|url map
    "loadTestReport": "docs/perf/load-42.html"
  }
}
```

Bump `schemaVersion` when a project changes the meaning of an existing entry name. Adding new entries does NOT require a bump.

### Defaults and backward compatibility

- The whole `artifactIndex` object is **optional**. Pipelines that omit it MUST continue to work.
- When present, the default shape is `{ extra: { schemaVersion: 1, entries: {} } }` with all fixed keys set to `null`.
- A consumer reading `artifactIndex.dataModelPath` MUST handle `null`/missing gracefully and fall back to `search/codebase` for discovery.

## Context Budget

The `contextBudget` object is an **advisory** per-phase budget. It is not enforced at the tool layer; the router and `speckit-verify` use it for warnings.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `maxSourceLines` | number | `1500` | Soft cap on source lines a single phase should read. `speckit-verify --scope pr` warns when a phase's `loadedArtifacts` total exceeds this. |
| `loadedArtifacts` | string[] | `[]` | Audit trail of file paths the current phase has already loaded. Phases SHOULD append rather than re-read. |

### Why advisory, not enforced

Hard enforcement would create false positives whenever a phase legitimately needs to read a large schema or migration file. The dominant token waste is **repeated** reads across phases — addressed by `loadedArtifacts` (so a phase doesn't re-read what it already has) and by `/memories/repo/` reuse hints (so cross-phase facts don't get rediscovered). `maxSourceLines` is the safety net, not the main lever.

### Backward compatibility

- The whole `contextBudget` object is **optional**.
- A missing `contextBudget` MUST be treated as "no budget configured" — `speckit-verify` skips the warning.
- A missing `loadedArtifacts` MUST be treated as `[]`.

## Phase Verdicts

The `phaseVerdicts` object is a typed pass/fail/blocked record per phase. It replaces parsing PR-checklist boxes or scraping issue-comment prose.

```jsonc
"phaseVerdicts": {
  "specify":   { "verdict": "pass",    "notes": "Spec accepted." },
  "research":  { "verdict": "pass",    "notes": "Decisions recorded." },
  "plan":      { "verdict": "pass",    "notes": "Plan posted to issue." },
  "implement": { "verdict": "pass",    "notes": "PR #99 opened." },
  "test":      { "verdict": "blocked", "notes": "Acceptance criterion 3 ambiguous." },
  "e2e":       { "verdict": "fail",    "notes": "Login flow regressed." }
}
```

### Verdict enum

| Value | Meaning | Router action |
|-------|---------|---------------|
| `"pass"` | Phase completed successfully. | Proceed. |
| `"fail"` | Phase ran and produced a definitive failure. | Increment `retryCount.{phase}`; do NOT auto-retry if already at limit. |
| `"blocked"` | Phase cannot proceed without a decision (ambiguous spec, missing dependency, external blocker). | Escalate to the user — do NOT auto-retry. |

### Defaults and backward compatibility

- The whole `phaseVerdicts` object is **optional**.
- A missing `phaseVerdicts.{phase}` MUST be treated as "no verdict yet" (the phase has not run, or ran on an older pipeline that did not emit verdicts).
- `notes` is optional but RECOMMENDED for `fail` and `blocked`.

## /memories/repo/ Write Convention

Cross-phase reusable facts (the original "reuseHints" idea) are NOT a schema field. Instead, phases write structured entries to `/memories/repo/{slug}.md` using the existing VS Code Copilot repository-memory shape:

```jsonc
{
  "subject": "Short subject line",
  "fact":    "The factual statement, with enough context to be useful in isolation.",
  "citations": [
    "path/to/file.md (line range or anchor)",
    "https://github.com/{owner}/{repo}/issues/{n}"
  ],
  "reason":   "Why this fact matters across future tasks.",
  "category": "architecture-principle"
}
```

### Why no schema field

VS Code Copilot auto-surfaces `/memories/repo/` entries to every future agent invocation as `<repository_memories>`. Adding a parallel `reuseHints` array in `PipelineContext` would create two sources of truth that drift. See `/memories/repo/prefer-vscode-primitives-over-pipelinecontext-fields.md` for the architectural principle.

### Recommended categories

| Category | Written by | Example use |
|----------|------------|-------------|
| `architecture-principle` | research, plan | "Prefer VS Code primitives over new schema fields" |
| `e2e-skill` | implement (consumer: #24) | Pointer to a codified reusable E2E flow |
| `repo-fact` | any phase | "All Python commands run inside Docker containers" |
| `decision` | specify, research | "Issue body holds spec only; plan goes to issue comment" |

### When to write

- After a research phase produces a finding that future phases should not have to rediscover.
- At `speckit-implement` done-done, when an implementation choice should inform future work.
- NEVER as a substitute for living docs — durable design content still belongs in `docs/`.

### Required fields

All five fields (`subject`, `fact`, `citations`, `reason`, `category`) are required. Entries missing `citations` or `reason` SHOULD be rejected by `speckit-verify --scope repo`.

### Staleness Check

The router checks staleness before passing context to a downstream agent:

```
if issue.updatedAt > context.livingContext.loadedAt → reload living context
```

If the issue body was modified after the living context was loaded, the router re-reads the relevant living docs directly (via `read_file` / `#codebase`) and replaces `livingContext` before proceeding.

### Backward Compatibility

When an agent is invoked **without** a `PipelineContext` (standalone / direct invocation):

1. The agent MUST accept a bare issue number as input.
2. It derives the context it needs from `gh` and `git` CLI commands:
   - `gh issue view {number} --json ...` for issue details
   - `git branch --show-current` for branch name
   - `gh pr list --head {branch} --json ...` for PR details
3. It reads the relevant living docs directly via `read_file` / `#codebase` (no separate loader subagent).
4. It does NOT build a full `PipelineContext` — it operates with whatever it can derive.

This ensures agents remain usable outside the full pipeline (e.g., running `speckit-test #42` standalone).

## Circuit Breaker Integration

See [AGENT-PROTOCOL.md](./AGENT-PROTOCOL.md) § Circuit Breaker for the retry-escalation rules.

The router increments `retryCount.{phase}` each time it re-invokes a phase due to failure.
When `retryCount.{phase} >= 2`, the router stops and escalates to the user instead of retrying.
