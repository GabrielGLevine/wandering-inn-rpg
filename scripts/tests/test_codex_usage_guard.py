"""Unit tests for the Codex app-server usage adapter."""

import importlib.util
import multiprocessing
import os
import tempfile
import time
import unittest
import json
from types import SimpleNamespace


HERE = os.path.dirname(os.path.abspath(__file__))
MODULE_PATH = os.path.join(HERE, "..", "codex_usage_guard.py")
SPEC = importlib.util.spec_from_file_location("codex_usage_guard", MODULE_PATH)
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


def partial_line_worker(read_fd, result_queue):
    stream = os.fdopen(read_fd, "r")
    try:
        GUARD.read_response(SimpleNamespace(stdout=stream), 1, time.monotonic() + 0.1)
    except Exception as error:
        result_queue.put(type(error).__name__)
    finally:
        stream.close()


def lock_worker(lock_path, start_event, release_event, result_queue):
    start_event.wait()
    lock_fd = GUARD.acquire_refresh_lock(lock_path)
    acquired = isinstance(lock_fd, int) and not isinstance(lock_fd, bool)
    result_queue.put(acquired)
    if acquired:
        release_event.wait()
        os.close(lock_fd)


class TestProtocol(unittest.TestCase):
    def test_partial_line_obeys_deadline(self):
        context = multiprocessing.get_context("fork")
        read_fd, write_fd = os.pipe()
        os.write(write_fd, b'{"id":1')
        queue = context.Queue()
        process = context.Process(target=partial_line_worker, args=(read_fd, queue))
        process.start()
        process.join(0.5)
        hung = process.is_alive()
        if hung:
            process.terminate()
            process.join()
        os.close(write_fd)
        self.assertFalse(hung, "partial JSON blocked past its deadline")
        self.assertEqual(queue.get_nowait(), "TimeoutError")

    def test_eof_is_distinct_from_deadline(self):
        read_fd, write_fd = os.pipe()
        os.close(write_fd)
        stream = os.fdopen(read_fd, "rb")
        try:
            with self.assertRaises(GUARD.ProtocolEOFError):
                GUARD.read_response(
                    SimpleNamespace(stdout=stream), 1, time.monotonic() + 1)
        finally:
            stream.close()


class TestSnapshots(unittest.TestCase):
    def test_snake_case_session_event_is_classified(self):
        now = time.time()
        event = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
            "type": "event_msg",
            "payload": {"type": "token_count", "rate_limits": {
                "limit_id": "codex",
                "primary": {"used_percent": 72, "window_minutes": 300,
                            "resets_at": now + 3600},
                "secondary": {"used_percent": 10, "window_minutes": 10080,
                              "resets_at": now + 86400}}}}
        with tempfile.NamedTemporaryFile("w", delete=False) as fh:
            fh.write(json.dumps(event) + "\n")
            path = fh.name
        try:
            snapshot = GUARD.read_session_snapshot(path)
            line, code = GUARD.format_snapshot(snapshot, now=now)
        finally:
            os.unlink(path)
        self.assertEqual(code, 10)
        self.assertIn("session=72%", line)
        self.assertIn("week=10%", line)

    def test_camel_case_app_server_snapshot_is_classified(self):
        now = time.time()
        snapshot = {"ts": now, "rateLimits": {
            "primary": {"usedPercent": 20, "windowDurationMins": 300,
                        "resetsAt": now + 3600},
            "secondary": {"usedPercent": 76, "windowDurationMins": 10080,
                          "resetsAt": now + 86400}}}
        line, code = GUARD.format_snapshot(snapshot, now=now)
        self.assertEqual(code, 20)
        self.assertIn("session=20%", line)
        self.assertIn("week=76%", line)

    def test_session_snapshot_keeps_event_timestamp_for_freshness(self):
        observed = time.time() - 4000
        event = {"timestamp": time.strftime(
            "%Y-%m-%dT%H:%M:%SZ", time.gmtime(observed)),
            "type": "event_msg", "payload": {
                "type": "token_count", "rate_limits": {
                    "limit_id": "codex",
                    "primary": {"used_percent": 20, "window_minutes": 300}}}}
        with tempfile.NamedTemporaryFile("w", delete=False) as fh:
            fh.write(json.dumps(event) + "\n")
            path = fh.name
        try:
            snapshot = GUARD.read_session_snapshot(path)
        finally:
            os.unlink(path)
        self.assertAlmostEqual(snapshot["ts"], observed, delta=1)


class TestRefreshLock(unittest.TestCase):
    def test_concurrent_processes_acquire_lock_once(self):
        self.assertTrue(hasattr(GUARD, "acquire_refresh_lock"),
                        "adapter lacks an atomic refresh-lock API")
        with tempfile.TemporaryDirectory() as td:
            context = multiprocessing.get_context("fork")
            start = context.Event()
            release = context.Event()
            queue = context.Queue()
            processes = [context.Process(
                target=lock_worker,
                args=(os.path.join(td, "refresh.lock"), start, release, queue))
                for _ in range(8)]
            for process in processes:
                process.start()
            start.set()
            results = [queue.get(timeout=2) for _ in processes]
            release.set()
            for process in processes:
                process.join(2)
                self.assertFalse(process.is_alive())
            self.assertEqual(results.count(True), 1, results)


class TestFallbacks(unittest.TestCase):
    def sample(self, used=20):
        return {'ts': time.time(), 'rateLimits': {'primary': {
            'usedPercent': used, 'windowDurationMins': 300, 'resetsAt': time.time() + 3600}}}

    def test_invalid_new_session_does_not_mask_valid_cache(self):
        from unittest.mock import patch
        cache = self.sample()
        session = self.sample('bad')
        session['source'] = 'session-jsonl'
        with patch.object(GUARD, 'load_cache', return_value=cache), patch.object(
                GUARD, 'session_snapshot', return_value=session):
            tier, line, chosen = GUARD._local_status()
        self.assertEqual(tier, 'OK')
        self.assertIs(chosen, cache)
        self.assertIn('session=20%', line)

    def test_bad_timestamp_fails_soft(self):
        from unittest.mock import patch
        cache = self.sample()
        cache['ts'] = 'invalid'
        with patch.object(GUARD, 'load_cache', return_value=cache), patch.object(
                GUARD, 'session_snapshot', return_value=None):
            self.assertEqual(GUARD._local_status()[0], 'UNKNOWN')

    def test_payload_session_id_routes_to_log_discovery(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as td:
            path = os.path.join(td, 'sessions', '2026', '09', '06', 'rollout-child-id.jsonl')
            os.makedirs(os.path.dirname(path))
            with open(path, 'w') as fh:
                fh.write('')
            with patch.dict(os.environ, {'CODEX_HOME': td}, clear=True):
                self.assertEqual(GUARD.discover_session_log('child-id'), path)

    def test_broken_stdin_preserves_redacted_stderr(self):
        from unittest.mock import patch
        class DeadProcess:
            def terminate(self): pass
            def wait(self, timeout): return 1
        def launch(*args, **kwargs):
            kwargs['stderr'].write(b'fatal startup token=abcdefghijklmnopqrstuvwxyz012345')
            return DeadProcess()
        with patch.object(GUARD.subprocess, 'Popen', side_effect=launch), patch.object(
                GUARD, 'send', side_effect=BrokenPipeError('pipe closed')):
            with self.assertRaises(GUARD.UsageQueryError) as caught:
                GUARD.query_rate_limits()
        self.assertEqual(caught.exception.reason, 'eof')
        self.assertIn('fatal startup', caught.exception.diagnostic)
        self.assertNotIn('abcdefghijklmnopqrstuvwxyz012345', caught.exception.diagnostic)
        with patch.object(GUARD.subprocess, 'Popen', side_effect=launch), patch.object(
                GUARD, 'send', side_effect=TimeoutError('deadline')):
            with self.assertRaises(GUARD.UsageQueryError) as caught:
                GUARD.query_rate_limits()
        self.assertEqual(caught.exception.reason, 'timeout')


if __name__ == "__main__":
    unittest.main()
