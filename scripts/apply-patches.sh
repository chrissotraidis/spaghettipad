#!/usr/bin/env bash
# Apply the maintained iOS backport to the pinned libultraship checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LUS_DIR="$ROOT/sources/spaghettikart/libultraship"
LUS_PATCH="$ROOT/patches/libultraship-ios.patch"
EXPECTED_LUS="f5c3843fe937320b64ff754fa6bf71b13ff5e7a1"

fail() {
    echo "Patch application failed: $*" >&2
    exit 1
}

[ -e "$LUS_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ -f "$LUS_PATCH" ] || fail "maintained patch is missing: $LUS_PATCH"
[ "$(git -C "$LUS_DIR" rev-parse HEAD)" = "$EXPECTED_LUS" ] ||
    fail "libultraship is not at the planned revision"
git -C "$LUS_DIR" diff --cached --quiet ||
    fail "libultraship has staged files"

if git -C "$LUS_DIR" apply --reverse --check "$LUS_PATCH" 2>/dev/null; then
    echo "libultraship iOS patch is already applied."
    exit 0
fi

git -C "$LUS_DIR" diff --quiet ||
    fail "libultraship has modified tracked files"
git -C "$LUS_DIR" apply --check "$LUS_PATCH"
git -C "$LUS_DIR" apply "$LUS_PATCH"
git -C "$LUS_DIR" apply --reverse --check "$LUS_PATCH" ||
    fail "applied patch does not pass its reverse check"

echo "Applied libultraship iOS patch at $EXPECTED_LUS."
