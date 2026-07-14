# Skills Wave Implementation Plan (chain step 5)

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Skills READ-ONLY for subagents. Controller commits per green task, explicit paths. FOREGROUND-ONLY verification in every brief.

**Goal:** Spec §3+§4 of `2026-07-06-systems-depth-priorities.md`, user-ratified incl. the stealth model (2026-07-06): overworld-impact effects across existing kits + new capability-first Skills, movement and stealth as the priority verbs, every new Skill carrying a combat AND overworld read where sensible.

**Architecture:** Three small sim seams (freezable water, burnable props, the sneak state), everything else data + presentation on the P1 field-dispatch machinery. Legibility cards (step 3) describe every one of these — this wave lands AFTER LEGIBILITY, so new Skills ship with generated effect lines by construction.

## Global Constraints

- Canon Skill names wiki-verified per the profiles/canon discipline; misses escalate flagged.
- Visible currencies in all copy; stats hidden; opaque-until-sleep.
- Each seam: pure sim + injected config, unit-covered; presentation consumes events; QA canonical coverage + windowed proof per effect (the [Light] bar).
- New Skills arrive through CLASSES (gained_by/level grants — existing machinery only).
- Suite count per CLAUDE.md at execution; disclosure discipline (trigger-zone changes touch route scripts!).

---

### Task K1: freezable water + burnable props (traversal seams)

**Files:** `src/core/wi_game.gd` — two prop/terrain response classes: `freezable` (a water-channel/pond CELL marked freezable in map data; field-cast frost skill on the faced cell → the cell becomes walkable ice until sleep [a frozen-cells set, additive save field, cleared in sleep()]; emits terrain_changed + toast) and `burnable` (a blocking prop with `burnable: true`; fire skill → prop removed/replaced via the visual_states/remove machinery, banks a counter, permanent); presentation: ice tile overlay (the water-shimmer overlay precedent) + burn poof (hit_sparks preset reuse); map data: 2-3 frozen crossings authored (sewers channel shortcut, floodplains pond secret) + 1-2 burnable debris (a blocked sewers side-passage).
**Tests:** freeze/thaw round-trip; walkability flip; burn permanence; save.
**QA:** extend sewers_walkthrough (freeze crossing) + a burnable in a route script; disclose.

### Task K2: the sneak state (stealth seam, user-ratified model)

**Files:** `src/core/wi_game.gd` — `sneaking: bool` (set by a [Stealth]-class field skill toggle; BROKEN by interact/attack/skill-use-on-target; NOT saved — drops on save/load honestly, document); `_check_trigger_radius` skips while sneaking (the whole point: walk PAST dangers); combat: the same Skill = a reposition/escape verb (reuse movement-effect machinery — extra move pool that turn, or untargetable-until-next-turn if a status rider expresses it — trace what exists, no new effect types without escalation); presentation: PC translucency while sneaking (modulate, the tint machinery) + a soft state toast.
**Tests:** trigger-skip while sneaking; break conditions; combat read.
**QA:** new canonical `stealth_loop` (sneak past the ambush zone — the tutorial ambush is corridor-free BY DESIGN for onboarding: verify the skill arrives POST-onboarding [class-gated] so the mandatory tutorial fight stays mandatory for fresh players — trace the gained_by class level; this is the wave's one design-tension, resolve toward onboarding integrity).

### Task K2b: hotbar loadout management (overflow — user-raised 2026-07-06)

**Why now:** known field skills already hit 8/9 slots on a maxed multiclass
(Three Pillars watch item); K3's new Skills overflow both bars. Number keys
top out at 9 (`hotbar_1..9`). Must land BEFORE K3 widens the kits.

**Model (recommended, ⚑ user may override — see HANDOFF queue):**
player-managed SLOTTED LIST, shared shape across both bars:
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

### Task K3: the new Skills (capability table → kits)

**Files:** data/skills.json + classes.json — wiki-verify + ship: movement ([Quick Movement]-class: field = brief speed state [move-repeat rate], combat = +move pool), stealth ([Stealth] per K2 — which class? rogue-line doesn't exist: TACTICIAN fits canon-adjacent scouting or a new earned [Scout] class via exploration counters — wiki-check, escalate the class call if ambiguous), perception ([Keen Eye]-class: field = reveal hidden interactables glow + threat-range overlay [the Battlefield Awareness overworld read from spec §3], combat = accuracy-adjacent via existing fields), plus 1-2 utility from the table. Icons via glyph pattern; effect lines generated (L1).
**QA:** field_skills_loop extension + kit asserts; harness re-check if any combat numbers.

### Task K4: kit-wide overworld pass (the [Light] bar audit)

Every existing fielded Skill re-checked: does it DO something visible?
Ship the cheap wins ([Sweep the Tables] on messy-state props; observe's journal knowledge log if cheap); document honest no-ops (combat-only skills stay combat-only with their cards saying so).

### Task KF: gate + docs + opus review

- Full gate + windowed set (ice crossing, burn, sneak translucency, reveal glow) controller-read; VISUAL-LOG drain.
- Playtest checklist: does freezing a channel feel like MAGIC or a switch? Is sneaking readable? Did any new Skill's card surprise you?
- Opus hints: frozen-cells × blocked-set × pathing composition (a frozen cell in every walker's route derivation?); sneak × trigger × defeat-reload; the onboarding-integrity trace (K2's tension); terrain_changed × map rebuild × save round-trip; burnable × quest props (can a quest-required prop be burned? gate it).

## Self-review notes
- §3 spec bullets → K1/K4; §4 table → K2/K3; the stealth model is user-ratified 2026-07-06 (skill-gated sneak state, cones deferred).
- K2's onboarding-integrity tension is called out — the resolution (class-gated arrival) is designed-in, reviewers verify.
- Invrisil (chain 8c) consumes K2/K3 — this wave is its dependency.
