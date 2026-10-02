#!/usr/bin/env python3
"""CI-only orchestration of the experimental native-host module build."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--padmint-source', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--expected-host', required=True,
                        choices=('windows-x86_64', 'linux-x86_64', 'windows-arm64', 'linux-arm64'))
    args = parser.parse_args()
    sys.path.insert(0, str(args.padmint_source.resolve()))
    from padmint import tools
    from padmint.manifest import host_id
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    os.environ['PADMINT_HOME'] = str(work / 'padmint-home')
    host = host_id()
    if host != args.expected_host:
        parser.error(f'expected native {args.expected_host}, but Python reports {host}')
    names = ['llvm', 'libcxx', 'apple-libc', 'apple-xnu', 'apple-libpthread',
             'apple-libmalloc', 'apple-libplatform', 'apple-availability']
    tools.install(names, host)
    env = tools.environment(names, host)
    scripts = Path(__file__).resolve().parent
    inputs, sdk, output = work / 'inputs', work / 'iPhoneOS-open-source.sdk', work / 'private-output'
    def run(name, *arguments):
        subprocess.run([sys.executable, str(scripts / name), *map(str, arguments)], env=env, check=True)
    run('fetch-ios-module-inputs.py', '--output', inputs)
    run('prepare-ios-module-headers.py', '--kartpad-source', inputs / 'kartpad', '--output', sdk)
    suffix = '.exe' if os.name == 'nt' else ''
    llvm = Path(env['PADMINT_LLVM_ROOT']) / 'bin'
    run('build-ios-game-module.py', '--source', inputs / 'source', '--runtime', inputs / 'runtime',
        '--torch', inputs / 'torch', '--dependencies', inputs / 'dependencies',
        '--imgui', inputs / 'dependencies/imgui-src', '--sdl-compat', inputs / 'sdl-compat',
        '--sdk', sdk, '--clang', llvm / ('clang' + suffix), '--linker', llvm / ('ld64.lld' + suffix),
        '--output', output, '--jobs', '2')
    subprocess.run([str(llvm / ('llvm-readobj' + suffix)), '--file-headers',
                    str(output / 'SpaghettiGame.dylib')], check=True)
    result = json.loads(next(output.glob('attempt-*/results.json')).read_text())
    assert len(result['compiles']) == 282 and result['link']['exit_code'] == 0
    print(json.dumps({'host': host, 'translation_units': len(result['compiles']),
                      'sha256': result['sha256'], 'device_loading_verified': False}))
    subprocess.run([sys.executable, str(scripts.parent / 'tests/check_native_module_audit.py'),
                    '--source', str(inputs / 'source'), '--module', str(output / 'SpaghettiGame.dylib'),
                    '--llvm', str(llvm), '--work', str(work / 'synthetic-audit-fixture'),
                    '--notice-root', str(inputs)], env=env, check=True)
    # Keep generated game code on the ephemeral runner. No artifact upload.


if __name__ == '__main__':
    main()
