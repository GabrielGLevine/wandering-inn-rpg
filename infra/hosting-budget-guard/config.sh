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
# Build identity: what Cloud Build uses to build the function's container,
# instead of the project's default build account (often broad).
BUILD_SA_ID="wi-hosting-budget-build"
BUILD_SA="${BUILD_SA_ID}@${PROJECT}.iam.gserviceaccount.com"

# Ownership marker. deploy.sh stamps it on everything it creates (a label
# where the resource has labels, the description of service accounts) and
# refuses to adopt a same-named resource without it; teardown.sh deletes
# only resources that carry it.
MANAGED_KEY="managed-by"
MANAGED_VALUE="wi-hosting-budget-guard"
MANAGED_TAG="[${MANAGED_KEY}=${MANAGED_VALUE}]"

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

# Prints the budget's resource name (billingAccounts/…/budgets/ID) or
# nothing. Exact display-name match; MORE THAN ONE match is an error, never
# "take the first" -- the guard pins one budget id and teardown deletes it.
find_budget() {
	local listing matches count
	listing="$(gcloud billing budgets list \
		--billing-account="$BILLING_ACCOUNT" \
		--billing-project="$PROJECT" \
		--format="value(name,displayName)")" || die "could not list budgets on $BILLING_ACCOUNT"
	matches="$(printf '%s\n' "$listing" | awk -F'\t' -v n="$BUDGET_DISPLAY_NAME" '$2 == n { print $1 }')"
	count="$(printf '%s' "$matches" | grep -c . || true)"
	[ "$count" -le 1 ] || die "$count budgets are named '$BUDGET_DISPLAY_NAME' on $BILLING_ACCOUNT; delete or rename the extra ones in the console, then re-run"
	printf '%s' "$matches"
}

# ownership CMD...: run a read-only describe whose --format prints the
# resource's marker field. Prints "missing" (describe failed, or --dry-run),
# "ours" (marker present) or "foreign" (exists without the marker).
ownership() {
	local value
	if [ "$_DRY" = 1 ]; then echo missing; return 0; fi
	if ! value="$("$@" 2>/dev/null)"; then echo missing; return 0; fi
	case "$value" in
		*"$MANAGED_VALUE"*) echo ours ;;
		*) echo foreign ;;
	esac
}

refuse_foreign() {
	die "$1 already exists but was not created by deploy.sh (no ${MANAGED_TAG} marker). Refusing to adopt or delete it; rename it or change the name in config.sh."
}

topic_ownership() {
	ownership gcloud pubsub topics describe "$TOPIC" --project="$PROJECT" \
		--format="value(labels.${MANAGED_KEY})"
}
sa_ownership() {
	ownership gcloud iam service-accounts describe "$1" --project="$PROJECT" \
		--format="value(description)"
}
function_ownership() {
	ownership gcloud functions describe "$FUNCTION" --project="$PROJECT" --region="$REGION" \
		--format="value(labels.${MANAGED_KEY})"
}
# A budget has no labels; deploy.sh's budget is the one wired to its topic.
budget_ownership() {
	local topic
	if [ "$_DRY" = 1 ] || [ -z "$1" ]; then echo missing; return 0; fi
	topic="$(gcloud billing budgets describe "$1" --billing-project="$PROJECT" \
		--format="value(notificationsRule.pubsubTopic)" 2>/dev/null)" || { echo missing; return 0; }
	if [ "$topic" = "projects/${PROJECT}/topics/${TOPIC}" ]; then echo ours; else echo foreign; fi
}
