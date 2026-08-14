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
- BALANCE PROGRAM state (details in merged PR bodies #435-#442, #488):
  every at-band climax row now sits inside [0.55,0.85]; steel thread
  GREEN at band (2569 steps, seed 37). #434 is the one open engine
  piece. #451 parked by user (Counter Strike power level). Pre-existing
  red still open: d3_inventory_shot (inventory pin drift, predates the
  program).
- ORCHESTRATOR HANDOVER **EXECUTED 2026-08-14**: Fable weekly hit its
  limit mid-gate (killed 3 auditors on the skirmisher lane); user
  switched the session to Opus, which now runs the wave. Gates re-run
  on Opus with the same template — no doctrine change. The gate discipline is canonical in
  wi-running-the-machine ("controller gate workflow" section, new);
  design docs are all written: equipment sketch
  (docs/superpowers/specs/2026-08-13-equipment-gaps-design.md, awaits
  user taste-pass), M3.6 + auto-consolidation + summoner specs on
  main, #485 name proposal posted (user approves per line). REMAINING
  QUEUE (all mechanical under the gate template): #488, #489 (Lich,
  #460 closed) and #490 (meal cap, #432 closed) MERGED — 30 total;
  skirmisher kit-gap lane sits at 6f77f0fa UNPUSHED with its gate
  re-running on Opus (ship on PASS); then M3.6 dispatch (spec is the
  brief), [Blademaster] rename lane, coverage lanes per #485 (blanket
  GO 2026-08-13 night, "stragglers edited later" — class-surface
  serialized, one lane at a time), equipment lane (sketch GO'd, §2
  rails binding), M4 (after M3.6 golden passes). ESCALATION RULE for
  Opus: anything smelling like a NEW design ruling (spec contradiction,
  window unreachable inside sanctioned levers, canon question) goes to
  the USER directly — do not improvise doctrine; wave autonomy covers
  execution calls only, logged to CHOICE-LOG.
- POST-WAVE FOLLOW-THROUGH (2026-08-13 session 2; resume here): 24
  MERGED total (wave 16 + #476 M2, #478 producers [Druid consolidation
  0/40->40/40], #479 Rank labels, #481 defects #474/#475, #482
  AUTO-CONSOLIDATION [#472 closed; narrowed live rows, coverage lint,
  proxy chaining, 77-pair parked queue], #483 annotations, #484 M3.5
  [fight.driven+journal+fence; golden prefix step 62]). M3.6 RULED on
  main, not dispatched. F0 #460 RATIFIED (Lich, crypt_lich/bone_thrall)
  — F1 queues behind class-lane merge. NAMING REVIEW: issue #485 (6
  set-level decisions). Post-bar class+Skill names proposable with user
  clearance (CHOICE-LOG). IN FLIGHT AT DRAIN: class lane d10d45b9
  ([Wild Sage]+[Skirmisher canon-match]+[Deathknight]; audit PASS bar
  ONE unpinned seam — counsel_of_the_wild live-ness test; fix agent
  finishing -> push+PR+merge) and balance tail (ladder + Tactician
  ceiling; drain order sent, read its output for state). AFTER RESET:
  merge class lane, read balance state, F1 Lich -> M3.6 -> equipment
  sketch (Fable) -> M4. User batch additions: skirmisher martial WALLs,
  wild_sage act5 1.00 ceiling (trivialization set with s16/druid).
  RULED 2026-08-13 late: capstone-set = trim growth AND/OR raise Warden
  (NO-AUTO-WIN principle binding; warden movement sanctioned; full
  re-window + re-fixture blast after); skirmisher walls = kit/Skill
  gap lane; #432 = meal cap (strongest-single, refresh-not-stack).
  These three join the post-reset dispatch queue AFTER balance-tail
  PR (same surfaces).
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

- **#19 — commercial gate:** any paid Steam path requires pirateaba's explicit
  permission. Free-on-Steam remains the recommended path.
- **Balance rulings raised by the skirmisher lane (2026-08-14), both
  escalated rather than improvised:**
  1. `act2_cistern_nest` skirmisher 0.40 WALL. Acts I–IV measure the
     PARENT lines (`spearmaster3/archer2`), not the consolidated class,
     so no skirmisher-table grant reaches it. It IS reachable by a
     spear-gated grant on `archer` L≤2 (the archer table is NOT
     bow-sealed — `keen_eye` carries no weapon key), and such a grant
     provably does not move ranger or scout, both bow at all five acts.
     The reason it stays open is COST, not reach: the cheapest reaching
     edit overshoots the same spine elsewhere — act3 0.72→0.88 (above
     the 0.85 ceiling), act1 0.79→0.96. Ruling wanted: accept the
     mid-act wall, or sanction the parent-table edit plus the re-window
     its overshoot forces. (The lane first recorded this as
     "structurally unreachable"; the gate refuted that premise.)
  2. **[Ranger] walls identically** at the warden (0.33, mp 0, no
     companion) — same diagnosis as skirmisher's pre-fix 0.26. Out of
     that lane's scope; wants the same kit-gap treatment if ruled.
- **Design calls still open from #488:** bonded wolf worth +0.79 at the
  Warden (bigger than every stat/Skill/item combined); t6/t12/s16 read as
  a level-budget problem, not capstone power; `beast_master14` 0.63→0.27
  collateral wants a broaden-growth repair (class-design call).

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
