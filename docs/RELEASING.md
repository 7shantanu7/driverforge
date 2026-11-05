# Release runbook

Everything below is automated except the decisions. A release is a reviewed
change to two files (`VERSION` and `CHANGELOG.md`) plus a tag.

## Versioning rules

- The release version follows [Semantic Versioning](https://semver.org/) and
  lives only in `VERSION`.
- The plugin ABI has its own version: `GPU_CORE_PLUGIN_ABI_VERSION` in
  `plugin_abi.h` and `DRIVERFORGE_PLUGIN_SOVERSION` in `CMakeLists.txt`. They
  change only when the plugin ABI breaks, and a break also requires a new
  major release.
- `scripts/check_abi.sh` (CI job "ABI check") fails on any ABI change until
  the change is recorded in `abi/` in the same pull request.

## Cut a regular release (from main)

1. Make sure `main` is green (the `ci-success` check).
2. Open a PR named `chore(release): vX.Y.Z` that:
   - sets `VERSION` to `X.Y.Z`;
   - moves the `## [Unreleased]` entries in `CHANGELOG.md` under a new
     `## [X.Y.Z] - YYYY-MM-DD` heading.
3. Merge it, then tag the merge commit and push the tag:

   ```bash
   git tag -s vX.Y.Z -m "driverforge vX.Y.Z"
   ```

   ```bash
   git push origin vX.Y.Z
   ```

4. The release workflow runs. It refuses to publish if the tag, `VERSION`
   and `CHANGELOG.md` disagree, or if any package fails to build, test or
   install.
5. Check the release page: packages for amd64 and arm64, `.rpm`,
   `SHA256SUMS`, the SPDX SBOM, and release notes generated from commits.

To rehearse without publishing, start the release workflow manually with
an existing tag ("Run workflow"). It runs everything except signing and
publishing, and writes a summary of what it would have shipped.

## Release candidates

Tag `vX.Y.Z-rc.1`, `-rc.2` and so on, with `VERSION` already at `X.Y.Z`.
The workflow publishes them as pre-releases. The final `vX.Y.Z` tag goes on
the same commit as the last good RC, so the final release is a build of
exactly what was tested.

## Release branches and backports

- Create `release/X.Y` from the release tag when the first patch release is
  needed:

  ```bash
  git switch -c release/X.Y vX.Y.0
  ```

  ```bash
  git push origin release/X.Y
  ```

- CI runs on `release/**` exactly as on `main`.
- Fix bugs on `main` first. Then add the label `backport release/X.Y` to the
  merged PR. The backport workflow opens a cherry-pick PR against the
  branch, or comments on the original PR if the cherry-pick conflicts.
- Release `X.Y.(Z+1)` from the branch with the same steps as above.

## Hotfix for a security issue

Follow [SECURITY.md](../SECURITY.md) for disclosure. Prepare the fix on a
private fork or a GitHub security advisory branch, then release from the
affected `release/X.Y` branches first and `main` last.

## Yank a bad release

A published version number is never reused.

1. Mark the GitHub release as a pre-release and prefix its title with
   "WITHDRAWN:", with a sentence explaining why and which version to use
   instead.
2. Release a fixed patch version (`X.Y.Z+1`) as soon as possible.
3. If the problem is security-relevant, publish an advisory.

Do not delete the tag or the release assets. Users and mirrors may have
already verified them by checksum, and deleting them hides what happened.

## What a release contains

| File | Purpose |
| --- | --- |
| `driverforge_X.Y.Z-1_{amd64,arm64}.deb` | Runtime: plugin, `driverforge-info`, shaders |
| `driverforge-dev_*.deb` | SDK: headers, static libraries, CMake config |
| `driverforge-tools_*.deb` | `shader_compiler` |
| `*-dbgsym_*.ddeb` | Detached debug symbols for crash triage |
| `driverforge*-X.Y.Z-1.x86_64.rpm` | The same split for RPM distributions |
| `driverforge-X.Y.Z-linux-*.tar.gz` | Relocatable tarball of everything |
| `SHA256SUMS` | Checksums of every file above |
| `driverforge-vX.Y.Z.spdx.json` | SBOM of the shipped files |
| Attestations (on GitHub) | Signed SLSA build provenance, checked with `gh attestation verify` |
