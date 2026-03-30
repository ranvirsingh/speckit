---
name: speckit-retro
description: >-
  Run a fully automated post-implementation retrospective to update living documents, verify 
  consistency, close the loop, and triage discovered TODOs to the parking lot. No user input 
  required — the AI agent observes the implementation session and writes the retrospective 
  autonomously. Use this skill after speckit-implement completes — for any work type 
  (feature, bug, or chore). Updates data model docs, API contracts, ADRs, and triages 
  TODO(speckit) markers into PARKING_LOT.md entries.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).
The input should include a GitHub Issue number (e.g. `#18`). If not provided, ask the user for it.

## Goal

After implementation is complete, ensure all living documents reflect the actual state of the codebase, close tracking issues, and **triage any discovered TODOs back into the specify phase** — creating a feedback loop.

## Outline

### Step 1: Update Living Documents

1. **Setup**: Read the GitHub Issue to get context:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --json body,title,labels
   ```
   Determine work type from labels (bug/chore/feature). Get the current branch: `git branch --show-current`.

2. **Scan for implementation changes**: Compare the current codebase state against what existed before implementation. Focus on:
   - New or modified migration/schema files (scan for `migrations/` directories or schema files)
   - New or modified shared type definitions (scan for type definition files in shared/common packages)
   - New or modified API routes or handlers (scan for route/handler definitions)
   - New or modified UI components (scan for frontend packages/directories)

3. **Update living documents** (check each, update only if changes are relevant):

   #### a. Data Model (`docs/data-model.md`)
   - Compare migration SQL files against the documented tables/columns
   - Compare TypeScript type definitions against the documented entities
   - If discrepancies found: update `docs/data-model.md` with new tables, columns, constraints, indexes
   - Add a changelog entry at the bottom with the spec number and date

   #### b. API Contracts (`docs/contracts/`)
   - If new API routes were added or existing ones modified, check if contract documentation exists in `docs/contracts/`
   - If contracts are outdated or missing for new routes: flag for user attention (do not auto-generate)

   #### c. Architecture Decision Records (`docs/adr/`)
   - If the implementation introduced a significant architectural choice (new dependency, pattern change, technology swap), ask the user if an ADR should be created
   - If yes: create `docs/adr/adr-NNN-{topic}.md` using this skill's `assets/adr-template.md`

   #### d. Type Consistency
   - Cross-reference shared type definitions against migration SQL
   - Flag any fields present in SQL but missing from types (or vice versa)
   - Offer to fix type mismatches directly

### Step 2: Verify Completion

- For **Features**: Check the GitHub Issue checklist — all tasks should be marked `[x]`
  1. Read the issue body and parse for unchecked items (`- [ ]`)
- For **Bugs/Chores**: Check that all verification items in the issue body are marked complete
- If incomplete items exist, list them and proceed with the retro (flag the incomplete items in the retro entry).

### Step 3: Close GitHub Issue

1. Get the Git remote: `git config --get remote.origin.url`
2. Extract `owner` and `repo`
3. The issue will auto-close when the PR (created by `speckit-implement`) is merged via `Closes #N`. No manual close needed.

### Step 4: TODO Triage (the feedback loop)

This step picks up items discovered during implementation and feeds them back into the parking lot for future prioritisation.

#### 4a. Scan for TODO(speckit) markers

Search the codebase for `TODO(speckit):` comments:

```bash
grep -rn "TODO(speckit):" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.rs" --include="*.go" .
```

Collect each marker with its file path, line number, and content.

#### 4b. Classify and add to Parking Lot

For each discovered item:
1. Classify as Bug, Chore, or Feature idea
2. Append to `docs/PARKING_LOT.md` with source reference and classification
3. Replace the `TODO(speckit):` marker in the code with a reference to the parking lot entry:
   ```typescript
   // See PARKING_LOT.md — {brief description}
   ```

#### 4c. Report triage results

```markdown
## TODO Triage Summary

| # | Source | Classification | Title | Added To |
|---|--------|---------------|-------|----------|
| 1 | src/example.ts:42 | Bug | RTL not handled | PARKING_LOT.md |
| 2 | src/service.ts:88 | Chore | Duplicate validation | PARKING_LOT.md |

**Total**: N items triaged → N parking lot entries added
```

If no TODO(speckit) markers found, report: "No discovered items to triage."

---

### Step 5: Documentation Hygiene Audit

Review the documentation that was consulted or could have been consulted during implementation and flag issues.

#### 5a. Detect outdated / misleading docs

Scan these locations for docs that **contradicted** the actual implementation:

- `docs/` — living docs (data-model.md, constitution.md, contracts/, research.md, ADRs, deployment.md, etc.)
- Skill `assets/` folders — templates that may have guided generation of incorrect artifacts
- `README.md` files in any package

For each file reviewed, check:
1. **Does it describe behaviour or structure that no longer matches the codebase?**
2. **Did any doc actively mislead the implementation?**
3. **Are there instructions or references to old tools/skills/workflows?**

Report findings:

```markdown
## Doc Hygiene Audit

| Doc | Issue | Severity | Action |
|-----|-------|----------|--------|
| docs/data-model.md | `status` column renamed to `state` but doc still says `status` | Misleading | Update doc |
| docs/contracts/api.md | References route that was moved | Outdated | Update |
| docs/deployment.md | Lists manual deploy steps; CI handles this now | Unnecessary | Flag for removal |
```

If no issues found, report: "All docs are current — no hygiene issues detected."

#### 5b. Flag docs for removal

For each flagged doc, ask the user whether to:
1. **Delete** — remove the file entirely
2. **Archive** — move to a `docs/archive/` directory
3. **Keep** — leave as-is

Do NOT delete docs without user confirmation. For other fixes (misleading content, outdated refs), apply the correction directly.

#### 5c. Apply fixes

For docs flagged as "Misleading" or "Outdated" where the fix is clear, apply the correction directly. No user prompt needed — just fix and report what was changed.

---

### Step 6: Append to Living Retrospective Log

The project maintains a **living retrospective document** at `docs/retro.md`.

#### 6a. Observe and reflect (automated — no user prompt)

Based on what you observed during implementation, determine:
1. **What went well?** — things that worked smoothly, clean implementations, good test coverage, etc.
2. **What could be better?** — blockers, friction, scope misses, infrastructure issues, etc.
3. **Process / tooling ideas?** — improvements to workflow, CI, testing, etc.
4. **Any docs that misled?** — docs that were incorrect or out of date (captured in Step 5)

Do NOT ask the user for input. Write the reflection yourself based on your observations during the implementation session.

#### 6b. Append a new entry to `docs/retro.md`

Append a new section to the **bottom** of `docs/retro.md` (after the last entry or the `<!-- New entries -->` comment):

```markdown
### {spec-number} — {feature title}

**Type**: Feature | Bug | Chore
**Branch**: {branch}
**Date**: {today}
**Issue**: #{issue-number}

#### Went Well
- {observed items}

#### Could Be Better
- {observed items}

#### Process / Tooling Ideas
- {observed items}

#### Metrics
- **Tasks**: {completed}/{total}
- **Discovered TODOs**: {count} → {count} parking lot entries
- **Doc Hygiene**: {N} issues found ({N} fixed, {N} flagged for removal, {N} kept)
- **Docs Updated**: {list or "none"}
- **ADRs Created**: {list or "none"}

---
```

#### 6c. Update Process Health summary

After appending the entry, review **all** entries in `docs/retro.md` and update the three "Process Health" sections at the top:

- **What's Working Well** — items in 2+ "Went Well" sections (keep max 5 bullets)
- **Recurring Pain Points** — items in 2+ "Could Be Better" sections (keep max 5 bullets)
- **Tooling & Capability Gaps** — gaps from "Process / Tooling Ideas" that are actionable

Only update these sections when there are 2+ entries.

---

### Step 7: Generate Completion Summary

```markdown
## Retrospective: {spec-number} — {feature title}

**Type**: Feature | Bug | Chore
**Branch**: {branch}
**Date**: {today}
**Issue**: #{issue-number}

### Documents Updated
- [ ] docs/data-model.md — {changes or "No changes needed"}
- [ ] docs/retro.md — Entry appended
- [ ] docs/adr/ — {new ADR or "No new ADRs"}
- [ ] types.ts — {changes or "No changes needed"}

### Issues Closed
- {list}

### Doc Hygiene
- {N} docs audited, {N} issues found ({N} fixed, {N} flagged)

### TODOs Triaged
- {N} items discovered → {N} parking lot entries added

### Suggested Commit Message
`docs: retrospective for {spec-number} — update living docs and retro log`
```

## Workflow Position

```
With plan:    speckit-specify → speckit-plan → speckit-implement (includes commit+PR) → speckit-retro (automated)
Without plan: speckit-specify → speckit-implement (includes commit+PR) → speckit-retro (automated)
```

The plan phase is complexity-gated, not type-gated. Any work type (feature, bug, or chore) goes
through speckit-plan when it involves schema changes, new/changed APIs, or an unfamiliar domain.

The TODO triage step feeds discovered work **into the parking lot** for future prioritisation:

```
speckit-specify → speckit-plan → speckit-implement (commit+PR) → speckit-retro
                                                                       |
                                                   PARKING_LOT.md ←───┘
```
