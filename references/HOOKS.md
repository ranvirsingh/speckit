# Extension Hook Execution Reference

This document describes the standard hook-checking logic used by speckit skills.
Each skill checks for hooks at a specific lifecycle point (e.g., `before_specify`, `before_plan`, `before_implement`, `after_specify`).

## Standard Hook Keys

| Skill | Pre-hook | Post-hook |
|-------|----------|-----------|
| `speckit-specify` | `hooks.before_specify` | `hooks.after_specify` |
| `speckit-research` | `hooks.before_research` | `hooks.after_research` |
| `speckit-plan` | `hooks.before_plan` | `hooks.after_plan` |
| `speckit-implement` | `hooks.before_implement` | `hooks.after_implement` |
| `speckit-implement` (PR creation) | `hooks.before_pr` | `hooks.after_pr` |
| `speckit-test` | `hooks.before_test` | `hooks.after_test` |
| `speckit-e2e` | `hooks.before_e2e` | `hooks.after_e2e` |

`before_pr` runs after the implementation is complete but before
`gh pr create` is executed. The default behaviour for `speckit-implement`
when this hook resolves to no entries is to force `--draft`, locally validate
the PR body against the bundled `pipeline-guard.yml` regex set, fix the body
if validation fails, and then `gh pr ready` once green. Extensions can hook
in to add their own pre-PR validation (lint, type-check, test summary).

## Hook Checking Procedure

Given a `hookKey` (e.g., `hooks.before_specify`):

1. Check if `.specify/extensions.yml` exists in the project root.
2. If it exists, read it and look for entries under the `{hookKey}` key.
3. If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally.
4. Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
5. For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
   - If the hook has no `condition` field, or it is null/empty, treat the hook as executable.
   - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation.
6. For each executable hook, output based on its `optional` flag:

### Optional hook (`optional: true`)

```
## Extension Hooks

**Optional Pre-Hook**: {extension}
Command: `/{command}`
Description: {description}

Prompt: {prompt}
To execute: `/{command}`
```

### Mandatory hook (`optional: false`)

```
## Extension Hooks

**Automatic Pre-Hook**: {extension}
Executing: `/{command}`
EXECUTE_COMMAND: {command}

Wait for the result of the hook command before proceeding.
```

7. If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently.

## Post-Hooks

For post-hooks (e.g., `after_specify`), the format is the same except:
- Replace "Pre-Hook" with "Post-Hook" in the output labels.
- Post-hooks run after the main skill logic completes.
