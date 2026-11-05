#!/usr/bin/env bash
# Configure, build and test one CMake preset, then publish metrics.
#
#   scripts/ci/build_and_test.sh <preset> [extra ctest args...]
#
# Writes:
#   build/<preset>/junit.xml        CTest results for the CI test report
#   build/<preset>/metrics.json     build/test metrics (tools/buildstats)
# and appends a Markdown summary to $GITHUB_STEP_SUMMARY when it is set.
set -euo pipefail

PRESET="${1:?usage: $0 <preset> [ctest args...]}"
shift
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/build/$PRESET"
cd "$ROOT"

if command -v ccache >/dev/null; then ccache --zero-stats >/dev/null; fi

echo "::group::configure ($PRESET)"
cmake --preset "$PRESET"
echo "::endgroup::"

echo "::group::build ($PRESET)"
cmake --build --preset "$PRESET"
echo "::endgroup::"

status=0
if [[ -f "$BUILD/CTestTestfile.cmake" ]]; then
    echo "::group::test ($PRESET)"
    ctest --preset "$PRESET" --output-junit "$BUILD/junit.xml" "$@" || status=$?
    echo "::endgroup::"
fi

export PYTHONPATH="$ROOT/tools/buildstats${PYTHONPATH:+:$PYTHONPATH}"
python3 -m buildstats collect "$BUILD" --label "$PRESET" --junit "$BUILD/junit.xml" \
    --output "$BUILD/metrics.json" || echo "warning: could not collect build metrics"
if [[ -f "$BUILD/metrics.json" ]]; then
    python3 -m buildstats markdown "$BUILD/metrics.json" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
fi
python3 -m buildstats ninja "$BUILD" --top 5 || true

exit $status
