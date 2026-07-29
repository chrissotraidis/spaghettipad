#!/usr/bin/env bash
# Install a signed build and capture the automated Phase 6 hardware evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${SPAGHETTIPAD_DEVICE:-}"
APP="${SPAGHETTIPAD_APP:-$ROOT/build-ios/Release-iphoneos/SpaghettiPad.app}"
STABILITY_SECONDS="${SPAGHETTIPAD_STABILITY_SECONDS:-600}"
SAMPLE_SECONDS="${SPAGHETTIPAD_SAMPLE_SECONDS:-30}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${SPAGHETTIPAD_EVIDENCE_DIR:-$ROOT/ref/evidence/phase6-hardware-$TIMESTAMP}"
EVIDENCE_READY=0

fail() {
    printf 'Phase 6 hardware smoke failed: %s\n' "$*" >&2
    if [ "$EVIDENCE_READY" = "1" ]; then
        printf '%s\n' "$*" >"$EVIDENCE_DIR/FAILURE.txt"
    fi
    exit 1
}

require_positive_integer() {
    case "$2" in
        ''|*[!0-9]*|0) fail "$1 must be a positive integer" ;;
    esac
}

[ -n "$DEVICE" ] ||
    fail "set SPAGHETTIPAD_DEVICE to the paired iPhone/iPad name or identifier"
[ -d "$APP" ] || fail "signed application bundle is missing: $APP"
require_positive_integer "SPAGHETTIPAD_STABILITY_SECONDS" "$STABILITY_SECONDS"
require_positive_integer "SPAGHETTIPAD_SAMPLE_SECONDS" "$SAMPLE_SECONDS"

for command in awk codesign date find git mktemp plutil rg shasum sleep \
    sw_vers xargs xcodebuild xcrun; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

if [ -e "$EVIDENCE_DIR" ] && [ -n "$(find "$EVIDENCE_DIR" -mindepth 1 -print -quit)" ]; then
    fail "evidence directory is not empty: $EVIDENCE_DIR"
fi
mkdir -p "$EVIDENCE_DIR"
EVIDENCE_READY=1

INFO="$APP/Info.plist"
[ -f "$INFO" ] || fail "Info.plist is missing from $APP"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")"
BINARY="$APP/$EXECUTABLE_NAME"
[ -f "$BINARY" ] || fail "application executable is missing: $BINARY"

REQUIRE_SIGNED=1 "$ROOT/scripts/audit-ios-app.sh" "$APP" \
    >"$EVIDENCE_DIR/app-audit.txt" 2>&1 ||
    fail "the app is not a valid signed SpaghettiPad device build"

codesign -d --verbose=4 "$APP" >"$EVIDENCE_DIR/codesign.txt" 2>&1 ||
    fail "codesign metadata could not be read"
xcrun devicectl list devices --timeout 15 \
    --json-output "$EVIDENCE_DIR/devices.json" \
    --log-output "$EVIDENCE_DIR/devices.log" >/dev/null ||
    fail "CoreDevice could not list paired devices"
xcrun devicectl device info details --device "$DEVICE" --timeout 30 \
    --json-output "$EVIDENCE_DIR/device-details-before.json" \
    --log-output "$EVIDENCE_DIR/device-details-before.log" >/dev/null ||
    fail "CoreDevice cannot reach '$DEVICE'; unlock, pair, and enable Developer Mode"

{
    printf 'captured_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'repository_commit=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
    printf 'repository_status_begin\n'
    git -C "$ROOT" status --short
    printf 'repository_status_end\n'
    printf 'device_selector=%s\n' "$DEVICE"
    printf 'app=%s\n' "$APP"
    printf 'bundle_identifier=%s\n' "$BUNDLE_ID"
    printf 'app_version=%s\n' \
        "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")"
    printf 'build_number=%s\n' \
        "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO")"
    printf 'executable_sha256=%s\n' \
        "$(shasum -a 256 "$BINARY" | awk '{print $1}')"
    printf 'stability_seconds=%s\n' "$STABILITY_SECONDS"
    printf 'sample_seconds=%s\n' "$SAMPLE_SECONDS"
    sw_vers
    xcodebuild -version
} >"$EVIDENCE_DIR/session.txt"

printf 'Installing %s on %s...\n' "$BUNDLE_ID" "$DEVICE"
xcrun devicectl device install app --device "$DEVICE" "$APP" --timeout 180 \
    --json-output "$EVIDENCE_DIR/install.json" \
    --log-output "$EVIDENCE_DIR/install.log" >/dev/null ||
    fail "installation failed; inspect install.log"

printf 'Cold-launching %s...\n' "$BUNDLE_ID"
xcrun devicectl device process launch --device "$DEVICE" \
    --terminate-existing --activate "$BUNDLE_ID" --timeout 60 \
    --json-output "$EVIDENCE_DIR/launch.json" \
    --log-output "$EVIDENCE_DIR/launch.log" >/dev/null ||
    fail "launch failed; inspect launch.log"

START_EPOCH="$(date +%s)"
while :; do
    ELAPSED="$(($(date +%s) - START_EPOCH))"
    SAMPLE_PATH="$EVIDENCE_DIR/process-$ELAPSED.json"
    xcrun devicectl device info processes --device "$DEVICE" \
        --filter "Name == '$EXECUTABLE_NAME'" --timeout 30 \
        --json-output "$SAMPLE_PATH" \
        --log-output "$EVIDENCE_DIR/process-$ELAPSED.log" >/dev/null ||
        fail "process query failed after $ELAPSED seconds"
    plutil -p "$SAMPLE_PATH" >/dev/null ||
        fail "CoreDevice returned invalid process JSON after $ELAPSED seconds"
    rg -Fq "$EXECUTABLE_NAME" "$SAMPLE_PATH" ||
        fail "$EXECUTABLE_NAME was no longer running after $ELAPSED seconds"

    ELAPSED="$(($(date +%s) - START_EPOCH))"
    [ "$ELAPSED" -ge "$STABILITY_SECONDS" ] && break
    REMAINING="$((STABILITY_SECONDS - ELAPSED))"
    WAIT_SECONDS="$SAMPLE_SECONDS"
    [ "$REMAINING" -lt "$WAIT_SECONDS" ] && WAIT_SECONDS="$REMAINING"
    sleep "$WAIT_SECONDS"
done

xcrun devicectl device info details --device "$DEVICE" --timeout 30 \
    --json-output "$EVIDENCE_DIR/device-details-after.json" \
    --log-output "$EVIDENCE_DIR/device-details-after.log" >/dev/null ||
    fail "final device-details capture failed"

OBSERVATION="pending"
if [ -t 0 ]; then
    printf '\nType YES only if the Mario Kart 64 title/demo stayed visible and\n'
    printf 'responsive throughout the run with no watchdog termination: '
    if read -r RESPONSE && [ "$RESPONSE" = "YES" ]; then
        OBSERVATION="confirmed by operator"
    fi
fi

AUTOMATED_GATE="diagnostic only (less than 600 seconds)"
if [ "$STABILITY_SECONDS" -ge 600 ]; then
    AUTOMATED_GATE="passed"
fi

{
    printf '# Phase 6 hardware smoke\n\n'
    printf -- '- Automated install, cold-launch, and process-stability gate: **%s**\n' \
        "$AUTOMATED_GATE"
    printf -- '- Requested duration: %s seconds\n' "$STABILITY_SECONDS"
    printf -- '- Observed elapsed time: %s seconds\n' "$ELAPSED"
    printf -- '- Title/demo observation: **%s**\n' "$OBSERVATION"
    printf -- '- Bundle identifier: `%s`\n' "$BUNDLE_ID"
    printf -- '- Executable SHA-256: `%s`\n' \
        "$(shasum -a 256 "$BINARY" | awk '{print $1}')"
    printf -- '- Repository commit: `%s`\n\n' "$(git -C "$ROOT" rev-parse HEAD)"
    printf 'Phase 6 closes only after the operator confirms the visible title/demo,\n'
    printf 'attaches a device screenshot or recording, and this evidence is reviewed\n'
    printf 'and entered into `docs/remaining-work.md` with device model and OS.\n'
} >"$EVIDENCE_DIR/summary.md"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS -print0 |
        LC_ALL=C sort -z |
        xargs -0 shasum -a 256 >SHA256SUMS
)

printf '\nAutomated Phase 6 evidence captured at:\n  %s\n' "$EVIDENCE_DIR"
printf 'Manual title/demo observation: %s\n' "$OBSERVATION"
if [ "$AUTOMATED_GATE" != "passed" ]; then
    printf 'This shortened run is diagnostic and does not close Phase 6.\n'
elif [ "$OBSERVATION" = "pending" ]; then
    printf 'The automated gate passed; visible title/demo confirmation is still required.\n'
else
    printf 'The Phase 6 evidence bundle is ready for review and proof-log entry.\n'
fi
