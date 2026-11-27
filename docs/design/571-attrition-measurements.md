# #571 attrition measurements (#453 criterion 3)

Shared-formula harness `tests/sim_combat_batch.gd` on branch
`issue/571-recovery-cutover`, source tree `2635e78c` (main `79177b01` plus the
report-only `WI_ENTRY_FRACTION` leg). All legs: 147 cells × 100 seeds
(`RUNS_PER_CELL`, seeds 1–100), zero engine noise, exit 0.

## What each leg measures

| Leg | PC entry resources | PC turn policy | Consumables | Bands |
|---|---|---|---|---|
| rested | full derived HP/MP (WICombat default) | floor autoplay | none (the matrix has no inventory; draughts belong to `sim_spine_viability`) | asserted, **PASS** |
| 0.75 / 0.50 | `floor(f × max)` HP and MP via `initial_hp/initial_mp`, maxima from a rested probe of the same roster | floor autoplay | none | report only |
| competent | full | `WI_POLICY=competent` | none | report only; ladder gate **PASS** |
| competent_0.50 | 0.50 of max | competent | none | report only |

Kit and gear are each cell's harness build (`Build` column; loadout cells name
weapon/armor/accessories in the log). Allies and summons always start rested;
only the PC carries resources, matching the runtime.

## Findings (surfaced, not tuned)

- **Rested baseline unchanged:** every gated band holds; the competent ladder
  order holds. The rested harness remains the tactical authority.
- **Depleted entry is a different game.** Mean win rate falls 0.21 at 75%
  entry and 0.42 at 50%. Cells below 0.55 rise from 48 (rested, mostly
  measured/off-build rows) to 90 and 116.
- **Chokepoints collapse first.** The vault construct party cells read
  0.85–0.90 rested but 0.20–0.24 at 75% and 0.03–0.12 at 50%. The seal warden
  and Awakened boss rows fall similarly. A player who reaches these fights
  without resting is very likely to lose.
- **Implication for #513/#512:** recovery before chokepoints must be reachable
  and legible on every route. Continuous journeys record actual entry
  resources per fight (`scripts/journey_ledger.py`); see the `571-ledger-*`
  docs. No band, encounter or seed was changed. Any tuning response needs an
  explicit ruling under the no-auto-win and chokepoint doctrine.

Reproduce:

```bash
godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
WI_ENTRY_FRACTION=0.75 godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
python3 scripts/harness_entry_report.py rested=rested.log 0.75=075.log 0.50=050.log competent=c.log competent_0.50=c050.log --baseline rested
```

## All cells, ordered by largest drop from rested

| Cell | Build | rested | 0.75 | 0.50 | competent | competent_0.50 |
|---|---|---|---|---|---|---|
| party / vault_construct_t4_spellsword14_party (measured) | t4_spellsword14_party | 0.90 | 0.24 | 0.03 | 0.93 | 0.23 |
| encounter / rock_crab_nest_t1_relc | warrior2 | 0.84 | 0.07 | 0.00 | 0.97 | 0.06 |
| riverfarm / river_wolf_pack_t3_hunter (measured) | t3_warrior10 | 0.86 | 0.42 | 0.03 | 0.84 | 0.02 |
| riverfarm / briar_collectors_deep_t5_sw14_solo | t4_spellsword14_party | 0.87 | 0.48 | 0.04 | 0.88 | 0.33 |
| party / vault_construct_t4_party | t4_spellsword11_party | 0.85 | 0.20 | 0.03 | 0.78 | 0.07 |
| encounter / druid14_raskghar_scouts_with_wolf | druid14_caster | 0.90 | 0.64 | 0.10 | 0.90 | 0.11 |
| party / vault_construct_t4_party_guided (measured) | t4_spellsword11_party | 0.85 | 0.20 | 0.12 | 0.78 | 0.15 |
| bestiary / market_watchgolems_t4_solo (measured) | t4_spellsword11_party | 0.84 | 0.42 | 0.11 | 0.96 | 0.35 |
| bestiary / market_watchgolems_t5_sw14_solo (measured) | t4_spellsword14_party | 0.97 | 0.75 | 0.24 | 0.98 | 0.85 |
| ruin / briar_arch_wards_warrior11_relc | p5_warrior11 | 0.81 | 0.52 | 0.10 | 0.88 | 0.24 |
| chieftains_raid / pure_mage10_caster (measured) | pure_mage10_caster | 0.84 | 0.71 | 0.53 | 0.72 | 0.13 |
| dungeon / gallery_vermin_nest_t4_solo | t4_spellsword11_party | 0.81 | 0.51 | 0.11 | 0.98 | 0.32 |
| invrisil / rest_bravos_t3_warrior10_solo | t3_warrior10 | 0.77 | 0.39 | 0.07 | 0.73 | 0.15 |
| bestiary / kingslayer_den_t4_solo (measured) | t4_spellsword11_party | 0.86 | 0.52 | 0.16 | 0.87 | 0.19 |
| encounter / raskghar_scouts_w5_solo (measured) | warrior5_mage5 | 0.94 | 0.62 | 0.26 | 0.94 | 0.37 |
| encounter / mage5_necromancer7_raskghar_scouts_solo | mage5_necromancer7_caster | 0.72 | 0.34 | 0.07 | 0.64 | 0.04 |
| encounter / beast_master10_raskghar_scouts_with_wolf | beast_master10_melee | 0.95 | 0.56 | 0.27 | 0.94 | 0.27 |
| invrisil / alley_footpads_w2_solo | warrior2 | 0.86 | 0.58 | 0.18 | 0.91 | 0.27 |
| scaled / forge_calibration_golem_t5_gold | gold_spellsword22 | 0.70 | 0.27 | 0.02 | 0.87 | 0.27 |
| second_wind / strategist14_solo (measured) | strategist14 | 0.77 | 0.39 | 0.11 | 0.98 | 0.42 |
| bestiary / forge_calibration_golem_t5_sw14_solo | t4_spellsword14_party | 0.69 | 0.26 | 0.03 | 0.87 | 0.30 |
| bestiary / forge_temper_golem_t5_sw14_solo | t4_spellsword14_party | 0.67 | 0.20 | 0.02 | 0.89 | 0.67 |
| second_wind / fire_mage14_solo | fire_mage14 | 0.74 | 0.51 | 0.09 | 0.79 | 0.31 |
| scaled / gallery_vermin_nest_t4_silver | t4_spellsword14_party | 0.67 | 0.29 | 0.02 | 0.99 | 0.26 |
| encounter / rags_scouting_party_t1_solo | warrior2 | 0.72 | 0.38 | 0.08 | 0.76 | 0.15 |
| ruin / briar_arch_wards_mage11_relc (measured) | p5_mage11_caster | 0.65 | 0.31 | 0.13 | 0.54 | 0.01 |
| second_wind / beast_master14_raskghar_scouts_with_wolf (measured) | beast_master14 | 0.69 | 0.24 | 0.05 | 0.70 | 0.05 |
| invrisil / boulevard_duel_ring_t3_solo | t3_warrior10 | 0.64 | 0.31 | 0.03 | 0.71 | 0.01 |
| ruin / rift_vermin_leak_w8_relc | warrior5_mage5 | 0.72 | 0.29 | 0.10 | 0.99 | 0.55 |
| goblin_ambush / warrior5_mage5 (measured) | warrior5_mage5 | 0.99 | 0.83 | 0.38 | 1.00 | 0.62 |
| encounter / goblin_night_patrol_t1_solo (measured) | warrior2 | 0.72 | 0.39 | 0.11 | 0.79 | 0.18 |
| chieftains_raid / warrior2_mage2 (measured) | warrior2_mage2 | 0.94 | 0.67 | 0.35 | 0.94 | 0.52 |
| encounter / mage3_necromancer3_goblin_ambush_with_skeleton | mage3_necromancer3_caster | 0.62 | 0.32 | 0.03 | 0.46 | 0.05 |
| encounter / camp_ground_press_t1_rags_ally | warrior2 | 0.63 | 0.08 | 0.04 | 0.70 | 0.04 |
| encounter / pond_guardian_t1_runner5_warrior5_solo | t1_runner5_warrior5 | 0.61 | 0.23 | 0.02 | 0.81 | 0.05 |
| second_wind / ice_mage14_solo | ice_mage14 | 0.60 | 0.38 | 0.03 | 0.51 | 0.01 |
| invrisil / hired_blades_t5_sw14_wilovan | t4_spellsword14_party | 0.70 | 0.46 | 0.12 | 0.89 | 0.49 |
| loadout / chieftains_hp_stack (measured) | warrior2 | 0.81 | 0.53 | 0.24 | 0.78 | 0.24 |
| second_wind / sharpshooter14_solo | sharpshooter14 | 0.66 | 0.29 | 0.10 | 0.97 | 0.55 |
| chieftains_raid / warrior2_helper2 (measured) | warrior2_helper2 | 0.78 | 0.46 | 0.23 | 0.77 | 0.29 |
| encounter / mage3_necromancer3_goblin_ambush_solo | mage3_necromancer3_caster | 0.57 | 0.42 | 0.14 | 0.65 | 0.02 |
| bestiary / forge_calibration_golem_t4_solo (measured) | t4_spellsword11_party | 0.57 | 0.16 | 0.02 | 0.62 | 0.03 |
| chieftains_raid / warrior2 | warrior2 | 0.77 | 0.46 | 0.23 | 0.76 | 0.29 |
| second_wind / infiltrator14_solo | infiltrator14 | 0.62 | 0.26 | 0.08 | 0.75 | 0.13 |
| riverfarm / granary_scavengers_t3_warrior10_solo | t3_warrior10 | 0.58 | 0.22 | 0.06 | 0.50 | 0.04 |
| loadout / warrior2_mage2_gambeson (measured) | warrior2_mage2 | 0.96 | 0.74 | 0.43 | 0.96 | 0.55 |
| encounter / mage5_necromancer7_raskghar_scouts_with_skeleton | mage5_necromancer7_caster | 0.92 | 0.79 | 0.41 | 0.92 | 0.39 |
| encounter / camp_ground_press_t1_spear_ally | warrior2 | 0.63 | 0.20 | 0.10 | 0.78 | 0.10 |
| scaled / gallery_vermin_nest_t4_gold | gold_spellsword16 | 0.54 | 0.16 | 0.01 | 0.97 | 0.29 |
| loadout / warrior1_tutorial_solo_max_legal_kit (measured) | warrior1_tutorial_solo | 0.52 | 0.23 | 0.00 | 0.52 | 0.00 |
| encounter / beast_tamer5_goblin_ambush_with_wolf | beast_tamer5_melee | 0.87 | 0.54 | 0.36 | 0.82 | 0.35 |
| riverfarm / thicket_line_den_t3_warrior10_solo | t3_warrior10 | 0.53 | 0.19 | 0.04 | 0.47 | 0.01 |
| bestiary / corusdeer_range_t1_solo (measured) | warrior2 | 0.72 | 0.38 | 0.20 | 0.88 | 0.47 |
| goblin_ambush / pure_warrior10 (measured) | pure_warrior10 | 0.97 | 0.68 | 0.46 | 0.99 | 0.48 |
| encounter / shield_spiders_w2_solo (measured) | warrior2 | 0.54 | 0.18 | 0.03 | 0.70 | 0.03 |
| bestiary / road_mothbears_t3_solo (measured) | t3_warrior10 | 0.57 | 0.29 | 0.06 | 0.49 | 0.07 |
| scaled / forge_calibration_golem_t5_silver | t4_spellsword14_party | 0.53 | 0.18 | 0.02 | 0.76 | 0.10 |
| loadout / warrior2_spear (measured) | warrior2 | 0.97 | 0.79 | 0.47 | 0.99 | 0.59 |
| riverfarm / riverfarm_thicket_patch_t3_solo | t3_warrior10 | 0.50 | 0.15 | 0.04 | 0.52 | 0.00 |
| chieftains_raid / pure_warrior10 (measured) | pure_warrior10 | 0.96 | 0.82 | 0.46 | 0.95 | 0.91 |
| goblin_ambush / warrior2_mage2_caster (measured) | warrior2_mage2_caster | 0.99 | 0.94 | 0.50 | 1.00 | 0.77 |
| goblin_ambush / warrior1_tutorial (measured) | warrior1_tutorial | 0.97 | 0.80 | 0.49 | 0.97 | 0.50 |
| goblin_ambush / warrior2_helper2 (measured) | warrior2_helper2 | 0.99 | 0.85 | 0.51 | 0.99 | 0.52 |
| chieftains_raid / warrior5_mage5 (measured) | warrior5_mage5 | 0.97 | 0.79 | 0.49 | 1.00 | 0.83 |
| loadout / moon_bone_solo (measured) | warrior2 | 0.99 | 0.89 | 0.51 | 0.98 | 0.65 |
| loadout / kingslayer_fang_solo (measured) | warrior2 | 0.99 | 0.83 | 0.51 | 0.99 | 0.51 |
| loadout / moonhide_fetish_solo (measured) | warrior2 | 0.99 | 0.83 | 0.51 | 1.00 | 0.57 |
| bestiary / razorbeak_nest_t1_solo (measured) | warrior2 | 0.98 | 0.85 | 0.50 | 0.98 | 0.60 |
| goblin_ambush / warrior2 (measured) | warrior2 | 0.98 | 0.85 | 0.51 | 0.99 | 0.52 |
| goblin_ambush / t3_warrior9 (measured) | t3_warrior9 | 0.99 | 0.93 | 0.55 | 1.00 | 0.52 |
| loadout / warrior2_sword (measured) | warrior2 | 0.98 | 0.85 | 0.51 | 0.98 | 0.51 |
| encounter / goblin_night_patrol_t1_relc (measured) | warrior2 | 0.98 | 0.85 | 0.51 | 0.99 | 0.52 |
| encounter / raskghar_scouts_w2_solo (measured) | warrior2 | 0.49 | 0.16 | 0.03 | 0.59 | 0.06 |
| ruin / briar_arch_wards_warrior11_solo (measured) | p5_warrior11 | 0.46 | 0.18 | 0.02 | 0.43 | 0.10 |
| invrisil / hired_blades_t4_sw11_wilovan (measured) | t4_spellsword11_party | 0.49 | 0.27 | 0.05 | 0.78 | 0.15 |
| goblin_ambush / t3_spellsword9 (measured) | t3_spellsword9 | 1.00 | 0.89 | 0.57 | 1.00 | 0.92 |
| loadout / warrior1_tutorial_solo_armored (measured) | warrior1_tutorial_solo | 0.43 | 0.13 | 0.00 | 0.43 | 0.00 |
| boss / awakened_boss_w2_relc | warrior2 | 0.49 | 0.28 | 0.06 | 0.54 | 0.10 |
| invrisil / hired_blades_t3_spellsword9_wilovan (measured) | t3_spellsword9 | 0.47 | 0.20 | 0.04 | 0.74 | 0.10 |
| chieftains_raid / warrior2_mage2_caster (measured) | warrior2_mage2_caster | 0.95 | 0.80 | 0.52 | 0.94 | 0.52 |
| loadout / warrior2_mage2_stonescale_dr2 (measured) | warrior2_mage2 | 0.97 | 0.79 | 0.54 | 1.00 | 0.57 |
| goblin_ambush / warrior5_mage5_caster (measured) | warrior5_mage5_caster | 1.00 | 0.98 | 0.58 | 1.00 | 0.62 |
| goblin_ambush / t3_warrior10 (measured) | t3_warrior10 | 0.99 | 0.93 | 0.59 | 1.00 | 0.57 |
| dungeon / side_vault_construct_t5_infiltrator14_solo | infiltrator14 | 0.61 | 0.45 | 0.19 | 0.73 | 0.30 |
| loadout / warrior2_sword_armored (measured) | warrior2 | 0.99 | 0.89 | 0.58 | 0.99 | 0.58 |
| dungeon / trapped_halls_snare_t4_solo | t4_spellsword11_party | 0.42 | 0.19 | 0.01 | 0.91 | 0.05 |
| encounter / crate_scavengers_w1_klbkch (measured) | warrior1_tutorial | 0.98 | 0.94 | 0.59 | 0.98 | 0.67 |
| goblin_ambush / t4_spellsword11_party (measured) | t4_spellsword11_party | 1.00 | 0.90 | 0.62 | 1.00 | 0.92 |
| loadout / pond_seal_solo (measured) | warrior2 | 1.00 | 0.95 | 0.62 | 1.00 | 0.62 |
| ruin / briar_arch_wards_mage11_solo (measured) | p5_mage11_caster | 0.38 | 0.10 | 0.01 | 0.09 | 0.00 |
| invrisil / alley_fence_t3_warrior10_solo | t3_warrior10 | 0.38 | 0.09 | 0.00 | 0.45 | 0.02 |
| invrisil / counting_room_guard_t3_warrior10_solo | t3_warrior10 | 0.38 | 0.04 | 0.00 | 0.53 | 0.00 |
| loadout / warrior2_max_legal_kit (measured) | warrior2 | 1.00 | 0.94 | 0.63 | 1.00 | 0.63 |
| riverfarm / briar_collectors_deep_t3_warrior10_solo | t3_warrior10 | 0.38 | 0.12 | 0.01 | 0.30 | 0.04 |
| invrisil / hired_blades_t3_warrior10_wilovan | t3_warrior10 | 0.42 | 0.28 | 0.05 | 0.47 | 0.14 |
| chieftains_raid / t3_warrior9 (measured) | t3_warrior9 | 0.98 | 0.87 | 0.62 | 0.96 | 0.89 |
| chieftains_raid / t3_warrior10 (measured) | t3_warrior10 | 1.00 | 0.91 | 0.64 | 0.96 | 0.93 |
| chieftains_raid / t4_spellsword11_party (measured) | t4_spellsword11_party | 1.00 | 0.94 | 0.64 | 1.00 | 0.92 |
| second_wind / spearmaster14_solo | spearmaster14 | 0.37 | 0.11 | 0.01 | 0.64 | 0.07 |
| goblin_ambush / warrior1_tutorial_solo (measured) | warrior1_tutorial_solo | 0.34 | 0.08 | 0.00 | 0.43 | 0.00 |
| ruin / ruin_guardian_w8_relc | warrior5_mage5 | 0.38 | 0.13 | 0.04 | 0.95 | 0.15 |
| chieftains_raid / t3_spellsword9 (measured) | t3_spellsword9 | 0.99 | 0.92 | 0.65 | 1.00 | 0.89 |
| chieftains_raid / warrior1_tutorial (measured) | warrior1_tutorial | 0.47 | 0.23 | 0.14 | 0.51 | 0.14 |
| loadout / hollow_herb_solo (measured) | warrior2 | 1.00 | 0.94 | 0.67 | 1.00 | 0.67 |
| riverfarm / briar_collectors_t3_warrior10_solo | t3_warrior10 | 0.33 | 0.14 | 0.03 | 0.28 | 0.01 |
| second_wind / swordsman14_solo | swordsman14 | 0.33 | 0.04 | 0.01 | 0.63 | 0.05 |
| goblin_ambush / warrior2_mage2 (measured) | warrior2_mage2 | 1.00 | 0.96 | 0.69 | 1.00 | 0.77 |
| loadout / guardian_ward_solo (measured) | warrior2 | 1.00 | 0.95 | 0.69 | 1.00 | 0.77 |
| invrisil / hired_blades_t3_warrior9_wilovan (measured) | t3_warrior9 | 0.35 | 0.23 | 0.04 | 0.44 | 0.08 |
| chieftains_raid / warrior5_mage5_caster (measured) | warrior5_mage5_caster | 0.99 | 0.90 | 0.71 | 1.00 | 0.83 |
| encounter / raskghar_scouts_w2_relc (measured) | warrior2 | 0.97 | 0.85 | 0.69 | 0.97 | 0.78 |
| dungeon / seal_warden_t5_sw14_solo | t4_spellsword14_party | 0.34 | 0.14 | 0.06 | 0.70 | 0.23 |
| dungeon / side_vault_construct_t5_swordsman14_solo | swordsman14 | 0.93 | 0.91 | 0.65 | 0.98 | 0.99 |
| chieftains_raid / t4_spellsword14_party (measured) | t4_spellsword14_party | 1.00 | 0.97 | 0.75 | 1.00 | 0.95 |
| goblin_ambush / pure_mage10_caster (measured) | pure_mage10_caster | 0.98 | 0.95 | 0.74 | 1.00 | 0.82 |
| invrisil / alley_footpads_t3_spellsword9_solo (measured) | t3_spellsword9 | 1.00 | 0.98 | 0.76 | 1.00 | 0.87 |
| invrisil / alley_footpads_t3_warrior10_solo (measured) | t3_warrior10 | 1.00 | 0.97 | 0.76 | 0.98 | 0.86 |
| invrisil / boulevard_night_footpads_t3_spellsword9_solo (measured) | t3_spellsword9 | 1.00 | 0.98 | 0.76 | 1.00 | 0.87 |
| invrisil / boulevard_night_footpads_t3_warrior10_solo (measured) | t3_warrior10 | 1.00 | 0.97 | 0.76 | 0.98 | 0.86 |
| loadout / construct_core_solo (measured) | warrior2 | 1.00 | 0.97 | 0.77 | 1.00 | 0.77 |
| encounter / pond_guardian_t1_warrior2_solo (measured) | warrior2 | 0.24 | 0.06 | 0.01 | 0.59 | 0.02 |
| invrisil / alley_footpads_w1_tutorial_solo (measured) | warrior1_tutorial | 0.22 | 0.08 | 0.01 | 0.35 | 0.01 |
| goblin_ambush / t4_spellsword14_party (measured) | t4_spellsword14_party | 1.00 | 0.95 | 0.79 | 1.00 | 0.98 |
| encounter / shield_spiders_w2_relc (measured) | warrior2 | 1.00 | 0.96 | 0.82 | 1.00 | 0.84 |
| dungeon / seal_warden_t4_sw11_solo (measured) | t4_spellsword11_party | 0.22 | 0.09 | 0.04 | 0.21 | 0.05 |
| encounter / crate_scavengers_w1_solo (measured) | warrior1_tutorial | 0.17 | 0.06 | 0.00 | 0.34 | 0.01 |
| encounter / supplier_scavengers_w1_solo (measured) | warrior1_tutorial | 0.17 | 0.06 | 0.00 | 0.34 | 0.01 |
| encounter / shield_spiders_w1_solo (measured) | warrior1_tutorial | 0.15 | 0.03 | 0.00 | 0.27 | 0.00 |
| invrisil / hired_blades_w10_wilovan (measured) | warrior5_mage5 | 0.14 | 0.03 | 0.00 | 0.33 | 0.03 |
| encounter / collapsed_gallery_nest_w10_solo | warrior5_mage5 | 0.12 | 0.03 | 0.01 | 0.44 | 0.00 |
| encounter / sewer_vermin_w2_solo (measured) | warrior2 | 1.00 | 0.99 | 0.89 | 1.00 | 0.94 |
| goblin_ambush / classless_solo (measured) | classless_solo | 0.07 | 0.02 | 0.00 | 0.07 | 0.00 |
| encounter / rock_crab_nest_t1_solo (measured) | warrior2 | 0.07 | 0.00 | 0.00 | 0.14 | 0.01 |
| riverfarm / river_wolf_pack_t3_solo (measured) | t3_warrior10 | 0.06 | 0.01 | 0.00 | 0.04 | 0.00 |
| encounter / shield_spiders_w2_klbkch (measured) | warrior2 | 0.98 | 0.99 | 0.92 | 1.00 | 0.94 |
| ruin / rift_vermin_leak_w8_solo (measured) | warrior5_mage5 | 0.05 | 0.00 | 0.00 | 0.64 | 0.02 |
| riverfarm / briar_collectors_deep_w10_solo (measured) | warrior5_mage5 | 0.05 | 0.01 | 0.00 | 0.41 | 0.02 |
| ruin / ruin_guardian_w8_solo (measured) | warrior5_mage5 | 0.03 | 0.00 | 0.00 | 0.46 | 0.00 |
| ruin / crypt_lich_w8_solo (measured) | warrior5_mage5 | 0.03 | 0.00 | 0.00 | 0.66 | 0.04 |
| party / raskghar_awakened_t4_party (measured) | t4_spellsword11_party | 1.00 | 1.00 | 0.98 | 1.00 | 0.99 |
| riverfarm / briar_collectors_w10_solo (measured) | warrior5_mage5 | 0.02 | 0.00 | 0.00 | 0.45 | 0.00 |
| chieftains_raid / warrior1_tutorial_solo (measured) | warrior1_tutorial_solo | 0.01 | 0.00 | 0.00 | 0.01 | 0.00 |
| invrisil / hired_blades_t3_spellsword9_solo (measured) | t3_spellsword9 | 0.01 | 0.00 | 0.00 | 0.06 | 0.00 |
| invrisil / hired_blades_t3_warrior10_solo (measured) | t3_warrior10 | 0.01 | 0.00 | 0.00 | 0.02 | 0.00 |
| chieftains_raid / classless_solo (measured) | classless_solo | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| boss / awakened_boss_w2_solo (measured) | warrior2 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| invrisil / hired_blades_w10_solo (measured) | warrior5_mage5 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

- **rested:** 147 cells; mean drop vs rested 0.000; cells below 0.55: 48.
- **0.75:** 147 cells; mean drop vs rested 0.209; cells below 0.55: 90.
- **0.50:** 147 cells; mean drop vs rested 0.418; cells below 0.55: 116.
- **competent:** 147 cells; mean drop vs rested -0.070; cells below 0.55: 39.
- **competent_0.50:** 147 cells; mean drop vs rested 0.335; cells below 0.55: 103.
