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
- ORCHESTRATOR = OPUS since 2026-08-14 (Fable weekly exhausted
  mid-gate). Gate discipline canonical in wi-running-the-machine
  ("controller gate workflow"). Specs on main: equipment (SHIPPED),
  M3.6, auto-consolidation, summoner. ESCALATION RULE: anything
  smelling like a NEW design ruling (spec contradiction, window
  unreachable inside sanctioned levers, canon question) goes to the
  USER directly — do not improvise doctrine; wave autonomy covers
  execution calls only, logged to CHOICE-LOG.
- **CI now runs the Python corpus** (#498, 2026-08-14): a gate audit
  found ~357 pytest tests wired into NO runner — CI's "Unit suites" is
  `tests/test_*.gd` only — including every itinerary contract suite and
  the differ's own safety guards. The new `Python suites (pytest)` job
  carries `fetch-depth: 0` (test_data_diff walks `<sha>^`) and installs
  the pinned engine (two contract tests drive the oracle). CI is 8
  checks now. Verified running green on main post-merge.
- WAVE STATE (2026-08-14): **36 MERGED** through #498 — Lich (#460),
  meal cap (#432), skirmisher [Give Ground], [Blademaster] rename, M3.6
  (PARTIAL), equipment kit, §6.3 tightening, the CI pytest job. Per-change detail lives in
  the merged PR bodies; rulings in docs/CHOICE-LOG.md (11 user calls
  landed 2026-08-14). Merged worktrees cleaned; verify a squash merge by
  CONTENT/tree, never `git cherry`.
  IN FLIGHT: drift-set re-window lane (six ceiling cells + beast_master
  growth + the Warden's companion counter, one re-window).
  NEXT: [Ranger] kit-gap lane, then the small-fixes lane ([Sword Saint]
  aspiration, "Runner's Sandals of the Second Wind" rename, harness
  build-level fix), then coverage lanes per #485 (class-surface
  serialized, one at a time), then M4 (still blocked — see below).
  PARKED FOR AFTER THIS TAG (user): #494 resonance semantics,
  #495 damage_mod-never-reaches-spell/line/blast.
  WATCH: prose budget 25713/25725 — 12 words of headroom, so the next
  CONTENT lane trips it; budget a trim into that lane's scope.
  EYE-GATE READY for the user: `qa/playtest_saves/2026-08-14-460-death-
  cast-colour/` (PC death-cast recolour; autoplay structurally cannot
  cast, so only a human read closes it).
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
- Pacing/reachability findings ledger for the user's debrief lives at
  `wandering_inn_game/docs/design/steel-thread-route-spec.md` (Act III
  XP lump, Act IV economy squeeze, Diplomat load-bearing, alleys need
  [Stealth]).
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
- **Equipment lane escalations (2026-08-14):** (a) **Book 17 means two
  different things** — docs/design/spoiler-cutoff.md says *Garden of
  Sanctuary* (Vol 7 Pt 1, ~7.10); the wiki ebook index says *Lady of
  Fire* (Vol 7 Pt 3, ~7.28), a ~18-chapter gap. Lanes judge STRICTER
  until ruled; noted in that doc. (b) **Post-bar name wants clearance:**
  "Runner's Sandals **of the Second Wind**" — [Second Wind] is Vol 8
  Ch 8.15; shipped the cleared fallback "Runner's Sandals". The ability
  itself is grandfathered. (c) **spellspear Act III 0.89 is out of
  window and gear cannot fix it** — `equipment_mods` reads only
  `damage_mod`, so that ceiling is the spearmaster line, not the weapon.
  The sketch's §0 expectation that new gear would ease it is
  mechanically false. Needs adjudication as a class/spine question.
- **M3.6 EXIT (#434) — tightening ruling LANDED 2026-08-14; M4 STILL
  BLOCKED.** M3.6 merged as a PARTIAL milestone (#493). The user ruled
  that §6.3's "TIGHTER and never looser" **extends to a compiled-only
  `wait_for_event`** (rejected: per-node emitter keys). `goldens.py`
  implements it one-way only — a shipped-only step of any action stays a
  dropped claim, a compiled-only step of any other action stays extra
  behaviour, a looser payload pin stays fatal — and prints every
  reclassified row in its own untruncated report block.
  Differ against shipped 0-217 went `50 exact / 9 net` ->
  **`38 exact-class, 9 net-class, 9 tolerance-class, 25 tightening(s),
  12 compiled-only wait(s) reclassified`**. The 12 are typed as 3
  `dialogue_node`, 2 `map_changed`, 2 `ui_dialogue_rendered`, and one
  each of `class_gained`, `entity_removed`, `phase_changed`,
  `ui_inventory_selection_rendered`, `ui_sleep_veil_rendered`.
  **The golden still FAILS, so §7's M3.6 exit is NOT met and M4 does not
  dispatch.** The residue is emitter idiom variance (330-row position-pin
  class, sleep idiom, `items` pin, in-autoplay hotbar assert, pickup
  toast) plus two differ accounting weaknesses, each named and counted in
  qa/STEEL-THREAD.md. Acts II–V (2337 of 2569 steps) still unauthored.
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
