#!/usr/bin/env python3
"""Exercise audit rejection paths with a synthetic Mach-O host, never a playable app."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'module', 'llvm', 'work'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=False)
    suffix = '.exe' if (args.llvm / 'clang.exe').exists() else ''
    def tool(name):
        return str(args.llvm / (name + suffix))
    audit = runpy.run_path(str(ROOT / 'scripts/audit-ios-module-app.py'))['audit']
    resources = runpy.run_path(str(ROOT / 'scripts/build-port-archive.py'))
    app = args.work / 'SyntheticAudit.app'
    app.mkdir()
    symbols = set((ROOT / 'ios/runtime-exports.txt').read_text().splitlines())
    symbols.add('_OBJC_CLASS_$_SDLUIKitSceneDelegate')
    assembly = args.work / 'synthetic.s'
    assembly.write_text('.text\n' + ''.join(
        f'.globl "{s}"\n"{s}":\n  ret\n' for s in sorted(symbols)))
    obj = args.work / 'synthetic.o'
    subprocess.run([tool('clang'), '-target', 'arm64-apple-ios15.0', '-c', str(assembly), '-o', str(obj)], check=True)
    subprocess.run([tool('ld64.lld'), '-arch', 'arm64', '-platform_version', 'ios', '15.0', '15.0',
                    '-e', '_main', '-export_dynamic', '-o', str(app / 'SpaghettiPad'), str(obj)], check=True)
    info = plistlib.loads((ROOT / 'ios/Info.plist.in').read_bytes())
    info.update(CFBundleIdentifier='invalid.example.synthetic-audit', CFBundleShortVersionString='0.0.0', CFBundleVersion='1')
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    for name in ('config.yml', 'meta/mods.toml', 'yamls/us/textures/startup_logo.yml'):
        destination = app / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.source / name, destination)
    cmake = (args.source / 'CMakeLists.txt').read_text()
    pin = re.search(r'set\(CONTROLLER_DB_COMMIT "([0-9a-f]{40})"\)', cmake)
    if pin is None:
        raise ValueError('Missing maintained controller database pin')
    subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', '--connect-timeout', '10',
                    '--max-time', '60', '--output', str(app / 'gamecontrollerdb.txt'),
                    'https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/' + pin[1] + '/gamecontrollerdb.txt'], check=True)
    resources['build_archive'](args.source / 'assets', app / 'spaghetti.o2r')
    (app / 'Frameworks').mkdir()
    shutil.copyfile(args.module, app / 'Frameworks/SpaghettiGame.dylib')
    def check():
        return audit(app, tool('llvm-readobj'), tool('llvm-nm'))
    check()
    cases = [('embedded.mobileprovision', b'synthetic stale profile'), ('player.z64', b'synthetic placeholder'),
             ('gamecontrollerdb.txt', b'changed database'), ('Info.plist', plistlib.dumps({})),
             ('Frameworks/SpaghettiGame.dylib', (app / 'SpaghettiPad').read_bytes())]
    for name, data in cases:
        path = app / name
        before = path.read_bytes() if path.exists() else None
        path.write_bytes(data)
        try:
            check()
        except ValueError as error:
            print('Rejected', name, ':', error, flush=True)
        else:
            raise AssertionError('Accepted invalid fixture: ' + name)
        finally:
            if before is None:
                path.unlink()
            else:
                path.write_bytes(before)
    check()
    print(json.dumps({'synthetic_runtime': True, 'rejection_cases_passed': len(cases),
                      'device_loading_verified': False}))


if __name__ == '__main__':
    main()
