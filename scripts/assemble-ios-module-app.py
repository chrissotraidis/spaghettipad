#!/usr/bin/env python3
"""Copy an unsigned runtime and private module into a fresh app for later signing."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def inspect_binary(path, file_type, readobj):
    report = subprocess.check_output([str(readobj), '--file-headers', '--macho-version-min', str(path)], text=True)
    required = ('Format: Mach-O arm64', 'Arch: aarch64', 'FileType: ' + file_type,
                'Platform: ios', 'Version: 15.0')
    if report.count('MachHeader {') != 1 or report.count('MinVersion {') != 1 or any(
            not re.search(r'^\s*' + re.escape(line) + r'(?:\s|$)', report, re.M) for line in required):
        raise ValueError(f'{path.name} must be a thin arm64 iOS 15.0 {file_type}')


def exported_symbols(path, nm):
    return set(subprocess.check_output([str(nm), '--defined-only', '--extern-only',
                                       '--just-symbol-name', str(path)], text=True).splitlines())


def assemble(app, module, output, readobj, nm):
    if output.exists() or output.is_symlink():
        raise ValueError('Output already exists; choose a new app path')
    if output.suffix != '.app' or output.resolve().is_relative_to(app.resolve()):
        raise ValueError('Output must be a separate .app directory')
    if not app.is_dir() or app.is_symlink() or not module.is_file() or module.is_symlink():
        raise ValueError('Runtime and module must be regular local inputs')
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('Runtime bundle must not contain symlinks')
        if path.name in ('_CodeSignature', 'embedded.mobileprovision'):
            raise ValueError('Use an unsigned runtime; existing signing material is not removed')
    if (app / 'Frameworks/SpaghettiGame.dylib').exists():
        raise ValueError('Runtime already contains a game module')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleExecutable') != 'SpaghettiPad' or info.get('MinimumOSVersion') != '15.0':
        raise ValueError('Unexpected runtime executable or minimum OS')
    binary = app / 'SpaghettiPad'
    inspect_binary(binary, 'Executable', readobj)
    inspect_binary(module, 'DynamicLibrary', readobj)
    expected = set((ROOT / 'ios/runtime-exports.txt').read_text().splitlines())
    missing = expected - exported_symbols(binary, nm)
    if missing:
        raise ValueError('Runtime is missing required exports: ' + ', '.join(sorted(missing)))
    if '_SDL_main' not in exported_symbols(module, nm):
        raise ValueError('Game module does not export SDL_main')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='module-app-', dir=output.parent) as temporary:
        staged = Path(temporary) / output.name
        shutil.copytree(app, staged)
        destination = staged / 'Frameworks/SpaghettiGame.dylib'
        destination.parent.mkdir(exist_ok=True)
        shutil.copy2(module, destination)
        destination.chmod(0o755)
        module_hash = hashlib.sha256(module.read_bytes()).hexdigest()
        if hashlib.sha256(destination.read_bytes()).hexdigest() != module_hash:
            raise ValueError('Module copy failed byte verification')
        if output.exists() or output.is_symlink():
            raise ValueError('Output appeared during assembly; preserved without replacement')
        staged.rename(output)
    return {'app': str(output), 'module_sha256': module_hash,
            'required_runtime_exports': len(expected), 'device_loading_verified': False,
            'signing': 'required'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('runtime', 'module', 'output', 'llvm-readobj', 'llvm-nm'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        result = assemble(args.runtime, args.module, args.output, args.llvm_readobj, args.llvm_nm)
    except (ValueError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        parser.exit(1, f'Module assembly: {error}\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
