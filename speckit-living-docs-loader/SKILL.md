---
name: speckit-living-docs-loader
description: >-
  Read-only subagent that loads and summarizes living documents (retro.md, constitution.md,
  data-model.md, contracts/*) into a compressed context block. Returns only actionable
  insights. Invoked at the start of any skill that needs living context. Not user-invocable.
---

## Purpose

Load living documents and return a **compressed summary** — not raw markdown.
Saves context tokens by distilling multiple docs into a focused context block.

## Input

The invoking skill provides:
1. **Doc paths** — list of files to load (typically `docs/retro.md`, `docs/constitution.md`, `docs/data-model.md`, `docs/contracts/*`)
2. **Work context** — brief description of the current task (to prioritize which insights matter)

## Procedure

1. **Check which docs exist** — skip missing files silently.

2. **Load and summarize each doc**:

   ### `docs/retro.md`
   - Extract the **Process Health** section (What's Working Well, Recurring Pain Points, Tooling Gaps)
   - From entries: last 5 entries only, extract just the key patterns (what went well, what didn't)
   - If >10 entries exist, summarize overall trends instead of individual entries
   - **Output**: 5-10 bullet points of actionable patterns

   ### `docs/constitution.md`
   - Extract all MUST/SHOULD principles as a bullet list
   - Include the governance rules (amendment procedure, compliance expectations)
   - Skip boilerplate, headers, and formatting — just the rules
   - **Output**: Numbered list of principles (max 10 items)

   ### `docs/data-model.md`
   - Extract the current entity list with key fields and relationships
   - Include the most recent changelog entries (last 3)
   - Skip full column definitions unless the work context involves schema changes
   - **Output**: Entity summary table + recent changes

   ### `docs/contracts/*.md`
   - List existing contracts with their status (draft/ratified)
   - Summarize endpoints/interfaces defined
   - **Output**: Contract inventory table

3. **Prioritize by work context** — highlight findings most relevant to the current task.

## Output Format

Return a single structured block:

```markdown
## Living Context Summary

**Task**: {work context}

### Retro Insights
- {insight 1 — relevant pattern from past work}
- {insight 2}
- ...

### Constitution Principles
1. {principle — MUST/SHOULD rule}
2. {principle}
...

### Current Data Model
| Entity | Key Fields | Relationships |
|--------|-----------|---------------|
| {name} | {fields} | {relations} |

**Recent changes**: {last 3 changelog entries}

### Active Contracts
| Contract | Status | Summary |
|----------|--------|---------|
| {name} | {status} | {brief description} |

### Relevance Notes
- {what from the living docs is most relevant to the current task}
- {what to watch out for based on retro patterns}
```

## Rules

- **Read-only** — never modify living docs
- **Compress aggressively** — the whole output should be <200 lines
- **Skip empty sections** — if a doc doesn't exist or has no relevant content, omit its section
- **Highlight conflicts** — if constitution principles conflict with retro patterns, flag it
- **Cap retro entries** — never load more than the last 5 entries; summarize trends if >10 exist
