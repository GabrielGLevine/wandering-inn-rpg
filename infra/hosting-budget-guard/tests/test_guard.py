"""Unit tests for the Hosting budget kill-switch (no network, no cloud).

The Hosting API is always a fake. Collected by CI through the shim
scripts/tests/test_hosting_budget_guard.py (CI runs `pytest -q scripts/`).
"""

from __future__ import annotations

import base64
import importlib.util
import io
import json
import sys
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

import pytest

GUARD_DIR = Path(__file__).resolve().parents[1]


def _load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, GUARD_DIR / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


guard = sys.modules.get("guard") or _load("guard", "guard.py")

BILLING = "000000-AAAAAA-BBBBBB"  # placeholder shape, not a real account
BUDGET_NAME = "wi-hosting-kill-switch"
BUDGET_ID = "de72f49d-779b-4945-a127-4d6ce8def0bb"  # the example id in Google's docs
NOW = datetime(2026, 11, 27, 12, 0, 0, tzinfo=timezone.utc)
PERIOD = "2026-11-01T07:00:00Z"
MARKER = f"[wi-hosting-budget-guard period={PERIOD} gen=1]"
SA = "wi-hosting-budget-guard@gpt-development.iam.gserviceaccount.com"


def make_config(**overrides):
    values = dict(
        project_id="gpt-development",
        site_id="wandering-inn-rpg",
        budget_display_name=BUDGET_NAME,
        billing_account_id=BILLING,
        dry_run=False,
        budget_id=BUDGET_ID,
        guard_service_account=SA,
    )
    values.update(overrides)
    return guard.Config(**values)


def payload(**overrides):
    body = {
        "budgetDisplayName": BUDGET_NAME,
        "costAmount": 10.42,
        "costIntervalStart": PERIOD,
        "budgetAmount": 10.0,
        "budgetAmountType": "SPECIFIED_AMOUNT",
        "alertThresholdExceeded": 1.0,
        "currencyCode": "USD",
    }
    body.update(overrides)
    return {k: v for k, v in body.items() if v is not None}


def event(body=None, attributes=None, publish_time="2026-11-27T11:59:30.123456789Z", raw=None):
    if raw is None:
        raw = base64.b64encode(json.dumps(payload() if body is None else body).encode()).decode()
    if attributes is None:
        attributes = {"billingAccountId": BILLING, "budgetId": BUDGET_ID, "schemaVersion": "1.0"}
    return {
        "message": {"data": raw, "attributes": attributes, "publishTime": publish_time},
        "subscription": "projects/gpt-development/subscriptions/eventarc-test",
    }


def deploy_release(n=1, when="2026-11-20T10:00:00Z"):
    return {
        "name": f"sites/wandering-inn-rpg/channels/live/releases/{n}",
        "type": "DEPLOY",
        "releaseTime": when,
        "message": "v0.21.0",
    }


def disable_release(message, when="2026-11-25T10:00:00Z", email=SA):
    return {
        "name": "sites/wandering-inn-rpg/releases/999",
        "type": "SITE_DISABLE",
        "releaseTime": when,
        "message": message,
        "releaseUser": {"email": email},
    }


class FakeApi:
    def __init__(self, releases=None, truncated=False, list_error=None, create_error=None):
        self.releases = list(releases or [])
        self.truncated = truncated
        self.list_error = list_error
        self.create_error = create_error
        self.list_calls = 0
        self.disable_calls: list[str] = []

    def list_releases(self):
        self.list_calls += 1
        if self.list_error:
            raise self.list_error
        return list(self.releases), self.truncated

    def disable_site(self, message):
        if self.create_error:
            raise self.create_error
        self.disable_calls.append(message)
        created = disable_release(message, when="2026-11-27T12:00:00Z")
        self.releases.append(created)
        return created


def run(api, body=None, config=None, now=NOW, **event_kwargs):
    return guard.handle_event(event(body, **event_kwargs), config or make_config(), api, now=now)


# ------------------------------------------------------------ core decisions
def test_under_budget_is_a_noop_with_no_api_call():
    api = FakeApi([deploy_release()])
    record = run(api, payload(costAmount=4.99, alertThresholdExceeded=None))
    assert record["decision"] == "noop_under_budget"
    assert api.list_calls == 0 and api.disable_calls == []


def test_threshold_alerts_below_100_percent_do_not_disable():
    api = FakeApi([deploy_release()])
    record = run(api, payload(costAmount=8.5, alertThresholdExceeded=0.8))
    assert record["decision"] == "noop_under_budget"
    assert api.disable_calls == []


@pytest.mark.parametrize("cost", [10.0, 10.42, 250.0])
def test_at_or_over_budget_disables_once_with_the_period_marker(cost):
    api = FakeApi([deploy_release()])
    record = run(api, payload(costAmount=cost))
    assert record["decision"] == "disabled"
    assert len(api.disable_calls) == 1
    assert MARKER in api.disable_calls[0]
    assert len(api.disable_calls[0]) <= 512
    assert record["marker_persisted"] is True


def test_repeat_notification_same_period_is_a_noop_while_still_disabled():
    api = FakeApi([deploy_release()])
    run(api)
    record = run(api)
    assert record["decision"] == "noop_already_disabled"
    assert len(api.disable_calls) == 1


def test_owner_reenable_mid_period_is_respected():
    # disabled by the guard on the 25th, owner redeployed on the 26th
    api = FakeApi(
        [
            deploy_release(1),
            disable_release(f"{MARKER} over budget"),
            deploy_release(2, when="2026-11-26T09:00:00Z"),
        ]
    )
    for _ in range(3):
        record = run(api)
        assert record["decision"] == "noop_already_acted_this_period"
    assert api.disable_calls == []


def test_new_period_acts_again():
    december = "2026-12-01T08:00:00Z"
    api = FakeApi(
        [disable_release(f"{MARKER} over budget"), deploy_release(2, when="2026-11-26T09:00:00Z")]
    )
    record = run(
        api,
        payload(costIntervalStart=december),
        now=datetime(2026, 12, 9, 12, 0, tzinfo=timezone.utc),
        publish_time="2026-12-09T11:59:00Z",
    )
    assert record["decision"] == "disabled"
    assert "period=2026-12-01T08:00:00Z" in api.disable_calls[0]


def test_period_marker_is_normalised_across_timestamp_spellings():
    api = FakeApi(
        [disable_release(f"{MARKER} over budget"), deploy_release(2, when="2026-11-26T09:00:00Z")]
    )
    record = run(api, payload(costIntervalStart="2026-11-01T00:00:00-07:00"))
    assert record["decision"] == "noop_already_acted_this_period"


def test_manual_disable_without_marker_does_not_consume_the_period():
    # owner ran `firebase hosting:disable` earlier this month, then redeployed
    api = FakeApi(
        [
            disable_release("", when="2026-11-05T10:00:00Z", email="owner@example.com"),
            deploy_release(2, when="2026-11-06T09:00:00Z"),
        ]
    )
    assert run(api)["decision"] == "disabled"


def test_messageless_disable_by_the_guard_account_counts_as_acted():
    api = FakeApi(
        [disable_release("", email=SA), deploy_release(2, when="2026-11-26T09:00:00Z")]
    )
    assert run(api)["decision"] == "noop_already_acted_this_period"
    assert api.disable_calls == []


def test_marker_generation_bump_rearms_the_same_period():
    api = FakeApi(
        [disable_release(f"{MARKER} test"), deploy_release(2, when="2026-11-26T09:00:00Z")]
    )
    record = run(api, config=make_config(marker_generation="2"))
    assert record["decision"] == "disabled"
    assert "gen=2]" in api.disable_calls[0]


def test_redisable_policy_disables_again_after_a_reenable():
    api = FakeApi(
        [disable_release(f"{MARKER} over budget"), deploy_release(2, when="2026-11-26T09:00:00Z")]
    )
    record = run(api, config=make_config(redisable_while_over_budget=True))
    assert record["decision"] == "disabled"
    assert run(api, config=make_config(redisable_while_over_budget=True))["decision"] == (
        "noop_already_disabled"
    )
    assert len(api.disable_calls) == 1


def test_preview_channel_releases_do_not_hide_a_disabled_live_site():
    api = FakeApi(
        [
            disable_release(f"{MARKER} over budget"),
            {
                "name": "sites/wandering-inn-rpg/channels/pr-12/releases/5",
                "type": "DEPLOY",
                "releaseTime": "2026-11-26T09:00:00Z",
            },
        ]
    )
    assert run(api)["decision"] == "noop_already_disabled"


# ------------------------------------------------------------------- refusals
@pytest.mark.parametrize(
    "body, attributes",
    [
        (payload(budgetDisplayName="gpt-development monthly"), None),
        (payload(budgetDisplayName=None), None),
        (None, {"billingAccountId": "111111-222222-333333", "budgetId": BUDGET_ID, "schemaVersion": "1.0"}),
        (None, {"billingAccountId": BILLING, "budgetId": "someone-elses", "schemaVersion": "1.0"}),
        (None, {}),
    ],
)
def test_wrong_budget_is_a_noop(body, attributes):
    api = FakeApi([deploy_release()])
    record = run(api, body, attributes=attributes)
    assert record["decision"] == "ignored_wrong_budget"
    assert api.list_calls == 0 and api.disable_calls == []


def test_forecast_only_message_is_ignored():
    api = FakeApi([deploy_release()])
    record = run(
        api, payload(costAmount=3.0, alertThresholdExceeded=None, forecastThresholdExceeded=1.5)
    )
    assert record["decision"] == "ignored_forecast_only"
    assert api.list_calls == 0 and api.disable_calls == []


def test_forecast_key_never_substitutes_for_actual_spend():
    api = FakeApi([deploy_release()])
    record = run(api, payload(costAmount=9.99, alertThresholdExceeded=0.8, forecastThresholdExceeded=2.0))
    assert record["decision"] == "noop_under_budget"
    assert api.disable_calls == []


MALFORMED_EVENTS = {
    "not-a-dict": "nope",
    "no-message": {},
    "no-data": {"message": {"attributes": {}}},
    "bad-base64": event(raw="%%%not-base64%%%"),
    "not-utf8": event(raw=base64.b64encode(b"\xff\xfe\xfd").decode()),
    "not-json": event(raw=base64.b64encode(b"{oops").decode()),
    "json-array": event(raw=base64.b64encode(b"[1,2]").decode()),
    "missing-cost": event(payload(costAmount=None)),
    "missing-budget": event(payload(budgetAmount=None)),
    "missing-period": event(payload(costIntervalStart=None)),
    "string-cost": event(payload(costAmount="10.42")),
    "bool-cost": event(payload(costAmount=True)),
    "nan-cost": event(raw=base64.b64encode(json.dumps(payload(costAmount=float("nan"))).encode()).decode()),
    "zero-budget": event(payload(budgetAmount=0)),
    "negative-cost": event(payload(costAmount=-1)),
    "bad-period": event(payload(costIntervalStart="last tuesday")),
    "last-month-budget-type": event(payload(budgetAmountType="LAST_MONTH_COST")),
    "bad-schema": event(attributes={"billingAccountId": BILLING, "budgetId": BUDGET_ID, "schemaVersion": "2.0"}),
    "bad-publish-time": event(publish_time="yesterday"),
}


@pytest.mark.parametrize("name", sorted(MALFORMED_EVENTS))
def test_malformed_messages_are_acked_noops(name):
    api = FakeApi([deploy_release()])
    record = guard.handle_event(MALFORMED_EVENTS[name], make_config(), api, now=NOW)  # must not raise
    assert record["decision"] == "ignored_malformed", record
    assert record["severity"] == "WARNING"
    assert api.list_calls == 0 and api.disable_calls == []


def test_stale_delivery_is_acked_without_acting():
    api = FakeApi([deploy_release()])
    record = run(api, publish_time="2026-11-27T09:00:00Z")
    assert record["decision"] == "ignored_stale_event"
    assert api.disable_calls == []


@pytest.mark.parametrize(
    "period",
    ["2026-10-01T07:00:00Z", "2026-12-01T08:00:00Z", "2025-11-01T07:00:00Z"],
)
def test_other_periods_never_disable(period):
    api = FakeApi([deploy_release()])
    record = run(api, payload(costIntervalStart=period))
    assert record["decision"] == "ignored_stale_period"
    assert api.list_calls == 0 and api.disable_calls == []


# -------------------------------------------------------------- API failures
@pytest.mark.parametrize("stage", ["list", "create"])
def test_transient_api_error_signals_retry(stage):
    error = guard.TransientError("Hosting API HTTP 503")
    api = FakeApi([deploy_release()], **{f"{stage}_error": error})
    with pytest.raises(guard.TransientError):
        run(api)
    assert api.disable_calls == []


@pytest.mark.parametrize("stage", ["list", "create"])
def test_permanent_api_error_is_acked_and_logged_as_error(stage):
    error = guard.PermanentApiError("Hosting API HTTP 403")
    api = FakeApi([deploy_release()], **{f"{stage}_error": error})
    record = run(api)
    assert record["decision"] == "error_api_refused"
    assert record["severity"] == "ERROR"


def test_truncated_listing_still_disables_and_says_so():
    api = FakeApi([deploy_release()], truncated=True)
    record = run(api)
    assert record["decision"] == "disabled"
    assert record["release_list_truncated"] is True


# -------------------------------------------------------------------- DRY_RUN
def test_dry_run_logs_intent_and_calls_nothing():
    api = FakeApi([deploy_release()])
    record = run(api, config=make_config(dry_run=True))
    assert record["decision"] == "dry_run_would_disable"
    assert record["would_post"]["parent"] == "projects/gpt-development/sites/wandering-inn-rpg"
    assert record["would_post"]["body"]["type"] == "SITE_DISABLE"
    assert MARKER in record["would_post"]["body"]["message"]
    assert api.list_calls == 0 and api.disable_calls == []


def test_dry_run_works_with_no_api_client_at_all():
    record = guard.handle_event(event(), make_config(dry_run=True), None, now=NOW)
    assert record["decision"] == "dry_run_would_disable"


def test_every_decision_is_one_json_serialisable_record():
    record = run(FakeApi([deploy_release()]))
    line = json.dumps(record, sort_keys=True)
    assert "\n" not in line
    for key in ("decision", "severity", "message", "site", "project", "dry_run", "period"):
        assert key in record


# -------------------------------------------------------------- startup rails
ENV = {
    "GUARD_PROJECT_ID": "gpt-development",
    "GUARD_SITE_ID": "wandering-inn-rpg",
    "GUARD_BUDGET_DISPLAY_NAME": BUDGET_NAME,
    "GUARD_BILLING_ACCOUNT_ID": BILLING,
    "DRY_RUN": "1",
}


def test_valid_env_loads_with_safe_defaults():
    config = guard.Config.from_env(ENV)
    assert config.dry_run is True
    assert config.redisable_while_over_budget is False
    assert config.site_parent == "projects/gpt-development/sites/wandering-inn-rpg"


@pytest.mark.parametrize("site", ["gpt-development", "wandering-inn-rpg-staging", "", "*"])
def test_site_outside_the_allowlist_is_refused_at_startup(site):
    with pytest.raises(guard.ConfigError):
        guard.Config.from_env({**ENV, "GUARD_SITE_ID": site})


def test_allowlist_contains_only_the_game_site():
    assert guard.ALLOWED_SITES == frozenset({"wandering-inn-rpg"})
    assert guard.ALLOWED_PROJECTS == frozenset({"gpt-development"})


@pytest.mark.parametrize(
    "override",
    [
        {"GUARD_PROJECT_ID": "leap-platform-dev"},
        {"GUARD_BUDGET_DISPLAY_NAME": ""},
        {"GUARD_BILLING_ACCOUNT_ID": ""},
        {"DRY_RUN": ""},
        {"DRY_RUN": "maybe"},
        {"REDISABLE_WHILE_OVER_BUDGET": "sometimes"},
        {"MAX_EVENT_AGE_SECONDS": "soon"},
        {"MAX_EVENT_AGE_SECONDS": "0"},
        {"GUARD_MARKER_GENERATION": "has space]"},
    ],
)
def test_bad_config_is_refused_at_startup(override):
    with pytest.raises(guard.ConfigError):
        guard.Config.from_env({**ENV, **override})


def test_dry_run_must_be_explicit():
    env = {k: v for k, v in ENV.items() if k != "DRY_RUN"}
    with pytest.raises(guard.ConfigError):
        guard.Config.from_env(env)


# ------------------------------------------------- HTTP client (fake opener)
class _Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


def _http_error(code):
    return urllib.error.HTTPError("https://x", code, "err", {}, io.BytesIO(b'{"error":"x"}'))


def make_api(responses):
    calls = []

    def opener(request, timeout=None):
        calls.append(request)
        result = responses.pop(0)
        if isinstance(result, Exception):
            raise result
        return _Response(json.dumps(result).encode())

    return guard.HostingApi(make_config(), token_provider=lambda: "tok", opener=opener), calls


def test_disable_request_shape_matches_the_rest_reference():
    api, calls = make_api([{"name": "sites/wandering-inn-rpg/releases/1", "type": "SITE_DISABLE"}])
    api.disable_site("hello")
    request = calls[0]
    assert request.get_method() == "POST"
    assert request.full_url == (
        "https://firebasehosting.googleapis.com/v1beta1/"
        "projects/gpt-development/sites/wandering-inn-rpg/releases"
    )
    assert "versionName" not in request.full_url
    assert json.loads(request.data) == {"type": "SITE_DISABLE", "message": "hello"}
    assert request.get_header("Authorization") == "Bearer tok"


def test_list_follows_pagination_and_only_reads():
    api, calls = make_api(
        [{"releases": [deploy_release(1)], "nextPageToken": "p2"}, {"releases": [deploy_release(2)]}]
    )
    releases, truncated = api.list_releases()
    assert [r["name"][-1] for r in releases] == ["1", "2"] and truncated is False
    assert all(c.get_method() == "GET" for c in calls)
    assert "pageToken=p2" in calls[1].full_url
    assert calls[0].full_url.startswith(
        "https://firebasehosting.googleapis.com/v1beta1/"
        "projects/gpt-development/sites/wandering-inn-rpg/releases?"
    )


def test_list_stops_at_the_page_cap():
    pages = [{"releases": [], "nextPageToken": "more"} for _ in range(guard.MAX_RELEASE_PAGES)]
    api, calls = make_api(pages)
    assert api.list_releases() == ([], True)
    assert len(calls) == guard.MAX_RELEASE_PAGES


@pytest.mark.parametrize("code", [429, 500, 502, 503, 504])
def test_http_5xx_and_429_are_transient(code):
    api, _ = make_api([_http_error(code)])
    with pytest.raises(guard.TransientError):
        api.list_releases()


@pytest.mark.parametrize("code", [400, 401, 403, 404])
def test_http_4xx_is_permanent(code):
    api, _ = make_api([_http_error(code)])
    with pytest.raises(guard.PermanentApiError):
        api.disable_site("x")


def test_network_failure_is_transient():
    api, _ = make_api([urllib.error.URLError("dns")])
    with pytest.raises(guard.TransientError):
        api.list_releases()


def test_end_to_end_through_the_http_client():
    api, calls = make_api(
        [{"releases": [deploy_release()]}, {"name": "sites/wandering-inn-rpg/releases/2", "message": MARKER}]
    )
    record = guard.handle_event(event(), make_config(), api, now=NOW)
    assert record["decision"] == "disabled"
    assert [c.get_method() for c in calls] == ["GET", "POST"]


# ------------------------------------------- entry point (needs the framework)
@pytest.fixture
def entry(monkeypatch):
    pytest.importorskip("functions_framework")
    for key, value in ENV.items():
        monkeypatch.setenv(key, value)
    monkeypatch.syspath_prepend(str(GUARD_DIR))
    sys.modules.pop("main", None)
    module = _load("main", "main.py")
    yield module
    sys.modules.pop("main", None)


def test_entry_point_logs_exactly_one_json_line(entry, capsys):
    entry.process(event())
    lines = [line for line in capsys.readouterr().out.splitlines() if line.strip()]
    assert len(lines) == 1
    assert json.loads(lines[0])["decision"] == "ignored_stale_event"  # real clock, 2026 event


def test_entry_point_reraises_transient_and_swallows_bugs(entry, monkeypatch, capsys):
    def transient(*_a, **_k):
        raise entry.guard.TransientError("503")

    monkeypatch.setattr(entry.guard, "handle_event", transient)
    with pytest.raises(entry.guard.TransientError):
        entry.process(event())
    assert json.loads(capsys.readouterr().out.strip())["decision"] == "retry_transient_error"

    def bug(*_a, **_k):
        raise RuntimeError("boom")

    monkeypatch.setattr(entry.guard, "handle_event", bug)
    assert entry.process(event())["decision"] == "error_unexpected"


def test_entry_point_refuses_to_import_with_a_foreign_site(monkeypatch):
    pytest.importorskip("functions_framework")
    for key, value in {**ENV, "GUARD_SITE_ID": "gpt-development"}.items():
        monkeypatch.setenv(key, value)
    monkeypatch.syspath_prepend(str(GUARD_DIR))
    sys.modules.pop("main", None)
    with pytest.raises(guard.ConfigError):
        _load("main", "main.py")
    sys.modules.pop("main", None)
