#!/usr/bin/env bash
# Fails unless a shared library exports EXACTLY the symbols in an allow-list.
# Catches both ABI leaks (an internal C++ symbol became public) and ABI
# breaks (a required entry point disappeared).
#
#   check_exported_symbols.sh <library.so> <allowlist.txt>
set -euo pipefail

LIB="${1:?usage: $0 <library.so> <allowlist.txt>}"
ALLOWLIST="${2:?usage: $0 <library.so> <allowlist.txt>}"
NM="${NM:-nm}"

actual="$("$NM" --dynamic --defined-only "$LIB" | awk '$2 ~ /^[TDBRVWiu]$/ {print $3}' | sed 's/@.*//' | sort -u)"
expected="$(grep -v '^[[:space:]]*#' "$ALLOWLIST" | sed '/^[[:space:]]*$/d' | sort -u)"

if [[ "$actual" == "$expected" ]]; then
    echo "OK: $(basename "$LIB") exports exactly $(wc -l <<<"$expected" | tr -d ' ') allow-listed symbols"
    exit 0
fi

echo "ERROR: exported symbols of $LIB do not match $ALLOWLIST" >&2
diff -u <(echo "$expected") <(echo "$actual") --label expected --label actual >&2 || true
exit 1
