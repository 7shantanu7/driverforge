#!/usr/bin/env bash
# Runs the whole test suite N times on one build (including quarantined
# tests) and reports every test whose result changed between runs.
#
#   scripts/ci/flaky_hunt.sh <build-dir> [runs]
set -euo pipefail

BUILD="$(realpath "${1:?usage: $0 <build-dir> [runs]}")"
RUNS="${2:-20}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$BUILD/flaky-hunt"
rm -rf "$OUT" && mkdir -p "$OUT"

for i in $(seq 1 "$RUNS"); do
    # Shuffle order and run in parallel: order and timing dependence are
    # the usual causes of flakiness.
    ctest --test-dir "$BUILD" --schedule-random -j "$(nproc)" \
        --output-junit "$OUT/run-$i.xml" >"$OUT/run-$i.log" 2>&1 || true
done

PYTHONPATH="$ROOT/tools/buildstats" python3 -m buildstats flaky "$OUT"/run-*.xml \
    | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
