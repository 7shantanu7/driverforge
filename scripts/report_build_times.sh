#!/usr/bin/env bash
# Kept for backwards compatibility: prints the N slowest steps of the last
# Ninja build. The logic now lives in the tested Python tool tools/buildstats.
#   report_build_times.sh [build_dir] [top_n]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONPATH="${ROOT}/tools/buildstats${PYTHONPATH:+:$PYTHONPATH}" \
    exec python3 -m buildstats ninja "${1:-build}" --top "${2:-10}"
