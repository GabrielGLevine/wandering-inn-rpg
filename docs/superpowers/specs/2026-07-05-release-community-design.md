# M-RELEASE — Packaging, Deployment & Community (DESIGN)

Status: user-ratified 2026-07-05 (all eight ⚑ calls answered via structured
brainstorm). Supersedes the SEED doc (`2026-07-05-release-community-seed.md`
— kept for the decision trail). One external gate remains open: the
**asset-redistribution audit** (running as a background task; report lands at
`.superpowers/sdd/fp-handoff/release-asset-audit.md`) — it fills in the
protected-asset manifest and the history-scrub scope, and it BLOCKS the
public push (R6) only, not the build-out (R1–R5).

## 1. Ratified decisions (2026-07-05)

| # | Question | Decision |
|---|----------|----------|
| 1 | Code license | **MIT** (matches Godot + the in-tree godot-ai addon) |
| 2 | Web saves | **Browser-local only** for the demo — Godot wasm's free `user://`→IndexedDB persistence; documented "saves live in your browser"; no accounts/backend |
| 3 | Asset mechanism | **(a) private bundle + fallback art** short-term, **(c) replace over time** long-term; **fresh-history public re-init** (not filter-repo on this repo) |
| 4 | License-in | **DCO** sign-off for code; **CONTRIBUTING-ASSETS requires CC-BY-4.0 or MIT grant** on submitted art/music |
| 5 | Opus triage | **GitHub Action fired by a user-applied `triage` label; drafts only** — user gates every run and every lore call |
| 6 | Hosting | **itch.io (butler) + GitHub**; Pages mirror deferred |
| 7 | Merge/release | **User is sole merger; deploy fires on version tag push (`v0.x.y`)**, not per-merge |
| 8 | (Adjacent, decided same session) Parley warrior-gate | KEEP — recorded here because it was ratified in the same batch; belongs to Onboarding rev |

## 2. Architecture overview

Two repos, one pipeline:

- **Public repo** (fresh-history re-init of this project's SHIP-OK subset):
  code, data, redistributable assets, QA suite, workflows, community docs.
  A public checkout **boots and passes the full QA gate with fallback art**
  — the sprite-registry chip/placeholder pipeline is the contract that makes
  open-source contribution possible without the protected assets.
- **Private assets repo** (or private release artifact): the
  non-redistributable curated extracts, laid out to overlay
  `wandering_inn_game_v4/assets/`. Only the release workflow (tag push, main
  repo, never fork PRs) fetches it via a repo secret.

Pipeline: PR → `ci.yml` full QA gate (no secrets, `pull_request` event) →
user review/approval → merge → (batching at user's discretion) → user pushes
`v0.x.y` tag → `release.yml` fetches private bundle → wasm export → butler
push to itch.io.

## 3. CI (`ci.yml`) — the QA suite IS the CI

- Trigger: `pull_request` (NOT `pull_request_target`) + `push` to main. No
  secrets exposed to the test stage — fork-PR-safe by construction.
- Container: Godot **4.7** headless (pinned image, e.g. `barichello/godot-ci`
  line or an explicit engine-download step — pin the exact 4.7 build; engine
  drift has bitten this project before).
- Stages: (1) headless parse/smoke `--quit`; (2) unit suites; (3) the full
  canonical script sweep at pinned seeds via `qa/run_qa.sh`, grep discipline
  (`SCRIPT ERROR|Parse Error|WARNING`, game_helper line exempt) enforced in
  the workflow, per-script alarm timeouts; (4) web-parity script.
- The sweep runs against **fallback art** (no private bundle in CI) — QA
  scripts assert events/state, not pixels, so this holds by design; R2
  proves it.
- DCO check (`dco` bot or the `app/dco` GitHub app) required on PRs.

## 4. Release (`release.yml`)

- Trigger: push of tag matching `v*` (user-only by branch/tag protection).
- Steps: checkout → fetch private asset bundle (secret token; job skips
  gracefully with a loud failure if secret absent) → overlay assets → full
  QA gate re-run (release must be green WITH real assets too) → Godot wasm
  export (4.7 export templates pinned) → `butler push` to the itch project
  (`ITCH_API_KEY` secret) with the version tag as the channel version.
- itch project config: HTML5 playable. R3 as-built kept the existing web
  preset's `thread_support=false` (single-threaded wasm — runs on itch
  WITHOUT the SharedArrayBuffer toggle, and the CI web-parity runner
  depends on the non-COOP/COEP serving path). Flipping to threaded later
  is a documented coupled 3-part change (preset + itch toggle + parity
  runner), in the R3 report.
- Saves: document on the itch page + in-game title screen footnote — "saves
  live in this browser on this device."

## 5. Protected assets + fresh-history re-init

- The audit report enumerates: per-pack redistribution verdicts, every
  ever-committed asset path, FORBIDDEN set, fallback coverage. Its output
  becomes `assets_manifest.json` (or equivalent): each protected path +
  which bundle provides it + fallback behavior.
- **Fresh-history re-init** (decision 3): the public repo starts at commit
  one from a curated export of the current tree minus FORBIDDEN assets minus
  history. This repo stays private as the archival history. No filter-repo
  archaeology on a repo whose entire history predates the split.
- Long-term lane (c): the standing art strategy (AI-gen/commissioned
  replacements) retires bundle entries over time; the manifest shrinks
  toward empty.
- NEW STANDING RULE from public day one: nothing lands in
  `wandering_inn_game_v4/assets/` without a redistribution-clean license
  trail (CONTRIBUTING-ASSETS enforces inbound; the audit's verdict table is
  the precedent list).

## 6. Community lanes

1. **Technical PRs**: `LICENSE` (MIT), `CONTRIBUTING.md` (build/run,
   the QA loop as the front door: "your PR must pass the gate; here's how to
   run it locally", windowed-shot requirement for player-visible changes,
   DCO sign-off), `CODE_OF_CONDUCT.md` (Contributor Covenant), PR template
   mirroring our own machine's rules.
2. **Quest/content form → Opus triage**: GitHub Issue Forms (quest idea /
   dialogue script / skill interaction / map suggestion; fields: one-liner,
   scope guess, canon refs). User applies `triage` label → Action runs a
   Claude (Opus) session with a triage prompt: viability vs canon + three
   pillars + scope guard → posts EITHER a draft spec comment (brainstorm-
   format, ready to enter the spec→plan machine) OR a what's-missing
   comment. Drafts only; user approves all lore; label-gating caps cost and
   spam by construction.
3. **Art/music**: `CONTRIBUTING-ASSETS.md` with the REAL pipeline specs:
   16px-native tiles on a 16px grid; 64px character frames with measured
   feet-plane anchors (the anchor gotcha documented); directional layout
   conventions; palette guidance per the map direction cards; music
   loopable-from-0 OGG; SFX conventions; license-in requirement (CC-BY-4.0
   or MIT, stated in the PR).

## 6b. Audit corrections (2026-07-05, report landed)

The audit (`.superpowers/sdd/fp-handoff/release-asset-audit.md`) corrected
three assumptions in this spec:

1. **There is no runtime art fallback today.** `WISpriteRegistry`
   hard-asserts on a missing sheet; only 17 procedurally-drawn skill icons
   degrade gracefully. The "public checkout builds against fallback art"
   contract is NEW registry-level scope — R2 grows from "prove the
   contract" to "BUILD the fallback path (registry renders a legible
   placeholder chip instead of asserting when a sheet is absent), then
   prove it."
2. **The FORBIDDEN set is the visual backbone**: Pixel Crawler sub-packs
   (PC/Erin sprites, inn tiles/props), xDeviruchi music (license PDF
   forbids redistribution — the repo's own 2026-07-02 verdict flagged
   this), Minifantasy SFX. Fallback mode will therefore be visually
   spartan; that's accepted for the contributor path (long-term lane (c)
   replaces the backbone over time).
3. **Seven packs need explicit user re-attestation at the public-repo
   bar** (shipping a built game ≠ redistributing sources): goblin-pack
   family, Bat_Fur, topdown_floor_tiles_12, Tiny Swords (no terms files);
   Admurin's Freebies (no-standalone-redistribution + no-AI-training
   clauses); PixelLab Relc output (ToS unverified). Queued in HANDOFF.

Confirmed: fresh-history re-init (343 commits, forbidden blobs throughout
history; v1 assets also unverifiable) — ratified decision 3 stands.
Additional ⚑ for R6: **pirateaba's fan-works policy** must be checked and
satisfied before any public push (non-commercial fan project framing is
already baked into README/LICENSE/CONTRIBUTING).

## 7. Testing & failure modes

- R2's proof: clean public-shaped checkout (protected assets deleted) →
  boot + full sweep green + windowed boot shot showing fallback chips. That
  test becomes a CI job ONLY in the public repo (it's the public repo's
  native state).
- Fork-PR secret safety: test stage uses `pull_request`; deploy exists only
  in `release.yml` on tags; tag protection = user-only. Reviewed at RF.
- Butler/itch failure: release job is re-runnable from the same tag;
  no partial-deploy state (butler push is atomic per channel).
- Triage Action failure/spam: label-gated = no unsolicited runs; a bad
  draft is just a comment — user deletes/ignores.

## 8. Sequencing & concurrency

Build-out (R1–R5) is **concurrency-safe with the Onboarding/Three-Pillars
lanes** (new files only: workflows, docs, manifest; zero overlap with
qa/scripts or game code) — EXCEPT R2's validation sweep, which must run at a
moment the canonical suite is stable (post-O5). The public push (R6) is
LAST, audit-gated + user-gated, after Three Pillars per the ladder.
