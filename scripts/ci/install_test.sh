#!/usr/bin/env bash
# Installs the built packages into a CLEAN system (run it inside a fresh
# ubuntu/debian/fedora container) and proves they work there:
#   1. the package manager accepts them and resolves their dependencies
#   2. the installed driverforge-info finds and loads the installed plugin
#   3. a downstream project builds against the installed -dev package
#      with find_package() and loads both the shipped plugin and its own
#
#   scripts/ci/install_test.sh <dist-dir> deb|rpm
set -euo pipefail

DIST="${1:?usage: $0 <dist-dir> deb|rpm}"
KIND="${2:?usage: $0 <dist-dir> deb|rpm}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUDO=""
if [[ "$(id -u)" != "0" ]]; then SUDO="sudo"; fi

shopt -s nullglob
case "$KIND" in
    deb)
        pkgs=("$DIST"/*.deb)
        [[ ${#pkgs[@]} -gt 0 ]] || { echo "no .deb files in $DIST" >&2; exit 1; }
        export DEBIAN_FRONTEND=noninteractive
        $SUDO apt-get update -qq
        # apt (given paths, not names) resolves the Depends: lines that
        # CPack and dpkg-shlibdeps generated, like a user's install would.
        mapfile -t pkgs < <(realpath "${pkgs[@]}")
        $SUDO apt-get install -y -qq --no-install-recommends "${pkgs[@]}"
        $SUDO apt-get install -y -qq --no-install-recommends cmake ninja-build g++ gcc
        dpkg -L driverforge | sed 's/^/  /'
        ;;
    rpm)
        pkgs=("$DIST"/*.rpm)
        [[ ${#pkgs[@]} -gt 0 ]] || { echo "no .rpm files in $DIST" >&2; exit 1; }
        $SUDO dnf install -y -q "${pkgs[@]}"
        $SUDO dnf install -y -q cmake ninja-build gcc-c++ gcc
        rpm -ql driverforge | sed 's/^/  /'
        ;;
    *)
        echo "unknown package kind '$KIND' (expected deb or rpm)" >&2
        exit 2
        ;;
esac

echo "--- installed host tool"
driverforge-info --version
driverforge-info --require-plugin
shader_compiler --version

echo "--- downstream consumer against the installed SDK"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
expected="$(cat "$ROOT/VERSION")"
cmake -S "$ROOT/tests/consumer" -B "$work/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DEXPECTED_VERSION="$expected"
cmake --build "$work/build"
ctest --test-dir "$work/build" --output-on-failure

# shellcheck source=/dev/null
echo "OK: $KIND packages install and work on $(. /etc/os-release && echo "$PRETTY_NAME")"
