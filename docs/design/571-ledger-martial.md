# #571 martial journey ledger (`steel_thread`, seed 37)

Lane C of `571-cutover-execution.md`. This journey starts from a fresh new game
and runs to the Inn epilogue with real input. It installs no fixture,
teleports nowhere and injects no state. The only loads are the game's own
defeat rollbacks and one pause-menu Save/Load. No data, source, seed or enemy
changed.

## Evidence

- Script commit `06efea7c` on `lane/571-martial` (base `ab851994`); this
  ledger lands in the commit after it. Tree `ad065e57`.
- `wandering_inn_game/qa/run_qa.sh steel_thread headless --seed=37` exits 0
  with `QA_RESULT: PASS`. `result.json` reports `passed: true` and 3134/3134
  steps. `qa/noise_scan.sh` is clean; the only engine line is the #586
  DummyShader shutdown leak. Log: `/private/tmp/wi-571-evidence/martial/headless.log`.
- The table below is `scripts/journey_ledger.py` run on that run's
  `events.jsonl`.
- `run_qa.sh steel_thread windowed --seed=37` passes 3134/3134 steps with 88
  captures, copied to `/private/tmp/wi-571-evidence/martial/`. Its log has
  two shutdown-only Metal lines after `QA_RESULT`: `ParticlesShaderRD` never
  freed, and a `MaterialStorage6ShaderE` RID leak. They are the
  rendering-device form of #586 and fall outside its exact headless
  exemption.
- Captures read:
  - Vault entry board: 42/42 HP, 14/14 MP, Ksmvr 17/17, construct 220/220.
  - After the vault rollback: field HUD `HP 42/42 MP 14/14`.
  - At the bed before the vault retry: `Rested: HP 49/49 (+7), MP 14/14 (+0).`
  - Vault retry board: 49/49, 14/14.
  - The core shard refused with "nowhere left on you".
  - After the guardian rollback: `HP 35/49 MP 0/14`.
  - First footpad ambush: 49/49, 16/16.
  - Second footpad ambush: 40/49, 0/16.
  - After the depleted reload: `HP 24/49 MP 0/16` in the alleys.
  - Warden down: `HP 4/50 MP 0/17`.
  - Ending room: `HP 50/50 MP 17/17` with the Spearmaster 16 toast. The
    epilogue text is not on screen in this capture; the run asserts its
    `ui_gdi_epilogue_rendered` (15 lines) instead.

## Vault analysis

The harness's reading of 0.82–0.89 comes from `sim_spine_viability.gd` row
`act4_vault_construct`. That row assumes ship build `ship_act4`, which is
fully rested: Warrior 11 / Mage 2, Relc's Spare Spear, no armor, no worn
accessories, one Mending Draught, and Ksmvr at −18 HP. The batch cell
`vault_construct_t4_party_guided` is different again: Spellsword 11 with a
knife, jerkin, Hedge Ward and Hunter's Fang.

Here is the route as it actually enters the vault (step 1001):

- Classes: the sixth sleep evolved Warrior 9 into Spearmaster 10 and raised
  Mage 4 to 6. That is 16 combined levels, against 13 for the ship build.
  Derived max HP fell from 49 to 42 across that sleep.
- HP/MP: 42/42 HP and 14/14 MP.
- Gear: the same spear and no armor. Three enchanted accessories were carried
  but not worn: Phosphor Pendant, Moonhide Fetish and Moon-Bone Amulet.
  Resonance stood at 0 of 4.
- Kit: one Mending Draught and 17 gold.
- Pending progress: the oracle `progression_preview` showed that the next
  sleep would bank Spearmaster 10 → 14.

So the equipment and draught matched the harness. The class split did not.
The Mage 6 kit hands the competent policy Invisibility: it spent 9 of 14 MP on
three self-casts and used Second Wind at full HP before attacking. That is kit
noise the ship build does not have. Nobody has measured a harness cell at this
exact build; lane B (#453) owns depleted and route-build harness cells.

**The loss is fixed for this route state, not bad luck.** A defeat reloads
`auto_pre_combat`. That save is written on `combat_preparing`, before
`start_combat` draws the combat seed with `rng.randi()`, and no world action
draws from `rng` in between. Every retry therefore replays the same seed, and
only a change in kit or state can change the outcome. These probes ran from
the vault-entry checkpoint. They were authoring analysis only and are not part
of the claimed run:

| Probe | Entry | Result |
|---|---|---|
| Identical retry | 42/42 HP, 14/14 MP | Loss, round 7, construct 46/220 (the same fight again) |
| Wear the 3 carried accessories, retry at once | 42/49, 14/14 | Loss, round 7, construct 36/220 |
| Sleep (Spearmaster 14), no accessories worn | 42/42, 14/14 | Loss, round 5, construct 45/220 |
| Wear accessories, then sleep | 49/49, 14/14 | Win, round 7, exit 35/49 HP, 0/14 MP |

## Retries and detours (ruling 1)

| Wall | What the route does | Why |
|---|---|---|
| Vault, defeat 1 (steps 1001–1027) | Keeps the measured loss and the real rollback to 42/42, 14/14 | Fully rested route kit. Logged, not hidden. |
| Vault, retry 1 (1028–1069) | Wears the carried Pendant, Fetish and Amulet (resonance 4 of 4), then retries from the same cell. Loss, round 7, 36/220. Rollback to 42/49. | The smallest player response: wear what is already in the pack. Gear never heals. |
| Vault, retry 2 (1070–1228) | Walks the route's own legs to the free Inn bed and back. The seventh sleep banks Spearmaster 10 → 14 and refills to 49/49, 14/14. Win, round 7. | Rest is the core recovery loop; the same walked-bed idiom is used before the Awakened boss (#578). |
| Ruin guardian, defeat (1390–1407) | Carries the vault exit 35/49, 0/14 with no sleep between. Loss, round 4, guardian 10/50. Real rollback. | The second no-sleep fight, kept as measured. |
| Ruin guardian, retry (1408–1500) | Ruin, then floodplains, then the Inn bed (eighth sleep: Diplomat forms, Spearmaster 15, 49/49, 15/15), then back. Win, round 3, 49/49, 1/15. | Same determinism: only rest changes the outcome. |

No fight is repeated for XP. Defeats roll back and bank nothing. The
[Greater Strength] warded side vault in the Trapped Halls (Wyvernbone Lance)
is optional content before the wall, but it was not taken: it is a solo
construct fight that would carry depletion into the vault, and resting was the
smaller detour.

Other changes downstream follow from those two sleeps and the worn gear. Each
is pinned exactly:

- Olesm's fresh-waking line (1278–1281).
- The core shard refusal at the reward beat, because all three accessory
  positions are full (1298–1309).
- The tonic is now the first sellable row, because the worn pendant is not for
  sale (2572).
- A re-pathed taproom walk (2907–2910).
- The descent-kit swap: the Guardian Ward Fragment replaces the Fetish, so the
  set is Pendant + Fragment + Amulet, resonance 4 of 5 (2881–2899).

The current build also needs the #504 purchase modal on 10 priced rows:
catalyst, Invrisil stone, 2 rumors, sponsorship 10, Pallass stone, entry 2,
filing 5, exam 8 and stamp 3.

## Route branches (unchanged from the shipped route)

- Talked Ksmvr through the plates (Ksmvr −18 HP in the vault).
- Relc joins the Awakened fight.
- Took the ruin guardian's fight leg.
- Riverfarm: took the walkable track leg rather than the night wolf fight,
  and mediated the blight with [Calming Touch].
- Invrisil: balked the Brothers with [Charming Smile], exposed rather than
  extorted, and chose testimony rather than drawing steel.
- The warden: sneak ambush.
- The open-seal ending (`seal_opened`, `seal_resolved`, `finale_played`).

## Gold, sleeps and stock

- **Gold:** +89 earned, −89 spent, ending at 0.
  - In: road 2, Selys 4+5, Olesm 6+5+15, Zevara bounties 3+4+10, field board
    2, Wilovan 25, tonic sale 8.
  - Out: catalyst 18, Pisces 5, Invrisil stone 18, rumors 1+1, sponsorship 10,
    Pallass stone 18, entry 2, filing 5, exam 8, stamp 3.
- **Sleeps:** 14 actual sleeps, all at the Inn bed. The seventh and eighth are
  the added retry rests.
- **Stock:** the Mending Draught is drunk in all three vault fights. The two
  defeats restore it on rollback; the win consumes it. The Remedy Draught is
  drunk against the warden. No food and no MP potion is used.

## Resource pins (task 3)

- **Two hostile fights with no sleep between: the alley footpads.** Both are
  fought on the eleventh sleep.
  - Ambush 1: entry 49/49 HP, 16/16 MP (pins 2073–2076); exit 40/49, 0/16
    (2081–2082, 2087–2088).
  - Ambush 2: entry 40/49, 0/16 (2097–2100); exit 24/49, 0/16 (2105–2106,
    2111–2112).
  - The vault win and guardian defeat are a second no-sleep pair: the vault
    exit at 1218–1228, the guardian entry at 1390–1392 and its loss at
    1394–1406.
- **Depleted pause-menu Save then Load** at 24/49 HP, 0/16 MP (2114–2139).
  The Save goes to the first manual slot and the Load reads it back. After the
  Load: exact `vitals`, `times_slept` 11, the cell and map, and the rendered
  `HP 24/49   MP 0/16`.

## Goldens

All of these claims are in shipped steps 889 and later. `steel_thread.yaml`
authors none of that range, so the claims have runtime proof only and no
structural-equivalence claim. The sliced golden diff for Acts I–III is
byte-identical on the base and lane trees. `scripts/itinerary/README.md`
records the current residue, including #578's 68 unauthored Act III rows.

## Ledger

| # | Encounter | Map | Entry | Exit | Result | Rounds | Items |
|---|---|---|---|---|---|---|---|
| 1 | relc_spar | floodplains | 32/32 HP | 32/32 HP | win | 4 | - |
| 2 | goblin_encounter_1 | floodplains | 43/43 HP | 4/43 HP | win | 4 | - |
| 3 | crate_scavengers | street | 45/45 HP, 12/12 MP | 45/45 HP, 0/12 MP | win | 2 | - |
| 4 | supplier_scavengers | street | 45/45 HP, 0/12 MP | 30/45 HP, 0/12 MP | win | 3 | - |
| 5 | shield_spiders | sewers | 46/46 HP, 13/13 MP | 2/46 HP, 0/13 MP | win | 5 | - |
| 6 | raskghar_scouts | deep_tunnels | 49/49 HP, 13/13 MP | 4/49 HP, 0/13 MP | win | 4 | - |
| 7 | awakened_boss | deep_tunnels | 49/49 HP, 13/13 MP | 26/49 HP, 0/13 MP | win | 4 | - |
| 8 | vault_boss_slot | trapped_halls | 42/42 HP, 14/14 MP | 0/42 HP, 0/14 MP → rollback 42/42 HP, 14/14 MP | loss | 7 | mending_draught |
| 9 | vault_boss_slot | trapped_halls | 42/49 HP, 14/14 MP | 0/49 HP, 0/14 MP → rollback 42/49 HP, 14/14 MP | loss | 7 | mending_draught |
| 10 | vault_boss_slot | trapped_halls | 49/49 HP, 14/14 MP | 35/49 HP, 0/14 MP | win | 7 | mending_draught |
| 11 | ruin_guardian | ruin_surface | 35/49 HP, 0/14 MP | 0/49 HP, 0/14 MP → rollback 35/49 HP, 0/14 MP | loss | 4 | - |
| 12 | ruin_guardian | ruin_surface | 49/49 HP, 15/15 MP | 49/49 HP, 1/15 MP | win | 3 | - |
| 13 | alley_footpads_a | mercantile_alleys | 49/49 HP, 16/16 MP | 40/49 HP, 0/16 MP | win | 2 | - |
| 14 | alley_footpads_b | mercantile_alleys | 40/49 HP, 0/16 MP | 24/49 HP, 0/16 MP | win | 2 | - |
| 15 | seal_warden_alcove | trapped_halls | 48/50 HP, 17/17 MP | 4/50 HP, 0/17 MP | win | 7 | remedy_draught |

Fights 15 (wins 12, losses 3, abandoned 0); retried {'vault_boss_slot': ['loss', 'loss', 'win'], 'ruin_guardian': ['loss', 'win']}; sleeps 14; gold +89 -89 = 0; final 50/50 HP, 17/17 MP.

Act boundaries: act_ii @ street: warrior 1; 2g; 1 sleeps; 2 fights (0 not won); act_iii @ street: mage 3, warrior 5; 6g; 3 sleeps; 5 fights (0 not won); act_iv @ street: mage 4, warrior 9; 12g; 5 sleeps; 7 fights (0 not won); act_v @ pallass_market: diplomat 5, mage 7, spearmaster 15; 0g; 11 sleeps; 14 fights (3 not won)
Sleeps: inn_upstairs bed → 43/43 HP; inn_upstairs bed → 45/45 HP, 12/12 MP; inn_upstairs bed → 46/46 HP, 13/13 MP; inn_upstairs bed → 49/49 HP, 13/13 MP; inn_upstairs bed → 49/49 HP, 13/13 MP; inn_upstairs bed → 42/42 HP, 14/14 MP; inn_upstairs bed → 49/49 HP, 14/14 MP; inn_upstairs bed → 49/49 HP, 15/15 MP; inn_upstairs bed → 49/49 HP, 16/16 MP; inn_upstairs bed → 49/49 HP, 16/16 MP; inn_upstairs bed → 49/49 HP, 16/16 MP; inn_upstairs bed → 49/49 HP, 17/17 MP; inn_upstairs bed → 49/49 HP, 17/17 MP; inn_upstairs bed → 50/50 HP, 17/17 MP
Recovery outside combat: none
Equipment: floodplains relcs_spare_spear 43/43 HP → 43/43 HP; trapped_halls phosphor_pendant 42/42 HP, 14/14 MP → 42/45 HP, 14/14 MP; trapped_halls moonhide_fetish 42/45 HP, 14/14 MP → 42/46 HP, 14/14 MP; trapped_halls moon_bone_amulet 42/46 HP, 14/14 MP → 42/49 HP, 14/14 MP; inn_upstairs accessory_2 49/49 HP, 17/17 MP → 48/48 HP, 17/17 MP; inn_upstairs guardian_ward_fragment 48/48 HP, 17/17 MP → 48/50 HP, 17/17 MP
Reloads: defeat@trapped_halls; defeat@trapped_halls; defeat@ruin_surface; load@mercantile_alleys
Gold: goblin_encounter_1 +2→2; selys_delivery +4→6; olesm_intro +6→12; olesm_intro +5→17; olesm_intro +15→32; zevara_intro +3→35; zevara_intro +4→39; zevara_intro +10→49; krshia_crate -18→31; pisces_magic -5→26; riverfarm_witch -18→8; riverfarm_field_board +2→10; invrisil_fixer -1→9; invrisil_fixer -1→8; invrisil_wilovan +25→33; selys_delivery +5→38; selys_delivery -10→28; krshia_sell +8→36; krshia_crate -18→18; pallass_market_clerk -2→16; pallass_forge_clerk -5→11; pallass_grimalkin -8→3; pallass_forge_clerk -3→0
