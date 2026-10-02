import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location(
    'assembly', Path(__file__).resolve().parents[1] / 'scripts/assemble-ios-module-app.py')
assembly = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assembly)


class AssemblyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='assembly spaces ')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.app = self.root / 'runtime.app'
        self.app.mkdir()
        (self.app / 'Info.plist').write_bytes(plistlib.dumps(
            {'CFBundleExecutable': 'SpaghettiPad', 'MinimumOSVersion': '15.0'}))
        (self.app / 'SpaghettiPad').write_bytes(b'synthetic runtime')
        self.module = self.root / 'module.dylib'
        self.module.write_bytes(b'synthetic module')
        self.output = self.root / 'output.app'

    def assemble(self):
        return assembly.assemble(self.app, self.module, self.output, 'readobj', 'nm')

    def test_copy_preserves_inputs_and_rejects_existing_output(self):
        exports = set((assembly.ROOT / 'ios/runtime-exports.txt').read_text().splitlines())
        with mock.patch.object(assembly, 'inspect_binary'), \
                mock.patch.object(assembly, 'exported_symbols', return_value=exports):
            self.assemble()
        self.assertEqual((self.output / 'Frameworks/SpaghettiGame.dylib').read_bytes(), self.module.read_bytes())
        self.assertFalse((self.app / 'Frameworks').exists())
        with self.assertRaisesRegex(ValueError, 'already exists'):
            self.assemble()
        self.assertEqual((self.output / 'SpaghettiPad').read_bytes(), b'synthetic runtime')

    def test_wrong_platform_type_and_missing_exports_are_rejected(self):
        report = 'MachHeader {\nFormat: Mach-O arm64\nArch: aarch64\nFileType: DynamicLibrary (0x6)\n}\nMinVersion {\nPlatform: ios\nVersion: 15.0\n}\n'
        with mock.patch.object(assembly.subprocess, 'check_output', return_value=report):
            assembly.inspect_binary(self.module, 'DynamicLibrary', 'readobj')
        for bad in (report.replace('ios', 'iossimulator'), report.replace('DynamicLibrary', 'Executable'),
                    report.replace('15.0', '15.1'), report + report,
                    report + 'MinVersion {\nPlatform: iossimulator\nVersion: 15.0\n}\n'):
            with self.subTest(report=bad), mock.patch.object(assembly.subprocess, 'check_output', return_value=bad):
                with self.assertRaises(ValueError):
                    assembly.inspect_binary(self.module, 'DynamicLibrary', 'readobj')
        with mock.patch.object(assembly, 'inspect_binary'), \
                mock.patch.object(assembly, 'exported_symbols', return_value=set()):
            with self.assertRaisesRegex(ValueError, 'missing required exports'):
                self.assemble()
        self.assertFalse(self.output.exists())

    def test_signing_material_is_preserved_and_refused(self):
        profile = self.app / 'embedded.mobileprovision'
        profile.write_bytes(b'synthetic profile')
        with self.assertRaisesRegex(ValueError, 'signing material'):
            self.assemble()
        self.assertEqual(profile.read_bytes(), b'synthetic profile')
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
