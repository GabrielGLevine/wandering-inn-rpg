"""CLI tests for usage_status.sh. Run: python3 scripts/tests/test_usage_status_cli.py -v
Never invokes the real `claude` CLI (PATH is restricted)."""
import json
import os
import subprocess
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
STATUS_SH = os.path.join(HERE, "..", "usage_status.sh")
SAFE_PATH = "/usr/bin:/bin"  # python3 lives here on macOS; `claude` does not


def run_status(env_extra, args=()):
    env = {"PATH": SAFE_PATH, "HOME": env_extra.pop("HOME", "/tmp")}
    env.update(env_extra)
    return subprocess.run(["bash", STATUS_SH, *args],
                          capture_output=True, text=True, env=env)


class TestStatusCLI(unittest.TestCase):
    def test_fake_winddown_exit_20(self):
        r = run_status({"USAGE_GUARD_FAKE": "session=90 week=10"})
        self.assertEqual(r.returncode, 20)
        self.assertTrue(r.stdout.startswith("WINDDOWN"), r.stdout)

    def test_fake_quiesce_exit_30(self):
        r = run_status({"USAGE_GUARD_FAKE": "session=96 week=10"})
        self.assertEqual(r.returncode, 30)

    def test_fake_dynamic_escalation(self):
        r = run_status(
            {"USAGE_GUARD_FAKE": "session=55 week=10 rate=0.75 mins_to_reset=120"})
        self.assertEqual(r.returncode, 10)
        self.assertIn("burn", r.stdout)

    def test_fresh_cache_used_without_claude(self):
        now = time.time()
        with tempfile.TemporaryDirectory() as td:
            cache = os.path.join(td, "cache.json")
            with open(cache, "w") as fh:
                json.dump([{"ts": now - 60, "session_pct": 72, "week_pct": 5,
                            "fable_pct": 5, "session_reset_ts": now + 3600,
                            "week_reset_ts": None}], fh)
            r = run_status({"USAGE_GUARD_CACHE": cache, "HOME": td})
            self.assertEqual(r.returncode, 10)
            self.assertTrue(r.stdout.startswith("CAUTION"), r.stdout)

    def test_unknown_when_no_cache_and_no_claude(self):
        with tempfile.TemporaryDirectory() as td:
            cache = os.path.join(td, "cache.json")
            r = run_status({"USAGE_GUARD_CACHE": cache, "HOME": td})
            self.assertEqual(r.returncode, 0)
            self.assertTrue(r.stdout.startswith("UNKNOWN"), r.stdout)

    def test_stale_cache_served_when_refresh_fails(self):
        # 10-min-old sample + no `claude` on PATH: refresh fails, stale
        # sample must still serve, marked "(stale Nm)" — not UNKNOWN
        now = time.time()
        with tempfile.TemporaryDirectory() as td:
            cache = os.path.join(td, "cache.json")
            with open(cache, "w") as fh:
                json.dump([{"ts": now - 600, "session_pct": 72, "week_pct": 5,
                            "fable_pct": 5, "session_reset_ts": now + 3600,
                            "week_reset_ts": None}], fh)
            r = run_status({"USAGE_GUARD_CACHE": cache, "HOME": td})
            self.assertEqual(r.returncode, 10)
            self.assertTrue(r.stdout.startswith("CAUTION"), r.stdout)
            self.assertIn("stale", r.stdout)

    def test_readonly_cache_with_fake_claude(self):
        # Make a tiny fake `claude` executable in a temp dir, put that on PATH,
        # point USAGE_GUARD_CACHE at a path whose parent is a regular file
        # (so cache write fails), run usage_status.sh with the fake claude.
        # Should parse fresh sample and exit with correct tier (not 1).
        now = time.time()
        with tempfile.TemporaryDirectory() as td:
            # Create fake claude script
            bin_dir = os.path.join(td, "bin")
            os.makedirs(bin_dir)
            claude_exe = os.path.join(bin_dir, "claude")
            with open(claude_exe, "w") as fh:
                fh.write("""#!/bin/bash
cat <<'EOT'
Current session: 72% used · resets Jul 12 at 4:40am (America/Chicago)
Current week (all models): 5% used · resets Jul 18 at 8pm (America/Chicago)
Current week (Fable): 5% used · resets Jul 18 at 8pm (America/Chicago)
EOT
""")
            os.chmod(claude_exe, 0o755)

            # Create cache path whose parent is a regular file (uncreatable)
            cache_dir_blocker = os.path.join(td, "blocker_file")
            with open(cache_dir_blocker, "w") as fh:
                fh.write("This blocks any attempt to mkdir")
            cache = os.path.join(cache_dir_blocker, "cache.json")

            # Set PATH to include our fake claude
            path = bin_dir + ":/usr/bin:/bin"
            r = run_status({"USAGE_GUARD_CACHE": cache, "HOME": td, "PATH": path})
            # Expect CAUTION tier (72% session), exit 10
            self.assertEqual(r.returncode, 10, f"Output: {r.stdout}, Stderr: {r.stderr}")
            self.assertTrue(r.stdout.startswith("CAUTION"), r.stdout)
            # Fresh sample should NOT have "(stale" marker
            self.assertNotIn("stale", r.stdout)


if __name__ == "__main__":
    unittest.main()
