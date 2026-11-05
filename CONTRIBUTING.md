# Contributing

## Build and test

```bash
cmake --workflow --preset dev
```

Run any CI job locally with the same script CI uses, for example:

```bash
CC=clang-18 CXX=clang++-18 scripts/ci/build_and_test.sh asan
```

Or work inside the CI image:

```bash
docker build -f Dockerfile.dev -t gpu-stack-dev .
```

## Before you open a pull request

- `scripts/check_format.sh --fix` formats C, C++ and CUDA files.
- Optional: `pre-commit install` runs format, shellcheck and actionlint on
  every commit (see `.pre-commit-config.yaml`).
- Add or update tests with every change.

## Pull request titles

PRs are squash-merged, and the PR title becomes the commit message and the
changelog entry. Titles must follow
[Conventional Commits](https://www.conventionalcommits.org/):

```text
feat(loader): reject plugins with an unknown struct_size
fix(packaging): install man pages into the tools package
ci: add gcc-15 to the build matrix
```

Mark breaking changes with `!` (for example `feat(abi)!: ...`).

## Changing the plugin ABI

Any change to `core/include/gpu_core/plugin_abi.h` is checked by
`scripts/check_abi.sh` in CI. See [docs/adr/0005](docs/adr/0005-abi-gate-policy.md)
for what to do when it fails.

## Quarantining a flaky test

Add its CTest name to `tests/quarantine.txt` with a link to a tracking
issue. PR pipelines skip it, and the nightly flaky-test hunt keeps running it
until it is fixed and removed from the list.
