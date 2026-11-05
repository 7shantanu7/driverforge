#!/usr/bin/env bash
# ABI compatibility gate for the driver plugin, using libabigail.
#
#   scripts/check_abi.sh <built-plugin.so>            compare with the baseline
#   scripts/check_abi.sh <built-plugin.so> --update   regenerate the baseline
#
# The baseline (abi/libnvk_driver.so.<SOVERSION>.abi) is the reviewed ABI of
# this SOVERSION. Rules enforced:
#   * new exported symbols                                -> pass
#   * ANY change to existing symbols or the types they
#     reach (struct layout, enum values, signatures)       -> FAIL
#
# libabigail only flags removed symbols as "incompatible" (exit bit 8); a
# struct member inserted in the middle or a changed enum value is reported
# as a plain "ABI change" (bit 4) even though it breaks every existing
# plugin. So both bits fail here. The two ways forward are:
#   * the change really is compatible (e.g. a member appended to the end):
#     regenerate the baseline with --update in the same PR, so a reviewer
#     sees and approves the ABI diff;
#   * the change is breaking: bump DRIVERFORGE_PLUGIN_SOVERSION and
#     GPU_CORE_PLUGIN_ABI_VERSION. The new SONAME has no baseline yet, so
#     this script then demands one, which again makes the break explicit.
set -euo pipefail

LIB="${1:?usage: $0 <plugin.so> [--update]}"
MODE="${2:-check}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEADERS="$ROOT/core/include"

soname="$(readelf -d "$LIB" | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p')"
[[ -n "$soname" ]] || { echo "error: $LIB has no SONAME" >&2; exit 2; }
baseline="$ROOT/abi/${soname}.abi"

# Only types declared in the public headers count as ABI. libabigail matches
# headers by absolute path, which is why the `abi` preset builds without
# -ffile-prefix-map. Locations are left out so the baseline does not churn
# when unrelated lines move.
abidw_args=(--headers-dir "$HEADERS" --drop-private-types --no-show-locs
            --no-corpus-path --no-comp-dir-path)

if [[ "$MODE" == "--update" ]]; then
    mkdir -p "$ROOT/abi"
    abidw "${abidw_args[@]}" --out-file "$baseline" "$LIB"
    echo "wrote ABI baseline $baseline"
    exit 0
fi

if [[ ! -f "$baseline" ]]; then
    echo "error: no ABI baseline for $soname at ${baseline#"$ROOT"/}" >&2
    echo "If this SOVERSION bump is intentional, record the new ABI with:" >&2
    echo "  scripts/check_abi.sh $LIB --update" >&2
    exit 1
fi

current="$(mktemp --suffix=.abi)"
trap 'rm -f "$current"' EXIT
abidw "${abidw_args[@]}" --out-file "$current" "$LIB"

set +e
abidiff --no-added-syms "$baseline" "$current" >/tmp/abidiff.$$ 2>&1
status=$?
set -e
report="$(cat /tmp/abidiff.$$)"; rm -f /tmp/abidiff.$$

# abidiff exit status is a bit field: 1 error, 2 usage error,
# 4 ABI change, 8 incompatible ABI change.
if (( status & 3 )); then
    echo "error: abidiff failed to run (status $status)" >&2
    echo "$report" >&2
    exit 2
fi
if (( status & 12 )); then
    if (( status & 8 )); then
        echo "FAIL: $soname removed or incompatibly changed exported symbols" >&2
    else
        echo "FAIL: $soname ABI differs from the reviewed baseline" >&2
    fi
    echo "$report" >&2
    echo >&2
    echo "If the change is backward compatible (e.g. a struct member appended at the end)," >&2
    echo "record it for review in this PR:   scripts/check_abi.sh $LIB --update" >&2
    echo "If it breaks existing plugins, bump DRIVERFORGE_PLUGIN_SOVERSION (CMakeLists.txt)" >&2
    echo "and GPU_CORE_PLUGIN_ABI_VERSION (plugin_abi.h), then record the new baseline." >&2
    exit 1
fi
echo "OK: $soname ABI is identical to baseline ${baseline#"$ROOT"/}"
