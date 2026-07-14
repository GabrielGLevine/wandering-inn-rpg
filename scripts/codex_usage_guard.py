#!/usr/bin/env python3
"""Read Codex account rate limits through the local app-server protocol."""

import json
import os
import select
import subprocess
import sys
import tempfile
import time
import re
import fcntl


CACHE_TTL_SECS = 300
STALE_LIMIT_SECS = 3600
QUERY_TIMEOUT_SECS = 8
SESSION_BANDS = (70, 85, 95)
WEEK_BANDS = (60, 75, 90)
TIERS = ("OK", "CAUTION", "WINDDOWN", "QUIESCE")
EXIT_CODES = {"OK": 0, "CAUTION": 10, "WINDDOWN": 20, "QUIESCE": 30}
HINTS = {
	"OK": "normal operations",
	"CAUTION": "no new lanes/workflows; finish in-flight; prefer cheap ops",
	"WINDDOWN": "drain lanes, commit WIP seams, update HANDOFF",
	"QUIESCE": "state-saving actions only, then wait for reset or stop",
}


def cache_path():
	return os.environ.get(
		"CODEX_USAGE_GUARD_CACHE",
		os.path.expanduser("~/.codex/usage-guard-cache.json"))


def load_cache():
	try:
		with open(cache_path()) as fh:
			data = json.load(fh)
		return data if isinstance(data, dict) else None
	except Exception:
		return None


def save_cache(snapshot):
	path = cache_path()
	os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
	fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
	with os.fdopen(fd, "w") as fh:
		json.dump(snapshot, fh)
	os.replace(tmp, path)


def send(proc, message):
	proc.stdin.write((json.dumps(message) + "\n").encode())
	proc.stdin.flush()


def read_response(proc, request_id, deadline):
	buffer = getattr(proc, "_wi_read_buffer", b"")
	while time.monotonic() < deadline:
		while b"\n" in buffer:
			line, buffer = buffer.split(b"\n", 1)
			proc._wi_read_buffer = buffer
			if not line:
				continue
			message = json.loads(line)
			if message.get("id") == request_id:
				if "error" in message:
					raise RuntimeError(message["error"])
				return message.get("result")
		remaining = max(0, deadline - time.monotonic())
		ready, _, _ = select.select([proc.stdout], [], [], remaining)
		if not ready:
			break
		chunk = os.read(proc.stdout.fileno(), 4096)
		if not chunk:
			break
		buffer += chunk
		proc._wi_read_buffer = buffer
	raise TimeoutError("Codex app-server response timed out")


def query_rate_limits():
	proc = subprocess.Popen(
		["codex", "app-server", "--listen", "stdio://"],
		stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
		bufsize=0)
	try:
		deadline = time.monotonic() + QUERY_TIMEOUT_SECS
		send(proc, {"method": "initialize", "id": 1, "params": {
			"clientInfo": {"name": "wi-usage-guard", "version": "1"}}})
		read_response(proc, 1, deadline)
		send(proc, {"method": "initialized"})
		send(proc, {"method": "account/rateLimits/read", "id": 2})
		result = read_response(proc, 2, deadline)
		if not isinstance(result, dict) or not isinstance(result.get("rateLimits"), dict):
			raise ValueError("Codex returned no rateLimits snapshot")
		snapshot = {"ts": time.time(), "rateLimits": result["rateLimits"]}
		try:
			save_cache(snapshot)
		except Exception:
			pass
		return snapshot
	finally:
		proc.terminate()
		try:
			proc.wait(timeout=1)
		except subprocess.TimeoutExpired:
			proc.kill()


def band_tier(percent, bands):
	tier = 0
	for index, threshold in enumerate(bands):
		if percent >= threshold:
			tier = index + 1
	return tier


def classify_windows(snapshot):
	primary = snapshot["rateLimits"].get("primary")
	secondary = snapshot["rateLimits"].get("secondary")
	windows = [value for value in (primary, secondary) if isinstance(value, dict)]
	weekly = next((value for value in windows
		if int(value.get("windowDurationMins") or 0) >= 1440), None)
	session = next((value for value in windows if value is not weekly), None)
	if session is None and weekly is None and isinstance(primary, dict):
		session = primary
	if weekly is None and isinstance(secondary, dict) and secondary is not session:
		weekly = secondary
	return session, weekly


def window(value):
	if not isinstance(value, dict):
		return None, None
	reset = value.get("resetsAt")
	if reset is not None and float(reset) <= time.time():
		return 0, None
	return int(value.get("usedPercent", 0)), reset


def format_snapshot(snapshot, stale_secs=0):
	session_window, week_window = classify_windows(snapshot)
	session_pct, session_reset = window(session_window)
	week_pct, week_reset = window(week_window)
	tier = TIERS[max(band_tier(session_pct or 0, SESSION_BANDS),
		band_tier(week_pct or 0, WEEK_BANDS))]
	now = time.time()
	parts = [tier, "provider=codex",
		"session=%d%%" % session_pct if session_pct is not None else "session=N/A"]
	if session_reset:
		parts.append("reset~%dm" % max(0, (session_reset - now) / 60))
	parts.append("week=%d%%" % week_pct if week_pct is not None else "week=N/A")
	if week_reset:
		parts.append("week_reset~%dm" % max(0, (week_reset - now) / 60))
	if stale_secs > CACHE_TTL_SECS:
		parts.append("(stale %dm)" % (stale_secs / 60))
	return " ".join(parts) + " | " + HINTS[tier], EXIT_CODES[tier]


def stamp_path(session_id):
	safe = re.sub(r"[^A-Za-z0-9_-]", "_", session_id)[:64] or "global"
	return os.path.expanduser("~/.codex/usage-guard-notify-%s" % safe)


def acquire_refresh_lock(lock):
	try:
		os.makedirs(os.path.dirname(lock) or ".", exist_ok=True)
		fd = os.open(lock, os.O_WRONLY | os.O_CREAT, 0o600)
		try:
			fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
		except OSError:
			os.close(fd)
			return None
		os.ftruncate(fd, 0)
		os.write(fd, str(os.getpid()).encode())
		return fd
	except Exception:
		return None


def refresh_background():
	lock = os.environ.get(
		"CODEX_USAGE_REFRESH_LOCK",
		os.path.expanduser("~/.codex/usage-guard-refresh.lock"))
	try:
		lock_fd = acquire_refresh_lock(lock)
		if lock_fd is None:
			return
		try:
			subprocess.Popen(
				[sys.executable, os.path.abspath(__file__), "refresh"],
				stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
				start_new_session=True, pass_fds=(lock_fd,))
		finally:
			os.close(lock_fd)
	except Exception:
		pass


def cmd_hook():
	try:
		raw = sys.stdin.read()
		payload = json.loads(raw) if raw.strip() else {}
		session_id = payload.get("session_id") or "global"
		snapshot = load_cache()
		age = time.time() - snapshot.get("ts", 0) if snapshot else None
		if snapshot is None or age > CACHE_TTL_SECS:
			refresh_background()
		if snapshot is None or age is None or age > STALE_LIMIT_SECS:
			return 0
		line, _ = format_snapshot(snapshot, age)
		tier = line.split()[0]
		path = stamp_path(session_id)
		previous = None
		try:
			with open(path) as fh:
				previous = fh.read().strip()
		except Exception:
			pass
		if tier == previous or (previous is None and tier == "OK"):
			if previous is None:
				os.makedirs(os.path.dirname(path), exist_ok=True)
				with open(path, "w") as fh:
					fh.write(tier)
			return 0
		os.makedirs(os.path.dirname(path), exist_ok=True)
		with open(path, "w") as fh:
			fh.write(tier)
		direction = "escalated" if TIERS.index(tier) > (
			TIERS.index(previous) if previous in TIERS else 0) else "de-escalated"
		print(json.dumps({"systemMessage":
			"USAGE-GUARD %s to %s: %s — follow wi-usage-guard for this tier."
			% (direction, tier, line)}))
		return 0
	except Exception:
		return 0


def main(argv):
	if argv and argv[0] == "hook":
		return cmd_hook()
	if argv and argv[0] == "refresh":
		try:
			query_rate_limits()
			return 0
		except Exception:
			return 1
	try:
		snapshot = load_cache()
		age = time.time() - float(snapshot.get("ts", 0)) if snapshot else None
		if "--fresh" in argv or snapshot is None or age > CACHE_TTL_SECS:
			try:
				snapshot = query_rate_limits()
				age = 0
			except Exception:
				pass
		if snapshot is None or age is None or age > STALE_LIMIT_SECS:
			raise ValueError("no trustworthy Codex usage snapshot")
		line, code = format_snapshot(snapshot, age)
	except Exception:
		print("N/A provider=codex | Codex rate-limit query unavailable; keep shared lane/integration discipline")
		return 0
	print(line)
	return code


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
