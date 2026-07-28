#!/usr/bin/env bash
# Apply the maintained iOS backports to the pinned upstream checkouts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPAGHETTIKART_DIR="$ROOT/sources/spaghettikart"
LUS_DIR="$ROOT/sources/spaghettikart/libultraship"
SPAGHETTIKART_PATCH="$ROOT/patches/spaghettikart-ios.patch"
LUS_PATCH="$ROOT/patches/libultraship-ios.patch"
EXPECTED_SPAGHETTIKART="5b28472d477bab101dee2a0f469fe2aee2c58a01"
EXPECTED_LUS="f5c3843fe937320b64ff754fa6bf71b13ff5e7a1"

fail() {
    echo "Patch application failed: $*" >&2
    exit 1
}

[ -e "$SPAGHETTIKART_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ -e "$LUS_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ -f "$SPAGHETTIKART_PATCH" ] ||
    fail "maintained patch is missing: $SPAGHETTIKART_PATCH"
[ -f "$LUS_PATCH" ] || fail "maintained patch is missing: $LUS_PATCH"
[ "$(git -C "$SPAGHETTIKART_DIR" rev-parse HEAD)" = \
    "$EXPECTED_SPAGHETTIKART" ] ||
    fail "SpaghettiKart is not at the planned revision"
[ "$(git -C "$LUS_DIR" rev-parse HEAD)" = "$EXPECTED_LUS" ] ||
    fail "libultraship is not at the planned revision"
git -C "$SPAGHETTIKART_DIR" diff --cached --quiet ||
    fail "SpaghettiKart has staged files"
git -C "$LUS_DIR" diff --cached --quiet ||
    fail "libultraship has staged files"

if git -C "$LUS_DIR" apply --reverse --check "$LUS_PATCH" 2>/dev/null; then
    echo "libultraship iOS patch is already applied."
else
    git -C "$LUS_DIR" diff --quiet ||
        fail "libultraship has modified tracked files"
    git -C "$LUS_DIR" apply --check "$LUS_PATCH"
    git -C "$LUS_DIR" apply "$LUS_PATCH"
    git -C "$LUS_DIR" apply --reverse --check "$LUS_PATCH" ||
        fail "libultraship patch does not pass its reverse check"
    echo "Applied libultraship iOS patch at $EXPECTED_LUS."
fi

if git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
    "$SPAGHETTIKART_PATCH" 2>/dev/null; then
    echo "SpaghettiKart iOS patch is already applied."
else
    git -C "$SPAGHETTIKART_DIR" diff --quiet -- . \
        ':(exclude)libultraship' ||
        fail "SpaghettiKart has modified tracked files"
    git -C "$SPAGHETTIKART_DIR" apply --check "$SPAGHETTIKART_PATCH"
    git -C "$SPAGHETTIKART_DIR" apply "$SPAGHETTIKART_PATCH"
    git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
        "$SPAGHETTIKART_PATCH" ||
        fail "SpaghettiKart patch does not pass its reverse check"
    echo "Applied SpaghettiKart iOS patch at $EXPECTED_SPAGHETTIKART."
fi
