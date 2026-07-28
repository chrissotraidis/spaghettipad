#!/usr/bin/env bash
# Build the pinned, unmodified SpaghettiKart tree for macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT/sources/spaghettikart"
BUILD_DIR="$ROOT/build-oracle"
EXPECTED_SPAGHETTIKART="5b28472d477bab101dee2a0f469fe2aee2c58a01"
BUILD_JOBS="${ORACLE_BUILD_JOBS:-4}"

fail() {
    echo "Oracle build failed: $*" >&2
    exit 1
}

[ -d "$SOURCE_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$EXPECTED_SPAGHETTIKART" ] ||
    fail "SpaghettiKart is not at the planned revision"
git -C "$SOURCE_DIR" diff --quiet ||
    fail "SpaghettiKart has modified tracked files"
git -C "$SOURCE_DIR" diff --cached --quiet ||
    fail "SpaghettiKart has staged files"

for command in cmake ninja; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done
case "$BUILD_JOBS" in
    ''|*[!0-9]*|0) fail "ORACLE_BUILD_JOBS must be a positive integer" ;;
esac

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SCRIPTING=OFF
[ -s "$BUILD_DIR/_deps/stb/stb_image.h" ] ||
    fail "CMake did not fetch the pinned stb_image.h; network access is required"
cmake --build "$BUILD_DIR" --target GenerateO2R --parallel "$BUILD_JOBS"
cmake --build "$BUILD_DIR" --target Spaghettify --parallel "$BUILD_JOBS"

ORACLE="$BUILD_DIR/Spaghettify"
PORT_ARCHIVE="$BUILD_DIR/spaghetti.o2r"
[ -x "$ORACLE" ] || fail "expected executable was not produced: $ORACLE"
[ -f "$PORT_ARCHIVE" ] ||
    fail "expected port archive was not produced: $PORT_ARCHIVE"

echo
echo "macOS oracle build complete:"
echo "  executable  $ORACLE"
echo "  archive     $PORT_ARCHIVE"
