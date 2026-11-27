#!/usr/bin/env bash
# teardown.sh — remove everything deploy.sh created. Owner-run, idempotent.
#
#   ./teardown.sh --billing-account "$BILLING_ACCOUNT" [--dry-run]
#
# Removes: the function (and its Eventarc trigger/subscription), the budget
# named wi-hosting-kill-switch, the topic, the IAM bindings, and the three
# service accounts (runtime, trigger, build). Leaves: enabled APIs (other
# services may use them), the "gpt-development monthly" budget, the Hosting
# site and its releases.
#
# It deletes ONLY resources that carry deploy.sh's ownership marker
# (managed-by=wi-hosting-budget-guard as a label or in a service account's
# description; for the budget: it publishes to the guard's topic). A
# same-named resource without the marker is left alone and the script stops
# with an error, so a pre-existing topic or account can never be deleted.
# It does NOT re-enable a site the guard disabled — see README "Re-enable".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/hosting-budget-guard/config.sh
. "$HERE/config.sh"

while [ $# -gt 0 ]; do
	case "$1" in
		--billing-account) BILLING_ACCOUNT="${2:?}"; shift 2 ;;
		--dry-run) _DRY=1; shift ;;
		-h | --help) awk 'NR > 1 && /^set -e/ { exit } NR > 1' "$0"; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done
require_billing_account
command -v gcloud >/dev/null || die "gcloud not found"
[ "$_DRY" = 1 ] && echo "*** --dry-run: printing commands only, calling nothing ***"

REFUSED=0
# guarded WHAT STATE CMD...: delete only when STATE is "ours" (or --dry-run).
guarded() {
	local what="$1" state="$2"
	shift 2
	if [ "$_DRY" = 1 ]; then
		note "only if $what carries ${MANAGED_TAG}:"
		run "$@"
		return 0
	fi
	case "$state" in
		ours) run "$@" ;;
		foreign)
			echo "REFUSED: $what exists but has no ${MANAGED_TAG} marker; deploy.sh did not create it. Left untouched." >&2
			REFUSED=1
			;;
		*) note "$what not found" ;;
	esac
}

step "1/5 Budget '$BUDGET_DISPLAY_NAME' (first, so nothing publishes to a dead topic)"
if [ "$_DRY" = 1 ]; then
	BUDGET_NAME="billingAccounts/${BILLING_ACCOUNT}/budgets/<budget-id>"
else
	BUDGET_NAME="$(find_budget)"
fi
guarded "budget $BUDGET_DISPLAY_NAME" "$(budget_ownership "$BUDGET_NAME")" \
	gcloud billing budgets delete "$BUDGET_NAME" --billing-project="$PROJECT" --quiet

step "2/5 Function $FUNCTION (its Eventarc trigger goes with it)"
guarded "function $FUNCTION" "$(function_ownership)" \
	gcloud functions delete "$FUNCTION" --project="$PROJECT" --region="$REGION" --quiet

step "3/5 Topic $TOPIC"
guarded "topic $TOPIC" "$(topic_ownership)" \
	gcloud pubsub topics delete "$TOPIC" --project="$PROJECT" --quiet

step "4/5 Project IAM bindings of the guard's own service accounts"
# remove_bindings EMAIL ROLE...: --all also drops a conditional binding.
remove_bindings() {
	local sa="$1" role
	shift
	[ "$_DRY" = 1 ] || [ "$(sa_ownership "$sa")" = ours ] || { note "$sa not ours or absent; bindings left"; return 0; }
	for role in "$@"; do
		run gcloud projects remove-iam-policy-binding "$PROJECT" \
			--member="serviceAccount:${sa}" --role="$role" \
			--all --quiet --format=none || note "$role binding already absent"
	done
}
remove_bindings "$RUNTIME_SA" roles/firebasehosting.admin
remove_bindings "$TRIGGER_SA" roles/eventarc.eventReceiver
remove_bindings "$BUILD_SA" roles/logging.logWriter roles/artifactregistry.writer roles/storage.objectViewer

step "5/5 Service accounts"
for sa in "$RUNTIME_SA" "$TRIGGER_SA" "$BUILD_SA"; do
	guarded "service account $sa" "$(sa_ownership "$sa")" \
		gcloud iam service-accounts delete "$sa" --project="$PROJECT" --quiet
done

step "Done"
if [ "$REFUSED" = 1 ]; then
	die "some same-named resources were not created by deploy.sh and were left in place (see REFUSED above)."
fi
note "The Hosting cap is gone. APIs were left enabled on purpose."
