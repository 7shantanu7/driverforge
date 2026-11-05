#!/usr/bin/env bash
# Verifies a CUDA binary really contains device code (SASS) for every GPU
# architecture we promised, e.g. sm_80 (A100) and sm_90 (H100). A wrong
# CMAKE_CUDA_ARCHITECTURES value otherwise ships silently and only fails on
# the customer's GPU at runtime with "no kernel image is available".
#
#   scripts/ci/check_cuda_fatbin.sh <binary-or-static-lib> <arch>...
#   scripts/ci/check_cuda_fatbin.sh build/cuda/tests/cuda_compute_tests 80 90
set -euo pipefail

BIN="${1:?usage: $0 <binary> <arch>...}"
shift
[[ $# -gt 0 ]] || { echo "usage: $0 <binary> <arch>..." >&2; exit 2; }

elves="$(cuobjdump --list-elf "$BIN" 2>/dev/null || true)"
echo "$elves"
missing=0
for arch in "$@"; do
    if grep -q "sm_${arch}" <<<"$elves"; then
        echo "OK: sm_${arch} device code present"
    else
        echo "FAIL: no sm_${arch} device code in $BIN" >&2
        missing=1
    fi
done
exit $missing
