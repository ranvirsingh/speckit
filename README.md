# Speckit

[![Release](https://img.shields.io/github/v/release/ranvirsingh/speckit?label=release&color=brightgreen)](https://github.com/ranvirsingh/speckit/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Spec-driven development pipeline for AI-assisted coding agents.

## What is Speckit?

Speckit is a coordinated system of [Agent Skills](https://agentskills.io/) and subagents that turn a one-line idea into a shipped, tested, documented feature — without you babysitting the AI.

You describe what to build. Speckit writes a structured spec, creates a GitHub Issue, classifies the complexity, routes through the right phases (research, plan, implement, test, e2e), and — at "done-done" — updates your project's living documentation so the next cycle starts smarter.

## What's new in v2.1 (Agent Harness & Token Reduction)

- **Context Budgets.** Explicit `contextBudget.maxSourceLines` limits prevent prompt explosion. Downstream phases warn if they ingest too much code at once.
- **Artifact Indexing.** Re-discovery is eliminated. Phases now cache pointers (`artifactIndex`) to research comments, PR branches, and generated schemas so subsequent agents read exactly what they need.
- **Repo Memories.** The `/memories/repo/` convention creates durable, cross-phase repository memory for architectural principles and decisions, leveraging Copilot's repository-level context.
- **Phase Verdicts.** The pipeline now routes deterministically using `pass | fail | blocked` phase verdicts instead of conversational guesses.
- **New Agent:** Added `speckit-report-discussant` to handle specialized reporting and pipeline blocking scenarios.

## What's new in v2.0

- **Enforcement via frontmatter.** Every skill and agent declares its `tools:` allowlist; read-only subagents physically cannot edit files or run commands.
- **Model tiering.** FAST (GPT-5.3-Codex) for mechanical work, MID/DEEP (Sonnet 4.6) for reasoning, TOP (Opus 4.7) reserved for the constitution.
- **Lean roster (18 → 11 entities).** Removed agents that duplicated `#codebase`/`read_file`, wrapped a single CLI command, or were better folded into adjacent phases. Retro doc updates moved into `speckit-implement` done-done; repo hygiene checks moved into `speckit-verify --scope repo`.
- **Asset co-location.** Templates live next to the skill that owns them, fanned out by `install.ps1` into the host repo's `.github/`.
- **Draft-first PR flow.** `speckit-implement` opens PRs as drafts, runs `pipeline-guard` locally, then marks ready only on a clean check.
- **Dogfooded.** This repo runs its own pipeline (`.github/copilot-instructions.md`, PR template, issue templates, pipeline-guard workflow).

Full notes: [Releases](https://github.com/ranvirsingh/speckit/releases).

**Core principles:**

- **Spec-driven, not AI-driven** — humans define _what_ to build; the pipeline decides _how_ to execute it
- **Living docs vs transient specs** — living documents (`docs/`) persist in the repo and evolve across cycles; specs are transient GitHub Issues that drive a single feature, then close. The repo remembers patterns, schemas, and decisions; issues capture the work-in-flight
- **Auto-continuation** — the full pipeline runs without pausing to ask which step to take next
- **Constitution-gated** — no work starts without project governance in place
- **Right-sized artifacts** — only generate docs, schemas, and research when complexity demands it
- **Issue-backed accountability** — one GitHub Issue per feature, full lifecycle tracked in the issue body

## Pipeline Overview

```mermaid
flowchart TD
  START(["💬 User prompt"])

  subgraph GATE ["Constitution Gate"]
    CK{"docs/constitution.md<br/>exists &amp; valid?"}
    CON([Constitution])
  end

  START --> CK
  CK -- "missing or<br/>invalid" --> CON
  CON --> CK
  CK -- "✓ valid" --> S

  subgraph SPECIFY ["Phase 1 — Specify"]
    S([Specify])
  end

  subgraph ROUTE ["Routing Decision"]
    direction LR
    R1["🔬 complex<br/>research + plan"]
    R2["🔍 research<br/>needed"]
    R3["⚡ simple<br/>& scoped"]
  end

  S --> ROUTE

  subgraph RESEARCH ["Phase 2 — Research"]
    RE([Research])
    CU[[Curie — web<br/>research]]
    RE --- CU
  end

  subgraph PLAN ["Phase 3 — Plan"]
    PL([Plan])
  end

  R1 --> RE
  R2 --> RE
  RE -- "complex" --> PL
  R3 --> I
  RE -- "research only" --> I
  PL --> I

  subgraph IMPLEMENT ["Phase 4 — Implement (incl. done-done living-doc updates)"]
    I([Implement])
  end

  subgraph TEST ["Phase 5 — Test"]
    UAT([Test — UAT])
  end

  subgraph E2E ["Phase 6 — E2E"]
    E([E2E])
    TU[[Turing — browser<br/>Playwright]]
    BL[[Berners-Lee —<br/>API recording]]
    E -. "web-ui" .-> TU
    E -. "api" .-> BL
  end

  I --> UAT
  UAT -- "FAIL<br/>(max 2 retries)" --> I
  UAT -- "PASS" --> E
  E -- "FAIL<br/>(max 2 retries)" --> I

  subgraph VERIFY ["Verify — invocable at any point (--scope pr | --scope repo)"]
    V([Verify])
  end

  V -. "checks compliance" .-> I
  V -. "checks compliance" .-> S
  V -. "merge gate" .-> E

  classDef phase fill:#1f2937,color:#ffffff,stroke:#111827,stroke-width:2px;
  classDef sub fill:#334155,color:#e2e8f0,stroke:#475569,stroke-width:1px;
  classDef decision fill:#fbbf24,color:#1f2937,stroke:#f59e0b,stroke-width:2px;
  classDef gate fill:#dc2626,color:#ffffff,stroke:#b91c1c,stroke-width:2px;
  classDef route fill:#0ea5e9,color:#ffffff,stroke:#0284c7,stroke-width:1px;

  class S,RE,PL,I,UAT,E,RET,V,CON phase;
  class NX decision;
  class CK gate;
  class HY,DJ,DJ2,CU,TU,BL,HOP sub;
  class R1,R2,R3 route;
```

**Legend:** <span style="display:inline-block;width:12px;height:12px;background:#1f2937;border-radius:50%;"></span> Pipeline phase &nbsp; <span style="display:inline-block;width:12px;height:12px;background:#fbbf24;border-radius:4px;"></span> Decision node &nbsp; <span style="display:inline-block;width:12px;height:12px;background:#334155;border-radius:3px;"></span> Subagent &nbsp; <span style="display:inline-block;width:12px;height:12px;background:#0ea5e9;border-radius:3px;"></span> Route option &nbsp; <span style="display:inline-block;width:12px;height:12px;background:#dc2626;border-radius:4px;"></span> Gate &nbsp; Solid lines = execution flow &nbsp; Dashed lines = feedback / cross-cutting

### Three paths through the pipeline

| Complexity | Path | When |
|------------|------|------|
| **Complex** | Specify → Research → Plan → Implement → Test → E2E → Retro | Schema changes, new APIs, unfamiliar domain |
| **Research needed** | Specify → Research → Implement → Test → E2E → Retro | Library selection, tech unknowns, no architecture changes |
| **Simple** | Specify → Implement → Test → E2E → Retro | Clear scope, no design decisions |

The **Nexus** subagent classifies complexity during Specify and sets a `complexitySignal` (`research`, `plan`, or `implement`) that the router uses to pick the right path.

## Artifact Flow

Each phase produces or updates specific artifacts. The pipeline keeps the **issue-backed spec** and **living documents** separate on purpose.

```mermaid
flowchart LR
  subgraph ISSUE ["GitHub Issue Body"]
    direction TB
    SPEC["📋 Spec<br/><i>scenarios, requirements,<br/>success criteria, edge cases</i>"]
    PLAN_BLOCK["📐 Plan Block<br/><i>design notes, task checklist</i><br/><code>&lt;!-- speckit-plan:start/end --&gt;</code>"]
    SPEC --- PLAN_BLOCK
  end

  subgraph DOCS ["docs/"]
    direction TB
    DM["data-model.md"]
    CON["contracts/"]
    ADR["adr/"]
    RES["research.md"]
    RT["retro.md"]
    PK["PARKING_LOT.md"]
    CONST["constitution.md"]
  end

  subgraph CODE ["Deliverables"]
    direction TB
    PR["Pull Request"]
    TESTS["Unit &amp; integration tests"]
    E2E_ART["E2E artifacts<br/><i>GIFs, .http files, logs</i>"]
    UAT_RPT["UAT report<br/><i>pass/fail per scenario</i>"]
  end

  S([Specify]) -. "creates" .-> SPEC
  PH([Plan]) -. "appends" .-> PLAN_BLOCK
  PH -. "updates" .-> DM
  PH -. "updates" .-> CON
  PH -. "creates" .-> ADR
  RE([Research]) -. "writes" .-> RES
  IM([Implement]) -. "delivers" .-> PR
  IM -. "delivers" .-> TESTS
  T([Test]) -. "produces" .-> UAT_RPT
  E([E2E]) -. "captures" .-> E2E_ART
  R([Retro]) -. "refreshes" .-> RT
  R -. "triages TODOs" .-> PK
  R -. "updates" .-> DM
  R -. "updates" .-> CON
  CO([Constitution]) -. "creates" .-> CONST

  classDef phase fill:#1f2937,color:#ffffff,stroke:#111827,stroke-width:2px;
  classDef artifact fill:#f8fafc,color:#0f172a,stroke:#94a3b8,stroke-width:1px;
  classDef artifactGroup fill:#f1f5f9,color:#0f172a,stroke:#cbd5e1,stroke-width:1px;

  class S,PH,RE,IM,T,E,R,CO phase;
  class SPEC,PLAN_BLOCK,DM,CON,ADR,RES,RT,PK,CONST,PR,TESTS,E2E_ART,UAT_RPT artifact;
```

**Legend:** Dark nodes = pipeline phases &nbsp; Light nodes = artifacts &nbsp; **GitHub Issue Body** = transient (per-feature, closes on merge) &nbsp; **docs/** = living (persists across cycles, evolves) &nbsp; **Deliverables** = shipped output

**Living vs Transient:**

| | Living Documents | Transient Specs |
|---|---|---|
| **Where** | `docs/` — committed to the repo | GitHub Issue body |
| **Lifespan** | Persist and evolve across many cycles | Created per feature, close when PR merges |
| **Updated by** | Plan and Retro only | Specify (create), Plan (append), Implement (tick tasks) |
| **Examples** | `data-model.md`, `contracts/`, `retro.md`, `constitution.md`, `PARKING_LOT.md` | Issue #42 spec + plan block |
| **Purpose** | Institutional memory — the repo remembers | Work-in-flight — drives a single feature |

**Rules:**

- The issue body is the canonical spec. **Specify** writes the top; **Plan** appends below it. Neither replaces the other.
- Living docs live in `docs/` — updated only by **Plan** and **Retro**.
- No `specs/` directory. No local `spec.md` files. No per-feature doc folders.
- Artifacts are right-sized: `data-model.md` is only created when schemas change, `contracts/` only when APIs change, ADRs only for significant decisions.

## Skills

User-invocable skills triggered via slash commands in VS Code:

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| speckit | `/speckit` | Pipeline router — checks constitution, classifies complexity, routes to the right phase |
| speckit-specify | `/speckit-specify` | Write a structured spec (scenarios, requirements, success criteria) and create a GitHub Issue |
| speckit-research | `/speckit-research` | Investigate technologies, compare libraries, assess patterns — writes to `docs/research.md` |
| speckit-plan | `/speckit-plan` | Design architecture, append design notes and task checklist to the issue body, update living docs |
| speckit-implement | `/speckit-implement` | Execute task checklist, code, test, commit, push, create PR (auto-closes issue via `Closes #N`) |
| speckit-constitution | `/speckit-constitution` | Create or update project governance in `docs/constitution.md` with MUST/SHOULD/NON-NEGOTIABLE rules |
| speckit-verify | `/speckit-verify` | Check compliance against constitution rules, test patterns, naming conventions, CI status |

## The Agents — A Coordinated Ensemble

Speckit is a **persona-driven agency** — a small set of agents, each named after a pioneer whose philosophy shapes how they think and what they contribute to the shared context. The roster has been deliberately trimmed to the entities that earn their keep: anything VS Code's built-in `#codebase` semantic search, a one-line `gh` command, or the parent LLM can already do has been folded back in instead of wrapped in a subagent.

Every agent follows the [Subagent Autonomy Protocol](references/AGENT-PROTOCOL.md): **never ask the user**, resolve what you can with tools, escalate only via structured partial results. Token buckets cap re-invocations to prevent deadlocks.

### Curie — _The Empiricist_ (speckit-web-researcher)

> _"Evidence beats hype. Measure everything."_

Named after Marie Curie, rigorous empiricist. Curie evaluates libraries on measurable signals: maintenance frequency, weekly downloads, bundle size, TypeScript support, security advisories. She flags red flags explicitly (stale packages, <1000 weekly downloads, 6+ months without update) and presents options with weights — never dictates. Invoked by **Research**. Bucket: **3**.

### Nightingale — _The Verifier_ (speckit-test)

> _"Spec is truth. Implementation proves truth."_

Named after Florence Nightingale, pioneer of evidence-based practice. Nightingale's obsession is testable proof. Every acceptance scenario, functional requirement, success criterion, and edge case must be verifiable in code or test runs. Acceptance scenarios are the primary gate; she doesn't soften on constitution violations — NON-NEGOTIABLE rules are hard stops. Produces a structured **UAT report** with per-item pass/fail tables. Bucket: **2**.

### Lovelace — _The E2E Orchestrator_ (speckit-e2e)

> _"Synthesis of evidence is proof. Show, don't tell."_

Named after Ada Lovelace, first programmer and computational synthesizer. Lovelace recognizes that different projects need different evidence. She detects the project type (`web-ui` / `api` / `cli` / `library` / `infrastructure`), delegates to the right specialist — **Turing** for browsers, **Berners-Lee** for APIs — then synthesizes all evidence into PR comments with raw GitHub URLs. Bucket: **2**.

### Turing — _The UI Choreographer_ (speckit-e2e-browser)

> _"If users can't see it work, it didn't work."_

Named after Alan Turing, pioneer of machine testing. Turing converts user scenarios into Playwright test choreography. He records video, converts to compact GIFs (8fps, 640px, <5MB), pushes assets to an orphan `e2e-assets` branch, and embeds proof directly in the PR. If tests fail, he reports exact error messages so implementers know precisely what to fix. Bucket: **3**.

### Berners-Lee — _The HTTP Diplomat_ (speckit-e2e-api)

> _"Every request/response pair is a contract. Verify it."_

Named after Tim Berners-Lee, inventor of the Web. Berners-Lee speaks HTTP fluently. He creates `.http` request files, executes them via curl, captures full exchanges (headers + body), and produces structured proof tables. For API projects, he's the acceptance test runner who demonstrates every scenario with real HTTP exchanges. Bucket: **3**.

## Focused Context — How the Agents Share What Matters

The essence of Speckit is **focused context**: every agent receives exactly what it needs — no more, no less. Context flows through two mechanisms working in concert.

### 1. PipelineContext — The Accumulating Handoff

A JSON object built incrementally as the pipeline progresses. Each phase enriches it; downstream phases inherit everything upstream learned. No re-discovery, no re-scanning.

```mermaid
flowchart LR
  subgraph PC ["PipelineContext"]
    direction TB
    L1["<b>Specify</b><br/>issueNumber, branch, workType,<br/>specNumber, complexitySignal"]
    L2["<b>+ livingContext</b><br/>focused summary of relevant docs<br/>read directly via #codebase / read_file<br/>retro patterns · constitution rules · schema state"]
    L3["<b>+ Research</b><br/>summary, completedAt"]
    L4["<b>+ Plan</b><br/>taskCount, completedAt"]
    L5["<b>+ Implement</b><br/>prNumber, prUrl, commitSha, baseUrl"]
    L6["<b>+ Test</b><br/>verdict, passCount, failCount, report"]
    L7["<b>+ E2E</b><br/>projectType, passed, artifacts[]"]
    L1 --- L2 --- L3 --- L4 --- L5 --- L6 --- L7
  end

  classDef ctx fill:#f0fdf4,color:#14532d,stroke:#86efac,stroke-width:1px;
  class L1,L2,L3,L4,L5,L6,L7 ctx;
```

A **circuit breaker** tracks `retryCount` per phase — if any phase fails twice, the pipeline stops and escalates to the user instead of looping.

See [HANDOFF-SCHEMA.md](references/HANDOFF-SCHEMA.md) for the full schema.

### 2. Focused Living-Doc Reads — The Context Membrane

Living docs can be thousands of lines. Each phase reads only what it needs via `#codebase` semantic search and direct `read_file` calls, focused on the work in scope:

| Source Document | Typical Consumers | Why |
|-----------------|-------------------|-----|
| `docs/retro.md` | All phases | Avoid repeating past mistakes (last few entries are usually enough) |
| `docs/constitution.md` | Specify (compliance gate), Verify, Test | Numbered MUST/SHOULD/NON-NEGOTIABLE rules |
| `docs/data-model.md` | Plan, Implement | Entity summary + recent changelog entries |
| `docs/contracts/*.md` | Plan, Implement | Endpoint inventory and status |

`speckit-implement` closes the loop at done-done — it updates these same documents at the end of every cycle, so the **next** cycle starts with accurate context. The pipeline learns.

### 3. What Each Agent Contributes Downstream

```mermaid
flowchart TD
  CU["🔬 <b>Curie</b><br/>tech recommendations &amp; risks"]
  NG["✅ <b>Nightingale</b><br/>UAT verdict &amp; failing scenarios"]
  LV["🎯 <b>Lovelace</b><br/>E2E verdict &amp; artifact URLs"]
  TU["🎬 <b>Turing</b><br/>GIFs &amp; screenshots"]
  BL["📡 <b>Berners-Lee</b><br/>HTTP exchanges"]

  CU --> |"evidence"| PLAN_IMPL["Plan &amp; Implement"]
  NG --> |"PASS → continue<br/>FAIL → retry implement"| ROUTER["Router — retry or continue"]
  LV --> |"proof in PR"| PR["Pull Request"]
  TU --> |"visual proof"| LV
  BL --> |"API proof"| LV
  VERIFY["Verify — any-phase compliance check<br/>(--scope pr or --scope repo)"] --> |"merge gate"| PR

  classDef agent fill:#1e293b,color:#f8fafc,stroke:#334155,stroke-width:2px;
  classDef target fill:#f8fafc,color:#0f172a,stroke:#94a3b8,stroke-width:1px;

  class CU,NG,LV,TU,BL agent;
  class ROUTER,PLAN_IMPL,PR,VERIFY target;
```

**Legend:** Dark nodes = subagents (each named after a pioneer) &nbsp; Light nodes = pipeline targets they feed into &nbsp; Arrows show what each agent contributes and who consumes it

> The installer copies all agents into `.github/agents/` for automatic discovery. No `settings.json` changes needed.

### The Learning Loop

Speckit is cyclical by design. The end of one cycle primes the next:

1. `speckit-implement` (done-done) updates `docs/retro.md`, `data-model.md`, `contracts/`, and triages TODOs to `PARKING_LOT.md` immediately after the PR is created.
2. The **next** `speckit-specify` invocation reads those updated docs directly via `#codebase` / `read_file` and uses them as focused context.
3. The complexity signal it derives from that context routes the next piece of work more accurately.
4. Parking lot items from the previous cycle become candidates for future specs.

Every cycle makes the pipeline smarter: past mistakes surface as retro patterns, schema drift gets corrected, and discovered TODOs feed future work.

## Constitution & Governance

Every pipeline run starts with a **constitution gate**: if `docs/constitution.md` is missing or has unfilled template placeholders, the router redirects to `speckit-constitution` before any work begins.

The constitution contains principles marked as:

| Severity | Meaning |
|----------|---------|
| **NON-NEGOTIABLE** | Blocks the pipeline — zero tolerance |
| **MUST** | Required — violations are errors |
| **SHOULD** | Recommended — violations are warnings |

`speckit-verify` extracts these rules and checks compliance across code, tests, commits, naming, and CI status.

## Extension Hooks

Speckit supports lifecycle hooks via `.specify/extensions.yml` in the project root. Each skill checks for hooks at `before_` and `after_` lifecycle points (e.g., `hooks.before_specify`, `hooks.after_implement`).

```yaml
# .specify/extensions.yml
hooks:
  before_specify:
    - extension: "my-linter"
      command: "run-lint"
      optional: true
  after_implement:
    - extension: "my-notifier"
      command: "notify-team"
      optional: false
```

See [HOOKS.md](references/HOOKS.md) for the full hook execution procedure.

## Installation

### Quick install (recommended)

```pwsh
# From the root of your project (requires pwsh — see Requirements below):
& ([scriptblock]::Create((Invoke-RestMethod https://raw.githubusercontent.com/ranvirsingh/speckit/main/install.ps1)))
```

This downloads the latest release zip, extracts it to `.github/skills/speckit/`, and links everything for VS Code discovery.

### Manual install

```bash
# 1. Download the latest release zip from GitHub
# 2. Extract to .github/skills/speckit/
# 3. Run the installer
pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

### Updating

```pwsh
# Re-run the installer — it auto-updates from GitHub and overwrites by default
pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

The installer copies everything into `.github/` for VS Code discovery:
- Sub-skills → `.github/skills/speckit-specify`, `speckit-plan`, `speckit-research`, `speckit-implement`, `speckit-verify`, `speckit-constitution`
- Subagents → `.github/agents/speckit-web-researcher.agent.md`, `speckit-e2e-browser.agent.md`, `speckit-e2e-api.agent.md`, `speckit-test.agent.md`, `speckit-e2e.agent.md`, `speckit-report-discussant.agent.md`
- Canonical assets fanned out into `.github/` (PR template, issue templates, `pipeline-guard.yml` workflow)
- Updates `.gitignore` to exclude the generated copies **and** `.github/skills/speckit/` itself

> **After cloning**: Since speckit is gitignored, each developer runs the install one-liner once after cloning the repo. The installer always pulls the latest release.

To uninstall: `pwsh -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1 -Uninstall`

## Requirements

- VS Code with GitHub Copilot
- **[PowerShell Core (`pwsh`)](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)** — cross-platform, required on all OSes:
  - Windows: `winget install Microsoft.PowerShell` or [MSI installer](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
  - macOS: `brew install --cask powershell`
  - Linux: [package manager instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)
- GitHub CLI (`gh`) for issue/PR management
- Git for version control

## License

This project is licensed under the [MIT License](LICENSE).

Inspired by [github/spec-kit](https://github.com/github/spec-kit).
