# #453 Rest signposting before chokepoints (environmental design)

Design only; no code, data or QA changed here. Base: main `842ef6e9`.
Implementation waits for the #514 gear work to land and rebases onto it.

## Rulings

- **2026-10-07 (CHOICE-LOG "Hurt entry").** Keep chokepoint balance as is,
  with no stat tuning. Make sure a rest or recovery point is reachable before
  each chokepoint, and make that legible.
- **2026-10-08 (this revision).** Hints are environmental and implicit, not
  triggered toasts. Use things like potions to loot, a rest opportunity and an
  autosave checkpoint. They should create the understanding that the player is
  walking into something where they will want full health, without telling
  them.
  - The earlier toast design and its HP/MP threshold are dropped.

**Evidence the rulings answer:** `571-attrition-measurements.md`. The vault
construct party cells read 0.85–0.90 rested, 0.20–0.24 at 75% entry and
0.03–0.12 at 50%. The seal warden and Awakened rows fall the same way.

## 1. Summary

**Six data-only placements and no engine change.**

| # | Placement | What it does |
|---|---|---|
| 1 | A Watch bunk in Liscor's barracks | A Liscor-side bed. It cuts the walk to rest from the cisterns, the warren and the vault by 54–56 steps, and the walk home no longer crosses the Act I gate ambush |
| 2 | A grate-crew pail in the sewers | One Hot Meal |
| 3 | A Gnoll hunter's satchel past the Raskghar scouts | One Mending Draught, right where the scouts leave the player hurt, before the Awakened |
| 4 | The Horns' delve camp at the dungeon approach | A bedroll 19–21 steps from the vault and the warden, instead of 53–123 |
| 5 | A bedroll at the Horns' dig camp | Rest 15 steps from the ruin guardian, instead of 69 |
| 6 | Crude arrows by the road before the gate ambush | A tell only |

Riverfarm, Invrisil and Pallass already have a near rest or a posted-price
potion seller, so they get no new placement.

**Existing autosave triggers already make checkpoints at the approach:**
- map changes;
- world-context item use;
- sleep;
- the pre-fight snapshot.

Every write shows the "Saved" pill. Placed items and beds therefore produce a
checkpoint where they are used, with no new save mechanism.

## 2. What the sim supports today

### Rest

- **Sleep props** (`sleep: true`, any `kind: prop`) are the only rest:
  - the Inn bed;
  - the Inn player room;
  - the Garden of Sanctuary bed;
  - Riverfarm's guest cot;
  - the Brothers' guest couch.

  Sleep has no location rule (`WIGame.sleep()` refuses only in combat or
  mid-settlement). `sleep_toast` accepts a string or a `when`-variant array.
- **Sleep refills HP and MP** and has world consequences:
  - it advances `times_slept`, which drives the board and delivery rotations
    and the guest rotation;
  - it clears `entity_first_use`, so per-waking chores, cover crossings and
    the once-per-waking props reset;
  - it re-arms dormant respawning encounters;
  - it fails a held delivery;
  - it fades an animated (not tamed) companion;
  - it clears `well_fed`, frozen cells and sneaking;
  - it decrements wards;
  - it resolves class gains, level-ups and evolutions;
  - it runs the door-study hooks.

  A new bed changes none of these. It only changes where they can happen.
- **No partial rest prop exists.** Benches and hearths do not restore.
  Partial recovery comes from Erin's meal service (3g, once a waking, up to
  6 HP and 4 MP) and from consumables.

### Lootable recovery

- **One-shot containers** have `contains: [item ids]` and save their opened
  state in `container_state`.
  - Optional keys: `contains_when`, `present_when`, `open_toast`,
    `on_open_accomplishment`.
  - Examples: `inn_chest`, `note_sewer_surveyor`, the gallery strongboxes.
  - A full stack refuses the open without consuming it (`can_change_items`).
- **Recovery items in the catalog:**

  | Item | Effect |
  |---|---|
  | `hot_meal` | +6 HP |
  | `fine_meal` | +8 HP, +4 MP, +2 max HP next fight |
  | `mending_draught`, `remedy_draught` | +8 HP (10g) |
  | `mana_potion` | +6 MP (10g; doses carry exposure) |
  | `signature_meal` | +10 HP, +6 MP |

### Autosave

`Game._on_domain_event` writes the `auto` slot on these events:
- `MAP_CHANGED`;
- `SLEEP_SETTLED`;
- `ITEM_USE_SETTLED` in world context;
- `COMBAT_SETTLED`, `LOOT_CLAIMED`, `QUEST_BEAT_COMPLETED`;
- class events and `PHASE_CHANGED`.

It writes `auto_pre_combat` on `COMBAT_PREPARING` or `PRE_COMBAT_CHOICE`.

Every write emits `GAME_SAVED`, and the hint ribbon shows "Saved" for 4 s
(#509, `ui_save_status_rendered`). Only the session's first autosave adds a
housekeeping toast.

### Environmental tells

Encounters and props carry `observe` lines that a player reads by looking.
Lore notes are container items. Existing tells near chokepoints:
- the sewers' marker with a hastily scratched spider, and the banded silk
  before the nest;
- the warren's cold hearth and the sorted Gnoll bones;
- the vault arch's "There is no dust on it";
- the warden's seams;
- the ruin guardian's stillness, and the bone piles in the halls and the ruin.

## 3. Chokepoint inventory and placements

### How the walk costs were measured

Costs come from a scratch BFS over the shipped map JSON and `portals.json`:
- blocking follows the loader: `blocked`, wall segments, water and unsteady
  cells, and every entity cell;
- `present_when` entities are counted as present, which is conservative;
- movement uses 8 directions with the `move_player` corner rule;
- doors, `door_when` props and Door carriers are used from a 4-adjacent cell
  and cost 1;
- the Door menu offers every attuned row.

"Steps" counts moves and transitions together. Each row uses the gates that
are open at that point in the story:
- the Door is not mounted until the Act IV dig, which comes after the vault;
- `dungeon_attuned` banks at a sleep after Pisces's lead.

The figures are planning estimates. The census in §6 fixes the final cells.

### Inventory table

**Act gate prerequisites.** These are the fights that stand between the
player and each act's gate:

| Act gate | Chokepoint fights on the way |
|---|---|
| I→II | goblin_encounter_1 |
| II→III | none mandatory |
| III→IV | raskghar_scouts, then awakened_boss |
| IV→V | vault_boss_slot (mandatory); Riverfarm and Invrisil have non-fight routes; Pallass has no fight |
| Act V end | seal_warden_alcove |

**Encounters and placements.** "Interact" means interact-only; "rN" means a
trigger radius of N. "Rest now" is the walk to the nearest bed today.

| Chokepoint | Map, cell, trigger | Mandatory? | Rest now | Placement | Rest after |
|---|---|---|---|---|---|
| `goblin_encounter_1` (Act I) | floodplains (30,23), r2 | Yes; cover and stealth crossings exist | Inn: 47 steps | P6 tell (crude arrows) | Same |
| `shield_spiders` (Act II climax) | sewers (15,10), interact | No (scout path) | Inn: 90, via the gate band | P2 pail (+6 HP); P1 bunk | Bunk: 36 |
| `raskghar_scouts` (Act III) | deep_tunnels (8,4), interact | Yes | Inn: 88, via the gate band | P1 bunk | Bunk: 34 |
| `awakened_boss` (Act III climax) | deep_tunnels (12,7), interact | Yes | Inn: 94, via the gate band | P3 satchel (+8 HP), reachable only past the scouts; P1 bunk | Bunk: 40 |
| `snare_nest_slot` (halls) | trapped_halls (17,8), interact | No | Inn: 122 | P4 delve camp | Camp: about 19 |
| `vault_boss_slot` (Act IV spine) | trapped_halls (18,6), interact | Yes | Inn: 123, 7 transitions | P4 delve camp | Camp: 19 (bunk: 69) |
| `ruin_guardian` (dig fight leg) | ruin_surface (17,8), interact | No | Inn: 69 | P5 dig-camp bedroll | Bedroll: 15 |
| `briar_collectors_deep` (rung 1) | witch_hollow (4,11), interact | No ([Calming Touch]) | Riverfarm cot: 21 | None | Same |
| `hired_blades` (rung 2) | mercantile_alleys (17,12), interact | No | Brothers' couch: 6 | None (finding §4.2) | Same |
| `forge_calibration_golem` (rung 3, respawning cull) | pallass_forge (20,8), interact | No | Inn: 48 through the lift and the Door; Xif's potions one tier down | None | Same |
| `seal_warden_alcove` (Act V and rung 4) | trapped_halls (19,6), r1 | Yes | Inn: 53 if `dungeon_attuned`, otherwise 97 | P4 delve camp | Camp: 21 |

Not given placements: respawning ambient culls, the tutorial spar and
one-shot optional pockets. They are not chokepoints.

### P1. A Watch bunk in Liscor's barracks (rest)

- **Entity:** `watch_spare_bunk`, a sleep prop in `liscor/barracks.json`.
  The candidate cell is (1,1), the empty north-west corner.
- **Gate:** `present_when: {requires: {heard_about_cisterns: 1}}`. This is
  the Watch's first errand below the city, so the bunk appears when the
  Watch starts sending the player down.
- **Recovery:** a full sleep, with the ordinary consequences (§2).
- **Reachability:** the street door (22,2), then the barracks. The barracks
  is ungated.
- **Effect on the rest map:**
  - cisterns: 90 → 36 steps;
  - scouts: 88 → 34;
  - Awakened: 94 → 40;
  - vault (pre-Door): 123 → 69.

  None of these routes crosses the floodplains gate band (finding §4.1). The
  Inn bed, its room tiers and Erin's meals are unchanged. The bunk is a plain
  bed with no tiers.
- **Copy direction** (drafts for the prose pass):
  - observe: "A Watch bunk with the blanket squared at the foot, the cell
    number on the frame chalked over."
  - `sleep_toast`: "Watch bedding, scratchy and clean."

### P2. Grate-crew pail in the sewers (loot)

- **Entity:** `grate_crew_pail`, a container in `sewers/sewers.json` near
  the ladder. Candidates are on the ledge cells by the grate arrival (2,2),
  off the walked lane.
- **Contents:** `contains: ["hot_meal"]`, which is +6 HP.
- **Ties to existing content:** the game already ships the grate crew in
  `delivery_grate_phials`. The existing spider scratch on the drainage
  marker and the banded silk are the tells.
- **Copy direction:**
  - observe: "A lidded tin pail on the ledge above the waterline, a crew
    number chalked on the lid."
  - `open_toast`: "Stew in a wired-shut tin, packed in a cloth."

### P3. A Gnoll hunter's satchel past the scouts (loot and tell)

- **Entity:** `gnoll_hunters_satchel`, a container in
  `sewers/deep_tunnels.json` east of the scouts and short of the Awakened.
  The candidate cell is (10,3), off the scouts-to-gallery diagonal.
- **Contents:** `contains: ["mending_draught"]`, which is +8 HP.
- **Why here:** the scouts hold the only lane east, so the satchel is only
  reachable after that fight. That is exactly where the ledgers show players
  hurt: worker 3/44, Rogue 10/44.
- **It doubles as the tell.** It sits beside the existing sorted Gnoll bones.
- **Copy direction:**
  - observe: "A Gnoll's hunting satchel lying apart from the bones, the
    strap bitten through."
  - `open_toast`: "One corked draught in the side pocket, the wax unbroken."
- **Balance:** the Awakened still drops its own Mending Draught after the
  fight. The harness matrix carries no inventory, and the
  `sim_spine_viability` act III rows keep their `draughts: []` calibration
  input. The placed draught is optional kit, as the ruling allows.

### P4. The Horns' delve camp at the dungeon approach (rest)

- **Entity:** `horns_delve_camp`, a sleep prop (a bedroll) in
  `dungeon/dungeon_approach.json` by the depths door. The candidate cell is
  (15,2), off the (2,6)→(13,6) lane.
- **Gate:** `present_when: {requires: {horns_party_formed: 1}}`. The Horns
  set up when the delve begins, and the camp stays through Act V.
- **Two looks** (`visual_states` and `sleep_toast` variants on
  `horns_dig_started`):
  - during the delve, four bedrolls are laid out around a cold firepit;
  - afterwards, one bedroll is left rolled against the wall.

  This matches the dig camp's shipped remnant ("four flattened squares of
  ground where bedrolls were").
- **Recovery:** a full sleep.
- **Walk:** vault 123 → 19 steps; warden 53 or 97 → 21. Finding 5 from the
  first draft (the warden before attunement) disappears.
- **Interactions with nearby content:**
  - the `kingslayer_den` cull 8 cells away re-arms on that sleep, as it
    would after any sleep;
  - the wardstone Door and the Inn stay the home route.
- **Tells:** the existing arch and alcove lines, and the halls' bone pile.
- **No loot at the vault or the warden.** These are the top-band climaxes,
  and rest is the answer the ledgers used.

### P5. Bedroll at the Horns' dig camp (rest)

- **Entity:** `dig_camp_bedroll`, a sleep prop in `ruin/ruin_surface.json`
  beside the shipped camp props. The candidate cell is (1,4).
- **Gate:** the camp's own lifetime:
  `present_when: {requires: {horns_dig_started: 1}, absent: {door_mounted: 1}}`.
  The shipped `dig_camp_remnant` takes over after that.
- **Recovery:** a full sleep. **Walk:** 69 → 15 steps.
- **Tells:** the shipped camp crate ("three days of dried rations for four
  people") and the guardian's own stillness.

### P6. Crude arrows by the road (tell)

- **Entity:** `gate_road_arrows`, a non-interactive scenery prop in
  `floodplains/floodplains.json` beside the road, outside the r2 band and off
  the road cells. It blocks its own cell, so it needs a visible reason, and
  the census applies.
- **Copy direction:** observe: "Three crude arrows stand in the turf beside
  the road, fletched with crow feathers."
- **Why:** `goblin_encounter_1` has no observe line of its own.
- **No loot.** Act I players usually arrive rested, and every journey walks
  this road.

## 4. Findings, revisited

1. **Meeting the Act I gate ambush again on the way home.** A player who
   never defeated `goblin_encounter_1`, and passed it by sneaking rather than
   by the drainage cut, springs it on the first floodplains step home.
   Players coming home hurt from the cisterns, the warren or the vault all
   face this. It matters: `goblin_ambush / warrior5_mage5` reads 0.99 rested
   but 0.38 at 50% entry.

   **Answer: P1.** A Liscor-side bunk means a hurt player never has to cross
   the gate band to rest. The encounter and its cover rule are untouched.
2. **The alleys' footpads on the way to the Door.** No placement. The
   Brothers' couch is the alleys' rest, and from the warehouse crew and the
   second footpad pair it is reached without crossing either band (6 and 11
   steps). The alleys are a designed gauntlet: the spine roster records that
   they cannot be crossed clean without [Stealth]. Once `brothers_job_done`
   banks, the cross-street door gives a band-free way out. Recorded as
   design.
3. **The 75% threshold is moot.** Nothing triggers on resources any more.
   The measurement it came from still explains why the placements sit
   before the climaxes.

**Related legibility gap, unchanged and not proposed here:** a defeat
rollback replays the same seed, so only a change of state helps.

## 5. Doctrine

- **Zero-inference scenery.** Every observe and open line states physical
  facts: a satchel, a bitten strap, a corked draught, bedrolls, arrows. The
  player infers who did not come back.
- **Discovery beats instruction.** Nothing names a fight, a threshold or a
  Skill. Beds and loot are found by looking and using.
- **No balance tuning.** No encounter, stat, band or seed moves. The only
  power added is two placed consumables, one Hot Meal and one Mending
  Draught, each one-shot.
- **Three Pillars.** Every placement is open to every build. No Skill gates.
- **No new class or Skill names.**
- **Canon.** Watch barracks, the Horns' camps, Gnoll victims of the Raskghar
  and goblin raiders are all well inside the Book 17 bar.

## 6. Effects on the five continuous journeys

- **No journey interacts with a placement.** Each placement is optional, and
  a container or bed acts only on interact. Ledgers, gold, fights, sleeps and
  pins stay the same.
- **The risk is blocking.** Each new entity blocks its own cell.
  - Derive every journey's walked cells per map from `player_moved` in its
    `events.jsonl`, plus the cells it faces on its interact steps.
  - A candidate cell, and the neighbour a player would stand on to use it,
    must lie outside that set. Pick another cell if not.

  The census covers barracks, sewers, deep_tunnels, dungeon_approach,
  ruin_surface and floodplains.
- **Presence-gated beds** (P1, P4, P5) render only in the journeys' later
  states. Their `ui_entities_rendered` waits pin `pc_sprite` only.
- **Canonicals that pin sprite counts** on these maps must be re-derived from
  observed runs when their fixture state shows the new entity:
  - `barracks_walkthrough`;
  - `archer_earn_loop`;
  - `deep_descent`;
  - `missing_recruit_loop`;
  - `dungeon_peek`;
  - `horns_dig_flow`;
  - `floodplains_price_help`.

## 7. QA plan (real input)

1. **Static checks:**
   - data_lint (schema, arrival and blocking, reachability from start);
   - `test_content` (container items exist; presence gates name produced
     counters);
   - `test_copy_fit` (observe, `open_toast`, `sleep_toast`);
   - the shipped-IDs test;
   - the prose pass.
2. **Reach report.** Promote the scratch walk-cost BFS to a report-only
   `scripts/rest_reach_report.py`. It prints this inventory from map data
   under declared gate states, so the table is reproducible.
3. **`rest_before_warren`** (new, tier `full`). It starts from
   `journey_rogue`'s earned save at 10/44 HP, 0/14 MP in `deep_tunnels`,
   captured as a disclosed checkpoint fixture (the
   `poor_retired_producer_recovery` idiom).
   - Walk to the satchel and open it. Assert `item_gained mending_draught`
     and the rendered `open_toast`.
   - Drink it in the field. Assert `item_use_settled` +8 HP, `game_saved`
     `auto` and `ui_save_status_rendered`.
   - Walk up through the tunnels, sewers and street to the bunk, and sleep.
     Assert full vitals and that **no fight started on floodplains**.
   - Return and win the Awakened rested.
   - Negatives: a second open renders "Empty."; the bunk is absent in a save
     before `heard_about_cisterns`.
4. **`rest_delve_camp`** (new). It starts from `steel_thread`'s earned
   post-vault state (35/49 HP, 0/14 MP in trapped_halls).
   - Walk to the camp and sleep. Assert full vitals and the camp's
     `sleep_toast`.
   - A second leg proves the post-dig look (one bedroll).
5. **`rest_dig_camp`** (new). It starts from `steel_thread`'s guardian
   rollback at 35/49 HP: bedroll, sleep, then win the guardian. This is the
   ledger's own retry, cut from 69 steps to 15.
6. **Sewer pail** leg: from an Act II save, open the pail and eat the meal.
   Assert +6 HP and the autosave.
7. **Windowed reads:**
   - each prop's look against its blocking reason;
   - the sleep veil and receipt at each new bed;
   - the "Saved" pill after eating or drinking;
   - the arrows' read from the road.
8. **Gates:**
   - `ci_sweep --touching` each map;
   - all five journeys with `qa/journey_gate.py`;
   - the full sweep;
   - the harness, which must show zero diff.

## 8. Files and lanes

Data only, with no `src/` change. The region directories are disjoint
lanes:

| Lane | Files |
|---|---|
| Liscor | `data/maps/liscor/barracks.json` (P1) |
| Sewers | `data/maps/sewers/sewers.json` (P2), `data/maps/sewers/deep_tunnels.json` (P3) |
| Dungeon | `data/maps/dungeon/dungeon_approach.json` (P4) |
| Ruin | `data/maps/ruin/ruin_surface.json` (P5) |
| Floodplains | `data/maps/floodplains/floodplains.json` (P6) |

Shared, serialized:
- `data/sprites.json`, only if a prop needs a new registry row; prefer
  shipped bed, bench, crate and satchel art (`wi-art-and-sprites`, best art
  wins);
- `data/shipped_ids.json`, regenerated;
- the QA manifest and fixtures, `derive_qa_surfaces.py` and
  `render_qa_notes.py --write`.

## 9. Remaining decisions

1. **P1: the Liscor-side bed.** Recommended: the Watch bunk gated on
   `heard_about_cisterns`. Alternatives:
   - a cot in Liscor's Runner's Guild, gated on one completed delivery;
   - no Liscor bed, accepting finding 1.
2. **P4: the dungeon bedroll** turns the game's longest rest walk (123
   steps) into 19. Recommended. The alternative is loot only (one Mending
   Draught at the approach), which keeps the long walk.
3. **Amounts.** Recommended: a Hot Meal at the cisterns and a Mending Draught
   at the warren. A Fine Meal (+8 HP, +4 MP) at the warren would also serve
   MP users.
