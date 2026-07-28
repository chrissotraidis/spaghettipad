#!/usr/bin/env bash
# Audit the ROM-free iPhoneOS application contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build-ios/Release-iphoneos/SpaghettiPad.app}"
EXPECTED_PORT_CONTENT_SHA256="5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0"
EXPECTED_CONTROLLER_SHA256="eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77"

fail() {
    echo "iOS application audit failed: $*" >&2
    exit 1
}

for command in codesign file find lipo plutil rg shasum unzip xcrun; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

[ -d "$APP" ] || fail "application bundle is missing: $APP"
INFO="$APP/Info.plist"
[ -f "$INFO" ] || fail "Info.plist is missing"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO")"
BINARY="$APP/$EXECUTABLE_NAME"
[ -f "$BINARY" ] || fail "application executable is missing: $BINARY"

[ "$EXECUTABLE_NAME" = "SpaghettiPad" ] ||
    fail "unexpected executable name: $EXECUTABLE_NAME"
[ "$(lipo -archs "$BINARY")" = "arm64" ] ||
    fail "application is not arm64-only"
file "$BINARY" | rg -q 'Mach-O 64-bit executable arm64' ||
    fail "application is not an arm64 Mach-O executable"

BUILD_METADATA="$(xcrun vtool -show-build "$BINARY")"
rg -q '^[[:space:]]*platform IOS$' <<<"$BUILD_METADATA" ||
    fail "application does not target iPhoneOS"
rg -q 'minos 15\.0' <<<"$BUILD_METADATA" ||
    fail "application does not target iOS 15.0"

[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$INFO")" = \
    "SpaghettiPad" ] || fail "unexpected display name"
[ "$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$INFO")" = \
    "15.0" ] || fail "unexpected minimum OS"
[ "$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$INFO")" = "1" ] ||
    fail "iPhone device family is missing"
[ "$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:1' "$INFO")" = "2" ] ||
    fail "iPad device family is missing"
[ "$(/usr/libexec/PlistBuddy -c 'Print :UIFileSharingEnabled' "$INFO")" = \
    "true" ] || fail "Files sharing is not enabled"

for required in \
    "$APP/config.yml" \
    "$APP/gamecontrollerdb.txt" \
    "$APP/meta/mods.toml" \
    "$APP/spaghetti.o2r" \
    "$APP/yamls/us/textures/startup_logo.yml"; do
    [ -f "$required" ] || fail "required runtime resource is missing: $required"
done

[ "$("$ROOT/scripts/hash-port-archive.sh" "$APP/spaghetti.o2r")" = \
    "$EXPECTED_PORT_CONTENT_SHA256" ] ||
    fail "clean port archive content hash changed"
[ "$(shasum -a 256 "$APP/gamecontrollerdb.txt" | awk '{print $1}')" = \
    "$EXPECTED_CONTROLLER_SHA256" ] || fail "controller database hash changed"

PORT_ENTRIES="$(unzip -Z1 "$APP/spaghetti.o2r")"
[ -n "$PORT_ENTRIES" ] || fail "clean port archive contains no entries"
if rg -qi '(^|/).*\.(z64|n64|v64|rom|otr)$|(^|/)mk64[^/]*\.o2r$' \
    <<<"$PORT_ENTRIES"; then
    fail "clean port archive contains ROM or ROM-derived data"
fi

FORBIDDEN_FILES="$(find "$APP" -type f \
    \( -iname '*.z64' -o -iname '*.n64' -o -iname '*.v64' \
       -o -iname '*.rom' -o -iname '*.otr' -o -iname '*.o2r' \) \
    ! -name 'spaghetti.o2r' -print)"
[ -z "$FORBIDDEN_FILES" ] || {
    printf '%s\n' "$FORBIDDEN_FILES" >&2
    fail "ROM-derived game data is embedded"
}

if [ "${REQUIRE_SIGNED:-0}" = "1" ] &&
   [ "${REQUIRE_UNSIGNED:-0}" = "1" ]; then
    fail "REQUIRE_SIGNED and REQUIRE_UNSIGNED cannot both be enabled"
fi

SIGNATURE_STATE="unsigned"
if codesign --verify --strict "$APP" >/dev/null 2>&1 &&
   [ -f "$APP/embedded.mobileprovision" ]; then
    SIGNATURE_STATE="signed"
elif [ -e "$APP/_CodeSignature" ] ||
     [ -e "$APP/embedded.mobileprovision" ]; then
    fail "stale or incomplete signing material is present"
fi

if [ "${REQUIRE_SIGNED:-0}" = "1" ] &&
   [ "$SIGNATURE_STATE" != "signed" ]; then
    fail "REQUIRE_SIGNED=1, but the app lacks a valid signature/profile"
fi
if [ "${REQUIRE_UNSIGNED:-0}" = "1" ] &&
   [ "$SIGNATURE_STATE" != "unsigned" ]; then
    fail "REQUIRE_UNSIGNED=1, but the app is signed"
fi

echo
echo "iPhoneOS application audit passed:"
echo "  bundle         $APP"
echo "  architecture   $(lipo -archs "$BINARY")"
echo "  signing        $SIGNATURE_STATE"
echo "  binary sha256  $(shasum -a 256 "$BINARY" | awk '{print $1}')"
echo "  archive content sha256 $EXPECTED_PORT_CONTENT_SHA256"
echo "  controller db  $EXPECTED_CONTROLLER_SHA256"
