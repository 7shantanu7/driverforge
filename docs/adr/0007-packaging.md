# ADR 0007: Package split, layout and supported distributions

**Status:** accepted

## Decision

- **Three components, three packages:** runtime (`gpu-driver-stack`), SDK
  (`gpu-driver-stack-dev`, or `-devel` for RPM) and tools
  (`gpu-driver-stack-tools`). Users who run the stack never install headers
  or the shader compiler.
- **Debug symbols are split out** into `-dbgsym` packages (Debian), so
  shipped binaries are stripped but crashes can still be symbolised.
- **Plugins live in a private directory**
  (`<libdir>/gpu_driver_stack/`), because they are loaded with `dlopen`
  and never linked against.
- **Native layouts:** the `.deb` uses the Debian multiarch libdir, and the
  `.rpm` is built by a separate preset with the Fedora `lib64` layout.
- **Policy-clean:** lintian runs with `--fail-on error,warning`. Packages
  carry a copyright file, a compressed changelog and man pages.
- **Proven on clean systems:** every package is installed in a fresh
  Ubuntu 24.04, Debian 13 and Fedora 43 container. The installed tool must
  load the installed plugin, and a downstream project must build against
  the installed SDK.

## Consequences

- Packages are built on Ubuntu 24.04 (glibc 2.39, GCC 13 `libstdc++`).
  Older distributions are not supported. Supporting them would mean
  building in an older base image, and the install-test matrix is where that
  support would have to be proven.
