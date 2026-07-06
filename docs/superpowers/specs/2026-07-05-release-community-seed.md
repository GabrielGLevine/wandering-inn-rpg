# M-RELEASE — Packaging, Deployment & Community (SEED)

> **SUPERSEDED 2026-07-05** by `2026-07-05-release-community-design.md` —
> all ⚑ calls ratified by the user. Kept for the decision trail.

Status: SEED (user direction 2026-07-05, capturing input + controller
recommendations). Full brainstorm NEEDS THE USER (license/policy calls
marked ⚑). Slots after Three Pillars per the ladder. Extends the standing
open-source track (ROADMAP 2026-07-03: asset-license audit = the gate).

## 1. User direction (verbatim intent)

Open-source project; CI tests/builds/deploys on user-approved third-party
PRs; community-driven at ALL levels — technical PRs AND non-technical
contribution (quest ideas via a form evaluated + planned by Opus; art/music
contributions with concrete guidelines); web save-state question open;
non-redistributable packs (Pixel Crawler et al.) must be protected.

## 2. CI/CD (controller recommendation)

- **The QA suite IS the CI** — the entire canonical sweep runs headless
  already (`run_qa.sh`, units, harness, web parity). GitHub Actions:
  PR → full gate (Godot 4.7 headless container) → user review/approval →
  merge → wasm build → deploy (itch.io butler push or Pages).
- Deploy gate = user approval on the PR (their stated model) — no
  auto-deploy from unreviewed code. Secrets (deploy keys, asset bundle
  access) never exposed to fork PRs (use pull_request, not
  pull_request_target, for the test stage; deploy only from main).

## 3. Web saves (recommendation: browser-local, no accounts)

- Godot wasm persists `user://` to IndexedDB — saves ALREADY survive
  browser sessions per-browser/per-device for free. Recommend: ship that,
  document "saves live in your browser," NO accounts/server state for the
  demo. ⚑ confirm.
- Server-side per-user state = accounts+backend+privacy surface; defer
  unless the demo's reception demands it.

## 4. Protected assets (the hard requirement)

- Public repo ships ONLY redistributable assets (the audit's SHIP-OK set:
  user-attested packs w/ redistribution rights, generated FX, commissioned/
  AI-gen). Pixel Crawler + any no-redistribution pack: **excluded from git
  history entirely** (they're currently in `assets/` as curated extracts —
  ⚑ AUDIT ITEM: which shipped extracts derive from non-redistributable
  packs? The extraction may already be a violation for a PUBLIC repo —
  must be resolved BEFORE any public push; this is the standing gate).
- Mechanism options (pick at brainstorm): (a) private asset bundle repo/
  release artifact, CI fetches with a secret, public contributors build
  against FALLBACK art (the chip/placeholder pipeline ALREADY EXISTS —
  sprite registry falls back gracefully); (b) buy-your-own-pack + import
  script (itch links + a mapping manifest); (c) replace non-redistributable
  extracts with AI-gen/commissioned equivalents over time (the standing
  art strategy already points here). Recommend (a) short-term + (c)
  long-term. ⚑
- History scrub check: if any non-redistributable asset was EVER committed,
  the public repo needs a fresh history or a rewrite. (`assets/` extracts
  are committed today — this likely forces a curated re-init or
  filter-repo pass. Plan for it.)

## 5. Community contribution (three lanes)

- **Technical PRs**: CONTRIBUTING.md (build/run/QA loop as the front door —
  the QA-first architecture is the contributor's safety net and the
  reviewer's gate), LICENSE (⚑ code license: MIT/Apache-2 vs copyleft),
  code of conduct, PR template requiring the gate green + windowed shots
  for player-visible changes (our own machine's rules, publicized).
- **Non-technical content (the form→Opus pipeline)**: GitHub Issue Forms
  (structured templates: quest idea / dialogue script / skill interaction /
  map suggestion — fields for scope, canon refs, one-liner-to-full-spec
  range). An Opus workflow triages: viability check against canon +
  three-pillars balance + scope guard, then either drafts a spec/plan
  (the existing brainstorm→plan machine, seeded from the submission) or
  responds with what's needed. Example submission from the user:
  "The player goes with the Rags tribe to eliminate a mothbear infestation"
  — exactly the granularity the triage should accept. ⚑ moderation/canon
  authority model (who approves lore: user).
- **Art/music contributions**: CONTRIBUTING-ASSETS.md with the REAL specs
  from our pipeline: tiles 16px-native (sheets on a 16px grid), character
  sheets 64px frames w/ measured feet-plane anchors (the anchor gotcha,
  documented for contributors), directional layout conventions, palette
  guidance per the direction cards, music loopable-from-0 OGG, SFX specs;
  license-in requirement (contributions must grant redistribution — ⚑ CLA
  vs DCO vs CC-BY requirement).

## 6. Open questions for the brainstorm (all ⚑)

1. Code license; asset license-in policy (CLA/DCO/CC).
2. Web saves: confirm browser-local-only for demo.
3. Asset mechanism (a/b/c above) + the history-scrub decision.
4. Hosting: itch.io only vs +Pages; repo host = GitHub (assumed — Actions
   + Issue Forms + the Opus triage all lean on it).
5. The Opus triage workflow's runtime (Actions-hosted claude session vs
   scheduled cloud agent vs manual dispatch) + its authority bounds.
6. Community cadence: who merges, release rhythm, versioning.

## 7. Sequencing

Ladder: Onboarding rev → Three Pillars → **M-RELEASE brainstorm (user) →
spec → plan → execute**. The asset audit (§4) can START EARLIER as a
background task — it gates everything and touches no code.
