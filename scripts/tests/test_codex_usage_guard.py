"""Unit tests for the Codex app-server usage adapter."""

import importlib.util
import multiprocessing
import os
import tempfile
import time
import unittest
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


if __name__ == "__main__":
    unittest.main()
