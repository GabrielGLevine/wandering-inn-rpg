# Hosting budget kill-switch

Takes the game's web build (`https://wandering-inn-rpg.web.app`, Firebase
Hosting site `wandering-inn-rpg` in GCP project `gpt-development`) **offline
when Firebase Hosting spend for the month reaches a cap** (default 10 USD).
Nothing else in the project is touched: billing stays attached, Cloud Run,
Vertex AI and the project's default Hosting site keep running.

Nothing here is deployed by CI. The owner runs `deploy.sh` by hand.

## Read this first: what it does NOT guarantee

- **It is not a hard cap. Spend can overshoot.** The guard reacts to Cloud
  Billing budget notifications, and billing data is late. Google's words:
  - "There's a delay between incurring costs and receiving budget
    notifications, so you might incur additional costs for usage that hasn't
    arrived at the time that all services are stopped. Following the steps in
    this example doesn't guarantee that you won't spend more than your
    budget." (Cloud Billing, *Disable billing usage with notifications*)
  - "Typically, your cost details are available within a day, but can
    sometimes take more than 24 hours." (Cloud Billing, *View your cost and
    payment history* / *Reports*, "Delayed billing")
  - "Budget notifications are sent to the Pub/Sub topic multiple times per
    day" and "It may take several hours before you receive the first Pub/Sub
    notification." (Cloud Billing, *Programmatic budget notifications*)

  So a traffic spike can run for roughly a day before the guard even learns
  about it. The guard **bounds** the damage of a sustained spike; it does not
  prevent the first day of one. Set the cap below what you can afford.
- **THE RE-ENABLE RULE: the guard disables the site AT MOST ONCE per month.**
  If you put the site back online in a month where the guard already fired,
  **there is no cap for the rest of that month** — notifications keep
  arriving, the guard sees its own marker and deliberately does nothing. This
  is on purpose (otherwise your re-enable would be undone within hours), and
  it is the most important thing to remember after an incident. To get the
  cap back before next month, see [Re-arming](#re-arming-inside-the-same-month).
- If the function is broken, undeployed, in observe mode, or its service
  account loses its role, **nothing protects you** and nothing tells you
  except the budget emails. The 50% / 80% / 100% emails to billing admins are
  the backstop; read them.
- It only watches Firebase Hosting spend (`services/2662-232A-AC11`) in
  `gpt-development`. Other spend is covered only by the existing alert-only
  "gpt-development monthly" budget, which this leaves alone.

## Architecture

```
Cloud Billing budget "wi-hosting-kill-switch"
  scope: project gpt-development AND service Firebase Hosting, monthly
  thresholds 50% / 80% / 100% of actual spend -> emails to billing admins
        |  status JSON, several times a day
        v
Pub/Sub topic wi-hosting-budget
        |  Eventarc trigger (identity: wi-hosting-budget-trigger@)
        v
Cloud Run function wi-hosting-budget-guard   (2nd gen, python312, us-central1)
  identity: wi-hosting-budget-guard@   role: roles/firebasehosting.admin
        |  only when costAmount >= budgetAmount, once per month
        v
Firebase Hosting REST: create a SITE_DISABLE release on site wandering-inn-rpg
```

Why not a native "spend cap budget": those support only the Gemini API,
Vertex AI, Cloud Run and Cloud Run functions, not Firebase Hosting. Why not
"disable billing on the project": it stops every service in the project.

Python, because the core is standard library only (`guard.py`: `urllib` +
the metadata-server token), so the repo's existing `pytest` CI job runs the
tests with no new dependency. The only runtime dependency is
`functions-framework`, pinned with hashes in `requirements.txt` (generated
from `requirements.in` by `uv pip compile --generate-hashes`).

## What the function does with each notification

One structured JSON log line per message, `jsonPayload.decision` is one of:

| decision | meaning | acked? |
|---|---|---|
| `noop_under_budget` | actual spend below the budget amount | yes |
| `disabled` | created the `SITE_DISABLE` release (severity WARNING) | yes |
| `dry_run_would_disable` | over budget, but `DRY_RUN=1`: logged the exact request, called nothing | yes |
| `noop_already_disabled` | over budget; the latest live release is already `SITE_DISABLE` | yes |
| `noop_already_acted_this_period` | over budget; the guard already disabled this month and the site was re-enabled since (the re-enable rule) | yes |
| `ignored_wrong_budget` | `budgetDisplayName`, `billingAccountId` or `budgetId` is not the configured budget | yes |
| `ignored_forecast_only` | only a forecast threshold fired; forecasts never disable | yes |
| `ignored_stale_period` | `costIntervalStart` is not the current month (late report for last month, out-of-order delivery) | yes |
| `ignored_stale_event` | delivery older than `MAX_EVENT_AGE_SECONDS` (default 3600) — the end condition for retries | yes |
| `ignored_malformed` | bad base64 / JSON / missing or non-numeric fields / unknown schema | yes |
| `error_api_refused` | Hosting API answered 4xx (severity ERROR; fix IAM) | yes |
| `error_unexpected` | a bug; logged at ERROR, never retried | yes |
| `retry_transient_error` | Hosting API 429/5xx or network failure | **no** — Pub/Sub redelivers until the event is 1 hour old |

Safety rails, all in code:

- The site and project come from env at deploy time and are checked against
  an allowlist compiled into `guard.py` (`wandering-inn-rpg`,
  `gpt-development`). Any other value — including the default site
  `gpt-development` — makes the container refuse to start, so the deploy
  fails. No environment variable can widen the allowlist.
- The request URL is project-qualified
  (`projects/gpt-development/sites/wandering-inn-rpg/releases`).
- `DRY_RUN` has no default: unset or unparsable refuses to start.
- Only `costAmount >= budgetAmount` on a `SPECIFIED_AMOUNT` budget in the
  current month can disable. Thresholds and forecasts are logged, not used.

### How "once per month" works

The `SITE_DISABLE` release's `message` carries a marker:
`[wi-hosting-budget-guard period=2026-11-01T08:00:00Z gen=1]` (the
notification's `costIntervalStart`, normalised to UTC). Before acting, the
function lists the site's recent releases (up to 500):

1. latest live release is `SITE_DISABLE` -> already off, do nothing;
2. a `SITE_DISABLE` release carrying this period's marker exists -> the guard
   already fired this month and someone re-enabled the site -> do nothing;
3. otherwise disable.

A manual `firebase hosting:disable` carries no marker, so it does not use up
the guard's one shot. A new month has a new marker, so the guard acts again.

`--redisable` (env `REDISABLE_WHILE_OVER_BUDGET=1`, default off) changes rule
2 to "disable again": while the month is over budget the site is turned off
again within hours of every re-enable, and stays unusable until next month or
until you raise the budget amount.

### Re-arming inside the same month

After a re-enable (or after a live test), get the cap back with either:

- raise nothing, bump the marker generation:
  `./deploy.sh --billing-account … --guard-mode armed --marker-generation 2`
  — old markers no longer match, so the next over-budget notification
  disables the site again (if spend is still over the cap, that means within
  hours); or
- raise the cap: `./deploy.sh … --amount 25` — the guard still will not fire
  again this month unless you also bump the generation.

## What "disabled" looks like

- Players see Firebase's **"Site Not Found"** page at
  `https://wandering-inn-rpg.web.app` (the Hosting reference: "Firebase
  Hosting acts as if the site never existed").
- **Saves are unaffected.** They live in each player's browser storage for
  that origin; nothing server-side is deleted, and the uploaded versions stay
  in Hosting. When the site returns on the same URL the saves are still there.
- Preview channels of the site and the project's default site are not
  targeted by the guard.

## Re-enable

A new live release re-enables the site:

1. Preferred: run the **Deploy to Firebase Hosting** workflow
   (`.github/workflows/hosting.yml`, added by PR #655) with `channel: live`.
2. Or roll back to the previous version: Firebase console > Hosting >
   `wandering-inn-rpg` > release history > the last good release > Rollback.
3. Or promote an existing preview channel:
   `firebase hosting:clone wandering-inn-rpg:CHANNEL wandering-inn-rpg:live --project gpt-development`.

Then decide about the rest of the month: by default **the cap is now off
until the 1st** (see the re-enable rule). Re-arm if you want it back.

## Owner steps

Prerequisites: `gcloud` logged in as an account that is Owner of
`gpt-development` and Billing Account Administrator (or Costs Manager) of the
billing account. The scripts never read or change gcloud config; every
command passes `--project gpt-development` / `--billing-project
gpt-development` explicitly.

```sh
cd infra/hosting-budget-guard
export BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX   # the billing account id; not stored in this public repo

# 0. See exactly what would run. Calls nothing.
./deploy.sh --billing-account "$BILLING_ACCOUNT" --guard-mode observe --dry-run

# 1. Deploy in OBSERVE mode (function logs, never disables).
./deploy.sh --billing-account "$BILLING_ACCOUNT" --guard-mode observe

# 2. Test the chain (see Testing).
./test-publish.sh --billing-account "$BILLING_ACCOUNT"

# 3. Arm it.
./deploy.sh --billing-account "$BILLING_ACCOUNT" --guard-mode armed

# Remove everything later:
./teardown.sh --billing-account "$BILLING_ACCOUNT"
```

`deploy.sh` is idempotent (re-run it to change `--amount`, the mode, or the
policy). `--guard-mode` is mandatory so a re-run can never silently arm or
disarm. Options: `--amount USD` (default 10), `--redisable`,
`--marker-generation N`, `--dry-run`.

What `deploy.sh` creates, all in `gpt-development`:

| resource | name |
|---|---|
| APIs enabled (idempotent, never disabled again) | cloudfunctions, run, cloudbuild, artifactregistry, eventarc, pubsub, logging, billingbudgets, firebasehosting |
| Pub/Sub topic | `wi-hosting-budget` |
| service accounts | `wi-hosting-budget-guard@` (runtime), `wi-hosting-budget-trigger@` (trigger) |
| budget on the billing account | `wi-hosting-kill-switch` |
| function + Eventarc trigger + its subscription | `wi-hosting-budget-guard`, `us-central1` |

### IAM, and why

| principal | role | scope | why |
|---|---|---|---|
| `wi-hosting-budget-guard@` (runtime) | `roles/firebasehosting.admin` | project | create/list Hosting releases. **Nothing narrower exists as a predefined role**: Hosting has exactly two, Admin and Viewer, and Viewer cannot create a release. **It is not site-scoped** — Hosting permissions are granted on the project, so this identity could technically act on the default site too. The code allowlist is what pins it to `wandering-inn-rpg`. A custom role with only `firebasehosting.sites.get/list/update` would drop site create/delete; not done here because it is untested. |
| `wi-hosting-budget-trigger@` (trigger) | `roles/run.invoker` | the function's Cloud Run service only | lets Eventarc's push subscription invoke this one service |
| `wi-hosting-budget-trigger@` (trigger) | `roles/eventarc.eventReceiver` | project | required of an Eventarc trigger identity by the Eventarc docs |
| Cloud Billing | Pub/Sub Publisher on the topic | topic | granted automatically when the budget is connected to the topic (which is why the deployer needs `pubsub.topics.setIamPolicy`) |

The runtime identity has no billing, Pub/Sub, Cloud Run, storage or logging
role (stdout logs need none). Builds use the project's default build service
account, as with any `gcloud functions deploy`.

If deliveries fail with 403 in a project whose Pub/Sub service agent predates
April 2021, the Eventarc docs' fix is granting that agent
`roles/iam.serviceAccountTokenCreator`:
`gcloud projects add-iam-policy-binding gpt-development --member=serviceAccount:service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator`
(project number: `gcloud projects describe gpt-development --format='value(projectNumber)'`).
`deploy.sh` does not do this for you.

## Testing

**Unit tests** (no cloud, Hosting API faked) run in CI with the rest of the
Python suites:

```sh
python3 -m pytest -q scripts/tests/test_hosting_budget_guard.py
```

**End-to-end, safe (do this):** with the function in observe mode,
`./test-publish.sh --billing-account …` publishes one synthetic over-budget
notification for the current month and prints the `gcloud logging read`
command. Expect `dry_run_would_disable` with the exact request it would have
sent. `--cost 2` should give `noop_under_budget`. This proves the budget
exists, the topic, trigger, invoker binding, function start-up, config and
parsing. It does not prove the runtime identity can create a release.
`test-publish.sh` refuses to run against an armed function.

**End-to-end, live (optional, deliberate):** the only faithful test of the
last hop is letting the armed function disable the real site.

- **Safe moment: before the first live deploy** (the site then already shows
  "Site Not Found", so a `SITE_DISABLE` release changes nothing a player can
  see), or any time a few minutes of downtime is acceptable. Re-enable is the
  next live deploy.
- **A preview channel is not a safe substitute, and is not offered.** The
  guard only ever targets the site itself; the reference does not say what a
  `SITE_DISABLE` release does on a channel, and adding a channel target just
  for testing would weaken the allowlist that makes this safe.

```sh
./deploy.sh --billing-account … --guard-mode armed
./test-publish.sh --billing-account … --live-yes-disable-the-site
# log shows: disabled, release=…, marker_persisted=true ; the URL shows Site Not Found
# publish again -> noop_already_disabled
# re-enable (live deploy), publish again -> noop_already_acted_this_period
./deploy.sh --billing-account … --guard-mode armed --marker-generation 2   # REQUIRED: re-arm
```

The last line matters: the live test spends this month's one shot. Without
the generation bump the guard stays silent until next month.

Check `marker_persisted` in the `disabled` log line. If it is `false`, the
API did not store the message on the release; the guard then falls back to
"a message-less `SITE_DISABLE` made by my own service account this month",
and `--marker-generation` cannot re-arm — tell the maintainer.

## Cost of the guard itself

Expected: nothing, within always-free allowances (Google Cloud *Free cloud
features*): Cloud Run functions "2 million invocations per month" (this uses
a few a day), Pub/Sub "10 GiB of messages per month" (these are ~300 bytes),
Cloud Build "2,500 build-minutes per month" (one short build per deploy).
The one item that can cost cents: the function's container image in Artifact
Registry ("0.5 GB of storage per month" free, shared with any other images in
the project). None of this is Firebase Hosting spend, so it never counts
toward the cap.

## Verified API shapes

Checked against Google's documentation on 2026-11-27 (document names as
served by the Developer Knowledge API):

- **Disable**: `POST https://firebasehosting.googleapis.com/v1beta1/{parent}/releases`
  with body `{"type": "SITE_DISABLE", "message": "…"}` and no `versionName`
  ("This query parameter must be empty if the `type` field in the request
  body is `SITE_DISABLE`"; `message` "can be up to 512 characters";
  `SITE_DISABLE`: "The release prevents the site from serving content.
  Firebase Hosting acts as if the site never existed.") —
  `firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.releases`,
  `…/sites.releases/create`, `…/sites.channels.releases` (Type enum). The
  `projects/{project}/sites/{site}` parent form is in the API discovery
  document (`projects.sites.releases.create`) and is what `firebase
  hosting:disable` sends (`firebase-tools` `src/commands/hosting-disable.ts`).
- **List**: `GET …/v1beta1/{parent}/releases?pageSize=&pageToken=` ->
  `{releases[], nextPageToken}`; a site listing "includes releases for both
  the default `live` channel and any active preview channels" —
  `…/sites.releases/list`, `…/ListReleasesResponse`.
- **"Site Not Found"**: `firebase.google.com/docs/cli` (`hosting:disable`).
- **Notification format** (attributes `billingAccountId`, `budgetId`,
  `schemaVersion`; data `budgetDisplayName`, `costAmount`,
  `costIntervalStart`, `budgetAmount`, `budgetAmountType`,
  `alertThresholdExceeded`, `forecastThresholdExceeded`, `currencyCode`),
  cadence, at-least-once and out-of-order delivery —
  `docs.cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications`.
- **Budget fields** (`budgetFilter.projects`, `.services`, `.calendarPeriod`,
  `creditTypesTreatment`, `thresholdRules`, `notificationsRule.pubsubTopic`,
  default IAM recipients; periods start at midnight US Pacific) —
  `docs.cloud.google.com/billing/docs/reference/budget/rest/v1/billingAccounts.budgets`;
  flags — `docs.cloud.google.com/sdk/gcloud/reference/billing/budgets/create`
  and `…/update`. A monthly budget "continues to track costs for the first
  two days of the next month" — `docs.cloud.google.com/billing/docs/how-to/budgets`
  (why `ignored_stale_period` exists).
- **Latency quotes** — `docs.cloud.google.com/billing/docs/how-to/disable-billing-with-notifications`,
  `…/billing/docs/how-to/view-history`, `…/billing/docs/how-to/budgets`.
- **Function, trigger, retries** — `docs.cloud.google.com/run/docs/tutorials/pubsub-eventdriven`
  (APIs to enable, `cloud_event.data["message"]["data"]`, trigger identity
  roles, Pub/Sub service agent note), `docs.cloud.google.com/run/docs/tips/function-retries`
  ("Set an end condition to avoid infinite retry loops").
- **Roles** — `docs.cloud.google.com/iam/docs/roles-permissions/firebasehosting`.
- **Free tier** — `docs.cloud.google.com/free/docs/free-cloud-features`.

Budget amounts use gross cost (`--credit-types-treatment=exclude-all-credits`,
the same basis Google requires for native spend caps), so promotional credits
cannot hide Hosting usage from the guard.

## Not verifiable without touching the cloud

Written from the documentation and unit-tested against fakes; none of this
has been run against the real project:

- that `message` is stored on a `SITE_DISABLE` release (the reference does
  not exclude it; there is a fallback, and the live test checks it);
- that `releases.list` returns newest first (the code does not rely on it for
  up to 500 releases; beyond that it disables anyway and logs
  `release_list_truncated`);
- that `roles/firebasehosting.admin` is sufficient for both calls from a
  service account, and that the hashed `requirements.txt` builds on the
  `python312` buildpack;
- how the budget reports during the two-day carry-over at a month boundary;
- the exact output of `gcloud billing budgets describe` used for the
  threshold read-back (a mismatch only prints a warning).

The observe-mode test covers everything up to the last hop; the live test
covers the rest.
