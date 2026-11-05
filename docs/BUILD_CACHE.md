# Build caching

Compilation results are cached, so unchanged files are not rebuilt.

## Local builds

`cmake/modules/CompilerLauncher.cmake` picks a cache automatically:

| Situation | Cache used |
| --- | --- |
| `SCCACHE_BUCKET` or `SCCACHE_GCS_BUCKET` is set | sccache (shared remote cache) |
| otherwise, if ccache is installed | ccache (local disk) |
| neither | none |

Override with `-DGPU_STACK_COMPILER_CACHE=ccache|sccache|none`, or with an
explicit `-DCMAKE_CXX_COMPILER_LAUNCHER=...`.

## GitHub Actions

Each matrix leg restores `.ccache` with `actions/cache/restore`, keyed by
compiler and build type. Only pushes to `main` and `release/**` save the
cache (`actions/cache/save`), so:

- pull requests start warm but cannot overwrite the trusted cache;
- each save uses a new key (`...-<run_id>`) and GitHub evicts old entries,
  so the cache does not grow without limit.

`CCACHE_COMPILERCHECK=content` makes ccache hash the compiler binary itself,
so a compiler update on the runner image never returns stale objects.

Each build job prints the ccache hit rate in its job summary
(`tools/buildstats`). The nightly cold build turns the cache off on purpose,
to measure the true cost of a build over time.

## A shared remote cache with sccache

A team or build farm gets the most from one cache shared by every machine.
sccache supports S3, GCS, Azure, Redis and others. Example with S3:

```bash
export SCCACHE_BUCKET=my-build-cache
```

```bash
export SCCACHE_REGION=us-west-2
```

```bash
cmake --workflow --preset ci-release
```

```bash
sccache --show-stats
```

In CI, provide the bucket credentials through the CI system's secret store
(for GitHub Actions, OIDC federation to a cloud role is better than static
keys). Only trusted branches should have write access to a shared cache;
pull requests from forks should be read-only or use no remote cache.
