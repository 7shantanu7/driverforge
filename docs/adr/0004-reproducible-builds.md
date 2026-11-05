# ADR 0004: Builds must be bit-for-bit reproducible

**Status:** accepted

## Context

If two builds of the same commit produce different bytes, nobody can verify
that a shipped binary was built from the claimed source. Differences also
defeat caching and make binary diffs between releases noisy.

## Decision

- Absolute source and build paths are rewritten with `-ffile-prefix-map`.
- Timestamps come from the commit (`SOURCE_DATE_EPOCH`). Generated files use
  deterministic tools (for example `gzip -n` for man pages and changelogs).
- Build metadata is limited to stable values (version, commit, compiler).
- CI (`scripts/check_reproducible.sh`) builds twice in two unrelated
  directories and compares the SHA-256 of every installed file and every
  `.deb`.

## Consequences

- A known CPack issue (seen with CMake 3.28) writes absolute build paths into
  the `md5sums` file of `-dbgsym` packages. The check therefore compares the
  payload of those packages instead of the whole archive. The debug info
  itself is verified identical.
- libabigail needs absolute header paths to filter types, so the `abi`
  preset turns path rewriting off. That build is not shipped.
