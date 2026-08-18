#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/spaghettipad-controller-tests"

mkdir -p "$BUILD_DIR"
"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror \
    -I"$ROOT/ios" \
    "$ROOT/tests/controller_slots_test.cpp" \
    -o "$BUILD_DIR/controller_slots_test"
"$BUILD_DIR/controller_slots_test"

echo "Controller slot regression passed."
