---
name: speckit
description: >-
  Spec-driven development pipeline. Routes to the appropriate sub-skill based
  on the current phase: specify → research (optional) → plan (if complex) → implement → test → e2e → retro.
  Verify can be run at any point to check compliance.
  Use this when starting any new feature, bug, or chore — or when unsure which
  pipeline step to enter.
user-invocable: true
argument-hint: Describe what you want to build, fix, or change
---

# Speckit Pipeline

Spec-driven development with a lightweight, right-sized process.
One GitHub Issue per spec — no sub-issues, no intermediate task files.

## Pre-Execution: Path Resolution

`<speckit-root>` is the directory where **this SKILL.md** lives (the speckit pipeline root).
This is typically `.github/skills/speckit`.
All script paths below are relative to `<speckit-root>`.

## Pre-Execution: Ensure Installation

Before routing, run the install script to ensure all skills and agents are linked:

```bash
powershell -ExecutionPolicy Bypass -File <speckit-root>/install.ps1
```

If the script reports all links as `[skip] Already linked`, proceed immediately. Do not wait for user confirmation.

> **Note**: Only the router (this skill) and `speckit-specify` run the installer. Other sub-skills skip bootstrap — they are always invoked via the router or after specify has already bootstrapped.

## Pre-Execution: Constitution Gate

After installation, check whether a project constitution exists:

```powershell
powershell -ExecutionPolicy Bypass -File <speckit-root>/scripts/check-constitution.ps1 -WorkspaceRoot "<workspace-root>"
```

- If `exists` is `false`: **Route to `speckit-constitution` immediately** — the project needs governance principles before any pipeline work can begin. Tell the user: "No project constitution found. Let's establish one before proceeding."
- If `exists` is `true` but `valid` is `false`: **Route to `speckit-constitution` immediately** — the constitution still contains template placeholders. Tell the user: "Your constitution has unfilled placeholders. Let's complete it before proceeding."
- If `exists` is `true` and `valid` is `true`: Continue to routing logic below.

This applies to both greenfield and brownfield projects.

## Auto-Freshness Check

**Before starting the first pipeline phase** and **after the last phase completes**, ensure speckit is up to date:

```
run_in_terminal: powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1
```

This always downloads the latest release from GitHub and overwrites existing links (Force + Update are on by default). The command is idempotent — safe to run every time.

Pass `-NoUpdate` if you know the local copy is current (e.g., just installed). Pass `-NoForce` to skip overwriting existing links.

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → research → plan → implement → test → e2e → retro
Needs research only?                   specify → research → implement → test → e2e → retro
Simple & scoped?                       specify → implement → test → e2e → retro
```

> **Auto-continuation**: The entire pipeline runs without stopping to ask the user which step to take. `speckit-specify` auto-routes to the appropriate next phase based on complexity signal. From there, `research → plan → implement → test → e2e → retro` each invoke the next skill on success. Do NOT pause for user confirmation between steps. User interaction occurs only during **specify** (confirmation round) and when a step encounters a failure requiring user action.

## When to Use Each Phase

### Skills (loaded as active skill context)

| Phase | Skill | Use When |
|-------|-------|----------|
| **Specify** | `speckit-specify` | Starting new work — write spec, create GitHub Issue |
| **Research** | `speckit-research` | Technology unknowns — compare libraries, investigate patterns, assess options |
| **Plan** | `speckit-plan` | Work involves schema changes, new/changed APIs, or unfamiliar domain |
| **Implement** | `speckit-implement` | Ready to code — has a GitHub Issue number |
| **Constitution** | `speckit-constitution` | Setting up or updating project governance principles |
| **Verify** | `speckit-verify` | Check compliance of specs, plans, or code against the constitution |

### Agents (invoked via `runSubagent` with PipelineContext)

| Phase | Agent | Codename | Use When |
|-------|-------|----------|----------|
| **Test** | `speckit-test` | **Nightingale** | Implementation done — verify it satisfies the spec (UAT) |
| **E2E** | `speckit-e2e` | **Lovelace** | UAT passed — generate e2e test artifacts and attach to PR |
| **Retro** | `speckit-retro` | **Deming** | E2E captured — update living docs, triage TODOs |

### Internal Subagents (`.agent.md` — invoked by agents/skills via `runSubagent`, not directly by users)

All subagents operate under the [Subagent Autonomy Protocol](references/AGENT-PROTOCOL.md) — they do NOT follow human-in-the-loop. They resolve questions autonomously or escalate via a structured `## Unresolved Questions` block. Each has a **token bucket** limiting re-invocation attempts to prevent deadlocks.

| Subagent | Codename | Bucket | Used By | Purpose |
|----------|----------|--------|---------|---------|
| `speckit-codebase-scanner` | **Dijkstra** | 2 | `speckit-plan`, `speckit-research` | Read-only codebase exploration — returns distilled findings for design research |
| `speckit-living-docs-loader` | **Hypatia** | 1 | `speckit-specify` (one-time load) | Loads and compresses living docs into a focused context summary |
| `speckit-nexus` | **Babbage** | 2 | `speckit-specify` | Pre-reasoning — classifies work type, extracts problem/actors/constraints/edge cases |
| `speckit-e2e-browser` | **Turing** | 3 | `speckit-e2e` | Browser automation for UI project e2e testing via Playwright |
| `speckit-e2e-api` | **Berners-Lee** | 3 | `speckit-e2e` | HTTP exchange recording for API-focused e2e testing |
| `speckit-pipeline-checker` | **Hopper** | 2 | `speckit-verify` | Checks PR status checks (CI green/red/pending) |
| `speckit-web-researcher` | **Curie** | 3 | `speckit-research` | External web research for libraries, APIs, and best practices |

## Routing Logic

1. **No issue yet?** → Route to `speckit-specify`
2. **Issue exists, needs technology research?** → Route to `speckit-research`
3. **Issue exists, needs design?** → Route to `speckit-plan`
4. **Issue exists, ready to code?** → Route to `speckit-implement`
5. **Code done, needs UAT?** → Invoke `speckit-test` via `runSubagent` with PipelineContext
6. **UAT passed, need e2e?** → Invoke `speckit-e2e` via `runSubagent` with PipelineContext
7. **E2E done, PR created?** → Invoke `speckit-retro` via `runSubagent` with PipelineContext
8. **Setting up project governance?** → Route to `speckit-constitution`
9. **Checking compliance?** → Route to `speckit-verify`

### Invoking Agent Phases (test, e2e, retro)

For phases 5–7, use `runSubagent` instead of loading a skill SKILL.md:

```
runSubagent(agentName: "speckit-test", prompt: JSON.stringify({ pipelineContext: ctx }))
runSubagent(agentName: "speckit-e2e",  prompt: JSON.stringify({ pipelineContext: ctx }))
runSubagent(agentName: "speckit-retro", prompt: JSON.stringify({ pipelineContext: ctx }))
```

Each agent returns a structured JSON result. Use that result to:
- Update the `PipelineContext` with the agent's output fields
- Decide whether to proceed to the next phase or loop back (subject to circuit breaker)

## Pipeline Context (Handoff Protocol)

The router builds a `PipelineContext` JSON object incrementally across phases. See [HANDOFF-SCHEMA.md](references/HANDOFF-SCHEMA.md) for the full schema.

### Context Flow

1. **specify** → creates the context with identity fields, living context, and constitution compliance
2. **research** (optional) → adds `research` summary
3. **plan** (optional) → adds `plan` completion info
4. **implement** → adds `implementation` with PR details, base URL, commit SHA
5. **test** (agent) → adds `uat` with verdict and report
6. **e2e** (agent) → adds `e2e` with project type, pass/fail, artifacts
7. **retro** (agent) → consumes the full context, returns completion summary

### Staleness Check

Before passing context to a downstream phase, check:
```
if issue.updatedAt > context.livingContext.loadedAt → reload living context
```

If stale, re-invoke `speckit-living-docs-loader` and replace `livingContext` in the context before proceeding.

## Circuit Breaker

The router tracks retry counts per phase in `retryCount` within the PipelineContext. See [AGENT-PROTOCOL.md § Circuit Breaker](references/AGENT-PROTOCOL.md) for full rules.

**Before invoking any phase**, check:
```
if retryCount.{phase} >= 2 → STOP and escalate to user
```

**When a phase fails and auto-continues back** (e.g., test → implement → test), increment `retryCount.{re-entered phase}` before re-invoking.

On escalation, present:
- Which phase tripped the breaker
- The failure reason from the last attempt
- Suggestion for manual intervention

## Plan Gate

The plan phase is **complexity-gated, not type-gated**. Any work type (feature, bug, or chore) goes through `speckit-plan` when:

- Schema changes are involved
- New or changed APIs are introduced
- The domain is unfamiliar

Otherwise, skip directly from specify to implement.

## Artifact Boundaries

Keep these artifacts separate:

- **Specify** writes the spec into the **GitHub Issue body only**
- **Plan** appends design notes and a task checklist beneath that spec in the **same issue body**
- **Plan** and **Retro** update living docs in `docs/` only when needed
- Issue comments are supplementary discussion, not the canonical plan source
- Never create `specs/`, `spec.md`, or per-feature doc folders

## Skill & Agent Resolution Protocol

When a phase says "invoke `speckit-X`", determine whether it's a **skill** or an **agent**:

### Skills (specify, research, plan, implement, constitution, verify)

Resolve using this ordered fallback:

1. **VS Code skill discovery** — if `speckit-X` appears in the available skills list, use it directly.
2. **Direct file read** — if the skill is NOT in the available skills list, read the SKILL.md file at the path relative to `<speckit-root>`:
   ```
   <speckit-root>/skills/speckit-X/SKILL.md
   ```
   Then follow the instructions in the loaded file as if it were the active skill.
3. **Workspace fallback** — if the above path does not exist, try:
   ```
   .github/skills/speckit-X/SKILL.md
   ```
   (relative to the workspace root).

### Agents (test, e2e, retro)

Invoke via `runSubagent` with `agentName: "speckit-X"` and pass the `PipelineContext` as input. The agent file lives at:
```
<speckit-root>/agents/speckit-X.agent.md
```

**CRITICAL**: Never skip a pipeline step because "the skill/agent doesn't exist". The files are always present in the speckit installation directory — use `read_file` to load them directly if VS Code discovery fails.

## Key Principles

- **One issue per spec** — checklist in the issue body, no sub-issues
- **Issue IS the tracker** — no tasks.md file
- **Issue-backed specs only** — the spec lives in the GitHub Issue body, never in `spec.md`
- **Plan appends; it does not replace** — keep the original spec at the top of the issue body and append/update the plan beneath it
- **Living docs live in `docs/`** — update `docs/` in plan/retro, never create `specs/`
- **Right-sized artifacts** — only generate data-model, contracts, research when needed
- **Human-in-the-loop** — ask the next question at every step
- **Conventional commits** — every commit references the issue (`#N`)
- **PRs close issues** — `Closes #N` in PR description
