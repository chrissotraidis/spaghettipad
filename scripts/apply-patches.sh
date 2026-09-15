#!/usr/bin/env bash
# Compatibility entry point: production sources are now ordinary source commits.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/check-source-pins.py"
echo 'No source patches are applied; fixes belong in the maintained source branches.'
