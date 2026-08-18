#!/usr/bin/env bash
# Build the pinned, unmodified SpaghettiKart tree for macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT/sources/spaghettikart"
BUILD_DIR="$ROOT/build-oracle"
EXPECTED_SPAGHETTIKART="5b28472d477bab101dee2a0f469fe2aee2c58a01"
BUILD_JOBS="${ORACLE_BUILD_JOBS:-4}"
EXPECTED_STB_SHA256="c54b15a689e6a1f32c75e2ec23afa442e3e0e37e894b73c1974d08679b20dd5c"
# The unmodified oracle downloads sse2neon master; bytes reviewed at 8f03de354e8a87426b94dadd57dbd55b544810c3.
EXPECTED_SSE2NEON_SHA256="44fa833125ba4671b6c2bc0c520f11dbc22f02e9ca223f9d3e04af0db09fcfc6"
EXPECTED_SEMVER_SHA256="af2c0c53124dc7f52c58a7205e458ad3efbac2f61ce55addf9c8f94338a04182"

fail() {
    echo "Oracle build failed: $*" >&2
    exit 1
}

verify_download() {
    local path="$1"
    local expected_sha256="$2"
    local label="$3"

    [ -s "$path" ] ||
        fail "CMake did not fetch $label; network access is required"
    [ "$(shasum -a 256 "$path" | awk '{print $1}')" = "$expected_sha256" ] ||
        fail "$label does not match its expected SHA-256"
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
verify_download "$BUILD_DIR/_deps/stb/stb_image.h" \
    "$EXPECTED_STB_SHA256" "stb_image.h"
verify_download "$BUILD_DIR/_deps/sse2neon/sse2neon.h" \
    "$EXPECTED_SSE2NEON_SHA256" "sse2neon.h"
verify_download "$BUILD_DIR/_deps/semver/semver.hpp" \
    "$EXPECTED_SEMVER_SHA256" "semver.hpp"
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
