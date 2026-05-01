---
name: speckit-research
user-invocable: true
model: Claude Sonnet 4.6 (copilot)
tools: ['search', 'codebase', 'web', 'fetch', 'editFiles', 'runCommands', 'githubRepo']
agents: ['speckit-web-researcher']
description: >-
  Research assistant that investigates both the internal codebase and external resources
  (libraries, APIs, design patterns, best practices) to inform architectural decisions.
  Use between specify and plan, or standalone when you need technology research.
  Posts findings as a GitHub Issue comment. Triggers on requests like "research options for",
  "investigate approaches", "compare libraries", "what's the best way to", or "explore before planning".
---

## Issue State Tracking

On entry, advance the Issue State to "Research". Read `.speckit-project.json` from the workspace root for `projectNumber` and `owner`. If the file does not exist, skip silently.

```powershell
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/set-issue-state.ps1 -ProjectNumber {projectNumber} -Owner {owner} -IssueNumber {issueNumber} -Repo {owner}/{repo} -State "Research"
```

## PipelineContext Fields

See [HANDOFF-SCHEMA.md](../../references/HANDOFF-SCHEMA.md) for the full schema.

- **Reads**: `livingContext`, `constitutionCompliant`, `artifactIndex` (if present, to reuse prior research pointers).
- **Writes**: `artifactIndex.researchCommentId` (the GitHub comment ID for the `<!-- speckit-research:start -->` block), `phaseVerdicts.research` (`pass`/`fail`/`blocked` with notes), and OPTIONAL durable findings as `/memories/repo/{slug}.md` entries with `category: "architecture-principle"`, `"repo-fact"`, or `"decision"`.

## Next Steps (AUTO-CONTINUE)

After research is complete, **automatically proceed** — do NOT stop to ask or suggest:
- If the work needs planning (schema/API/unfamiliar domain): invoke `speckit-plan #{issue-number}` immediately.
- If the work is simple & scoped: invoke `speckit-implement #{issue-number}` immediately.

> **Skill resolution**: If a skill is not in your available skills list, use `read_file` to load its SKILL.md directly from `.github/skills/{skill-name}/SKILL.md` (or `.github/skills/speckit/skills/{skill-name}/SKILL.md` inside the bundle). Never skip a pipeline step because a skill appears unavailable.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).
The input should include a GitHub Issue number and/or a description of what to research.

## Pre-Execution Checks

### Load Living Context

Read the relevant living docs directly with the `read_file` / `#codebase` tools — only what you need for the current research scope:

- `docs/constitution.md` — for any technology / architecture constraints
- `docs/data-model.md` — for the existing schema
- (optional) Prior research from earlier issue comments via `gh issue view {N} --repo {owner}/{repo} --comments`

Keep what's relevant to the research questions. Skip the rest.

**Check for extension hooks (before research)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.before_research`.

## GitHub Issue Gate (RECOMMENDED)

A GitHub issue is recommended but not mandatory. Research can be performed standalone.

1. Parse `$ARGUMENTS` for a GitHub issue reference (number or `#number`).
2. If an issue number is found, read the issue to extract the spec and acceptance criteria.
3. If no issue number is found, use the user's free-text description as the research scope.

## Outline

### Step 1 — Define Research Questions

Based on the spec (or user description), identify the concrete unknowns:

1. **Technology choices** — Which libraries/frameworks to use?
2. **Architecture patterns** — What design pattern fits this problem?
3. **Integration points** — How to connect with existing systems/APIs?
4. **Data model impact** — What schema changes are needed?
5. **Performance considerations** — Will this approach scale?
6. **Security implications** — Any auth/authz/data-handling concerns?

Present the research questions to the user for confirmation before proceeding. Add or remove questions based on their feedback.

### Step 2 — Internal Codebase Research

Use the built-in `#codebase` semantic search and `grep_search` to investigate the internal-focused subset of questions: existing patterns, current architecture, tech debt in the affected area.

Focus on:
- Existing patterns and conventions
- Relevant file locations
- Gaps that need to be filled
- Cross-cutting concerns

### Step 3 — External Web Research

Use the `runSubagent` tool with `agentName: "speckit-web-researcher"` and provide:
- **spec**: The feature spec
- **questions**: The external-focused subset of questions (library selection, best practices, API documentation)
- **techStack**: The project's detected tech stack (from Step 2 findings)
- **constraints**: Any constitution constraints on technology choices

The web researcher uses the **Gemini CLI** for all web-grounded research.

**If the web-researcher subagent is unavailable**, run Gemini CLI queries directly via `run_in_terminal`:

```
gemini -p "Search for: <query>. Provide a concise summary with source URLs." --model flash --output-format text --approval-mode yolo
```

- Use `--model flash` for straightforward lookups (~90% of queries); use `--model pro` for complex multi-source synthesis.
- Craft specific, context-rich queries that include the tech stack.
- One focused question per invocation — chain multiple calls for multi-part questions.
- For deep research, chain a search query followed by targeted URL fetch queries.
- Always preserve source URLs in the output.

The web researcher will return:
- Library/package comparisons with evidence
- Design pattern recommendations
- API integration guidance
- Risk assessments

### Step 4 — Synthesise Findings

Combine internal and external research into a cohesive analysis:

1. **Cross-reference** internal patterns with external recommendations
2. **Identify conflicts** between existing codebase conventions and recommended approaches
3. **Flag trade-offs** that require human decision-making
4. **Prioritise options** based on fit with existing architecture and constitution

### Step 5 — Post Research to GitHub Issue Comment

Post the research findings as a GitHub Issue comment (do not write to `docs/research.md` or modify the issue body). If no issue number is available (standalone invocation), fall back to writing `docs/research.md`.

#### When an issue number is available

1. Check for an existing research comment:
   ```bash
   gh issue view {ISSUE_NUMBER} --repo {owner}/{repo} --comments --json comments
   ```
   Search the returned comments for one containing `<!-- speckit-research:start -->`.

2. Compose the research comment:

   ```markdown
   <!-- speckit-research:start -->
   ### Research: #{issue-number} — {title}

   **Date**: {today}
   **Scope**: {brief description of what was researched}
   **Status**: Complete

   #### Research Questions

   1. {question 1}
   2. {question 2}

   #### Internal Findings

   {Summary of codebase scanner results — existing patterns, conventions, gaps}

   #### External Findings

   {Summary of web researcher results — library comparisons, best practices, recommendations}

   #### Synthesis

   | Decision Area | Options | Recommendation | Confidence |
   |--------------|---------|---------------|------------|
   | {area} | {A, B, C} | {recommended} | High/Medium/Low |

   #### Open Questions

   - {Questions that couldn't be answered by research alone — need human input or prototyping}

   #### Risk Register

   | Risk | Likelihood | Impact | Mitigation |
   |------|-----------|--------|------------|
   | {risk} | Low/Med/High | Low/Med/High | {strategy} |

   ---
   _Research posted by speckit-research._
   <!-- speckit-research:end -->
   ```

3. Post or update the research comment:
   - **If no existing research comment**: Create a new comment:
     ```bash
     gh issue comment {ISSUE_NUMBER} --repo {owner}/{repo} --body "{research comment body}"
     ```
   - **If an existing research comment was found**: Edit that comment:
     ```bash
     gh api repos/{owner}/{repo}/issues/comments/{comment_id} -X PATCH -f body="{research comment body}"
     ```

#### Standalone fallback (no issue number)

If `docs/research.md` does not exist, initialise it from this skill's `assets/RESEARCH.TEMPLATE.md`.

Append a new research entry to `docs/research.md` using the same format above (without the HTML markers).

### Step 6 — Present Summary

Present the key findings and recommendations to the user. Highlight:
- The top 1-3 decisions that need to be made
- Any high-confidence recommendations that can proceed immediately
- Open questions that need human input
- Risks that should be accepted or mitigated during planning

**Check for extension hooks (after research)**:
Follow the [hook execution procedure](../../references/HOOKS.md) with `hookKey = hooks.after_research`.

## Gotchas

- **Research is not planning** — don't create task lists, ADRs, or implementation plans. That's speckit-plan's job.
- **Present options, don't decide** — for technology choices with trade-offs, present the evidence and let the user/team decide.
- **Existing patterns matter** — if the codebase already uses a specific library/pattern, prefer extending that over introducing something new (unless there's a compelling reason).
- **Constitution constraints are non-negotiable** — if the constitution mandates specific technology choices, those override research recommendations.
- **Mark confidence levels** — distinguish between well-evidenced recommendations (High) and educated guesses (Low).
