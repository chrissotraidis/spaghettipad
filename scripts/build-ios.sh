#!/usr/bin/env bash
# Build the maintained unsigned SpaghettiPad application.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="device"

if [ "${1:-}" = "--simulator" ]; then
    MODE="simulator"
fi

"$ROOT/scripts/configure-ios.sh" "$@"

if [ "$MODE" = "simulator" ]; then
    BUILD_DIR="${SPAGHETTIPAD_SIM_BUILD_DIR:-$ROOT/build-ios-sim}"
else
    BUILD_DIR="${SPAGHETTIPAD_IOS_BUILD_DIR:-$ROOT/build-ios}"
fi

cmake --build "$BUILD_DIR" --config Release --target Spaghettify \
    --parallel "${IOS_BUILD_JOBS:-4}" -- CODE_SIGNING_ALLOWED=NO

if [ "$MODE" = "device" ]; then
    "$ROOT/scripts/audit-ios-app.sh" \
        "$BUILD_DIR/Release-iphoneos/SpaghettiPad.app"
fi
