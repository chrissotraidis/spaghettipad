#!/usr/bin/env python3
"""Exercise copied build entrypoints with synthetic inputs and command fixtures.

No source checkout, network request, compilation, signing, or game input is used.
SPAGHETTIPAD_BUILD_TEST_REF optionally selects entrypoints from a local Git ref
for baseline failure reproduction; otherwise the working scripts are copied.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
PIN = '5b28472d477bab101dee2a0f469fe2aee2c58a01'
HASHES = {
    'stb_image.h': 'c54b15a689e6a1f32c75e2ec23afa442e3e0e37e894b73c1974d08679b20dd5c',
    'sse2neon.h': '44fa833125ba4671b6c2bc0c520f11dbc22f02e9ca223f9d3e04af0db09fcfc6',
    'semver.hpp': 'af2c0c53124dc7f52c58a7205e458ad3efbac2f61ce55addf9c8f94338a04182',
}
PROFILES = (
    ('build-ios.sh', 'IOS_BUILD_JOBS', '--device', ''),
    ('build-ios.sh', 'IOS_BUILD_JOBS', '--device', 'FIXTURETEAM'),
    ('build-ios.sh', 'IOS_BUILD_JOBS', '--simulator', ''),
    ('build-oracle.sh', 'ORACLE_BUILD_JOBS', 'oracle', ''),
)

# Every external build/download/source command is replaced and recorded.
# The default compile fixture stops with 73, before an app audit or success.
COMMAND = r'''
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ['FIXTURE_ROOT'])
with (root / 'commands.jsonl').open('a') as log:
    log.write(json.dumps([name, args, os.environ.get('REQUIRE_SIGNED'),
                          os.environ.get('REQUIRE_UNSIGNED')]) + '\n')

def write(relative, content='synthetic fixture\n'):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return path

failure = os.environ.get('FIXTURE_FAILURE', '')
if name == 'git':
    if args[2:] == ['rev-parse', 'HEAD']:
        print('wrong-pin' if failure == 'pin' else os.environ['FIXTURE_PIN'])
    elif args[2:] in (['diff', '--quiet'], ['diff', '--cached', '--quiet']):
        if failure == ('dirty' if args[2:] == ['diff', '--quiet'] else 'staged'):
            sys.exit(1)
    else:
        sys.exit(99)
elif name == 'cmake':
    if args[0] == '-S':
        if failure == 'configure':
            sys.exit(71)
        for relative in ('_deps/stb/stb_image.h', '_deps/semver/semver.hpp'):
            if failure != 'missing-' + Path(relative).name:
                write('build-oracle/' + relative)
        (root / 'build-oracle/_deps/sse2neon').mkdir(parents=True, exist_ok=True)
    elif args[0] == '--build':
        if os.environ.get('FIXTURE_COMPILE', 'stop') == 'stop':
            sys.exit(73)
        if failure != 'missing-executable':
            write('build-oracle/Spaghettify').chmod(0o755)
        if failure != 'missing-archive':
            write('build-oracle/spaghetti.o2r')
    else:
        sys.exit(99)
elif name == 'curl':
    if failure == 'download':
        sys.exit(72)
    Path(args[args.index('-o') + 1]).write_text('synthetic fixture\n')
elif name == 'shasum':
    path = Path(args[-1])
    label = 'sse2neon.h' if path.name.startswith('reviewed.') else path.name
    hashes = json.loads(os.environ['FIXTURE_HASHES'])
    print(('bad-hash' if failure == 'hash-' + label else hashes[label]) + '  ' + str(path))
elif name in ('clone-sources.sh', 'clone-oracle-sources.sh'):
    if failure == 'clone':
        sys.exit(70)
    write('sources/' + ('oracle' if name == 'clone-oracle-sources.sh' else 'spaghettikart') + '/.git', '')
elif name == 'configure-ios.sh':
    if failure == 'configure':
        sys.exit(71)
elif name == 'audit-ios-app.sh':
    if failure == 'audit':
        sys.exit(74)
else:
    sys.exit(99)
'''


class BuildJobsTest(unittest.TestCase):
    def run_entrypoint(self, script, values=None, mode='--device', fresh=False,
                       failure='', compile_result='stop', stale_app=False):
        with tempfile.TemporaryDirectory(prefix='spaghettipad-jobs-') as directory:
            root = Path(directory)
            scripts = root / 'scripts'
            scripts.mkdir()
            for name in ('build-ios.sh', 'build-oracle.sh'):
                ref = os.environ.get('SPAGHETTIPAD_BUILD_TEST_REF')
                content = (subprocess.check_output(
                    ['git', 'show', ref + ':scripts/' + name], cwd=ROOT)
                    if ref else (ROOT / 'scripts' / name).read_bytes())
                (scripts / name).write_bytes(content)
                (scripts / name).chmod(0o755)
            command = root / 'command-fixture'
            command.write_text('#!' + sys.executable + '\n' + COMMAND)
            command.chmod(0o755)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            for name in ('cmake', 'git', 'curl', 'shasum', 'ninja'):
                (bin_dir / name).symlink_to(command)
            for name in ('clone-sources.sh', 'clone-oracle-sources.sh',
                         'configure-ios.sh', 'audit-ios-app.sh'):
                (scripts / name).symlink_to(command)
            if not fresh:
                for source in ('oracle', 'spaghettikart'):
                    path = root / 'sources' / source
                    path.mkdir(parents=True)
                    (path / '.git').touch()
                (root / 'build-oracle').mkdir()
                (root / 'build-oracle/spaghetti.o2r').write_text('synthetic fixture\n')
            sentinel = root / 'build-ios/Release-iphoneos/SpaghettiPad.app/sentinel'
            if stale_app:
                sentinel.parent.mkdir(parents=True)
                sentinel.write_text('preserve before validation\n')
            # Inherit no build, signing, SDK, or private-input environment.
            env = {
                'PATH': str(bin_dir) + ':/usr/bin:/bin',
                'FIXTURE_ROOT': str(root), 'FIXTURE_PIN': PIN,
                'FIXTURE_HASHES': json.dumps(HASHES),
                'FIXTURE_FAILURE': failure, 'FIXTURE_COMPILE': compile_result,
            }
            env.update(values or {})
            args = ['/bin/bash', str(scripts / script)]
            if script == 'build-ios.sh':
                args.append(mode)
            result = subprocess.run(args, cwd=root, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    timeout=15)
            log = root / 'commands.jsonl'
            commands = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, commands, sentinel.exists()

    def builds(self, commands):
        return [args for name, args, _, _ in commands
                if name == 'cmake' and args[0] == '--build']

    def assert_jobs(self, commands, expected, count=1):
        builds = self.builds(commands)
        self.assertEqual(len(builds), count)
        for args in builds:
            self.assertEqual(args[args.index('--parallel') + 1], expected)

    def test_environment_two(self):
        for script in ('build-ios.sh', 'build-oracle.sh'):
            for mode in ('--device', '--simulator') if script == 'build-ios.sh' else ('oracle',):
                with self.subTest(script=script, mode=mode):
                    result, commands, _ = self.run_entrypoint(
                        script, {'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, mode)
                    self.assertEqual(result.returncode, 73, result.stderr)
                    self.assert_jobs(commands, '2')
                    self.assertNotIn('complete:', result.stdout)
                    self.assertFalse(any(c[0] == 'audit-ios-app.sh' for c in commands))

    def test_precedence_and_default(self):
        cases = [({}, '4'), ({'CMAKE_BUILD_PARALLEL_LEVEL': ''}, '4'),
                 ({'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, '2'),
                 ({'MANUAL': ''}, '4'),
                 ({'MANUAL': '', 'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, '2'),
                 ({'MANUAL': '3', 'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, '3'),
                 ({'MANUAL': '3', 'CMAKE_BUILD_PARALLEL_LEVEL': 'bad'}, '3'),
                 ({'MANUAL': '3'}, '3')]
        for script, manual, mode, team in PROFILES:
            for values, expected in cases:
                values = {manual if k == 'MANUAL' else k: v for k, v in values.items()}
                values['DEVELOPMENT_TEAM'] = team
                with self.subTest(script=script, mode=mode, values=values):
                    oracle = script == 'build-oracle.sh'
                    result, commands, _ = self.run_entrypoint(
                        script, values, mode, compile_result='success' if oracle else 'stop')
                    self.assertEqual(result.returncode, 0 if oracle else 73, result.stderr)
                    self.assert_jobs(commands, expected, count=2 if oracle else 1)

    def test_invalid_before_side_effects(self):
        for script, manual, mode, team in PROFILES:
            for value in ('0', '00', '02', '-1', '+2', '1.5', 'two', ' 2', '2 ', '2\n'):
                for selected in (manual, 'CMAKE_BUILD_PARALLEL_LEVEL'):
                    with self.subTest(script=script, mode=mode, team=team, selected=selected, value=value):
                        values = {'CMAKE_BUILD_PARALLEL_LEVEL': '2', selected: value,
                                  'DEVELOPMENT_TEAM': team}
                        result, commands, sentinel = self.run_entrypoint(
                            script, values, mode, fresh=True, stale_app=True)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn('must be a positive integer with no leading zeroes', result.stderr)
                        self.assertEqual(commands, [])
                        self.assertTrue(sentinel)

    def test_ios_signing_and_current_app(self):
        for mode in ('--device', '--simulator'):
            for team in ('', 'FIXTURETEAM'):
                with self.subTest(mode=mode, team=team):
                    result, commands, sentinel = self.run_entrypoint(
                        'build-ios.sh', {'CMAKE_BUILD_PARALLEL_LEVEL': '2',
                                         'DEVELOPMENT_TEAM': team}, mode,
                        compile_result='success', stale_app=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assert_jobs(commands, '2')
                    build = self.builds(commands)[0]
                    audits = [c for c in commands if c[0] == 'audit-ios-app.sh']
                    config = [c[1] for c in commands if c[0] == 'configure-ios.sh']
                    if mode == '--simulator':
                        self.assertEqual(config, [['--simulator']])
                        self.assertEqual(build[build.index('--') + 1:], ['CODE_SIGNING_ALLOWED=NO'])
                        self.assertEqual(audits, [])
                        self.assertTrue(sentinel)
                    else:
                        self.assertEqual(config, [[]])
                        expected = ['-destination', 'generic/platform=iOS']
                        if not team:
                            expected += ['CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO']
                        self.assertEqual(build[build.index('--') + 1:], expected)
                        self.assertEqual(len(audits), 1)
                        self.assertEqual(audits[0][2:], ['1', None] if team else [None, '1'])
                        self.assertFalse(sentinel)

    def test_fresh_oracle_is_required(self):
        for mode in ('--device', '--simulator'):
            with self.subTest(mode=mode):
                result, commands, _ = self.run_entrypoint(
                    'build-ios.sh', {'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, mode, fresh=True)
                self.assertEqual(result.returncode, 73, result.stderr)
                self.assertEqual(commands[0][0], 'clone-sources.sh')
                self.assertIn('clone-oracle-sources.sh', [c[0] for c in commands])
                self.assert_jobs(commands, '2')
                self.assertEqual(self.builds(commands)[0][self.builds(commands)[0].index('--target') + 1], 'GenerateO2R')
                self.assertNotIn('configure-ios.sh', [c[0] for c in commands])

    def test_fresh_oracle_then_ios_counts(self):
        cases = [({}, ['4', '4', '4']),
                 ({'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, ['2', '2', '2']),
                 ({'CMAKE_BUILD_PARALLEL_LEVEL': '2', 'IOS_BUILD_JOBS': '3',
                   'ORACLE_BUILD_JOBS': '5'}, ['5', '5', '3'])]
        for script, _, mode, team in PROFILES[:3]:
            for values, expected in cases:
                with self.subTest(mode=mode, team=team, values=values):
                    result, commands, _ = self.run_entrypoint(
                        script, dict(values, DEVELOPMENT_TEAM=team), mode,
                        fresh=True, compile_result='success')
                    self.assertEqual(result.returncode, 0, result.stderr)
                    builds = self.builds(commands)
                    self.assertEqual([a[a.index('--parallel') + 1] for a in builds], expected)
                    self.assertEqual([a[a.index('--target') + 1] for a in builds],
                                     ['GenerateO2R', 'Spaghettify', 'Spaghettify'])

    def test_oracle_both_builds_and_output_guards(self):
        for failure in ('', 'missing-executable', 'missing-archive'):
            with self.subTest(failure=failure):
                result, commands, _ = self.run_entrypoint(
                    'build-oracle.sh', {'CMAKE_BUILD_PARALLEL_LEVEL': '2'},
                    fresh=True, failure=failure, compile_result='success')
                self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                self.assert_jobs(commands, '2', count=2)
                self.assertEqual([a[a.index('--target') + 1] for a in self.builds(commands)],
                                 ['GenerateO2R', 'Spaghettify'])
                if failure:
                    self.assertIn('was not produced', result.stderr)
                curls = [c[1] for c in commands if c[0] == 'curl']
                self.assertEqual(len(curls), 1)
                self.assertEqual(curls[0][4], 'https://raw.githubusercontent.com/DLTcollab/sse2neon/8f03de354e8a87426b94dadd57dbd55b544810c3/sse2neon.h')

    def test_fail_closed(self):
        failures = ('pin', 'dirty', 'staged', 'configure', 'download',
                    'hash-stb_image.h', 'hash-sse2neon.h', 'hash-semver.hpp',
                    'missing-stb_image.h', 'missing-semver.hpp')
        for failure in failures:
            with self.subTest(failure=failure):
                result, commands, _ = self.run_entrypoint(
                    'build-oracle.sh', {'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.builds(commands), [])
        for mode in ('--device', '--simulator'):
            for failure in ('clone', 'configure', 'pin', 'download', 'hash-stb_image.h'):
                with self.subTest(mode=mode, failure=failure):
                    result, commands, sentinel = self.run_entrypoint(
                        'build-ios.sh', {'CMAKE_BUILD_PARALLEL_LEVEL': '2'}, mode,
                        fresh=failure != 'configure', failure=failure, stale_app=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.builds(commands), [])
                    self.assertTrue(sentinel)
        for team in ('', 'FIXTURETEAM'):
            result, commands, _ = self.run_entrypoint(
                'build-ios.sh', {'CMAKE_BUILD_PARALLEL_LEVEL': '2', 'DEVELOPMENT_TEAM': team},
                failure='audit', compile_result='success')
            self.assertEqual(result.returncode, 74)
            self.assertNotIn('Device app:', result.stdout)


if __name__ == '__main__':
    unittest.main()
