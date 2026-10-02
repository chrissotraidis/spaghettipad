import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "port_archive", Path(__file__).resolve().parents[1] / "scripts/build-port-archive.py")
archive = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(archive)


class PortArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="port archive with spaces ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "assets"
        (self.source / "nested").mkdir(parents=True)
        self.files = {"nested/resource.bin": b"synthetic resource", "config.txt": b"configuration"}
        for name, data in self.files.items():
            (self.source / name).write_bytes(data)
        self.digest = archive.content_hash(self.files)
        self.output = self.root / "output with spaces/spaghetti.o2r"

    def build(self):
        archive.build_archive(self.source, self.output, self.digest)

    def test_exact_paths_bytes_and_idempotent_retry(self):
        self.build()
        before = self.output.read_bytes()
        with zipfile.ZipFile(self.output) as z:
            self.assertIsNone(z.testzip())
            self.assertEqual({n: z.read(n) for n in z.namelist()}, self.files)
        self.build()
        self.assertEqual(self.output.read_bytes(), before)

    def test_source_drift_preserves_previous_output(self):
        self.build()
        before = self.output.read_bytes()
        (self.source / "config.txt").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "hash changed"):
            self.build()
        self.assertEqual(self.output.read_bytes(), before)

    def test_existing_conflicting_archive_is_preserved(self):
        self.output.parent.mkdir()
        with zipfile.ZipFile(self.output, "w") as z:
            z.writestr("player.txt", b"keep this")
        before = self.output.read_bytes()
        with self.assertRaisesRegex(ValueError, "differs"):
            self.build()
        self.assertEqual(self.output.read_bytes(), before)

    def test_interrupted_write_does_not_publish_partial_and_retry_works(self):
        with mock.patch.object(zipfile.ZipFile, "writestr", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(OSError, "disk full"):
                self.build()
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.output.parent.iterdir()), [])
        self.build()
        self.assertTrue(self.output.is_file())


if __name__ == "__main__":
    unittest.main()
