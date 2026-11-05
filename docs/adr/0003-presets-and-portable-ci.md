# ADR 0003: CMake presets and shell scripts are the CI interface

**Status:** accepted

## Context

CI YAML tends to accumulate build logic: compiler flags, sanitizer options,
packaging commands. That logic cannot be run locally, is duplicated across
jobs, and is locked into one CI vendor. Large organisations often run more
than one CI system (for example Jenkins on an internal build farm and
GitHub Actions or GitLab for public code).

## Decision

- Every build flavour is a CMake preset. Flags such as sanitizers, coverage
  and clang-tidy are CMake options (`GPU_STACK_SANITIZE`,
  `GPU_STACK_COVERAGE`, `GPU_STACK_CLANG_TIDY`), set by presets.
- Every CI step is a script in `scripts/ci/`. CI files only choose the
  environment (runner, container, compiler) and call scripts.
- The same `Dockerfile.dev` image is used by developers, the GitHub
  container-parity job, Jenkins and GitLab.

## Consequences

- Any CI failure can be reproduced locally with the same command, for
  example `CC=clang-18 CXX=clang++-18 scripts/ci/build_and_test.sh tsan`.
- `Jenkinsfile` and `.gitlab-ci.yml` are each about one screen long.
- Scripts must stay portable bash and are checked with shellcheck.
