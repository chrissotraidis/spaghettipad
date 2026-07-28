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

for command in codesign date file find lipo mktemp plutil rg security shasum \
    unzip xcrun; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

[ -d "$APP" ] || fail "application bundle is missing: $APP"
INFO="$APP/Info.plist"
[ -f "$INFO" ] || fail "Info.plist is missing"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")"
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
    SIGNING_AUDIT_DIR="$(mktemp -d /tmp/spaghettipad-signing-audit.XXXXXX)"
    trap 'rm -rf "$SIGNING_AUDIT_DIR"' EXIT
    PROFILE_PLIST="$SIGNING_AUDIT_DIR/profile.plist"
    CODE_ENTITLEMENTS="$SIGNING_AUDIT_DIR/code-entitlements.plist"

    security cms -D -i "$APP/embedded.mobileprovision" \
        -o "$PROFILE_PLIST" >/dev/null 2>&1 ||
        fail "embedded provisioning profile cannot be decoded"
    codesign -d --entitlements :- "$APP" \
        >"$CODE_ENTITLEMENTS" 2>/dev/null ||
        fail "signed app entitlements cannot be decoded"
    plutil -lint "$PROFILE_PLIST" "$CODE_ENTITLEMENTS" >/dev/null ||
        fail "signed app or profile entitlements are invalid"

    PROFILE_APP_ID="$(/usr/libexec/PlistBuddy \
        -c 'Print :Entitlements:application-identifier' \
        "$PROFILE_PLIST" 2>/dev/null || true)"
    PROFILE_TEAM="$(/usr/libexec/PlistBuddy \
        -c 'Print :Entitlements:com.apple.developer.team-identifier' \
        "$PROFILE_PLIST" 2>/dev/null || true)"
    PROFILE_IDENTIFIER_PREFIX="$(/usr/libexec/PlistBuddy \
        -c 'Print :ApplicationIdentifierPrefix:0' \
        "$PROFILE_PLIST" 2>/dev/null || true)"
    PROFILE_EXPIRATION="$(plutil -extract ExpirationDate raw -o - \
        "$PROFILE_PLIST" 2>/dev/null || true)"
    PROFILE_EXPIRATION_EPOCH="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' \
        "$PROFILE_EXPIRATION" '+%s' 2>/dev/null || true)"
    CODE_APP_ID="$(/usr/libexec/PlistBuddy \
        -c 'Print :application-identifier' \
        "$CODE_ENTITLEMENTS" 2>/dev/null || true)"
    CODE_TEAM="$(/usr/libexec/PlistBuddy \
        -c 'Print :com.apple.developer.team-identifier' \
        "$CODE_ENTITLEMENTS" 2>/dev/null || true)"

    [ -n "$PROFILE_APP_ID" ] && [ -n "$PROFILE_TEAM" ] &&
        [ -n "$PROFILE_IDENTIFIER_PREFIX" ] && [ -n "$CODE_APP_ID" ] &&
        [ -n "$CODE_TEAM" ] && [ -n "$PROFILE_EXPIRATION_EPOCH" ] ||
        fail "signed app or profile lacks required application entitlements"
    [ "$PROFILE_EXPIRATION_EPOCH" -gt "$(date +%s)" ] ||
        fail "embedded provisioning profile is expired"
    [ "$PROFILE_TEAM" = "$CODE_TEAM" ] ||
        fail "code-signing team does not match the provisioning profile"
    [ "$CODE_APP_ID" = "$PROFILE_IDENTIFIER_PREFIX.$BUNDLE_ID" ] ||
        fail "signed application identifier does not match the bundle identifier"
    if [ "$PROFILE_APP_ID" != "$CODE_APP_ID" ]; then
        PROFILE_AUTH_PREFIX="${PROFILE_APP_ID%\*}"
        [ "$PROFILE_AUTH_PREFIX" != "$PROFILE_APP_ID" ] ||
            fail "provisioning profile does not authorize the signed application"
        case "$CODE_APP_ID" in
            "$PROFILE_AUTH_PREFIX"*) ;;
            *) fail "provisioning profile does not authorize the signed application" ;;
        esac
    fi
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
