---
name: speckit-living-docs-loader
description: Loads and compresses living documents into a focused context summary for speckit skills.
user-invocable: false
model: ['Claude Haiku 4.5 (copilot)', 'Gemini 3 Flash (Preview) (copilot)', 'GPT-5.4 (copilot)']
---

## Purpose

Load living documents and return a **compressed summary** — not raw markdown.
Saves context tokens by distilling multiple docs into a focused context block.

## Input

The invoking agent provides:
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

### Data Model (current state)
| Entity | Key Fields | Relationships |
|--------|-----------|---------------|
| ...    | ...       | ...           |

Recent changes: {last 3 changelog entries}

### Contracts
| Contract | Status | Endpoints |
|----------|--------|-----------|
| ...      | ...    | ...       |
```

## Constraints

- **Read-only** — do not modify any files.
- **Cap output** — total summary must be under 200 lines.
- **Skip missing files** — do not report errors for missing docs, just omit the section.
- **Summarize, don't copy** — never return raw file contents longer than 10 lines.
