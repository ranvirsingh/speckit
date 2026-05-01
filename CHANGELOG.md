# Changelog

All notable changes to this project will be documented in this file.

## [v3.1.1] - 2026-05-01

### Fixed
- Hardened `scripts/set-issue-state.ps1` to safely skip GitHub Project draft items that do not expose `content.id`, preventing property-access crashes during issue-item lookup.
- Added regression tests in `scripts/speckit.tests.ps1` to verify draft/non-issue project items are ignored without exceptions while issue-backed items are still matched correctly.
