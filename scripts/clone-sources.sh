#!/usr/bin/env bash
# Obtain the maintained app sources without rewriting local source files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/check-source-pins.py" --allow-missing
# Preserve pinned resource/patch bytes even when the host defaults to CRLF.
# This affects new checkouts only; existing source edits are not rewritten.
git -c core.autocrlf=false -C "$ROOT" submodule update --init sources/spaghettikart
git -c core.autocrlf=false -C "$ROOT/sources/spaghettikart" submodule update --init libultraship torch
python3 "$ROOT/scripts/check-source-pins.py"
