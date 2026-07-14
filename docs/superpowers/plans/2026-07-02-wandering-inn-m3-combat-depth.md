# Wandering Inn M3 — Combat Depth Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Free move pool + Dash, line-of-sight + the Flame Jet line (friendly fire real), [Mage] earned multiclass with a visible MP pool and the core-four spells, two new enemies with a full harness rebalance, and web QA seed threading.

**Architecture:** All mechanics land in the pure sim layer first (WICombat/WISkillEffects/WIProgression), harness-verified, then presentation. Statuses are a minimal dict-on-combatant framework (tick at turn start). Class GAIN joins level-up at the sleep beat. The balance harness grows to a matrix (2 encounter compositions × 2 PC builds) and remains the tuning authority.

**Tech Stack:** Godot 4.7 GDScript, JSON data, existing QA harness.

**Spec:** `docs/superpowers/specs/2026-07-02-wandering-inn-m3-combat-depth-design.md` (delegated; [D] marks controller calls). Read it first.

## Global Constraints

- Godot `/usr/local/bin/godot` (4.7.stable); repo root `/Users/gabriel/wandering_inn_rpg`; branch main; commit per task with the standard trailer; `--import` after .gd changes; commit `*.uid`s; zero SCRIPT ERROR/Parse Error/WARNING (RED runs excepted).
- Purity rule unchanged. All randomness via injected rng; determinism assertions must keep passing.
- **Exact mechanic numbers (from spec, [D]-locked):** MOVE_POOL=3/turn; DASH: 1 AP → +3 pool, repeatable; AP=4, ATTACK=2 unchanged; Flame Jet line length 4, friendly fire ON, 2 AP + 4 MP; Frost Bolt 1 AP + 2 MP, range 4, applies `slowed` (move pool −2, min 1, expires after the victim's next turn start); Mana Shield: armed-while-known reaction, absorbs damage 1:1 from MP; Quick Cast: first spell each turn −1 AP (min 0); max_mp = 8 + INT/2 (integer division), 0 when the combatant knows no spells; Mage L1 = frost_bolt + quick_cast, L2 (`won_combat >= 3`) = flame_jet + mana_shield; mage `gained_by` = `used_magic >= 1`.
- MP number is player-visible; raw INT (and all raw stats) remain forbidden everywhere.
- LoS: Bresenham over blocked cells; blocks ranged attacks + spells; melee exempt.
- Balance bounds unchanged (win_rate 0.55–0.95, median rounds 3–12) across the full matrix; tuning is data-only; new canonical seeds discovered per script and recorded in ledger + CLAUDE.md.
- Tests: SceneTree scripts, purity-safe. Style: tabs, static typing, `##` doc comments.

## File Structure

```
src/core/combat/wi_combat.gd      # T2 move pool/dash/statuses; T3 LoS; T4 MP/shield/quick-cast hooks
src/core/combat/skill_effects.gd  # T3 line resolution; T4 spell costs/status application
src/core/combat/combat_ai.gd      # T2 pool-aware movement/dash; T3 LoS+ally-safe line filter; T4 spell/MP awareness
src/core/progression.gd           # T5 check_class_gains
src/core/wi_game.gd               # T5 sleep class-gain; scroll handled via existing prop machinery
src/combat/combat_screen.gd       # T6 MP bar, pool pips, Dash row, status/LoS feedback
qa/test_driver.gd                 # T1 since-marker
src/ui/* + input consumers        # T1 set_input_as_handled hardening + minor-batch fixes
data/{skills,classes,combatants,arenas,skeleton_scene}.json  # T3/T4/T5/T7 content
tests/test_combat_sim.gd (T2-T4) / test_progression.gd (T5) / sim_combat_batch.gd (T7 matrix)
qa/scripts/* (T8) ; qa/web/run_web_qa.mjs + src/core/game.gd (T8 seed threading)
```

Task order: T1 opener → T2 movement → T3 LoS/line/status → T4 MP/spells → T5 class gain + content → T6 UI → T7 enemies/arena/rebalance → T8 QA scripts + web seeds → T9 docs/windowed (controller).

---

### Task 1: Opener — deferred-minor batch + harness pre-work

**Files:** `qa/test_driver.gd`, `src/ui/dialogue_panel.gd`, `src/ui/pause_menu.gd`, `src/ui/journal.gd`, `src/combat/combat_screen.gd`, `src/world/world.gd`, `src/core/save.gd`, `data/dialogue/erin_errand.json`, `tests/test_content.gd`, `export_presets.cfg`, `tests/test_save.gd`, `tests/test_dialogue.gd` as needed.

**Interfaces produced:** `wait_for_event` matches only events at indices ≥ a per-driver `_wait_cursor` advanced to the match position +1 on every successful wait (explicit `{"from_start": true}` opts out); every `_unhandled_input` consumer that ACTS calls `get_viewport().set_input_as_handled()` after consuming (arbitration semantics otherwise unchanged).

- [ ] Since-marker in TestDriver: add `var _wait_cursor := 0`; `_wait_for_event` scans `_events_seen` from `_wait_cursor`, on success sets `_wait_cursor = match_index + 1`. `assert_event_logged`/`assert_event_absent` keep whole-history semantics (they are audits, not sequencing). Adjust any existing script broken by the change (run all six + inn_walkthrough; the M2 scripts were authored around cumulative quirks — fix SCRIPTS, never weaken assertions; report each adjustment).
- [ ] `set_input_as_handled()` in dialogue_panel/pause_menu/journal/combat_screen/world at every point an input action is actually consumed.
- [ ] Minor batch: (a) `WISave.apply` returns false (no crash) when `state.current_map` isn't in `game._maps` — add a membership guard + test_save case; (b) erin_errand cleaning option gains `"hide_when": {"accomplishment": {"cleaned_the_inn": 1}}` (test_content/test counts adjusted); (c) dialogue_panel: when the authored text already ends with a parenthesized tag, still append requirement but ONLY if different — simpler [D]: STRIP the auto-suffix when `requirement` text is already a substring of the option text; (d) locked rows render the cursor mark (greyed `> `) so navigation is visible; (e) generalize test_content's always-available-exit assert to every graph containing any hide_when; (f) drop redundant `data/quests.json` from include_filter.
- [ ] Verify: all M2 tests + all six QA scripts (seeds 9/9/9/9/9/11) + inn_walkthrough + load_gate PASS. Commit `"M3 opener: QA since-marker, input-handled hardening, deferred-minor batch"`.

---

### Task 2: Movement economy — move pool + Dash

**Files:** `src/core/combat/wi_combat.gd`, `src/core/combat/combat_ai.gd`, `tests/test_combat_sim.gd`.

**Interfaces produced:** `const MOVE_POOL := 3`, `const DASH_COST := 1`, `const DASH_GAIN := 3`; combatant state key `"move_pool"`; `move_active(dir)` consumes pool not AP (refuses at pool 0; still refuses dead/finished/dialogue-irrelevant); new intent `dash() -> bool` (active, AP ≥ 1 → AP−1, pool+3, emits `dashed {id, move_pool}` + `ap_changed`); `turn_started` payload + `snapshot()` combatants gain `move_pool`; statuses hook: `_start_turn` sets pool to `MOVE_POOL` MINUS any `slowed` reduction then EXPIRES the status (framework lands here: `c["statuses"]: Dictionary`, applied by T3/T4 effects; `status_applied {id, status}` / `status_expired {id, status}` events).

- [ ] Failing tests: pool starts 3 on turn start; 4th step refused with AP untouched; dash spends 1 AP → 3 more steps possible; repeated dash; dash refused at 0 AP; attack still 2 AP and unaffected by pool; determinism test still passes with a dash in the scripted stream; `slowed` status: apply via test hook (`c["statuses"]["slowed"] = {"pool_penalty": 2}`), next `_start_turn` gives pool 1 and emits `status_expired`.
- [ ] Implement per interfaces (complete code authored by implementer following the existing wi_combat style; the mechanics above are exhaustive).
- [ ] AI: `_act_melee`/`_act_ranged` movement branches consume pool first; when pool exhausted and AP ≥ DASH_COST + (attack/spell cost they intend), dash-then-continue [D: dash only when it enables an action this turn — implement as: dash iff after dashing the projected steps reach adjacency/range AND AP remainder covers the action].
- [ ] Batch harness will be broken balance-wise (more mobility) — DO NOT retune here; run it, record the interim numbers in the report, and assert only termination (temporarily flag the bounds assert behind `const TUNING_PENDING := true` with a loud comment; T7 removes it). All other tests/scripts must PASS except the two combat QA scripts if fight outcomes shifted (expected — report outcomes; T8 re-seeds).
- [ ] Commit `"Movement economy: free move pool + Dash action; status framework"`.

---

### Task 3: Line-of-sight + Flame Jet line + slowed application

**Files:** `src/core/combat/wi_combat.gd`, `skill_effects.gd`, `combat_ai.gd`, `data/skills.json`, `tests/test_combat_sim.gd`, `tests/test_combat_data.gd` (if shape fields need validation).

**Interfaces produced:** `WICombat.has_los(a_id, b_id) -> bool` (Bresenham over `blocked`; entity cells do NOT block LoS [D], walls do); `attack`/ranged `use_skill` refuse without LoS (melee exempt); `line_cells(from: Vector2i, toward: Vector2i, length: int) -> Array[Vector2i]`; skill data: flame_jet entry `{"ap_cost": 2, "mp_cost": 4, "effect": {"type": "line_damage", "length": 4}}` (mp enforcement arrives T4 — until then mp_cost tolerated-ignored with a comment); frost_bolt gains `"applies": {"slowed": {"pool_penalty": 2}}` on its (new) entry; `skill_resolved` for line carries `cells` + `hit_ids`.

- [ ] Failing tests: LoS truth table on a fixture arena (wall between → has_los false; adjacent gap → true; ranged spell refused through wall, melee attack allowed); line enumeration from caster through target dir length 4 clipped at bounds; line hits enemy AND ally in path (friendly fire) with damage events per victim; frost_bolt applies slowed (victim's next turn pool 1, then expires); AI never selects a line whose cells include an ally (construct a forced fixture).
- [ ] Implement: `line_damage` resolver in skill_effects (direction = normalized cardinal from caster to target — refuse non-cardinal targets [D: lines are cardinal-only, keeps targeting UI sane]; iterate cells, `_resolve_hit` each occupant, spells melee=false no-riposte); statuses applied post-hit via `"applies"`.
- [ ] AI ranged: LoS-filter candidates; line-caster variant filters ally-inclusive lines.
- [ ] Verify: combat sim tests PASS; batch still TUNING_PENDING; commit `"Add line-of-sight and Flame Jet line with real friendly fire; slowed status"`.

---

### Task 4: MP pool + spell costs + Mana Shield + Quick Cast

**Files:** `wi_combat.gd`, `skill_effects.gd`, `combat_ai.gd`, `data/skills.json`, `tests/test_combat_sim.gd`.

**Interfaces produced:** combatant build computes `max_mp = 8 + int(stats.int / 2)` iff the combatant's skills include any with `mp_cost`, else 0; `mp` state + `mp_changed {id, mp}` events; `use_skill` refuses on insufficient MP; `quick_cast` passive: first successful spell each turn costs 1 less AP (min 0) — per-turn flag reset in `_start_turn`; `mana_shield` reaction: while holder knows it and `mp > 0`, incoming damage drains MP 1:1 before HP (emit `reaction_triggered {id, skill: "mana_shield", absorbed}`); skills.json entries for `frost_bolt`, `flame_jet` (updated), `mana_shield`, `quick_cast` with display names/descriptions/contexts ["combat"].

- [ ] Failing tests: max_mp formula + zero-for-nonmage; spell refused at low MP with AP untouched; quick_cast discounts exactly the first spell (second spell full price; next turn resets); mana_shield absorbs into MP with HP intact, partial absorb splits correctly, shield inert at 0 MP; riposte does NOT trigger on spell hits (regression); determinism with a spell-heavy scripted stream (extend the existing determinism block).
- [ ] Implement per interfaces; AI ranged extends to MP awareness (skip spells it can't afford; prefer flame_jet when ≥2 enemies share a safe cardinal line [D]).
- [ ] Verify + commit `"Add MP pool, spell costs, Mana Shield and Quick Cast"`.

---

### Task 5: Class gain machinery + mage content

**Files:** `src/core/progression.gd`, `src/core/wi_game.gd`, `data/classes.json`, `data/skeleton_scene.json`, `tests/test_progression.gd`, `tests/test_sim_core.gd`, `tests/test_content.gd`.

**Interfaces produced:** `WIProgression.check_class_gains(classes, accomplishments, catalog) -> Array[String]` (classes with `gained_by` met and not yet held); `sleep()` applies gains BEFORE level-ups (a just-gained class can also level the same sleep only if its thresholds pass — natural composition, assert it); events `class_gained {class}` + toast `"[Mage] class gained!"`; classes.json mage entry (gained_by used_magic≥1; L1 grants frost_bolt+quick_cast; L2 requires won_combat≥3 grants flame_jet+mana_shield); Dusty Scroll prop in the inn (`{"id": "dusty_scroll", "kind": "prop", "cell": [8, 5], "display_name": "Dusty Scroll", "on_interact_accomplishment": "used_magic", "toast": "Strange symbols sear briefly into your vision. Something shifts."}` — NEW minimal prop path [D]: prop with `on_interact_accomplishment` records + toasts without requiring a skill; implement in `interact()`'s prop arm before the skill path).
- [ ] Failing tests first (progression: gained_by met/unmet/already-held; wi_game: scroll interact records; sleep gains mage then, with won_combat≥3 pre-earned, ALSO levels it; PC combat build knows frost_bolt after gain), then implement, then content validation (test_content: gained_by references known accomplishments-producible ids — extend the producible-union to include `on_interact_accomplishment`).
- [ ] Verify sweep + commit `"Add earned-multiclass machinery; [Mage] class and the Dusty Scroll"`.

---

### Task 6: Combat UI for the new mechanics

**Files:** `src/combat/combat_screen.gd` (prose-spec task — implementer authors, studying existing style).

Requirements: move-pool pips (distinct glyph `○` beside AP `●`); `Dash  ●` menu row (refused-disabled at 0 AP — greyed like locked dialogue options); MP as `mp/max_mp` text + thin blue bar under HP for combatants with max_mp>0; SKILL_PICK rows show `AP ● MP ◆` costs and grey unaffordable ones; targeting cycle SKIPS LoS-refused targets and the header notes "(no line of sight)" when the cycle is empty for that reason; line skills target a DIRECTION: targeting mode for line_damage cycles the four cardinals, header shows predicted hit list by display name (friendly-fire warning: ally names rendered in the locked-grey); feed lines for dashed ("X surges forward!"), status ("X is slowed!"/"recovers"), mana shield ("X's shield drinks the blow (N)"), line casts. NO raw stats; damage/HP/MP numbers fine.
- [ ] Implement; windowed sanity + headless boot + load_gate + inn_walkthrough clean; commit `"Combat UI: move pool, Dash, MP, line targeting with friendly-fire preview"`.

---

### Task 7: New enemies, cave arena, harness matrix + REBALANCE

**Files:** `data/combatants.json`, `data/arenas.json`, `data/skeleton_scene.json`, `tests/sim_combat_batch.gd`, `tests/test_combat_data.gd`.

- Cave Spider `{str 8, dex 15, con 5, int 4, wis 6, cha 4, weapon_die 4, ai "melee"}` [D]; Goblin Chieftain `{str 13, dex 9, con 10, int 7, wis 8, cha 9, weapon_die 6, ai "melee", skills ["power_strike"]}` [D] — starting guesses, harness tunes.
- `cave_mouth` arena: 12×8 with wall clusters producing real LoS play (author blocked list; validate bounds).
- New street encounter `chieftains_raid` at [8, 2]... [VERIFY free cell — selys sits at [8,1]; pick a free cell and document]: Chieftain + Raider + Cave Spider, arena cave_mouth, allies relc, on_victory ["won_combat"], conversation-less.
- Batch matrix: for composition in [goblin_ambush-set, chieftains_raid-set] × build in [Fighter-2, Fighter-2+Mage-2]: 100 seeds each (400 fights); per-cell bounds asserted; REMOVE `TUNING_PENDING`; tune data until all four cells pass; log every iteration.
- [ ] Verify sweep (all tests) + commit `"Add Cave Spider, Goblin Chieftain, cave arena; rebalance across the build/encounter matrix"`.

---

### Task 8: QA scripts + web seed threading

**Files:** `qa/scripts/` (new: `mage_unlock_loop.json`, `line_of_sight_denial.json`; rewrites: `combat_walkthrough.json`, `level_up_loop.json`), `qa/web/run_web_qa.mjs`, `src/core/game.gd`, `wandering_inn_game_v4/CLAUDE.md` seed table.

- Web seeds: `run_web_qa.mjs` accepts a seed arg → `window.__WI_QA__ = {script, seed}`; `game.gd._build_sim` on web (`OS.has_feature("web")`, empty user args) reads it via `JavaScriptBridge.eval("window.__WI_QA__ ? String(window.__WI_QA__.seed ?? '') : ''", true)`.
- `mage_unlock_loop`: scroll interact (used_magic + toast) → bed sleep → `class_gained {class: "mage"}` + toast → street fight (any) with `mp_changed` + a frost_bolt `skill_resolved` asserted (PC build must include mage kit — dry-run whose turn/AP/MP allow one cast; assert `status_applied {status: "slowed"}` on the victim).
- `line_of_sight_denial`: needs the chieftains_raid/cave arena: enter fight, assert a spell/ranged refusal path via events... [refusals emit nothing today — assert positively instead: assert_event_absent of a hit on the walled target during phase 1, then after repositioning assert the hit lands [D: refusal-event addition is allowed if needed — `action_refused {reason: "no_los"}` event on LoS refusal, added in T3 if this script wants it; coordinate].
- Rewrites: new movement economy changes routes minimally (field movement untouched!) but fight outcomes shift → discover new canonical seeds for all combat-bearing scripts (search ≤ 30, log), update invocations + CLAUDE.md seed table + ledger.
- Web-loop proof: run ONE combat script through `run_web_qa.sh` with its seed; PASS required (screenshots land in qa_output/web_*).
- [ ] Full regression sweep (everything) + commit `"M3 QA: mage loop, LoS denial, re-seeded combat scripts, web seed threading"`.

---

### Task 9: Docs, windowed verification, HANDOFF (controller-executed)

- Windowed runs of mage_unlock_loop + one combat script; read PNGs (MP bar, Dash row, line preview, slow feedback; no raw stats).
- CLAUDE.md: mechanics summary, new commands/seeds, statuses/MP conventions. HANDOFF: M3 section + playtest queue. Ledger close.

---

## Self-Review Notes

- Spec coverage: movement economy T2; LoS/line/friendly-fire T3; statuses T2 (framework) + T3 (application); MP/shield/quick-cast T4; class gain + scroll + mage data T5; UI T6; enemies/arena/matrix rebalance T7; web seeds + QA T8; review-mandated pre-work T1; docs T9. Non-goals respected (no circles, no regen, no new maps — cave is an ARENA).
- Known sequencing: batch bounds suspended T2→T7 behind TUNING_PENDING (loud, tracked); combat QA scripts expected red T2→T8 (ledger notes each).
- Type consistency: move_pool/dash/statuses/mp/mp_changed/has_los/line_cells/check_class_gains named once here and reused verbatim in later tasks.
- Final whole-branch review after T9 — mandatory (caught real Criticals in M0/M1; zero-Critical M2 doesn't retire the gate).
