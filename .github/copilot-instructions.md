# Speckit Repository Guidelines

This is the upstream speckit repo. We dogfood our own pipeline.

## Ways of Working

### Pipeline Entry Decision (run this BEFORE touching any file)

Classify the request before doing anything else:

| Request type | Action |
|---|---|
| Read-only question, status report, or research | Answer directly. No pipeline. |
| Writes to a file, runs a migration, opens a PR, or pushes a commit | **Pipeline. No exceptions.** |

If the second row applies and **no GitHub issue exists yet**, the first action is `speckit-specify` — even for a one-line typo fix. The chore template exists for this.

There is no "small enough to skip" exemption. The escape hatch is `skip-speckit: <phase> — <reason>` in the PR body, which is checked by `pipeline-guard.yml`.

### Pipeline
Use the `speckit` pipeline for any code change work (feature, bug, or chore).

- `speckit-specify` — create or refine the spec in a single GitHub Issue.
- `speckit-research` — when there are technology unknowns.
- `speckit-plan` — for complex work (schema changes, new APIs, unfamiliar domain).
- `speckit-implement` — execute the checklist, ship the PR, update living docs and triage TODOs at done-done.
- `speckit-test` — UAT against the spec.
- `speckit-e2e` — generate end-to-end proof-of-work artifacts.
- `speckit-constitution` — define or update governance.
- `speckit-verify` — check compliance against the constitution (`--scope pr`) or audit repo hygiene (`--scope repo`).

### Pipeline Shape
- Simple/scoped: `specify → implement → test → e2e`
- Complex: `specify → research → plan → implement → test → e2e`

Living-doc updates and TODO triage happen at the tail end of `speckit-implement` ("done-done"), not as a separate phase.

### GitHub Issue Rules
- One issue per spec.
- Keep the spec and implementation checklist in the issue body or as a single `<!-- speckit-plan:start -->` comment.
- No sub-issues. No `tasks.md` tracker.

### Code Practices
- Branch names start with the issue number: `7-speckit-v2`, `12-fix-install-permissions`.
- Conventional commits with `Refs #N` in the footer.
- Link PRs back to the issue with `Closes #N` (NOT `Refs` — `Refs` leaves issues open).
- The PR template's speckit checklist is mandatory. Every unchecked box needs a `skip-speckit: <phase> — <reason>` line. `pipeline-guard.yml` blocks merge otherwise.

## Architecture Notes

- **Skills** (`skills/<name>/SKILL.md`) — user-invocable phases of the pipeline. Loaded into Copilot context when their description matches.
- **Agents** (`agents/<name>.agent.md`) — internal subagents and pipeline orchestrators. Invoked via `runSubagent`.
- **Frontmatter is the enforcement layer.** `tools:` allowlist physically restricts what each role can do — read-only subagents have no `editFiles`/`runCommands`. Don't add a tool to a subagent's allowlist without thinking about its scope.
- **Assets co-locate with their owning skill** under `skills/<name>/assets/`. `install.ps1` fans them out into the host repo's `.github/`.
