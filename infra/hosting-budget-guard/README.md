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
- **Anyone who can publish to the topic can take the site down.** The
  function trusts any well-formed message on `wi-hosting-budget` whose
  display name, `billingAccountId` and `budgetId` match, and none of those
  is a secret (the budget id appears in logs and in `gcloud billing budgets
  list`; the billing account id is visible to every billing viewer). So
  every principal with `pubsub.topics.publish` on the topic **or on the
  project** — project Owners/Editors, `roles/pubsub.publisher` or
  `roles/pubsub.editor` holders, *and the project's other service accounts
  that hold such roles for unrelated production work* — can publish a fake
  over-budget notification and disable the site (once per month by default).
  Likewise any holder of project-level `roles/run.invoker` may invoke the
  function's service; `--ingress-settings=internal-only` (set by
  `deploy.sh`) limits that to callers inside the project's network
  perimeter, it does not remove it. The damage is bounded (the site goes
  offline, nothing is deleted, a rollback restores it), but treat those
  project roles as "can turn the game off".

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
Cloud Run function wi-hosting-budget-guard   (2nd gen, python312, us-central1,
  identity: wi-hosting-budget-guard@             ingress internal-only)
  role: roles/firebasehosting.admin    built by: wi-hosting-budget-build@
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
`functions-framework` (plus the `tzdata` wheel, so the Pacific-time period
maths never depends on the base image), pinned with hashes in
`requirements.txt` (generated from `requirements.in` by `uv pip compile
--generate-hashes`).

## What the function does with each notification

One structured JSON log line per message, `jsonPayload.decision` is one of:

| decision | meaning | acked? |
|---|---|---|
| `noop_under_budget` | actual spend below the budget amount | yes |
| `disabled` | created the `SITE_DISABLE` release (severity WARNING; ERROR with `marker_persisted=false`) | yes |
| `dry_run_would_disable` | over budget, but `DRY_RUN=1`: logged the exact request, called nothing | yes |
| `noop_already_disabled` | over budget; the live channel's current release (`Channel.release`) is already `SITE_DISABLE` | yes |
| `noop_already_acted_this_period` | over budget; the guard already disabled this month and the site was re-enabled since (the re-enable rule) | yes |
| `noop_cannot_tell_if_acted` | over budget, but the guard cannot tell whether it already acted this month (see below); it stays up. Severity ERROR | yes |
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
`[wi-hosting-budget-guard period=2026-11-01T07:00:00Z gen=1]`. The period is
the budget month containing `costIntervalStart`, computed with `zoneinfo`
in `America/Los_Angeles` (budget months start at midnight US Pacific on the
1st), written in UTC: `07:00Z` for a month that starts in PDT (April–
November), `08:00Z` for one that starts in PST (December–March). The month's
end is computed the same way, so March is 743 hours and November 721.

Before acting, the function reads only the site's **live channel**:

1. `GET sites/wandering-inn-rpg/channels/live` — if the channel's current
   release (`Channel.release`) is `SITE_DISABLE`, the site is already off:
   do nothing;
2. page through `GET sites/wandering-inn-rpg/channels/live/releases` (all
   pages, up to 20 × 100; the reference documents no ordering, so nothing
   assumes newest-first). Preview-channel deploys are not in this listing,
   so they cannot push the marker out of view. If a `SITE_DISABLE` release
   carries this period's marker, the guard already fired this month and
   someone re-enabled the site: do nothing;
3. otherwise disable.

**When it cannot tell, it stays up.** If a message-less `SITE_DISABLE`
release this month has no `releaseUser.email` (or no `releaseTime`), or
`GUARD_SERVICE_ACCOUNT` is unset, or the listing hit the 2 000-release cap
without finding the marker, the guard cannot know whether it already acted.
It then logs `noop_cannot_tell_if_acted` at ERROR and does **not** disable:
a false "never acted" would undo every owner re-enable within hours, which
is worse than missing a second disable in a month where the site already
went down once. `--redisable` overrides this (it disables regardless).

**The `releaseUser` fallback.** The reference does not promise that
`message` is stored on a `SITE_DISABLE` release. If it is not, the only
evidence left is the release's `releaseUser.email`: a message-less
`SITE_DISABLE` this month whose `releaseUser.email` equals the guard's
runtime service account counts as the guard's. That is why the `disabled`
log line reports `marker_persisted`; when it is `false` the line is logged
at **ERROR**, the once-per-month rule rests on `releaseUser` alone, and
`--marker-generation` cannot re-arm. Fix that before relying on the guard.

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

Any new release on the live channel that serves a version re-enables the
site. Fast path first:

1. **Roll back to the previous release (minutes, no rebuild).** Firebase
   console > Hosting & Serverless > Hosting > site `wandering-inn-rpg` >
   Release history > hover the last good release (the one before the
   `SITE_DISABLE`) > ⋮ > **Roll back**. Rolling back "create[s] a new
   release that serves the same version of content as a previous release".
   CLI equivalent (no rollback command exists; clone that release's version
   onto `live` — the version id is in the same Release history row):

   ```sh
   firebase hosting:clone wandering-inn-rpg@VERSION_ID wandering-inn-rpg:live --project gpt-development
   ```

   `hosting:clone` takes the site in its arguments, not as `--site`. To
   promote a preview channel instead:
   `firebase hosting:clone wandering-inn-rpg:CHANNEL_ID wandering-inn-rpg:live --project gpt-development`.
2. **Full redeploy (slow).** Run the **Deploy to Firebase Hosting** workflow
   (`.github/workflows/hosting.yml`) with `channel: live`. It runs in the
   `hosting` GitHub environment, so it waits for that environment's
   reviewer to approve, then rebuilds the web export from scratch (job
   timeout 60 minutes). Use it when the previous release is not one you
   want back.

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
| service accounts | `wi-hosting-budget-guard@` (runtime), `wi-hosting-budget-trigger@` (trigger), `wi-hosting-budget-build@` (Cloud Build) |
| budget on the billing account | `wi-hosting-kill-switch` |
| function + Eventarc trigger + its subscription | `wi-hosting-budget-guard`, `us-central1` |

**Ownership marker.** Everything `deploy.sh` creates is marked
`managed-by=wi-hosting-budget-guard`: a label on the topic and the function,
`[managed-by=wi-hosting-budget-guard]` in each service account's description
(service accounts have no labels), and for the budget (no labels either) the
fact that it publishes to `projects/gpt-development/topics/wi-hosting-budget`.
If a resource with one of these names already exists **without** the marker,
`deploy.sh` stops instead of adopting it, and `teardown.sh` leaves it alone,
deletes only marked resources, and exits non-zero listing what it refused.
`find_budget` matches the display name exactly and fails if more than one
budget has it, rather than picking one.

### IAM, and why

| principal | role | scope | why |
|---|---|---|---|
| `wi-hosting-budget-guard@` (runtime) | `roles/firebasehosting.admin` | project | create/list Hosting releases. **Nothing narrower exists as a predefined role**: Hosting has exactly two, Admin and Viewer, and Viewer cannot create a release. **It is not site-scoped** — Hosting permissions are granted on the project, so this identity could technically act on the default site too. The code allowlist is what pins it to `wandering-inn-rpg`. A custom role with only `firebasehosting.sites.get/list/update` would drop site create/delete; not done here because it is untested. |
| `wi-hosting-budget-trigger@` (trigger) | `roles/run.invoker` | the function's Cloud Run service only | lets Eventarc's push subscription invoke this one service |
| `wi-hosting-budget-trigger@` (trigger) | `roles/eventarc.eventReceiver` | project | required of an Eventarc trigger identity by the Eventarc docs |
| `wi-hosting-budget-build@` (build) | `roles/logging.logWriter` | project | "Required to store build logs in Cloud Logging" |
| `wi-hosting-budget-build@` (build) | `roles/artifactregistry.writer` | project | "Required to store build images in Artifact Registry" (`gcf-artifacts`); project-wide as in the docs' own command, so it could push to other repositories in the project — it is only ever used by this function's builds |
| `wi-hosting-budget-build@` (build) | `roles/storage.objectViewer` | project, **conditioned** to objects in `gcf-v2-sources-*`, `gcf-v2-uploads-*`, `run-sources-*` | "Required to retrieve the function source"; the condition is the one the docs give |
| Cloud Billing | Pub/Sub Publisher on the topic | topic | granted automatically when the budget is connected to the topic (which is why the deployer needs `pubsub.topics.setIamPolicy`) |

The runtime identity has no billing, Pub/Sub, Cloud Run, storage or logging
role (stdout logs need none). Builds do **not** use the project's default
build account (often Editor in a project with unrelated production
services): `deploy.sh` passes
`--build-service-account=projects/gpt-development/serviceAccounts/wi-hosting-budget-build@…`
and that account has exactly the three roles the Cloud Run functions
*building* docs list for a custom build service account (Provide a service
account for building functions). The function is deployed with
`--ingress-settings=internal-only`: Cloud Run's "Internal" ingress still
admits Eventarc and Pub/Sub subscriptions in the same project, so the
trigger keeps working, while requests from the internet get a 404.

If deliveries fail with 403 in a project whose Pub/Sub service agent predates
April 2021, the Eventarc docs' fix is granting that agent
`roles/iam.serviceAccountTokenCreator`:
`gcloud projects add-iam-policy-binding gpt-development --member=serviceAccount:service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator`
(project number: `gcloud projects describe gpt-development --format='value(projectNumber)'`).
`deploy.sh` does not do this for you.

## Testing

**Unit tests** (no cloud, Hosting API and `gcloud` faked; the three
entry-point tests skip without `functions-framework`) run in CI with the
rest of the Python suites:

```sh
python3 -m pytest -q scripts/tests/test_hosting_budget_guard.py
```

**End-to-end, safe (do this):** with the function in observe mode,
`./test-publish.sh --billing-account …` publishes one synthetic over-budget
notification for the current month (its `costIntervalStart` comes from
`python3 guard.py period-start`, the same Pacific-time code the function
uses, so it matches what real notifications produce) and prints the `gcloud logging read`
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
# re-enable (roll back, see Re-enable), publish again -> noop_already_acted_this_period
./deploy.sh --billing-account … --guard-mode armed --marker-generation 2   # REQUIRED: re-arm
```

The last line matters: the live test spends this month's one shot. Without
the generation bump the guard stays silent until next month.

Check `marker_persisted` in the `disabled` log line. If it is `false` (the
line is then severity ERROR), the API did not store the message on the
release; the guard then falls back to `releaseUser.email` (see "How once
per month works"), `--marker-generation` cannot re-arm, and if
`releaseUser` is missing too the guard will log `noop_cannot_tell_if_acted`
and never disable again this month — tell the maintainer.

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
- **Live channel**: `GET …/v1beta1/sites/{site}/channels/live` -> `Channel`
  whose `release` is "The current release for the channel, if any" —
  `firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.channels`.
- **List**: `GET …/v1beta1/sites/{site}/channels/live/releases?pageSize=&pageToken=`
  (`{parent=sites/*/channels/*}`; `pageSize` default 100) ->
  `{releases[], nextPageToken}` — `…/sites.channels.releases/list`,
  `…/ListReleasesResponse`. Neither page documents an ordering. Listing the
  site instead "includes releases for both the default live channel and any
  active preview channels", which is why the guard lists the channel. The
  reference shows only the `sites/…` form for channel reads (not a
  `projects/…/sites/…` one), so reads use it; the disabling POST keeps the
  project-qualified parent.
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
- **Build service account** (three roles, the source-bucket condition,
  `--build-service-account` format `projects/{project}/serviceAccounts/{email}`)
  — `docs.cloud.google.com/functions/docs/building` ("Provide a service
  account for building functions"), `docs.cloud.google.com/sdk/gcloud/reference/functions/deploy`.
- **Ingress** (`--ingress-settings` `all|internal-only|internal-and-gclb`;
  "Internal" admits Eventarc and Pub/Sub subscriptions in the same project)
  — `docs.cloud.google.com/sdk/gcloud/reference/functions/deploy`,
  `docs.cloud.google.com/run/docs/securing/ingress`.
- **Rollback / clone** — `firebase.google.com/docs/hosting/manage-hosting-resources`
  ("Roll back to a previous version of your site", `hosting:clone`),
  `firebase.google.com/docs/cli` (`hosting:clone SITE@VERSION_ID SITE:CHANNEL`).
- **Free tier** — `docs.cloud.google.com/free/docs/free-cloud-features`.

Budget amounts use gross cost (`--credit-types-treatment=exclude-all-credits`,
the same basis Google requires for native spend caps), so promotional credits
cannot hide Hosting usage from the guard.

## Not verifiable without touching the cloud

Written from the documentation and unit-tested against fakes; none of this
has been run against the real project:

- that `message` is stored on a `SITE_DISABLE` release (the reference does
  not exclude it; there is a fallback, and the live test checks it);
- that `releaseUser.email` on a release made by the function equals its
  runtime service account (the fallback when `message` is not stored);
- that the live-channel listing returns every release still on record (the
  code reads all pages and assumes no order; past 2 000 it stays up and logs
  `noop_cannot_tell_if_acted`);
- that the build succeeds with only the dedicated build account's three
  roles, and that the conditional `storage.objectViewer` binding parses as
  written (`deploy.sh` step 4);
- that `roles/firebasehosting.admin` is sufficient for both calls from a
  service account, and that the hashed `requirements.txt` builds on the
  `python312` buildpack;
- how the budget reports during the two-day carry-over at a month boundary;
- the exact output of `gcloud billing budgets describe` used for the
  threshold read-back (a mismatch only prints a warning).

The observe-mode test covers everything up to the last hop; the live test
covers the rest.
