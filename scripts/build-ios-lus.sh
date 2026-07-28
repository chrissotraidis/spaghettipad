#!/usr/bin/env bash
# Build and audit the maintained libultraship iPhoneOS archive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT/sources/spaghettikart/libultraship"
BUILD_DIR="${LUS_IOS_BUILD_DIR:-$ROOT/build-ios-lus}"
LIBRARY="$BUILD_DIR/src/Release-iphoneos/libultraship.a"

fail() {
    echo "iOS libultraship build failed: $*" >&2
    exit 1
}

for command in cmake lipo nm otool rg shasum; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

"$ROOT/scripts/apply-patches.sh"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -GXcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DDEPLOYMENT_TARGET=15.0 \
    -DPLATFORM=OS64 \
    -DENABLE_SCRIPTING=OFF
cmake --build "$BUILD_DIR" --config Release --target libultraship -- \
    CODE_SIGNING_ALLOWED=NO

[ -f "$LIBRARY" ] || fail "expected archive was not produced: $LIBRARY"
[ "$(lipo -archs "$LIBRARY")" = "arm64" ] ||
    fail "archive is not arm64-only"
OTOOL_OUTPUT="$(otool -l "$LIBRARY")"
UNDEFINED_SYMBOLS="$(nm -u "$LIBRARY")"
GLOBAL_SYMBOLS="$(nm -g "$LIBRARY")"
MACHO_SYMBOLS="$(nm -m "$LIBRARY")"

rg -q 'platform 2' <<<"$OTOOL_OUTPUT" ||
    fail "archive does not contain iOS platform load commands"
rg -q 'minos 15\.0' <<<"$OTOOL_OUTPUT" ||
    fail "archive does not target iOS 15.0"

if rg -q 'toggleNativeMacOSFullscreen|CoreAudioAudioPlayer' \
    <<<"$UNDEFINED_SYMBOLS"; then
    fail "archive references a forbidden macOS-only symbol"
fi
rg -q '_WindowIsFrameReady$' <<<"$GLOBAL_SYMBOLS" ||
    fail "archive is missing WindowIsFrameReady"
rg -q 'weak private external _SpaghettiPad_SetTouchControlsMenuVisible$' \
    <<<"$MACHO_SYMBOLS" ||
    fail "archive is missing the weak touch-menu bridge"

echo
echo "iPhoneOS libultraship build complete:"
echo "  archive       $LIBRARY"
echo "  architecture  $(lipo -archs "$LIBRARY")"
echo "  sha256        $(shasum -a 256 "$LIBRARY" | awk '{print $1}')"
