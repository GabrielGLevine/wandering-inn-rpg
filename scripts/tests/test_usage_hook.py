"""Hook behavior tests. Run: python3 scripts/tests/test_usage_hook.py -v"""
import json
import os
import subprocess
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HOOK_SH = os.path.join(HERE, "..", "usage_hook.sh")
SAFE_PATH = "/usr/bin:/bin"


def run_hook(home, env_extra, stdin_json=None):
    env = {"PATH": SAFE_PATH, "HOME": home}
    env.update(env_extra)
    payload = json.dumps(stdin_json or {"session_id": "testsess"})
    return subprocess.run(["bash", HOOK_SH], input=payload,
                          capture_output=True, text=True, env=env)


class TestHook(unittest.TestCase):
    def test_codex_notifies_once_from_provider_cache(self):
        with tempfile.TemporaryDirectory() as home:
            cache = os.path.join(home, "codex-cache.json")
            with open(cache, "w") as fh:
                json.dump({"ts": time.time(), "rateLimits": {
                    "primary": {"usedPercent": 90, "resetsAt": int(time.time()) + 3600},
                    "secondary": {"usedPercent": 10}}}, fh)
            env = {"CODEX_CI": "1", "CODEX_USAGE_GUARD_CACHE": cache}
            first = run_hook(home, env)
            self.assertEqual(first.returncode, 0)
            self.assertNotEqual(first.stdout.strip(), "", "Codex tier change was not surfaced")
            out = json.loads(first.stdout)
            self.assertIn("WINDDOWN", out["systemMessage"])
            self.assertIn("provider=codex", out["systemMessage"])
            second = run_hook(home, env)
            self.assertEqual(second.stdout.strip(), "")

    def test_notifies_once_on_escalation(self):
        with tempfile.TemporaryDirectory() as home:
            env = {"USAGE_GUARD_FAKE": "session=90 week=10"}
            first = run_hook(home, env)
            self.assertEqual(first.returncode, 0)
            out = json.loads(first.stdout)
            ctx = out["hookSpecificOutput"]["additionalContext"]
            self.assertIn("WINDDOWN", ctx)
            self.assertIn("wi-usage-guard", ctx)
            second = run_hook(home, env)
            self.assertEqual(second.returncode, 0)
            self.assertEqual(second.stdout.strip(), "")

    def test_silent_on_initial_ok(self):
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, {"USAGE_GUARD_FAKE": "session=10 week=5"})
            self.assertEqual(r.returncode, 0)
            self.assertEqual(r.stdout.strip(), "")

    def test_deescalation_notifies(self):
        with tempfile.TemporaryDirectory() as home:
            run_hook(home, {"USAGE_GUARD_FAKE": "session=90 week=10"})
            r = run_hook(home, {"USAGE_GUARD_FAKE": "session=5 week=5"})
            out = json.loads(r.stdout)
            self.assertIn("OK", out["hookSpecificOutput"]["additionalContext"])

    def test_fail_soft_corrupt_cache(self):
        with tempfile.TemporaryDirectory() as home:
            cache = os.path.join(home, "cache.json")
            with open(cache, "w") as fh:
                fh.write("{not json")
            r = run_hook(home, {"USAGE_GUARD_CACHE": cache})
            self.assertEqual(r.returncode, 0)

    def test_fail_soft_empty_stdin(self):
        with tempfile.TemporaryDirectory() as home:
            env = {"PATH": SAFE_PATH, "HOME": home}
            r = subprocess.run(["bash", HOOK_SH], input="",
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
