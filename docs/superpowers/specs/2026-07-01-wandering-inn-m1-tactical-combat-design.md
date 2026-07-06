# Wandering Inn RPG M1 — Tactical Combat + Progression Spine Design

## Context

M0 (agent-QA foundation, commits `e6035d8..472bce6`) shipped: pure sim core (`WIGame`),
ObservableBus event pipe, TestDriver declarative playtests, native + headless-web QA loops.
M1 builds the first real game systems on that foundation, per the north star ("Baldur's Gate 3
set in The Wandering Inn, scaled for a team of 1"; [Skills] usable outside combat) and the
already-made combat direction call (tactical, positional, turn-based — spec
`2026-07-01-wandering-inn-v4-agent-qa-foundation-design.md`, decision 4).

Decisions made with the user (2026-07-01, all locked):

1. **Scope: combat core + progression spine** — one milestone delivers the full loop
   (fight → accomplishments → sleep → level → new skill → fight better), not just a fight.
   Rejected: combat-only (no loop payoff) and full v3-slice parity (scope sprawl).
2. **Action economy: AP pool** — 4 AP/turn, v1's `ap_cost` skill data ports directly.
   Rejected: BG3-style action/bonus slots (78-skill re-tag cost), hybrid move-pool.
3. **Party scale: design for 4, field 2** — sim/AI/UI assume up to 4 player-side combatants
   (arrays and balance math, not speculative code); M1 content fields PC + Relc.
4. **Combat UI: functional minimal** — placeholder squares, HP bars, no animation.
5. **No damage numbers** — HP bars shrink + prose event text; exact numbers stay in the
   sim event log where QA reads them. (HP/MP visible is allowed; raw STR/DEX never.)
6. **Sim shape: separate pure combat sim (`WICombat`)** — per-encounter instance, same
   purity rule as `WIGame`; world sim hands off and consumes the outcome. Rejected:
   growing WIGame into a god-object; ECS indirection.

## Goal

A human (or agent) can play: walk to the goblin encounter, fight PC+Relc vs Goblin Raider +
Goblin Shaman on a tactical grid, win, sleep in the Bed, level Fighter 1→2 (Counter Strike
unlocks, shown via toast), fight again with the riposte live — with the entire combat system
balanced via mass headless simulation before the combat UI existed.

## Architecture

### Module layout (sim code under M0's purity rule: no autoload/Node/scene-tree refs)

```
src/core/combat/wi_combat.gd      # WICombat — pure per-encounter combat sim
src/core/combat/skill_effects.gd  # effect-type registry (String → resolver Callable)
src/core/combat/combat_ai.gd      # role-profile AI (pure functions, seeded RNG)
src/core/progression.gd           # WIProgression — data-driven level-up checks
src/combat/combat_screen.gd       # code-built presentation (CanvasLayer/Node2D UI)
data/combatants.json              # relc, goblin_raider, goblin_shaman, pc build rules
data/classes.json                 # fighter: per-level accomplishment thresholds + granted skills
data/skills.json                  # extended: combat skills gain ap_cost + effect params
data/arenas.json                  # per-encounter grid size + blocked cells + spawn cells
```

`WICombat.new(arena_cfg, combatants_cfg, skills_cfg, event_sink, rng_seed)` runs an
encounter and produces an outcome Dictionary (`victory: bool`, survivors, rounds, kills by
combatant). `WIGame` remains the world sim: it triggers combat (new entity kind
`encounter`), consumes the outcome (accomplishment counters, entity removal), and owns the
sleep/level beat. 1000 `WICombat`s can run with zero world state — that is the balance
harness.

### Combat rules

- **Grid:** 12×8 cells, 4-directional movement, blocked cells from `arenas.json`.
  Presentation renders at 48px/cell (576×384, fits the 640×400 viewport).
- **AP:** 4 per turn. Move = 1 AP/cell; basic attack = 2 AP (melee: Chebyshev-adjacent,
  8 directions); skills cost their `ap_cost`. Turn ends at 0 AP or an explicit end-turn.
  Unspent AP is lost (no banking — deferred).
- **Initiative:** DEX-derived value + seeded roll, **precomputed once at combat start**
  into a fixed order for the whole fight (v1 lesson: never roll inside a sort comparator).
- **Damage model:** internal stats (STR/DEX/CON/INT/WIS/CHA) per race+class, ported from
  v1's formulas. Derived: max HP, hit chance (base 85% ± modifiers), damage roll (seeded).
  All rolls go through the injected RNG. Numbers appear in sim events only; the player
  sees HP bars and prose event text ("Relc's spear strikes deep").
- **Reactions:** resolution hooks `on_hit_received` and `on_kill`, resolved in initiative
  order. Carries Counter Strike (riposte 80% weapon damage) and Battle Momentum (+1 AP on
  kill, capped at one trigger per turn).
- **Ranged:** in-range = Chebyshev distance ≤ R. **No line-of-sight blocking in M1** —
  arenas are kept sparse; LoS ships with AoE/line shapes in M2.
- **Defeat:** all player-side down → `combat_finished {victory:false}` → `game_over`
  event; presentation offers restart (fresh run). No death persistence in M1.

### Skill-effect registry

`skill_effects.gd` maps effect-type strings to resolver Callables
(`resolve(combat: WICombat, actor, target, params) -> void`, emitting events via the
combat's sink). M1 tranche (~10 effects, all from v1's `skills.json`):

- Passives (applied at combatant build): `hp_bonus` (Tough Body), `hit_bonus` (Basic Swordwork)
- Actives: basic attack, `damage_mult` (Power Strike, 2 AP), single-target spell damage
  (Goblin Shaman's fire spell — v1's line-shaped `flame_jet` is deliberately reduced to
  single-target for M1; the line shape returns with LoS in M2)
- Reactions: `riposte` (Counter Strike), `ap_on_kill` (Battle Momentum)

`skills.json` entries keep their `contexts` tags — `basic_cleaning` (exploration) is
untouched; combat skills are tagged `combat`. One skill definition, context-tagged effects,
per the cross-context principle (v4 foundation spec, principle 7).

### Progression spine

- `WIGame.accomplishments` generalizes from flags to **counters**:
  `record_accomplishment(id)` increments an int (existing flag semantics preserved —
  a flag is a counter ≥ 1; `snapshot()` shape unchanged in kind, values become ints).
- `data/classes.json`: per class, per level → required accomplishment thresholds
  (e.g. Fighter 2 needs `won_combat >= 1`) + granted skill ids. Data, not code.
- `WIProgression.check_level_ups(classes, accomplishments, class_catalog) -> Array`
  (pure, static): returns pending gains. Called by `WIGame` **only at the sleep beat**
  (Bed interaction — level-by-sleeping is canon). Emits `class_level_up
  {class, level}` and `skill_unlocked {skill}` events → toast via the existing message
  layer. Skills granted at level-up are automatic (no choice UI in M1).
- Fighter is the only class fielded in M1. The PC's combat build derives from
  race + class levels + granted skills at combat start (mirrors v2's proven
  build-fresh-per-fight model — no live-battler mutation, ever).

### The M1 playable loop (mirrors v3's proven quest shape)

Skeleton map gains three entities: a `GoblinEncounter` (new kind `encounter`), a second
post-level encounter, and a `Bed` (kind `prop`, sleep interaction — new to v4; M0 had none).
Loop: interact with encounter → combat (PC Fighter 1 + Relc vs Raider + Shaman) → victory
records `won_combat` → sleep at Bed → Fighter 2 + Counter Strike toast → encounter
respawns (M1: victory removes it; a second encounter entity is placed for the post-level
fight) → second fight demonstrates the riposte. Defeat at any point → game over → restart.
No new dialogue, no new maps.

## QA & Balance (the new capability this milestone proves)

- `tests/test_combat_sim.gd` — pure headless: rules edge cases (AP spend, blocked moves,
  adjacency, initiative order, reaction triggers, death/victory) and the **determinism
  assertion: two WICombats with the same seed and same scripted inputs produce identical
  event streams** (closes the M0 final-review note — first RNG-consuming logic ships with
  its determinism proof).
- `tests/sim_combat_batch.gd` — **the balance harness**: 200 seeded AI-vs-AI runs of the
  M1 encounter (player side driven by the same AI profiles). Asserts: every fight
  terminates (round cap 30 = hang guard), win-rate within 0.55–0.95, median round count
  3–12. Prints win-rate/round/damage distributions for tuning. Balance changes are data
  edits + a batch re-run — no human grinding.
- New QA playtest scripts:
  - `combat_walkthrough` — seeded scripted victory via injected input; screenshots at
    combat start / mid-fight skill use / victory; asserts `combat_finished {victory:true}`
    and post-combat accomplishment counter.
  - `level_up_loop` — the full M1 loop: fight → sleep → toast (`ui_toast_rendered`) →
    second fight where a `reaction_triggered {skill:"counter_strike"}` event occurs.
- TestDriver extensions (also close M0 review notes): `assert_state` path-walk gains array
  indexing (`player_cell.0`) and a `combat.` path root served by the active combat's
  snapshot; a `wait_for_event` payload-match option (`{"type":"skill_unlocked",
  "payload_contains":{"skill":"counter_strike"}}`).
- M0 deferred Minors addressed in passing where the code is already open: `_:` diagnostic
  arms in `interact()`/`use_skill()` (entity kinds expand this milestone — the M1 note
  said bake it in now).

## Combat presentation (functional minimal)

`combat_screen.gd`, all code-built: grid + blocked-cell tint, combatant squares with name
labels + HP bars, turn-order strip (top), action menu (Move/Attack/Skill/End Turn), cursor-
based targeting (arrows move cursor/selection, Enter confirms, Tab cycles targets, Esc
backs out). Instant state application (no tweens). Prose event feed (last 3 events) at the
bottom in place of damage numbers. Combat runs in the same viewport; the field world hides
while combat is active (`combat_started`/`combat_finished` events drive the swap). No raw
stat numbers anywhere; HP bars and AP pips are the only meters.

## Non-Goals (M1)

- No LoS/cover, no AoE/line/push/teleport skill shapes (M2, together)
- No status effects beyond the two reactions; no buffs/debuffs framework
- No mage class content; no additional companions beyond Relc
- No save/load; no animation/juice; no AP banking; no flee action
- No dialogue additions; no new maps; no death persistence

## Files Touched (expected)

- Create: `src/core/combat/wi_combat.gd`, `skill_effects.gd`, `combat_ai.gd`,
  `src/core/progression.gd`, `src/combat/combat_screen.gd`,
  `data/combatants.json`, `data/classes.json`, `data/arenas.json`,
  `tests/test_combat_sim.gd`, `tests/sim_combat_batch.gd`,
  `qa/scripts/combat_walkthrough.json`, `qa/scripts/level_up_loop.json`
- Modify: `data/skills.json` (combat tranche), `data/skeleton_scene.json` (encounter
  entities + bed), `src/core/wi_game.gd` (counters, encounter kind, sleep beat, combat
  handoff), `qa/test_driver.gd` (assert_state paths, payload match), `src/world/world.gd`
  (field/combat swap hooks), `wandering_inn_game_v4/CLAUDE.md` (new commands/conventions),
  `tests/test_sim_core.gd` (counter semantics)
