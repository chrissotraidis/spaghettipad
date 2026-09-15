#!/usr/bin/env python3
"""Reject missing, dirty or mismatched maintained source inputs before building."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
allow_missing = sys.argv[1:] == ['--allow-missing']
if sys.argv[1:] and not allow_missing:
    raise SystemExit('Usage: check-source-pins.py [--allow-missing]')

def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()

for item in json.loads((root / 'sources.lock.json').read_text())['components']:
    path = root / item['path']
    if not (path / '.git').exists():
        if allow_missing:
            continue
        raise SystemExit(f"Missing {item['path']}; run scripts/clone-sources.sh")
    if git(path, 'rev-parse', 'HEAD') != item['commit']:
        raise SystemExit(f"Wrong commit in {item['path']}; preserve local work and use a fresh checkout")
    if git(path, 'status', '--porcelain', '--untracked-files=all', '--ignore-submodules=all'):
        raise SystemExit(f"Dirty source in {item['path']}; preserve changes before building")
    subprocess.run(['git', '-C', str(path), 'merge-base', '--is-ancestor', item['base'], item['commit']], check=True)
    parent = root if item['path'] == 'sources/spaghettikart' else root / 'sources/spaghettikart'
    relative = 'sources/spaghettikart' if parent == root else path.name
    url = git(parent, 'config', '-f', '.gitmodules', f'submodule.{relative}.url')
    if url.removesuffix('.git') != item['repository'].removesuffix('.git'):
        raise SystemExit(f"Submodule URL disagrees with lock: {item['path']}")
    record = git(parent, 'ls-files', '--stage', '--', relative).split()
    if len(record) < 2 or record[0] != '160000' or record[1] != item['commit']:
        raise SystemExit(f"Gitlink disagrees with lock: {item['path']}")
print('Maintained source pins and clean inputs verified.' if not allow_missing else 'Existing source inputs verified.')
