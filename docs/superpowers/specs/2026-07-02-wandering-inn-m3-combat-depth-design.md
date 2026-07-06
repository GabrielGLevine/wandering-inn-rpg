# Wandering Inn RPG M3 — Combat Depth Design

> **Delegation note (for morning review):** authored overnight under the delegation recorded
> in `.superpowers/sdd/progress.md` (user, 2026-07-02, pre-sleep, including the mage
> amendment). Scope was user-locked; the *numbers and mechanics details* below are
> controller calls made under that delegation, each marked **[D]** where judgment was
> exercised. Flag anything for revision before or after execution — systems are
> harness-balanced, so number changes are cheap.

## Context

M2 (story spine) closed READY TO SHIP with zero Criticals. M3 is the combat-depth
milestone the M1 playtest and final reviews queued: the user's movement-economy note
("same AP pool for movement feels clunky... maybe BG3-style free movement + Dash"), the
deferred positional mechanics (AoE/line + LoS), and the user-amended mage scope.

User-locked scope (all decisions user-made unless marked [D]):
1. **Movement economy:** free per-turn move pool + Dash action for AP (user sketch).
2. **AoE/line skill shapes + line-of-sight.**
3. **[Mage] via earned multiclass** — `gained_by` machinery; a magic-adjacent prop grants
   `used_magic`; the next sleep grants [Mage] 1 alongside Fighter.
4. **Simple MP pool** — visible like HP; spells cost MP + AP; no in-combat regen; sleep
   restores. Raw INT stays hidden.
5. **Core four spells:** Flame Jet (line), Frost Bolt (+slow — first status effect),
   Mana Shield (MP-absorb reaction), Quick Cast (first-spell-each-turn discount passive).
6. **New enemies + full rebalance** with new canonical seeds.
7. **Web QA seed threading** (closes combat QA's native-only gap).
8. Deferred to M4: story content, spell evolution, more classes, respawn design.

## Mechanics

### Movement economy (replaces move-costs-AP)

- Each turn: **move pool = 3 cells** [D], consumed by 4-dir steps, free of AP.
- **Dash** action: 1 AP → +3 move pool [D], repeatable while AP lasts (BG3 allows one
  Dash per action economy; repeatable is simpler and the harness will price it).
- AP stays 4; attack 2; skills per `ap_cost`. Unspent pool lost at turn end.
- Sim API: `move_active` consumes pool (refuses at 0); new `dash()` intent; `turn_started`
  payload + snapshot gain `move_pool`. UI: pool pips beside AP pips; Dash menu row.
- AI: profiles use pool first, Dash only when it enables an attack this turn [D].

### Line-of-sight + shapes

- **LoS:** Bresenham cell walk caster→target; blocked cells block ranged attacks and
  spells (melee unaffected). Refused targets are filtered from AI candidates and the
  player's target cycle (greyed in feed text: "no line of sight").
- **Line shape (Flame Jet):** from caster through the target direction, length 4 [D],
  hits EVERY combatant in the walked cells — **friendly fire is real** [D] (WI-true and
  tactically honest; AI filters candidate lines that would hit allies).
- AoE circle deferred — line is M3's only multi-target shape [D] (one new resolution
  path; circle adds no new machinery, M4 content can add it as data).

### [Mage] multiclass + MP

- `classes.json` gains `gained_by` per class: `{"accomplishment": {"used_magic": 1}}` on
  mage. `WIProgression.check_class_gains(classes, accomplishments, catalog)` → new
  classes granted at level 1 during `sleep()` (same beat as level-ups, own toast:
  `"[Mage] class gained!"`).
- Content: **Dusty Scroll** prop (inn, cell chosen in plan): any character may attempt;
  interact records `used_magic` + toast [D]. One-shot via prop `hide/`... props lack
  hide_when — repeatable but idempotent-harmless like the table [D].
- **MP:** `max_mp = 8 + INT/2` [D] (internal formula; only the MP number is visible).
  Non-casters show no MP bar (max_mp 0 when no spells known [D]). Spells cost MP + AP;
  refused without both. Sleep restores MP narrative-side (combat builds fresh anyway).
- Mage levels: L1 grants Frost Bolt + Quick Cast; L2 (requires `won_combat >= 3` [D])
  grants Flame Jet + Mana Shield.
- Core four [D] numbers: Frost Bolt 1 AP + 2 MP, range 4, INT-based damage, applies
  `slowed` (move pool −2, min 1, one turn — first status effect, minimal framework:
  statuses dict on combatant, tick at turn start). Flame Jet 2 AP + 4 MP, line 4.
  Mana Shield reaction: absorbs incoming damage 1:1 from MP until MP empty, armed while
  known [D]. Quick Cast passive: first spell each turn costs 1 less AP (min 0).

### Enemies + balance

- Two new enemies from v1 flavor [D]: **Cave Spider** (fast melee: dex-high, fragile)
  and **Goblin Chieftain** (tanky, knows power_strike). Pure data.
- One new arena with LoS terrain (`cave_mouth` [D]: 12×8, wall clusters) + one new street
  encounter ("Chieftain's Raid": Chieftain + Raider + Spider [D]) so the new systems are
  playable without new maps.
- **Full rebalance:** batch harness extended to run BOTH encounter compositions and a
  Fighter/Mage-build PC variant; bounds unchanged (0.55–0.95, median 3–12) [D]; new
  canonical seeds discovered and recorded per script.

### Web QA seed threading

- `run_web_qa.mjs` passes the seed: `window.__WI_QA__ = {script, seed}`; `game.gd` on web
  reads seed via `JavaScriptBridge` when user args are empty. Combat scripts then run in
  the headless-web loop too (parity with native).

### Harness/UX pre-work mandated by the M2 final review

- `TestDriver.wait_for_event` gains a since-marker (matches events after the previous
  wait's position) — BEFORE M3 combat QA is authored.
- Combat/UI input arbitration hardened with `set_input_as_handled()` at each consuming
  layer (surface grows this milestone).
- M3-opener cleanup batch: the deferred Minor list in `.superpowers/sdd/progress.md`
  (M2 section) — apply-crash guard on bad map id, repeatable-cleaning hide_when,
  requirement-text doubling, locked-cursor UX, validator generalization, include_filter
  redundancy, plus the M1/M0 carried items that touch files this milestone opens anyway.

## Non-Goals (M3)

Story/dialogue content beyond the scroll prop; AoE circles; spell evolution; MP regen
mechanics; new maps; respawns; multi-slot saves; art (asset integration is its own
post-M3 plan); mage-specific AI profile beyond spell-aware "ranged" extension [D].

## QA

- Unit: movement-pool/dash rules; LoS truth table against wall fixtures; line-hit
  enumeration incl. friendly fire; status tick; MP spend/refusal; Mana Shield absorb;
  Quick Cast discount; class-gain at sleep; determinism assertion extended to a
  spell-heavy scripted fight.
- Batch: both compositions × both builds, printed distributions, bounds asserted.
- QA scripts: `mage_unlock_loop` (scroll → sleep → [Mage] toast → frost bolt in fight),
  `line_of_sight_denial` (wall blocks a cast; reposition; cast lands), rewritten combat
  scripts on new canonical seeds; web-loop run of one combat script (seed threading
  proof).
- Windowed screenshot pass: MP bar, Dash row, line-hit feed lines, slow status feedback.
