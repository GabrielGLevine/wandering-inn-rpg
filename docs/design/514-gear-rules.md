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

Base: `69bd9cf5` (main), rebased onto `842ef6e9` (#513, #590, #591).
Branch: `issue/514-gear-rules`.

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
`tests/test_items.gd` and `tests/test_gear_rules.gd` enforce these rules:

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
| Inventory detail, unworn accessory (or any piece whose swap would move the total) | — | "If worn: Resonance 3/4", "If worn: Resonance 5/4, more than you can hold" or "If worn: no free accessory slot", drawn above the reach line |
| Hedault option preview (swap) | product card | product card with "Resonance 1 → 0" in place of its resonance line when the trueing lowers it |
| Sleep-beat toast | "…before the pieces start arguing…" | "Resonance is how much enchantment you can wear at once. Stronger pieces take more of it, and crude work argues louder than its strength; a properly trued piece keeps quiet. Yours grew by one in the night. The anchor stone paid for it." |

The "If worn" line and `equip()` share one plan function (slot choice,
displaced-slot subtraction, capacity check), so the preview and the refusal
cannot disagree. Weapons and armour cannot move the total, so they show only
the reach line. The combat HUD's slot record carries each Skill's weapon gate,
so the bar's readout and the journal compose the same source tag. The equip-refusal toast keeps its ratified copy. The four
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
- `combat_hud.gd`: the slot record carries `weapon`. The combat snapshot exposes
  per-combatant `damage_mod` and `spell_power` for QA.
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

Measured twice, with the same result:

- base `69bd9cf5` against `cf3e680a`, the last pre-rebase commit to touch
  combat resolution or data;
- after the rebase, main `842ef6e9` (tree `efc36598`) against `b6f77e8d`.

Every leg ran 100 seeds, exited 0, printed its success marker and logged no
engine noise. The table reads the post-rebase pair.

| Leg | Base | Branch | Cells moved |
|---|---|---|---|
| `sim_combat_batch` rested (gated bands) | PASS, 147 cells | PASS; log byte-identical | 0 |
| `WI_POLICY=competent` (ladder gate) | PASS, 0.88 > 0.89 > 0.87 > 0.70 | identical | 0 |
| `WI_ENTRY_FRACTION=0.75` | report | byte-identical | 0 |
| `sim_spine_viability` (5 calibration, 5 climaxes, 2 ruled) | PASS | log byte-identical | 0 |
| `sim_progression_pace` floor | PASS | byte-identical | none |
| `sim_progression_pace` competent | PASS | ranger spine only | see below |

`harness_entry_report.py` against the base logs (full table in the appendix):
rested, competent and 0.75 read the same 147 cells at the same rates on both
trees. The summaries are
mean drop vs rested 0.000 / −0.070 / 0.209 and cells below 0.55 48 / 39 / 90,
each identical to base.

The only change is in the competent pace leg's ranger spine (archer then
sharpshooter, bow at every act):

- Act III: p10 total level 17 → 18; the p50 build reads sharpshooter11/warrior7
  where it read sharpshooter11/warrior8; ranged_hit p50 73 → 74.
- Act V: ranged_hit p50 159 → 158.
- No other spine moved.

**Why the gated matrix cannot move.**

- No harness build wears an implement, so spell power is 0 in every cell.
- Both policies fire a line only when it would cross two or more enemies and no
  ally (`WICombatAI._act_line`). A scratch count of the competent leg's gated-line
  holders found zero casts in 100 fights each: swordsman14_solo ([Crescent Cut]),
  spearmaster14_solo ([Pierce Thrust]), sharpshooter14_solo ([Piercing Shot],
  [Piercing Volley]) and side_vault_construct_t5_swordsman14_solo. The floor
  policy never casts a line.
- The pace sim's ranger spine is the one measured place a gated line fires.

**Gated bands:** all hold. No band was widened and no encounter, seed or
window was touched. No lever was pulled and there is no STOP.

### Spell power (`tests/_spell_power_probe.gd`)

The caster cells at spell power 0–3, and with each wand worn. "Pre" is the
wand as it shipped before #514 (one inert point of weapon damage), so
pre → shipped is the ruling's effect on a wand-wearer. The sp0 column
reproduces the matrix exactly.

| Cell | Policy | sp0 | sp1 | sp2 | sp3 | Graveflame pre | Graveflame | Lichbone pre | Lichbone |
|---|---|---|---|---|---|---|---|---|---|
| second_wind / fire_mage14_solo | dumb | 0.74 | 0.77 | 0.81 | 0.81 | 0.82 | 0.81 | 0.90 | 0.91 |
| second_wind / fire_mage14_solo | competent | 0.79 | 0.83 | 0.85 | 0.85 | 0.85 | 0.86 | 0.92 | 0.93 |
| second_wind / ice_mage14_solo | dumb | 0.60 | 0.61 | 0.63 | 0.64 | 0.70 | 0.65 | 0.80 | 0.71 |
| second_wind / ice_mage14_solo | competent | 0.51 | 0.53 | 0.54 | 0.54 | 0.62 | 0.60 | 0.72 | 0.62 |
| encounter / mage3_necromancer3_goblin_ambush_solo | dumb | 0.57 | 0.73 | 0.77 | 0.80 | 0.64 | 0.75 | 0.72 | 0.88 |
| encounter / mage3_necromancer3_goblin_ambush_solo | competent | 0.65 | 0.77 | 0.78 | 0.81 | 0.84 | 0.85 | 0.90 | 0.92 |
| encounter / mage5_necromancer7_raskghar_scouts_solo | dumb | 0.72 | 0.74 | 0.78 | 0.79 | 0.83 | 0.79 | 0.93 | 0.94 |
| encounter / mage5_necromancer7_raskghar_scouts_solo | competent | 0.64 | 0.66 | 0.70 | 0.70 | 0.74 | 0.71 | 0.82 | 0.83 |
| encounter / mage3_necromancer3_goblin_ambush_with_skeleton | dumb | 0.62 | 0.73 | 0.75 | 0.78 | 0.68 | 0.74 | 0.77 | 0.81 |
| encounter / mage3_necromancer3_goblin_ambush_with_skeleton | competent | 0.46 | 0.55 | 0.57 | 0.58 | 0.55 | 0.55 | 0.66 | 0.66 |
| encounter / mage5_necromancer7_raskghar_scouts_with_skeleton | dumb | 0.92 | 0.92 | 0.92 | 0.92 | 0.94 | 0.93 | 0.96 | 0.95 |
| encounter / mage5_necromancer7_raskghar_scouts_with_skeleton | competent | 0.92 | 0.92 | 0.92 | 0.92 | 0.94 | 0.93 | 0.95 | 0.94 |
| encounter / druid14_raskghar_scouts_with_wolf | dumb | 0.90 | 0.91 | 0.93 | 0.94 | 0.90 | 0.91 | 0.95 | 0.97 |
| encounter / druid14_raskghar_scouts_with_wolf | competent | 0.90 | 0.90 | 0.93 | 0.94 | 0.92 | 0.90 | 0.96 | 0.98 |
| ruin / briar_arch_wards_mage11_relc | dumb | 0.65 | 0.78 | 0.84 | 0.85 | 0.78 | 0.85 | 0.86 | 0.91 |
| ruin / briar_arch_wards_mage11_relc | competent | 0.54 | 0.58 | 0.63 | 0.66 | 0.93 | 0.95 | 0.96 | 0.98 |
| ruin / briar_arch_wards_mage11_solo | dumb | 0.38 | 0.40 | 0.43 | 0.49 | 0.55 | 0.49 | 0.63 | 0.56 |
| ruin / briar_arch_wards_mage11_solo | competent | 0.09 | 0.08 | 0.08 | 0.08 | 0.47 | 0.41 | 0.57 | 0.43 |
| composition / goblin_ambush | dumb | 0.98 | 0.98 | 1.00 | 1.00 | 0.98 | 0.98 | 1.00 | 1.00 |
| composition / goblin_ambush | competent | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| composition / chieftains_raid | dumb | 0.84 | 0.85 | 0.85 | 0.85 | 0.86 | 0.87 | 0.88 | 0.89 |
| composition / chieftains_raid | competent | 0.72 | 0.73 | 0.73 | 0.75 | 0.76 | 0.75 | 0.80 | 0.78 |

Reading:

- One point of spell power lifts the caster cells by 0.00–0.16; the
  necromancer and briar-arch cells gain most.
- Moving the wand's point from weapon damage to spell power is a sidegrade.
  It rises where the build casts (mage3_necromancer3 0.64 → 0.75 floor) and
  falls where an out-of-MP caster bonks (ice_mage14 0.70 → 0.65 floor,
  briar_arch_wards_mage11_solo 0.47 → 0.41 competent).
- With the Lichbone Wand, druid14 (0.96 → 0.98) and briar_arch_wards_mage11
  with Relc (0.96 → 0.98) sit above a 0.95 ceiling at competent. The
  pre-#514 wand already put both there through its +3 HP and 1 DR, so spell
  power adds 0.02.
- None of these is a gated cell (every band is authored gearless), so the
  wand values hold at 1 and 2.

### Trueing

No harness, spine or pace build carries a Hedault product, so the trueing
values cannot move a measured cell. Their effect is capacity, proven in
`tests/test_gear_rules.gd` and `hedault_trueing_loop`: Traveler's Charm plus
Anchor Sliver is 4/4 and refuses the Hedge-Ward Charm. After the trueing the
charm costs 0, and the same Hedge-Ward Charm fits at 4/4.

`scripts/analysis/capacity_570.py --check` now differs from the dated #570
table. Row D's three Hedault pieces cost 1, not 4, and wand flat damage moved
to spell power. That table is a snapshot of `b1c4b02b`; it is not
regenerated here.

## 9. Journey impact

Before the rebase, `python3 wandering_inn_game/qa/journey_gate.py` at
`38948d63`:

| Route | Script | Result |
|---|---|---|
| rogue | `journey_rogue` | ok (3509/3509 steps, full-ending checkpoint) |
| generalist | `journey_worker` | ok (3998/3998) |
| martial | `steel_thread` | ok (3134/3134) |
| caster | `journey_caster` | ok (3782/3782) |
| imperfect | `journey_imperfect` | FAIL on two text pins only |

`journey_imperfect` fails at steps 3048 and 3163. Both are Krshia's `charms`
preview, pinning the Hunter's Fang Talisman card as "+1 damage on melee
hits"; it now reads "+1 damage on attacks and weapon Skills".

The route itself still completes. It runs all 4115 steps, reaches
`imperfect_full_ending` and keeps the same ledger (8 wins, 2 losses). No fight
outcome moved in any journey, because no journey wears an implement or casts
a gated line. Pins are left for the controller's post-rebase update, as
instructed.

After the rebase onto `842ef6e9`, the controller released the journey pins.
`journey_imperfect`'s two charms waits now pin the new wording. That is the
fang's actual reach under #495, and both waits assert the same full options
array. The rerun at `b6f77e8d` passes every journey:

| Route | Script | Steps | Ledger | Result |
|---|---|---|---|---|
| rogue | `journey_rogue` | 3509/3509 | 8W/3L/0A, 18 sleeps, 4g | ok |
| generalist | `journey_worker` | 3998/3998 | 8W/7L/1A, 16 sleeps, 2g | ok |
| martial | `steel_thread` | 3134/3134 | 12W/3L/0A, 14 sleeps, 0g | ok |
| caster | `journey_caster` | 3782/3782 | 8W/0L/0A, 12 sleeps, 0g | ok |
| imperfect | `journey_imperfect` | 4122/4122 | 8W/2L/0A, 20 sleeps, 2g | ok |

`scripts/journey_ledger.py` regenerated over the passing `journey_imperfect`
run reproduces `571-ledger-imperfect.md`'s ledger block byte for byte (main's
#513 version). No other journey's script changed and no ledger needed an edit.
No wall moved, so the 2026-10-07 retry ruling was not exercised.

## 10. Open questions

- Spell power reaches [Evil Eye], [Calming Touch] and [Phantom Barrage]
  because the rule classifies by weapon gate. Narrowing it to elemental or
  MP-cost spells would be a separate ruling.
- Gated lines take the whole weapon-damage pool, accessories and meals
  included ("like ordinary melee"), not the weapon's `damage_mod` alone.
- Meal and oil cards still read "Next fight: +N damage"; that pool now also
  reaches gated lines. The wording is unchanged here.
- The batch harness cannot see the #495 line change: neither policy aims a
  gated line in any matrix cell. A cell or policy that lines up two foes would
  be needed to measure it as anything but a report.
- The combat bar's one-line readout already clipped [Piercing Shot]'s cooldown
  clause; the "weapon damage to" wording clips seven more characters of it.
- A Hedault swap unequips the consumed piece silently (shipped behaviour).
  Re-equipping the product into the same slot would now always fit, because
  of the trueing invariant, but it is not done here.

## Appendix: harness entry report

`python3 scripts/harness_entry_report.py` over the post-rebase logs, baseline
`base_rested` (main `842ef6e9`); `head_*` is `b6f77e8d`.

<details><summary>All 147 cells</summary>

| Cell | Build | base_rested | head_rested | base_competent | head_competent | base_0.75 | head_0.75 |
|---|---|---|---|---|---|---|---|
| encounter / rock_crab_nest_t1_relc | warrior2 | 0.84 | 0.84 | 0.97 | 0.97 | 0.07 | 0.07 |
| party / vault_construct_t4_spellsword14_party (measured) | t4_spellsword14_party | 0.90 | 0.90 | 0.93 | 0.93 | 0.24 | 0.24 |
| party / vault_construct_t4_party | t4_spellsword11_party | 0.85 | 0.85 | 0.78 | 0.78 | 0.20 | 0.20 |
| party / vault_construct_t4_party_guided (measured) | t4_spellsword11_party | 0.85 | 0.85 | 0.78 | 0.78 | 0.20 | 0.20 |
| encounter / camp_ground_press_t1_rags_ally | warrior2 | 0.63 | 0.63 | 0.70 | 0.70 | 0.08 | 0.08 |
| bestiary / forge_temper_golem_t5_sw14_solo | t4_spellsword14_party | 0.67 | 0.67 | 0.89 | 0.89 | 0.20 | 0.20 |
| second_wind / beast_master14_raskghar_scouts_with_wolf (measured) | beast_master14 | 0.69 | 0.69 | 0.70 | 0.70 | 0.24 | 0.24 |
| riverfarm / river_wolf_pack_t3_hunter (measured) | t3_warrior10 | 0.86 | 0.86 | 0.84 | 0.84 | 0.42 | 0.42 |
| encounter / camp_ground_press_t1_spear_ally | warrior2 | 0.63 | 0.63 | 0.78 | 0.78 | 0.20 | 0.20 |
| ruin / rift_vermin_leak_w8_relc | warrior5_mage5 | 0.72 | 0.72 | 0.99 | 0.99 | 0.29 | 0.29 |
| bestiary / forge_calibration_golem_t5_sw14_solo | t4_spellsword14_party | 0.69 | 0.69 | 0.87 | 0.87 | 0.26 | 0.26 |
| scaled / forge_calibration_golem_t5_gold | gold_spellsword22 | 0.70 | 0.70 | 0.87 | 0.87 | 0.27 | 0.27 |
| bestiary / market_watchgolems_t4_solo (measured) | t4_spellsword11_party | 0.84 | 0.84 | 0.96 | 0.96 | 0.42 | 0.42 |
| bestiary / forge_calibration_golem_t4_solo (measured) | t4_spellsword11_party | 0.57 | 0.57 | 0.62 | 0.62 | 0.16 | 0.16 |
| riverfarm / briar_collectors_deep_t5_sw14_solo | t4_spellsword14_party | 0.87 | 0.87 | 0.88 | 0.88 | 0.48 | 0.48 |
| encounter / beast_master10_raskghar_scouts_with_wolf | beast_master10_melee | 0.95 | 0.95 | 0.94 | 0.94 | 0.56 | 0.56 |
| scaled / gallery_vermin_nest_t4_silver | t4_spellsword14_party | 0.67 | 0.67 | 0.99 | 0.99 | 0.29 | 0.29 |
| encounter / pond_guardian_t1_runner5_warrior5_solo | t1_runner5_warrior5 | 0.61 | 0.61 | 0.81 | 0.81 | 0.23 | 0.23 |
| invrisil / rest_bravos_t3_warrior10_solo | t3_warrior10 | 0.77 | 0.77 | 0.73 | 0.73 | 0.39 | 0.39 |
| second_wind / strategist14_solo (measured) | strategist14 | 0.77 | 0.77 | 0.98 | 0.98 | 0.39 | 0.39 |
| scaled / gallery_vermin_nest_t4_gold | gold_spellsword16 | 0.54 | 0.54 | 0.97 | 0.97 | 0.16 | 0.16 |
| encounter / mage5_necromancer7_raskghar_scouts_solo | mage5_necromancer7_caster | 0.72 | 0.72 | 0.64 | 0.64 | 0.34 | 0.34 |
| second_wind / sharpshooter14_solo | sharpshooter14 | 0.66 | 0.66 | 0.97 | 0.97 | 0.29 | 0.29 |
| encounter / shield_spiders_w2_solo (measured) | warrior2 | 0.54 | 0.54 | 0.70 | 0.70 | 0.18 | 0.18 |
| riverfarm / granary_scavengers_t3_warrior10_solo | t3_warrior10 | 0.58 | 0.58 | 0.50 | 0.50 | 0.22 | 0.22 |
| second_wind / infiltrator14_solo | infiltrator14 | 0.62 | 0.62 | 0.75 | 0.75 | 0.26 | 0.26 |
| scaled / forge_calibration_golem_t5_silver | t4_spellsword14_party | 0.53 | 0.53 | 0.76 | 0.76 | 0.18 | 0.18 |
| riverfarm / riverfarm_thicket_patch_t3_solo | t3_warrior10 | 0.50 | 0.50 | 0.52 | 0.52 | 0.15 | 0.15 |
| ruin / briar_arch_wards_mage11_relc (measured) | p5_mage11_caster | 0.65 | 0.65 | 0.54 | 0.54 | 0.31 | 0.31 |
| riverfarm / thicket_line_den_t3_warrior10_solo | t3_warrior10 | 0.53 | 0.53 | 0.47 | 0.47 | 0.19 | 0.19 |
| invrisil / counting_room_guard_t3_warrior10_solo | t3_warrior10 | 0.38 | 0.38 | 0.53 | 0.53 | 0.04 | 0.04 |
| encounter / rags_scouting_party_t1_solo | warrior2 | 0.72 | 0.72 | 0.76 | 0.76 | 0.38 | 0.38 |
| bestiary / corusdeer_range_t1_solo (measured) | warrior2 | 0.72 | 0.72 | 0.88 | 0.88 | 0.38 | 0.38 |
| bestiary / kingslayer_den_t4_solo (measured) | t4_spellsword11_party | 0.86 | 0.86 | 0.87 | 0.87 | 0.52 | 0.52 |
| invrisil / boulevard_duel_ring_t3_solo | t3_warrior10 | 0.64 | 0.64 | 0.71 | 0.71 | 0.31 | 0.31 |
| encounter / raskghar_scouts_w2_solo (measured) | warrior2 | 0.49 | 0.49 | 0.59 | 0.59 | 0.16 | 0.16 |
| encounter / goblin_night_patrol_t1_solo (measured) | warrior2 | 0.72 | 0.72 | 0.79 | 0.79 | 0.39 | 0.39 |
| encounter / beast_tamer5_goblin_ambush_with_wolf | beast_tamer5_melee | 0.87 | 0.87 | 0.82 | 0.82 | 0.54 | 0.54 |
| chieftains_raid / warrior2_helper2 (measured) | warrior2_helper2 | 0.78 | 0.78 | 0.77 | 0.77 | 0.46 | 0.46 |
| encounter / raskghar_scouts_w5_solo (measured) | warrior5_mage5 | 0.94 | 0.94 | 0.94 | 0.94 | 0.62 | 0.62 |
| chieftains_raid / warrior2 | warrior2 | 0.77 | 0.77 | 0.76 | 0.76 | 0.46 | 0.46 |
| dungeon / gallery_vermin_nest_t4_solo | t4_spellsword11_party | 0.81 | 0.81 | 0.98 | 0.98 | 0.51 | 0.51 |
| loadout / warrior1_tutorial_solo_armored (measured) | warrior1_tutorial_solo | 0.43 | 0.43 | 0.43 | 0.43 | 0.13 | 0.13 |
| encounter / mage3_necromancer3_goblin_ambush_with_skeleton | mage3_necromancer3_caster | 0.62 | 0.62 | 0.46 | 0.46 | 0.32 | 0.32 |
| loadout / warrior1_tutorial_solo_max_legal_kit (measured) | warrior1_tutorial_solo | 0.52 | 0.52 | 0.52 | 0.52 | 0.23 | 0.23 |
| ruin / briar_arch_wards_warrior11_relc | p5_warrior11 | 0.81 | 0.81 | 0.88 | 0.88 | 0.52 | 0.52 |
| ruin / briar_arch_wards_mage11_solo (measured) | p5_mage11_caster | 0.38 | 0.38 | 0.09 | 0.09 | 0.10 | 0.10 |
| invrisil / alley_fence_t3_warrior10_solo | t3_warrior10 | 0.38 | 0.38 | 0.45 | 0.45 | 0.09 | 0.09 |
| second_wind / swordsman14_solo | swordsman14 | 0.33 | 0.33 | 0.63 | 0.63 | 0.04 | 0.04 |
| goblin_ambush / pure_warrior10 (measured) | pure_warrior10 | 0.97 | 0.97 | 0.99 | 0.99 | 0.68 | 0.68 |
| loadout / chieftains_hp_stack (measured) | warrior2 | 0.81 | 0.81 | 0.78 | 0.78 | 0.53 | 0.53 |
| ruin / briar_arch_wards_warrior11_solo (measured) | p5_warrior11 | 0.46 | 0.46 | 0.43 | 0.43 | 0.18 | 0.18 |
| invrisil / alley_footpads_w2_solo | warrior2 | 0.86 | 0.86 | 0.91 | 0.91 | 0.58 | 0.58 |
| bestiary / road_mothbears_t3_solo (measured) | t3_warrior10 | 0.57 | 0.57 | 0.49 | 0.49 | 0.29 | 0.29 |
| invrisil / hired_blades_t3_spellsword9_wilovan (measured) | t3_spellsword9 | 0.47 | 0.47 | 0.74 | 0.74 | 0.20 | 0.20 |
| chieftains_raid / warrior2_mage2 (measured) | warrior2_mage2 | 0.94 | 0.94 | 0.94 | 0.94 | 0.67 | 0.67 |
| goblin_ambush / warrior1_tutorial_solo (measured) | warrior1_tutorial_solo | 0.34 | 0.34 | 0.43 | 0.43 | 0.08 | 0.08 |
| encounter / druid14_raskghar_scouts_with_wolf | druid14_caster | 0.90 | 0.90 | 0.90 | 0.90 | 0.64 | 0.64 |
| riverfarm / briar_collectors_deep_t3_warrior10_solo | t3_warrior10 | 0.38 | 0.38 | 0.30 | 0.30 | 0.12 | 0.12 |
| second_wind / spearmaster14_solo | spearmaster14 | 0.37 | 0.37 | 0.64 | 0.64 | 0.11 | 0.11 |
| ruin / ruin_guardian_w8_relc | warrior5_mage5 | 0.38 | 0.38 | 0.95 | 0.95 | 0.13 | 0.13 |
| chieftains_raid / warrior1_tutorial (measured) | warrior1_tutorial | 0.47 | 0.47 | 0.51 | 0.51 | 0.23 | 0.23 |
| invrisil / hired_blades_t5_sw14_wilovan | t4_spellsword14_party | 0.70 | 0.70 | 0.89 | 0.89 | 0.46 | 0.46 |
| dungeon / trapped_halls_snare_t4_solo | t4_spellsword11_party | 0.42 | 0.42 | 0.91 | 0.91 | 0.19 | 0.19 |
| second_wind / fire_mage14_solo | fire_mage14 | 0.74 | 0.74 | 0.79 | 0.79 | 0.51 | 0.51 |
| loadout / warrior2_mage2_gambeson (measured) | warrior2_mage2 | 0.96 | 0.96 | 0.96 | 0.96 | 0.74 | 0.74 |
| invrisil / hired_blades_t4_sw11_wilovan (measured) | t4_spellsword11_party | 0.49 | 0.49 | 0.78 | 0.78 | 0.27 | 0.27 |
| bestiary / market_watchgolems_t5_sw14_solo (measured) | t4_spellsword14_party | 0.97 | 0.97 | 0.98 | 0.98 | 0.75 | 0.75 |
| second_wind / ice_mage14_solo | ice_mage14 | 0.60 | 0.60 | 0.51 | 0.51 | 0.38 | 0.38 |
| boss / awakened_boss_w2_relc | warrior2 | 0.49 | 0.49 | 0.54 | 0.54 | 0.28 | 0.28 |
| dungeon / seal_warden_t5_sw14_solo | t4_spellsword14_party | 0.34 | 0.34 | 0.70 | 0.70 | 0.14 | 0.14 |
| riverfarm / briar_collectors_t3_warrior10_solo | t3_warrior10 | 0.33 | 0.33 | 0.28 | 0.28 | 0.14 | 0.14 |
| encounter / pond_guardian_t1_warrior2_solo (measured) | warrior2 | 0.24 | 0.24 | 0.59 | 0.59 | 0.06 | 0.06 |
| chieftains_raid / warrior5_mage5 (measured) | warrior5_mage5 | 0.97 | 0.97 | 1.00 | 1.00 | 0.79 | 0.79 |
| loadout / warrior2_spear (measured) | warrior2 | 0.97 | 0.97 | 0.99 | 0.99 | 0.79 | 0.79 |
| loadout / warrior2_mage2_stonescale_dr2 (measured) | warrior2_mage2 | 0.97 | 0.97 | 1.00 | 1.00 | 0.79 | 0.79 |
| goblin_ambush / warrior1_tutorial (measured) | warrior1_tutorial | 0.97 | 0.97 | 0.97 | 0.97 | 0.80 | 0.80 |
| goblin_ambush / warrior5_mage5 (measured) | warrior5_mage5 | 0.99 | 0.99 | 1.00 | 1.00 | 0.83 | 0.83 |
| loadout / kingslayer_fang_solo (measured) | warrior2 | 0.99 | 0.99 | 0.99 | 0.99 | 0.83 | 0.83 |
| loadout / moonhide_fetish_solo (measured) | warrior2 | 0.99 | 0.99 | 1.00 | 1.00 | 0.83 | 0.83 |
| dungeon / side_vault_construct_t5_infiltrator14_solo | infiltrator14 | 0.61 | 0.61 | 0.73 | 0.73 | 0.45 | 0.45 |
| encounter / mage3_necromancer3_goblin_ambush_solo | mage3_necromancer3_caster | 0.57 | 0.57 | 0.65 | 0.65 | 0.42 | 0.42 |
| chieftains_raid / warrior2_mage2_caster (measured) | warrior2_mage2_caster | 0.95 | 0.95 | 0.94 | 0.94 | 0.80 | 0.80 |
| goblin_ambush / warrior2_helper2 (measured) | warrior2_helper2 | 0.99 | 0.99 | 0.99 | 0.99 | 0.85 | 0.85 |
| chieftains_raid / pure_warrior10 (measured) | pure_warrior10 | 0.96 | 0.96 | 0.95 | 0.95 | 0.82 | 0.82 |
| invrisil / alley_footpads_w1_tutorial_solo (measured) | warrior1_tutorial | 0.22 | 0.22 | 0.35 | 0.35 | 0.08 | 0.08 |
| invrisil / hired_blades_t3_warrior10_wilovan | t3_warrior10 | 0.42 | 0.42 | 0.47 | 0.47 | 0.28 | 0.28 |
| goblin_ambush / warrior2 (measured) | warrior2 | 0.98 | 0.98 | 0.99 | 0.99 | 0.85 | 0.85 |
| chieftains_raid / pure_mage10_caster (measured) | pure_mage10_caster | 0.84 | 0.84 | 0.72 | 0.72 | 0.71 | 0.71 |
| loadout / warrior2_sword (measured) | warrior2 | 0.98 | 0.98 | 0.98 | 0.98 | 0.85 | 0.85 |
| encounter / goblin_night_patrol_t1_relc (measured) | warrior2 | 0.98 | 0.98 | 0.99 | 0.99 | 0.85 | 0.85 |
| encounter / mage5_necromancer7_raskghar_scouts_with_skeleton | mage5_necromancer7_caster | 0.92 | 0.92 | 0.92 | 0.92 | 0.79 | 0.79 |
| dungeon / seal_warden_t4_sw11_solo (measured) | t4_spellsword11_party | 0.22 | 0.22 | 0.21 | 0.21 | 0.09 | 0.09 |
| bestiary / razorbeak_nest_t1_solo (measured) | warrior2 | 0.98 | 0.98 | 0.98 | 0.98 | 0.85 | 0.85 |
| encounter / shield_spiders_w1_solo (measured) | warrior1_tutorial | 0.15 | 0.15 | 0.27 | 0.27 | 0.03 | 0.03 |
| encounter / raskghar_scouts_w2_relc (measured) | warrior2 | 0.97 | 0.97 | 0.97 | 0.97 | 0.85 | 0.85 |
| invrisil / hired_blades_t3_warrior9_wilovan (measured) | t3_warrior9 | 0.35 | 0.35 | 0.44 | 0.44 | 0.23 | 0.23 |
| encounter / crate_scavengers_w1_solo (measured) | warrior1_tutorial | 0.17 | 0.17 | 0.34 | 0.34 | 0.06 | 0.06 |
| encounter / supplier_scavengers_w1_solo (measured) | warrior1_tutorial | 0.17 | 0.17 | 0.34 | 0.34 | 0.06 | 0.06 |
| invrisil / hired_blades_w10_wilovan (measured) | warrior5_mage5 | 0.14 | 0.14 | 0.33 | 0.33 | 0.03 | 0.03 |
| goblin_ambush / t3_spellsword9 (measured) | t3_spellsword9 | 1.00 | 1.00 | 1.00 | 1.00 | 0.89 | 0.89 |
| chieftains_raid / t3_warrior9 (measured) | t3_warrior9 | 0.98 | 0.98 | 0.96 | 0.96 | 0.87 | 0.87 |
| goblin_ambush / t4_spellsword11_party (measured) | t4_spellsword11_party | 1.00 | 1.00 | 1.00 | 1.00 | 0.90 | 0.90 |
| loadout / warrior2_sword_armored (measured) | warrior2 | 0.99 | 0.99 | 0.99 | 0.99 | 0.89 | 0.89 |
| loadout / moon_bone_solo (measured) | warrior2 | 0.99 | 0.99 | 0.98 | 0.98 | 0.89 | 0.89 |
| encounter / collapsed_gallery_nest_w10_solo | warrior5_mage5 | 0.12 | 0.12 | 0.44 | 0.44 | 0.03 | 0.03 |
| chieftains_raid / warrior5_mage5_caster (measured) | warrior5_mage5_caster | 0.99 | 0.99 | 1.00 | 1.00 | 0.90 | 0.90 |
| chieftains_raid / t3_warrior10 (measured) | t3_warrior10 | 1.00 | 1.00 | 0.96 | 0.96 | 0.91 | 0.91 |
| encounter / rock_crab_nest_t1_solo (measured) | warrior2 | 0.07 | 0.07 | 0.14 | 0.14 | 0.00 | 0.00 |
| chieftains_raid / t3_spellsword9 (measured) | t3_spellsword9 | 0.99 | 0.99 | 1.00 | 1.00 | 0.92 | 0.92 |
| chieftains_raid / t4_spellsword11_party (measured) | t4_spellsword11_party | 1.00 | 1.00 | 1.00 | 1.00 | 0.94 | 0.94 |
| loadout / warrior2_max_legal_kit (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.94 | 0.94 |
| loadout / hollow_herb_solo (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.94 | 0.94 |
| goblin_ambush / t3_warrior9 (measured) | t3_warrior9 | 0.99 | 0.99 | 1.00 | 1.00 | 0.93 | 0.93 |
| goblin_ambush / t3_warrior10 (measured) | t3_warrior10 | 0.99 | 0.99 | 1.00 | 1.00 | 0.93 | 0.93 |
| goblin_ambush / warrior2_mage2_caster (measured) | warrior2_mage2_caster | 0.99 | 0.99 | 1.00 | 1.00 | 0.94 | 0.94 |
| goblin_ambush / t4_spellsword14_party (measured) | t4_spellsword14_party | 1.00 | 1.00 | 1.00 | 1.00 | 0.95 | 0.95 |
| loadout / guardian_ward_solo (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.95 | 0.95 |
| loadout / pond_seal_solo (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.95 | 0.95 |
| goblin_ambush / classless_solo (measured) | classless_solo | 0.07 | 0.07 | 0.07 | 0.07 | 0.02 | 0.02 |
| ruin / rift_vermin_leak_w8_solo (measured) | warrior5_mage5 | 0.05 | 0.05 | 0.64 | 0.64 | 0.00 | 0.00 |
| riverfarm / river_wolf_pack_t3_solo (measured) | t3_warrior10 | 0.06 | 0.06 | 0.04 | 0.04 | 0.01 | 0.01 |
| goblin_ambush / warrior2_mage2 (measured) | warrior2_mage2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.96 | 0.96 |
| encounter / shield_spiders_w2_relc (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.96 | 0.96 |
| encounter / crate_scavengers_w1_klbkch (measured) | warrior1_tutorial | 0.98 | 0.98 | 0.98 | 0.98 | 0.94 | 0.94 |
| riverfarm / briar_collectors_deep_w10_solo (measured) | warrior5_mage5 | 0.05 | 0.05 | 0.41 | 0.41 | 0.01 | 0.01 |
| goblin_ambush / pure_mage10_caster (measured) | pure_mage10_caster | 0.98 | 0.98 | 1.00 | 1.00 | 0.95 | 0.95 |
| chieftains_raid / t4_spellsword14_party (measured) | t4_spellsword14_party | 1.00 | 1.00 | 1.00 | 1.00 | 0.97 | 0.97 |
| loadout / construct_core_solo (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.97 | 0.97 |
| invrisil / alley_footpads_t3_warrior10_solo (measured) | t3_warrior10 | 1.00 | 1.00 | 0.98 | 0.98 | 0.97 | 0.97 |
| invrisil / boulevard_night_footpads_t3_warrior10_solo (measured) | t3_warrior10 | 1.00 | 1.00 | 0.98 | 0.98 | 0.97 | 0.97 |
| ruin / ruin_guardian_w8_solo (measured) | warrior5_mage5 | 0.03 | 0.03 | 0.46 | 0.46 | 0.00 | 0.00 |
| ruin / crypt_lich_w8_solo (measured) | warrior5_mage5 | 0.03 | 0.03 | 0.66 | 0.66 | 0.00 | 0.00 |
| goblin_ambush / warrior5_mage5_caster (measured) | warrior5_mage5_caster | 1.00 | 1.00 | 1.00 | 1.00 | 0.98 | 0.98 |
| invrisil / alley_footpads_t3_spellsword9_solo (measured) | t3_spellsword9 | 1.00 | 1.00 | 1.00 | 1.00 | 0.98 | 0.98 |
| invrisil / boulevard_night_footpads_t3_spellsword9_solo (measured) | t3_spellsword9 | 1.00 | 1.00 | 1.00 | 1.00 | 0.98 | 0.98 |
| dungeon / side_vault_construct_t5_swordsman14_solo | swordsman14 | 0.93 | 0.93 | 0.98 | 0.98 | 0.91 | 0.91 |
| riverfarm / briar_collectors_w10_solo (measured) | warrior5_mage5 | 0.02 | 0.02 | 0.45 | 0.45 | 0.00 | 0.00 |
| encounter / sewer_vermin_w2_solo (measured) | warrior2 | 1.00 | 1.00 | 1.00 | 1.00 | 0.99 | 0.99 |
| chieftains_raid / warrior1_tutorial_solo (measured) | warrior1_tutorial_solo | 0.01 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| invrisil / hired_blades_t3_spellsword9_solo (measured) | t3_spellsword9 | 0.01 | 0.01 | 0.06 | 0.06 | 0.00 | 0.00 |
| invrisil / hired_blades_t3_warrior10_solo (measured) | t3_warrior10 | 0.01 | 0.01 | 0.02 | 0.02 | 0.00 | 0.00 |
| chieftains_raid / classless_solo (measured) | classless_solo | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| encounter / shield_spiders_w2_klbkch (measured) | warrior2 | 0.98 | 0.98 | 1.00 | 1.00 | 0.99 | 0.99 |
| boss / awakened_boss_w2_solo (measured) | warrior2 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| invrisil / hired_blades_w10_solo (measured) | warrior5_mage5 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| party / raskghar_awakened_t4_party (measured) | t4_spellsword11_party | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |

- **base_rested:** 147 cells; mean drop vs base_rested 0.000; cells below 0.55: 48.
- **head_rested:** 147 cells; mean drop vs base_rested 0.000; cells below 0.55: 48.
- **base_competent:** 147 cells; mean drop vs base_rested -0.070; cells below 0.55: 39.
- **head_competent:** 147 cells; mean drop vs base_rested -0.070; cells below 0.55: 39.
- **base_0.75:** 147 cells; mean drop vs base_rested 0.209; cells below 0.55: 90.
- **head_0.75:** 147 cells; mean drop vs base_rested 0.209; cells below 0.55: 90.

</details>
