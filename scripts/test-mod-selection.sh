#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror \
    -I"$ROOT/sources/spaghettikart/src/engine/mods" \
    "$ROOT/tests/mod_selection_test.cpp" -o "$TEST_DIR/mod-selection"
"$TEST_DIR/mod-selection"
