#!/usr/bin/env bash
# Audit a device app and wrap it as a ROM-free IPA.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build-ios/Release-iphoneos/SpaghettiPad.app}"

if [[ "$APP" != /* ]]; then
    APP="$ROOT/$APP"
fi

REQUIRE_SIGNED="${REQUIRE_SIGNED:-0}"
case "$REQUIRE_SIGNED" in
    0)
        REQUIRE_UNSIGNED=1
        ;;
    1)
        REQUIRE_UNSIGNED=0
        ;;
    *)
        echo "REQUIRE_SIGNED must be 0 or 1." >&2
        exit 2
        ;;
esac

REQUIRE_SIGNED="$REQUIRE_SIGNED" REQUIRE_UNSIGNED="$REQUIRE_UNSIGNED" \
    "$ROOT/scripts/audit-ios-app.sh" "$APP"

INFO="$APP/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
   [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Refusing app with invalid release version: $VERSION ($BUILD_NUMBER)" >&2
    exit 1
fi

SIGNATURE_STATE="unsigned"
if codesign --verify --strict "$APP" >/dev/null 2>&1 &&
   [ -f "$APP/embedded.mobileprovision" ]; then
    SIGNATURE_STATE="signed"
fi

OUTPUT="${2:-$ROOT/artifacts/SpaghettiPad-${VERSION}-preview.${BUILD_NUMBER}-${SIGNATURE_STATE}.ipa}"
if [[ "$OUTPUT" != /* ]]; then
    OUTPUT="$ROOT/$OUTPUT"
fi

[ -f "$ROOT/RIGHTS_AND_LICENSES.md" ] || {
    echo "Required rights and licensing notice is missing." >&2
    exit 1
}
[ -f "$ROOT/THIRD_PARTY_NOTICES/SDL_GameControllerDB.LICENSE" ] || {
    echo "SDL_GameControllerDB license notice is missing." >&2
    exit 1
}

mkdir -p "$(dirname "$OUTPUT")"
PACKAGE_ROOT="$(mktemp -d /tmp/spaghettipad-package.XXXXXX)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
mkdir "$PACKAGE_ROOT/Payload"
ditto "$APP" "$PACKAGE_ROOT/Payload/SpaghettiPad.app"
cp "$ROOT/RIGHTS_AND_LICENSES.md" "$PACKAGE_ROOT/RIGHTS_AND_LICENSES.md"

LICENSES_DIR="$PACKAGE_ROOT/ThirdPartyLicenses"
mkdir "$LICENSES_DIR"
cp "$ROOT/THIRD_PARTY_NOTICES/SDL_GameControllerDB.LICENSE" \
    "$LICENSES_DIR/SDL_GameControllerDB.LICENSE"
LICENSE_COUNT=1
while IFS= read -r -d '' LICENSE_FILE; do
    RELATIVE="${LICENSE_FILE#"$ROOT/"}"
    DESTINATION="$LICENSES_DIR/$RELATIVE"
    mkdir -p "$(dirname "$DESTINATION")"
    cp "$LICENSE_FILE" "$DESTINATION"
    LICENSE_COUNT=$((LICENSE_COUNT + 1))
done < <(
    find "$ROOT/sources/spaghettikart" "$ROOT/build-ios/_deps" -type f \
        \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \) \
        -print0 | sort -z
)
[ "$LICENSE_COUNT" -gt 0 ] || {
    echo "No third-party license files were found for packaging." >&2
    exit 1
}

PACKAGE_ARCHIVE="$PACKAGE_ROOT/SpaghettiPad.ipa"
find "$PACKAGE_ROOT/Payload" "$PACKAGE_ROOT/RIGHTS_AND_LICENSES.md" \
    "$PACKAGE_ROOT/ThirdPartyLicenses" -exec touch -h -t 198001010000 {} +
(
    cd "$PACKAGE_ROOT"
    find Payload RIGHTS_AND_LICENSES.md ThirdPartyLicenses -print | \
        LC_ALL=C sort | zip -X -q -y "$PACKAGE_ARCHIVE" -@
)
mv "$PACKAGE_ARCHIVE" "$OUTPUT"

IPA_ENTRIES="$(unzip -Z1 "$OUTPUT")"
rg -q '^Payload/SpaghettiPad\.app/SpaghettiPad$' <<<"$IPA_ENTRIES" ||
    { echo "IPA payload verification failed: $OUTPUT" >&2; exit 1; }
rg -q '^RIGHTS_AND_LICENSES\.md$' <<<"$IPA_ENTRIES" ||
    { echo "IPA rights notice is missing: $OUTPUT" >&2; exit 1; }
rg -q '^ThirdPartyLicenses/' <<<"$IPA_ENTRIES" ||
    { echo "IPA third-party licenses are missing: $OUTPUT" >&2; exit 1; }
rg -q '^ThirdPartyLicenses/SDL_GameControllerDB\.LICENSE$' <<<"$IPA_ENTRIES" ||
    { echo "IPA controller database license is missing: $OUTPUT" >&2; exit 1; }

if rg -qi '\.(z64|n64|v64|rom)$|Payload/.*/mk64[^/]*\.o2r$|\.otr$' \
    <<<"$IPA_ENTRIES"; then
    echo "Refusing IPA containing ROM or ROM-derived data: $OUTPUT" >&2
    exit 1
fi
if [ "$SIGNATURE_STATE" = "unsigned" ] &&
   rg -q 'Payload/SpaghettiPad\.app/(_CodeSignature/|embedded\.mobileprovision$)' \
      <<<"$IPA_ENTRIES"; then
    echo "Refusing unsigned IPA containing signing material: $OUTPUT" >&2
    exit 1
fi

echo
echo "Packaged $SIGNATURE_STATE SpaghettiPad $VERSION ($BUILD_NUMBER)"
echo "  bundle identifier  $BUNDLE_ID"
echo "  third-party notices $LICENSE_COUNT"
echo "  IPA                 $OUTPUT"
shasum -a 256 "$OUTPUT"
if [ "$SIGNATURE_STATE" = "unsigned" ]; then
    echo "This proof artifact must be re-signed before standard-device installation."
fi
