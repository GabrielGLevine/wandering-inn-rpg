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
- DONE (2026-08-11, Fable session): #423 art follow-ups SHIPPED — bespoke
  `icon_pick_lock` (16x16, live on the hotbar, verified legible + distinct
  from rogue-line siblings), `door_locked_heavy` on the work-room door
  (window-read defect closed; one P4 residual row: unoccluded in-scene
  read pending), `enchanter_stock_shelf` (8,1) + `enchanter_vial_case`
  (10,1) fill the sparse right half. Gates: --touching 214/214, smoke
  14/14, test_sprite_registry PASS (4 new frame-count rows), data_lint
  rc 0, import pass done. License verdict appended (license-notes,
  local). Alternates parked server-side (tags pick-lock-icon /
  workroom-door / enchanter-shelf).
- DONE (2026-08-12, Fable session): **balance program complete** (#434 is
  the one open engine piece). Shipped across three waves: oracle/
  fail-fast/checkpoints (#436/#435), dual-policy sim table + calibration
  (#437), Acts I-III retunes into the [0.55,0.85] window + 8 canonical
  re-fixtures (#439/#441), warden chokepoint (#440: wakes every descent,
  endings post-fight, sneak = ambush edge), [Second Wind] once_per_fight
  (#442), competent-policy survive amendments (hit-aware potential_damage,
  largest-heal-wins, death-band second action). Steel thread REAUTHORED
  and GREEN at band: 2567 steps, seed 9, x3 verified (events 10995/11000/
  10995), warden falls in 9 rounds with every resource spent (PC 2/47).
  Filed for the user: #448 (Relc veto trap choice), #449 (evolution
  orphans consolidation — end-to-end evidence in the run), plus two #439
  follow-ups recorded on #449 (dilution-stated bands; 4g finale economy).
  #451 parked by user (Counter Strike power level, ablation data attached). Pre-existing red still open: d3_inventory_shot (inventory pin drift,
  predates the program). Windowed observation run launched for the user.
- RESUME STATE (2026-08-12 late; agent drain states live in this
  session's task outputs): (0) derived-spines fix PR #461 (branch
  fix/derived-spines-exempt, e986c519, fully proven) — merge on CI green;
  same-shape follow-up: calibration-failure assert-then-quit at
  sim_spine_viability ~line 650 hangs to watchdog, fold into B2
  completion. (1) B2 branch: rebased clean onto post-C main (6bf43e6a +
  WIP 2524b91d; safety ref backup/b2-pre-rebase-bf8eeb92); REMAINING:
  wire 3 Tactician BUILDS rows into ROSTER (seal_warden_alcove,
  act5_seal_warden_amulet precedent), WI_SPINE_WRITE=1 measure, all
  Task-3 gates incl. steel_thread --seed=37, then PR+merge. (2) d3
  branch fix/d3-inventory-shot 45d66479 (#79 root cause + manifest
  promotion): verification runs pending (headless x2, preflight, 5
  inventory canonicals; step 10 = windowed-only coin shot). (3) E6 #459:
  resume at PixelLab submission; recon in task output ab97218de87e63227
  (sheet-share + side-profile traps; renderer at world.gd:2100 /
  _play_player_anim:1777; registry rows 247/505/506; balance healthy).
  Max 2 concurrent Opus agents. `timeout` not on PATH — perl alarm idiom.
- WAVE >=434 (plan: docs/superpowers/plans/2026-08-12-sol-wave-434-plus.md;
  rulings: CHOICE-LOG SS Sol wave >=434). MERGED: #454 B1 validator
  (26-pair inventory on #452 awaits user naming), #455 E3 aura (user
  eye-gate via qa/playtest_saves/2026-08-12-446-dangersense-aura/),
  #457 A-M1 compiler, #456 full Lane C (cap + harness probe + window
  repair + matrix re-derivation + report-only ladder + 13 canonical
  re-fixtures). E1 green on its branch (50a4a4b8) — after B2 merges:
  rebase, re-derive its 2 QA hunks vs the seed-37 thread, PR, windowed
  facade read. QUEUE after B2: E5 #458 (wi_game.gd), E4 #447 (after E1),
  C2 #448 + C3, B3 #449 (wiki-verify name) + B4 (after sim file
  settles), E2 verify-only, Lane D last. All implementation via Opus
  subagents (Codex dry); Fable gates only. USER-ASK BATCH: 26 orphan
  names; Coyle bounty re-arm; WALL list (Innkeeper I-V, Scout I-V,
  Ranger x4, Druid I/IV + ceiling drift) + 8 t3_warrior10
  competent-floor cells; ladder stop-order (both policies non-monotone
  post-cap); cisterns 0.64 / arc_flow 0.55 band-top headroom; oracle
  dispatch duplication; #454 squash carried 41-commit backlog (granular
  history on main-pre-454-archive).
- QUEUED: **#452 codify #347** (user-directed 2026-08-12): lineage-
  completeness validator (build FIRST — inventories all orphaned pairs,
  protects main at commit time), consolidation scaffolder, doctrine
  ratification (spec EXPLORATION->RATIFIED needs user go), skill-library
  method section, sim-roster derivation. #449's [Spellspear] = the
  validator's first satisfied row + scaffolder golden.
- QUEUED: **#434 itinerary compiler — DESIGN COMPLETE** (user-directed
  Fable frontload 2026-08-12): full engine design at
  wandering_inn_game/docs/design/itinerary-compiler-design.md + #434
  comment. Four lane-sized milestones (M1 spine → M4 Mage variant);
  implementation is delegable cold. Dispatch M1 when usage allows.
- QUEUED: **playthrough engine** (#438 tracking; #436 oracle → #435
  checkpoints → #437 pre-sim → #434 itinerary compiler; all knowledge
  embedded in the issues + the wi-writing-qa-scripts lessons section).
  Acceptance milestone: Mage-focused steel-thread variant as an
  itinerary diff. Pieces 1-3 are hour-scale and Codex/Opus-delegable;
  #434 is day-scale (Fable specs, Sol implements per doctrine).
- DONE (2026-08-11, Fable session): **continuous steel thread rebuilt and
  merged** (`ceefd357` + follow-ups on main). One PC, title → epilogue,
  true act order, zero install_fixture/teleport (grep-gated), 2448 steps,
  seed 9, headless ~55s ×2 green, windowed observation run completed
  green (72 captures, 14-line epilogue). Companion ruling shipped: worn-
  accessory abilities are known while worn (known_skills fold + field-bar
  re-render on equip + honest effect-text qualifier; sim_core/effect_text
  pins and data_lint code-grant anchors repinned). Findings ledger for
  the user's pacing/reachability debrief:
  `wandering_inn_game/docs/design/steel-thread-route-spec.md` (warden
  wall + autoplay competence gap, Act III XP lump, Act IV economy
  squeeze, Diplomat load-bearing, alleys need [Stealth]). Known
  pre-existing red, NOT this wave's: `d3_inventory_shot` (fails on an
  unmodified tree too — inventory pin drift; triage separately).
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
- **Playtest triage 2026-08-12 (filed, undispatched):** #458 companion swap
  permanently exhausts the old bond (post-#332 gap, verified in code — the
  `released` reason never banks/re-supplies); #459 companion follower sprites
  are idle-only, need 4-direction walks (PixelLab path); #460 enemy archetype
  variety, first target a mid-fight summoner (needs design pass; balance pins
  will move).
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
