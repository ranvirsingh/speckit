# Speckit

Spec-driven development pipeline for AI-assisted coding agents.

## What is Speckit?

A set of [Agent Skills](https://agentskills.io/) that implement a lightweight, right-sized development process:

1. **Specify** — Write a spec, create a GitHub Issue
2. **Plan** — Design architecture, update the issue (when complex)
3. **Implement** — Code, test, commit, push, create PR
4. **Retro** — Update living docs, triage TODOs

Plus a **Constitution** skill for setting up project governance.

## Installation

### As a Git submodule (recommended)

```bash
# Add as submodule at the standard skills location
git submodule add https://github.com/ranvirsingh/speckit.git .github/skills/speckit

# Configure VS Code to discover nested skills
# Add to .vscode/settings.json:
# "chat.agentSkillsLocations": { ".github/skills/speckit": true }
```

### Manual copy

```bash
# Copy the entire folder into your project
cp -r speckit/ your-project/.github/skills/speckit/
```

## VS Code Configuration

Add to `.vscode/settings.json` so VS Code discovers the nested sub-skills:

```json
{
  "chat.agentSkillsLocations": {
    ".github/skills/speckit": true
  }
}
```

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| speckit | `/speckit` | Pipeline router — routes to the appropriate sub-skill |
| speckit-specify | `/speckit-specify` | Write spec, create GitHub Issue |
| speckit-plan | `/speckit-plan` | Design architecture, update issue with task checklist |
| speckit-implement | `/speckit-implement` | Execute tasks, commit, push, create PR |
| speckit-retro | `/speckit-retro` | Post-implementation retrospective |
| speckit-constitution | `/speckit-constitution` | Project governance setup |

## Pipeline Flow

```
Complex work (schema/API/unfamiliar)?  specify → plan → implement → retro
Simple & scoped?                       specify → implement → retro
```

## Requirements

- VS Code with GitHub Copilot
- GitHub CLI (`gh`) for issue/PR management
- Git for version control

## License

Private repository. All rights reserved.
