---
name: wi-shipping
description: Cut a release, manage private asset bundles, run release CI, and deploy the web build to Firebase Hosting.
---

# Ship the public repository safely

The public `wandering-inn-rpg` repository is the working source. The underscored
legacy repository is a private frozen archive and must never become public. The
private assets repository supplies licensed bundle releases and parked source
packs.

Before any release, regenerate the shipped-ID freeze for the intended release
using the existing generator. Reconcile its new IDs with the change set and the
content/shipped-ID tests, including accomplishment literals banked directly by
code and any new producer schema. Once released, IDs are save API and may only
be retired through explicit migration.

If protected assets changed:

1. update `assets_manifest.json` and regenerate its labeled `.gitignore` block;
2. confirm both diffs are tracked and leak check passes;
3. build and inspect the private asset bundle;
4. create the new bundle release in the private assets repository;
5. only then land public references and fallbacks.

Potential-asset releases remain prereleases so they cannot become the “latest”
bundle selected by release automation. The public repository contains only
redistributable files; official builds may overlay redistribution-limited assets.
Never expose API keys or tokens. Keep CI PR jobs secret-free and release secrets
only in the tag-triggered and manually dispatched deploy workflows.

Firebase Hosting is the only deploy target: <https://wandering-inn-rpg.web.app>
(site `wandering-inn-rpg`; never the project's default site). A version tag
runs `release.yml`, which re-runs the full gate with real assets and then
deploys live. `hosting.yml` is manual only: dispatch it with `preview` for a
temporary channel URL to test on a phone, or with `live` to republish without
a tag. Both deploy through `.github/actions/firebase-hosting-deploy`. Browser
saves are per origin, so a preview channel never shows live saves. The web
build bakes licensed assets: it is deployed straight from the runner and must
never become a workflow artifact, a branch, or a commit. `pages.yml` only
publishes the redirect from the retired GitHub Pages address. itch.io left the
deploy train on 2026-11-27; nothing pushes there. Roll back a bad live deploy
from the Firebase console's release history; that is outward-facing like any
other deploy.

Run the full current-tree verification contract with the real overlay, including
leak check, preflight/full units, canonical sweep, balance/parity routes required
by the change, and windowed/player evidence. Verify release workflow inputs,
asset release selection, export settings, target Hosting site, and current tool
versions from source rather than copied historic values.

Tagging, pushing, creating releases, and Hosting deployment are outward-facing and
require user authorization unless the user already explicitly authorized this
release. Prepare the exact version, commits, bundle, checks, release notes, and
commands first. After authorization, create/push the tag, watch the release job
to completion, inspect the published build, and record the durable release in
the PR/release while keeping `HANDOFF.md` current-state only.

Use `wi-handling-prs` for external contributions and `wi-verifying-changes` for
the evidence contract. Read the workflow files and existing release scripts for
exact commands; they are authoritative over this procedure.
