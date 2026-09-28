"""Exercise the login helper with a fake device flow; never use real credentials."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


LOGIN = Path(__file__).resolve().parents[1] / "features/atuin/_login.py"
STUB = '''
import os
from pathlib import Path

class Authenticator:
    def get_api_key(self):
        directory = Path(os.environ["GITHUB_COPILOT_TOKEN_DIR"])
        # A cached OAuth token prevents LiteLLM from initiating the device flow.
        if (directory / "access-token").exists():
            raise RuntimeError("reused revoked OAuth token")
        (directory / "access-token").write_text("new-oauth")
        (directory / "api-key.json").write_text('{"token":"new-copilot"}')
        if os.environ.get("FAIL_DEVICE_FLOW"):
            raise RuntimeError("device flow rejected")
        return "new-copilot"
'''


class LoginTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.token_dir = root / "tokens"
        self.token_dir.mkdir()
        (self.token_dir / "access-token").write_text("revoked-oauth")
        (self.token_dir / "api-key.json").write_text('{"token":"expired-copilot"}')
        stub = root / "stub/litellm/llms/github_copilot"
        stub.mkdir(parents=True)
        (stub / "authenticator.py").write_text(STUB)
        self.env = {**os.environ, "PYTHONPATH": str(root / "stub"), "GITHUB_COPILOT_TOKEN_DIR": str(self.token_dir)}

    def run_login(self):
        return subprocess.run([sys.executable, str(LOGIN)], env=self.env, capture_output=True, text=True)

    def test_revoked_cached_token_starts_fresh_device_flow(self):
        result = self.run_login()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.token_dir / "access-token").read_text(), "new-oauth")
        self.assertEqual((self.token_dir / "api-key.json").read_text(), '{"token":"new-copilot"}')
        self.assertEqual((self.token_dir / "access-token").stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.token_dir / "api-key.json").stat().st_mode & 0o777, 0o600)

    def test_first_login_creates_private_token_directory(self):
        for file in self.token_dir.iterdir():
            file.unlink()
        self.token_dir.rmdir()
        result = self.run_login()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.token_dir / "access-token").read_text(), "new-oauth")
        self.assertEqual(self.token_dir.stat().st_mode & 0o777, 0o700)

    def test_failed_device_flow_does_not_replace_existing_credentials(self):
        self.env["FAIL_DEVICE_FLOW"] = "1"
        result = self.run_login()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.token_dir / "access-token").read_text(), "revoked-oauth")
        self.assertEqual((self.token_dir / "api-key.json").read_text(), '{"token":"expired-copilot"}')


if __name__ == "__main__":
    unittest.main()
