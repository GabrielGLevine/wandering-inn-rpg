#!/usr/bin/env bash
# test-publish.sh — publish ONE synthetic budget notification to the topic,
# so the whole chain (Pub/Sub -> Eventarc -> function -> log line) can be
# exercised without waiting for real spend. Owner-run.
#
#   ./test-publish.sh --billing-account "$BILLING_ACCOUNT"            # over budget
#   ./test-publish.sh --billing-account … --cost 2.00                    # under budget
#   ./test-publish.sh --billing-account … --dry-run                      # print only
#   ./test-publish.sh --billing-account … --live-yes-disable-the-site    # ARMED test
#
# SAFETY: an over-budget message sent to an ARMED function takes
# https://wandering-inn-rpg.web.app offline. So this script reads the
# deployed function's DRY_RUN setting first and refuses unless it is "1" —
# or you pass --live-yes-disable-the-site. See README "Testing".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/hosting-budget-guard/config.sh
. "$HERE/config.sh"

COST="12.34"
AMOUNT="10"
LIVE=0
while [ $# -gt 0 ]; do
	case "$1" in
		--billing-account) BILLING_ACCOUNT="${2:?}"; shift 2 ;;
		--cost) COST="${2:?}"; shift 2 ;;
		--amount) AMOUNT="${2:?}"; shift 2 ;;
		--live-yes-disable-the-site) LIVE=1; shift ;;
		--dry-run) _DRY=1; shift ;;
		-h | --help) sed -n '2,16p' "$0"; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done
require_billing_account
[[ "$COST" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "--cost must be a number"
[[ "$AMOUNT" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "--amount must be a number"

BUDGET_ID="<budget-id>"
if [ "$_DRY" != 1 ]; then
	step "Check the deployed function's mode"
	MODE="$(gcloud functions describe "$FUNCTION" --project="$PROJECT" --region="$REGION" \
		--format="value(serviceConfig.environmentVariables.DRY_RUN)")"
	note "function DRY_RUN=${MODE:-<unset>}"
	if [ "$MODE" != "1" ] && [ "$LIVE" != 1 ]; then
		die "the function is ARMED; an over-budget test would disable the live site. Re-deploy with --guard-mode observe, or pass --live-yes-disable-the-site."
	fi
	if [ "$MODE" = "1" ] && [ "$LIVE" = 1 ]; then
		note "function is observing; --live flag has no effect (nothing will be disabled)"
	fi
	BUDGET_NAME="$(find_budget)"
	[ -n "$BUDGET_NAME" ] || die "budget '$BUDGET_DISPLAY_NAME' not found — run deploy.sh first"
	BUDGET_ID="${BUDGET_NAME##*/}"
fi

# Budget months start at midnight US Pacific time on the 1st. The UTC offset
# is the one in force ON THE 1ST (07:00Z in a PDT month, 08:00Z in PST), not
# today's -- so compute it with the guard's own zoneinfo code, which is also
# what the function uses to build its once-per-period marker.
command -v python3 >/dev/null || die "python3 not found"
PERIOD="$(python3 "$HERE/guard.py" period-start)" || die "could not compute the budget period start"
MESSAGE="$(printf '{"budgetDisplayName":"%s","costAmount":%s,"costIntervalStart":"%s","budgetAmount":%s,"budgetAmountType":"SPECIFIED_AMOUNT","alertThresholdExceeded":1.0,"currencyCode":"USD"}' \
	"$BUDGET_DISPLAY_NAME" "$COST" "$PERIOD" "$AMOUNT")"

step "Publish a synthetic notification (cost $COST of budget $AMOUNT, period $PERIOD)"
run gcloud pubsub topics publish "$TOPIC" \
	--project="$PROJECT" \
	--message="$MESSAGE" \
	--attribute="billingAccountId=${BILLING_ACCOUNT},budgetId=${BUDGET_ID},schemaVersion=1.0"

step "Read the decision (give it ~30 seconds, then run)"
cat <<LOGCMD
    gcloud logging read \\
      'resource.type="cloud_run_revision" AND resource.labels.service_name="${FUNCTION}" AND jsonPayload.component="wi-hosting-budget-guard"' \\
      --project=${PROJECT} --freshness=10m --limit=5 \\
      --format='value(timestamp,jsonPayload.decision,jsonPayload.reason)'
LOGCMD
note "Expected: dry_run_would_disable (observe mode, over budget),"
note "          noop_under_budget (with --cost below --amount),"
note "          disabled (armed + --live-yes-disable-the-site)."
