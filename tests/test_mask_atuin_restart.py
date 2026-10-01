"""Exercise the mask restart recipe without touching the real user services."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


MASK = Path(__file__).resolve().parents[1] / "maskfile.md"


class RestartTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.proc = self.root / "proc"
        self.proc.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "STATE": str(self.state),
            "CONFIGURED": "yes",
        }
        self.stub("systemctl", """\
case "$*" in
    '--user cat atuin-ai-proxy.service --no-pager') [ "$CONFIGURED" = yes ] ;;
    '--user stop atuin-ai-proxy.service')
        echo 'stop proxy' >> "$STATE/calls"
        [ "$PROXY_STOPS" != yes ] || rm -f "$STATE/busy" ;;
    '--user start atuin-ai-proxy.service') echo 'start proxy' >> "$STATE/calls" ;;
    '--user restart atuin-ai-server.service') echo 'restart server' >> "$STATE/calls" ;;
    *) exit 2 ;;
esac
""")
        self.stub("ss", """\
[ ! -f "$STATE/busy" ] || echo 'LISTEN 127.0.0.1:8082'
""")
        self.stub("sleep", ":")
        self.script = MASK.read_text().split("### restart\n", 1)[1].split("~~~sh\n", 1)[1].split("~~~", 1)[0]
        # kill is a shell builtin, so a PATH stub would not intercept it.
        self.script = '''kill() {
    echo "kill $*" >> "$STATE/calls"
    [ "$KILL_CLEARS" != yes ] || rm -f "$STATE/busy"
}
''' + self.script
        # The recipe's /proc scan is exercised against fake process entries.
        self.script = self.script.replace("/proc/", f"{self.proc}/")

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def process(self, pid, cgroup, command):
        entry = self.proc / str(pid)
        entry.mkdir()
        (entry / "cgroup").write_text(cgroup + "\n")
        (entry / "cmdline").write_bytes(command.encode() + b"\0")

    def run_restart(self):
        result = subprocess.run(["sh", "-c", self.script], env=self.env, capture_output=True, text=True)
        calls = self.state / "calls"
        return result, calls.read_text().splitlines() if calls.exists() else []

    def test_stale_proxy_is_terminated_before_restart(self):
        (self.state / "busy").touch()
        self.process(486, "0::/user.slice/app.slice/atuin-ai-proxy.service", "/nix/store/old/bin/.litellm-wrapper")
        self.env["KILL_CLEARS"] = "yes"
        result, calls = self.run_restart()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["stop proxy", "kill -TERM 486", "start proxy", "restart server"])

    def test_normal_restart_needs_no_kill(self):
        result, calls = self.run_restart()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["stop proxy", "start proxy", "restart server"])

    def test_other_listener_is_never_killed_or_overwritten(self):
        (self.state / "busy").touch()
        self.process(999, "0::/user.slice/app.slice/other.service", "/usr/bin/other")
        result, calls = self.run_restart()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("8082", result.stderr)
        self.assertEqual(calls, ["stop proxy"])

    def test_other_litellm_service_is_not_killed(self):
        (self.state / "busy").touch()
        self.process(999, "0::/user.slice/app.slice/other.service", "/nix/store/other/bin/.litellm-wrapper")
        result, calls = self.run_restart()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, ["stop proxy"])

    def test_other_process_in_proxy_cgroup_is_not_killed(self):
        (self.state / "busy").touch()
        self.process(999, "0::/user.slice/app.slice/atuin-ai-proxy.service", "/usr/bin/other")
        result, calls = self.run_restart()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, ["stop proxy"])

    def test_unreleased_stale_listener_fails_instead_of_claiming_success(self):
        (self.state / "busy").touch()
        self.process(486, "0::/user.slice/app.slice/atuin-ai-proxy.service", "/nix/store/old/bin/.litellm-wrapper")
        result, calls = self.run_restart()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("8082", result.stderr)
        self.assertEqual(calls, ["stop proxy", "kill -TERM 486"])

    def test_llama_backend_does_not_touch_proxy(self):
        self.env["CONFIGURED"] = "no"
        (self.state / "busy").touch()
        result, calls = self.run_restart()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["restart server"])


if __name__ == "__main__":
    unittest.main()
