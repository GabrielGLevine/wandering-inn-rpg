# Dialogue graph heatmap — GH#397 Phase 3 targeting

**Generated** by `qa/scripts/extract_prose.py heatmap` (seed 397, deterministic). Do not hand-edit.

Acceptance criterion 4: residual dialogue work is targeted by graph-level evidence, not a mandatory second rewrite of every file. This is that evidence.

**How to read it.** `closer density` = share of narrator/NPC `text` strings (player options excluded) whose final sentence trips the button smoke score (>=2 of 5; see review-rubric.md §4). `shared geom` = for every rhetorical shape this graph uses, how many OTHER graphs use the same shape — the issue's actual complaint is distributional, so a shape is only damning when it is common. `score` = density*100 + shared*0.5 + raw shape hits. **These are smoke detectors. A high row is a graph worth READING, never a graph proven bad**; a low row is not a clearance.

Corpus: 72 graphs, 577 narrator/NPC strings, 861 player options.

`density` is raw; `adj` is the volume-shrunk density the ranking actually uses (flagged / (nodes + 6)), so a 1-node graph cannot top the list on a single hit.

| # | graph | nodes | flagged | density | adj | shared geom | shape hits | score |
|--:|---|--:|--:|--:|--:|--:|---|--:|
| 1 | `krshia_crate` | 26 | 5 | 19% | 16% | 8 | neg correction 1 | 20.6 |
| 2 | `pisces_seal` | 14 | 3 | 21% | 15% | 8 | neg correction 1 | 20.0 |
| 3 | `riverfarm_villager` | 3 | 1 | 33% | 11% | 8 | neg correction 2 | 17.1 |
| 4 | `forge_temper_golem` | 1 | 1 | 100% | 14% | 0 | — | 14.3 |
| 5 | `rags_inn` | 5 | 1 | 20% | 9% | 8 | neg correction 1 | 14.1 |
| 6 | `ceria_dig_camp` | 2 | 1 | 50% | 12% | 0 | — | 12.5 |
| 7 | `ksmvr_plates` | 2 | 1 | 50% | 12% | 0 | — | 12.5 |
| 8 | `pisces_magic` | 40 | 3 | 8% | 7% | 8 | neg correction 1 | 11.5 |
| 9 | `krshia_inn` | 3 | 1 | 33% | 11% | 0 | — | 11.1 |
| 10 | `selys_delivery` | 17 | 1 | 6% | 4% | 8 | neg correction 1 | 9.3 |
| 11 | `zevara_intro` | 24 | 1 | 4% | 3% | 8 | neg correction 2 | 9.3 |
| 12 | `invrisil_stationer_client` | 17 | 2 | 12% | 9% | 0 | — | 8.7 |
| 13 | `riverfarm_tallyman` | 6 | 1 | 17% | 8% | 0 | — | 8.3 |
| 14 | `invrisil_wilovan` | 23 | 2 | 9% | 7% | 0 | — | 6.9 |
| 15 | `invrisil_merchant_prince` | 9 | 1 | 11% | 7% | 0 | — | 6.7 |
| 16 | `pallass_forge_clerk` | 10 | 1 | 10% | 6% | 0 | — | 6.2 |
| 17 | `pallass_market_clerk` | 10 | 1 | 10% | 6% | 0 | — | 6.2 |
| 18 | `hedault_enchanting` | 10 | 0 | 0% | 0% | 8 | neg correction 1 | 5.0 |
| 19 | `relc_intro` | 14 | 1 | 7% | 5% | 0 | — | 5.0 |
| 20 | `renn_hammer` | 5 | 0 | 0% | 0% | 8 | neg correction 1 | 5.0 |
| 21 | `pallass_lift_attendant` | 15 | 1 | 7% | 5% | 0 | — | 4.8 |
| 22 | `riverfarm_witch` | 17 | 1 | 6% | 4% | 0 | — | 4.3 |
| 23 | `olesm_intro` | 40 | 1 | 2% | 2% | 0 | — | 2.2 |
| 24 | `pallass_den_keeper` | 7 | 0 | 0% | 0% | 0 | noun repeat wit 1 | 1.0 |
| 25 | `_shared_lines` | 5 | 0 | 0% | 0% | 0 | — | 0.0 |
| 26 | `boulevard_duel_ring` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 27 | `ceria_intro` | 9 | 0 | 0% | 0% | 0 | — | 0.0 |
| 28 | `corusdeer_range` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 29 | `crab_nest` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 30 | `door_mounting` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 31 | `drayman_dispute` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 32 | `dresk_recruit` | 8 | 0 | 0% | 0% | 0 | — | 0.0 |
| 33 | `dummies_note` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 34 | `erin_errand` | 25 | 0 | 0% | 0% | 0 | — | 0.0 |
| 35 | `forge_calibration_golem` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 36 | `gallery_vermin_nest` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 37 | `goblin_parley` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 38 | `grimalkin_inn` | 4 | 0 | 0% | 0% | 0 | — | 0.0 |
| 39 | `invrisil_fixer` | 16 | 0 | 0% | 0% | 0 | — | 0.0 |
| 40 | `invrisil_hired_scribe` | 8 | 0 | 0% | 0% | 0 | — | 0.0 |
| 41 | `invrisil_house_steward` | 5 | 0 | 0% | 0% | 0 | — | 0.0 |
| 42 | `invrisil_rest_factor` | 5 | 0 | 0% | 0% | 0 | — | 0.0 |
| 43 | `invrisil_seal_broker` | 10 | 0 | 0% | 0% | 0 | — | 0.0 |
| 44 | `kingslayer_den` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 45 | `klbkch_inn` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 46 | `ksmvr_intro` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 47 | `lyonette_tip` | 9 | 0 | 0% | 0% | 0 | — | 0.0 |
| 48 | `market_watchgolems` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 49 | `octavia` | 6 | 0 | 0% | 0% | 0 | — | 0.0 |
| 50 | `olesm_inn` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 51 | `pallass_forge_smith` | 15 | 0 | 0% | 0% | 0 | — | 0.0 |
| 52 | `pallass_grimalkin` | 9 | 0 | 0% | 0% | 0 | — | 0.0 |
| 53 | `pallass_market_local` | 5 | 0 | 0% | 0% | 0 | — | 0.0 |
| 54 | `patron_serving` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 55 | `peddler_stall` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 56 | `pisces_inn` | 6 | 0 | 0% | 0% | 0 | — | 0.0 |
| 57 | `rags_meeting` | 19 | 0 | 0% | 0% | 0 | — | 0.0 |
| 58 | `razorbeak_nest` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 59 | `recruit_pell` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 60 | `relc_descent` | 2 | 0 | 0% | 0% | 0 | — | 0.0 |
| 61 | `relc_inn` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 62 | `riverfarm_headman` | 15 | 0 | 0% | 0% | 0 | — | 0.0 |
| 63 | `riverfarm_hunter` | 11 | 0 | 0% | 0% | 0 | — | 0.0 |
| 64 | `riverfarm_thicket_patch` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 65 | `room_ledger` | 10 | 0 | 0% | 0% | 0 | — | 0.0 |
| 66 | `selys_inn` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 67 | `vess_counter` | 1 | 0 | 0% | 0% | 0 | — | 0.0 |
| 68 | `watch_crate` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 69 | `wilovan_inn` | 4 | 0 | 0% | 0% | 0 | — | 0.0 |
| 70 | `xif` | 4 | 0 | 0% | 0% | 0 | — | 0.0 |
| 71 | `yvlon_intro` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |
| 72 | `zevara_inn` | 3 | 0 | 0% | 0% | 0 | — | 0.0 |

## Top 10 by score — the Phase 3 shortlist

### 1. `krshia_crate` — density 19% (5/26), shared geom 8, score 20.6
Speakers: Krshia, narrator. 1018 words.

- smoke 3/5 · `$.nodes.hub.text_variants[0].text`
  > Stall closes with the light. Come back at a decent hour, or knock loud enough I know it is not the wind.
- smoke 2/5 · `$.nodes.wrong_order_recap.text`
  > The inn's shortfall, yes. Smooth it here at my stall, or settle it your own way. Either gets Lyonette her full order.

### 2. `pisces_seal` — density 21% (3/14), shared geom 8, score 20.0
Speakers: Pisces. 766 words.

- smoke 2/5 · `$.nodes.fork_reward_done.text_variants[0].text`
  > There. It runs again, and the work it runs through this time is yours, which will outlast the city and annoy me for the rest of my life. It is a repair, and the door behind it stays open; I would call it a rescue if the facts allowed. They do not. I have decided that is the outcome I wanted, and I will be saying so as though I said it first.
- smoke 2/5 · `$.nodes.fork_reward_done.text`
  > There. The pour runs the way it always did, and the work it runs through now is yours, which will outlast the city and annoy me for the rest of my life. Whatever is back there gets to keep sleeping. I have decided that is the outcome I wanted, and I will be saying so as though I said it first.

### 3. `riverfarm_villager` — density 33% (1/3), shared geom 8, score 17.1
Speakers: A Villager. 115 words.

- smoke 2/5 · `$.nodes.remember.text`
  > Pieces. A price I said yes to. Never read the terms, none of us did. There was a voice in my mouth for weeks and it weren't mine. I should be angry. I keep meaning to be angry.

### 4. `forge_temper_golem` — density 100% (1/1), shared geom 0, score 14.3
Speakers: Calibration Rig. 51 words.

- smoke 3/5 · `$.nodes.confront.text`
  > The rig registers you, corrects a half-beat late, and registers you again. Its gauges swing past their own marks and settle wrong. Three of the four needles disagree. The fourth is not moving at all.

### 5. `rags_inn` — density 20% (1/5), shared geom 8, score 14.1
Speakers: Rags, narrator. 96 words.

- smoke 2/5 · `$.nodes.greet.text_variants[0].text`
  > You again. Camp ate. Still count doors. Habit, not you.

### 6. `ceria_dig_camp` — density 50% (1/2), shared geom 0, score 12.5
Speakers: Ceria. 129 words.

- smoke 3/5 · `$.nodes.camp_fourth.text`
  > Pisces. He's ours. He bills the team by invoice, and the roster carries four names with the hours split four ways. He takes his in the city with a treatise open, which is exactly where I want him until there's something down here worth reading. Three of us hold the shovels. That was the trade, and he argued it well.

### 7. `ksmvr_plates` — density 50% (1/2), shared geom 0, score 12.5
Speakers: Ksmvr, narrator. 35 words.

- smoke 2/5 · `$.text_banks.i_did_not_die_this_is_th`
  > I did not die. This is the preferred outcome.

### 8. `pisces_magic` — density 8% (3/40), shared geom 8, score 11.5
Speakers: Pisces, narrator. 2184 words.

- smoke 2/5 · `$.nodes.horns_bridge.text`
  > Horns of Hammerad. Yes. There is a name on their roster and a share of their debts attached to it. That is membership. I am not in the hole with them because the interesting half of the work is here — things that are written do not read themselves, and nobody else in this city can. Ceria calls that being hired. Ceria also calls my handwriting adequate, so her judgement is not beyond dispute.
- smoke 2/5 · `$.nodes.greet.text_variants[5].text`
  > Ward-lore from a hedge witch. Do not make that face — hers is older than the Guild's, and she fed hers too. Fed. That word keeps recurring.

### 9. `krshia_inn` — density 33% (1/3), shared geom 0, score 11.1
Speakers: Krshia. 99 words.

- smoke 2/5 · `$.nodes.greet.text`
  > A Human inn, and the food does not insult me. I walked up from the stall, and there is nobody haggling in my ear, yes?

### 10. `selys_delivery` — density 6% (1/17), shared geom 8, score 9.3
Speakers: Selys, narrator. 610 words.

- smoke 2/5 · `$.nodes.pallass_sponsor.text`
  > Pallass. Guild's got the standing arrangement. I file the sponsorship, you cover the clerk's fee — fee first, actually. It goes through same-day. Ten gold, paid to the Guild, not to me.

