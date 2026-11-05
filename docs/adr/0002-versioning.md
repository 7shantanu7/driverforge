# ADR 0002: One release version file; plugin SOVERSION versioned separately

**Status:** accepted

## Context

In 0.1.0 the version was written in two places (the driver's CMake file and
an environment variable in CI). Two copies drift.

The release version and the binary compatibility of the plugin are also two
different things. A bug-fix release must not change the SONAME that hosts
load, while a single ABI break must.

## Decision

- `VERSION` holds the release version. CMake reads it into
  `project(VERSION)`, which feeds the generated `version.h`, the package
  versions, the CMake package version file and the release gate
  (`scripts/ci/verify_version.sh`).
- `DRIVERFORGE_PLUGIN_SOVERSION` (CMake) and `GPU_CORE_PLUGIN_ABI_VERSION`
  (`plugin_abi.h`) describe the plugin ABI. They change only on an ABI
  break, and an ABI break requires a new major release.
- Binaries record the commit they were built from (`driverforge-info
  --version`), taken from git, or from `DRIVERFORGE_GIT_SHA` in CI. It is a
  fixed value, not a timestamp, so builds stay reproducible.

## Consequences

- A release is a two-file PR plus a tag, and the tag cannot disagree with the
  code: the release workflow refuses to publish.
- The file name `libnvk_driver.so.1.0.0` carries the release version and the
  SONAME `libnvk_driver.so.1` carries the ABI version, the same scheme
  shared libraries use on Linux.
