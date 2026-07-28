#!/usr/bin/env bash
# Hash archive paths and uncompressed contents while ignoring ZIP timestamps.
set -euo pipefail

ARCHIVE="${1:-}"

if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
    echo "usage: $0 <spaghetti.o2r>" >&2
    exit 1
fi

for command in awk shasum sort unzip; do
    command -v "$command" >/dev/null || {
        echo "required command is unavailable: $command" >&2
        exit 1
    }
done

unzip -Z1 "$ARCHIVE" |
    LC_ALL=C sort |
    while IFS= read -r entry; do
        case "$entry" in
            */) continue ;;
        esac
        entry_sha="$(unzip -p "$ARCHIVE" "$entry" |
            shasum -a 256 |
            awk '{print $1}')"
        printf '%s  %s\n' "$entry_sha" "$entry"
    done |
    shasum -a 256 |
    awk '{print $1}'
