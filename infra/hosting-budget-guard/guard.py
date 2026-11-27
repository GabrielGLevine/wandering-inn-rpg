"""Budget kill-switch for ONE Firebase Hosting site (stdlib only).

A Cloud Billing budget publishes its status to Pub/Sub several times a day.
`handle_event` reads one such notification and, when the budget's actual
spend has reached its amount, takes the configured Hosting site offline by
creating a `SITE_DISABLE` release -- the call `firebase hosting:disable
--site` makes. It never touches billing, other sites, or other services.

Contract with the caller (main.py): `handle_event` returns a decision dict
for every message it wants ACKED, and raises `TransientError` only when a
retry can plausibly help (Hosting API 429/5xx, network failure). Nothing
else escapes, so a bad message can never loop through Pub/Sub redelivery.

API shapes are documented in README.md ("Verified API shapes").
"""

from __future__ import annotations

import base64
import binascii
import json
import math
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Mapping

# --------------------------------------------------------------- hard rails
# The ONLY targets this code may ever act on. Widening either set is a code
# change that must go through review; no environment variable can do it.
ALLOWED_SITES = frozenset({"wandering-inn-rpg"})
ALLOWED_PROJECTS = frozenset({"gpt-development"})

MARKER_PREFIX = "wi-hosting-budget-guard"
HOSTING_API = "https://firebasehosting.googleapis.com/v1beta1"
METADATA_TOKEN_URL = (
    "http://metadata.google.internal/computeMetadata/v1/"
    "instance/service-accounts/default/token"
)
RELEASE_PAGE_SIZE = 100
MAX_RELEASE_PAGES = 5
HTTP_TIMEOUT_SECONDS = 20
MAX_MESSAGE_LENGTH = 512  # Release.message limit in the Hosting REST reference
SUPPORTED_SCHEMA_VERSION = "1.0"


class ConfigError(Exception):
    """The deployment is misconfigured; refuse to start."""


class TransientError(Exception):
    """A retry may succeed; the caller should NACK the message."""


class PermanentApiError(Exception):
    """The Hosting API refused the call; retrying will not help."""


# ------------------------------------------------------------------- config
_TRUE = {"1", "true", "yes", "on"}
_FALSE = {"0", "false", "no", "off"}


def _flag(env: Mapping[str, str], name: str, default: bool | None) -> bool:
    raw = env.get(name)
    if raw is None or raw.strip() == "":
        if default is None:
            raise ConfigError(f"{name} must be set explicitly (1 or 0)")
        return default
    value = raw.strip().lower()
    if value in _TRUE:
        return True
    if value in _FALSE:
        return False
    raise ConfigError(f"{name}={raw!r} is not a boolean (use 1 or 0)")


def _required(env: Mapping[str, str], name: str) -> str:
    value = (env.get(name) or "").strip()
    if not value:
        raise ConfigError(f"{name} is required")
    return value


@dataclass(frozen=True)
class Config:
    project_id: str
    site_id: str
    budget_display_name: str
    billing_account_id: str
    dry_run: bool
    budget_id: str = ""
    redisable_while_over_budget: bool = False
    marker_generation: str = "1"
    guard_service_account: str = ""
    max_event_age_seconds: int = 3600

    def __post_init__(self) -> None:
        if self.site_id not in ALLOWED_SITES:
            raise ConfigError(
                f"site {self.site_id!r} is not in the allowlist {sorted(ALLOWED_SITES)}"
            )
        if self.project_id not in ALLOWED_PROJECTS:
            raise ConfigError(
                f"project {self.project_id!r} is not in the allowlist {sorted(ALLOWED_PROJECTS)}"
            )
        if not self.budget_display_name or not self.billing_account_id:
            raise ConfigError("budget display name and billing account id are required")
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,32}", self.marker_generation):
            raise ConfigError("GUARD_MARKER_GENERATION must match [A-Za-z0-9_.-]{1,32}")
        if self.max_event_age_seconds <= 0:
            raise ConfigError("MAX_EVENT_AGE_SECONDS must be positive")

    @classmethod
    def from_env(cls, env: Mapping[str, str]) -> "Config":
        try:
            max_age = int((env.get("MAX_EVENT_AGE_SECONDS") or "3600").strip())
        except ValueError as exc:
            raise ConfigError("MAX_EVENT_AGE_SECONDS must be an integer") from exc
        return cls(
            project_id=_required(env, "GUARD_PROJECT_ID"),
            site_id=_required(env, "GUARD_SITE_ID"),
            budget_display_name=_required(env, "GUARD_BUDGET_DISPLAY_NAME"),
            billing_account_id=_required(env, "GUARD_BILLING_ACCOUNT_ID"),
            # No default: a kill-switch that silently guesses whether it is
            # armed is worse than one that refuses to start.
            dry_run=_flag(env, "DRY_RUN", None),
            budget_id=(env.get("GUARD_BUDGET_ID") or "").strip(),
            redisable_while_over_budget=_flag(env, "REDISABLE_WHILE_OVER_BUDGET", False),
            marker_generation=(env.get("GUARD_MARKER_GENERATION") or "1").strip(),
            guard_service_account=(env.get("GUARD_SERVICE_ACCOUNT") or "").strip(),
            max_event_age_seconds=max_age,
        )

    @property
    def site_parent(self) -> str:
        # Project-qualified on purpose: the request can only resolve to the
        # site inside the allowlisted project (the form the Firebase CLI uses).
        return f"projects/{self.project_id}/sites/{self.site_id}"


# -------------------------------------------------------------- Hosting API
def metadata_access_token() -> str:
    """Access token of the function's runtime service account."""
    request = urllib.request.Request(METADATA_TOKEN_URL, headers={"Metadata-Flavor": "Google"})
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
            return json.loads(response.read().decode("utf-8"))["access_token"]
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError) as exc:
        raise TransientError(f"metadata token fetch failed: {exc}") from exc


class HostingApi:
    """The two Hosting calls the guard needs: list releases, disable site."""

    def __init__(
        self,
        config: Config,
        token_provider: Callable[[], str] = metadata_access_token,
        opener: Callable[..., Any] = urllib.request.urlopen,
    ) -> None:
        self._config = config
        self._token_provider = token_provider
        self._opener = opener

    def _call(self, method: str, url: str, body: dict | None = None) -> dict:
        data = json.dumps(body).encode("utf-8") if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self._token_provider()}")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with self._opener(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
                payload = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:300] if exc.fp else ""
            if exc.code == 429 or exc.code >= 500:
                raise TransientError(f"Hosting API HTTP {exc.code}: {detail}") from exc
            raise PermanentApiError(f"Hosting API HTTP {exc.code}: {detail}") from exc
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise TransientError(f"Hosting API unreachable: {exc}") from exc
        try:
            parsed = json.loads(payload) if payload.strip() else {}
        except ValueError as exc:
            raise TransientError("Hosting API returned non-JSON") from exc
        if not isinstance(parsed, dict):
            raise TransientError("Hosting API returned a non-object")
        return parsed

    def list_releases(self) -> tuple[list[dict], bool]:
        """Recent releases of the site, and whether the listing was cut short."""
        releases: list[dict] = []
        token = ""
        for _ in range(MAX_RELEASE_PAGES):
            query = {"pageSize": str(RELEASE_PAGE_SIZE)}
            if token:
                query["pageToken"] = token
            url = f"{HOSTING_API}/{self._config.site_parent}/releases?" + urllib.parse.urlencode(query)
            page = self._call("GET", url)
            for release in page.get("releases") or []:
                if isinstance(release, dict):
                    releases.append(release)
            token = page.get("nextPageToken") or ""
            if not token:
                return releases, False
        return releases, True

    def disable_site(self, message: str) -> dict:
        # No versionName: the reference requires it to be empty for SITE_DISABLE.
        url = f"{HOSTING_API}/{self._config.site_parent}/releases"
        return self._call("POST", url, {"type": "SITE_DISABLE", "message": message})


# ------------------------------------------------------------------ parsing
class _Malformed(Exception):
    pass


def _parse_time(value: Any) -> datetime:
    """RFC 3339 -> aware UTC datetime (tolerates nanosecond fractions)."""
    if not isinstance(value, str):
        raise _Malformed("timestamp is not a string")
    match = re.fullmatch(
        r"(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?([Zz]|[+-]\d{2}:\d{2})",
        value.strip(),
    )
    if not match:
        raise _Malformed(f"unparseable timestamp {value!r}")
    year, month, day, hour, minute, second = (int(part) for part in match.groups()[:6])
    zone = match.group(7)
    offset = timedelta(0)
    if zone not in ("Z", "z"):
        sign = 1 if zone[0] == "+" else -1
        offset = sign * timedelta(hours=int(zone[1:3]), minutes=int(zone[4:6]))
    try:
        local = datetime(year, month, day, hour, minute, second, tzinfo=timezone.utc)
    except ValueError as exc:
        raise _Malformed(f"invalid timestamp {value!r}") from exc
    return local - offset


def _canonical(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _add_month(moment: datetime) -> datetime:
    year, month = (moment.year + 1, 1) if moment.month == 12 else (moment.year, moment.month + 1)
    for day in (moment.day, 30, 29, 28):
        try:
            return moment.replace(year=year, month=month, day=day)
        except ValueError:
            continue
    raise _Malformed("cannot compute period end")


def _number(payload: Mapping[str, Any], key: str) -> float:
    value = payload.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise _Malformed(f"{key} is missing or not a finite number")
    return float(value)


def _decode_envelope(event_data: Any) -> tuple[dict, dict, str]:
    """Pub/Sub CloudEvent data -> (budget payload, attributes, publishTime)."""
    if not isinstance(event_data, Mapping):
        raise _Malformed("event data is not an object")
    message = event_data.get("message")
    if not isinstance(message, Mapping):
        raise _Malformed("event has no Pub/Sub message")
    raw = message.get("data")
    if not isinstance(raw, str) or not raw:
        raise _Malformed("Pub/Sub message has no data")
    try:
        decoded = base64.b64decode(raw, validate=True).decode("utf-8")
    except (binascii.Error, UnicodeDecodeError, ValueError) as exc:
        raise _Malformed("message data is not base64-encoded UTF-8") from exc
    try:
        payload = json.loads(decoded)
    except ValueError as exc:
        raise _Malformed("message data is not JSON") from exc
    if not isinstance(payload, dict):
        raise _Malformed("message JSON is not an object")
    attributes = message.get("attributes")
    if not isinstance(attributes, Mapping):
        attributes = {}
    return payload, dict(attributes), message.get("publishTime") or ""


def period_marker(config: Config, period: str) -> str:
    return f"[{MARKER_PREFIX} period={period} gen={config.marker_generation}]"


def _is_live(release: Mapping[str, Any]) -> bool:
    # sites.releases.list also returns preview-channel releases; only the
    # live channel decides whether the public site is serving.
    name = str(release.get("name") or "")
    return "/channels/" not in name or "/channels/live/" in name


def _release_time(release: Mapping[str, Any]) -> datetime | None:
    try:
        return _parse_time(release.get("releaseTime"))
    except _Malformed:
        return None


def _acted_this_period(
    config: Config, releases: list[dict], period_start: datetime, marker: str
) -> bool:
    for release in releases:
        if release.get("type") != "SITE_DISABLE":
            continue
        message = str(release.get("message") or "")
        if marker in message:
            return True
        # Fallback for the one thing the reference does not promise: that
        # `message` is stored on a SITE_DISABLE release. A message-less
        # disable made by the guard's own service account in this period
        # counts as the guard's.
        email = str((release.get("releaseUser") or {}).get("email") or "")
        released = _release_time(release)
        if (
            not message
            and config.guard_service_account
            and email == config.guard_service_account
            and released is not None
            and released >= period_start
        ):
            return True
    return False


# ----------------------------------------------------------------- decision
def handle_event(
    event_data: Any,
    config: Config,
    api: HostingApi | None,
    now: datetime | None = None,
) -> dict:
    """Decide and (maybe) act on one budget notification.

    Returns the decision record (always ACK). Raises TransientError only.
    """
    now = now or datetime.now(timezone.utc)
    record: dict[str, Any] = {
        "component": MARKER_PREFIX,
        "site": config.site_id,
        "project": config.project_id,
        "dry_run": config.dry_run,
        "severity": "INFO",
    }

    def done(decision: str, reason: str = "", severity: str = "INFO") -> dict:
        record["decision"] = decision
        record["severity"] = severity
        if reason:
            record["reason"] = reason
        record["message"] = f"{MARKER_PREFIX}: {decision}" + (f" ({reason})" if reason else "")
        return record

    try:
        payload, attributes, publish_time = _decode_envelope(event_data)
    except _Malformed as exc:
        return done("ignored_malformed", str(exc), "WARNING")

    # End condition for retries (Cloud Run "function retries" best practice):
    # an old delivery is dropped; a fresh notification arrives within hours.
    if publish_time:
        try:
            age = (now - _parse_time(publish_time)).total_seconds()
        except _Malformed as exc:
            return done("ignored_malformed", f"publishTime: {exc}", "WARNING")
        record["event_age_seconds"] = round(age)
        if age > config.max_event_age_seconds:
            return done("ignored_stale_event", f"older than {config.max_event_age_seconds}s")

    name = payload.get("budgetDisplayName")
    record["budget_display_name"] = name if isinstance(name, str) else None
    record["budget_id"] = attributes.get("budgetId")
    if name != config.budget_display_name:
        return done("ignored_wrong_budget", "budgetDisplayName does not match")
    if attributes.get("billingAccountId") != config.billing_account_id:
        return done("ignored_wrong_budget", "billingAccountId attribute does not match")
    if config.budget_id and attributes.get("budgetId") != config.budget_id:
        return done("ignored_wrong_budget", "budgetId attribute does not match")
    if attributes.get("schemaVersion") != SUPPORTED_SCHEMA_VERSION:
        return done("ignored_malformed", "unsupported schemaVersion", "WARNING")

    try:
        cost = _number(payload, "costAmount")
        budget = _number(payload, "budgetAmount")
        if budget <= 0 or cost < 0:
            raise _Malformed("budgetAmount must be > 0 and costAmount >= 0")
        if payload.get("budgetAmountType") != "SPECIFIED_AMOUNT":
            raise _Malformed("budgetAmountType is not SPECIFIED_AMOUNT")
        period_start = _parse_time(payload.get("costIntervalStart"))
        period_end = _add_month(period_start)
    except _Malformed as exc:
        return done("ignored_malformed", str(exc), "WARNING")

    period = _canonical(period_start)
    record.update(
        cost_amount=cost,
        budget_amount=budget,
        currency=payload.get("currencyCode"),
        period=period,
        alert_threshold_exceeded=payload.get("alertThresholdExceeded"),
        forecast_threshold_exceeded=payload.get("forecastThresholdExceeded"),
    )

    # A budget keeps reporting the previous month for ~2 days into the next
    # one, and Pub/Sub may deliver out of order: only the current period can
    # take the site down.
    if not period_start <= now < period_end:
        return done("ignored_stale_period", "costIntervalStart is not the current month")

    # Only ACTUAL spend decides. A forecast is a guess; it never disables.
    if cost < budget:
        if "forecastThresholdExceeded" in payload and "alertThresholdExceeded" not in payload:
            return done("ignored_forecast_only", "forecast thresholds never trigger the guard")
        return done("noop_under_budget")

    marker = period_marker(config, period)
    release_message = (
        f"{marker} Hosting spend {cost:.2f} >= budget {budget:.2f} "
        f"{payload.get('currencyCode') or ''}. Site disabled by the budget guard; "
        "redeploy to live to re-enable."
    )[:MAX_MESSAGE_LENGTH]
    record["marker"] = marker

    if config.dry_run:
        record["would_post"] = {
            "parent": config.site_parent,
            "body": {"type": "SITE_DISABLE", "message": release_message},
        }
        return done("dry_run_would_disable", "DRY_RUN is set; no API call made", "NOTICE")

    if api is None:
        return done("error_no_api", "armed but no Hosting API client", "ERROR")

    try:
        releases, truncated = api.list_releases()
        record["releases_seen"] = len(releases)
        record["release_list_truncated"] = truncated

        live = [r for r in releases if _is_live(r)]
        latest = max(
            live,
            key=lambda r: _release_time(r) or datetime.min.replace(tzinfo=timezone.utc),
            default=None,
        )
        if latest is not None and latest.get("type") == "SITE_DISABLE":
            record["latest_release"] = latest.get("name")
            return done("noop_already_disabled", "latest live release is SITE_DISABLE")

        if not config.redisable_while_over_budget and _acted_this_period(
            config, releases, period_start, marker
        ):
            return done(
                "noop_already_acted_this_period",
                "site was re-enabled after this period's disable; not disabling again",
                "WARNING",
            )

        created = api.disable_site(release_message)
    except PermanentApiError as exc:
        # ACK: retrying a 4xx cannot help, and the next notification is hours
        # away at most. ERROR severity so it is visible and alertable.
        return done("error_api_refused", str(exc), "ERROR")

    record["release"] = created.get("name")
    record["marker_persisted"] = marker in str(created.get("message") or "")
    return done("disabled", "SITE_DISABLE release created", "WARNING")
