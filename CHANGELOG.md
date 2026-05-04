# Changelog

All notable changes to this project will be documented in this file.

## [v3.2.0] - 2026-05-04

### Added
- New `speckit-pr-description` skill that validates and auto-fixes PR descriptions against the pipeline guard rules before the PR is marked ready for review. Prevents the guard from staying red because AI forgot to fill in phase checkboxes or the `Closes #N` link.
- `speckit-implement` `before_pr` gate now explicitly delegates to `speckit-pr-description` instead of ad-hoc inline instructions, making the gate reliably enforced.
- `speckit-pr-description` registered in the router skill table and as routing rule #10.
- `speckit-pr-description` added to the `install.ps1` skills list so it is copied to `.github/skills/` on installation.

## [v3.1.1] - 2026-05-01

### Fixed
- Hardened `scripts/set-issue-state.ps1` to safely skip GitHub Project draft items that do not expose `content.id`, preventing property-access crashes during issue-item lookup.
- Added regression tests in `scripts/speckit.tests.ps1` to verify draft/non-issue project items are ignored without exceptions while issue-backed items are still matched correctly.
