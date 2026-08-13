# Enemy archetypes — framework + summoner (#460 F0 design)

> Status: **AWAITING USER RATIFICATION** (F1 does not dispatch until this
> flips to APPROVED). Fable-authored 2026-08-13.

## 0. What this buys

Behavioral encounter variety (the playtest ask): fights that play
differently, starting with an enemy that adds combatants mid-fight. The
framework piece is ONE new data-driven skill effect; every later
archetype (healer, reinforcement-caller) is data + fiction on the same
rails or on rails that already exist.

## 1. Mechanic contract — the `summon` effect

New skill-effect arm in `wi_combat.gd` (the effect table `use_skill`
dispatches on), data-shaped:

```json
"raise_bones": {
  "display_name": "[Raise Bones]",
  "contexts": ["combat"],
  "ap_cost": 3,
  "cooldown_rounds": 2,
  "effect": { "summon": { "combatant": "bone_thrall", "count": 1, "fight_limit": 3 } }
}
```

- **Placement (deterministic, zero new rng draws):** first FREE cell in
  the arena's `enemy_spawns` array order (`is_cell_free`), nearest-first
  is NOT used — array order is the determinism contract, same as roster
  →spawn mapping today. No free enemy_spawns cell → the skill is
  unavailable (`skill_available` false), mirroring the crowded-field
  idiom at `wi_game.gd:2320-2326` (capacity is the spawn array, both
  sides of the board).
- **Turn order:** the summon appends to `turn_order` AFTER the current
  round's tail — it acts from the NEXT round. No initiative re-roll, no
  reordering of existing actors, zero rng consumed. (rng doctrine: the
  effect must not reshuffle existing draw sequences; a summon that rolls
  initiative would invalidate every downstream pin in any fight that
  contains one.)
- **Caps:** `fight_limit` per summoner per fight (tallied like
  `used_skills_tally`), `cooldown_rounds` via the existing cooldown
  plumbing, `ap_cost > 0` (engine activation rule, per the #450
  amendment precedent).
- **Death/cleanup:** summons are ordinary combatants; victory requires
  the full enemy roster dead (existing rule, unchanged). `_on_kill`
  crediting: summon deaths credit the KILLER's in-fight tallies
  normally, but the encounter's `on_victory` banks once as today —
  summons must add NO per-kill accomplishment/counter surface
  (anti-farming constraint; unit-pinned in F1).

## 2. First archetype — the bone-raiser

- **Combatant:** `bone_raiser` (new row, frail caster statline: low HP,
  no melee threat, the summons ARE the threat) + `bone_thrall` (new
  row, weak melee add — deliberately NOT the ally `skeleton_ally`
  record). **Art constraint:** the enemy thrall must read distinct from
  the player's animated ally at a glance — distinct silhouette/palette,
  tint-is-not-disambiguation applies hard here because both are
  skeletons on one board. PixelLab job in F1; the raiser itself can
  seed from existing robed-caster art direction.
- **Canon/spoiler check (discharged at design time):** necromancy is
  Volume-1 canon (Pisces; the game already ships `animate_dead` and the
  `learned_magic_from_pisces` counter). A nameless hedge bone-raiser in
  a ruin/dungeon context clears the Book-17 bar trivially; we introduce
  NO named canon necromancer (no Az'kerash reference in shipped prose —
  he is technically Vol-1-known but naming him in-world is a lore
  escalation this feature does not need). Class display: **[Bone
  Raiser]**, not [Necromancer] — reserves the canon-loaded class name.
- **Placement in world:** ONE new optional encounter (ruin_surface or
  dungeon approach band — F1 picks the cell against the region's
  existing encounter density), Act III-IV band. NOT on any climax, NOT
  on any existing route pin. This keeps the #441 re-fixture blast at
  zero: no existing canonical's fight changes; the rng doctrine bill is
  one NEW encounter's own pins only.

## 3. Chokepoint + balance guardrails (binding on F1)

1. No existing encounter gains a summoner this wave; climaxes untouched.
2. The new encounter lands inside [0.55, 0.85] competent-at-band with
   summons priced in (100-seed row before merge; floor row report-only).
3. Summon spam inversion check: the fight must also be measured at the
   fight_limit ceiling (all summons fired) — if the LIMIT case breaches
   the window, the limit is wrong, not the stats (composition-only
   tuning: count/limit/cooldown/placement, never the frozen shared
   stat rows — bone_raiser/bone_thrall are NEW rows and tunable until
   first ship, frozen after).
4. Policy: NO competent-policy change in v1 (summoner-first targeting is
   a plausible v2; measure the naive policy first — if the window is
   unreachable without a policy change, that is a STOP-and-report, not
   a silent policy edit, because policy edits move every measured row
   in the program).

## 4. Verification plan (F1 exit)

- Unit: deterministic placement (enemy_spawns order), next-round turn
  entry, capacity refusal, fight_limit, cooldown, no-per-kill-banking.
  Each mutation-proven (the wave's quit-before-assert discipline).
- Canonical: new encounter script asserting `combatant_added` mid-fight
  (event exists? F1 verifies; if the engine lacks the event, it is part
  of the effect arm), the capacity-refusal leg, victory over raiser +
  thralls, on_victory single bank.
- Sim: new rows (competent window + limit-ceiling case); pace: no new
  producers (G-series is user-gated), so no pace impact.
- Machine playtest + windowed read for feel (summon moment must READ:
  spawn cell flash/toast per existing combat event vocabulary).

## 5. Follow-up archetypes (file per-archetype after F1 ships)

- **Healer/support enemy:** `heal` effects exist engine-side
  (largest-heal-wins policy already models healing); archetype is data
  + target-selection for enemy AI (`WICombatAI` heal arm) — smaller
  than summoner.
- **Reinforcement-caller:** the same `summon` effect, fiction of
  calling not raising (patrol arrives at the map edge = spawn cell at
  board edge); zero new engine surface.

## 6. Open questions for ratification

1. [Bone Raiser] name + nameless-hedge-necromancer fiction — OK?
2. Act III-IV optional-encounter placement — OK, or do you want the
   first summoner somewhere specific?
3. fight_limit default 3 / cooldown 2 / ap 3 — starting numbers only
   (window measurement rules them), any priors?
4. v1 no-policy-change constraint — OK? (STOP-and-report if window
   unreachable.)
