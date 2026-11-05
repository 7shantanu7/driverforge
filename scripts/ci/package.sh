#!/usr/bin/env bash
# Builds, tests and packages one release preset, lints the packages and
# collects them into dist/.
#
#   scripts/ci/package.sh release|release-rpm|cross-aarch64
set -euo pipefail

PRESET="${1:?usage: $0 <package-preset>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Reproducible packages: every timestamp comes from the commit.
SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
export SOURCE_DATE_EPOCH
DRIVERFORGE_GIT_SHA="${DRIVERFORGE_GIT_SHA:-$(git rev-parse --short=12 HEAD)}"
export DRIVERFORGE_GIT_SHA

rm -rf "build/$PRESET/dist"
cmake --workflow --preset "$PRESET"

mkdir -p dist
shopt -s nullglob
artifacts=("build/$PRESET"/dist/*.{deb,ddeb,rpm,tar.gz})
[[ ${#artifacts[@]} -gt 0 ]] || { echo "no packages produced" >&2; exit 1; }
cp -v "${artifacts[@]}" dist/

debs=("build/$PRESET"/dist/*.deb)
if [[ ${#debs[@]} -gt 0 ]] && command -v lintian >/dev/null; then
    echo "--- lintian"
    # initial-upload-closes-no-bugs only matters for uploads to the Debian
    # archive itself (an ITP bug), not for vendor packages.
    lintian --fail-on error,warning --tag-display-limit 0 \
        --suppress-tags initial-upload-closes-no-bugs "${debs[@]}"
    echo "lintian: clean"
fi
