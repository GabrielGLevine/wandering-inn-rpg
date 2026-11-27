#!/usr/bin/env bash
# teardown.sh — remove everything deploy.sh created. Owner-run, idempotent.
#
#   ./teardown.sh --billing-account "$BILLING_ACCOUNT" [--dry-run]
#
# Removes: the function (and its Eventarc trigger/subscription), the budget
# named wi-hosting-kill-switch, the topic, the IAM bindings, and the two
# service accounts. Leaves: enabled APIs (other services may use them), the
# "gpt-development monthly" budget, the Hosting site and its releases.
# It does NOT re-enable a site the guard disabled — see README "Re-enable".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/hosting-budget-guard/config.sh
. "$HERE/config.sh"

while [ $# -gt 0 ]; do
	case "$1" in
		--billing-account) BILLING_ACCOUNT="${2:?}"; shift 2 ;;
		--dry-run) _DRY=1; shift ;;
		-h | --help) sed -n '2,12p' "$0"; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done
require_billing_account
command -v gcloud >/dev/null || die "gcloud not found"
[ "$_DRY" = 1 ] && echo "*** --dry-run: printing commands only, calling nothing ***"

step "1/5 Budget '$BUDGET_DISPLAY_NAME' (first, so nothing publishes to a dead topic)"
if [ "$_DRY" = 1 ]; then
	note "would look up the budget by display name, then:"
	run gcloud billing budgets delete "billingAccounts/${BILLING_ACCOUNT}/budgets/<budget-id>" \
		--billing-project="$PROJECT" --quiet
else
	BUDGET_NAME="$(find_budget)"
	if [ -n "$BUDGET_NAME" ]; then
		run gcloud billing budgets delete "$BUDGET_NAME" --billing-project="$PROJECT" --quiet
	else
		note "not found"
	fi
fi

step "2/5 Function $FUNCTION (its Eventarc trigger goes with it)"
if [ "$_DRY" = 1 ] || exists gcloud functions describe "$FUNCTION" --project="$PROJECT" --region="$REGION"; then
	run gcloud functions delete "$FUNCTION" --project="$PROJECT" --region="$REGION" --quiet
else
	note "not found"
fi

step "3/5 Topic $TOPIC"
if [ "$_DRY" = 1 ] || exists gcloud pubsub topics describe "$TOPIC" --project="$PROJECT"; then
	run gcloud pubsub topics delete "$TOPIC" --project="$PROJECT" --quiet
else
	note "not found"
fi

step "4/5 Project IAM bindings"
if [ "$_DRY" = 1 ] || exists gcloud iam service-accounts describe "$RUNTIME_SA" --project="$PROJECT"; then
	run gcloud projects remove-iam-policy-binding "$PROJECT" \
		--member="serviceAccount:${RUNTIME_SA}" --role="roles/firebasehosting.admin" \
		--condition=None --quiet --format=none || note "binding already absent"
fi
if [ "$_DRY" = 1 ] || exists gcloud iam service-accounts describe "$TRIGGER_SA" --project="$PROJECT"; then
	run gcloud projects remove-iam-policy-binding "$PROJECT" \
		--member="serviceAccount:${TRIGGER_SA}" --role="roles/eventarc.eventReceiver" \
		--condition=None --quiet --format=none || note "binding already absent"
fi

step "5/5 Service accounts"
for sa in "$RUNTIME_SA" "$TRIGGER_SA"; do
	if [ "$_DRY" = 1 ] || exists gcloud iam service-accounts describe "$sa" --project="$PROJECT"; then
		run gcloud iam service-accounts delete "$sa" --project="$PROJECT" --quiet
	else
		note "$sa not found"
	fi
done

step "Done"
note "The Hosting cap is gone. APIs were left enabled on purpose."
