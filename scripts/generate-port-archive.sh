#!/usr/bin/env bash
# Generate and audit the clean port archive and local ROM-derived game archive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT/sources/spaghettikart"
BUILD_DIR="$ROOT/build-oracle"
EXPECTED_ROM_SHA1="579c48e211ae952530ffc8738709f078d5dd215e"
SOURCE_ROM="$SOURCE_DIR/baserom.us.z64"
SOURCE_GAME_ARCHIVE="$SOURCE_DIR/mk64.o2r"
BUILD_GAME_ARCHIVE="$BUILD_DIR/mk64.o2r"
PORT_ARCHIVE="$BUILD_DIR/spaghetti.o2r"
SAVED_GAME_ARCHIVE="$ROOT/ref/mk64.o2r"

fail() {
    echo "Archive generation failed: $*" >&2
    exit 1
}

cleanup() {
    status=$?
    rm -f "$SOURCE_ROM" "$SOURCE_GAME_ARCHIVE"
    if [ -d "$SOURCE_DIR/.git" ] &&
        ! git -C "$SOURCE_DIR" diff --quiet --ignore-submodules --; then
        git -C "$SOURCE_DIR" restore --worktree -- .
    fi
    return "$status"
}
trap cleanup EXIT

[ -d "$SOURCE_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"

matching_rom=""
while IFS= read -r -d '' candidate; do
    candidate_sha1="$(shasum -a 1 "$candidate" | awk '{print $1}')"
    if [ "$candidate_sha1" = "$EXPECTED_ROM_SHA1" ]; then
        matching_rom="$candidate"
        break
    fi
done < <(find "$ROOT/ref" -maxdepth 1 -type f -iname '*.z64' -print0)

[ -n "$matching_rom" ] ||
    fail "ref/ lacks the required US big-endian .z64 ($EXPECTED_ROM_SHA1)"

"$ROOT/scripts/build-oracle.sh"
cp "$matching_rom" "$SOURCE_ROM"
cmake --build "$BUILD_DIR" --target ExtractAssets \
    --parallel "${ORACLE_BUILD_JOBS:-4}"

[ -s "$PORT_ARCHIVE" ] ||
    fail "clean port archive was not generated: $PORT_ARCHIVE"
[ -s "$BUILD_GAME_ARCHIVE" ] ||
    fail "game archive was not generated: $BUILD_GAME_ARCHIVE"

port_entries="$(unzip -Z1 "$PORT_ARCHIVE")"
[ -n "$port_entries" ] || fail "clean port archive contains no entries"
if grep -Eiq '(^|/).*\.(z64|n64|v64|rom|otr)$|(^|/)mk64[^/]*\.o2r$' \
    <<< "$port_entries"; then
    fail "clean port archive contains a ROM or ROM-derived archive"
fi

cp "$BUILD_GAME_ARCHIVE" "$SAVED_GAME_ARCHIVE"

echo
echo "Archive gate complete:"
echo "  clean port archive  $PORT_ARCHIVE"
shasum -a 256 "$PORT_ARCHIVE"
echo "  local game archive  $SAVED_GAME_ARCHIVE"
shasum -a 256 "$SAVED_GAME_ARCHIVE"
echo "  clean archive entries: $(printf '%s\n' "$port_entries" | wc -l | tr -d ' ')"
