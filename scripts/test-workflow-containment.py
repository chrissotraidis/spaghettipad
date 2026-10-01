"""Keep personal-use app packages out of public CI artifact downloads."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WorkflowContainmentTest(unittest.TestCase):
    def test_ios_ci_does_not_upload_personal_app(self):
        workflow = (ROOT / '.github/workflows/ios-build.yml').read_text()
        self.assertIsNone(re.search(
            r'(?m)^\s*(?:-\s*)?uses:\s*actions/upload-artifact@', workflow),
            'This full app is personal-use only; CI must not upload it.')

    def test_compile_package_and_signing_checks_remain(self):
        workflow = (ROOT / '.github/workflows/ios-build.yml').read_text()
        for command in ('scripts/build-ios.sh --device',
                        'scripts/package-ios.sh',
                        'REQUIRE_SIGNED=1 scripts/package-ios.sh'):
            self.assertIn(command, workflow)


if __name__ == '__main__':
    unittest.main()
