#!/usr/bin/env bash
# Obtain the maintained app sources without rewriting local source files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/check-source-pins.py" --allow-missing
git -C "$ROOT" submodule update --init sources/spaghettikart
git -C "$ROOT/sources/spaghettikart" submodule update --init libultraship torch
python3 "$ROOT/scripts/check-source-pins.py"
