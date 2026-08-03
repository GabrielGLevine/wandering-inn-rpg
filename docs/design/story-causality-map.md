# Story causality map

Status: LIVING REFERENCE — agent-drafted from the data, controller hand-verified.
Deliverable of GH#338 (note 26), specified in
[`2026-08-02-quest-clarity-spec.md`](2026-08-02-quest-clarity-spec.md) §"Note 26".

This is the cause→effect map of the shipped story: every act gate, every quest
beat, every accomplishment producer→consumer edge, every region unlock, and
where a player is told about each link in fiction. It exists because the class
of bug wave-2 fixed twice — a counter with exactly one producer that nothing in
the world names (`invrisil_attuned`), a chain that was only accident-proof
(`dungeon_attuned`) — is invisible from inside any single file.

**Accuracy contract.** Every row below cites the file and id it came from.
Nothing here is remembered; it is all derived from `data/**` and `src/**` at the
SHA this doc was committed at. A link that could not be cited is in §7
(Unverified), not in a table. When a row and the data disagree, the DATA is
right and this doc is stale — regenerate (§0.3) and fix the row.

---

## 0. How to read and maintain this

### 0.1 Citation shorthand

| Shorthand | Means |
| --- | --- |
| `map#entity` | `wandering_inn_game/data/maps/<region>/<map>.json`, entity with that `id` |
| `graph:node#N` | `wandering_inn_game/data/dialogue/<graph>.json`, node `node`, option at index N (0-based, authored order) |
| `graph:node` | that node's `text_variants` / node-level fields |
| `quests.json:<quest>/<beat>` | `wandering_inn_game/data/quests.json` |
| `acts.json:<act>/<beat>` | `wandering_inn_game/data/acts.json` |
| `leads.json:<id>`, `portals.json:<id>`, `bounties.json:<id>` | those catalogs |
| `src/...gd:NNN` | line in the Godot source |

All paths are relative to `wandering_inn_game/` unless the repo root is written out.

### 0.2 The counter model in one paragraph

There is exactly one currency of story state: the **accomplishment counter** — a
free-form string id with an integer count, living in the save's
`accomplishments` dict. Everything gates on counters. Quests are not state
machines; `WIQuests.beat_index` (`src/core/quests.gd:5-37`) walks a quest's beats
and returns the first whose `complete_when` (AND) / `complete_when_any` (OR)
is unsatisfied — so a beat can be skipped entirely if a later counter banks
first. Acts are DERIVED, never saved: `WIActs.current_index`
(`src/core/acts.gd:17-24`) walks acts in order and stops at the first
`advance_when` that fails, so act gates are cumulative and ordered. The
completed-quest ending is `WIQuests.resolved_path` (`src/core/quests.gd:88-101`),
**last match wins** among `resolution_paths` entries that name a real counter,
with an `""`-accomplishment entry acting as the authored fallback.

### 0.3 Regenerating the census (do this before editing any table)

The producer census below is byte-equivalent to the one
`scripts/generate_shipped_ids.py` already runs (its module docstring documents
the five sources), so the fastest correctness check is:

```
cd wandering_inn_game
python3 scripts/generate_shipped_ids.py   # clean tree ⇒ byte-identical data/shipped_ids.json
```

A diff there means the producer set genuinely changed and this doc's §6 orphan
tables are stale. Note the shipped-ids census does NOT include the dynamic
`fought_<encounter_id>` family (§6.3.4) — add one per `kind: "encounter"` entity
in `data/maps/**` to reach the 569 this doc counts.

The consumer side has no shipped generator; the gate shapes that read counters
are enumerated in §5.3 — grep those keys. **Three traps in that regeneration,
all of which have bitten this doc:**

1. §5.3 is a DATA-gate list. It cannot see a counter that only `src/**` reads.
   Before calling anything an orphan, grep the id across `src/**` AND check the
   two shapes that never spell an id out literally: `fought_<encounter_id>`
   (`combat_banking.gd:122`) and `chatted_with_<npc>` (`wi_game.gd:900`), both
   built by string concatenation. `sign_defended` (§6.2) is the counter that
   proves the cost of missing this.
2. `arrival_toasts` is a MAP-level key, not an entity key — a census that walks
   `entities[]` never reaches it.
3. `talk_pool_stages[].requires_accomplishment` and `bounties`/`deliveries`
   `condition` are bare counter→count DICTS. Parsing either as a string or as an
   `{accomplishment: ...}` wrapper silently drops ~40 real consumers and
   manufactures phantom orphans.

Validate a regenerated census against this doc's arithmetic before trusting it:
producers 569 (529 frozen + 40 `fought_*`), data consumers 295, consumed-but-
never-produced 0, produced-but-not-data-consumed 274.

### 0.4 When you add a quest, a beat, or a counter

1. Add the quest's row to §2 (trigger → beats → sets → consumed-by).
2. Add each NEW counter to §6 if nothing consumes it yet, or state its consumer.
3. Every beat's completion counter needs **at least one producer that some
   in-fiction surface names** — a lead row, a board rumor, a relay talk stage,
   or the beat copy itself. A counter with one producer and no namer is the
   `invrisil_attuned` bug shape (§6.3.1).
4. Region unlocks go in §3.
5. This step is wired into `.agents/skills/wi-adding-dialogue-and-quests`.

---

## 1. Acts

Act gates read `min_classes`, `quests_completed`, and `accomplishments`
(`WIActs.conditions_met`, `src/core/acts.gd:5-14`). Beat rows render the beat's
banked `text` once its `when` is satisfied and its forward-looking `opening`
before that; a pending beat with no `opening` is dropped rather than showing
unearned outcome copy (`WIActs.render_beats`, `src/core/acts.gd:56-67`).

### Act I — Arrival (`acts.json:act_i`)

Advance when: `min_classes >= 1` **and** `reached_liscor >= 1`.

| Beat | Banks on | Produced by | Player learns it |
| --- | --- | --- | --- |
| `first_class` | `min_classes >= 1` (not a counter) | first class awarded at the sleep beat (`src/core/sleep_beat.gd`) | Relc's talk stage `floodplains#relc` `relc_sleep_nudge` (requires `sparred_with_relc`): "Go sleep at the inn — upstairs, real bed. Classes settle at the pillow"; then the class-gained toast |
| `reached_city` | `reached_liscor` | three doors, all `on_enter_accomplishment`: `floodplains#liscor_gate`, `floodplains#liscor_gate_west`, `floodplains#liscor_gate_east` | the doors' own `display_name` "To Liscor" — walking through is the whole link |

`reached_liscor` is consumed ONLY by the act catalog (`acts.json:act_i`
advance_when + `act_i/reached_city`) and by the finale recap
(`src/ui/sleep_veil.gd:117`).

### Act II — Make a Place for Yourself (`acts.json:act_ii`)

Advance when: `reached_two_classes >= 1` **and** `quests_completed >= 3`.

| Beat | Banks on | Produced by |
| --- | --- | --- |
| `errands_around` | `package_delivered` | `selys_delivery:hub#0`, `selys_delivery:hub#1` |
| `krshia_trust` | `crate_returned` | `krshia_crate:hub#1`, `krshia_crate:hub#2` |
| `watch_calls` | `cisterns_reported` | `olesm_intro:cisterns#1`, `#2`, `#3` |
| `known_face` | `reached_two_classes` + `quests_completed >= 3` | `reached_two_classes` is code-banked at the sleep beat (`src/core/sleep_beat.gd:131`, `_bank_reached_two_classes`) |

`reached_two_classes` is the hinge of the whole midgame: besides this act gate it
gates the Watch-runner pointer (`src/core/sleep_beat.gd:192`) and the Garden of
Sanctuary unlock (`src/core/sleep_beat.gd:207`). It is monotonic across class
consolidation by design (see `acts.json`'s own `_comment`).

### Act III — What Stirs Beneath (`acts.json:act_iii`)

Advance when: `raskghar_sealed >= 1`.

| Beat | Banks on | Produced by |
| --- | --- | --- |
| `the_stirring` | `heard_the_deep_tremor` | `zevara_intro:summons#0` |
| `warren_cleared` | `cleared_the_warren` | `deep_tunnels#awakened_boss` (`on_victory`) |

### Act IV — What the Door Opened (`acts.json:act_iv`)

Advance when: `lattice_forge_rune` **and** `seal_kept_reported` **and**
`price_of_a_favor_reported` **and** `brothers_job_done`, all `>= 1`. Transitivity
covers the rest of the pilgrimage (the act's own `_comment` states the reasoning:
`lattice_forge_rune` implies `spine_started` + `elevator_pass_stamped`;
`lattice_witch_lore` requires `price_of_a_favor_reported`;
`lattice_hedault_reading` requires `brothers_job_done`).

| Beat | Banks on | Produced by |
| --- | --- | --- |
| `counted_among` | `post_game` | code: first sleep after `raskghar_sealed` (`src/core/sleep_beat.gd:155-157`) |
| `the_door_opens` | `door_awakened` | code: third qualifying sleep (`src/core/sleep_beat.gd:159-163`) |
| `riverfarm_owed` | `price_of_a_favor_reported` | `riverfarm_headman:hub#1` |
| `invrisil_squared` | `brothers_job_done` | `invrisil_wilovan:hub#3` |
| `pallass_tiers` | `elevator_pass_stamped` | `pallass_forge_clerk:collect_stamp#0` |
| `the_horns_home` | `seal_kept_reported` | `olesm_intro:hub#12` |
| `the_reach_mapped` | `lattice_forge_rune` | `pallass_grimalkin:forge_runes#0` |

### Act V — What the Seal Was Feeding (`acts.json:act_v`)

Advance when: `seal_resolved >= 1` — defined but unreachable, because Act V is
last (`WIActs.current_index` stops at `size() - 1`). Naming it here gives the
finale a single gate to read and lets a maxed save light every beat this act owns.

| Beat | Banks on | Produced by |
| --- | --- | --- |
| `the_descent` | `seal_descent_agreed` | `pisces_magic:descent_ask#1`, `pisces_magic:descent_expect#0` |
| `the_reading` | `read_the_feeding_ward` | `trapped_halls#seal_kept_door` (interact `variants`, and `skill_uses[detect_magic].variants`), `pisces_seal:at_the_door#0` |
| `the_answer` | `seal_resolved` | `seal_vault#vault_anchor_stone` (`on_open`), `olesm_intro:seal_bounty_pitch#0/#1`, `pisces_seal:fork_reward#0/#1` |

---

## 2. Quests — trigger → beats → sets → consumed-by

24 quests ship (`data/quests.json`). Every table follows the same shape.

**Column contract.** "Consumed by" lists **structural** consumers only — act
gates, other quests' beats, portal gates, entity `present_when` /
`encounter_when` / `door_when` / `fence_menu_when`, lead rows, class/bounty
conditions, and code reads. Conversational reads (`option.requires`,
`option.hide_when`, `text_variants.requires`) are deliberately omitted: nearly
every terminal counter has 5–20 of them and listing them would bury the
structural edges. Full lists are one grep away (§0.3, §5.3).

### 2.1 Liscor, opening arc

#### `the_errand` — "The Errand"

* **Trigger:** `erin_errand:hub#0` "I'll take the package." (`inn#erin`), no
  requires, hides on `has_package`. Banks `has_package`.
* **Learned at:** Erin's opening line; Lyonette's tip option (`lyonette_tip`)
  banks `lyonette_tip`, which unlocks the smoother delivery rung.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `deliver` | `package_delivered` | `selys_delivery:hub#0`, `selys_delivery:hub#1` (the `lyonette_tip` rung, which also banks `selys_impressed`) |
| `decide` | `errand_decided` | `selys_delivery:delivered#0/#1`, `selys_delivery:delivered_smooth#0/#1` |

* **Resolution (fork-exclusive):** `kept_reward` (`delivered#0`,
  `delivered_smooth#0`) / `gave_reward` (`delivered#1`, `delivered_smooth#1`).
* **Consumed by:** `package_delivered` → `acts.json:act_ii/errands_around`.
  `errand_decided` → talk stages `inn#erin` `erin_regular`, `guild#selys`
  `selys_past_the_counter`.
* **Downstream:** `reward_acknowledged` (`erin_errand:hub#3/#4`) is one of the
  three gates on `floodplains#rags_scouting_party`'s `encounter_when.requires`.

#### `missing_crate` — "The Missing Crate"

* **Trigger:** `krshia_crate:hub#0` "I'll look into it." (`street#krshia`), hides
  on `asked_about_crate`. Banks `asked_about_crate`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `find` | `found_the_crate` | `street#crate_scavengers` (`on_victory`), `krshia_crate:hub#1`, `watch_crate:hub#0/#2` |
| `report` | `crate_returned` | `krshia_crate:hub#1`, `krshia_crate:hub#2` |

* **Resolution ladder (weakest first, last match wins):** `recovered_crate_guile`
  < `recovered_crate_watch` < `recovered_crate_force`.
* **Consumed by:** `crate_returned` → `acts.json:act_ii/krshia_trust`; talk stages
  `street#krshia` `krshia_fair_weight` / `krshia_friend_of_the_silverfangs`;
  `street#cellar_door` (`skill_uses` variant gate).

#### `cisterns` — "Something in the Cisterns"

* **Trigger:** `olesm_intro:cisterns#0` (`street#olesm`), hides on
  `heard_about_cisterns`. Banks `heard_about_cisterns` — which is ALSO the
  door gate on `street#sewer_grate` (`door_when.requires`), i.e. the quest-start
  counter is what physically opens the sewers.
* **Learned at:** relay stages `inn#erin` `erin_thread_cisterns`, `street#krshia`
  `krshia_thread_cisterns`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `resolved_the_cisterns` OR `scouted_the_nest` | `sewers#shield_spiders` (`on_victory`), `olesm_intro:cisterns#3`, `zevara_intro:sweep_argue#0/#2` — and `sewers#nest_ledge` (`on_skill_use[observe]`) for the scout leg |
| `report` | `cisterns_reported` | `olesm_intro:cisterns#1/#2/#3` |

* **The OR-producer idiom lives here** (`src/core/quests.gd:16-26`): the scout
  route banks only `scouted_the_nest` at the ledge and picks up
  `resolved_the_cisterns` later from Olesm's report, so the beat needs the OR arm
  or the journal keeps telling a finished player to go do it.
* **Consumed by:** `cisterns_reported` → `acts.json:act_ii/watch_calls`; talk
  stages on `inn#erin`, `street#zevara`, `street#olesm` (`olesm_board_partner`).

#### `wrong_order` — "The Wrong Order"

* **Trigger:** `lyonette_tip:hub#3` (`inn#lyonette`), hides on `heard_wrong_order`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `resolved_wrong_order` OR `stretched_the_order` | `street#supplier_scavengers` (`on_victory`), `krshia_crate:hub#3/#4`, `lyonette_tip:hub#6`; kitchen leg `inn#short_order` (`on_skill_use[basic_cooking]`) |
| `report` | `wrong_order_reported` | `lyonette_tip:hub#4/#5/#6` |

* **Resolution ladder:** `stretched_the_order` < `smoothed_with_krshia` <
  `strongarmed_the_supplier`.
* **Consumed by:** `resolved_wrong_order` is a **Garden of Sanctuary leg**
  (`src/core/sleep_beat.gd:209`) and the gate on the tier-1 room upgrade
  (`room_ledger:hub#0`).

#### `the_missing_recruit` — "The Missing Recruit"

* **Trigger:** `dresk_recruit:hub#1` (`barracks#duty_sergeant`), requires
  `heard_about_missing_recruit`, hides on `missing_recruit_started`.
* **Learned at:** `guild#guild_board` board rumor `rumor_missing_recruit`
  (`banks_accomplishment: heard_about_missing_recruit`) — the rumor is the ONLY
  producer of that counter, and the real quest option lives on the sergeant.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `search` | `found_missing_recruit` | `recruit_pell:hub#0` |
| `report` | `recruit_reported_safe` | `dresk_recruit:hub#2` |

* `missing_recruit_started` gates `sewers#recruit_pell`'s `present_when` — Pell
  does not exist in the sewers until the quest is taken.

#### `renns_warhammer` — "Renn's Old Warhammer"

* **Trigger:** `renn_hammer:hub#1` (`guild#renn`), requires
  `heard_about_lost_hammer` (sole producer: `guild#guild_board` rumor
  `rumor_lost_hammer`), hides on `hammer_quest_started`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `search` | `found_the_warhammer` | `guild#renns_gear_stash` (`on_open`) |
| `report` | `returned_the_warhammer` | `renn_hammer:hub#2` |

* **Consumed by:** nothing structural. This is a closed two-beat side thread.

### 2.2 The main spine

#### `something_beneath` — "Something Beneath" (Act III)

* **Trigger:** CODE, not dialogue. `src/core/sleep_beat.gd:187-205`
  (`_maybe_fire_tremor_pointer`) fires at a sleep when
  `watch_runner_pointed < 1`, `heard_the_deep_tremor < 1`,
  `reached_two_classes >= 1`, and `quests_completed >= 3`. It banks
  `watch_runner_pointed` and calls `start_quest("something_beneath")`.
  `src/core/save.gd:327-332` backfills the started-quest row for saves that
  predate GH#167.
* **Learned at:** the sticky lore toast "A Watch runner is looking for you."
  (`sleep_beat.gd:200`), the veil line `WATCH_RUNNER_VEIL_LINE`
  (`src/ui/sleep_veil.gd:188`, guaranteed read under the black), and relay stages
  `inn#erin` `erin_thread_gate_runner`, `street#olesm` `olesm_thread_gate_runner`,
  `street#krshia` `krshia_thread_gate_runner`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `summons` | `heard_the_deep_tremor` | `zevara_intro:summons#0` |
| `delve` | `cleared_the_warren` | `deep_tunnels#awakened_boss` (`on_victory`) |
| `report` | `raskghar_sealed` | `zevara_intro:hub#3` |

* **Consumed by:** `raskghar_sealed` → `acts.json:act_iii` advance_when;
  `post_game` bank (`sleep_beat.gd:155`); `garden_sanctuary#memorial_plot_seal`
  visual state; `inn#zevara_inn_guest_returned` `present_when`.
* **`post_game` is the Act IV / gallery hinge:** it gates `olesm_intro:hub#11`
  (the `what_the_seal_kept` start) and `leads.json:lead_survey`. Despite the name
  it banks MID-story, at the first sleep after the seal.

#### `what_the_seal_kept` — "What the Seal Kept" (Liscor)

* **Trigger:** `olesm_intro:hub#11` "That Watch notice — the gallery survey."
  (`street#olesm`), requires `post_game`, hides on `horns_delve_started`.
* **Learned at:** `leads.json:lead_survey` (requires `post_game`, hides on
  `horns_delve_started`, place "Adventurer's Guild"); `guild#guild_board` rumor
  `heard_of_the_gallery_survey`; relay stages `inn#erin`
  `erin_thread_horns_gallery`, `guild#selys` `selys_thread_horns_gallery`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `delve` | `horns_party_formed` | `ceria_intro:rules#0` |
| `halls` | `halls_cleared` | `trapped_halls#dart_slit_a` (`on_skill_use[observe]`), `trapped_halls#snare_nest_slot` (`on_victory`), `ksmvr_plates:hub#0` |
| `vault` | `seal_kept_found` | `trapped_halls#seal_kept_door` interact variant `when {vault_construct_downed: 1}` |
| `report` | `seal_kept_reported` | `olesm_intro:hub#12` |

* **Resolution ladder:** `guided_ksmvr_through_plates` < `cleared_halls_by_force`
  < `""` fallback (the trap-kit disarm — a REAL route, not a default; see the
  quest's `_resolution_order` note).
* **`horns_delve_started` is a world gate, not bookkeeping:** it opens
  `dungeon_approach#gallery_seal_anchor` (`door_when`), `deep_tunnels#warren_mouth`
  (`door_when`), and arms `trapped_halls#snare_nest_slot` (`encounter_when`).
* **Consumed by:** `seal_kept_reported` → `acts.json:act_iv` advance_when +
  `act_iv/the_horns_home`; `ceria_intro:hub#1` (the `horns_dig` start);
  `leads.json:lead_dig`; the Horns' inn presence (`inn#ceria_inn`,
  `inn#yvlon_inn`, `inn#ksmvr_inn` `present_when.requires`).

#### `horns_dig` — "The Dig" (Liscor)

* **Trigger:** `ceria_intro:hub#1` (`dungeon_approach#ceria`, `inn#ceria_inn`,
  `inn#ceria_inn_returned`), requires `seal_kept_reported`, hides on
  `horns_dig_started`.
* **Learned at:** `leads.json:lead_dig` (place "The Wandering Inn").

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `join_dig` | `horns_dig_joined` | `ceria_dig_camp:camp_hub#0` |
| `breach` | `pedestal_breached` | `ruin_surface#anchor_stone_pedestal` (`on_open_accomplishment: ["recovered_anchor_stone", "pedestal_breached", "door_retrieved"]`) |
| `haul` | `door_mounted` | `door_mounting:door_mounting#1`, `door_mounting:door_mounting_far#0` |

* The pedestal is gated by `contains_when.requires: {pedestal_unsealed,
  rune_sequence_done, horns_dig_joined}` — so the breach beat cannot be reached
  before joining the camp. Beats here are genuinely order-gated (the quest's own
  `_comment` says so, and the data agrees).
* `horns_dig_started` also opens `floodplains#ruin_door` (`door_when.requires`)
  and removes the Horns from the dungeon approach (`present_when.absent` on
  `dungeon_approach#ceria`, `#yvlon`, `#ksmvr`, `trapped_halls#ksmvr_plates`).
* **`door_mounted` is the largest single fan-out counter in the game** — 27
  consumer sites. It gates `portals.json:liscor_street` and
  `portals.json:the_wandering_inn` (the day-one inn↔Liscor hop); THREE of the six
  portal carriers (`inn#pantry_door`, `street#street_anchor_stone`,
  `invrisil_boulevard#invrisil_anchor_stone`) plus a fourth,
  `riverfarm_village#riverfarm_anchor_stone`, whose own portal row gates on
  `door_awakened` instead (§3); `inn#pantry_door` and `street#street_anchor_stone`
  `visual_states`; `inn#rift_vermin_leak` (`encounter_when` + `visual_states`);
  the Horns' and Pisces' "returned" inn variants (`present_when`);
  `inn#pisces_mounting` (`present_when` — this is the counter that RETIRES the
  mounting scene); the ten `ruin_surface` dig-camp rows (`present_when`);
  `quests.json:horns_dig`; and `erin_errand`.

#### `door_that_goes_elsewhere` — "The Door That Goes Elsewhere"

* **Trigger:** AUTO — the same mounting conversation options that bank
  `door_mounted` also carry `{"quest": "door_that_goes_elsewhere"}` and bank
  `door_chain_started` (`door_mounting:door_mounting#1`,
  `door_mounting:door_mounting_far#0`, `inn#pisces_mounting`). There is no
  separate start option and no lead row.
* **Learned at:** relay stages `inn#lyonette` `lyonette_thread_door`,
  `street#pisces` `pisces_thread_door` (both on `door_chain_started`), then
  `erin_thread_ruin_east` / `krshia_thread_ruin_east` (`door_understood`),
  `erin_thread_catalyst` / `krshia_thread_ruin_neutral`
  (`recovered_anchor_stone`), `erin_thread_pisces_ready` /
  `krshia_thread_pisces_ready` (`bought_catalyst` + `recovered_anchor_stone`),
  `erin_thread_door_resting` / `krshia_thread_door_resting`
  (`catalyst_delivered`), `erin_thread_door_neutral` / `krshia_thread_door_neutral`
  (`door_awakened`). This chain is the best-relayed thread in the game.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `consult` | `door_understood` | `inn#rift_vermin_leak` (`on_victory`), `pisces_magic:greet#5`, `pisces_magic:consult_talk_argue#0/#2` |
| `buy_catalyst` | `bought_catalyst` | `krshia_crate:charms#6` (18 gold) |
| `deliver_catalyst` | `catalyst_delivered` OR `door_awakened` | `pisces_magic:greet#8` (requires `bought_catalyst` + `recovered_anchor_stone`) |
| `attune` | `door_awakened` | CODE: `src/core/sleep_beat.gd:159-163` |

* **The attune rule, exactly as the code has it** (`sleep_beat.gd:159-163`):
  while `door_understood >= 1` **and** `recovered_anchor_stone >= 1` **and**
  `bought_catalyst >= 1` **and** `door_awakened < 1`, each sleep banks
  `door_study_sleeps`; at `>= 3` it banks `door_awakened`.
  `recovered_anchor_stone` comes from `horns_dig`'s pedestal, NOT from this
  quest — the cross-quest dependency the `deliver_catalyst` beat copy names.
* **`catalyst_delivered` is not on the critical path** — see §6.3.2.
* **Resolution ladder:** `read_the_door_runes` (`inn#pantry_door`
  `skill_uses[observe]`) < `cleared_the_leak` (`inn#rift_vermin_leak` victory) <
  `""` fallback ("You consulted Pisces about it").
* **Consumed by:** `door_awakened` → `acts.json:act_iv/the_door_opens`;
  `portals.json:riverfarm` (the region unlock); `pisces_magic:greet#12` (the
  `where_the_door_reaches` start); `leads.json:lead_spine`; the second-door and
  resonance sleep pairs (`sleep_beat.gd:165`, `:174`); a veil line
  (`src/ui/sleep_veil.gd:307-308`).

#### `where_the_door_reaches` — "Where the Door Reaches"

* **Trigger:** `pisces_magic:greet#12` "The Door woke. It reaches past Liscor
  now." (`street#pisces`), requires `door_awakened`, hides on `spine_started`.
* **Learned at:** `leads.json:lead_spine` (place "Guild steps, Market Street").

| Beat | Completes on | Produced by | Its own lead |
| --- | --- | --- | --- |
| `riverfarm_reach` | `lattice_witch_lore` | `riverfarm_witch:witch_ward_lore#0` | `leads.json:lead_witch_ear` (requires `price_of_a_favor_reported` + `spine_started`) |
| `invrisil_reach` | `lattice_hedault_reading` | `hedault_enchanting:door_reading#0` | `leads.json:lead_hedault_eye` (requires `brothers_job_done` + `spine_started`) |
| `pallass_reach` | `lattice_forge_rune` | `pallass_grimalkin:forge_runes#0` | `leads.json:lead_forge_ledger` (requires `elevator_pass_stamped` + `spine_started`) |
| `return` | `seal_descent_agreed` | `pisces_magic:descent_ask#1`, `pisces_magic:descent_expect#0` | — |

* These four beats are the spine's ONLY region-agnostic rows; each region's own
  prerequisite quest is named in the lead's `requires`, not in the beat.
* **`seal_descent_agreed` does double duty:** it closes this quest's last beat
  AND is the `{"quest": "what_the_seal_was_feeding"}` start on the same options.
* **Consumed by:** `lattice_forge_rune` → `acts.json:act_iv` advance_when +
  `act_iv/the_reach_mapped`; all three lattice counters → their leads' hide arms
  and the finale region recap (`src/ui/sleep_veil.gd:124-128`).
  `seal_descent_agreed` → `trapped_halls#seal_kept_door` variant gates,
  `trapped_halls#pisces_seal_escort` `present_when`, `acts.json:act_v/the_descent`.

#### `what_the_seal_was_feeding` — "What the Seal Was Feeding" (Act V, Liscor)

* **Trigger:** `pisces_magic:descent_ask#1` / `pisces_magic:descent_expect#0`,
  banking `seal_descent_agreed`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `descend` | `read_the_seal_runes` | `trapped_halls#seal_kept_door` interact variant `when {seal_descent_agreed, seal_kept_found}`, and `skill_uses[observe].variants` with the same gate |
| `read` | `read_the_feeding_ward` | same door's interact variant `when {read_the_seal_runes}`, `skill_uses[detect_magic].variants` (`{seal_descent_agreed, read_the_seal_runes}` and a `detected_wardwork >= 3` arm), and `pisces_seal:at_the_door#0` |
| `resolve` | `seal_resolved` | `seal_vault#vault_anchor_stone` (`on_open`), `olesm_intro:seal_bounty_pitch#0/#1`, `pisces_seal:fork_reward#0/#1` |

* Beats are order-gated by their producers' own `when` chains: no counter here
  can bank before its predecessor's.
* **Resolution ladder (last match wins, mirrors
  `sleep_veil.gd:137-141 FINALE_CLOSE_LINES`):** `seal_opened` < `seal_kept_fed`
  < `seal_rewarded`. `seal_opened` is a bounce hatch — a player can open the seal
  and STILL resolve by feeding or re-warding, so the resolution must overwrite.
* **Consumed by:** `seal_resolved` → `acts.json:act_v` advance_when; the finale
  (`_finale_owed`, `src/ui/sleep_veil.gd:456-458`); Pallass relay stages
  `pallass_forge#forge_smith` `smith_seal_resolved`, `pallass_forge#lift_attendant`
  `attendant_seal_resolved`.

### 2.3 Floodplains

#### `chieftains_price` — "The Chieftain's Price"

* **Trigger:** `rags_meeting:hub#0` "Who are you?" or `rags_meeting:hub#1`
  "(Say nothing. Wait.)" — both bank `met_rags` + `chatted_with_rags`; or
  `rags_meeting:hub#4` "(Draw steel.)", which banks `met_rags` +
  `rags_price_named` and jumps straight to the settle fork.
* **Reaching the giver at all:** `floodplains#rags_scouting_party`
  `encounter_when.requires: {reward_acknowledged: 1, chatted_with_erin: 3,
  goblins_spared: 1}` with `absent: {fought_chieftains_raid: 1}` — a composed
  conduct + relationship gate. Failing it shows `gate_closed_toast` instead.
  `goblins_spared` comes from `goblin_parley:hub#1/#2`; `reward_acknowledged` from
  `erin_errand:hub#3/#4`; `chatted_with_erin` from Erin's talk pool.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `meet` | `met_rags` | `rags_meeting:hub#0/#1/#4` |
| `price` | `rags_price_named` | `rags_meeting:hub#4`, `rags_meeting:ask#0` |
| `close` | `rags_meeting_settled` | `floodplains#rags_scouting_party` (`on_victory`), `rags_meeting:settle#0/#1` |

* **Resolution (fork-exclusive):** `helped_rags_tribe` / `brokered_goblin_trade` /
  `drove_off_rags`.
* **Consumed by:** `rags_meeting_settled` opens `floodplains#rags_camp_mouth`
  (`present_when.requires` + `door_when.requires`, with
  `present_when.absent: {drove_off_rags: 1}`), arms
  `rags_camp#camp_ground_press` (`encounter_when` + `ally_requires`), and gates
  `inn#rags_inn_guest` `present_when` and the Krshia trade rungs
  (`krshia_crate:hub#11/#12`).

#### `the_price_kept` — "The Price Kept"

* **Trigger:** `rags_meeting:hub#6` "Winter's coming. What does the camp need?",
  requires `rags_meeting_settled`, hides on `drove_off_rags`. **This option banks
  no accomplishment of its own** — the quest has no start counter.
* **Learned at:** `leads.json:lead_camp_winter` — see §6.3.3 for the dead-end it
  produces on the betrayal path.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `camp_trade_brokered` OR `camp_larder_filled` OR `camp_ground_held` | `krshia_crate:hub#11/#12`; `rags_camp#camp_meat_rack` (interact `variants`); `rags_camp#camp_ground_press` (`on_victory`) |
| `report` | `rags_price_kept` | `rags_meeting:winter#1/#2/#3` |

* **Resolution ladder:** `camp_trade_brokered` < `camp_larder_filled` <
  `camp_ground_held`.

### 2.4 Riverfarm (reached through `portals.json:riverfarm`, gated on `door_awakened`)

#### `price_of_a_favor` — "The Price of a Favor"

* **Trigger:** `riverfarm_headman:hub#0` "Tell me about the blight."
  (`riverfarm_village#riverfarm_headman`), no requires, hides on
  `heard_price_of_a_favor`. This is the region's ungated entry quest.
* **Learned at:** relay stages `riverfarm_headman_thread_hollow` and
  `riverfarm_hunter_thread_hollow` (both on `heard_price_of_a_favor`).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `blight_lifted` | `witch_hollow#hollow_true_knot` (`on_skill_use[observe]`), `witch_hollow#briar_collectors_deep` (`on_victory`), `riverfarm_witch:mediate_argue#0` |
| `report` | `price_of_a_favor_reported` | `riverfarm_headman:hub#1` |

* **Resolution ladder:** `drove_off_collectors` < `mediated_the_debt` < `""`
  fallback (paid at the standing stones).
* **Consumed by:** `price_of_a_favor_reported` → `acts.json:act_iv` advance_when +
  `act_iv/riverfarm_owed`; the two follow-on quest starts
  (`riverfarm_headman:hub#6`, `riverfarm_hunter:hub#2`); `riverfarm_witch:hub#6`
  (the lattice lore option); `leads.json:lead_witch_ear`, `lead_flood_ledger`,
  `lead_thicket`. `blight_lifted` gates `leads.json:lead_invrisil_stone`.

#### `flood_ledger` — "The Flood Ledger"

* **Trigger:** `riverfarm_headman:hub#6`, requires `price_of_a_favor_reported`,
  hides on `heard_flood_ledger`.
* **Learned at:** `leads.json:lead_flood_ledger` (place "The village square,
  Riverfarm").

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `ledger_read_true` OR `flood_prep_done` OR `granary_cleared` | `riverfarm_tallyman:tally_name#0`; `riverfarm_mill#mill_flood_stack` (`skill_uses[basic_cleaning]` and `skill_uses[basic_cooking]`); `riverfarm_mill#mill_granary_scavengers` (`on_victory`) |
| `report` | `flood_ledger_settled` | `riverfarm_headman:hub#7/#8/#9` |

* **The HELP route needs no shared resolve counter:** the skill arm banks exactly
  one counter, so the headman carries one report option per route. All three
  report rows also require `heard_flood_ledger` — because `mill_flood_stack` is
  ungated and `basic_cleaning` is the PC's starting field skill, a wander into
  the mill would otherwise settle a quest never offered (the graph's own
  `_comment` records this).
* `heard_flood_ledger` arms `riverfarm_mill#mill_granary_scavengers`
  (`encounter_when.requires`).

#### `what_the_thicket_keeps` — "What the Thicket Keeps"

* **Trigger:** `riverfarm_hunter:hub#2`, requires `price_of_a_favor_reported`,
  hides on `heard_thicket_keeps`. **Learned at:** `leads.json:lead_thicket`.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `herd_rerouted` OR `ward_scrap_read` OR `thicket_cleared` | `riverfarm_hunter:thicket_sign#0`; `witch_hut#hut_ward_scrap` (`on_skill_use[detect_magic]`); `witch_hollow#thicket_line_den` (`on_victory`) |
| `report` | `thicket_answered` | `riverfarm_hunter:hub#3/#4/#5` |

* The SKILL route banks `ward_scrap_read` ONLY and must never bank
  `detected_wardwork` — `trapped_halls`' `detect_magic` arm protects that
  counter's `>= 3` threshold.
* `thicket_answered` gates `riverfarm_village#riverfarm_thicket_patch` and
  `riverfarm_village#hunters_lamb_pen` `present_when`.

### 2.5 Invrisil (reached through `portals.json:invrisil`, gated on `invrisil_attuned`)

`invrisil_attuned` has exactly ONE producer: `riverfarm_witch:shop#4` — Eloise's
travel-stone, 18 gold, no accomplishment requirement, hides once bought. Two
lead rows exist solely to name it (§6.3.1).

#### `a_gentlemans_disagreement` — "A Gentleman's Disagreement"

* **Trigger:** `invrisil_wilovan:commission#0` or `invrisil_wilovan:why_you#0`
  (`brothers_parlor#wilovan`), both bank `took_brothers_job`. No requires.

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `scout` | `coyle_operation_found` | `invrisil_boulevard#coyle_operation_lookout` (`on_interact`) |
| `resolve` | `merchant_fate_decided` | `invrisil_merchant_prince:cornered#0/#1` |
| `report` | `brothers_job_done` | `invrisil_wilovan:hub#3` |

* The three info-gathering methods (stealth / talk / fight) feed the same
  `resolve` beat and are not separately surfaced in `resolution_paths`.
* **Resolution (fork-exclusive):** `merchant_exposed` / `merchant_extorted`.
* **Consumed by:** `brothers_job_done` → `acts.json:act_iv` advance_when +
  `act_iv/invrisil_squared`; `hedault_enchanting:hub#5` (the lattice reading);
  `leads.json:lead_hedault_eye`, `leads.json:lead_hat_stays_on`;
  `brothers_parlor#parlor_stash_chest` (`fence_menu_when.requires:
  {eyed_the_stash, brothers_job_done}` — the Fence opens only once the chest has
  been interacted with AND the job is done; the unmet case falls through to the
  plain prop, `src/core/interactions.gd:102-105`);
  `inn#wilovan_inn_guest` `present_when`.

#### `a_setting_for_a_lady` — "A Setting for a Lady"

* **Trigger:** `invrisil_stationer_client:commission#0` (`stationer#stationer_client`),
  hides on `heirloom_commission_started`. **Learned at:**
  `leads.json:lead_setting_for_a_lady` (requires `invrisil_attuned`).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `resolve` | `heirloom_truth_kept` OR `setting_assisted` OR `original_recovered` | `hedault_enchanting:heirloom_bench#0`; `#1`/`#2`; `mercantile_alleys#alley_fence_door` (`on_victory`) |
| `report` | `setting_commissioned` | `invrisil_stationer_client:handover#0/#1` |

* **Resolution ladder:** `setting_assisted` < `heirloom_truth_kept` <
  `original_recovered`. No `""` fallback — the handover option is gated on
  holding at least one route counter.
* `heirloom_commission_started` arms `mercantile_alleys#alley_fence_door`
  (`encounter_when.requires`).

#### `the_hat_stays_on` — "The Hat Stays On"

* **Trigger:** `invrisil_wilovan:hat_errand#0`, hides on `hat_job_taken`.
  **Learned at:** `leads.json:lead_hat_stays_on` (requires `brothers_job_done`).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `run` | `handoff_talked` OR `handoff_quiet` OR `handoff_loud` | `invrisil_rest_factor:exchange_three#0`; `adventurers_rest#rest_corner_table` (interact `variants`); `adventurers_rest#rest_bravos` (`on_victory`) |
| `report` | `hat_job_done` | `invrisil_wilovan:hat_report#0/#1/#2` |

* **Resolution ladder:** `handoff_loud` < `handoff_talked` < `handoff_quiet`.
* `hat_job_taken` gates the whole Rest set-piece: `adventurers_rest#rest_hat_hook`,
  `#rest_corner_table` (`present_when`), `#rest_bravos` (`encounter_when`).

### 2.6 Pallass (reached through `portals.json:pallass`, gated on `pallass_attuned`)

#### `papers_for_pallass` — "Papers for Pallass"

* **Trigger:** `selys_delivery:hub#10` "About papers for Pallass." (`guild#selys`),
  requires **`invrisil_attuned`**, hides on `pallass_sponsored`. Banks
  `pallass_sponsorship_asked` (which nothing reads — §6.2).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `sponsor` | `pallass_sponsored` | `selys_delivery:pallass_sponsor#0` |
| `attune` | `pallass_attuned` | `krshia_crate:charms#8` (18 gold, requires `pallass_sponsored`) |
| `arrive` | `pallass_entry_stamped` | `pallass_market_clerk:hub#0` |

* **Learned at:** relay stages `guild#selys` `selys_thread_pallass`
  (`pallass_sponsored`) and `selys_thread_pallass_neutral` (`pallass_attuned`).
  No lead row.
* `pallass_attuned` also gates `pallass_market#pallass_market_arrival_anchor`
  (`portal_menu_when` — the return carrier).

#### `forge_tier_permit` — "Clearance for the Forge Tier"

* **Trigger:** `pallass_forge_clerk:hub#0` (`pallass_market#forge_permit_clerk`),
  requires `pallass_entry_stamped`, hides on `forge_permit_filed`. Banks
  `forge_tier_permit_asked` (nothing reads it — §6.2).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `apply` | `forge_permit_filed` | `pallass_forge_clerk:permit_intro#0` |
| `examined` | `grimalkin_examination_passed` | `pallass_grimalkin:exam#0` |
| `stamped` | `elevator_pass_stamped` | `pallass_forge_clerk:collect_stamp#0` |

* **`elevator_pass_stamped` is the forge-tier key:** it opens
  `pallass_forge#grand_lift_forge` and `pallass_market#grand_lift_market`
  (`door_when.requires`), flips `pallass_market#market_ordinance_wall`
  (`variants.when`), gates `acts.json:act_iv/pallass_tiers`, and is the `requires`
  on `leads.json:lead_forge_ledger`, `lead_tempered_standards`,
  `lead_ledger_eats_first`. It also gates `inn#grimalkin_inn_guest` `present_when`.

#### `tempered_standards` — "Tempered Standards"

* **Trigger:** `pallass_forge_smith:commission#0` (`pallass_forge#forge_smith`),
  banks `standards_commission_taken`. **Learned at:**
  `leads.json:lead_tempered_standards` (requires `elevator_pass_stamped` +
  `chatted_with_forge_smith` — i.e. the lead only fires after you have actually
  spoken to her once).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `commission` | `golem_recalibrated` OR `temper_run` OR `standards_brokered` | `pallass_forge_hall#forge_temper_golem` (`on_victory`); `pallass_forge_hall#forge_hall_temper_bench` (`on_skill_use[appraise_goods]`); `pallass_forge_smith:commission_report#0` |
| `report` | `standards_tempered` | `pallass_forge_smith:commission_report#1/#2/#3` |

* **Resolution ladder:** `golem_recalibrated` < `temper_run` < `standards_brokered`.
* The FIGHT counter is `golem_recalibrated`, never `forge_golems_culled`, so this
  quest cannot feed `bounties.json:bounty_forge_golem_cull`.
* `standards_commission_taken` arms `pallass_forge_hall#forge_temper_golem`
  (`encounter_when.requires`).

#### `ledger_eats_first` — "The Ledger Eats First"

* **Trigger:** `pallass_lift_attendant:ledger_pitch#0` (`pallass_forge#lift_attendant`),
  banks `ledger_loop_started`. **Learned at:** `leads.json:lead_ledger_eats_first`
  (requires `elevator_pass_stamped` + `chatted_with_lift_attendant`).

| Beat | Completes on | Produced by |
| --- | --- | --- |
| `unstick` | `loop_walked` OR `exemption_found` OR `shipment_carried` | `pallass_den_keeper:consignee#0`; `pallass_den_shop#den_shop_consignment_file` (`on_skill_use[appraise_goods]`); `pallass_den_keeper:consignee#1` |
| `report` | `ledger_unstuck` | `pallass_lift_attendant:ledger_report#0/#1/#2` |

* **Resolution ladder:** `shipment_carried` < `loop_walked` < `exemption_found`.

---

## 3. Region unlocks — the Door lattice

`data/portals.json` is the whole region-unlock table. Each row's
`requires_accomplishment` is the ONLY gate.

| Portal row | Destination map | Gate counter | Gate's sole/primary producer |
| --- | --- | --- | --- |
| `liscor_street` | `street` | `door_mounted` | `door_mounting:door_mounting#1` / `door_mounting_far#0` |
| `the_wandering_inn` | `inn` | `door_mounted` | same |
| `riverfarm` | `riverfarm_village` | `door_awakened` | CODE, `src/core/sleep_beat.gd:159-163` |
| `invrisil` | `invrisil_boulevard` | `invrisil_attuned` | `riverfarm_witch:shop#4` (ONE producer) |
| `pallass` | `pallass_market` | `pallass_attuned` | `krshia_crate:charms#8` (ONE producer, itself gated on `pallass_sponsored`) |
| `dungeon_depths` | `dungeon_approach` | `dungeon_attuned` | CODE, `src/core/sleep_beat.gd:165-171` |

The carrier props (the things a player interacts with to open the picker) are
gated separately and can differ from the portal row's own gate. There are
exactly SIX in the whole of `data/maps/**` — every entity carrying
`portal_menu: true` + `portal_menu_when.requires`:

| Carrier prop | Carrier gate | Its own map's portal row, and that row's gate |
| --- | --- | --- |
| `inn#pantry_door` | `door_mounted` | `the_wandering_inn` → `door_mounted` (same) |
| `street#street_anchor_stone` | `door_mounted` | `liscor_street` → `door_mounted` (same) |
| `invrisil_boulevard#invrisil_anchor_stone` | `door_mounted` | `invrisil` → `invrisil_attuned` (**differs**) |
| `riverfarm_village#riverfarm_anchor_stone` | `door_mounted` | `riverfarm` → `door_awakened` (**differs**) |
| `pallass_market#pallass_market_arrival_anchor` | `pallass_attuned` | `pallass` → `pallass_attuned` (same) |
| `dungeon_approach#dungeon_wardstone` | `dungeon_attuned` | `dungeon_depths` → `dungeon_attuned` (same) |

**Carrier = the DEPARTURE leg; portal row = the ARRIVAL leg.** Every carrier's
picker offers the SAME set — every row whose counter is banked and whose map
exists, minus the map you are standing on
(`WIPortals.attuned_destinations` + `build_portal_graph`, `src/core/portals.gd:10-33`,
reached via `src/core/wi_game.gd:1470-1481`). So a region needs a carrier only to
let a player LEAVE; arriving costs the row's gate and nothing else. That is why
the two gates are allowed to differ — and why tightening a carrier to match its
row strands everyone already standing there:

* `riverfarm_village#riverfarm_anchor_stone` is the village's ONLY exit
  (`witch_hollow` is a dead end hanging off it), so its gate must be satisfied by
  every cohort that can arrive — the pre-fix `riverfarm_attuned` path and the
  shipped `door_awakened` row alike. `door_mounted` is the one counter both hold.
  The entity's own `_comment` states the ruling and ends "Never tighten past the
  row's own gate."
* `invrisil_boulevard#invrisil_anchor_stone` is the same shape one region over:
  arrival costs `invrisil_attuned` (Eloise's 18-gold stone), departure costs only
  `door_mounted`, so the region can never become a one-way trap.

`pallass_market#pallass_market_arrival_anchor` reaches the same safety from the
other side: its gate is deliberately IDENTICAL to the `pallass` row, which (per
its own `_comment`) is always met by anyone standing on it, because
`pallass_market`/`pallass_forge` have no map exit but each other.

**Region chain, end to end:**

```
horns_dig/haul  → door_mounted   → inn ↔ Liscor hop
                → (3 qualifying sleeps, needs door_understood
                    + recovered_anchor_stone + bought_catalyst)
                → door_awakened  → Riverfarm
Riverfarm: price_of_a_favor (ungated entry quest)
                → blight_lifted  → lead_invrisil_stone names Eloise's stone
                → invrisil_attuned (riverfarm_witch:shop#4, 18g) → Invrisil
Invrisil: a_gentlemans_disagreement → brothers_job_done
Liscor:   selys_delivery:hub#10 requires invrisil_attuned
                → pallass_sponsored → pallass_attuned (krshia, 18g) → Pallass
Pallass:  papers_for_pallass → forge_tier_permit → elevator_pass_stamped
                → forge tier lifts open
Dungeon:  door_awakened + heard_pisces_second_door, 2 sleeps
                → dungeon_attuned → dungeon_depths
```

---

## 4. Where a player is told — the four in-fiction relay surfaces

| Surface | File / mechanism | What it can say |
| --- | --- | --- |
| **Journal quest line** | `data/quests.json` beat `description`, surfaced by `WIQuests.evaluate` (`src/core/quests.gd:47-64`) — the ACTIVE beat only | WHO and WHERE, in person+place prose |
| **Leads strip** | `data/leads.json`, 15 rows — pure counter reads, each mirroring its target dialogue option's `requires`/`hide_when` | An un-started hook whose prerequisites are met, plus a `place` |
| **Board rumors** | `guild#guild_board` `board_rumors[]`, each with `banks_accomplishment` | Points at a PERSON by name; the real quest option lives on that person's own graph |
| **Relay talk stages** | `talk_pool_stages[]` on world NPCs, keyed `requires_accomplishment` | WHO/WHERE, never WHAT-TO-DO (the anti-trivialisation rule) |
| **Sleep toasts + veil lines** | `src/core/sleep_beat.gd`, `src/ui/sleep_veil.gd:306-314` | The one guaranteed read for code-banked beats |

All five board rumors live on `guild#guild_board`:

| Rumor id | Banks | Role |
| --- | --- | --- |
| `rumor_missing_recruit` | `heard_about_missing_recruit` | **Sole producer** of `the_missing_recruit`'s entry gate |
| `rumor_lost_hammer` | `heard_about_lost_hammer` | **Sole producer** of `renns_warhammer`'s entry gate |
| `rumor_invrisil` | `heard_of_invrisil` | Signpost; read only by `leads.json:lead_invrisil_letter` |
| `rumor_dungeon_survey` | `heard_of_the_gallery_survey` | Signpost only — the `what_the_seal_kept` start gates on `post_game`, not on this counter, which nothing reads (§6.2) |
| `rumor_riverfarm` | `riverfarm_attuned` | Lore only; `portals.json:riverfarm` gates on `door_awakened` instead (§6.2) |

---

## 5. Causality that lives in code, not data

### 5.1 The sleep beat (`src/core/sleep_beat.gd`)

| Trigger condition | Banks | Line |
| --- | --- | --- |
| `raskghar_sealed >= 1` and `post_game < 1` | `post_game` (no toast by design — the beat is voiced once by `SEAL_TRANSITION_LINE`) | `:155-157` |
| `door_understood` + `recovered_anchor_stone` + `bought_catalyst`, `door_awakened < 1` | `door_study_sleeps`; at `>= 3` → `door_awakened` | `:159-163` |
| `door_awakened` + `heard_pisces_second_door`, `dungeon_attuned < 1` | `second_door_study_sleeps`; at `>= 2` → `dungeon_attuned` + a lore toast | `:165-171` |
| `door_awakened`, `resonance_grown < 1` | `catalyst_attunement_sleeps`; at `>= 2` → `resonance_grown` + `_grow_resonance()` | `:173-178` |
| `watch_runner_pointed < 1`, `heard_the_deep_tremor < 1`, `reached_two_classes >= 1`, `quests_completed >= 3` | `watch_runner_pointed` + starts `something_beneath` | `:187-205` |
| `reached_two_classes >= 1`, `quests_completed >= 3`, and `>= 2` of `cleaned_the_inn` / `goblins_spared` / `sign_defended` / `resolved_wrong_order` | `garden_door_unlocked` (opens `inn#garden_door` sight AND passage together) | `:206-223` |

### 5.2 Combat banking (`src/core/combat_banking.gd`)

* `victories` on every win (`:111`) — read only by the chronicle facts
  (`src/core/wi_game.gd:1618`), rendered in the journal and title screen.
* `fought_<encounter_id>` on every weighted victory (`:126`), READ at `:122` as
  `prior_wins` for GH#211 diminishing-return weighting. 40 such counters exist,
  one per encounter entity. See §6.3.4 — they are absent from the freeze list.
* `<weapon>_skill_used` and `<element>_cast` are data-driven from `skills.json`
  tags, not hardcoded.

### 5.3 The complete list of gate shapes that READ a counter

**Map file, top level (NOT inside `entities`):** `arrival_toasts[].requires` and
`arrival_toasts[].hide_when` — a map-level array, read by
`WIGame._emit_arrival_toast` (`src/core/wi_game.gd:213-222`, gate at `:225-233`),
first satisfied entry wins. Two shipped uses:
`data/maps/dungeon/dungeon_approach.json` (requires `heard_the_deep_tremor`, hides
on `cleared_the_warren`) and `data/maps/ruin/ruin_surface.json` (requires
`horns_dig_started`, hides on `door_retrieved`). **This shape is easy to miss
because a whole-file `entities[]` walk never reaches it.**

**Map entities:** `present_when.{requires,absent}`, `encounter_when.{requires,absent}`,
`door_when.requires`, `contains_when.requires`, `portal_menu_when.requires`,
`fence_menu_when.requires`, `ally_requires`, `ally_hp_penalty.*.when`,
`visual_states[].when.counter`, `variants[].when`, `skill_uses[*].variants[].when`,
`on_skill_use.variants[].when`, `talk_pool_stages[].requires_accomplishment`
(a DICT of counter→count, not a string — mis-reading it as a string drops all 109
shipped `talk_pool_stages` gates, and with them the six Horns inn-variant
counters that no other gate names),
`sleep_toast[].when` (the array form only; `WIInteractions._resolve_sleep_toast`,
`src/core/interactions.gd:205-209` — shipped at
`data/maps/inn/inn_upstairs.json#your_bed`, reading `room_tier_1/2/3`), and
`open_toast_variants[].when` (`src/core/interactions.gd:248-258` — shipped at
`data/maps/ruin/ruin_surface.json#anchor_stone_pedestal`, reading
`door_retrieved`).

**Dialogue:** `option.requires.accomplishment`, `option.hide_when.accomplishment`,
`text_variants[].requires/hide_when.accomplishment`.

**Catalogs:** `quests.json` `complete_when` / `complete_when_any` /
`resolution_paths[].accomplishment`; `acts.json` `advance_when.accomplishments` /
`beats[].when.accomplishments`; `leads.json` `requires` / `hide_when`;
`portals.json` `requires_accomplishment`; `classes.json` `gained_by.accomplishment`,
`levels[].requires`, `levels[].requires_any`, `evolution.targets` keys (the KEYS
are counters, the values are class ids);
`bounties.json` `condition` + `tiers.*.condition` + `requires`;
`deliveries.json` `condition`. Note `bounties.json`/`deliveries.json`
`condition` is a bare counter→count dict, NOT an `{accomplishment: ...}` wrapper;
reading it as the latter drops ~30 consumers (the `*_culled` and
`delivered_delivery_*` families) and manufactures phantom orphans.

The four toast-side shapes above (`arrival_toasts` ×2, `sleep_toast[].when`,
`open_toast_variants[].when`) all read counters that other gates ALSO read today,
so no live counter is mis-classified by their omission — but a future counter
whose only consumer is a toast variant would land in §6.2's orphan list and get
retired as dead, silently deleting a shipped line. They are listed here because
§0.3 sends a maintainer to grep exactly these keys.

Three `visual_states.when` keys are NOT counters and must not be mistaken for
them (`src/world/world.gd:791-799`): `container_opened` (reads
`Game.sim.container_state`), `dormant` (reads `dormant_encounters`), and `phase`
(time of day).

---

## 6. Orphans and dead ends

Cross-checked in BOTH directions against the full producer census
(§0.3) and the gate-shape list (§5.3).

### 6.1 Consumed but never produced — **zero**

Every counter named by any authored gate has at least one live producer. The
three apparent misses (`container_opened`, `phase`, `dormant`) are render-only
`visual_states` keys, not accomplishments (§5.3).

`fought_chieftains_raid` deserves a note because it *reads* like an orphan: it is
the `encounter_when.absent` arm on `floodplains#rags_scouting_party`, and its only
producer is the dynamic `fought_<encounter_id>` bank for the separate
`floodplains#chieftains_raid` encounter (`combat_banking.gd:126`). It is real, and
the can-fail proof lives in `qa/fixtures/rags_gate_unmet_start.json`.

### 6.2 Produced but never consumed by any DATA gate — 274 counters

"Consumed" in this section's headline number means **consumed by one of §5.3's
authored gate shapes**. Code reads are not visible to that census, so several
families below are read by `src/**` and are NOT orphans; each row says so
explicitly. Breakdown (every counter lands in exactly ONE row):

| Family | Count | Verdict |
| --- | --- | --- |
| `fought_*` | 39 | **Consumed in code** (`combat_banking.gd:122`). Not orphans. |
| `accepted_bounty_*` / `completed_bounty_*` | 33 / 31 | Board bookkeeping. `accepted_bounty_bounty_sewer_survey` and `completed_bounty_grimalkin_study_*` ARE read by dialogue; the rest are inert by design. |
| `accepted_delivery_*` / `completed_delivery_*` | 13 / 13 | Delivery bookkeeping; the `delivered_*` twins are what relay stages actually read. |
| `chatted_with_*` | 38 without a data gate, of 55 produced | Per-NPC talk tally, banked by `WISocial.talk_pool_line` (`src/core/social.gd:26`). Exactly 17 are named by an authored gate: `chatted_with_` + `erin`, `selys`, `krshia`, `olesm`, `pisces`, `relc`, `zevara`, `klbkch`, `duty_sergeant`, `forge_smith`, `lift_attendant`, plus the six Horns inn-row counters `ceria_inn`, `ceria_inn_returned`, `yvlon_inn`, `yvlon_inn_returned`, `ksmvr_inn`, `ksmvr_inn_returned` (each row's own `talk_pool_stages`). Of the remaining 38, **three are read in code, not data**: `chatted_with_rags`, `chatted_with_wilovan`, `chatted_with_grimalkin` are the inn-guest roster's "met" test, built inline at `src/core/wi_game.gd:900` (`accomplishment_count("chatted_with_" + npc) >= 1`) over `inn#selys_inn_guest`'s ten-name roster and consumed by `WIInnGuests.met_pool` (`src/core/inn_guests.gd:109-121`) via `guest_active` (`:137-138`). The other 35 are flavor. |
| Observation / flavor props (`observed_*`, `eyed_*`, `read_*`, `found_*`, `heard_*`, `saw_*`, `browsed_*`, `leaned_*`, `noticed_*`, `visited_*`, `searched_*`, `scouted_vantage`, `rune_far_cold`) | 79 | **Inert by design** — a per-prop breadcrumb. Note these props do NOT feed progression on a plain interact: `src/core/interactions.gd:106-142` banks only the named counter. `observed_things` banks separately, on the FIRST `[Observe]` per entity (`src/core/field_skills.gd:73-81`). |
| Ungrouped, code-read | 5 | `catalyst_attunement_sleeps`, `resonance_grown`, `finale_played`, `victories` — all read in `sleep_beat.gd` / `sleep_veil.gd` / `wi_game.gd:1618` — plus `sign_defended`, read at `src/core/sleep_beat.gd:209`. Not orphans. |
| Ungrouped, **no consumer anywhere** | 23 | Listed below. |

39 + 33 + 31 + 13 + 13 + 38 + 79 + 5 + 23 = **274**. Each counter appears in
exactly ONE family row; the residual bucket is what is left after the other
eight claim theirs.

The 23 with no consumer in data OR code. **Every id here is residual — none of
them also belongs to a family row above, so the table's id count and the 23 in
the family table are the same 23.** Three counters a reader will hunt for here
are deliberately NOT in it, because they are already counted in a family row and
listing them twice would break the arithmetic; they are described immediately
after the table instead.

| Counter | Produced by | Note |
| --- | --- | --- |
| `blinked_past_danger` | `src/core/wi_game.gd:669` | Field-skill tally; that line is the PRODUCER — no class level, bounty, or gate reads it. |
| `burned_the_debris` | `src/core/field_skills.gd:97` | Same shape (producer site, no reader). |
| `warded_danger` | `src/core/wi_game.gd:712` and `quests.json:what_the_seal_was_feeding` resolution grant | Produced twice, read never. |
| `went_fishing` | `floodplains#pond_edge` | Named in GH#339 item 3 as fully inert — wire or retire. |
| `riverfarm_attuned` | `guild#guild_board` rumor `rumor_riverfarm` | Deliberate: `portals.json:riverfarm` gates on `door_awakened` instead, and the row's `_comment` says this counter "keeps banking off the rumor as lore". |
| `pallass_sponsorship_asked` | `selys_delivery:hub#10` | Quest-start flag; the real gate is `pallass_sponsored`. |
| `forge_tier_permit_asked` | `pallass_forge_clerk:hub#0` | Quest-start flag; the real gate is `forge_permit_filed`. |
| `selys_impressed` | `selys_delivery:hub#1` | The Lyonette-tip reward; no downstream read. |
| `commended_by_olesm` | `olesm_intro:cisterns#1/#2/#3` | |
| `goblin_left_in_peace` | `goblin_parley:hub#2` | `goblins_spared` (same node, options #1/#2) is the counter everything gates on. |
| `street_cleared` | `floodplains#goblin_encounter_2`, `goblin_parley:hub#1` | |
| `trap_disarmed` | `mercantile_alleys#alley_footpad_snag_a/_b`, `witch_hollow#hollow_briar_snare` | Three producers, no consumer. |
| `cooked_the_offering` | `witch_hollow#hollow_offering_pot` | |
| `corusdeer_calmed` | `corusdeer_range:confront#1/#2` | |
| `forge_golem_stilled` | `forge_calibration_golem:confront#1` | |
| `watchgolems_stood_down` | `market_watchgolems:confront#1` | |
| `boulevard_challenge_declined`, `boulevard_formal_bout` | `boulevard_duel_ring:confront#1/#2` | |
| `handoff_mistimed` | `adventurers_rest#rest_corner_table` | The mistimed-approach branch of the hat handover. |
| `invrisil_errands_run` | `brothers_parlor#parlor_errand_slate` | |
| `cleared_raskghar_scouts`, `cleared_ruin_guardian` | `deep_tunnels#raskghar_scouts`, `ruin_surface#ruin_guardian` | Optional-encounter victory ids with no bounty or gate behind them. |
| `nature_cast` | element tally from `skills.json:thorn_hand` | No class level requires it, unlike `ice_cast`/`fire_cast`. |

Nothing in this table is asserted to be a BUG. The pattern worth watching is the
last group: a fight or a dialogue fork that banks a distinct id nobody reads is
a route the world cannot acknowledge afterwards.

**Counted in a family row above, NOT in the 23** (recorded here so a cleanup
pass working the table top-to-bottom does not double-retire them):

| Counter | Produced by | Which row counts it | Status |
| --- | --- | --- | --- |
| `chatted_with_rags` | `rags_meeting:hub#0/#1` | `chatted_with_*` (38) | **NOT inert.** It is the roster met-test for Rags at `src/core/wi_game.gd:900`; the graph's own `_comment` says so ("the met counter her inn-guest row needs"). Hand-written because Rags has no npc entity anywhere — her graph hangs off the `rags_scouting_party` ENCOUNTER, so the usual `talk_pool` producer cannot exist. Deliberately absent from "(Draw steel.)" so a betrayal win cannot seat the Chieftain you drove off. |
| `read_the_board` | `src/core/wi_game.gd:1308` | flavor / `read_*` (79) | Inert. Banked idempotently on every board browse. |
| `read_the_delivery_board` | `src/core/wi_game.gd:1419` | flavor / `read_*` (79) | Inert. Same shape. |

And one counter the old table listed under a "no consumer anywhere" heading
while its own note said the opposite:

| Counter | Produced by | Which row counts it | Status |
| --- | --- | --- | --- |
| `sign_defended` | `floodplains#goblin_encounter_1` `on_victory` | Ungrouped, code-read (5) | **NOT an orphan and must never be retired.** Read at `src/core/sleep_beat.gd:209` as one of the four Garden of Sanctuary unlock legs (`_garden_earn_met` needs `>= 2` of `cleaned_the_inn` / `goblins_spared` / `sign_defended` / `resolved_wrong_order`). Retiring it costs a player who spared the goblins their second leg, and the Garden never opens. It has no DATA consumer, which is exactly why it looks retirable from a §5.3 grep alone. |

### 6.3 Named dead ends and soft defects

**6.3.1 `invrisil_attuned` — one producer, now named twice.** The counter that
gates the entire Invrisil region has exactly one producer,
`riverfarm_witch:shop#4` (Eloise's 18-gold travel-stone), and the option itself
requires only gold. Two lead rows exist purely to point at it —
`leads.json:lead_invrisil_stone` (requires `blight_lifted`) and
`lead_invrisil_letter` (requires `heard_of_invrisil`), both hiding on
`invrisil_attuned`, both placed at "The witch's hollow, Riverfarm". This is the
CURE, not the disease; the disease is what happens when it is removed. Any future
region gate needs the same treatment.

**6.3.2 `catalyst_delivered` is cosmetic on the critical path.** The
`deliver_catalyst` beat closes on `catalyst_delivered` OR `door_awakened`, but the
sleep that banks `door_awakened` (`sleep_beat.gd:159`) reads `door_understood` +
`recovered_anchor_stone` + `bought_catalyst` and never reads `catalyst_delivered`.
A player who buys the catalyst and never returns to Pisces still wakes the Door,
and both beats close at once. This matches the quest's own `_comment` ("catalyst
still ungated on consult by design", GH#334 ruling 15) — recorded here so nobody
"fixes" the OR arm without moving the sleep gate with it.

**6.3.3 `lead_camp_winter` is a live dead end on the betrayal path.**
`leads.json:lead_camp_winter` requires `rags_meeting_settled >= 1` and hides only
on `rags_price_kept`. The betrayal close — `rags_meeting:hub#4` "(Draw steel.)"
into the `floodplains#rags_scouting_party` fight — banks
`on_victory: ["won_combat", "drove_off_rags", "rags_meeting_settled"]`, so the
lead FIRES. But on that same path:

* `rags_meeting:hub#6`, the `the_price_kept` start option, has
  `hide_when: {drove_off_rags: 1}` — the option is gone;
* `floodplains#rags_camp_mouth` has `present_when.absent: {drove_off_rags: 1}` —
  the camp entrance is gone;
* the encounter entity itself is consumed by the victory (it carries no
  `respawns`), so the figure on the rise is gone.

The result is a permanently visible lead ("Rags stood on the rise the whole time
you were leaving, and did not sit down." / "The southern floodplains") pointing at
a person, a place, and a quest that no longer exist, with no counter that can ever
hide it. The one-line fix is adding `drove_off_rags` to the lead's `hide_when`;
it is NOT applied here (this lane owns docs only) and belongs to whoever owns
`data/leads.json`. Note `hide_when` is AND across keys, so the fix is a second
lead row or an `absent`-style arm, not simply another key — the same trap
`quests.json:the_price_kept`'s own `_comment` already flags for the offer row.

**6.3.4 `fought_*` counters are missing from the shipped-ids freeze list.**
`combat_banking.gd:126` banks `fought_<encounter_id>` for all 40 encounter
entities, and `:122` reads them back for repeat-fight weighting — so they land in
real shipped saves. `data/shipped_ids.json` contains zero `fought_*` entries
because `scripts/generate_shipped_ids.py`'s census does not include the family
(`tests/test_content.gd:463-465` DOES synthesise them, so the two censuses
disagree). Renaming an encounter entity id today silently re-semanticises a
shipped counter with no validator to catch it. Owner: whoever owns
`scripts/generate_shipped_ids.py` + `tests/test_shipped_ids.gd`.

**6.3.5 Two quest-start flags nothing reads.** `pallass_sponsorship_asked`
(`selys_delivery:hub#10`) and `forge_tier_permit_asked`
(`pallass_forge_clerk:hub#0`) are banked at the moment their quest starts, but
both options hide on the FIRST BEAT's counter (`pallass_sponsored` /
`forge_permit_filed`) rather than on the start flag. Harmless today; it means
these two quests have no counter that says "started", so no lead row can be
written for them in the shape every other lead uses.

---

## 7. Unverified — claims this pass could NOT cite

* **Bounty/delivery availability gating.** `bounties.json` rows carry
  `condition` (the turn-in test) and sometimes `requires`, but which board a
  posting appears on, and when, is resolved in `src/core/bounties.gd` +
  `bounty_scaling.gd` against rank/tier state this pass did not trace. The
  bounty→quest edges are therefore absent from §2 rather than guessed at.
* **`quests_completed`** is used by two act gates and two sleep-beat gates. It is
  a derived count of quests whose every beat is met, not a counter; the exact
  call chain feeding `ctx["quests_completed"]` was not traced here.
* **Inn-guest rosters — the met-counter arm is now traced, the rotation is not.**
  `present_when.guest` resolves at `src/core/wi_game.gd:898-909`: the per-NPC
  "met" test is `accomplishment_count("chatted_with_" + npc) >= 1`, so every
  name in `inn#selys_inn_guest`'s ten-entry roster (selys, krshia, olesm, pisces,
  relc, zevara, klbkch, rags, wilovan, grimalkin) consumes its own
  `chatted_with_*` counter in CODE — that is the §6.2 carve-out for
  `chatted_with_rags` / `_wilovan` / `_grimalkin`. FIVE roster members carry an
  extra `WIInnGuests.GUEST_POOL_GATES` arm — rags, wilovan, grimalkin, zevara,
  pisces (`src/core/inn_guests.gd:47-52`; the inline comment at
  `src/core/wi_game.gd:901` still says "three" and is stale). What is still
  untraced: which guest is seated on which waking (the `times_slept`-driven
  shift window, `WIInnGuests.active_guests` / `guest_active`,
  `src/core/inn_guests.gd:123-138`), so per-guest presence edges remain absent
  from §2.
* **Class/skill progression edges.** Every observation counter that feeds
  `classes.json` `levels[].requires` / `requires_any` was counted for §6 but is
  not mapped per class — that belongs in `class-expansion-spec.md`, not here.
* **Ordering within a single waking.** This map states what gates what, never
  how many wakings apart two things can be, except where a sleep count is
  literally in the code (§5.1).
