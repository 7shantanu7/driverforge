#!/usr/bin/env bash
# Fails if any tracked C/C++/CUDA file is not clang-formatted.
#   scripts/check_format.sh          check (CI)
#   scripts/check_format.sh --fix    rewrite files in place
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLANG_FORMAT="${CLANG_FORMAT:-$(command -v clang-format-18 || command -v clang-format)}"
echo "using $("$CLANG_FORMAT" --version)"

mapfile -t files < <(git ls-files '*.c' '*.cpp' '*.h' '*.cu')
if [[ "${1:-}" == "--fix" ]]; then
    "$CLANG_FORMAT" -i "${files[@]}"
    echo "formatted ${#files[@]} files"
else
    "$CLANG_FORMAT" --dry-run --Werror "${files[@]}"
    echo "OK: ${#files[@]} files are clang-formatted"
fi
