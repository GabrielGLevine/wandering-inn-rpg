#!/usr/bin/env python3
"""Read fresh, provider-local Codex rate-limit telemetry without auth access."""

import datetime
import fcntl
import glob
import json
import math
import os
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time


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


class ProtocolEOFError(RuntimeError):
	pass


class UsageQueryError(RuntimeError):
	def __init__(self, reason, diagnostic=""):
		super().__init__(diagnostic or reason)
		self.reason = reason
		self.diagnostic = diagnostic


def state_dir():
	override = os.environ.get("CODEX_USAGE_GUARD_STATE_DIR")
	if override:
		return os.path.expanduser(override)
	cache_override = os.environ.get("CODEX_USAGE_GUARD_CACHE")
	if cache_override:
		return os.path.dirname(os.path.expanduser(cache_override)) or "."
	return os.path.join(tempfile.gettempdir(),
		"wandering-inn-rpg-usage-%s" % getattr(os, "getuid", lambda: 0)())


def cache_path():
	return os.path.expanduser(os.environ.get(
		"CODEX_USAGE_GUARD_CACHE", os.path.join(state_dir(), "codex-cache.json")))


def load_cache():
	try:
		with open(cache_path()) as fh:
			data = json.load(fh)
		return data if isinstance(data, dict) else None
	except Exception:
		return None


def save_cache(snapshot):
	path = cache_path()
	os.makedirs(os.path.dirname(path) or ".", mode=0o700, exist_ok=True)
	fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
	try:
		with os.fdopen(fd, "w") as fh:
			json.dump(snapshot, fh)
		os.replace(tmp, path)
	except Exception:
		try:
			os.unlink(tmp)
		except OSError:
			pass
		raise


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
			try:
				message = json.loads(line)
			except (TypeError, ValueError) as error:
				raise UsageQueryError("protocol", "invalid JSON response: %s" % error)
			if message.get("id") == request_id:
				if "error" in message:
					raise UsageQueryError("protocol", str(message["error"]))
				return message.get("result")
		remaining = max(0, deadline - time.monotonic())
		ready, _, _ = select.select([proc.stdout], [], [], remaining)
		if not ready:
			break
		chunk = os.read(proc.stdout.fileno(), 4096)
		if not chunk:
			raise ProtocolEOFError(
				"app-server closed stdout before response %s" % request_id)
		buffer += chunk
		proc._wi_read_buffer = buffer
	raise TimeoutError("Codex app-server response timed out")


def redact_diagnostic(value):
	text = re.sub(r"\s+", " ", str(value or "")).strip()
	text = text.replace(os.path.expanduser("~"), "~")
	text = re.sub(r"(?i)\b(bearer)\s+\S+", r"\1 [redacted]", text)
	text = re.sub(
		r"(?i)\b(token|api[_ -]?key|secret|authorization)\s*[:=]\s*\S+",
		r"\1=[redacted]", text)
	text = re.sub(r"\b[A-Za-z0-9_./+-]{32,}\b", "[redacted]", text)
	return text[:240]


def discover_codex_binary():
	for key in ("CODEX_USAGE_GUARD_CODEX", "CODEX_BINARY"):
		if os.environ.get(key):
			return os.path.expanduser(os.environ[key])
	home = os.path.expanduser("~")
	candidates = glob.glob(os.path.join(
		home, ".vscode", "extensions", "openai.chatgpt-*", "bin", "*", "codex"))
	candidates = [path for path in candidates if os.path.isfile(path) and os.access(path, os.X_OK)]
	if candidates:
		return max(candidates, key=lambda path: (os.path.getmtime(path), path))
	return shutil.which("codex") or "codex"


def _stderr_tail(stream):
	try:
		stream.flush()
		stream.seek(0, os.SEEK_END)
		size = stream.tell()
		stream.seek(max(0, size - 4096))
		return stream.read().decode("utf-8", "replace")
	except Exception:
		return ""


def query_rate_limits():
	proc = None
	stderr_log = tempfile.TemporaryFile()
	try:
		try:
			proc = subprocess.Popen(
				[discover_codex_binary(), "app-server", "--listen", "stdio://"],
				stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr_log,
				bufsize=0)
		except OSError as error:
			raise UsageQueryError("startup", redact_diagnostic(error))
		deadline = time.monotonic() + QUERY_TIMEOUT_SECS
		try:
			send(proc, {"method": "initialize", "id": 1, "params": {
				"clientInfo": {"name": "wi-usage-guard", "version": "1"}}})
			read_response(proc, 1, deadline)
			send(proc, {"method": "initialized"})
			send(proc, {"method": "account/rateLimits/read", "id": 2})
			result = read_response(proc, 2, deadline)
		except ProtocolEOFError as error:
			diagnostic = _stderr_tail(stderr_log) or str(error)
			raise UsageQueryError("eof", redact_diagnostic(diagnostic))
		except TimeoutError as error:
			diagnostic = _stderr_tail(stderr_log) or str(error)
			raise UsageQueryError("timeout", redact_diagnostic(diagnostic))
		except OSError as error:
			diagnostic = _stderr_tail(stderr_log) or str(error)
			raise UsageQueryError("eof", redact_diagnostic(diagnostic))
		if not isinstance(result, dict) or not isinstance(result.get("rateLimits"), dict):
			raise UsageQueryError("protocol", "Codex returned no rateLimits snapshot")
		snapshot = {"ts": time.time(), "source": "app-server",
			"rateLimits": result["rateLimits"]}
		try:
			format_snapshot(snapshot)
		except (TypeError, ValueError) as error:
			raise UsageQueryError("protocol", redact_diagnostic(error))
		try:
			save_cache(snapshot)
		except Exception:
			pass
		return snapshot
	finally:
		if proc is not None:
			proc.terminate()
			try:
				proc.wait(timeout=1)
			except subprocess.TimeoutExpired:
				proc.kill()
		stderr_log.close()


def _parse_timestamp(value):
	if isinstance(value, (int, float)):
		return float(value)
	if not isinstance(value, str):
		raise ValueError("snapshot has no timestamp")
	clean = value[:-1] + "+00:00" if value.endswith("Z") else value
	return datetime.datetime.fromisoformat(clean).timestamp()


def read_session_snapshot(path):
	with open(path, "rb") as fh:
		fh.seek(0, os.SEEK_END)
		size = fh.tell()
		fh.seek(max(0, size - 2 * 1024 * 1024))
		data = fh.read()
	if size > len(data):
		data = data.split(b"\n", 1)[-1]
	for raw in reversed(data.splitlines()):
		if b'"token_count"' not in raw or b'"rate_limits"' not in raw:
			continue
		try:
			event = json.loads(raw)
			payload = event.get("payload", {})
			limits = payload.get("rate_limits")
			if payload.get("type") != "token_count" or not isinstance(limits, dict):
				continue
			limit_id = limits.get("limit_id")
			if limit_id not in (None, "codex"):
				continue
			return {"ts": _parse_timestamp(event.get("timestamp")),
				"source": "session-jsonl", "rate_limits": limits}
		except (TypeError, ValueError):
			continue
	raise ValueError("no Codex token_count rate_limits event in session log")


def discover_session_log(session_id=None):
	override = os.environ.get("CODEX_USAGE_GUARD_SESSION_LOG")
	if override:
		return os.path.expanduser(override)
	identifiers = [session_id, os.environ.get("CODEX_THREAD_ID"), os.environ.get("CODEX_SESSION_ID")]
	identifiers = [value for value in identifiers if value]
	if not identifiers:
		return None
	root = os.path.join(os.path.expanduser(os.environ.get("CODEX_HOME", "~/.codex")), "sessions")
	paths = glob.glob(os.path.join(root, "*", "*", "*", "*.jsonl"))
	for identifier in identifiers:
		matches = [path for path in paths if identifier in os.path.basename(path)]
		if matches:
			return max(matches, key=os.path.getmtime)
	return None


def session_snapshot(session_id=None):
	path = discover_session_log(session_id)
	if not path:
		return None
	try:
		return read_session_snapshot(path)
	except Exception:
		return None


def _limits(snapshot):
	if not isinstance(snapshot, dict):
		raise ValueError("snapshot is not an object")
	limits = snapshot.get("rateLimits", snapshot.get("rate_limits"))
	if not isinstance(limits, dict):
		raise ValueError("snapshot has no rate-limit object")
	limit_id = limits.get("limitId", limits.get("limit_id"))
	if limit_id not in (None, "codex"):
		raise ValueError("snapshot belongs to another provider")
	return limits


def _field(value, camel, snake):
	return value.get(camel, value.get(snake))


def band_tier(percent, bands):
	tier = 0
	for index, threshold in enumerate(bands):
		if percent >= threshold:
			tier = index + 1
	return tier


def classify_windows(snapshot):
	limits = _limits(snapshot)
	primary = limits.get("primary")
	secondary = limits.get("secondary")
	windows = [value for value in (primary, secondary) if isinstance(value, dict)]
	weekly = next((value for value in windows
		if int(_field(value, "windowDurationMins", "window_minutes") or 0) >= 1440), None)
	session = next((value for value in windows if value is not weekly), None)
	if session is None and weekly is None and isinstance(primary, dict):
		session = primary
	if weekly is None and isinstance(secondary, dict) and secondary is not session:
		weekly = secondary
	return session, weekly


def window(value, now=None):
	if not isinstance(value, dict):
		return None, None
	now = time.time() if now is None else now
	reset = _field(value, "resetsAt", "resets_at")
	if reset is not None:
		reset = float(reset)
		if reset <= now:
			return None, None
	percent = _field(value, "usedPercent", "used_percent")
	if percent is None:
		return None, reset
	percent = float(percent)
	if not math.isfinite(percent) or percent < 0 or percent > 100:
		raise ValueError("invalid used percentage")
	return int(percent), reset


def format_snapshot(snapshot, stale_secs=0, now=None):
	now = time.time() if now is None else now
	session_window, week_window = classify_windows(snapshot)
	session_pct, session_reset = window(session_window, now)
	week_pct, week_reset = window(week_window, now)
	if session_pct is None and week_pct is None:
		raise ValueError("snapshot windows are missing or expired")
	tier = TIERS[max(band_tier(session_pct or 0, SESSION_BANDS),
		band_tier(week_pct or 0, WEEK_BANDS))]
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
	return os.path.join(state_dir(), "notify-%s" % safe)


def acquire_refresh_lock(lock):
	try:
		os.makedirs(os.path.dirname(lock) or ".", mode=0o700, exist_ok=True)
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
		"CODEX_USAGE_REFRESH_LOCK", os.path.join(state_dir(), "refresh.lock"))
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


def _newest_local_snapshot(session_id=None):
	snapshots = [value for value in (load_cache(), session_snapshot(session_id)) if isinstance(value, dict)]
	valid = []
	for snapshot in snapshots:
		try:
			_limits(snapshot)
			ts = float(snapshot.get("ts", 0))
			if not math.isfinite(ts) or ts > time.time() + 60:
				continue
			valid.append(snapshot)
		except (TypeError, ValueError):
			continue
	if not valid:
		return None
	valid.sort(key=lambda value: float(value.get("ts", 0)), reverse=True)
	for candidate in valid:
		try:
			if time.time() - float(candidate.get("ts", 0)) > STALE_LIMIT_SECS:
				continue
			format_snapshot(candidate)
			return candidate
		except (TypeError, ValueError):
			continue
	return valid[0]


def _unknown_line(reason, diagnostic=""):
	line = "UNKNOWN provider=codex reason=%s | telemetry unavailable" % reason
	clean = redact_diagnostic(diagnostic)
	if clean:
		line += "; diagnostic=" + clean
	return line[:360]


def _local_status(now=None, session_id=None):
	now = time.time() if now is None else now
	snapshot = _newest_local_snapshot(session_id)
	if snapshot is None:
		return "UNKNOWN", _unknown_line("missing"), None
	try:
		age = max(0, now - float(snapshot.get("ts", 0)))
	except (TypeError, ValueError):
		return "UNKNOWN", _unknown_line("invalid"), None
	if age > STALE_LIMIT_SECS:
		return "UNKNOWN", _unknown_line("stale", "snapshot age %dm" % (age / 60)), snapshot
	try:
		line, _ = format_snapshot(snapshot, age, now)
	except (TypeError, ValueError) as error:
		return "UNKNOWN", _unknown_line("invalid", error), snapshot
	return line.split()[0], line, snapshot


def cmd_hook():
	try:
		raw = sys.stdin.read()
		payload = json.loads(raw) if raw.strip() else {}
		session_id = payload.get("session_id") or os.environ.get("CODEX_THREAD_ID") or "global"
		tier, line, snapshot = _local_status(session_id=session_id)
		if snapshot and snapshot.get("source") == "session-jsonl":
			try:
				save_cache(snapshot)
			except Exception:
				pass
		path = stamp_path(session_id)
		previous = None
		try:
			with open(path) as fh:
				previous = fh.read().strip()
		except Exception:
			pass
		if tier == previous:
			return 0
		os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
		with open(path, "w") as fh:
			fh.write(tier)
		if previous is None and tier in ("OK", "UNKNOWN"):
			return 0
		if tier in TIERS and previous in TIERS:
			direction = "escalated" if TIERS.index(tier) > TIERS.index(previous) else "de-escalated"
		elif previous is None:
			direction = "escalated"
		else:
			direction = "changed"
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

	now = time.time()
	tier, line, snapshot = _local_status(now)
	age = now - float(snapshot.get("ts", 0)) if snapshot else None
	needs_refresh = "--fresh" in argv or snapshot is None or age > CACHE_TTL_SECS or tier == "UNKNOWN"
	query_error = None
	if needs_refresh and not (tier != "UNKNOWN" and snapshot and age <= CACHE_TTL_SECS and snapshot.get("source") == "session-jsonl"):
		try:
			snapshot = query_rate_limits()
			line, code = format_snapshot(snapshot, now=now)
			tier = line.split()[0]
		except UsageQueryError as error:
			query_error = error
		except Exception as error:
			query_error = UsageQueryError("protocol", redact_diagnostic(error))

	if tier != "UNKNOWN":
		print(line)
		return EXIT_CODES[tier]
	if snapshot is not None and age is not None and age > STALE_LIMIT_SECS:
		print(_unknown_line("stale", "snapshot age %dm" % (age / 60)))
	elif query_error is not None:
		print(_unknown_line(query_error.reason, query_error.diagnostic))
	else:
		print(line)
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
