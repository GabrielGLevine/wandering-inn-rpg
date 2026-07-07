# Task K2b: hotbar loadout management (slotted-loadout model) — Skills wave

## Goal
A player-managed slotted loadout deciding which KNOWN skills sit on the two
hotbars (field + combat), landing BEFORE K3 widens the kits past 9 number
keys. The model below is USER-RATIFIED (HANDOFF "HOTBAR OVERFLOW" block,
plan amendment 2026-07-06; the ⚑ veto window closed without a veto — apply,
don't re-flag). Empty loadout = AUTO = byte-identical to today.

## Plan text (verbatim, `docs/superpowers/plans/2026-07-06-skills-wave.md` Task K2b)
**Why now:** known field skills already hit 8/9 slots on a maxed multiclass
(Three Pillars watch item); K3's new Skills overflow both bars. Number keys
top out at 9 (`hotbar_1..9`). Must land BEFORE K3 widens the kits.
**Model:** player-managed SLOTTED LIST, shared shape across both bars:
- New sim field `hotbar_loadout: Array[String]` (ordered skill ids, additive
  save, tolerant default `[]` = AUTO mode: fill in the current derivation
  order, exactly today's behavior — zero change until the player first
  customizes; a loadout never grants anything, it's a VIEW onto known/kit
  skills, invalid ids filtered on read).
- Field bar renders `loadout ∩ known field skills` (AUTO when empty);
  combat bar keeps slots 1/2 fixed (Attack/Dash) and renders
  `loadout ∩ fielded kit` into 3..9 (AUTO when empty).
- Assignment UI lives in the JOURNAL skills panel (the only place all known
  skills are already listed): a assign/unassign toggle per skill row +
  reorder; keyboard-driven; emits `ui_loadout_changed` + re-renders both
  bars via the existing render triggers.
- A skill KNOWN but unslotted is still usable in combat targeting? NO —
  slots are the verb surface; unslotted = not fielded that fight (combat
  build unchanged, only the bar view filters). Disclose this clearly on the
  journal UI ("Slotted skills appear on your bars").
- Sim purity: the loadout is pure state + pure filters; UI renders.
**Tests:** loadout round-trip; AUTO default byte-parity with today's order;
invalid-id filter; combat bar 1/2 pinned.
**QA:** extend `field_skills_loop` (assign/unassign through the real journal
UI, bar re-renders with the chosen subset, number key fires the REMAPPED
slot); combat canonical re-pin only if slot text moves (disclose).

## Design decisions already made
- **AUTO-default byte-parity is THE acceptance bar.** With `hotbar_loadout
  == []`, the field bar's slot list must equal `known_skills()` filtered by
  `field: true` in the EXACT current order, and the combat bar must equal
  today's `rebuild_slots` output (1 Attack, 2 Dash, 3+ kit skills with
  `contexts` combat + `ap_cost > 0`, current order) — pin this parity in a
  unit test (derive both ways, assert equal arrays). The parity's live proof:
  the ENTIRE existing canonical suite passes with ZERO edits except the
  `field_skills_loop` extension. If any other script needs a change, your
  parity is broken — fix the feature, not the script.
- Loadout is a VIEW: never grants, never persists unknown ids; filter
  invalid/unknown ids on READ (a save carrying a renamed/removed skill id
  must degrade silently to the surviving intersection — K3 renames are
  coming; do not crash, do not toast).
- Save: additive-optional field, NO version bump (the char-creation /
  seen_statuses precedent); `test_save` round-trips a customized loadout AND
  proves an old save (field absent) loads to `[]`/AUTO.
- Sim owns state + filters (`wi_game.gd` — or its extracted sub-sim home if
  the ARCH-4 extraction landed; grep for `known_skills` and follow where the
  field-skill dispatch now lives, do NOT assume K2-era file shape). UI only
  renders. New event const for `ui_loadout_changed` (or the project's
  `UI_*_RENDERED` confirmation idiom — read `src/core/wi_events.gd` and match
  its naming style; disclose the shape).
- Journal skills panel is the assignment surface: reuse its existing
  grouped-by-class rows; a toggle key (pick one not already bound — check
  `ACTION_KEYS` in `qa/test_driver.gd` and the input map) assigns/unassigns
  the cursored skill; reorder can be v1-minimal (assignment order IS the
  order — appending on assign is acceptable if disclosed; a dedicated
  reorder key is better if cheap).
- **K2b owns the field-readout surface** (ledger note from K2's close): the
  bottom-left field readout has a measured 3-line budget
  (`READOUT_TEXT_HEIGHT := 70.0`, see `field_hotbar.gd`'s doc comment and
  `task-k2-sneak-report.md` fix #2) and silently DROPS overflow rows. With a
  loadout, the player now controls which rows exist — that is the intended
  resolution of the drop-row UX trade. Verify windowed that a customized
  loadout's readout shows the loadout's skills (and note in the report
  whether a >3-row loadout still drops rows — acceptable, disclose).

## Hazards for the executor (exact pins to check BEFORE editing)
- `field_skills_loop` asserts `ui_field_hotbar_rendered{slots:1}` → `{slots:3}`
  and fires specific hotbar numbers; `social_loop` asserts slots 1→2 and
  fires `hotbar_2` on [Charming Smile]; `stealth_loop` fires `hotbar_2`
  ([Sneak] toggle) + `hotbar_3` ([Observe]); `status_first_encounter` casts
  frost_bolt via a real combat hotbar key. ALL must stay green untouched
  under AUTO. Grep `qa/scripts/*.json` for `hotbar_` and
  `ui_field_hotbar_rendered` and read every hit before you start.
- `journal_skills` pins the journal's grouped-by-class payload structure —
  adding assign-state to rows may move that pin; enumerate first, update in
  the same edit, disclose old → new.
- `combat_hud.gd` slot 1/2 are reserved commands (Attack/Dash), NOT data
  skills — the loadout only governs 3..9. Pin that in a test.
- Do not touch the P1 dispatch seam semantics (`use_skill_field`) — the
  loadout changes which skill a NUMBER maps to, not how a skill fires.

## Binding constraints
- Sim purity (no Node/autoload refs in sim code); zero-warning; GDQuest
  style; additive events only; OPACITY (no stat numbers anywhere; the
  journal toggle copy is plain: "Slotted skills appear on your bars.").
- Voice lint any new player-facing string (banned-tell list in
  `.claude/skills/wi-adding-dialogue-and-quests/SKILL.md`).
- Commit `*.uid` for any new `.gd` (run `--headless --import` once).

## Successor safety rails (spelled out — do not skip)
1. **Ledger first:** `tail -40 .superpowers/sdd/progress.md` — if K2b already
   appears as complete/in-flight, STOP and reconcile before dispatching.
2. **Exact-pin discipline:** any string/array/count a QA script or unit test
   pins must be updated in the SAME edit that moves it; grep `qa/scripts/`,
   `qa/fixtures/`, `tests/` for every literal you change; report every pin
   moved (old → new).
3. **Script registration is conditional on ARCH-1:** if
   `wandering_inn_game/qa/manifest.json` EXISTS, it is the single source of
   truth for script → seed → fixture — add/edit rows there and follow its
   generated-table convention. If it does NOT exist, register in BOTH
   `wandering_inn_game/CLAUDE.md` lists (Commands block + canonical seed
   table) AND `qa/ci_sweep.sh`'s CANON array, counts bumped everywhere.
   Never trust a hardcoded count — count `ci_sweep.sh`'s entries and
   `tests/test_*.gd` yourself (49 canonicals / 17 unit files at K2 close).
4. **Alarm-wrap every run:** a failed `assert` HANGS godot forever. macOS has
   no `timeout`; use `perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot …`.
   Kill anything past ~2min and read partial output.
5. **Zero-warning grep:** grep EVERY run's output for
   `SCRIPT ERROR|Parse Error|WARNING` — a unit can print PASS and still
   carry a swallowed SCRIPT ERROR. Never grep `^PASS` alone.
6. **Windowed shots must be READ by eyes,** and `qa_output/<script>/` is
   clobbered by every re-run — copy PNGs out IMMEDIATELY to the shots dir
   below, then actually look at them (text clipping, row drops, slot
   labels).
7. **Worktree-merge intersection rule:** if any other lane is live, compute
   the file-map intersection against `git status` AND the live lane's
   reported file list BEFORE any copy-merge; re-gate the MERGED tree. In
   doubt, serialize (the K1/L2 clobber is the cautionary tale).
8. **NO-COMMIT implementers:** the implementer never commits or `git add`s;
   the controller stages the EXPLICIT paths the lane's report names — never
   `git add -A` while any lane is live.
9. **CLAUDE.md is freshly slimmed:** reference its sections by NAME, not
   line number; per-script routing detail may live in
   `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` if the slimming created it —
   check, and put new per-script notes where the existing ones live.

## Verification (FOREGROUND, alarm-wrapped, sequential — never background
## a run and wait; notifications cannot reach you)
1. `--import` (if new .gd) + load_gate + smoke.
2. Units individually, grep discipline: test_sim_core (parity + filter
   blocks), test_save (round-trip + absent-field default), test_combat_sim
   or test_combat_visuals (slots 1/2 pinned, loadout∩kit), test_effect_text
   (should be untouched — verify), test_content.
3. field_skills_loop (extended), journal_skills, social_loop, stealth_loop,
   status_first_encounter, combat_walkthrough at their pinned seeds.
4. Full `bash wandering_inn_game/qa/ci_sweep.sh` — all green, no grep hits.
5. Windowed field_skills_loop: the journal assign toggle mid-flow + the
   re-rendered bar with the chosen subset; copy PNGs to
   `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/k2b-shots/`
   and READ them.

## Report contract
- NO commit, NO git add. Full report to
  `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/task-k2b-loadout-report.md`:
  files touched, the loadout event shape, the AUTO-parity proof method, the
  journal-UI key choice, every pin moved (old → new), the readout drop-row
  disclosure, gate table, shot names.
- Return only: status, one-line test summary, concerns.
