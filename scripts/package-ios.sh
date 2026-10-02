#!/usr/bin/env bash
# Audit a device app and wrap it as a ROM-free IPA.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/scripts/package-ios.py" "$@"
