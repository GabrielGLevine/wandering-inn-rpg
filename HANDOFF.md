# Wandering Inn RPG handoff

Current state only. GitHub Issues/Milestones own scheduling; merged PR bodies
own per-issue narrative; `docs/CHOICE-LOG.md` indexes durable rulings; git owns
history. Read through `wi-start-here`.

Insertion: replace current facts in place. Do not add dated `DONE`, archived,
or superseded session blocks.

## Current state

- Latest public release: **v0.19.0**. `main` also contains the post-release
  orphan drain (#429, PR #433): six missing skill/item/content wires are live
  and reachability categories now hard-fail once clean.
- Working tree: **do not discard** the active guidance/documentation bundle.
  It condenses the game `AGENTS.md`, moves detailed mechanisms into
  `wandering_inn_game/docs/ARCHITECTURE-HISTORY.md`, adds the current structural
  map `wandering_inn_game/docs/ARCHITECTURE.md`, makes QA inventories derive
  from `qa/manifest.json`, updates/syncs affected `wi-*` skills, and condenses
  this file plus `docs/CHOICE-LOG.md` with regression guards.
- ACTIVE (2026-08-11, Fable session): #423 art follow-ups — user ordered the
  VISUAL-LOG trio ([Pick Lock] bespoke icon, work-room door sprite,
  shop-right-half dressing). Three PixelLab 16-candidate packs QUEUED on the
  subscription, awaiting review post-usage-reset (get_object inline):
  icon 56d68454-7755-4ded-98ee-dc454770bf2d · door
  babe3af1-1870-4fea-b81d-7027de0be15a · shelf
  3811696a-00c3-467c-8df2-f1dc545917c4. Resume: select primary+alternate per
  pack → icon_pick_lock.png 16x16 (nearest-neighbor from 64) + skills.json
  icon swap → door/shelf sprites.json entries (alpha-bbox anchor,
  render_scale windowed-verified) → work-room door swap + shop dressing rows
  → license-notes verdict append → tick 3 VISUAL-LOG rows → windowed reads
  (both interiors + hotbar) → --touching/smoke/units.
- No other issue implementation lane is recorded as active. The exact next action on
  this tree is to review and commit the housekeeping bundle without dropping
  unrelated edits. `scripts/preflight.sh --full` is green on the composed
  working tree (2026-08-10).
- Open visual debt stays in `docs/VISUAL-LOG.md`. The immediate human-eye items
  are the repainted Coyle & Sons sign and the interim [Pick Lock]/enchanter-shop
  art; they are observations, not blockers on the documentation bundle.

## User-held

- **#432 — balance ruling required:** `next_fight` `pending_meal` effects from
  repeatable produce/use props currently stack without a cap. This predates the
  improvised cudgel and also affects food props. Choose the stacking/reset rule
  before implementation; current behavior remains accepted-on-precedent until
  that issue is ruled.
- **#19 — commercial gate:** any paid Steam path requires pirateaba's explicit
  permission. Free-on-Steam remains the recommended path.

No other open issue is recorded here as waiting on user taste. Visual eye/ear
reads remain in `docs/VISUAL-LOG.md`, where they can be accepted or promoted.

## Queue

The live board is authoritative:

```sh
gh issue list -R GabrielGLevine/wandering-inn-rpg --state open
```

Current open work, grouped by gate rather than guessed priority:

- **Needs ruling:** #432 unbounded `next_fight` stacking.
- **Product work:** #406 prose holdout release/residue drain; #371 v0.20 inn
  visitor scheduling; #348 remaining property-based Skill interactions; #347
  dynamic Class creation.
- **Deferred/environment:** #253 itch/mobile Import Save picker; #140
  intermittent Metal/windowed screenshot corruption; #19 Steam packaging.

When the documentation bundle lands, take the highest-priority unblocked issue
from GitHub. Do not revive completed work from old plans, this file's history,
or the stale narrative portions of `docs/ROADMAP.md`.

## Commands and environment

```sh
# Play
/usr/local/bin/godot --path wandering_inn_game

# Focused canonical QA; seed is owned by qa/manifest.json
wandering_inn_game/qa/run_qa.sh <script> headless

# Primary close gates
python3 scripts/preflight.sh --full
wandering_inn_game/qa/ci_sweep.sh
python3 scripts/sync_agent_guidance.py
python3 scripts/render_qa_notes.py

# Smoke parse
/usr/local/bin/godot --headless --path wandering_inn_game --quit
```

- Engine: Godot **4.7.stable** at `/usr/local/bin/godot`; the 4.6 app is for
  the frozen predecessor only.
- macOS has no `timeout`; shell scripts must remain compatible with Bash 3.2.
- Windowed QA runs serialize. Headless reruns reuse `qa_output/`, so capture or
  inspect windowed evidence before rerunning headless.
- A windowed run may print the known teardown leak/exit noise after
  `QA_RESULT: PASS`; headless warnings still fail verification.
- `potential_assets/` and licensed overlays are local-only and must never be
  committed.

## History lookup

- Completed issue: `gh pr list --state merged`, then `gh pr view <n>`.
- Removed handoff narrative: `git log -p -- HANDOFF.md`.
- Pre-2026-07-05 archive: `docs/archive/HANDOFF-archive-2026-07.md`.
