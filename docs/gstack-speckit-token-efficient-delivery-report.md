# Speckit × gstack: token-efficient end-to-end delivery report

**Date:** 2026-04-29  
**Tracker:** [ranvirsingh/speckit#20](https://github.com/ranvirsingh/speckit/issues/20)  
**Problem to solve:** minimize token usage, maximize end-to-end delivery, and keep every change inside a repeatable process.

## Executive verdict

Speckit and gstack solve adjacent problems from opposite directions:

- **Speckit is the governance spine.** It turns work into issue-backed specs, constrains agents by phase, enforces scope with frontmatter `tools:`, hands context through `PipelineContext`, and insists on UAT/E2E proof before work is considered done.
- **gstack is the execution compressor.** It pushes repeated work out of chat and into deterministic CLIs, browser daemons, browser-skills, memory lookup, checkpointing, and safety rails.

The best hybrid is **not** “install gstack inside Speckit.” It is:

> Keep Speckit as the process and audit layer. Borrow gstack’s low-token execution surfaces, codification loop, and memory discipline so Speckit agents spend tokens on judgment rather than re-discovery, browser plumbing, and repeated mechanical work.

The highest-leverage move is a Speckit-native “thin harness, fat skills” pattern:

1. **Thin deterministic harnesses** for browser, repository lookup, issue state, and verification.
2. **Fat Speckit skills** for judgment-heavy phase work: specify, research, plan, implement, test, e2e, verify.
3. **Structured handoffs only** through `PipelineContext`, issue comments, and durable artifacts.
4. **Codify after success** so repeated browser flows, E2E checks, and repo discovery steps become reusable assets.

## Evidence base

### Local Speckit files reviewed

- `README.md` — project overview, pipeline, focused context, living-doc philosophy.
- `SKILL.md` — router skill, constitution gate, pipeline routing, auto-continuation, circuit breaker.
- `references/AGENT-PROTOCOL.md` — subagent autonomy, scope discipline, token buckets.
- `references/HANDOFF-SCHEMA.md` — `PipelineContext` JSON schema and staleness checks.
- `references/HOOKS.md` — before/after phase extension hooks.
- `references/MODELS.md` — model tiering and rationale.
- `skills/speckit-specify/SKILL.md` — issue-backed specification.
- `skills/speckit-research/SKILL.md` — research phase and issue-comment output.
- `skills/speckit-plan/SKILL.md` — planning phase and “no application code” boundary.
- `skills/speckit-implement/SKILL.md` — implementation, PR, tests, done-done living docs.
- `skills/speckit-verify/SKILL.md` — constitution and repo-hygiene verification.
- `agents/speckit-test.agent.md` — UAT verification.
- `agents/speckit-e2e.agent.md`, `agents/speckit-e2e-browser.agent.md`, `agents/speckit-e2e-api.agent.md` — E2E orchestration and artifacts.
- `agents/speckit-web-researcher.agent.md` — external research subagent.
- `install.ps1` and `scripts/speckit.tests.ps1` — installation shape and current script tests.

### External gstack/GBrain material reviewed

- `https://github.com/garrytan/gstack`
- `https://github.com/garrytan/gstack/blob/main/README.md`
- `https://github.com/garrytan/gstack/blob/main/SKILL.md`
- `https://github.com/garrytan/gstack/blob/main/AGENTS.md`
- `https://github.com/garrytan/gstack/blob/main/ARCHITECTURE.md`
- `https://github.com/garrytan/gstack/blob/main/BROWSER.md`
- `https://github.com/garrytan/gstack/blob/main/docs/designs/BROWSER_SKILLS_V1.md`
- `https://github.com/garrytan/gstack/blob/main/scrape/SKILL.md`
- `https://github.com/garrytan/gstack/blob/main/skillify/SKILL.md`
- `https://github.com/garrytan/gstack/blob/main/docs/domain-skills.md`
- `https://github.com/garrytan/gstack/blob/main/docs/OPENCLAW.md`
- `https://github.com/garrytan/gstack/blob/main/docs/gbrain-sync.md`
- `https://github.com/garrytan/gbrain`
- `https://github.com/garrytan/gbrain/blob/master/docs/ethos/THIN_HARNESS_FAT_SKILLS.md`
- `https://github.com/garrytan/gbrain/blob/master/docs/guides/minions-deployment.md`
- `https://github.com/browser-use/browser-harness-js`
- `https://github.com/chenglou/pretext`
- `https://garryslist.org/posts/boil-the-ocean`

## Current Speckit strengths

### 1. Process is explicit and inspectable

Speckit already has the thing most agent workflows lack: a process spine.

| Speckit capability | Why it matters |
|---|---|
| GitHub issue-backed specs | Work starts from an auditable problem statement, not chat drift. |
| Phase skills | Each phase has a clear output and scope boundary. |
| Issue comments for research/plan | Keeps issue body lean while preserving decisions. |
| `PipelineContext` | Prevents every phase from re-discovering the same project facts. |
| Constitution gate | Gives the project a non-negotiable policy layer. |
| Frontmatter `tools:` allowlists | Scope is enforced by the harness, not just prompt text. |
| UAT and E2E agents | Done means verified behavior, not “code compiles on my vibes.” |
| PR template and pipeline guard | The process follows work into review. |

This should remain the backbone.

### 2. Speckit already has token-saving primitives

Speckit is not starting from zero. It already has several token-reduction patterns:

- **`PipelineContext`**: compact handoff object to eliminate rediscovery.
- **Issue comment markers**: research and plans can be loaded by marker rather than by entire histories.
- **Scope-bounded subagents**: focused agents return distilled findings instead of polluting the parent context with every search result.
- **Model tiering**: cheaper models for bounded reads, stronger models for specs/plans/code/constitution.
- **Living docs**: stable project knowledge moves out of repeated chat context.
- **Circuit breaker**: `retryCount` prevents runaway loops.

These are strong foundations. The opportunity is to make them more deterministic and more aggressively compressed.

### 3. Speckit’s main token risks

The current architecture can still spend too many tokens in predictable places:

| Token risk | Why it happens | Hybrid fix |
|---|---|---|
| Re-reading project structure | Agents may scan files each phase if handoff is incomplete. | Make `PipelineContext` and repo fact summaries mandatory phase inputs. |
| Browser/E2E tool chatter | Browser MCP-style interactions can expose large schemas, snapshots, traces, and screenshots. | Add a thin browser CLI path with compact text/JSON output. |
| Repeated successful flows | A browser flow that worked once is rediscovered next time. | Codify successful flows into reusable Speckit E2E/browser skills. |
| Issue comment bloat | Research/plan comments can become long and repeatedly loaded. | Store long evidence in artifacts; keep comments as index + decisions. |
| Ambiguous phase transitions | Parent agent may reload broad context to decide next action. | Add machine-readable phase outputs and validation gates. |
| Mechanical audits in latent space | LLMs inspect checklists, branches, issue markers manually. | Push repo hygiene into deterministic scripts/CLI commands. |

## Current gstack strengths worth borrowing

### 1. Thin harness, fat skills

The strongest gstack idea is architectural, not tool-specific:

- Keep the harness small and deterministic.
- Put judgment, process, and domain knowledge into skills.
- Route the right skill/context only when needed.
- Move stable repeated procedures into code.

For Speckit, this means the router and agents should avoid becoming giant all-knowing prompts. Speckit should keep phase skills rich, but push status checks, browser operation, issue-state lookup, and repeated extraction into deterministic commands.

### 2. Persistent browser CLI instead of protocol-heavy browser loops

gstack’s browser docs describe a persistent local Chromium daemon controlled by a compiled CLI. Its stated advantage is that plain stdout avoids MCP schema/protocol overhead, while repeated operations run against a warm browser session.

The report does not benchmark those claims in this repo, so treat the exact numbers as gstack’s own documented measurements. The design lesson is still sound:

> Browser automation should return compact, task-shaped text or JSON. The LLM should not pay protocol and screenshot tax on every step unless visual judgment is actually required.

Speckit’s E2E browser agent currently uses Playwright-style tests and may use browser tools. That is good for durable CI artifacts, but there is room for a lower-token exploration layer before durable tests are written.

### 3. `/scrape` → `/skillify` codification loop

gstack’s browser-skills design is a direct answer to token waste:

1. First call prototypes the flow using browser primitives.
2. Successful output is returned as stable JSON.
3. `/skillify` turns the working flow into a deterministic script with a fixture and test.
4. Future matching calls run the skill in about one command instead of replaying exploration.

Key practices to copy:

- **Provenance guard**: only codify a recent, successful, accepted prototype.
- **Input slicing**: use only final successful commands and the user’s intent, not the whole conversation.
- **Pure parser/test split**: browser navigation in `main`, parsing in pure functions tested against fixtures.
- **Atomic write**: stage in temp dir, test, ask approval, then rename into place.
- **Tiered storage**: project/global/bundled scopes, with project override winning.
- **JSON stdout protocol**: logs on stderr, machine-readable result on stdout.

Speckit can adapt this for E2E flows and repeated repo/process checks.

### 4. Safety rails as first-class workflow concepts

gstack’s safety posture includes ideas Speckit should consider as hooks or verify checks:

- “Careful” mode for destructive commands.
- “Freeze” mode to prevent edits outside allowed paths.
- Guard mode combining caution and edit boundaries.
- Prompt-injection defense for browser/domain skill data.
- Scoped browser tokens and command allowlists.
- Privacy modes for memory sync.

Speckit already has a strong scope story via frontmatter tool allowlists. gstack’s contribution is more operational: safety state can be toggled or enforced at runtime based on risk.

### 5. Memory and deterministic background work

GBrain adds two patterns relevant to Speckit:

- **Memory/code lookup**: hybrid search, code definitions/references, and persistent knowledge reduce repeated repo scans.
- **Minions/supervisor**: deterministic background work is queued, supervised, health-checked, and machine-readable.

Speckit should not require GBrain by default. But it can borrow the shape:

- Project facts should be discoverable through a compact index.
- Deterministic jobs should expose JSON status.
- Long-running workers need liveness checks and audit logs if introduced.

## Best-of-both-worlds target architecture

```text
User request
  ↓
Speckit router skill
  ↓
GitHub issue-backed spec and phase selection
  ↓
PipelineContext JSON + living-doc index
  ↓
Phase skill or scoped subagent
  ↓
Deterministic harnesses for mechanical work
  ├─ issue/PR state CLI
  ├─ repo fact/code lookup CLI
  ├─ browser/session CLI
  ├─ test/e2e runner
  └─ verify/audit scripts
  ↓
Durable artifacts
  ├─ issue comments with markers
  ├─ docs/living docs
  ├─ tests/e2e evidence
  ├─ reusable browser/e2e skills
  └─ PR checklist + guard
```

The key split:

| Work type | Where it belongs |
|---|---|
| Ambiguous product, architecture, or scope decisions | Speckit skills/subagents |
| Repeated browser navigation/extraction | Deterministic browser skill |
| Repo status, branch, issue, PR, constitution checks | Deterministic script/CLI |
| User-facing acceptance judgment | UAT/E2E agents |
| Durable process memory | Living docs, issue comments, repo memory, optional GBrain-like index |

## Recommendations

### R1. Keep Speckit’s issue-backed pipeline as the non-negotiable outer loop

Do not replace Speckit’s pipeline with gstack’s sprint loop. Map gstack’s strengths into Speckit phases instead.

| gstack concept | Speckit home |
|---|---|
| Think | `speckit-specify` and issue spec |
| Plan | `speckit-research` + `speckit-plan` issue comments |
| Build | `speckit-implement` |
| Review | PR guard, optional review subagent/future skill |
| Test | `speckit-test` UAT |
| Ship | `speckit-implement` PR flow + checks |
| Reflect | done-done living docs and future retro agent/step |

Why: Speckit’s differentiator is process compliance. gstack’s differentiator is execution compression. The hybrid should not trade one for the other.

### R2. Make `PipelineContext` the single compact context contract

Today `PipelineContext` is already the right shape. Strengthen it into a strict phase contract:

- Every phase should accept either an issue number or a `PipelineContext`.
- Every phase should return an updated compact `PipelineContext` block.
- Phase outputs should include pointers to large artifacts, not inline dumps.
- `retryCount` should be incremented and checked consistently.
- Include a `tokenBudget` or `contextBudget` field per phase.

Suggested additions:

| Field | Purpose |
|---|---|
| `contextBudget.maxSourceLines` | Prevent accidental full-repo reads. |
| `contextBudget.loadedArtifacts` | Record what was already read. |
| `artifactIndex` | Map research, plan, tests, screenshots, logs to paths/URLs. |
| `phaseVerdicts` | Machine-readable pass/fail/blocked state by phase. |
| `reuseHints` | Known browser skills, repo facts, prior decisions to load first. |

This gives Speckit a native answer to token minimization without depending on external memory systems.

### R3. Add a low-token browser harness path for E2E exploration

Keep Playwright tests as durable CI artifacts. Add a thinner exploration harness before test generation.

Desired properties:

- Persistent local browser session.
- Commands return compact text or JSON.
- Snapshot command returns stable element references, not large screenshots by default.
- Screenshot/video only when visual proof is needed.
- JSON stdout, logs on stderr.
- Scoped capability token for browser operations.
- No arbitrary JS/eval in default mode.

This can be implemented three ways:

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| Build `speckit-browse` from scratch | Full control, native process fit | More initial work | Best long-term if browser becomes core. |
| Adapt gstack browser ideas, not code | Faster design, fewer coupling risks | Still requires implementation | Best near-term design path. |
| Use existing browser MCP/tooling only | No new code | Higher token/protocol overhead, weaker codification | Keep as fallback. |

For Speckit, browser exploration should serve E2E test generation. It should not become a separate product surface unless real usage proves it.

### R4. Introduce Speckit “E2E skills” for repeated acceptance flows

Borrow browser-skills, but make them Speckit-native.

Possible layout:

```text
.speckit/e2e-skills/<name>/
├── SKILL.md              # frontmatter: issue, scenario ids, host/app area, triggers, version
├── flow.spec.ts          # durable Playwright test or helper
├── fixtures/             # HTML/API snapshots if useful
├── evidence/             # small screenshots/GIFs from known-good run
└── results.json          # last verified result
```

Use cases:

- Repeated login/onboarding flows.
- Common API happy paths.
- Regression checks for high-value scenarios.
- Browser setup flows reused across issues.

Codification rules:

1. Only codify a flow that passed during `speckit-e2e`.
2. Stage in a temp directory.
3. Run the generated test/fixture replay.
4. Ask for approval or require parent-agent approval gate.
5. Commit atomically into project scope.
6. Register in `PipelineContext.reuseHints`.

This directly reduces repeated browser/test setup tokens.

### R5. Add an artifact index to issue comments

Speckit should keep issue comments human-readable but compact. The full evidence can live in files.

Recommended comment shape:

```text
<!-- speckit-research:start -->
Status: complete
Decision summary:
- Browser CLI is the highest-leverage gstack idea for token reduction.
- Browser-skills should be adapted as Speckit E2E skills.
Artifacts:
- docs/gstack-speckit-token-efficient-delivery-report.md
- e2e/results/... if applicable
Context budget:
- Sources loaded: README, AGENT-PROTOCOL, HANDOFF-SCHEMA, gstack BROWSER, Browser-Skills v1
<!-- speckit-research:end -->
```

This prevents future agents from reloading long research dumps when a summary and artifact pointer will do.

### R6. Route deterministic checks out of the LLM

Speckit already has PowerShell scripts for constitution and tests. Expand that strategy.

Candidates for deterministic scripts:

| Script/CLI | Purpose |
|---|---|
| `scripts/get-pipeline-state.ps1` | Emit issue, branch, PR, checklist, phase markers as JSON. |
| `scripts/build-pipeline-context.ps1` | Build compact `PipelineContext` from issue + repo state. |
| `scripts/check-token-budget.ps1` | Estimate oversized comments/artifacts and flag bloat. |
| `scripts/list-reusable-flows.ps1` | List available E2E/browser skills for a project. |
| `scripts/audit-speckit-hygiene.ps1` | Local mirror of repo-scope verify checks. |

The rule from “thin harness, fat skills” applies: if the same input should always produce the same output, make it code.

### R7. Add optional memory integration, but keep living docs primary

Do not make GBrain mandatory. Speckit should remain easy to install and understand.

A safe path:

1. **Default:** living docs + issue comments + repo memory.
2. **Optional:** GBrain or similar memory provider for teams that want cross-repo/cross-machine memory.
3. **Privacy modes:** off, artifacts-only, full.
4. **Secret scanning:** before any memory sync.
5. **Staleness checks:** memories cite files and should be flagged when cited paths change.

Speckit can support an interface without binding to one tool:

```text
speckit-memory-provider:
  mode: off | artifacts-only | full
  backend: living-docs | gbrain | custom
  sync: manual | phase-start-end
```

The key is not GBrain itself. The key is to stop paying tokens to rediscover stable facts.

### R8. Add runtime guardrails through hooks

Speckit’s `references/HOOKS.md` is the natural home for gstack-inspired safety states.

Potential hooks:

| Hook | Guardrail |
|---|---|
| `before_implement` | Freeze allowed edit paths based on issue scope. |
| `before_pr` | Run destructive-change scan and TODO triage. |
| `before_test` | Ensure tests align with acceptance criteria. |
| `before_e2e` | Select browser/API harness and require safe base URL. |
| `after_e2e` | Attach compact evidence and update artifact index. |

Add a “careful mode” rule for destructive commands:

- Delete files/directories.
- Rewrite history.
- Drop databases.
- Run migrations.
- Touch secrets/config.
- Modify generated assets broadly.

For those cases, the agent should emit a structured decision brief and require approval.

### R9. Preserve model tiering, but measure by phase cost

`references/MODELS.md` gives a useful qualitative tier map. Improve it with measured phase cost over time:

| Metric | Why it matters |
|---|---|
| Tokens per phase | Detect which phase burns budget. |
| Re-invocations per phase | Detect unclear scope or weak handoff. |
| Browser commands per E2E | Detect candidates for codification. |
| Files read per phase | Detect rediscovery. |
| Artifact size | Detect issue/comment bloat. |

Avoid optimizing by model alone. The bigger win is moving deterministic work out of the model entirely.

## Token reduction playbook

### Highest-impact reductions

| Rank | Change | Expected effect | Why |
|---:|---|---|---|
| 1 | Mandatory compact `PipelineContext` | High | Stops phase-by-phase rediscovery. |
| 2 | Thin browser CLI for exploration | High | Reduces protocol/snapshot noise during E2E work. |
| 3 | E2E/browser skill codification | High over time | Successful flows become reusable deterministic assets. |
| 4 | Artifact index comments | Medium-high | Future agents load summaries and paths, not full dumps. |
| 5 | Deterministic repo/issue state scripts | Medium | Replaces LLM checklist archaeology with JSON. |
| 6 | Optional memory/code lookup | Medium | Speeds codebase understanding for repeated tasks. |
| 7 | Runtime guard hooks | Medium | Prevents costly mistakes and rework. |

### Practical context budget rules

Recommended defaults:

- **Issue body:** spec only, concise and stable.
- **Research comment:** decision summary + evidence links, not copied pages.
- **Plan comment:** implementation checklist + key decisions, not full source excerpts.
- **PipelineContext:** one compact JSON object per transition.
- **Subagent return:** structured summary, unresolved questions, artifact paths.
- **Browser output:** text/JSON first; screenshot/video only when visual proof is required.
- **E2E evidence:** attach small GIFs/screenshots, store raw output in artifact paths.

A Speckit agent should ask: “Can this be a pointer, fixture, JSON status, or script output instead of prose?” Most of the time, yes.

## End-to-end delivery playbook

### Current good Speckit flow

```text
Issue spec → research/plan → implement → UAT → E2E → PR guard → done-done docs
```

### Hybrid improved flow

```text
Issue spec
  → build/load PipelineContext
  → research/plan with artifact index
  → implement with frozen scope
  → UAT against acceptance criteria
  → E2E exploration through low-token browser/API harness
  → durable Playwright/API tests generated
  → successful repeated flows optionally codified as E2E skills
  → PR guard + compact evidence
  → done-done living docs + reusable flow registry update
```

The improvement is not skipping steps. The improvement is making each step cheaper and more reusable.

## Process-fit analysis

### What to keep from Speckit

- Issue-first discipline.
- Phase-specific skills.
- Frontmatter tool allowlists.
- Subagent scope boundaries.
- `PipelineContext` handoff.
- Constitution verification.
- PR template and pipeline guard.
- UAT/E2E separation.
- Living-doc principle.

### What to borrow from gstack

- Thin CLI harnesses for mechanical work.
- Persistent browser session with compact command output.
- Browser-skills and `/skillify` pattern.
- Domain-skill style memory for repeated site/app facts.
- Continuous checkpoint/context recovery, adapted carefully to Git discipline.
- Safety modes: careful/freeze/guard.
- Decision briefs for high-stakes questions.
- “Search before building” and “codify if asked twice” discipline.

### What not to borrow wholesale

- Do not replace GitHub issues with local-only session state.
- Do not add many MCP tools if a CLI with JSON stdout will do.
- Do not make telemetry or memory sync default-on.
- Do not auto-codify mutating browser flows without explicit gates.
- Do not let browser/domain skills inject untrusted page text directly into privileged prompts.
- Do not turn Speckit’s router into a giant CLAUDE.md-style monolith.

## Proposed roadmap

### Phase 0 — Report and process tightening

**Goal:** Capture this analysis and turn it into scoped specs.

Actions:

- Land this report under `docs/`.
- Link it from issue `#20`.
- Create follow-up issues for the implementation phases below.
- Add a lightweight “token budget” section to `references/AGENT-PROTOCOL.md` in a future change.

Done when:

- Report exists.
- Follow-up specs are agreed.
- No source behavior changes are introduced accidentally.

### Phase 1 — Compact handoff and artifact index

**Goal:** Make context handoff stricter before building new tools.

Candidate issue title:

> Add PipelineContext artifact index and context-budget fields

Acceptance criteria:

- `references/HANDOFF-SCHEMA.md` documents `artifactIndex`, `contextBudget`, and `reuseHints`.
- Phase skills mention returning/updating those fields.
- Existing tests validate the schema docs or examples.
- Research/plan comments use compact summaries with artifact links.

Why first: it is cheap and immediately reduces repeated context load.

### Phase 2 — Speckit browser exploration harness design

**Goal:** Specify, not yet build, a low-token browser harness.

Candidate issue title:

> Design Speckit browser harness for low-token E2E exploration

Acceptance criteria:

- Design doc compares current browser tooling, gstack-style CLI, and Playwright direct execution.
- Security model is explicit: allowed commands, token scope, no default eval.
- Output protocol is defined: JSON stdout, stderr logs, exit codes, max output.
- E2E agent integration points are documented.

Why second: browser automation touches safety and needs a clear boundary.

### Phase 3 — Deterministic repo/issue state scripts

**Goal:** Move Speckit hygiene checks into machine-readable outputs.

Candidate issue title:

> Add machine-readable pipeline state and hygiene scripts

Acceptance criteria:

- Script emits current issue/branch/PR/checklist/phase markers as JSON.
- `speckit-verify` can reference the script output.
- Tests cover happy path and missing-state cases.
- Agents stop manually rediscovering the same state in prose.

Why third: this improves every pipeline phase and is safer than browser work.

### Phase 4 — Speckit E2E skill registry

**Goal:** Codify repeated E2E flows after they pass.

Candidate issue title:

> Add project-scoped reusable E2E flow registry

Acceptance criteria:

- Defines `.speckit/e2e-skills/<name>/` layout.
- Defines frontmatter contract and trigger matching.
- Adds an atomic staging/commit/discard helper.
- Adds tests for staging cleanup and trigger resolution.
- E2E agent can list available flows before generating new tests.

Why fourth: the registry is useful once the handoff and state machinery are stable.

### Phase 5 — Optional memory provider interface

**Goal:** Support GBrain-like memory without making it required.

Candidate issue title:

> Add optional Speckit memory provider interface

Acceptance criteria:

- Defines `off`, `artifacts-only`, and `full` modes.
- Requires secret scanning before sync in non-off modes.
- Requires citations for stored facts.
- Supports living-docs as the default backend.
- Documents GBrain as one optional backend, not a dependency.

Why fifth: memory is powerful, but privacy and staleness must be designed first.

### Phase 6 — Runtime safety hooks

**Goal:** Add careful/freeze/guard concepts through Speckit hooks.

Candidate issue title:

> Add safety guard hooks for destructive and out-of-scope operations

Acceptance criteria:

- `references/HOOKS.md` documents safety hook outputs.
- Destructive operations require explicit approval.
- Edit-path freeze can be derived from issue scope.
- Verify catches unchecked skip/bypass patterns.

Why sixth: this protects the higher-throughput system from moving fast in the wrong direction.

## Design details for a Speckit E2E skill

### Frontmatter contract

A Speckit E2E skill should have enough metadata for resolver matching without loading the whole script:

```yaml
---
name: login-happy-path
kind: e2e-flow
version: 1.0.0
source: speckit-e2e
trusted: false
issue: 42
scenarioIds:
  - US1-SC1
appArea: auth
triggers:
  - login happy path
  - user signs in successfully
  - auth smoke test
artifacts:
  lastResult: results.json
  evidence: evidence/sc1.gif
---
```

### Execution contract

- `stdout`: one JSON result.
- `stderr`: logs.
- Exit `0`: pass.
- Exit nonzero: fail with structured error.
- Max output size enforced.
- No source-code writes.
- No secrets in artifacts.

### Test contract

Minimum gate before committing a skill:

- Fixture or mock replay test.
- Live smoke test if base URL is available.
- Failure cleanup test for staging helper.
- Trigger resolution test.

### Approval contract

Codification must be explicit because reusable skills influence future behavior.

Acceptable gates:

- Human approval via Speckit parent skill.
- PR review approval for committed project-scoped skills.
- Strict auto-approval only for non-mutating, read-only flows with passing tests, if configured by project constitution.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Browser harness becomes another heavy subsystem | More maintenance, less clarity | Start with design and one narrow E2E use case. |
| Codified skills go stale | False confidence in old flows | Fixture-staleness checks and periodic live revalidation. |
| Memory sync leaks sensitive data | Security/privacy incident | Default off, secret scan, allowlist, citations, privacy modes. |
| Agents overuse reusable flows when scenario differs | Missed bugs | Trigger matching must fall back to fresh E2E when uncertain. |
| Too many local artifacts clutter repo | Process drag | Artifact index, retention rules, `.gitignore` policy where appropriate. |
| Scope freeze blocks legitimate fixes | Slower delivery | Allow explicit override with issue comment justification. |
| CLI tooling diverges from VS Code tool model | Confusion | Keep CLI outputs machine-readable and document when agents should use them. |

## Success metrics

Track these before and after changes. Do not guess them.

| Metric | Target direction | Notes |
|---|---|---|
| Files read per phase | Down | Proxy for rediscovery. |
| Browser commands per E2E scenario | Down | Repeated flows should resolve to skills. |
| Tokens/context size per phase | Down | Needs tool or transcript measurement. |
| Re-invocations per subagent | Down | Good handoff reduces loops. |
| Time from issue to PR | Down | Throughput metric. |
| UAT pass rate on first implementation loop | Up | Quality metric. |
| E2E evidence attached per PR | Up | Delivery proof metric. |
| Process guard failures after PR open | Down | Earlier checks should catch issues. |

## Concrete next issues

1. **Add PipelineContext artifact index and context-budget fields**  
   Small, foundational, low risk.

2. **Design Speckit browser harness for low-token E2E exploration**  
   Architecture/design first, no implementation leap.

3. **Add machine-readable pipeline state and hygiene scripts**  
   Converts repeated issue/PR archaeology into JSON.

4. **Add project-scoped reusable E2E flow registry**  
   Speckit-native version of gstack browser-skills.

5. **Add optional Speckit memory provider interface**  
   Living docs first, GBrain-style backend optional.

6. **Add safety guard hooks for destructive and out-of-scope operations**  
   Runtime careful/freeze/guard mapped into Speckit.

## Bottom line

Speckit should stay process-first. That is its moat.

gstack’s best ideas should be treated as compression mechanisms:

- Compress browser exploration into a CLI.
- Compress repeated successful flows into tested skills.
- Compress phase handoff into `PipelineContext`.
- Compress repo memory into living docs and optional indexed lookup.
- Compress safety into hooks and deterministic checks.

The future system should feel like this:

> The agent spends tokens deciding what matters. Scripts and reusable skills do the boring exact work. Speckit proves the whole journey from issue to PR to UAT to E2E evidence.

That is the best of both worlds: lower token burn, higher delivery confidence, and a process that survives beyond one heroic chat session.
