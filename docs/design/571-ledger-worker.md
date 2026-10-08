# #571 worker journey ledger (`journey_worker`, seed 9)

Lane D of `571-cutover-execution.md`. The work-heavy generalist route starts
from a fresh new game and runs to the Inn epilogue (`worker_full_ending`) with
real input. It installs no fixture, teleports nowhere and injects no state.
The only loads are the game's own defeat rollbacks and one pause-menu Abandon.
No data, source, seed or enemy changed.

## Evidence

- Script commits on `lane/571-worker` (base `8c22ad40`): `ddff9bc8` (wall),
  `ecdb288f` (ending), `dabdb756` (comment and capture). Tree `358e2d3b`.
  This ledger lands in the next commit.
- `wandering_inn_game/qa/run_qa.sh journey_worker headless --seed=9` exits 0
  with `QA_RESULT: PASS`, `passed: true`, 3998/3998 steps, 22.2 s wall time.
  `qa/noise_scan.sh` is clean; the only engine line is the #586 DummyShader
  shutdown leak. Log: `/private/tmp/wi-571-evidence/worker/headless.log`.
- `qa/journey_gate.py --only journey_worker` with the registry checkpoint set to
  `worker_full_ending` (scratch copy; `qa/journeys.json` is unchanged): PASS,
  21.6 s against the 60 s budget.
- `run_qa.sh journey_worker windowed --seed=9` passes 3998/3998 with 74
  captures, copied to `/private/tmp/wi-571-evidence/worker/windowed/`. Its log
  ends with two shutdown-only rendering-device lines (`ParticlesShaderRD` never
  freed, a `MaterialStorage6ShaderE` RID leak), the windowed form of #586,
  now deferred by the extended ruling, so `noise_scan.sh` reads the log clean.
- The table below is `scripts/journey_ledger.py` on the integrated gate run's
  `events.jsonl` (regenerated at integration; each meal is listed once and the
  pause-menu Abandon appears as an `abandoned` fight with its exact rollback).
- Captures read:
  - Raid before Abandon: Maren 50/52 HP, MP 11/15; Relc 29/40; Cave Bat 5/26.
  - Abandon confirmation: "Abandon the fight? You return to your last autosave."
  - After Abandon: at the floodplains gate, field HUD `HP 50/50 MP 15/15`.
  - Raid won: `HP 50/50 MP 1/15` with the toast "Max HP -2." (meal expiry).
  - Warrior 2 boss entry: Maren 51/51, 15/15; boss 50/50, scouts 34/34, bat 24/24.
  - Warren cleared: `HP 42/51 MP 0/15`.
  - Jerkin toggle: the inventory reads `HP 42/51 MP 0/15`, Jerkin re-equipped.
  - Ruin wardwork: the [Detect Magic] toast "the seal lets go under your hand".
  - Pallass exam: Grimalkin's dialogue with the 8-gold row greyed, after "Paid 5 gold."
  - Warden defeat 1: "Defeat... — Enter"; Maren 0/54, warden 29/164.
  - Guardian detour entry: Maren 54/54, 16/16; guardian 50/50, wards 34/34.
  - After re-gear and the meal: `HP 45/57 MP 4/16`.
  - Warden retry entry: Maren 57/59, 16/16; warden 164/164.
  - Warden down: `HP 35/57 MP 0/16` with "Max HP -2."
  - Ending room: `HP 59/59 MP 16/16` and the Warrior 5 → 8 toast. The epilogue
    text is not on screen in this capture; the run asserts
    `ui_gdi_epilogue_rendered` instead.

## Wall 1: the Awakened boss

The harness reads `boss / awakened_boss_w2_relc` (Warrior 2 build, Relc
joined) at 0.49 rested. The encounter's own note gives the joined Warrior 5 /
Mage 4 competent read as 0.78, which matches the band.

At the wall the worker stood at Warrior 1 / Mage 4 / Diplomat 6 / Rogue 2 /
Cook 2 / Helper 1, with 50/52 HP (an armed Fine Meal) and 15/15 MP. It carried
Relc's spear, the Leather Jerkin, Hunter's Fang and the Traveler's Charm. Gear
and entry pools were already at or above the Rogue's winning history. The
missing piece was the class kit. Warrior 1 has no [Counter Strike] or
[Battle Momentum], which the w2 cell and the Rogue's win both carry. Warrior 2
needs one whole `won_combat`. The worker held only 0.574: the road fight
deposits at challenge weight, while the spar and the scouts bank quest ids. A
defeat reloads `auto_pre_combat`, which is written before the combat seed is
drawn, so the six earlier attempts could only move the result through state.

The smallest legitimate fix is the untouched optional **Chieftain's Raid**
(floodplains (31,7), interact-only, Relc ally, `on_victory: won_combat`). At the
worker's effective power (9.45) against the raid party (5.91), the challenge
weight is 0.472. That deposit takes the bank from 0.574 to 1.046, so Warrior 2
lands at the next real sleep. The raid is fought once. Probes from the wall
checkpoint showed the raid won in round 3 and the boss in round 5. Those probes
were authoring analysis only.

## Wall 2: the seal warden

The first attempt used the template's [Invisibility] ambush at 54/54, 16/16,
wearing Fang, Traveler's Charm and Moonhide. It loses in round 5 with the
warden at 29/164. Authoring probes from that rollback (not in the claimed run):

| Probe | Result |
|---|---|
| Identical retry | Loss, round 5, warden 29/164 (the same fight) |
| Moon-Bone Amulet for the Traveler's Charm, retry at once | Loss, round 5, 26/164 |
| Moon-Bone for the Fang, retry at once | Loss, round 5, 29/164 |
| Moon-Bone, walk out, cooked Fine Meal, sleep, return | Loss, round 5, 21/164 (sleep does not move the seed) |

The worker needed about 16 more effective HP to survive round 5's 30-damage
[Power Strike]. The ruin guardian is optional on this route, because the worker
opened the pedestal by reading the wardwork. It drops a Remedy Draught and the
Guardian Ward Fragment at chance 1.0. That is the warden kit both the Rogue
and the martial route carried.

## Retries and detours (ruling 1)

| Wall | What the route does | Why |
|---|---|---|
| Awakened boss, six retained defeats (steps up to 1428) | Unchanged original history. | Already measured; kept. |
| Raid Abandon (1430–1512) | Walks to the raid, casts one Flame Jet, ends the turn, then uses pause → Abandon. The `auto` save at the floodplains gate is restored exactly. | Criterion-5 Abandon pin; the retry replays the same seed. |
| Chieftain's Raid (1513–1541) | Wins in round 3, 50/52 → 50/50 HP. | Earns the missing whole `won_combat`. Untouched optional content, fought once. |
| Inn cook and sleep (1542–1579) | Cooks a Fine Meal with held [Advanced Cooking]; the eighth sleep banks Warrior 2. | Rest and earned level. |
| Boss retry (1580–1652) | Wins in round 5, 51/51 → 42/51 HP. | Warrior 2 kit present. |
| Warden defeat (3634–3658) | Keeps the loss and the real rollback to 54/54, 16/16. | Measured; logged. |
| Guardian detour (3659–3720) | Walks out through the Door, wins the ruin guardian in round 3 (54 → 37 HP) and takes the Remedy and the Fragment. | Optional fight that exists before the wall; its loot is the missing kit. |
| Inn recovery (3721–3808) | Cooks a Fine Meal and re-gears from owned items only (Moonhide, Moon-Bone, Fragment; resonance 4/5). Eats (37→45 HP, 0→4 MP, arms +2) and sleeps (Mage 8, Rogue 5, Cook 3). | Worker identity: meal, gear and rest. |
| Warden retry (3809–3870) | Recloaks before (18,7), because the awake warden springs there. Wins in round 9 at 35/57 HP; both draughts are drunk. | Same ambush with the new kit. |

No fight is repeated for XP. Defeats roll back and bank nothing.

## Gold against the fee audit

**Gold: +105 earned, −103 spent, ending at 2.**

- **All 82 mandatory gold is paid:**
  - catalyst 18;
  - Invrisil stone 18;
  - Pallass sponsorship 10;
  - Pallass stone 18;
  - entry stamp 2;
  - forge permit 5;
  - Grimalkin exam 8;
  - lift pass 3.
- **Avoided:** Pisces's 5-gold consultation (the [Charming Smile] row).
- **Optional spends:** Hunter's Fang 14, Traveler's Charm 5, two Cups rumors
  1+1 (the testimony route).
- **In:**
  - early wages and quests, 22 (table 1, tray 1, served plate 2, Selys 3,
    Olesm 6, road 2, Zevara 3+4);
  - raid loot 5;
  - Olesm 5 and 15;
  - Zevara's warren bounty 10;
  - Riverfarm field board 2;
  - Wilovan's courier pay 25;
  - Selys board pick 5;
  - the vault Tonic, sold for 8;
  - Inn work, 8.
- **Pallass shortfall (#513 finding 2):** after the entry stamp and the filing,
  the purse held 5. Grimalkin's 8-gold row rendered visible-locked. Pallass
  has no Skill-free income before the lift pass, so the worker went home
  through the Door. It worked two wakings at the Inn, each with a served
  plate (2), the table (1) and the tray (1), bringing the purse 5 → 9 → 13.
  It then paid the exam and the stamp, leaving 2. The optional Invrisil
  one-shots (heirloom 25, name 30) were not taken.

## Route branches and changed choices

The original 1423 worker inputs are unchanged. Seven exact meal pins are
inserted after the existing meal uses. That shifts later step indices, but no
existing pin changed. The continuation reuses the martial steel thread's
shipped spine. Every template pin now carries this route's own values. The
worker diverges from that template in these places:

1. **Ruin breach:** reads the anchor socket with held [Detect Magic] (Mage 7,
   earned from spell casts) and walks the plates. No guardian fight at the
   breach. Pisces's seal fork still accepts the vault's Core Shard.
2. **Pisces's Door consultation:** the [Charming Smile] row, not the 5-gold row.
3. **Invrisil alleys:** crossed under [Stealth] on every pass. The footpads are
   never fought. The martial's depleted Save/Load pin there belongs to the
   martial lane and was dropped.
4. **Krshia:** sells the Tonic (row 2) and keeps the Mending Draught.
5. **Descent kit:** no swap before the warden; there is no fragment yet.
6. **Pallass:** the two-waking work stint described above.
7. **Dungeon attunement:** one sleep. The work-stint sleep after Pisces's
   second-door lead already counted as one.
8. **Warden:** the ruling-1 loss and guardian detour.

Unchanged from the template: Ksmvr talked through the plates; Relc joins the
warren; Riverfarm's walkable track and the [Calming Touch] blight; the
Brothers, testimony and Coyle exposure dialogue rows; the [Invisibility]
warden ambush; the Core Shard refusal (all three positions worn); and the
open-seal ending (`seal_opened`, `seal_resolved`, `finale_played`; no
`seal_rewarded` or `seal_kept_fed`).

Final kit: Warrior 8 / Mage 8 / Diplomat 9 / Rogue 5 / Cook 3 / Helper 2 /
Archer 2 / Trader 2. Worn: Relc's spear, Leather Jerkin, Moon-Bone Amulet,
Guardian Ward Fragment, Moonhide Fetish. 16 sleeps, all at the Inn bed.

## Criterion-5 pins

Step numbers are 0-based indices into `qa/scripts/journey_worker.json`.

- **Every earned meal eaten** (`item_use_settled`, exact before/after/counts):
  - 823: Fine, 44/44 → 44/44; no restore, arms +2;
  - 863: Fine, 3 → 11 HP, 0 → 4 MP;
  - 897: Fine, 11 → 19, 4 → 8;
  - 910: Fine, 19 → 27, 8 → 12;
  - 923: Hot, 27 → 33;
  - 936: Hot, 33 → 39;
  - 949: Hot, 39 → 44 (capped at 5);
  - 1682: Fine cooked at 1554, 42 → 50 HP, 0 → 4 MP;
  - 3781: Fine cooked at 3746, 37 → 45 HP, 0 → 4 MP.
- **Meal preparation armed → active → expired:**
  - Raid: armed 1454; active at entry 1518–1522 (50/50 → 50/52); expired at
    exit 1532–1536 (max 52 → 50). HP was 50, so only the cap clamps.
  - Vault: armed 1684; active 1884–1885 (53 → 55); the exit at 1896 clamps HP
    55/55 → 53/53.
  - Warden win: armed 3783 and 3807; active 3854 and 3857; expired at 3867
    (59 → 57).
- **Equip toggle that does not heal:** 1659–1668, the worn Leather Jerkin off and
  on at 42/51. Max HP goes 51 → 47 → 51 and HP stays 42. The pre-warden re-gear
  (3756–3779) adds four more no-heal equipment receipts.
- **Pause-menu Abandon:** pause 1488, load 1496, exact rollback pins 1500–1511.
  These cover vitals 50/50 HP and 15/15 MP, zero exposure, the armed +2 meal
  restored with nothing active, stock `{hot_meal: 1}`, 3 gold, the
  floodplains cell, the rendered field HP/MP, and unchanged resolved/finished
  counts. The abandoned round changed MP (15 → 11), max HP (50 → 52) and the
  meal preparation. The stock could not change, because the worker held no
  item usable in combat at that point.

## Ledger

| # | Encounter | Map | Entry | Exit | Result | Rounds | Items |
|---|---|---|---|---|---|---|---|
| 1 | relc_spar | floodplains | 33/33 HP, 14/14 MP | 33/33 HP, 12/14 MP | win | 3 | - |
| 2 | raskghar_scouts | deep_tunnels | 44/44 HP, 14/14 MP | 0/44 HP, 1/14 MP → rollback 44/44 HP, 14/14 MP | loss | 4 | - |
| 3 | goblin_encounter_1 | floodplains | 44/44 HP, 14/14 MP | 44/44 HP, 0/14 MP | win | 4 | - |
| 4 | raskghar_scouts | deep_tunnels | 44/46 HP, 14/14 MP | 3/44 HP, 0/14 MP | win | 4 | - |
| 5 | awakened_boss | deep_tunnels | 11/46 HP, 4/14 MP | 0/46 HP, 0/14 MP → rollback 11/44 HP, 4/14 MP | loss | 2 | - |
| 6 | awakened_boss | deep_tunnels | 44/46 HP, 12/14 MP | 0/46 HP, 0/14 MP → rollback 44/44 HP, 12/14 MP | loss | 5 | - |
| 7 | awakened_boss | deep_tunnels | 48/50 HP, 14/14 MP | 0/50 HP, 0/14 MP → rollback 48/48 HP, 14/14 MP | loss | 6 | - |
| 8 | awakened_boss | deep_tunnels | 50/52 HP, 15/15 MP | 0/52 HP, 0/15 MP → rollback 50/50 HP, 15/15 MP | loss | 6 | - |
| 9 | awakened_boss | deep_tunnels | 50/52 HP, 15/15 MP | 0/52 HP, 0/15 MP → rollback 50/50 HP, 15/15 MP | loss | 5 | - |
| 10 | chieftains_raid | floodplains | 50/52 HP, 15/15 MP | 50/52 HP, 11/15 MP → rollback 50/50 HP, 15/15 MP | abandoned | None | - |
| 11 | chieftains_raid | floodplains | 50/52 HP, 15/15 MP | 50/50 HP, 1/15 MP | win | 3 | - |
| 12 | awakened_boss | deep_tunnels | 51/51 HP, 15/15 MP | 42/51 HP, 0/15 MP | win | 5 | - |
| 13 | vault_boss_slot | trapped_halls | 53/55 HP, 16/16 MP | 53/53 HP, 0/16 MP | win | 6 | - |
| 14 | seal_warden_alcove | trapped_halls | 54/54 HP, 16/16 MP | 0/54 HP, 0/16 MP → rollback 54/54 HP, 16/16 MP | loss | 5 | mending_draught |
| 15 | ruin_guardian | ruin_surface | 54/54 HP, 16/16 MP | 37/54 HP, 0/16 MP | win | 3 | - |
| 16 | seal_warden_alcove | trapped_halls | 57/59 HP, 16/16 MP | 35/57 HP, 0/16 MP | win | 9 | mending_draught; remedy_draught |

Fights 16 (wins 8, losses 7, abandoned 1); retried {'raskghar_scouts': ['loss', 'win'], 'awakened_boss': ['loss', 'loss', 'loss', 'loss', 'loss', 'win'], 'chieftains_raid': ['abandoned', 'win'], 'seal_warden_alcove': ['loss', 'win']}; sleeps 16; gold +105 -103 = 2; final 59/59 HP, 16/16 MP.

Sleeps: inn_upstairs bed → 33/33 HP; inn_upstairs bed → 33/33 HP, 13/13 MP; inn_upstairs bed → 33/33 HP, 14/14 MP; inn_upstairs bed → 44/44 HP, 14/14 MP; inn_upstairs bed → 44/44 HP, 14/14 MP; inn_upstairs bed → 48/48 HP, 14/14 MP; inn_upstairs bed → 50/50 HP, 15/15 MP; inn_upstairs bed → 51/51 HP, 15/15 MP; inn_upstairs bed → 53/53 HP, 16/16 MP; inn_upstairs bed → 54/54 HP, 16/16 MP; inn_upstairs bed → 54/54 HP, 16/16 MP; inn_upstairs bed → 54/54 HP, 16/16 MP; inn_upstairs bed → 53/53 HP, 16/16 MP; inn_upstairs bed → 54/54 HP, 16/16 MP; inn_upstairs bed → 57/57 HP, 16/16 MP; inn_upstairs bed → 59/59 HP, 16/16 MP
Recovery outside combat: deep_tunnels item_use:fine_meal 44/44 HP, 14/14 MP → 44/44 HP, 14/14 MP; deep_tunnels item_use:fine_meal 3/44 HP, 0/14 MP → 11/44 HP, 4/14 MP; deep_tunnels item_use:fine_meal 11/44 HP, 4/14 MP → 19/44 HP, 8/14 MP; deep_tunnels item_use:fine_meal 19/44 HP, 8/14 MP → 27/44 HP, 12/14 MP; deep_tunnels item_use:hot_meal 27/44 HP, 12/14 MP → 33/44 HP, 12/14 MP; deep_tunnels item_use:hot_meal 33/44 HP, 12/14 MP → 39/44 HP, 12/14 MP; deep_tunnels item_use:hot_meal 39/44 HP, 12/14 MP → 44/44 HP, 12/14 MP; deep_tunnels item_use:fine_meal 42/52 HP, 0/15 MP → 50/52 HP, 4/15 MP; inn item_use:fine_meal 37/57 HP, 0/16 MP → 45/57 HP, 4/16 MP
Equipment: floodplains relcs_spare_spear 44/44 HP, 14/14 MP → 44/44 HP, 14/14 MP; street hunters_fang_talisman 44/44 HP, 14/14 MP → 44/44 HP, 14/14 MP; inn_upstairs leather_jerkin 44/44 HP, 12/14 MP → 44/48 HP, 12/14 MP; street traveler_charm 48/48 HP, 14/14 MP → 48/50 HP, 14/14 MP; deep_tunnels armor 42/51 HP, 0/15 MP → 42/47 HP, 0/15 MP; deep_tunnels leather_jerkin 42/47 HP, 0/15 MP → 42/51 HP, 0/15 MP; deep_tunnels moonhide_fetish 42/51 HP, 0/15 MP → 42/52 HP, 0/15 MP; inn accessory_1 37/54 HP, 0/16 MP → 37/54 HP, 0/16 MP; inn accessory_2 37/54 HP, 0/16 MP → 37/52 HP, 0/16 MP; inn moon_bone_amulet 37/52 HP, 0/16 MP → 37/55 HP, 0/16 MP; inn guardian_ward_fragment 37/55 HP, 0/16 MP → 37/57 HP, 0/16 MP
Reloads: defeat@deep_tunnels; defeat@deep_tunnels; defeat@deep_tunnels; defeat@deep_tunnels; defeat@deep_tunnels; defeat@deep_tunnels; load@floodplains; defeat@trapped_halls
Gold: dirty_table +1→1; serving_tray +1→2; patron_serving +2→4; selys_delivery +3→7; olesm_intro +6→13; goblin_encounter_1 +2→15; krshia_crate -14→1; zevara_intro +3→4; zevara_intro +4→8; krshia_crate -5→3; chieftains_raid +5→8; olesm_intro +5→13; olesm_intro +15→28; zevara_intro +10→38; krshia_crate -18→20; riverfarm_witch -18→2; riverfarm_field_board +2→4; invrisil_fixer -1→3; invrisil_fixer -1→2; invrisil_wilovan +25→27; selys_delivery +5→32; selys_delivery -10→22; krshia_sell +8→30; krshia_crate -18→12; pallass_market_clerk -2→10; pallass_forge_clerk -5→5; patron_serving +2→7; dirty_table +1→8; serving_tray +1→9; patron_serving +2→11; dirty_table +1→12; serving_tray +1→13; pallass_grimalkin -8→5; pallass_forge_clerk -3→2
