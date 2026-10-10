"""Exercise credential setup with disposable, fake configurations only."""

import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "development_defines.py"
VALID = {
    "TRACESTRACK_API_KEY": "fake-tracestrack-secret",
    "TRACESTRACK_REFERER": "https://example.test/",
    "MAPY_CZ_API_KEY": "fake-mapy-secret",
}


class DevelopmentDefinesTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "dart_defines.local.json"

    def run_tool(self, receive=False, payload=None):
        command = [sys.executable, str(SCRIPT), "--file", str(self.path)]
        if receive:
            command.append("--receive")
        result = subprocess.run(command, input=payload, capture_output=True)
        output = result.stdout + result.stderr
        for value in VALID.values():
            self.assertNotIn(value.encode(), output)
        return result

    def test_seeds_absent_configuration_with_private_permissions(self):
        payload = json.dumps(VALID).encode()
        result = self.run_tool(receive=True, payload=payload)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.path.read_bytes(), payload)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)

    def test_preserves_existing_valid_copy(self):
        payload = json.dumps(VALID).encode()
        self.path.write_bytes(payload)
        result = self.run_tool(receive=True, payload=b"not the existing copy")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.path.read_bytes(), payload)

    def test_reports_invalid_existing_copy_without_overwriting(self):
        payload = b'{"TRACESTRACK_API_KEY": "fake-tracestrack-secret",'
        self.path.write_bytes(payload)
        result = self.run_tool(receive=True, payload=json.dumps(VALID).encode())
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.path.read_bytes(), payload)
        self.assertIn(b"deliberate correction", result.stderr)

    def test_rejects_invalid_incoming_data_without_creating_file(self):
        for payload in [b"[]", b"{}", b"\xff", b"not JSON"]:
            with self.subTest(payload=payload):
                result = self.run_tool(receive=True, payload=payload)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.path.exists())

    def test_rejects_examples_missing_fields_and_invalid_referer(self):
        for updates in [
            {"MAPY_CZ_API_KEY": "replace-with-your-mapy-api-key"},
            {"MAPY_CZ_API_KEY": " "},
            {"TRACESTRACK_API_KEY": None},
            {"TRACESTRACK_REFERER": "not a URL"},
        ]:
            with self.subTest(updates=updates):
                self.path.write_text(json.dumps({**VALID, **updates}))
                self.assertNotEqual(self.run_tool().returncode, 0)

    def test_validation_is_read_only(self):
        payload = json.dumps(VALID).encode()
        self.path.write_bytes(payload)
        self.assertEqual(self.run_tool().returncode, 0)
        self.assertEqual(self.path.read_bytes(), payload)

    def test_dangling_symlink_is_not_an_absent_file(self):
        target = self.path.parent / "missing.json"
        self.path.symlink_to(target)
        result = self.run_tool(receive=True, payload=json.dumps(VALID).encode())
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.path.is_symlink())
        self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
