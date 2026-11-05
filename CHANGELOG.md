# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
uses [Semantic Versioning](https://semver.org/). Release notes on GitHub are
generated from commit messages (see `cliff.toml`); this file is the curated
summary.

## [Unreleased]

## [1.0.0] - 2026-11-05

First release with a committed plugin ABI (plugin SOVERSION 1).

### Added

- C plugin ABI (`gpu_core/plugin_abi.h`) with Vulkan-style version
  negotiation, and `gpu_core::LoadedPlugin`, which validates a plugin before
  calling into it.
- `driverforge-info` host tool that discovers, loads and reports driver plugins,
  falling back to the software rasterizer.
- Thread-safe `SubmissionQueue`, exercised by the ThreadSanitizer job.
- Optional CUDA backend (`-DENABLE_CUDA=ON`), built in CI for several CUDA
  versions and GPU architectures, with a fat-binary architecture check.
- Install rules, `find_package(driverforge)` support, and `.deb`, `.rpm`
  and tarball packages split into runtime, `-dev` and `-tools`.
- CMake presets for every build flavour (dev, CI, sanitizers, coverage,
  clang-tidy, ABI, release, aarch64 cross, CUDA).
- Release automation: tag-driven releases with checksums, an SPDX SBOM and
  signed build-provenance attestations.
- Quality gates: libabigail ABI check, exported-symbol allow-list,
  reproducible-build check, package install tests on clean Ubuntu, Debian and
  Fedora containers, nightly flaky-test hunt and build-time regression check.
- Jenkins and GitLab CI pipelines that reuse the same scripts, and autoscaling
  Kubernetes runners (including a GPU pool) via Actions Runner Controller.

### Changed

- The project is now called **driverforge** (previously `gpu_driver_stack`):
  CMake package `find_package(driverforge)`, targets `driverforge::*`,
  packages `driverforge`, `driverforge-dev` and `driverforge-tools`, and the
  host tool `driverforge-info`. The plugin C ABI (`gpu_core_plugin_*`) and the
  `gpu_core` library keep their names.
- **Breaking:** the driver plugin now exports only the two C entry points of
  the plugin ABI, instead of C++ classes. Plugins built against 0.1.0 do not
  load. This is why the plugin SOVERSION moved from 0 to 1.
- The version lives only in the `VERSION` file.
- `scripts/report_build_times.sh` now wraps the tested Python tool
  `tools/buildstats`.

## [0.1.0]

Initial version: modular CMake build, NVK-inspired mock driver plugin,
software fallback, mock shader compiler and a GitHub Actions matrix.
