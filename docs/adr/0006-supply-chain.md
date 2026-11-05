# ADR 0006: Supply-chain controls

**Status:** accepted

## Context

Consumers of a driver package need to know what they are installing and
where it came from. CI also runs third-party code (actions, containers,
downloads) with access to the repository.

## Decision

- **Downloads are pinned by content.** GoogleTest is fetched with
  `URL_HASH SHA256=...` from two mirrors, and an installed copy is
  preferred.
- **Least privilege.** Workflows default to `contents: read`. Only the
  release job gets `contents: write`, `id-token: write` and
  `attestations: write`. Workflows triggered by `pull_request_target` never
  check out or run PR code.
- **Caches are written by trusted branches only.**
- **Releases ship `SHA256SUMS`, an SPDX SBOM and signed SLSA build
  provenance** (GitHub artifact attestations, Sigstore keyless signing).
  Users verify with `gh attestation verify`.
- **Dependencies are kept current** by Dependabot (actions, Docker base).

## Consequences and known gaps

- Third-party actions are referenced by major-version tag (`@v4`), not by
  commit SHA. Tags can be moved by the action's owner. Pinning to full
  SHAs (for example with `pinact` or Dependabot's SHA updates) is the next
  hardening step. It was not done in the first pass because the SHAs could
  not be verified from the environment the pipeline was written in.
- `Dockerfile.dev` uses `ubuntu:24.04` by tag. Pinning by digest is
  documented in the file and is a one-line change once a digest is chosen.
