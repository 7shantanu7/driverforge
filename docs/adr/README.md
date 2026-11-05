# Architecture decision records

Each record explains one decision: the context, what was decided, and the
consequences, including the downsides that were accepted.

| ADR | Decision |
| --- | --- |
| [0001](0001-c-plugin-abi.md) | The driver plugin interface is a versioned C ABI |
| [0002](0002-versioning.md) | One release version file; plugin SOVERSION versioned separately |
| [0003](0003-presets-and-portable-ci.md) | CMake presets and shell scripts are the CI interface |
| [0004](0004-reproducible-builds.md) | Builds must be bit-for-bit reproducible |
| [0005](0005-abi-gate-policy.md) | Any ABI change fails CI until it is reviewed |
| [0006](0006-supply-chain.md) | Supply-chain controls: pinning, SBOM, signed provenance |
| [0007](0007-packaging.md) | Package split, layout and supported distributions |
