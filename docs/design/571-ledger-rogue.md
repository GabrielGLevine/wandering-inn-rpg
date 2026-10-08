# #571 Rogue journey ledger (`journey_rogue`, seed 9)

Fresh Rogue history from the title to the open-ending epilogue
(`rogue_full_ending`), authored for #512 and extended in #571 with exact
entry/exit pins on every fight's resources and an earned pause-menu Save/Load
at 10/44 HP, 0/14 MP in `deep_tunnels` (read windowed: the HUD shows
`HP 10/44 MP 0/14` after the Load). No fixtures, teleports or top-ups.
Retries are the route's own logged defeats with real rollback (shield
spiders, the first scout fight and the first warden fight).

Table: `scripts/journey_ledger.py` on the integrated journey-gate run. Act
boundaries mark where each `acts.json` gate is first met by the run's events.

| # | Encounter | Map | Entry | Exit | Result | Rounds | Items |
|---|---|---|---|---|---|---|---|
| 1 | relc_spar | floodplains | 32/32 HP, 12/12 MP | 32/32 HP, 10/12 MP | win | 3 | - |
| 2 | goblin_encounter_1 | floodplains | 43/43 HP, 12/12 MP | 43/43 HP, 0/12 MP | win | 5 | - |
| 3 | shield_spiders | sewers | 43/43 HP, 13/13 MP | 0/43 HP, 0/13 MP → rollback 43/43 HP, 13/13 MP | loss | 3 | - |
| 4 | raskghar_scouts | deep_tunnels | 43/43 HP, 15/15 MP | 0/43 HP, 0/15 MP → rollback 43/43 HP, 15/15 MP | loss | 4 | - |
| 5 | raskghar_scouts | deep_tunnels | 44/44 HP, 14/14 MP | 10/44 HP, 0/14 MP | win | 4 | - |
| 6 | awakened_boss | deep_tunnels | 44/44 HP, 14/14 MP | 44/44 HP, 4/14 MP | win | 4 | - |
| 7 | vault_boss_slot | trapped_halls | 49/49 HP, 15/15 MP | 29/49 HP, 0/15 MP | win | 9 | mending_draught |
| 8 | ruin_guardian | ruin_surface | 51/51 HP, 16/16 MP | 51/51 HP, 0/16 MP | win | 3 | - |
| 9 | alley_footpads_b | mercantile_alleys | 51/51 HP, 16/16 MP | 48/51 HP, 0/16 MP | win | 2 | - |
| 10 | seal_warden_alcove | trapped_halls | 48/48 HP, 16/16 MP | 0/48 HP, 0/16 MP → rollback 48/48 HP, 16/16 MP | loss | 7 | remedy_draught |
| 11 | seal_warden_alcove | trapped_halls | 51/51 HP, 16/16 MP | 10/51 HP, 0/16 MP | win | 11 | remedy_draught |

Fights 11 (wins 8, losses 3, abandoned 0); retried {'raskghar_scouts': ['loss', 'win'], 'seal_warden_alcove': ['loss', 'win']}; sleeps 18; gold +146 -142 = 4; final 53/53 HP, 16/16 MP.

Act boundaries: act_ii @ street: rogue 1; 0g; 1 sleeps; 0 fights (0 not won); act_iii @ street: diplomat 3, mage 4, rogue 3, warrior 2; 6g; 6 sleeps; 3 fights (1 not won); act_iv @ street: diplomat 5, helper 1, mage 4, rogue 3, warrior 2; 0g; 9 sleeps; 6 fights (2 not won); act_v @ pallass_market: diplomat 6, helper 1, mage 8, rogue 4, warrior 7; 48g; 14 sleeps; 9 fights (2 not won)
Sleeps: inn_upstairs bed → 32/32 HP; inn_upstairs bed → 32/32 HP, 12/12 MP; inn_upstairs bed → 32/32 HP, 12/12 MP; inn_upstairs bed → 43/43 HP, 12/12 MP; inn_upstairs bed → 43/43 HP, 13/13 MP; inn_upstairs bed → 43/43 HP, 14/14 MP; inn_upstairs bed → 43/43 HP, 15/15 MP; inn_upstairs bed → 44/44 HP, 14/14 MP; inn_upstairs bed → 44/44 HP, 14/14 MP; inn_upstairs bed → 49/49 HP, 15/15 MP; inn_upstairs bed → 51/51 HP, 16/16 MP; inn_upstairs bed → 51/51 HP, 16/16 MP; inn_upstairs bed → 51/51 HP, 16/16 MP; inn_upstairs bed → 51/51 HP, 16/16 MP; inn_upstairs bed → 48/48 HP, 16/16 MP; inn_upstairs bed → 48/48 HP, 16/16 MP; inn_upstairs bed → 51/51 HP, 16/16 MP; inn_upstairs bed → 53/53 HP, 16/16 MP
Recovery outside combat: none
Equipment: floodplains relcs_spare_spear 43/43 HP, 12/12 MP → 43/43 HP, 12/12 MP; street hunters_fang_talisman 44/44 HP, 14/14 MP → 44/44 HP, 14/14 MP; deep_tunnels moonhide_fetish 44/44 HP, 4/14 MP → 44/45 HP, 4/14 MP; street moon_bone_amulet 44/45 HP, 4/14 MP → 44/48 HP, 4/14 MP; street accessory_2 29/49 HP, 0/15 MP → 29/48 HP, 0/15 MP; street accessory_3 29/48 HP, 0/15 MP → 29/45 HP, 0/15 MP; street construct_core_shard 29/45 HP, 0/15 MP → 29/48 HP, 0/15 MP; street moonhide_fetish 29/48 HP, 0/15 MP → 29/49 HP, 0/15 MP; street accessory_2 48/51 HP, 0/16 MP → 48/48 HP, 0/16 MP; street accessory_3 48/48 HP, 0/16 MP → 47/47 HP, 0/16 MP; street hedge_ward_charm 47/47 HP, 0/16 MP → 47/49 HP, 0/16 MP; street stonescale_talisman 47/49 HP, 0/16 MP → 47/49 HP, 0/16 MP; trapped_halls accessory_2 48/48 HP, 16/16 MP → 46/46 HP, 16/16 MP; trapped_halls accessory_3 46/46 HP, 16/16 MP → 46/46 HP, 16/16 MP; trapped_halls moon_bone_amulet 46/46 HP, 16/16 MP → 46/49 HP, 16/16 MP; trapped_halls guardian_ward_fragment 46/49 HP, 16/16 MP → 46/51 HP, 16/16 MP
Reloads: defeat@sewers; defeat@deep_tunnels; load@deep_tunnels; defeat@trapped_halls
Gold: selys_delivery +4→4; goblin_encounter_1 +2→6; olesm_intro +6→12; dirty_table +1→13; serving_tray +1→14; krshia_crate -14→0; olesm_intro +5→5; olesm_intro +15→20; zevara_intro +3→23; zevara_intro +4→27; zevara_intro +10→37; krshia_crate -18→19; riverfarm_witch -18→1; riverfarm_field_board +2→3; invrisil_fixer -1→2; invrisil_fixer -1→1; invrisil_wilovan +25→26; invrisil_stationer_client +25→51; invrisil_house_steward +30→81; selys_delivery +5→86; selys_delivery -10→76; krshia_sell +8→84; krshia_crate -18→66; pallass_market_clerk -2→64; pallass_forge_clerk -5→59; pallass_grimalkin -8→51; pallass_forge_clerk -3→48; krshia_crate -9→39; krshia_crate -35→4
