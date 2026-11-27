#!/usr/bin/env bash
# Shared, fixed identifiers for deploy.sh / teardown.sh / test-publish.sh.
# Sourced, never executed. Nothing here is a secret.
#
# PROJECT and SITE are constants on purpose: the function's code allowlists
# exactly these two values and refuses to start with anything else.
# shellcheck disable=SC2034  # variables are used by the sourcing scripts

PROJECT="gpt-development"
SITE="wandering-inn-rpg"

# us-central1: the region Google's own Pub/Sub-function tutorial uses, a
# Tier 1 (cheapest) Cloud Run pricing region, and supported by Eventarc,
# Cloud Build and Artifact Registry. Latency is irrelevant here (billing
# data is hours old before the function ever sees it).
REGION="us-central1"

TOPIC="wi-hosting-budget"
FUNCTION="wi-hosting-budget-guard"
RUNTIME="python312"
ENTRY_POINT="hosting_budget_guard"

# Runtime identity: what the function's code runs as (may edit Hosting).
RUNTIME_SA_ID="wi-hosting-budget-guard"
RUNTIME_SA="${RUNTIME_SA_ID}@${PROJECT}.iam.gserviceaccount.com"
# Trigger identity: what Eventarc/PubSub uses to invoke the function (may
# invoke this one service, nothing else).
TRIGGER_SA_ID="wi-hosting-budget-trigger"
TRIGGER_SA="${TRIGGER_SA_ID}@${PROJECT}.iam.gserviceaccount.com"

BUDGET_DISPLAY_NAME="wi-hosting-kill-switch"
# Cloud Billing service id of Firebase Hosting (billing catalog).
HOSTING_SERVICE="services/2662-232A-AC11"

# "$BILLING_ACCOUNT" style id; required as --billing-account or env.
BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"

_DRY=0
step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# run CMD...: print the exact command, then execute it unless --dry-run.
run() {
	printf '    $'
	printf ' %q' "$@"
	printf '\n'
	if [ "$_DRY" = 1 ]; then return 0; fi
	"$@"
}

# exists CMD...: quiet read-only probe. In --dry-run nothing is called, so
# it reports "missing" and the script prints the create path.
exists() {
	if [ "$_DRY" = 1 ]; then return 1; fi
	"$@" >/dev/null 2>&1
}

require_billing_account() {
	[ -n "$BILLING_ACCOUNT" ] || die "billing account required: --billing-account XXXXXX-XXXXXX-XXXXXX (or BILLING_ACCOUNT env)"
	[[ "$BILLING_ACCOUNT" =~ ^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$ ]] \
		|| die "billing account '$BILLING_ACCOUNT' is not of the form XXXXXX-XXXXXX-XXXXXX"
}

# Prints the budget's resource name (billingAccounts/…/budgets/ID) or nothing.
find_budget() {
	gcloud billing budgets list \
		--billing-account="$BILLING_ACCOUNT" \
		--billing-project="$PROJECT" \
		--filter="displayName=${BUDGET_DISPLAY_NAME}" \
		--format="value(name)" | head -n 1
}
