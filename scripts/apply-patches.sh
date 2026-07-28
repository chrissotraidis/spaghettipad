#!/usr/bin/env bash
# Apply the maintained iOS backports to the pinned upstream checkouts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPAGHETTIKART_DIR="$ROOT/sources/spaghettikart"
LUS_DIR="$ROOT/sources/spaghettikart/libultraship"
SPAGHETTIKART_PATCH="$ROOT/patches/spaghettikart-ios.patch"
SPAGHETTIKART_FIRSTRUN_PATCH="$ROOT/patches/spaghettikart-ios-firstrun.patch"
SPAGHETTIKART_TOUCH_PATCH="$ROOT/patches/spaghettikart-ios-touch.patch"
LUS_PATCH="$ROOT/patches/libultraship-ios.patch"
LUS_TOUCH_PATCH="$ROOT/patches/libultraship-ios-touch.patch"
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
[ -f "$SPAGHETTIKART_FIRSTRUN_PATCH" ] ||
    fail "maintained patch is missing: $SPAGHETTIKART_FIRSTRUN_PATCH"
[ -f "$SPAGHETTIKART_TOUCH_PATCH" ] ||
    fail "maintained patch is missing: $SPAGHETTIKART_TOUCH_PATCH"
[ -f "$LUS_PATCH" ] || fail "maintained patch is missing: $LUS_PATCH"
[ -f "$LUS_TOUCH_PATCH" ] ||
    fail "maintained patch is missing: $LUS_TOUCH_PATCH"
[ "$(git -C "$SPAGHETTIKART_DIR" rev-parse HEAD)" = \
    "$EXPECTED_SPAGHETTIKART" ] ||
    fail "SpaghettiKart is not at the planned revision"
[ "$(git -C "$LUS_DIR" rev-parse HEAD)" = "$EXPECTED_LUS" ] ||
    fail "libultraship is not at the planned revision"
git -C "$SPAGHETTIKART_DIR" diff --cached --quiet ||
    fail "SpaghettiKart has staged files"
git -C "$LUS_DIR" diff --cached --quiet ||
    fail "libultraship has staged files"

if git -C "$LUS_DIR" apply --reverse --check \
    "$LUS_TOUCH_PATCH" 2>/dev/null; then
    echo "libultraship iOS base and touch patches are already applied."
else
    if git -C "$LUS_DIR" apply --reverse --check \
        "$LUS_PATCH" 2>/dev/null; then
        echo "libultraship iOS base patch is already applied."
    else
        git -C "$LUS_DIR" diff --quiet ||
            fail "libultraship has modified tracked files"
        git -C "$LUS_DIR" apply --check "$LUS_PATCH"
        git -C "$LUS_DIR" apply "$LUS_PATCH"
        git -C "$LUS_DIR" apply --reverse --check "$LUS_PATCH" ||
            fail "libultraship patch does not pass its reverse check"
        echo "Applied libultraship iOS patch at $EXPECTED_LUS."
    fi

    git -C "$LUS_DIR" apply --check "$LUS_TOUCH_PATCH"
    git -C "$LUS_DIR" apply "$LUS_TOUCH_PATCH"
    git -C "$LUS_DIR" apply --reverse --check "$LUS_TOUCH_PATCH" ||
        fail "libultraship touch patch does not pass its reverse check"
    echo "Applied libultraship iOS touch patch at $EXPECTED_LUS."
fi

if git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
    "$SPAGHETTIKART_TOUCH_PATCH" 2>/dev/null; then
    echo "SpaghettiKart iOS base, first-run, and touch patches are already applied."
else
    if git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
        "$SPAGHETTIKART_FIRSTRUN_PATCH" 2>/dev/null; then
        echo "SpaghettiKart iOS base and first-run patches are already applied."
    else
        if git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
            "$SPAGHETTIKART_PATCH" 2>/dev/null; then
            echo "SpaghettiKart iOS base patch is already applied."
        else
            git -C "$SPAGHETTIKART_DIR" diff --quiet -- . \
                ':(exclude)libultraship' ||
                fail "SpaghettiKart has modified tracked files"
            git -C "$SPAGHETTIKART_DIR" apply --check \
                "$SPAGHETTIKART_PATCH"
            git -C "$SPAGHETTIKART_DIR" apply \
                "$SPAGHETTIKART_PATCH"
            git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
                "$SPAGHETTIKART_PATCH" ||
                fail "SpaghettiKart patch does not pass its reverse check"
            echo "Applied SpaghettiKart iOS patch at $EXPECTED_SPAGHETTIKART."
        fi

        git -C "$SPAGHETTIKART_DIR" apply --check \
            "$SPAGHETTIKART_FIRSTRUN_PATCH"
        git -C "$SPAGHETTIKART_DIR" apply \
            "$SPAGHETTIKART_FIRSTRUN_PATCH"
        git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
            "$SPAGHETTIKART_FIRSTRUN_PATCH" ||
            fail "SpaghettiKart first-run patch does not pass its reverse check"
        echo "Applied SpaghettiKart iOS first-run patch at $EXPECTED_SPAGHETTIKART."
    fi

    git -C "$SPAGHETTIKART_DIR" apply --check \
        "$SPAGHETTIKART_TOUCH_PATCH"
    git -C "$SPAGHETTIKART_DIR" apply \
        "$SPAGHETTIKART_TOUCH_PATCH"
    git -C "$SPAGHETTIKART_DIR" apply --reverse --check \
        "$SPAGHETTIKART_TOUCH_PATCH" ||
        fail "SpaghettiKart touch patch does not pass its reverse check"
    echo "Applied SpaghettiKart iOS touch patch at $EXPECTED_SPAGHETTIKART."
fi
