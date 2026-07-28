#!/usr/bin/env bash
# Reproduce the maintained SpaghettiPad application from pinned inputs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---device}"

case "$MODE" in
    --device)
        MODE="device"
        ;;
    --simulator)
        MODE="simulator"
        ;;
    *)
        echo "Usage: scripts/build-ios.sh [--device|--simulator]" >&2
        exit 2
        ;;
esac

if [ ! -d "$ROOT/sources/spaghettikart/.git" ]; then
    "$ROOT/scripts/clone-sources.sh"
fi
if [ ! -s "$ROOT/build-oracle/spaghetti.o2r" ]; then
    "$ROOT/scripts/build-oracle.sh"
fi

if [ "$MODE" = "simulator" ]; then
    BUILD_DIR="${SPAGHETTIPAD_SIM_BUILD_DIR:-$ROOT/build-ios-sim}"
    "$ROOT/scripts/configure-ios.sh" --simulator
else
    BUILD_DIR="${SPAGHETTIPAD_IOS_BUILD_DIR:-$ROOT/build-ios}"
    "$ROOT/scripts/configure-ios.sh"
fi

if [ "$MODE" = "simulator" ]; then
    cmake --build "$BUILD_DIR" --config Release --target Spaghettify \
        --parallel "${IOS_BUILD_JOBS:-4}" -- CODE_SIGNING_ALLOWED=NO
    echo
    echo "Simulator app:"
    echo "  $BUILD_DIR/Release-iphonesimulator/SpaghettiPad.app"
    exit 0
fi

APP="$BUILD_DIR/Release-iphoneos/SpaghettiPad.app"
if [ -d "$APP" ]; then
    rm -rf "$APP"
fi

set -- cmake --build "$BUILD_DIR" --config Release --target Spaghettify \
    --parallel "${IOS_BUILD_JOBS:-4}" -- -destination generic/platform=iOS
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    set -- "$@" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
fi
"$@"

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    REQUIRE_UNSIGNED=1 "$ROOT/scripts/audit-ios-app.sh" "$APP"
else
    REQUIRE_SIGNED=1 "$ROOT/scripts/audit-ios-app.sh" "$APP"
fi

echo
echo "Device app:"
echo "  $APP"
