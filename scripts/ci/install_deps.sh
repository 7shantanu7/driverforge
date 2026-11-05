#!/usr/bin/env bash
# Installs exactly what one CI job needs on an Ubuntu 24.04 runner. Every CI
# system (GitHub Actions, GitLab CI, Jenkins without the dev image) calls
# this, so the package list for a job lives in one place.
#
#   scripts/ci/install_deps.sh <profile>...
#
# Profiles: build gcc-N clang-N sanitizers coverage tidy lint abi package cross
set -euo pipefail

SUDO=""
if [[ "$(id -u)" != "0" ]]; then SUDO="sudo"; fi

packages=()
for profile in "$@"; do
    case "$profile" in
        build)      packages+=(cmake ninja-build ccache libgtest-dev libgmock-dev python3 git) ;;
        gcc-*)      packages+=("g++-${profile#gcc-}" "gcc-${profile#gcc-}") ;;
        clang-*)    packages+=("clang-${profile#clang-}" "libclang-rt-${profile#clang-}-dev") ;;
        sanitizers) packages+=(libclang-rt-18-dev) ;;
        coverage)   packages+=(gcovr) ;;
        tidy)       packages+=(clang-tidy-18) ;;
        lint)       packages+=(clang-format-18 shellcheck python3) ;;
        abi)        packages+=(abigail-tools) ;;
        package)    packages+=(dpkg-dev rpm lintian file) ;;
        cross)      packages+=(g++-aarch64-linux-gnu qemu-user) ;;
        *) echo "unknown profile '$profile'" >&2; exit 2 ;;
    esac
done

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq --no-install-recommends "${packages[@]}"
echo "installed: ${packages[*]}"
