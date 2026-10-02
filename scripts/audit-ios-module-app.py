#!/usr/bin/env python3
"""Portable structural/resource audit of a private, unsigned iOS module app.

Does not verify signatures, resolve all imports, or establish device acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import runpy
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ASSEMBLY = runpy.run_path(str(ROOT / 'scripts/assemble-ios-module-app.py'))
RESOURCES = runpy.run_path(str(ROOT / 'scripts/build-port-archive.py'))
CONTROLLER_HASH = 'eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77'


def audit(app, readobj, nm):
    if not app.is_dir() or app.is_symlink():
        raise ValueError('Application must be a regular directory')
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('Application links are not supported by this unsigned audit')
        if path.name in ('_CodeSignature', 'embedded.mobileprovision'):
            raise ValueError('Signing material is present; use the Mac signing audit')
        if path.is_file() and (path.suffix.lower() in ('.z64', '.n64', '.v64', '.rom', '.otr')
                              or (path.suffix.lower() == '.o2r' and path.name != 'spaghetti.o2r')):
            raise ValueError('ROM-derived game data is embedded')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if not isinstance(info, dict):
        raise ValueError('App metadata must be a dictionary')
    expected = {'CFBundleExecutable': 'SpaghettiPad', 'CFBundleDisplayName': 'SpaghettiPad',
                'MinimumOSVersion': '15.0', 'UIDeviceFamily': [1, 2], 'UIFileSharingEnabled': True}
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError('Unexpected app metadata: ' + key)
    if not isinstance(info.get('CFBundleIdentifier'), str) or not info['CFBundleIdentifier']:
        raise ValueError('Missing bundle identifier')
    try:
        scene = info['UIApplicationSceneManifest']['UISceneConfigurations']['UIWindowSceneSessionRoleApplication'][0]
        if scene['UISceneDelegateClassName'] != 'SDLUIKitSceneDelegate':
            raise ValueError('Unexpected scene delegate')
    except (KeyError, TypeError, IndexError) as error:
        raise ValueError('SDL application scene configuration is missing') from error
    binary, module = app / 'SpaghettiPad', app / 'Frameworks/SpaghettiGame.dylib'
    ASSEMBLY['inspect_binary'](binary, 'Executable', readobj)
    ASSEMBLY['inspect_binary'](module, 'DynamicLibrary', readobj)
    exports = ASSEMBLY['exported_symbols'](binary, nm)
    required = set((ROOT / 'ios/runtime-exports.txt').read_text().splitlines())
    if required - exports:
        raise ValueError('Runtime is missing required exports: ' + ', '.join(sorted(required - exports)))
    # Objective-C finds this registered class without a public C export. Match
    # the Mac audit's symbol-presence check, separately from the module ABI.
    defined = set(subprocess.check_output([str(nm), '--defined-only', '--just-symbol-name',
                                          str(binary)], text=True).splitlines())
    if '_OBJC_CLASS_$_SDLUIKitSceneDelegate' not in defined:
        raise ValueError('SDL scene delegate is not linked')
    if '_SDL_main' not in ASSEMBLY['exported_symbols'](module, nm):
        raise ValueError('Game module does not export SDL_main')
    for name in ('config.yml', 'gamecontrollerdb.txt', 'meta/mods.toml', 'spaghetti.o2r',
                 'yamls/us/textures/startup_logo.yml'):
        if not (app / name).is_file():
            raise ValueError('Required runtime resource is missing: ' + name)
    if hashlib.sha256((app / 'gamecontrollerdb.txt').read_bytes()).hexdigest() != CONTROLLER_HASH:
        raise ValueError('Controller database hash changed')
    with zipfile.ZipFile(app / 'spaghetti.o2r') as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or archive.testzip() is not None:
            raise ValueError('Clean port archive is invalid')
        files = {n: archive.read(n) for n in names if not n.endswith('/')}
        if RESOURCES['content_hash'](files) != RESOURCES['EXPECTED_CONTENT']:
            raise ValueError('Clean port archive content hash changed')
    return {'check': 'unsigned-module-app-structure-and-resources',
            'runtime_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
            'module_sha256': hashlib.sha256(module.read_bytes()).hexdigest(),
            'signature_verification': 'not-performed', 'device_loading_verified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--llvm-readobj', type=Path, required=True)
    parser.add_argument('--llvm-nm', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = audit(args.app, args.llvm_readobj, args.llvm_nm)
    except (ValueError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException,
            zipfile.BadZipFile) as error:
        parser.exit(1, f'Unsigned module app audit: {error}\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
