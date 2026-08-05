# Dialogue graph heatmap — GH#397 Phase 3 targeting

**GENERATED** by `qa/scripts/extract_prose.py heatmap` — seed 397, python 3.12.3, deterministic (a re-run on the same tree is byte-identical). Do not hand-edit.

> ## ⚠ THE RANKING DOES NOT GRANT PERMISSION TO EDIT
>
> **Holdout ids and protected keeps are UNTOUCHABLE by Phase 3, regardless of
> where their graph ranks here.** A graph at the top of this table may be
> mostly holdout; a graph with one flagged node may carry the corpus's most
> important protected keep. The `keeps` and `holdout` columns below are the
> counts per graph and the exact ids are listed in §*Untouchable ids per
> graph*. Before and after any Phase 3 edit, run:
>
> ```
> python3 qa/scripts/extract_prose.py verify-untouched --dir docs/prose-naturalization
> ```
>
> It exits 1 with a diff list if any holdout or protected-keep string has
> moved a byte. That is the mechanical guard; this table is only a reading
> order.

Acceptance criterion 4: residual dialogue work is targeted by graph-level evidence, not a mandatory second rewrite of every file. This is that evidence.

**How to read it.** `density` = share of narrator/NPC `text` strings whose final sentence trips the button smoke score (>=2 of 5; see review-rubric.md §4). One population runs the ranking: narrator/NPC nodes. Player options are the player's voice, not the narrator's, so their flagged count and shape hits are reported in their own columns and do not enter the score. `shared geom` = every instance of a rhetorical shape this graph uses, weighted by how many OTHER graphs use the same shape — the issue's complaint is distributional, so a shape is damning in proportion to both its frequency here and its commonness elsewhere. `score` = adj_density*100 + shared_geom*0.5. **These are smoke detectors. A high row is a graph worth READING, never a graph proven bad**; a low row is not a clearance.

Corpus: 72 graphs, 577 narrator/NPC strings, 868 player options. Untouchable in dialogue: 6 protected keeps, 113 holdout strings.

`density` is raw; `adj` is the volume-shrunk density the ranking actually uses (flagged / (nodes + 6)), so a 1-node graph cannot top the list on a single hit.

| # | graph | nodes | flagged | density | adj | opts | opt flagged | shared geom | shape hits | keeps | holdout | score |
|--:|---|--:|--:|--:|--:|--:|--:|--:|---|--:|--:|--:|
| 1 | `krshia_crate` | 26 | 5 | 19% | 16% | 54 | 0 | 7 | neg correction 1 | 0 | 5 | 19.1 |
| 2 | `pisces_seal` | 14 | 3 | 21% | 15% | 20 | 0 | 7 | neg correction 1 | 0 | 5 | 18.5 |
| 3 | `riverfarm_villager` ⛔ | 3 | 1 | 33% | 11% | 3 | 0 | 14 | neg correction 2 | 2 | 0 | 18.1 |
| 4 | `forge_temper_golem` | 1 | 1 | 100% | 14% | 2 | 0 | 0 | — | 0 | 0 | 14.3 |
| 5 | `rags_inn` | 5 | 1 | 20% | 9% | 4 | 0 | 7 | neg correction 1 | 0 | 1 | 12.6 |
| 6 | `ceria_dig_camp` | 2 | 1 | 50% | 12% | 4 | 0 | 0 | — | 0 | 0 | 12.5 |
| 7 | `ksmvr_plates` | 2 | 1 | 50% | 12% | 4 | 0 | 0 | — | 0 | 1 | 12.5 |
| 8 | `krshia_inn` | 3 | 1 | 33% | 11% | 4 | 0 | 0 | — | 0 | 1 | 11.1 |
| 9 | `zevara_intro` | 24 | 1 | 4% | 3% | 41 | 0 | 14 | neg correction 2 | 0 | 5 | 10.3 |
| 10 | `pisces_magic` | 40 | 3 | 8% | 7% | 61 | 0 | 7 | neg correction 1 | 0 | 11 | 10.0 |
| 11 | `invrisil_stationer_client` | 17 | 2 | 12% | 9% | 19 | 0 | 0 | — | 0 | 4 | 8.7 |
| 12 | `riverfarm_tallyman` ⛔ | 6 | 1 | 17% | 8% | 7 | 0 | 0 | — | 0 | 0 | 8.3 |
| 13 | `selys_delivery` | 17 | 1 | 6% | 4% | 30 | 0 | 7 | neg correction 1 | 0 | 4 | 7.8 |
| 14 | `invrisil_wilovan` | 23 | 2 | 9% | 7% | 36 | 0 | 0 | — | 0 | 7 | 6.9 |
| 15 | `invrisil_merchant_prince` | 9 | 1 | 11% | 7% | 11 | 0 | 0 | — | 0 | 2 | 6.7 |
| 16 | `pallass_forge_clerk` | 10 | 1 | 10% | 6% | 18 | 0 | 0 | — | 0 | 1 | 6.2 |
| 17 | `pallass_market_clerk` | 10 | 1 | 10% | 6% | 7 | 0 | 0 | — | 0 | 2 | 6.2 |
| 18 | `relc_intro` | 14 | 1 | 7% | 5% | 25 | 0 | 0 | — | 0 | 0 | 5.0 |
| 19 | `pallass_lift_attendant` | 15 | 1 | 7% | 5% | 18 | 0 | 0 | — | 0 | 4 | 4.8 |
| 20 | `riverfarm_witch` ⛔ | 17 | 1 | 6% | 4% | 34 | 0 | 0 | — | 0 | 3 | 4.3 |
| 21 | `hedault_enchanting` | 10 | 0 | 0% | 0% | 20 | 0 | 7 | neg correction 1 | 0 | 5 | 3.5 |
| 22 | `olesm_intro` | 40 | 1 | 2% | 2% | 71 | 0 | 0 | — | 0 | 8 | 2.2 |
| 23 | `_shared_lines` | 5 | 0 | 0% | 0% | 0 | 0 | 0 | — | 0 | 0 | 0.0 |
| 24 | `boulevard_duel_ring` | 1 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 25 | `ceria_intro` | 9 | 0 | 0% | 0% | 7 | 0 | 0 | — | 0 | 2 | 0.0 |
| 26 | `corusdeer_range` | 1 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 1 | 0.0 |
| 27 | `crab_nest` | 1 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 0 | 0.0 |
| 28 | `door_mounting` | 2 | 0 | 0% | 0% | 3 | 0 | 0 | — | 0 | 0 | 0.0 |
| 29 | `drayman_dispute` | 3 | 0 | 0% | 0% | 3 | 0 | 0 | — | 1 | 0 | 0.0 |
| 30 | `dresk_recruit` | 8 | 0 | 0% | 0% | 8 | 0 | 0 | — | 0 | 2 | 0.0 |
| 31 | `dummies_note` | 1 | 0 | 0% | 0% | 1 | 0 | 0 | — | 0 | 0 | 0.0 |
| 32 | `erin_errand` | 25 | 0 | 0% | 0% | 38 | 1 | 0 | — | 1 | 4 | 0.0 |
| 33 | `forge_calibration_golem` | 1 | 0 | 0% | 0% | 3 | 0 | 0 | — | 0 | 0 | 0.0 |
| 34 | `gallery_vermin_nest` | 1 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 0 | 0.0 |
| 35 | `goblin_parley` | 2 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 2 | 0.0 |
| 36 | `grimalkin_inn` | 4 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 37 | `invrisil_fixer` | 16 | 0 | 0% | 0% | 27 | 0 | 0 | — | 0 | 1 | 0.0 |
| 38 | `invrisil_hired_scribe` | 8 | 0 | 0% | 0% | 11 | 0 | 0 | — | 0 | 0 | 0.0 |
| 39 | `invrisil_house_steward` | 5 | 0 | 0% | 0% | 10 | 0 | 0 | — | 0 | 4 | 0.0 |
| 40 | `invrisil_rest_factor` | 5 | 0 | 0% | 0% | 7 | 0 | 0 | — | 0 | 1 | 0.0 |
| 41 | `invrisil_seal_broker` | 10 | 0 | 0% | 0% | 16 | 0 | 0 | — | 0 | 3 | 0.0 |
| 42 | `kingslayer_den` | 1 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 0 | 0.0 |
| 43 | `klbkch_inn` | 3 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 44 | `ksmvr_intro` | 2 | 0 | 0% | 0% | 1 | 0 | 0 | — | 0 | 1 | 0.0 |
| 45 | `lyonette_tip` | 9 | 0 | 0% | 0% | 14 | 0 | 0 | — | 0 | 3 | 0.0 |
| 46 | `market_watchgolems` | 1 | 0 | 0% | 0% | 3 | 0 | 0 | — | 0 | 0 | 0.0 |
| 47 | `octavia` | 6 | 0 | 0% | 0% | 9 | 1 | 0 | — | 0 | 3 | 0.0 |
| 48 | `olesm_inn` | 3 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 49 | `pallass_den_keeper` | 7 | 0 | 0% | 0% | 12 | 0 | 0 | noun repeat wit 1 | 0 | 0 | 0.0 |
| 50 | `pallass_forge_smith` | 15 | 0 | 0% | 0% | 25 | 0 | 0 | — | 0 | 3 | 0.0 |
| 51 | `pallass_grimalkin` | 9 | 0 | 0% | 0% | 12 | 0 | 0 | — | 0 | 2 | 0.0 |
| 52 | `pallass_market_local` | 5 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 2 | 0.0 |
| 53 | `patron_serving` | 2 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 0 | 0.0 |
| 54 | `peddler_stall` | 2 | 0 | 0% | 0% | 6 | 0 | 0 | — | 0 | 2 | 0.0 |
| 55 | `pisces_inn` | 6 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 56 | `rags_meeting` | 19 | 0 | 0% | 0% | 28 | 0 | 0 | — | 1 | 2 | 0.0 |
| 57 | `razorbeak_nest` | 1 | 0 | 0% | 0% | 3 | 0 | 0 | — | 0 | 0 | 0.0 |
| 58 | `recruit_pell` | 2 | 0 | 0% | 0% | 1 | 0 | 0 | — | 0 | 0 | 0.0 |
| 59 | `relc_descent` | 2 | 0 | 0% | 0% | 4 | 0 | 0 | — | 1 | 0 | 0.0 |
| 60 | `relc_inn` | 3 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 61 | `renn_hammer` | 5 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |
| 62 | `riverfarm_headman` ⛔ | 15 | 0 | 0% | 0% | 23 | 0 | 0 | — | 0 | 1 | 0.0 |
| 63 | `riverfarm_hunter` ⛔ | 11 | 0 | 0% | 0% | 19 | 0 | 0 | — | 0 | 1 | 0.0 |
| 64 | `riverfarm_thicket_patch` ⛔ | 1 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 0 | 0.0 |
| 65 | `room_ledger` | 10 | 0 | 0% | 0% | 7 | 0 | 0 | — | 0 | 1 | 0.0 |
| 66 | `selys_inn` | 3 | 0 | 0% | 0% | 3 | 0 | 0 | — | 0 | 1 | 0.0 |
| 67 | `vess_counter` | 1 | 0 | 0% | 0% | 2 | 0 | 0 | — | 0 | 0 | 0.0 |
| 68 | `watch_crate` | 3 | 0 | 0% | 0% | 3 | 0 | 0 | — | 0 | 1 | 0.0 |
| 69 | `wilovan_inn` | 4 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 1 | 0.0 |
| 70 | `xif` | 4 | 0 | 0% | 0% | 9 | 2 | 0 | — | 0 | 0 | 0.0 |
| 71 | `yvlon_intro` | 3 | 0 | 0% | 0% | 1 | 0 | 0 | — | 0 | 0 | 0.0 |
| 72 | `zevara_inn` | 3 | 0 | 0% | 0% | 4 | 0 | 0 | — | 0 | 0 | 0.0 |

⛔ = `riverfarm_*`: **excluded from the Phase 3 shortlist by controller ruling** — riverfarm is out of scope for this pass. The rows stay in the table because dropping them from the measurement would corrupt the shared-geometry denominators every other graph is scored against; they are simply not work.

## Top 10 by score — the Phase 3 shortlist

riverfarm_* graphs are skipped here per the ruling above.

### 1. `krshia_crate` — density 19% (5/26), shared geom 7, score 19.1
Speakers: Krshia, narrator. 1018 words. **Untouchable here: 0 keeps, 5 holdout.**

- smoke 3/5 · `dlg:krshia_crate.json:$.nodes.hub.text_variants[0].text`
  > Stall closes with the light. Come back at a decent hour, or knock loud enough I know it is not the wind.
- smoke 2/5 · `dlg:krshia_crate.json:$.nodes.wrong_order_recap.text`
  > The inn's shortfall, yes. Smooth it here at my stall, or settle it your own way. Either gets Lyonette her full order.

### 2. `pisces_seal` — density 21% (3/14), shared geom 7, score 18.5
Speakers: Pisces. 766 words. **Untouchable here: 0 keeps, 5 holdout.**

- smoke 2/5 · `dlg:pisces_seal.json:$.nodes.fork_reward_done.text_variants[0].text`
  > There. It runs again, and the work it runs through this time is yours, which will outlast the city and annoy me for the rest of my life. It is a repair, and the door behind it stays open; I would call it a rescue if the facts allowed. They do not. I have decided that is the outcome I wanted, and I will be saying so as though I said it first.
- smoke 2/5 · `dlg:pisces_seal.json:$.nodes.fork_reward_done.text`
  > There. The pour runs the way it always did, and the work it runs through now is yours, which will outlast the city and annoy me for the rest of my life. Whatever is back there gets to keep sleeping. I have decided that is the outcome I wanted, and I will be saying so as though I said it first.

### 3. `forge_temper_golem` — density 100% (1/1), shared geom 0, score 14.3
Speakers: Calibration Rig. 51 words. **Untouchable here: 0 keeps, 0 holdout.**

- smoke 3/5 · `dlg:forge_temper_golem.json:$.nodes.confront.text`
  > The rig registers you, corrects a half-beat late, and registers you again. Its gauges swing past their own marks and settle wrong. Three of the four needles disagree. The fourth is not moving at all.

### 4. `rags_inn` — density 20% (1/5), shared geom 7, score 12.6
Speakers: Rags, narrator. 96 words. **Untouchable here: 0 keeps, 1 holdout.**

- smoke 2/5 · `dlg:rags_inn.json:$.nodes.greet.text_variants[0].text`
  > You again. Camp ate. Still count doors. Habit, not you.

### 5. `ceria_dig_camp` — density 50% (1/2), shared geom 0, score 12.5
Speakers: Ceria. 129 words. **Untouchable here: 0 keeps, 0 holdout.**

- smoke 3/5 · `dlg:ceria_dig_camp.json:$.nodes.camp_fourth.text`
  > Pisces. He's ours. He bills the team by invoice, and the roster carries four names with the hours split four ways. He takes his in the city with a treatise open, which is exactly where I want him until there's something down here worth reading. Three of us hold the shovels. That was the trade, and he argued it well.

### 6. `ksmvr_plates` — density 50% (1/2), shared geom 0, score 12.5
Speakers: Ksmvr, narrator. 54 words. **Untouchable here: 0 keeps, 1 holdout.**

- smoke 2/5 · `dlg:ksmvr_plates.json:$.text_banks.i_did_not_die_this_is_th`
  > I did not die. This is the preferred outcome.

### 7. `krshia_inn` — density 33% (1/3), shared geom 0, score 11.1
Speakers: Krshia. 99 words. **Untouchable here: 0 keeps, 1 holdout.**

- smoke 2/5 · `dlg:krshia_inn.json:$.nodes.greet.text`
  > A Human inn, and the food does not insult me. I walked up from the stall, and there is nobody haggling in my ear, yes?

### 8. `zevara_intro` — density 4% (1/24), shared geom 14, score 10.3
Speakers: Zevara, narrator. 1062 words. **Untouchable here: 0 keeps, 5 holdout.**

- smoke 2/5 · `dlg:zevara_intro.json:$.nodes.summons_send.text`
  > Good. See Olesm before you climb down. He's been up since the second bell drawing what shouldn't be there, and he'll want you carrying it. And take Relc. That's an order.

### 9. `pisces_magic` — density 8% (3/40), shared geom 7, score 10.0
Speakers: Pisces, narrator. 2184 words. **Untouchable here: 0 keeps, 11 holdout.**

- smoke 2/5 · `dlg:pisces_magic.json:$.nodes.horns_bridge.text`
  > Horns of Hammerad. Yes. There is a name on their roster and a share of their debts attached to it. That is membership. I am not in the hole with them because the interesting half of the work is here — things that are written do not read themselves, and nobody else in this city can. Ceria calls that being hired. Ceria also calls my handwriting adequate, so her judgement is not beyond dispute.
- smoke 2/5 · `dlg:pisces_magic.json:$.nodes.greet.text_variants[5].text`
  > Ward-lore from a hedge witch. Do not make that face — hers is older than the Guild's, and she fed hers too. Fed. That word keeps recurring.

### 10. `invrisil_stationer_client` — density 12% (2/17), shared geom 0, score 8.7
Speakers: A Lady with a Ring Box, narrator. 952 words. **Untouchable here: 0 keeps, 4 holdout.**

- smoke 3/5 · `dlg:invrisil_stationer_client.json:$.nodes.commission.text_variants[4].text`
  > I answered it in my own hand. Two lines and no apology in either of them. That is the first thing I have signed in eleven years that nobody had to be told about afterwards.
- smoke 3/5 · `dlg:invrisil_stationer_client.json:$.nodes.commission.text`
  > I have been sitting in a paper shop for an hour. On this street it is the one room where a woman may hold something closed and nobody asks her to open it. You are the first person to stop at this table.

## Untouchable ids per graph

`K` = protected keep (never rewritten, even where it trips a rule — the keep outranks the rule). `H` = holdout (Phase 5 reads it untouched; editing it destroys the exit comparison). Absence from this list is not permission to rewrite: the default action on a string nobody flagged is to leave it alone.

- **`krshia_crate`** — 0K / 5H
  - H `dlg:krshia_crate.json:$.nodes.hub.options[4].text`
  - H `dlg:krshia_crate.json:$.nodes.hub.options[8].text`
  - H `dlg:krshia_crate.json:$.nodes.hub.text_variants[6].text`
  - H `dlg:krshia_crate.json:$.nodes.smoothed_paid.text`
  - H `dlg:krshia_crate.json:$.nodes.thanks.text`
- **`pisces_seal`** — 0K / 5H
  - H `dlg:pisces_seal.json:$.nodes.at_the_door.text_variants[4].text`
  - H `dlg:pisces_seal.json:$.nodes.fork_open.text`
  - H `dlg:pisces_seal.json:$.nodes.fork_reward.options[0].text`
  - H `dlg:pisces_seal.json:$.nodes.fork_reward.options[2].text`
  - H `dlg:pisces_seal.json:$.nodes.the_choice.options[1].text`
- **`riverfarm_villager`** — 2K / 0H
  - K `dlg:riverfarm_villager.json:$.nodes.hub.text`
  - K `dlg:riverfarm_villager.json:$.nodes.remember.text`
- **`rags_inn`** — 0K / 1H
  - H `dlg:rags_inn.json:$.nodes.greet.text`
- **`ksmvr_plates`** — 0K / 1H
  - H `dlg:ksmvr_plates.json:$.text_banks.i_did_not_die_this_is_th`
- **`krshia_inn`** — 0K / 1H
  - H `dlg:krshia_inn.json:$.nodes.served.text`
- **`zevara_intro`** — 0K / 5H
  - H `dlg:zevara_intro.json:$.nodes.hub.options[2].text`
  - H `dlg:zevara_intro.json:$.nodes.hub.options[6].text`
  - H `dlg:zevara_intro.json:$.nodes.hub.text_variants[2].text`
  - H `dlg:zevara_intro.json:$.nodes.hub.text_variants[4].text`
  - H `dlg:zevara_intro.json:$.nodes.summons.text`
- **`pisces_magic`** — 0K / 11H
  - H `dlg:pisces_magic.json:$.nodes.consult_fight_response.text`
  - H `dlg:pisces_magic.json:$.nodes.consult_skill_report.text`
  - H `dlg:pisces_magic.json:$.nodes.consult_talk_pitch.options[0].text`
  - H `dlg:pisces_magic.json:$.nodes.descent_ask.options[0].text`
  - H `dlg:pisces_magic.json:$.nodes.descent_ask.text`
  - H `dlg:pisces_magic.json:$.nodes.door_consult.options[1].text`
  - H `dlg:pisces_magic.json:$.nodes.greet.options[13].text`
  - H `dlg:pisces_magic.json:$.nodes.greet.options[4].text`
  - H `dlg:pisces_magic.json:$.nodes.greet.text_variants[3].text`
  - H `dlg:pisces_magic.json:$.nodes.greet.text_variants[7].text`
  - H `dlg:pisces_magic.json:$.nodes.lesson_casting.text`
- **`invrisil_stationer_client`** — 0K / 4H
  - H `dlg:invrisil_stationer_client.json:$.nodes.commission.text_variants[0].text`
  - H `dlg:invrisil_stationer_client.json:$.nodes.handover.text`
  - H `dlg:invrisil_stationer_client.json:$.nodes.terms.text`
  - H `dlg:invrisil_stationer_client.json:$.nodes.terms_card.text`
- **`selys_delivery`** — 0K / 4H
  - H `dlg:selys_delivery.json:$.nodes.errand_kept.text`
  - H `dlg:selys_delivery.json:$.nodes.hub.text`
  - H `dlg:selys_delivery.json:$.nodes.pallass_sponsor.text`
  - H `dlg:selys_delivery.json:$.nodes.selys_board_context.text`
- **`invrisil_wilovan`** — 0K / 7H
  - H `dlg:invrisil_wilovan.json:$.nodes.fence.text`
  - H `dlg:invrisil_wilovan.json:$.nodes.hat_errand.text`
  - H `dlg:invrisil_wilovan.json:$.nodes.hub.options[3].text`
  - H `dlg:invrisil_wilovan.json:$.nodes.hub.options[6].text`
  - H `dlg:invrisil_wilovan.json:$.nodes.hub.options[8].text`
  - H `dlg:invrisil_wilovan.json:$.nodes.marker.text`
  - H `dlg:invrisil_wilovan.json:$.nodes.why_you.text`
- **`invrisil_merchant_prince`** — 0K / 2H
  - H `dlg:invrisil_merchant_prince.json:$.nodes.cornered.options[0].text`
  - H `dlg:invrisil_merchant_prince.json:$.nodes.hub.text_variants[1].text`
- **`pallass_forge_clerk`** — 0K / 1H
  - H `dlg:pallass_forge_clerk.json:$.nodes.hub.options[1].text`
- **`pallass_market_clerk`** — 0K / 2H
  - H `dlg:pallass_market_clerk.json:$.nodes.hub.text_variants[1].text`
  - H `dlg:pallass_market_clerk.json:$.nodes.hub.text_variants[2].text`
- **`pallass_lift_attendant`** — 0K / 4H
  - H `dlg:pallass_lift_attendant.json:$.nodes.cycle.text`
  - H `dlg:pallass_lift_attendant.json:$.nodes.hub.text_variants[0].text`
  - H `dlg:pallass_lift_attendant.json:$.nodes.ledger_report.options[0].text`
  - H `dlg:pallass_lift_attendant.json:$.nodes.traffic.text`
- **`riverfarm_witch`** — 0K / 3H
  - H `dlg:riverfarm_witch.json:$.nodes.witch_lesson.options[1].text`
  - H `dlg:riverfarm_witch.json:$.nodes.witch_lesson.text`
  - H `dlg:riverfarm_witch.json:$.nodes.witch_ward_lore.text`
- **`hedault_enchanting`** — 0K / 5H
  - H `dlg:hedault_enchanting.json:$.nodes.heirloom_bench.options[0].text`
  - H `dlg:hedault_enchanting.json:$.nodes.heirloom_truth.options[0].text`
  - H `dlg:hedault_enchanting.json:$.nodes.hub.options[1].text`
  - H `dlg:hedault_enchanting.json:$.nodes.hub.options[5].text`
  - H `dlg:hedault_enchanting.json:$.nodes.hub.options[6].text`
- **`olesm_intro`** — 0K / 8H
  - H `dlg:olesm_intro.json:$.nodes.cisterns.text_variants[2].text`
  - H `dlg:olesm_intro.json:$.nodes.hub.options[9].text`
  - H `dlg:olesm_intro.json:$.nodes.lism_errand.text`
  - H `dlg:olesm_intro.json:$.nodes.olesm_chess_loss.text`
  - H `dlg:olesm_intro.json:$.nodes.olesm_chess_puzzle.options[1].text`
  - H `dlg:olesm_intro.json:$.nodes.olesm_chess_setup.text`
  - H `dlg:olesm_intro.json:$.nodes.seal_bounty_posted.text`
  - H `dlg:olesm_intro.json:$.nodes.seal_survey_offer.text`
- **`ceria_intro`** — 0K / 2H
  - H `dlg:ceria_intro.json:$.nodes.dig_unknown.text`
  - H `dlg:ceria_intro.json:$.nodes.hub.text`
- **`corusdeer_range`** — 0K / 1H
  - H `dlg:corusdeer_range.json:$.nodes.confront.options[1].text`
- **`drayman_dispute`** — 1K / 0H
  - K `dlg:drayman_dispute.json:$.nodes.calmed.text`
- **`dresk_recruit`** — 0K / 2H
  - H `dlg:dresk_recruit.json:$.nodes.hub.options[3].text`
  - H `dlg:dresk_recruit.json:$.nodes.hub.text_variants[3].text`
- **`erin_errand`** — 1K / 4H
  - K `dlg:erin_errand.json:$.nodes.door_paths.text`
  - H `dlg:erin_errand.json:$.nodes.erin_chess.text`
  - H `dlg:erin_errand.json:$.nodes.erin_pond.text`
  - H `dlg:erin_errand.json:$.nodes.errand_recap.text`
  - H `dlg:erin_errand.json:$.nodes.hub.options[7].text`
- **`goblin_parley`** — 0K / 2H
  - H `dlg:goblin_parley.json:$.nodes.backdown.text`
  - H `dlg:goblin_parley.json:$.nodes.hub.options[1].text`
- **`invrisil_fixer`** — 0K / 1H
  - H `dlg:invrisil_fixer.json:$.nodes.hub.options[7].text`
- **`invrisil_house_steward`** — 0K / 4H
  - H `dlg:invrisil_house_steward.json:$.nodes.answered.options[1].text`
  - H `dlg:invrisil_house_steward.json:$.nodes.waiting.options[0].text`
  - H `dlg:invrisil_house_steward.json:$.nodes.waiting.options[2].text`
  - H `dlg:invrisil_house_steward.json:$.nodes.waiting.options[3].text`
- **`invrisil_rest_factor`** — 0K / 1H
  - H `dlg:invrisil_rest_factor.json:$.nodes.table.text`
- **`invrisil_seal_broker`** — 0K / 3H
  - H `dlg:invrisil_seal_broker.json:$.nodes.named.options[1].text`
  - H `dlg:invrisil_seal_broker.json:$.nodes.table.text`
  - H `dlg:invrisil_seal_broker.json:$.nodes.talk_close.text`
- **`ksmvr_intro`** — 0K / 1H
  - H `dlg:ksmvr_intro.json:$.nodes.hub.text_variants[0].text`
- **`lyonette_tip`** — 0K / 3H
  - H `dlg:lyonette_tip.json:$.nodes.barmaid_retort.text`
  - H `dlg:lyonette_tip.json:$.nodes.gratitude.text`
  - H `dlg:lyonette_tip.json:$.nodes.hub.options[6].text`
- **`octavia`** — 0K / 3H
  - H `dlg:octavia.json:$.nodes.bought.text`
  - H `dlg:octavia.json:$.nodes.hub.options[1].text`
  - H `dlg:octavia.json:$.nodes.hub.text`
- **`pallass_forge_smith`** — 0K / 3H
  - H `dlg:pallass_forge_smith.json:$.nodes.commission_drift.text`
  - H `dlg:pallass_forge_smith.json:$.nodes.hub.options[4].text`
  - H `dlg:pallass_forge_smith.json:$.nodes.spec.text`
- **`pallass_grimalkin`** — 0K / 2H
  - H `dlg:pallass_grimalkin.json:$.nodes.forge_runes.text`
  - H `dlg:pallass_grimalkin.json:$.nodes.studies.options[0].text`
- **`pallass_market_local`** — 0K / 2H
  - H `dlg:pallass_market_local.json:$.nodes.hub.options[0].text`
  - H `dlg:pallass_market_local.json:$.nodes.hub.text_variants[0].text`
- **`peddler_stall`** — 0K / 2H
  - H `dlg:peddler_stall.json:$.nodes.bought.text`
  - H `dlg:peddler_stall.json:$.nodes.hub.options[2].text`
- **`rags_meeting`** — 1K / 2H
  - K `dlg:rags_meeting.json:$.nodes.winter_ways.text`
  - H `dlg:rags_meeting.json:$.nodes.winter_kept.text`
  - H `dlg:rags_meeting.json:$.nodes.winter_ways.options[1].text`
- **`relc_descent`** — 1K / 0H
  - K `dlg:relc_descent.json:$.nodes.join.text`
- **`riverfarm_headman`** — 0K / 1H
  - H `dlg:riverfarm_headman.json:$.nodes.favor_recap.text`
- **`riverfarm_hunter`** — 0K / 1H
  - H `dlg:riverfarm_hunter.json:$.nodes.hub.options[2].text`
- **`room_ledger`** — 0K / 1H
  - H `dlg:room_ledger.json:$.nodes.hub.options[1].text`
- **`selys_inn`** — 0K / 1H
  - H `dlg:selys_inn.json:$.nodes.served.text`
- **`watch_crate`** — 0K / 1H
  - H `dlg:watch_crate.json:$.nodes.hub.text`
- **`wilovan_inn`** — 0K / 1H
  - H `dlg:wilovan_inn.json:$.nodes.offduty.options[1].text`

