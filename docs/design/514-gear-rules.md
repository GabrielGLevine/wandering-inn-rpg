# #514: gear damage and resonance rules

Implements two user rulings from 2026-10-07, recorded in `docs/CHOICE-LOG.md`
under "Combat rules and gear":

- **#495:** weapon-gated physical Skills take the weapon's `damage_mod` and
  scale off STR, like ordinary melee. Spells and blasts keep INT and gain a
  new caster spell-power stat carried by wands and implements.
- **#494:** resonance stays a power budget, so stronger gear costs more.
  Hedault's trueing lowers an item's resonance (a craft discount). The
  sleep-beat toast is reworded to match. The #570 capacity curve (4 at
  creation, 5 after the once-only growth) is unchanged.

Base: `69bd9cf5` (main). Branch: `issue/514-gear-rules`.

## 1. Classification rule

One function decides an arm's damage source:
`WICombatBuild.damage_source(skill)`. The engine, the competent policy, the
item and Skill text and the inventory reach line all call it, so none of them
can disagree.

| Effect type | Skill carries a `weapon` gate | Source |
|---|---|---|
| `damage_mult` | either | weapon |
| `riposte` ([Counter Strike]) | n/a | weapon |
| `blast_damage` with `windup_rounds` (resolves through the windup strike) | n/a | weapon |
| `spell_damage`, `line_damage`, `blast_damage` | yes | weapon |
| `spell_damage`, `line_damage`, `blast_damage` | no | spell |
| anything else | n/a | none (deals no hit damage) |

A Skill is weapon-gated physical exactly when its record has a `weapon` key.
That is the same key `WICombatBuild.weapon_gated_kit` already uses to strip a
Skill when the wrong weapon is held, so a Skill can never be "physical" for
damage and "ungated" for the kit.

## 2. Effect matrix

"Weapon damage" is the combatant's `damage_mod`: the weapon's plus every
equipped accessory's, plus an armed meal's `next_fight.damage_mod`. That is
the pool ordinary melee already used. "Spell power" is the new combatant field
`spell_power`, summed over the equipped weapon, armor and accessories. Enemies
and allies carry neither unless their own record sets it; no shipped
combatant does.

| Arm | Shipped examples | Damage source | Scaling stat | Gear contribution | Reactions and tallies |
|---|---|---|---|---|---|
| Ordinary attack (`attack()`) | sword swing, bow shot | weapon die | STR (unchanged) | weapon damage (unchanged) | Counter Strike may answer; `melee_hit`/`ranged_hit` (unchanged) |
| `damage_mult` | [Power Strike], [Quick Slash], [Spellbound Strike], [Blinding Arrow], [Sudden Strike] | weapon die × mult | STR (unchanged) | weapon damage, after the multiplier (unchanged) | unchanged |
| `riposte` | [Counter Strike] | weapon die × mult | STR (unchanged) | weapon damage (unchanged) | n/a |
| Windup blast | [Slam] (enemy only) | weapon die | STR (unchanged) | weapon damage (unchanged) | unchanged |
| **Weapon-gated line** | [Crescent Cut] (sword), [Pierce Thrust] (spear), [Piercing Shot], [Piercing Volley] (bow) | weapon die | **STR** (was INT) | **weapon damage** (was none) | unchanged: no riposte, no `melee_hit` tally, `ATTACK_RESOLVED.melee` stays false |
| Spell line | [Flame Jet], [Phantom Barrage] | die | INT (unchanged) | **spell power** (was none) | unchanged |
| `spell_damage` | [Flame Bolt], [Frost Bolt], [Ice Shard], [Flame Scythe], [Flare Burst], [Flame Dart], [Bone Dart], [Deathbolt], [Thorn Hand], [Bramble Hand], [Evil Eye], [Calming Touch]; enemy [Raskghar Maul], Lich casts | die | INT (unchanged) | **spell power** (was none) | unchanged |
| Spell blast | [Flame Pillar] | die | INT (unchanged) | **spell power** (was none) | unchanged |
| Burning tick | [Flame Bolt]'s rider | fixed tick | none | none (unchanged) | unchanged |

The die in every row is the attacker's `weapon_die`, as today. Neither
contribution is multiplied by an arm's `mult`; both are added after it, as
`damage_mod` already was. Difficulty, damage reduction, weakened/guarded and
[Mana Shield] apply afterwards, unchanged.

Spell power applies to every non-weapon spell, line and blast arm, including
[Evil Eye], [Calming Touch] and [Phantom Barrage]. These already scale off
INT, and the controller's rule classifies by the `weapon` gate rather than
by element or MP cost. This is surfaced as an open question (§9) rather than
silently narrowed.

The combined weapon-damage pool for gated lines (weapon plus accessories plus
meal, rather than the weapon alone) follows "like ordinary melee". A
weapon-only split would need a second field, and every accessory card that
says "+1 damage on attacks and weapon Skills" would then be false for lines.

## 3. Affected items

All items with `damage_mod > 0` now also improve weapon-gated lines. These are
the weapons `relcs_spare_spear`, `gnollish_hunting_knife`, `hunting_bow`,
`guardsmans_pike`, `hedault_trued_spear`, `wyvernbone_lance`,
`recurve_of_the_watch` and `ashwood_warbow`, and the accessories
`hunters_fang_talisman`, `moon_bone_amulet`, `kingslayer_fang`,
`moonhide_fetish` and `hedaults_hunters_fang`. Their stats do not change; only
their reach and wording do.

### Implements and spell power (starting values)

The only shipped implements are the two wands. Both are accessories (the
#438 engine reasons recorded on the rows still hold). Each wand's `damage_mod`
point moves to `spell_power`. A wand that sharpens sword swings contradicts
the new rule's fiction, and `damage_mod` on a wand was inert for the casters
it was built for. Resonance is unchanged, because resonance never increases
in this lane (§6).

| Item | Before | Proposed | Resonance |
|---|---|---|---|
| `graveflame_wand` (T2, 30g, Wilovan) | +1 damage, +3 HP | **+1 spell power**, +3 HP | 2 (unchanged) |
| `lichbone_wand` (T3, Lich loot) | +1 damage, +3 HP, 1 DR | **+2 spell power**, +3 HP, 1 DR | 3 (unchanged) |

The ladder +1/+2 mirrors the weapon rungs (T2 +1, T3/Hedault +2). It is a
measurement-led proposal. The probe in §8 sweeps spell power 0–3 on the
caster yardsticks; the value moves only if a wand-wearing caster cell crosses
a ceiling.

### Hedault's trueing (craft discount)

The shipped resonance of each Hedault product is its power-budget price. His
trueing hands it back one point below that price, never below zero. Stat lines
and granted abilities are unchanged, so the discount is the new upgrade axis
on top of what each correction already added.

| Hedault arm | Source → product | Product resonance |
|---|---|---|
| Improve it (20g) | `traveler_charm` (1) → `hedaults_traveler_charm` | 1 → **0** |
| More than a trophy (35g) | `hunters_fang_talisman` (1) → `hedaults_hunters_fang` | 1 → **0** |
| Set it true (40g) | `witch_wardstone_bead` (1) → `hedaults_wardstone` | 2 → **1** |
| Fragment trade | `guardian_ward_fragment` (1) → `hedaults_warded_setting` | 1 → **0** |
| Correct it (35g) | `relcs_spare_spear` (0) → `hedault_trued_spear` | 0 → 0 (mundane; nothing to discount) |

Data marker: each product carries `"trued_from": "<source id>"`.
`tests/test_items.gd` enforces these rules:

- A product may be enchanted at resonance 0, which is otherwise a
  mundane-only value.
- A product never costs more resonance than its source.
- Every `trued_from` names the item the Hedault arm actually consumes.

Consequence: a trueing can never make a loadout illegal. The Wardstone used to
cost one more than the bead it consumed; now it costs the same.

## 4. Preview and effect wording

Player-facing currency only (damage, HP, Resonance, Skill names); no
attribute names.

| Surface | Before | After |
|---|---|---|
| Item card, `damage_mod` (any kind) | "+N damage on melee hits" / "+N damage on ranged hits" | "+N damage on attacks and weapon Skills" |
| Item card, `spell_power` | — | "+N damage on spells" |
| Item card, enchanted at resonance 0 | (no line) | "Resonance 0" |
| Skill card, `spell_damage` | "damage 1d6 at range 4" | "spell damage 1d6 at range 4" |
| Skill card, gated line | "damage everything in a line 3 cells long" | "weapon damage to everything in a line 3 cells long" |
| Skill card, spell line | "damage everything in a line 4 cells long" | "spell damage to everything in a line 4 cells long" |
| Skill card, blast | "…for 1d6. Hits friend and foe." | "…for 1d6 spell damage. Hits friend and foe." (windup: "weapon damage") |
| Skill card, `damage_mult` | "×2 damage" | unchanged (it multiplies the weapon hit) |
| Inventory detail, damage item | — | "Improves your attacks, [Power Strike] and [Crescent Cut]." (the Skills you would hold with it equipped) |
| Inventory detail, spell item | — | "Improves your [Frost Bolt] and [Flame Jet]." or "Improves none of your current Skills." |
| Inventory detail, unworn equipment | — | "If worn: Resonance 3/4" or "If worn: Resonance 6/5, more than you can hold" or "No free accessory position" |
| Hedault option preview (swap) | product card | product card with "Resonance 1 → 0" in place of its resonance line when the trueing lowers it |
| Sleep-beat toast | "…before the pieces start arguing…" | "Resonance is how much enchantment you can wear at once. Stronger pieces take more of it, and crude work argues louder than its strength; a properly trued piece keeps quiet. Yours grew by one in the night. The anchor stone paid for it." |

The "If worn" line and `equip()` share one plan function (slot choice,
displaced-slot subtraction, capacity check), so the preview and the refusal
cannot disagree. The equip-refusal toast keeps its ratified copy. The four
trued accessories' descriptions gain one sentence of quiet-craft fiction.

## 5. Implementation map

- `combat_build.gd`: `damage_source()`, `damage_reach()`, and `spell_power`
  in `equipment_mods()`.
- `wi_combat.gd`: `_build_combatant` carries `spell_power`. `_resolve_hit`
  takes an optional source, and two statics, `hit_stat()` and `hit_flat()`,
  replace the inline `str`/`int` and `damage_mod` reads.
- `skill_effects.gd`: the `spell_damage`, line and blast arms pass
  `damage_source(skill)`. The `damage_mult` and windup arms stay melee
  weapon hits.
- `qa/combat_policies.gd`: `expected_damage`/`potential_damage` call the
  same statics, so the competent policy ranks with the engine's numbers.
- `wi_game.gd`: the player config carries `spell_power`. It also gains
  `equip_plan()`, shared by `equip()` and the preview, and `gear_reach()`.
- `effect_text.gd`, `dialogue.gd`, `inventory.gd`: the wording in §4.
- `sleep_beat.gd`: the toast.
- `data/items.json`: wand stats, Hedault resonance, `trued_from` and
  descriptions (surgical edits, `data_lint` before and after).
- Harness builders (`sim_combat_batch._build_pc` and the loadout loop,
  `sim_class_parity`) carry `spell_power` so they keep mirroring the runtime.

## 6. Old saves

No new save state; `WISave.VERSION` is unchanged. Spell power is derived from
the equipped item ids at combatant build, so a loaded save picks up the new
rule on its next fight.

- No item's resonance increases, so a loadout that fit before still fits.
- Saves holding Hedault products now use less resonance than before, which
  is the discount the ruling grants.
- Wand HP is unchanged, so `vitals.reconcile` moves nothing on load.
- A wand-wearer's next fight loses the wand's +1 weapon damage and gains its
  spell power.

Tests load a pre-change-shaped v12 save and a v10 legacy save with Hedault
products and a wand equipped. They assert the save applies, the loadout fits,
`resonance_used` drops by the discount, and the live combatant carries the
spell power.

## 7. Re-measure plan

Legs at base `69bd9cf5` and at the branch head, all 100 seeds:

1. `tests/sim_combat_batch.gd` plain (the gated floor-policy bands).
2. `WI_POLICY=competent` (ladder ordering gate; per-cell report).
3. `WI_ENTRY_FRACTION=0.75` (report).
4. `tests/sim_spine_viability.gd`: reference climaxes, calibration rows and
   ruled windows (gated); per-spine table (report).
5. `tests/sim_progression_pace.gd`, floor and competent. Real fights feed the
   pace bands, so a damage change can move pace.
6. `tests/sim_class_paths.gd` is progression-only (counter accumulation, no
   combat) and cannot be moved by a damage rule. It is not run.
7. `tests/_spell_power_probe.gd` (new instrument, not a gate): caster
   yardsticks at spell power 0–3 and with each wand, both policies.

`python3 scripts/harness_entry_report.py` compares base and head per leg.

Expected movers, from the matrix above:

- The floor policy never casts a line, and no harness caster wears an
  implement, so the plain gated bands should not move.
- Competent cells whose kit holds a gated line should move: [Crescent Cut]
  on swordsman14, [Pierce Thrust] on spearmaster14 and spellspear/skirmisher
  at Act V, and [Piercing Shot] and [Piercing Volley] on sharpshooter14,
  ranger and scout.

Doctrine bindings:

- No build auto-wins. The competent column is the authority.
- Ruled windows never widen, and no encounter is tuned to green an autoplay
  pin.
- If a gated band fails, the only levers are this document's spell-power
  values and trueing values.
- If a ruled window becomes unreachable with those, STOP and report the
  cells.

## 8. Measurements

Pending: filled in after implementation from the legs above.

## 9. Open questions

- Spell power reaches [Evil Eye], [Calming Touch] and [Phantom Barrage]
  because the rule classifies by weapon gate. Narrowing it to elemental or
  MP-cost spells would be a separate ruling.
- Gated lines take the whole weapon-damage pool, accessories and meals
  included ("like ordinary melee"), not the weapon's `damage_mod` alone.
- Meal and oil cards still read "Next fight: +N damage"; that pool now also
  reaches gated lines. The wording is unchanged here.
- A Hedault swap unequips the consumed piece silently (shipped behaviour).
  Re-equipping the product into the same slot would now always fit, because
  of the trueing invariant, but it is not done here.
