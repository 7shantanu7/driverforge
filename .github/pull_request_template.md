## What and why

<!-- One or two sentences. The PR title must be a Conventional Commit
     (feat:, fix:, ci:, ...): it becomes the changelog entry. -->

## Checklist

- [ ] `cmake --workflow --preset dev` passes locally
- [ ] Tests added or updated for the change
- [ ] If `plugin_abi.h` changed: ABI baseline updated (`scripts/check_abi.sh ... --update`) or SOVERSION bumped
- [ ] If user-visible: entry added under `## [Unreleased]` in CHANGELOG.md
- [ ] If this fixes a released bug: labelled `backport release/X.y`
