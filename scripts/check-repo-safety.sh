#!/usr/bin/env bash
# ROM-free repository gate for local checks and CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "Repository safety check failed: $*" >&2
    exit 1
}

current_files="$(git ls-files --cached --others --exclude-standard | sort -u)"

tracked_ref_files="$(printf '%s\n' "$current_files" | grep '^ref/' || true)"
if [ -n "$tracked_ref_files" ]; then
    printf '%s\n' "$tracked_ref_files" >&2
    fail "ref/ must remain entirely local and untracked"
fi

forbidden_extensions='\.(z64|n64|v64|rom|o2r|otr|mpq|ipa|xcarchive|mobileprovision|provisionprofile|p12|p8|pem|key)(/|$)'
forbidden_current="$(printf '%s\n' "$current_files" |
    grep -Ei "$forbidden_extensions|(^|/)[^/]+\.app/" || true)"
if [ -n "$forbidden_current" ]; then
    printf '%s\n' "$forbidden_current" >&2
    fail "game data, generated packages, app bundles, or signing material is present"
fi

history_paths="$(git rev-list --objects --all |
    awk 'NF > 1 { sub(/^[^ ]+ /, ""); print }')"
forbidden_history="$(printf '%s\n' "$history_paths" |
    grep -Ei "$forbidden_extensions|(^|/)[^/]+\.app/|^ref/" || true)"
if [ -n "$forbidden_history" ]; then
    printf '%s\n' "$forbidden_history" >&2
    fail "forbidden material exists in Git history"
fi

while IFS= read -r file; do
    [ -f "$file" ] || continue
    size="$(wc -c < "$file")"
    if [ "$size" -gt 5242880 ]; then
        echo "$file ($size bytes)" >&2
        fail "tracked file exceeds the 5 MiB review limit"
    fi
done < <(printf '%s\n' "$current_files")

credential_pattern='(-----BEGIN [A-Z ]*PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})'
credential_hits=""
while IFS= read -r file; do
    [ -f "$file" ] || continue
    matches="$(grep -nEI "$credential_pattern" "$file" 2>/dev/null || true)"
    if [ -n "$matches" ]; then
        credential_hits="${credential_hits}${file}:${matches}"$'\n'
    fi
done < <(printf '%s\n' "$current_files")
if [ -n "$credential_hits" ]; then
    printf '%s' "$credential_hits" >&2
    fail "a likely credential or private key exists in the current tree"
fi

credential_history="$(git log --all --format='%H' \
    -G "$credential_pattern" -- . \
    ':(exclude)scripts/check-repo-safety.sh')"
if [ -n "$credential_history" ]; then
    printf '%s\n' "$credential_history" >&2
    fail "a likely credential or private key exists in Git history"
fi

public_identifier_pattern='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}|/Users/[^/]+/'
public_identifier_hits="$(rg -n -I -e "$public_identifier_pattern" \
    --glob '*.md' README.md RIGHTS_AND_LICENSES.md docs || true)"
if [ -n "$public_identifier_hits" ]; then
    printf '%s\n' "$public_identifier_hits" >&2
    fail "public documentation contains a local user path or UUID-shaped identifier"
fi

bash -n scripts/*.sh
for script in scripts/*.sh; do
    [ -x "$script" ] || fail "$script is not executable"
done

while IFS= read -r patch; do
    git apply --numstat "$patch" >/dev/null ||
        fail "$patch is not a syntactically valid patch"
done < <(find patches -maxdepth 1 -type f -name '*.patch' -print 2>/dev/null | sort)

python3 - "$ROOT" <<'PY'
import pathlib
import re
import subprocess
import sys
import urllib.parse

root = pathlib.Path(sys.argv[1])
markdown = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
    cwd=root,
    text=True,
).splitlines()
missing = []
patterns = [
    re.compile(r"!?\[[^\]]*\]\(([^)\s]+)"),
    re.compile(r'<(?:img|a)\b[^>]+(?:src|href)="([^"]+)"', re.IGNORECASE),
]

for relative in markdown:
    document = root / relative
    if not document.is_file():
        continue
    text = document.read_text(encoding="utf-8")
    for pattern in patterns:
        for raw_target in pattern.findall(text):
            target = raw_target.strip("<>")
            if target.startswith(("#", "/", "http://", "https://", "mailto:")):
                continue
            target = urllib.parse.unquote(target.split("#", 1)[0].split("?", 1)[0])
            if target and not (document.parent / target).exists():
                missing.append(f"{relative}: {raw_target}")

if missing:
    print("Missing local Markdown targets:", file=sys.stderr)
    print("\n".join(missing), file=sys.stderr)
    raise SystemExit(1)
PY

git check-ignore -q --no-index ref/rom.z64 ||
    fail "ref/ ROM inputs are not ignored"
git check-ignore -q --no-index sources/bootstrap-probe ||
    fail "sources/ is not ignored"
git fsck --full --strict --no-dangling

echo "Repository safety checks passed."
