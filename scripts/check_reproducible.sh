#!/usr/bin/env bash
# Proves the build is bit-for-bit reproducible: builds the same commit twice,
# in two different directories with different absolute paths, installs both,
# and compares a SHA-256 of every installed file and of the .deb packages.
# A difference means something machine- or path-specific leaked into the
# binaries (absolute paths, timestamps, ordering), which would make it
# impossible to verify that a shipped binary came from this source.
#
#   scripts/check_reproducible.sh [work-dir]
#
# Uses CC/CXX from the environment. Set DIFFOSCOPE=1 to get a detailed diff
# of the first mismatching file (needs diffoscope installed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${1:-$(mktemp -d)}"
mkdir -p "$WORK"

# Timestamps come from the commit, not the clock.
SOURCE_DATE_EPOCH="$(git -C "$ROOT" log -1 --format=%ct)"
export SOURCE_DATE_EPOCH
export DRIVERFORGE_GIT_SHA="${DRIVERFORGE_GIT_SHA:-$(git -C "$ROOT" rev-parse --short=12 HEAD)}"

build_once() {
    local name="$1"
    # Different, deliberately long and unrelated paths for the two builds.
    local build="$WORK/$name/some/deeply/nested/path-$name/build"
    local stage="$WORK/$name/stage"
    cmake -S "$ROOT" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DBUILD_TESTING=OFF \
        -DDRIVERFORGE_COMPILER_CACHE=none \
        -DDRIVERFORGE_GIT_SHA="$DRIVERFORGE_GIT_SHA" >/dev/null
    cmake --build "$build" >/dev/null
    DESTDIR="$stage" cmake --install "$build" >/dev/null
    (cd "$build" && cpack -G DEB >/dev/null 2>&1)
    (cd "$stage" && find . -type f -print0 | sort -z | xargs -0 sha256sum) >"$WORK/$name.files.sha256"
    (cd "$build/dist" && sha256sum ./*.deb) >"$WORK/$name.packages.sha256"
    # -dbgsym packages: compare the payload, not the whole .ddeb. CPack (seen
    # with CMake 3.28) writes ABSOLUTE build paths into the md5sums control
    # file of -dbgsym packages, so the archive differs by build directory
    # even though every byte of the debug info inside is identical.
    for ddeb in "$build"/dist/*.ddeb; do
        [[ -e "$ddeb" ]] || continue
        printf '%s  %s(payload)\n' "$(dpkg-deb --fsys-tarfile "$ddeb" | sha256sum | cut -d' ' -f1)" \
            "$(basename "$ddeb")"
    done >>"$WORK/$name.packages.sha256"
    echo "$build"
}

echo "building twice with SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
build_a="$(build_once a)"
build_b="$(build_once b)"

status=0
for kind in files packages; do
    if diff -u "$WORK/a.$kind.sha256" "$WORK/b.$kind.sha256"; then
        echo "OK: installed $kind are identical ($(wc -l <"$WORK/a.$kind.sha256") checked)"
    else
        echo "FAIL: installed $kind differ between the two builds" >&2
        status=1
    fi
done

if [[ $status -ne 0 && "${DIFFOSCOPE:-0}" == "1" ]] && command -v diffoscope >/dev/null; then
    first="$(diff "$WORK/a.files.sha256" "$WORK/b.files.sha256" | sed -n 's/^< [0-9a-f]*  //p' | head -1)"
    if [[ -n "$first" ]]; then
        diffoscope "$WORK/a/stage/$first" "$WORK/b/stage/$first" || true
    fi
fi
echo "builds: $build_a $build_b"
exit $status
