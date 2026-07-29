#!/usr/bin/env bash
# Configure the maintained SpaghettiKart iOS application project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT/sources/spaghettikart"
PORT_ARCHIVE="${SPAGHETTIPAD_PORT_ARCHIVE:-$ROOT/build-oracle/spaghetti.o2r}"
MODE="device"

fail() {
    echo "iOS configure failed: $*" >&2
    exit 1
}

if [ "${1:-}" = "--simulator" ]; then
    MODE="simulator"
    shift
fi
[ "$#" -eq 0 ] || fail "unexpected argument: $1"

for command in cmake git; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

SPAGHETTIPAD_VERSION="${SPAGHETTIPAD_VERSION:-0.1.0}"
SPAGHETTIPAD_BUILD_NUMBER="${SPAGHETTIPAD_BUILD_NUMBER:-3}"
[[ "$SPAGHETTIPAD_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "SPAGHETTIPAD_VERSION must use numeric major.minor.patch form"
[[ "$SPAGHETTIPAD_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] ||
    fail "SPAGHETTIPAD_BUILD_NUMBER must be a positive integer"

[ -d "$SOURCE_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ -s "$PORT_ARCHIVE" ] ||
    fail "clean port archive is missing; run scripts/generate-port-archive.sh"

"$ROOT/scripts/apply-patches.sh"

if [ "$MODE" = "simulator" ]; then
    BUILD_DIR="${SPAGHETTIPAD_SIM_BUILD_DIR:-$ROOT/build-ios-sim}"
    PLATFORM="SIMULATORARM64"
    SDK="iphonesimulator"
else
    BUILD_DIR="${SPAGHETTIPAD_IOS_BUILD_DIR:-$ROOT/build-ios}"
    PLATFORM="OS64"
    SDK="iphoneos"
fi

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -GXcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DDEPLOYMENT_TARGET=15.0 \
    -DPLATFORM="$PLATFORM" \
    -DENABLE_SCRIPTING=OFF \
    -DSPAGHETTIPAD_SHELL_DIR="$ROOT/ios" \
    -DSPAGHETTIPAD_PORT_ARCHIVE="$PORT_ARCHIVE" \
    -DSPAGHETTIPAD_VERSION="$SPAGHETTIPAD_VERSION" \
    -DSPAGHETTIPAD_BUILD_NUMBER="$SPAGHETTIPAD_BUILD_NUMBER" \
    -DBUNDLE_ID="${BUNDLE_ID:-com.chrissotraidis.spaghettipad}" \
    -DDEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

echo
echo "Configured $MODE project: $BUILD_DIR/Spaghettify.xcodeproj"
