#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="${1:-$ROOT/build-ios/_deps}"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
python3 "$ROOT/tests/mod_catalog/fixtures.py" "$TEMP"
"${CXX:-c++}" -std=c++20 -Wno-deprecated-literal-operator \
 -I"$ROOT/tests/mod_catalog/stubs" -I"$ROOT/sources/spaghettikart/src/engine/mods" \
 -I"$DEPS/semver" -I"$DEPS/tomlplusplus-src/include" -I"$DEPS/spdlog-src/include" \
 $(pkg-config --cflags libzip) \
 "$ROOT/sources/spaghettikart/src/engine/mods/ModCatalog.cpp" "$ROOT/tests/mod_catalog/catalog_test.cpp" \
 $(pkg-config --libs libzip) -o "$TEMP/test"
"$TEMP/test" "$TEMP"
