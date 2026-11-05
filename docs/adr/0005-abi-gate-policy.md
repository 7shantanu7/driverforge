# ADR 0005: Any ABI change fails CI until it is reviewed

**Status:** accepted

## Context

libabigail's `abidiff` sets exit bit 8 ("incompatible change") only when
symbols are removed. Inserting a struct member in the middle of
`gpu_core_plugin_api`, or changing an enum value, is reported only as bit 4
("ABI change"). Both break every existing plugin. This was verified on this
code base before writing the policy.

## Decision

- `scripts/check_abi.sh` fails on bit 4 or bit 8.
- New exported symbols are allowed (`--no-added-syms`).
- To accept a compatible change (for example a member appended at the end of
  the table), the PR regenerates `abi/libnvk_driver.so.1.abi` with
  `--update`. The ABI diff is then part of code review, and CODEOWNERS
  requires an owner to approve changes under `abi/`.
- To make a breaking change, bump the plugin SOVERSION and ABI version. The
  new SONAME has no baseline, so the script asks for one.

## Consequences

- No ABI change reaches `main` by accident.
- Compatible changes cost one extra command and a review.
- The baseline was confirmed to be identical across GCC 12, GCC 13 and
  Clang 18 builds, so contributors are not tied to one compiler.
