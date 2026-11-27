#!/usr/bin/env bash
# deploy.sh — create or update the Firebase Hosting budget kill-switch.
#
# RUN BY THE OWNER, BY HAND. Nothing in CI calls this. It is idempotent:
# every step first checks whether the resource exists, so re-running it
# converges instead of duplicating. Read README.md first.
#
#   ./deploy.sh --billing-account "$BILLING_ACCOUNT" --guard-mode observe
#   ./deploy.sh --billing-account "$BILLING_ACCOUNT" --guard-mode armed
#   ./deploy.sh --billing-account … --guard-mode observe --dry-run   # print only
#
# Options
#   --billing-account ID   required (or env BILLING_ACCOUNT)
#   --guard-mode MODE      required: observe = function logs what it WOULD do
#                          (DRY_RUN=1); armed = function really disables the
#                          site (DRY_RUN=0). No default, so a re-run can never
#                          silently arm or disarm the guard.
#   --amount USD           monthly Firebase Hosting cap, default 10
#   --redisable            policy switch: re-disable on every notification
#                          while over budget, even after a manual re-enable
#                          (default off — see README "The re-enable rule")
#   --marker-generation N  bump to re-arm the guard inside a month in which
#                          it has already fired (default 1)
#   --dry-run              print every command, call nothing (not even reads)
#
# What it touches: ONLY resources named wi-hosting-budget* in project
# gpt-development, one budget named wi-hosting-kill-switch on the billing
# account, and additive IAM bindings for two new service accounts. It never
# reads or changes gcloud config, the default Hosting site, the existing
# "gpt-development monthly" budget, billing linkage, or any other service.
# Every gcloud call names --project / --billing-project explicitly because
# this machine's default gcloud config points at an unrelated project.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/hosting-budget-guard/config.sh
. "$HERE/config.sh"

AMOUNT="10"
GUARD_MODE=""
REDISABLE="0"
MARKER_GENERATION="1"

while [ $# -gt 0 ]; do
	case "$1" in
		--billing-account) BILLING_ACCOUNT="${2:?}"; shift 2 ;;
		--guard-mode) GUARD_MODE="${2:?}"; shift 2 ;;
		--amount) AMOUNT="${2:?}"; shift 2 ;;
		--redisable) REDISABLE="1"; shift ;;
		--marker-generation) MARKER_GENERATION="${2:?}"; shift 2 ;;
		--dry-run) _DRY=1; shift ;;
		-h | --help) sed -n '2,32p' "$0"; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done

require_billing_account
case "$GUARD_MODE" in
	observe) FUNCTION_DRY_RUN="1" ;;
	armed) FUNCTION_DRY_RUN="0" ;;
	*) die "--guard-mode observe|armed is required" ;;
esac
[[ "$AMOUNT" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || die "--amount must be a plain USD number, e.g. 10 or 7.50"
[[ "$MARKER_GENERATION" =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || die "--marker-generation must match [A-Za-z0-9_.-]{1,32}"
command -v gcloud >/dev/null || die "gcloud not found"

TOPIC_PATH="projects/${PROJECT}/topics/${TOPIC}"

echo "Hosting budget kill-switch"
echo "  project          $PROJECT"
echo "  site protected   $SITE"
echo "  region           $REGION"
echo "  billing account  $BILLING_ACCOUNT"
echo "  cap              $AMOUNT USD / month, Firebase Hosting only"
echo "  guard mode       $GUARD_MODE (function DRY_RUN=$FUNCTION_DRY_RUN)"
echo "  re-disable       $REDISABLE"
[ "$_DRY" = 1 ] && echo "  *** --dry-run: printing commands only, calling nothing ***"

# ---------------------------------------------------------------- 1. APIs
step "1/7 Enable the APIs the guard needs (no-op for ones already on)"
note "Enabling an API never changes services that already use it."
run gcloud services enable \
	cloudfunctions.googleapis.com \
	run.googleapis.com \
	cloudbuild.googleapis.com \
	artifactregistry.googleapis.com \
	eventarc.googleapis.com \
	pubsub.googleapis.com \
	logging.googleapis.com \
	billingbudgets.googleapis.com \
	firebasehosting.googleapis.com \
	--project="$PROJECT"

# --------------------------------------------------------------- 2. topic
step "2/7 Pub/Sub topic $TOPIC"
if exists gcloud pubsub topics describe "$TOPIC" --project="$PROJECT"; then
	note "exists"
else
	run gcloud pubsub topics create "$TOPIC" --project="$PROJECT"
fi

# ---------------------------------------------------- 3. service accounts
step "3/7 Service accounts (runtime + trigger)"
if exists gcloud iam service-accounts describe "$RUNTIME_SA" --project="$PROJECT"; then
	note "runtime SA exists"
else
	run gcloud iam service-accounts create "$RUNTIME_SA_ID" --project="$PROJECT" \
		--display-name="WI Hosting budget guard (runtime)" \
		--description="Runs the Hosting budget kill-switch; may create Hosting releases."
fi
if exists gcloud iam service-accounts describe "$TRIGGER_SA" --project="$PROJECT"; then
	note "trigger SA exists"
else
	run gcloud iam service-accounts create "$TRIGGER_SA_ID" --project="$PROJECT" \
		--display-name="WI Hosting budget guard (Eventarc trigger)" \
		--description="Identity Eventarc uses to invoke the budget guard; nothing else."
fi

# ------------------------------------------------------------ 4. IAM roles
step "4/7 IAM (additive bindings only; add-iam-policy-binding is idempotent)"
note "Runtime SA: roles/firebasehosting.admin — the narrowest PREDEFINED role"
note "that can create a Hosting release. It is project-wide (Hosting has no"
note "per-site IAM); the site allowlist in the code is what pins the target."
run gcloud projects add-iam-policy-binding "$PROJECT" \
	--member="serviceAccount:${RUNTIME_SA}" \
	--role="roles/firebasehosting.admin" \
	--condition=None --quiet --format=none
note "Trigger SA: roles/eventarc.eventReceiver (receive events for the trigger)."
run gcloud projects add-iam-policy-binding "$PROJECT" \
	--member="serviceAccount:${TRIGGER_SA}" \
	--role="roles/eventarc.eventReceiver" \
	--condition=None --quiet --format=none

# --------------------------------------------------------------- 5. budget
# Before the function, so the function can be pinned to this budget's id.
step "5/7 Budget '$BUDGET_DISPLAY_NAME' ($AMOUNT USD/month, Firebase Hosting in $PROJECT)"
note "Thresholds 50% / 80% / 100% of ACTUAL spend; emails still go to billing"
note "admins (default IAM recipients left on); status also goes to Pub/Sub."
note "The existing 'gpt-development monthly' budget is not read or changed."
BUDGET_NAME=""
if [ "$_DRY" != 1 ]; then BUDGET_NAME="$(find_budget)"; fi
if [ -z "$BUDGET_NAME" ]; then
	run gcloud billing budgets create \
		--billing-account="$BILLING_ACCOUNT" \
		--billing-project="$PROJECT" \
		--display-name="$BUDGET_DISPLAY_NAME" \
		--budget-amount="${AMOUNT}USD" \
		--calendar-period=month \
		--filter-projects="projects/${PROJECT}" \
		--filter-services="$HOSTING_SERVICE" \
		--credit-types-treatment=exclude-all-credits \
		--threshold-rule=percent=0.5,basis=current-spend \
		--threshold-rule=percent=0.8,basis=current-spend \
		--threshold-rule=percent=1.0,basis=current-spend \
		--notifications-rule-pubsub-topic="$TOPIC_PATH"
	if [ "$_DRY" != 1 ]; then BUDGET_NAME="$(find_budget)"; fi
else
	note "exists: $BUDGET_NAME — updating amount, scope and topic"
	# Threshold rules are deliberately NOT rewritten on update (the gcloud
	# reference documents the percent unit differently for create and update);
	# they are read back and checked below instead.
	run gcloud billing budgets update "$BUDGET_NAME" \
		--billing-project="$PROJECT" \
		--budget-amount="${AMOUNT}USD" \
		--calendar-period=month \
		--filter-projects="projects/${PROJECT}" \
		--filter-services="$HOSTING_SERVICE" \
		--credit-types-treatment=exclude-all-credits \
		--notifications-rule-pubsub-topic="$TOPIC_PATH"
fi
if [ "$_DRY" = 1 ]; then
	BUDGET_ID="<budget-id-known-after-create>"
else
	[ -n "$BUDGET_NAME" ] || die "budget not found after create/update"
	BUDGET_ID="${BUDGET_NAME##*/}"
	note "budget id: $BUDGET_ID"
	RULES="$(gcloud billing budgets describe "$BUDGET_NAME" --billing-project="$PROJECT" \
		--format="value(thresholdRules[].thresholdPercent)")"
	note "threshold rules now: ${RULES:-<none>}"
	case "$RULES" in
		*0.5*0.8*1.0* | *0.5*0.8*1) ;;
		*) echo "WARNING: thresholds are not 0.5/0.8/1.0 — fix them in the console (Billing > Budgets & alerts). The kill-switch itself only needs costAmount >= budgetAmount and still works." >&2 ;;
	esac
fi

# ------------------------------------------------------------- 6. function
step "6/7 Deploy function $FUNCTION ($RUNTIME, $REGION, mode: $GUARD_MODE)"
note "--retry + the function's own event-age cut-off = bounded retries for"
note "transient Hosting API errors only. --max-instances=1 keeps it serial."
run gcloud functions deploy "$FUNCTION" \
	--gen2 \
	--project="$PROJECT" \
	--region="$REGION" \
	--runtime="$RUNTIME" \
	--source="$HERE" \
	--entry-point="$ENTRY_POINT" \
	--trigger-topic="$TOPIC" \
	--trigger-service-account="$TRIGGER_SA" \
	--service-account="$RUNTIME_SA" \
	--retry \
	--no-allow-unauthenticated \
	--max-instances=1 \
	--memory=256Mi \
	--timeout=60s \
	--set-env-vars="GUARD_PROJECT_ID=${PROJECT},GUARD_SITE_ID=${SITE},GUARD_BUDGET_DISPLAY_NAME=${BUDGET_DISPLAY_NAME},GUARD_BILLING_ACCOUNT_ID=${BILLING_ACCOUNT},GUARD_BUDGET_ID=${BUDGET_ID},GUARD_SERVICE_ACCOUNT=${RUNTIME_SA},GUARD_MARKER_GENERATION=${MARKER_GENERATION},REDISABLE_WHILE_OVER_BUDGET=${REDISABLE},DRY_RUN=${FUNCTION_DRY_RUN}" \
	--quiet

# -------------------------------------------------------------- 7. invoker
step "7/7 Let the trigger SA invoke THIS service only"
note "Bound on the function's Cloud Run service, not on the project."
run gcloud run services add-iam-policy-binding "$FUNCTION" \
	--project="$PROJECT" \
	--region="$REGION" \
	--member="serviceAccount:${TRIGGER_SA}" \
	--role="roles/run.invoker" \
	--quiet --format=none

step "Done"
if [ "$GUARD_MODE" = observe ]; then
	note "The guard is OBSERVING: it logs decisions and never disables the site."
	note "Test it:   ./test-publish.sh --billing-account $BILLING_ACCOUNT"
	note "Then arm:  ./deploy.sh --billing-account $BILLING_ACCOUNT --guard-mode armed"
else
	note "The guard is ARMED: at >= 100% of the Hosting budget it disables $SITE."
fi
note "Budget notifications can take several hours to start flowing."
