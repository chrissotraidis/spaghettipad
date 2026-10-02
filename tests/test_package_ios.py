import importlib.util
from pathlib import Path
import plistlib
import stat
import tempfile
import unittest
from unittest import mock
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "package_ios", Path(__file__).resolve().parents[1] / "scripts/package-ios.py")
package = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package)


class PackageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="ipa spaces ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.app = self.root / "input app/SpaghettiPad.app"
        self.app.mkdir(parents=True)
        self.info = {"CFBundleExecutable": "SpaghettiPad", "CFBundleShortVersionString": "0.2.1",
                     "CFBundleVersion": "12"}
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))
        (self.app / "SpaghettiPad").write_bytes(b"synthetic executable - not a device acceptance test")
        for relative in ("RIGHTS_AND_LICENSES.md", "THIRD_PARTY_NOTICES/SDL_GameControllerDB.LICENSE",
                         "sources/spaghettikart/LICENSE", "build-ios/_deps/lib/LICENSE.txt"):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("synthetic notice " + relative)
        self.output = self.root / "output with spaces/personal.ipa"

    def write(self):
        return package.write_package(self.root, self.app, self.output, False)

    def test_payload_notices_permissions_and_repeat(self):
        self.write()
        before = self.output.read_bytes()
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(len(archive.namelist()), 6)
            self.assertEqual(archive.read("Payload/SpaghettiPad.app/SpaghettiPad"),
                             (self.app / "SpaghettiPad").read_bytes())
            self.assertEqual(archive.getinfo("Payload/SpaghettiPad.app/SpaghettiPad").external_attr >> 16,
                             stat.S_IFREG | 0o755)
            for relative in ("sources/spaghettikart/LICENSE", "build-ios/_deps/lib/LICENSE.txt"):
                self.assertEqual(archive.read("ThirdPartyLicenses/" + relative),
                                 (self.root / relative).read_bytes())
        self.write()
        self.assertEqual(self.output.read_bytes(), before)

    def test_missing_notice_and_game_data_preserve_existing_output(self):
        self.write()
        before = self.output.read_bytes()
        for name in ("player.z64", "mk64.o2r", "other.otr", "embedded.mobileprovision"):
            with self.subTest(name=name):
                path = self.app / name
                path.write_bytes(b"synthetic")
                with self.assertRaises(ValueError):
                    self.write()
                path.unlink()
                self.assertEqual(self.output.read_bytes(), before)
        (self.root / "RIGHTS_AND_LICENSES.md").unlink()
        with self.assertRaisesRegex(ValueError, "notice is missing"):
            self.write()
        self.assertEqual(self.output.read_bytes(), before)

    def test_interrupted_write_preserves_existing_ipa_and_retry(self):
        self.write()
        before = self.output.read_bytes()
        with mock.patch.object(zipfile.ZipFile, "writestr", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(OSError, "disk full"):
                self.write()
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(list(self.output.parent.iterdir()), [self.output])
        self.write()

    def test_cli_requires_audit_before_serialization(self):
        import subprocess
        with mock.patch("sys.argv", ["package-ios.py", str(self.app), str(self.output)]), \
                mock.patch.object(package.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "audit")) as audit, \
                mock.patch.object(package, "write_package") as write:
            with self.assertRaises(SystemExit):
                package.main()
        write.assert_not_called()
        self.assertEqual(audit.call_args.kwargs["env"]["REQUIRE_UNSIGNED"], "1")
        self.assertTrue(audit.call_args.kwargs["check"])

    def test_signed_serialization_preserves_signing_bytes(self):
        (self.app / "embedded.mobileprovision").write_bytes(b"synthetic profile")
        (self.app / "_CodeSignature").mkdir()
        (self.app / "_CodeSignature/CodeResources").write_bytes(b"synthetic signature")
        package.write_package(self.root, self.app, self.output, True)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.read("Payload/SpaghettiPad.app/embedded.mobileprovision"),
                             b"synthetic profile")
            self.assertEqual(archive.read("Payload/SpaghettiPad.app/_CodeSignature/CodeResources"),
                             b"synthetic signature")

    def test_experimental_route_cannot_bypass_signed_or_failed_audit(self):
        argv = ["package-ios.py", str(self.app), str(self.output),
                "--experimental-module-tools", str(self.root / "llvm"),
                "--dependency-root", str(self.root / "build-ios/_deps")]
        with mock.patch("sys.argv", argv), mock.patch.dict(package.os.environ, REQUIRE_SIGNED="1"), \
                mock.patch.object(package.subprocess, "run") as audit, \
                mock.patch.object(package, "write_package") as write:
            with self.assertRaises(SystemExit):
                package.main()
            audit.assert_not_called()
            write.assert_not_called()
        with mock.patch("sys.argv", argv), mock.patch.dict(package.os.environ, REQUIRE_SIGNED="0"), \
                mock.patch.object(package.subprocess, "run", side_effect=package.subprocess.CalledProcessError(1, "audit")) as audit, \
                mock.patch.object(package, "write_package") as write:
            with self.assertRaises(SystemExit):
                package.main()
            self.assertTrue(audit.call_args.args[0][1].endswith("audit-ios-module-app.py"))
            write.assert_not_called()

    def test_output_inside_app_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "inside the application"):
            package.write_package(self.root, self.app, self.app / "nested/output.ipa", False)
        self.assertFalse((self.app / "nested").exists())

    def test_separate_dependency_notices_and_invalid_root_preserve_output(self):
        with tempfile.TemporaryDirectory(prefix="runtime dependencies ") as temporary:
            dependencies = Path(temporary)
            notice = dependencies / "runtime-lib/LICENSE.txt"
            notice.parent.mkdir()
            notice.write_bytes(b"runtime dependency notice")
            package.write_package(self.root, self.app, self.output, False, dependencies)
            before = self.output.read_bytes()
            with zipfile.ZipFile(self.output) as archive:
                self.assertEqual(archive.read("ThirdPartyLicenses/dependencies/runtime-lib/LICENSE.txt"),
                                 notice.read_bytes())
                self.assertNotIn("ThirdPartyLicenses/build-ios/_deps/lib/LICENSE.txt", archive.namelist())
                self.assertIn("ThirdPartyLicenses/sources/spaghettikart/LICENSE", archive.namelist())
            notice.unlink()
            for invalid in (dependencies, dependencies / "missing"):
                with self.subTest(directory=invalid), self.assertRaisesRegex(ValueError, "notice directory"):
                    package.write_package(self.root, self.app, self.output, False, invalid)
                self.assertEqual(self.output.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
