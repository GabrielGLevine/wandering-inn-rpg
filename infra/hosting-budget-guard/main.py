"""Cloud Run functions entry point (2nd gen, Pub/Sub via Eventarc).

All logic lives in guard.py. This file only: loads and validates the config
ONCE at startup (a bad config crashes the container, so a misconfigured
deploy fails visibly instead of running unprotected), prints exactly one
structured JSON log line per message, and maps outcomes to ack/retry:

  return normally -> message acknowledged
  TransientError  -> re-raised -> non-2xx -> Pub/Sub redelivers (bounded by
                     MAX_EVENT_AGE_SECONDS inside guard.handle_event)
"""

import json
import os
import sys

import functions_framework

import guard

CONFIG = guard.Config.from_env(os.environ)
API = guard.HostingApi(CONFIG)


def _log(record: dict) -> None:
    # One JSON object per line on stdout becomes a structured Cloud Logging
    # entry; `severity` and `message` are the recognised special fields.
    print(json.dumps(record, sort_keys=True, default=str), file=sys.stdout, flush=True)


def process(event_data) -> dict:
    try:
        record = guard.handle_event(event_data, CONFIG, API)
    except guard.TransientError as exc:
        _log(
            {
                "component": guard.MARKER_PREFIX,
                "decision": "retry_transient_error",
                "severity": "ERROR",
                "site": CONFIG.site_id,
                "dry_run": CONFIG.dry_run,
                "reason": str(exc),
                "message": f"{guard.MARKER_PREFIX}: retry_transient_error ({exc})",
            }
        )
        raise
    except Exception as exc:  # noqa: BLE001 - a bug must never loop redelivery
        record = {
            "component": guard.MARKER_PREFIX,
            "decision": "error_unexpected",
            "severity": "ERROR",
            "site": CONFIG.site_id,
            "dry_run": CONFIG.dry_run,
            "reason": f"{type(exc).__name__}: {exc}",
            "message": f"{guard.MARKER_PREFIX}: error_unexpected ({type(exc).__name__})",
        }
    _log(record)
    return record


@functions_framework.cloud_event
def hosting_budget_guard(cloud_event) -> None:
    process(cloud_event.data)
