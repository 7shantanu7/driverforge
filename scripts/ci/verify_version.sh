#!/usr/bin/env bash
# Release gate: the pushed tag, the VERSION file and CHANGELOG.md must agree.
#   scripts/ci/verify_version.sh v1.2.3
set -euo pipefail

TAG="${1:?usage: $0 <tag>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT/VERSION")"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: VERSION '$VERSION' is not MAJOR.MINOR.PATCH" >&2
    exit 1
fi
if [[ "$TAG" != "v$VERSION" ]]; then
    echo "error: tag '$TAG' does not match VERSION file ($VERSION). Expected 'v$VERSION'." >&2
    exit 1
fi
if ! grep -qE "^## \[?$VERSION\]?" "$ROOT/CHANGELOG.md"; then
    echo "error: CHANGELOG.md has no '## [$VERSION]' section" >&2
    exit 1
fi
echo "OK: tag $TAG matches VERSION and CHANGELOG.md"
