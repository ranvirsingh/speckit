---
name: speckit-specify
user-invocable: true
model: Claude Sonnet 4.6 (copilot)
tools: ['search', 'codebase', 'web', 'fetch', 'usages', 'editFiles', 'runCommands', 'githubRepo']
agents: ['speckit-living-docs-loader', 'speckit-nexus', 'speckit-codebase-scanner']
description: >-
  Create or update a feature specification, bug report, or chore definition as a GitHub
  Issue-backed spec from a natural language description. Use this skill when the user wants to
  define a new feature, report a bug, write requirements, capture user stories, or create a
  spec. Triggers on requests like "I want to build...", "specify a feature for...", "write a
  spec", "fix this bug", or any feature ideation, bug reporting, and scoping task.
---

## Issue State Tracking

On entry, advance the Issue State to "Specify". Read `.speckit-project.json` from the workspace root for `projectNumber` and `owner`. If the file does not exist, skip silently.

```powershell
powershell -ExecutionPolicy Bypass -File .github/skills/speckit/scripts/set-issue-state.ps1 -ProjectNumber {projectNumber} -Owner {owner} -IssueNumber {issueNumber} -Repo {owner}/{repo} -State "Specify"
```

Run this after the GitHub Issue is created (you need the issue number).

> **Note**: When the issue is first added to the project, the script automatically sets it to "Parking Lot" before advancing to the requested state.
