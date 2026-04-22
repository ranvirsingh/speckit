---
name: speckit-doctor
user-invocable: true
model: Claude Sonnet 4.6 (copilot)
tools: ['search', 'codebase', 'githubRepo', 'runCommands']
description: >-
  Audit the current repository for speckit pipeline hygiene. Checks open issues for
  spec markers, open PRs for `Closes #N` and a fully-justified Speckit checklist,
  and recent branches for the `<issue>-` naming convention. Use this skill when
  the user says "doctor", "audit speckit", "check pipeline hygiene", or before a
  release to make sure nothing has slipped past the gates.
---

## Purpose

Speckit relies on conventions that are easy to forget: every issue should have a
spec marker, every PR should close an issue and tick every Speckit phase (or justify
the skip), every branch should start with the issue number. `pipeline-guard.yml`
catches violations at PR-merge time, but problems quietly accumulate before that
gate fires. This skill is the periodic checkup that surfaces them.

## Procedure

1. **Detect the repo**: `gh repo view --json owner,name` to determine `{owner}/{repo}`.

2. **Audit open issues**:
   ```bash
   gh issue list --repo {owner}/{repo} --state open --limit 100 --json number,title,body,labels
   ```
   For each issue, check whether `body` contains `<!-- speckit-spec:start -->`.
   Issues without the marker are flagged.

3. **Audit open PRs**:
   ```bash
   gh pr list --repo {owner}/{repo} --state open --limit 100 --json number,title,body,headRefName
   ```
   For each PR:
   - Check the body for `Closes #N` / `Fixes #N` / `Resolves #N` (case-insensitive)
   - Check each Speckit phase line: must be `- [x] **{Phase}**` OR have a matching
     `skip-speckit: {phase} — <reason>` line
   - Check the branch name (`headRefName`) starts with `<issue-number>-`

4. **Audit recent merged branches** (best-effort):
   ```bash
   git for-each-ref --sort=-committerdate --count=20 --format='%(refname:short)' refs/remotes/origin/
   ```
   Flag any non-`main`/`master` branch that does not start with a digit followed by `-`.

5. **Produce a report** as a markdown table grouped by category:
   - Issues missing spec markers
   - PRs missing `Closes #N`
   - PRs with unchecked phases AND no `skip-speckit:`
   - Branches not following the naming convention

6. **Exit code**: print the summary, then if **any** rule was violated, exit 1.
   This makes the skill suitable for running in CI as a scheduled job.

## Output Format

```markdown
# Speckit Doctor Report — {repo} — {ISO timestamp}

## ✅ Healthy
- Issues with spec markers: {n}/{total}
- PRs with `Closes #N`: {n}/{total}
- PRs with complete checklist: {n}/{total}
- Branches following convention: {n}/{total}

## ⚠️ Issues missing spec markers
| # | Title |
|---|---|
| #N | ... |

## ⚠️ PRs missing `Closes #N`
| # | Title | Branch |
|---|---|---|
| #N | ... | ... |

## ⚠️ PRs with unjustified unchecked phases
| # | Phase | Title |
|---|---|---|
| #N | research | ... |

## ⚠️ Branches not matching `<issue>-` convention
| Branch | Last commit |
|---|---|
| feat/something | ... |
```

## Constraints

- Read-only against GitHub (uses `gh` and `git` for reads only)
- Does NOT open issues, comment on PRs, or rename branches — it reports only
- Idempotent — safe to run repeatedly
- Designed to be invoked from a scheduled GitHub Action (e.g., weekly) as well
  as on-demand from chat

## Next Steps

After the report, the user can:
- Open issues to add missing spec markers (use `speckit-specify` to refine)
- Edit PR bodies to add `Closes` lines and tick checklists
- Rename branches via `git branch -m`
