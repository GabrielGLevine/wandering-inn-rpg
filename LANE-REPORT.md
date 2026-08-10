# LANE-REPORT — #423 Hedault's Enchanter shop + [Pick Lock] debut (lane H)

Worktree `/tmp/wi-423`, branch `issue/423-hedault-shop`, base `aef1fe82`.
Commits: `c2de3bc5` (feature), `497c0c91` (voice baselines + QA notes + VISUAL-LOG).

STATUS: **core deliverables 1-6 + 9 DONE and green. Deliverables 7 (route growth
on invrisil_walkthrough / steel_thread), the three PROVE-CAN-FAIL runs, the full
`--touching` sweep and `preflight.sh` are NOT DONE — the session hit the
USAGE-GUARD WINDDOWN tier mid-lane.** Everything that IS committed was verified
foreground; nothing is claimed green that was not run. See §9.

---

## 1. What shipped

### New maps
* `data/maps/invrisil/enchanter_shop.json` — 12x9 interior, `brothers_parlor`
  biome, stationer.json schema (perimeter in `walls.segments`, `blocked` empty,
  decor non-solid). Hedault at **(2,3)** with three orthogonally-adjacent
  standable cells — (1,3), (3,3), (2,4) — every one walk-reachable from the
  shop door's landing (6,7). That is the exact defect #423 names: his
  `mercantile_alleys` (0,6) had **zero**.
* `data/maps/invrisil/enchanter_work_room.json` — 8x6, the gated AREA behind
  the lock (the user's "true use of [Pick Lock] is access to gated areas").

### Door pair
* `invrisil_boulevard`: new `boulevard_enchanter_shop` door at **(22,1)** —
  inside the briefed 19..27 band, clear of `boulevard_stationer` (20,1) and
  `boulevard_coyle_front` (23,1). Row 1 is blocked x0-27, so promoting a facade
  cell costs no walkable cell (the shipped stationer/adventurer's-rest pattern).
  Landing **(22,2)**, open plaza.
* `enchanter_shop_exit` (6,8) -> boulevard (22,2). Both landings are open floor,
  **not** door cells (entities block: `wi_game.gd:310-312` blocks on *every*
  present entity, doors included — see §7 for why that matters).

### Hedault moved + alley re-dressed
* `hedault` deleted from `mercantile_alleys`; `talk_pool`, `observe` and
  `conversation` **moved verbatim** (not copied — the anti-duplication gate
  would have caught a copy).
* (0,6) is walkable for the first time, which also gives
  `invrisil_apothecary_bench` (1,6) a second approach.
* Re-dress: `alley_enchanter_card` on the already-blocked wall cell (0,5),
  sprite `price_board`, approach (0,6) — a diegetic pointer at the new
  frontage for a player who knew the old pitch. Cups untouched.

### [Pick Lock]
* `skills.json`: id `pick_lock`, `[Pick Lock]`, `contexts:["exploration"]`,
  `field: true`, `field_ambient`, description. **Zero engine, zero
  interactions.json row** — it carries no `skill_property`, so it rides the
  shipped `requires_skill` + `on_skill_use` seam exactly like `disarm_trap`.
* `classes.json`: rogue **L2** grant. `requires` (`sneaked_past_danger: 2`)
  UNCHANGED per brief. Ladder now sneak / pick_lock / find_trap / dangersense /
  disarm_trap.

### The debut gate — ONE prop, two modes
`enchanter_work_room_door` (enchanter_shop 8,3) carries **both** `door_when`
and `requires_skill`. `interactions.gd` checks `door_when` at line 93 and
`requires_skill` at 159, so one prop gives all three behaviours with no new
machinery:

| state | interact does |
|---|---|
| gate unmet, skill unknown | falls to `_use_skill` -> `SKILL_UNKNOWN{pick_lock}` + the prop's `locked_toast` |
| gate unmet, skill known | `skill_hint_toast` (interact never auto-casts — the 2026-07-10 directive) |
| gate met (either mode) | transitions into `enchanter_work_room` |

**Why not `present_when`** (the counting_room_* idiom I started with): a
dialogue-banked counter flipping a same-map prop's presence leaves a stale
sprite until the next `MAP_CHANGED` — `world.gd` reconciles presence on
`PHASE_CHANGED` and `MAP_CHANGED` only, never on `ACCOMPLISHMENT_RECORDED`
(AGENTS.md, GH#104 block). The virtuous path banks its counter while the player
is standing in the shop, so `present_when` would have shipped the exact
machine-green/player-truth ghost this issue exists to close. `door_when` never
flips presence, so there is nothing to reconcile.

### The virtuous path (deliverable 4, mode 2)
`hedault_enchanting.json` gains one hub option, **appended LAST** and gated on
`setting_commissioned: 1` (the `a_setting_for_a_lady` completion — the brief's
first candidate), hidden once `enchanter_work_room_opened` banks, plus one new
node `work_room_opened`. Because it is accomplishment-gated it is HIDDEN at
every shipped fixture, so `invrisil_v016_gate_check`'s whole-array hub pin and
`spine_reach`'s blind `move down 5` both stayed exact — **zero re-pins**
(verified by run).

### Back-room contents — hedaults_wardstone AUDIT
Per the coordinator's mid-lane correction, and independently reached here
before it arrived:

* `hedaults_wardstone` **is** an orphan — no dialogue, quest, prop or container
  grants it (`grep` over `data/` + `qa/`, excluding playtest_saves, finds only
  `items.json:1072`, `shipped_ids.json:189`, and a **stale `_comment`** in
  `hedault_fragment_loop.json` claiming that loop grants it; it grants
  `hedaults_warded_setting`). Comment corrected in this lane.
* **ROOT CAUSE of the orphan (controller call, NOT taken here):** GH#142's swap
  triple is 1:1 base->variant everywhere except the wardstone. `traveler_charm
  -> hedaults_traveler_charm`, `hunters_fang_talisman -> hedaults_hunters_fang`,
  but `witch_wardstone_bead -> hedaults_warded_setting` — the *fragment* trade's
  output, granted by two different options. `hedaults_wardstone`'s own
  `_comment` says verbatim "Hedault enchant variant of witch_wardstone_bead
  (base 16g + 40g fee)". The 40g bead option almost certainly means to grant it.
  **Not fixed here**: re-pointing it changes a shipped purchasable's stats
  (res 1->2, DR 1->0, +`mana_shield`) — a balance-touching change outside this
  lane's charter. Filed as a finding.
* **Band verdict: does not fit a back-room reward.** It is a resonance-2
  `mana_shield` combat carrier at 50g behind a 40g fee. Every shipped
  container reward in the comparable band is a mundane trade good with zero
  combat modifiers. Gifting it free would both misband the reward and undercut
  the enchant loop's own gold sink. **Left unwired.**
* **New item instead:** `enchanters_true_gauge` — banded field-for-field on
  `sealed_factor_bale` / `riverfarm_ferry_tally`: `kind: tool`, mundane, 28g,
  `damage_mod/hp_mod/damage_reduction/resonance` all 0. No balance-harness
  surface. Lives in `work_room_finished_work` (2,2), one-shot via
  `container_state` (`on_open_accomplishment: took_enchanters_gauge`).

### invrisil_apothecary_bench disposition (audit, per brief)
**LEFT IN THE ALLEYS.** References audited: zero QA scripts, zero fixtures,
zero dialogue. Its counter `synthesized_draught` is shared with the Pallass
benches (`sim_class_paths.gd`, `test_sim_core.gd`, `mixer_alchemist_loop`), so
nothing is pinned to *this* placement — moving it would have been free
mechanically. It stays on fiction: it is a **rented-by-the-hour apothecary
corner** ("WORKING SPACE, BY THE HOUR, NO CREDIT"), which is the opposite of
Hedault's shop, and he would not keep someone else's alchemy burner in it. It
also gained a second approach from this lane (0,6 is now walkable).

---

## 2. Re-anchor inventory (deliverable 6) — COMPLETE

Grepped `qa/scripts` + `qa/fixtures` for every hedault / alleys-cell reference.
Full enumeration and disposition:

| surface | before | after |
|---|---|---|
| `qa/fixtures/near_hedault.json` | `mercantile_alleys` (0,7), **on the alleys door cell**, facing Hedault at (0,6) | `enchanter_shop` (6,7), the shop-door landing — five moves from him |
| `qa/fixtures/hedault_fragment_start.json` | same staged shape | same re-anchor |
| `qa/scripts/hedault_enchant_loop.json` | booted adjacent, interacted immediately | WALKS up 3 / left 4, bumps north into (2,3) — `player_blocked` asserted |
| `qa/scripts/hedault_fragment_loop.json` | same | same walk |
| `qa/scripts/spine_reach.json` | teleport alleys (0,7) + `move up 1` | teleport shop (6,7) + the same walk |
| `qa/scripts/invrisil_setting_skill.json` | teleport alleys (0,7), `player_blocked [0,6]` | teleport shop (6,7), `player_blocked [2,3]` |
| `qa/scripts/invrisil_setting_talk.json` | same | same |
| `qa/scripts/invrisil_v016_gate_check.json` | same (first of two alleys teleports; the second, (11,11), untouched) | same |
| `qa/fixtures/finale_merge_start`, `seal_fed_start`, `seal_open_start`, `seal_reward_start` | reference `lattice_hedault_reading` only — an accomplishment, no cell/map pin | **no change needed** |
| `data/quests.json` `a_setting_for_a_lady` resolve beat | "Hedault keeps a bench in the alleys" | "…keeps a shop off the main square" (two of its three producers moved) |
| `tests/test_content.gd` `LANDMARK_TOKENS` | — | + `enchanter_shop`, `enchanter_work_room` (the beat above is a travel beat; a missing row is a HARD fail) |
| `tests/test_fixture_coherence.gd` `MAP_REQUIRES` | — | + both maps; the work room requires `enchanter_work_room_opened` (the seal_vault/rags_camp precedent) |

**The pre-staged-adjacency finding, sharpened:** both fixtures stood the PC
*on* the alleys door cell (0,7). `WIGame.is_cell_blocked` blocks on every
present entity including doors, so **no player could ever stand there** — the
fixtures were not merely pre-staging adjacency, they were pre-staging an
impossible cell. Both new fixtures land on plain open floor.

### New canonical: `enchanter_work_room` (seed 7)
Three phases, each swapped in through the real pause-menu Load path
(`martial_field_loop`'s idiom), all counters **created by the run**:
* **Phase 0 — refusal** (`near_hedault`: no rogue line, no commission):
  `assert_field_skill_absent pick_lock`, walk to (8,4), bump (8,3),
  `skill_unknown{pick_lock}` + the exact `locked_toast`, and
  `current_map` still `enchanter_shop` (the refusal is structural, not cosmetic).
* **Phase 1 — pick** (`enchanter_pick_start`, rogue 2): bare interact HINTS,
  `press_field_skill pick_lock` banks `enchanter_work_room_opened`, the SAME
  interact then transitions, the case yields `enchanters_true_gauge`, a second
  interact answers "Empty." and `assert_event_count item_gained == 1`.
* **Phase 2 — trust** (`enchanter_key_start`, **no rogue line at all**):
  `assert_field_skill_absent pick_lock` proves the pick mode is *unreachable*,
  not merely unused; Hedault's row 6 opens the door; the room yields the SAME
  id (`assert_event_count item_gained == 2`); exits by the work-room's own door.
  `assert_event_absent combat_started` over the run.

### Fixtures (grant-derived, honest)
* `enchanter_pick_start` — `near_hedault` backbone + `rogue: 2`, with
  `recovered_crate_watch: 1` (gained_by) and `sneaked_past_danger: 2` (the L2
  requires) banked. `player_skills` untouched: [Pick Lock] arrives as the class
  grant, never hand-granted. No `enchanter_work_room_opened`, no
  `took_enchanters_gauge`.
* `enchanter_key_start` — `near_hedault` backbone + the commission chain
  (`heirloom_commission_started` -> `heirloom_truth_kept` ->
  `setting_commissioned`), **no rogue line**. No gate counters.

---

## 3. Existing-door audit (deliverable 5) — PROPOSAL: **NO CONVERSION**

The brief's default stands. Assessed against the three-part test (literal lock
+ meaningful gated content + a legitimate alternate mode):

* **`inn_upstairs` `hallway_door_a` / `hallway_door_b`** — ungated set-dressing
  with no space behind them. Fails "meaningful gated content" outright.
  A [Pick Lock] row here would be a Skill that opens a cupboard.
* **`inn_upstairs` `lyonette_door`** — a literal lock with an `observe` +
  `locked_toast`, so it passes test 1, and fails tests 2 and 3 together: there
  is no room content behind it, and the only honest legitimate mode is Lyonette
  handing over her own key, which is a **character** ask (she is a named ally
  living in the inn) rather than a data one. Picking a housemate's bedroom
  door for nothing is also a tonal call the controller should make, not a lane.
* **`barracks` `cell_door`** — a real lock over a deliberately empty,
  "empty-v1 dressed" cell (its own canonical, `barracks_walkthrough`, pins the
  `locked_toast`). Passes test 1, fails test 2, and the legitimate mode is a
  jailbreak's-worth of Watch design (Zevara, consequences, a reason to be in
  there) — a milestone, not a lane item.

**Recommendation:** ship the pattern on the new shop only, exactly as the
dispatch comment anticipated ("this shop back room CREATES the pattern"). The
first *good* second placement is a future locked cache authored with its
two modes from the start, not a retrofit onto a door that gates nothing.

---

## 4. Icon call (scoped STOP, per brief) — NEEDS_CONTEXT

The icon set ships **196 files, all registered, none of them a lock, pick or
key**. No unregistered PNG exists to adopt. Reuse candidates were assessed and
all collide: [Pick Lock] is rogue L2, so [Stealth] (L1), [Find Trap] (L3) and
[Disarm Trap] (L5) are all held by the same PC on the same hotbar — the
distinct-silhouette directive (2026-08-02) rules those out.

**Shipped choice:** `icon_open_doors`, INTERIM, on the reuse-with-precedent
branch the brief allows (precedent: Basic Swordwork on `icon_power_strike`,
CHOICE-LOG 26). Semantically nearest glyph; collides only with [Open Doors],
a social-line skill a rogue rarely also carries. Documented in the skill's own
`_comment` and filed as a VISUAL-LOG row. **Controller owns the bespoke-icon
call — that is the ask.** I did not generate art (brief: controller owns art
calls).

---

## 5. Gate commands + verbatim verdicts

All foreground, sequential, alarm-wrapped (`perl -e 'alarm N; exec @ARGV'`).

```
python3 scripts/data_lint.py
  -> data_lint: OK -- 129 files, 32 maps clean in 256ms
     (3 pre-existing report-only advisories, unchanged in count)

godot --headless --path . --import                       -> DONE (class_name cache)
```

Full unit bar — **every test in `tests/test_*.gd`, all PASS**:
```
test_acts test_audio_data test_chronicle test_combat_data test_combat_sim
test_combat_visuals test_content test_copy_fit test_dialogue test_effect_text
test_event_log test_fixture_coherence test_inn_guests test_input_hints
test_interactions_table test_items test_journal_producers test_message_layer
test_portals test_progression test_quests test_reachability test_reload_caches
test_save test_save_rename test_settings test_shipped_ids test_sleep_veil
test_sprite_registry test_system_bestowal test_traversal_seams
test_water_shoreline test_world_visuals
```
Notables:
* `PASS: fixture coherence — 194/194 fixtures are reachable story positions`
* `PASS: requires-gate reachability — 337 consumed counters, 588 real producers, 0 orphans`
* `PASS: shipped-ids freeze -- 908 frozen ids across 5 classes still covered`

Three tests needed lane edits to stay honest (all committed):
* `test_content.gd` — `LANDMARK_TOKENS` rows for both new maps (the moved quest
  beat is a travel beat; without the row it hard-failed: *"needs a travel
  landmark on map enchanter_shop"*).
* `test_effect_text.gd` — pinned `enchanters_true_gauge: ["Worth 28 gold"]` and
  `pick_lock: []` (EXPECTED_ITEMS/EXPECTED_SKILLS are exhaustive both ways).
* `test_fixture_coherence.gd` — `MAP_REQUIRES` rows.

Canonicals, each run individually at its pinned seed:
```
qa/run_qa.sh enchanter_work_room     headless --seed=7  -> QA_RESULT: PASS (223 events, first try)
qa/run_qa.sh hedault_enchant_loop    headless --seed=7  -> QA_RESULT: PASS
qa/run_qa.sh hedault_fragment_loop   headless --seed=7  -> QA_RESULT: PASS
qa/run_qa.sh invrisil_setting_skill  headless --seed=9  -> QA_RESULT: PASS
qa/run_qa.sh invrisil_setting_talk   headless --seed=9  -> QA_RESULT: PASS
qa/run_qa.sh invrisil_v016_gate_check headless --seed=9 -> QA_RESULT: PASS
qa/run_qa.sh spine_reach             headless --seed=9  -> QA_RESULT: PASS
```
No `SCRIPT ERROR`, `Parse Error` or `WARNING` in any run output.

Manifest / surfaces:
```
scripts/derive_qa_surfaces.py          -> wrote surfaces for 239 script(s)
qa/ci_sweep.sh --touching <26 paths>   -> derive_qa_surfaces: --check OK, 239 script(s) match
scripts/render_qa_notes.py --write     -> PASS: QA notes match manifest
```
`AGENTS.md`'s canonical seed table gained the `enchanter_work_room` row and the
`hedault_enchant_loop` row notes the re-anchor (ci_sweep hard-fails on drift).

Voice gates:
```
dialogue_voice_gate.py check --maps --baseline docs/dialogue-voice/baseline-maps
  -> pass  enchanter_shop.json        hard=0 warn=0 anti=0   (cold, first run)
  -> pass  enchanter_work_room.json   hard=0 warn=0 anti=0   (cold, first run)
  -> invrisil_boulevard / mercantile_alleys: structural-only FAIL (entity move),
     re-frozen, now pass
dialogue_voice_gate.py check --baseline docs/dialogue-voice/baseline
  -> hedault_enchanting.json: structural-only FAIL (added node+option), anti=0,
     re-frozen, now pass
```
**PRE-EXISTING, NOT THIS LANE:** the maps gate still reports 12 structural
FAILs on maps this lane never opened — `trapped_halls`, `floodplains`, `inn`,
`inn_upstairs`, `street`, `pallass_forge`, `pallass_forge_hall`,
`pallass_market`, `riverfarm_longhouse`, `riverfarm_village`, `witch_hollow`,
`witch_hut`. The maps baseline is stale on base `aef1fe82`. Flagging, not
touching (re-freezing someone else's drift would launder it).

---

## 6. #424 waiver obligation (deliverable 8)

The suite lives on the unmerged #424 lane and was not hunted for. The
obligation is met by construction and asserted by run:
* `hedault` (2,3): neighbours (1,3), (3,3), (2,4) — all standable, all reached
  by a real walk from (6,7) in five separate canonicals.
* Every prop placed by this lane has >=1 standable orthogonal neighbour
  reachable from its map's landing cell: shop props at (1,1)/(4,1)/(5,1) from
  y=2; (1,5) from (1,4)/(2,5); the gate prop (8,3) from (8,4); work-room props
  (2,2) from (2,3), (5,2) from (5,3), (5,4) from (4,4)/(6,4).
* `alley_enchanter_card` (0,5) from (0,6), which this lane *created* by moving
  Hedault out.
The controller removes the suite's hedault waiver at composed-merge.

---

## 7. Findings for the controller

1. **`hedaults_wardstone` orphan root cause** (§1) — the GH#142 bead option
   grants the fragment's output. One-line data fix, balance-touching, not
   taken here.
2. **Fixtures could stand on blocked cells.** `near_hedault` /
   `hedault_fragment_start` stood the PC on a door cell — a position
   `is_cell_blocked` forbids. Fixture load does no blocking check. A cheap
   `test_fixture_coherence` arm ("no fixture stands on a blocked cell") would
   catch the whole class; sibling material for #424.
3. **Maps voice baseline is stale on 12 untouched maps** (§5).
4. **`present_when` + a same-map dialogue bank is a ghost factory** — worth a
   line in the skill library: prefer `door_when` for any gate whose key can be
   banked while the player is standing on that map.

---

## 8. Diffstat

```
 wandering_inn_game/AGENTS.md                                 |   3 +-
 wandering_inn_game/data/classes.json                         |   2 +-
 wandering_inn_game/data/dialogue/hedault_enchanting.json     |  33 ++
 wandering_inn_game/data/items.json                           |  16 +
 wandering_inn_game/data/maps/invrisil/enchanter_shop.json    | 337 +++++++++++
 wandering_inn_game/data/maps/invrisil/enchanter_work_room.json | 165 ++++++
 wandering_inn_game/data/maps/invrisil/invrisil_boulevard.json |  17 +
 wandering_inn_game/data/maps/invrisil/mercantile_alleys.json |  20 +-
 wandering_inn_game/data/moods.json                           |  40 ++
 wandering_inn_game/data/quests.json                          |   4 +-
 wandering_inn_game/data/skills.json                          |  12 +
 wandering_inn_game/qa/fixtures/enchanter_key_start.json      |  new
 wandering_inn_game/qa/fixtures/enchanter_pick_start.json     |  new
 wandering_inn_game/qa/fixtures/hedault_fragment_start.json   |   6 +-
 wandering_inn_game/qa/fixtures/near_hedault.json             |   8 +-
 wandering_inn_game/qa/manifest.json                          |  46 +-
 wandering_inn_game/qa/scripts/enchanter_work_room.json       |  new (120 steps)
 wandering_inn_game/qa/scripts/hedault_enchant_loop.json      |  +walk
 wandering_inn_game/qa/scripts/hedault_fragment_loop.json     |  +walk
 wandering_inn_game/qa/scripts/invrisil_setting_skill.json    |  re-anchor
 wandering_inn_game/qa/scripts/invrisil_setting_talk.json     |  re-anchor
 wandering_inn_game/qa/scripts/invrisil_v016_gate_check.json  |  re-anchor
 wandering_inn_game/qa/scripts/spine_reach.json               |  re-anchor
 wandering_inn_game/tests/test_content.gd                     |   6 +
 wandering_inn_game/tests/test_effect_text.gd                 |   8 +
 wandering_inn_game/tests/test_fixture_coherence.gd           |   9 +
 docs/VISUAL-LOG.md                                           |  +4 rows
 docs/dialogue-voice/baseline{,-maps}/                        |  4 snapshots
 wandering_inn_game/docs/QA-SCRIPT-NOTES.md                   |  regen
```
**No `src/**` edits.** Content is data, as briefed.

---

## 9. NEEDS_CONTEXT / NOT DONE — the honest remainder

Session hit USAGE-GUARD **WINDDOWN** (burn 37%/hr, exhaustion ETA ~48m) with
the lane's core green and committed. Deliberately stopped rather than start
work I could not verify. Outstanding, in the order I would resume:

1. **Deliverable 7 — route growth.** `invrisil_walkthrough` and `steel_thread`
   do NOT yet have the shop leg. Both are untouched and still green as-is
   (neither references Hedault). The insert point for `invrisil_walkthrough` is
   after its stationer beat (its steps ~57-67, PC around (17,2) on the
   boulevard): walk to (22,2), interact into the shop, read the work-room
   door's `locked_toast` (that fixture has no rogue line — it is a free
   refusal read), exit, resume. `steel_thread` is the composed windowed
   instrument; keep its duration honest per its own conventions.
2. **PROVE-CAN-FAIL x3.** Designed, not run:
   (a) *reward one-shot* — temporarily add a third case interact asserting
   `item_gained == 2` within phase 1; must red.
   (b) *lock refusal* — temporarily delete `requires_skill` + `locked_toast`
   from `enchanter_work_room_door`; phase 0's toast wait must time out.
   (c) *WALK leg* — temporarily add `[2,4]` to `enchanter_shop.blocked`;
   `hedault_enchant_loop`'s `player_cell == [2,4]` assert must red.
   Restore after each.
3. **Full `--touching` sweep + `--tier smoke`.** The 26 changed paths were fed
   to `ci_sweep.sh --touching` for the surfaces `--check` only. `skills.json` /
   `classes.json` / `items.json` pull in a wide selection; the seven directly
   affected canonicals were each run green individually, the wider set was not.
4. **`scripts/preflight.sh`** — not run.
5. **A windowed look at the two new interiors.** They ship with no
   `floor_layers` (biome default) and reuse `temper_bench` / `price_board`;
   nobody has seen them. VISUAL-LOG rows filed.
6. **CHOICE-LOG 28** — the wave plan already carries the [Pick Lock] ruling;
   this lane's own calls (icon interim, wardstone left unwired, `door_when`
   over `present_when`, no door conversion) are recorded here and in the data's
   own `_comment`s but are not yet folded into `docs/CHOICE-LOG.md`.

---
---

# TAIL (resumed after usage-window reset) — §9 closed

Commit: `<tail>` on the same branch. Everything in report §9 is now done
except one item proven PRE-EXISTING (see T4). No rebase; base is still
`aef1fe82`.

## T1. Route growth (deliverable 7) — DONE, both green

**`invrisil_walkthrough`** (+38 steps, seed 9) — inserted as BEAT 3c
between the stationer read and the Coyle sign, entering and leaving so
every downstream leg's cell arithmetic is byte-unchanged (it returns to
(20,2) before the existing `move right 3`). The leg is the region
canonical's answer to the issue itself:

* right 2 to (22,2), bump (22,1), interact -> `enchanter_shop` (6,7);
  screenshot `01f_enchanter_shop_entered`.
* `assert_field_skill_absent pick_lock` (this fixture holds no rogue
  line), walk to the gate at (8,4), bump (8,3), interact ->
  `skill_unknown{pick_lock}` + the exact `locked_toast`, and
  `current_map` unchanged. Screenshot `01g_work_room_locked`. **The
  refusal read is free at this fixture** — no new state, no new fixture.
* left 6 to (2,4), bump (2,3), interact -> `dialogue_line{Hedault}`.
  Screenshot `01h_hedault_reachable`. **This is the #423 proof living in
  the region canonical**: the enchanter is spoken to from a cell a
  player can stand on, by walking, with no fixture staging.
* out via (6,7)/(6,8) back to (22,2), left 2 to (20,2).

**`steel_thread`** (+9 steps) — ONE plate, inserted after the
`06b_mercantile_alleys` plate, built to the file's own **TOLERANT
MAJOR-MAP LEG** convention verbatim (teleport, `map_changed`, map+cell
asserts only, no interior-data pins, one screenshot, `wait_frames 240`).
Duration cost is exactly one album plate — the same 240-frame hold every
other plate takes. Plate `06c_enchanter_shop_the_bench_you_can_reach` is
shot from (3,4), which frames Hedault, the workbench and the shelving.
**The work room takes NO plate**: this album's PC holds neither the rogue
line nor the commission, so it is structurally unreachable at that save
and a plate would have required staging state the album does not carry.

```
qa/run_qa.sh invrisil_walkthrough headless --seed=9  -> QA_RESULT: PASS
qa/run_qa.sh steel_thread         headless --seed=9  -> QA_RESULT: PASS ("failures": [])
```

## T2. PROVE-CAN-FAIL x3 — all three RED then restored GREEN

Each: arm the mutation, run foreground alarm-wrapped, capture the failure
verbatim, `git checkout --` the file, re-run.

**(a) Back-room reward one-shot (`container_state`).** Armed by flipping
phase 1's `assert_event_count item_gained == 1` to `== 2` — the count a
BROKEN one-shot would produce.
```
RED  QA_RESULT: FAIL
     QA_FAILURE: event count mismatch for item_gained: expected 2, got 1
RESTORED  QA_RESULT: PASS
```

**(b) Lock refusal leg reds if the gate row is deleted.** Armed by
deleting `requires_skill` AND `locked_toast` from
`enchanter_work_room_door`.
```
RED  QA_RESULT: FAIL
     QA_FAILURE: timeout (5.0s) waiting for event: skill_unknown subset={"skill":"pick_lock"} cursor=13
     QA_FAILURE: expected event was never emitted: player_blocked
     ...cascading: item_gained / took_enchanters_gauge / open_toast / "Empty."
        all time out, inventory lacks the gauge, both count asserts miss
RESTORED  QA_RESULT: PASS
```
Note the cascade is itself informative: with the skill arm gone the prop
stops blocking as a gate at all, so the whole downstream chain collapses
— the leg is not pinned on the toast string alone.

**(c) The re-anchored loop's WALK leg reds if Hedault's adjacent
standable cell is re-blocked.** Armed by adding `[2,4]` to
`enchanter_shop.blocked` (the exact defect #423 fixes, re-injected), run
against `hedault_enchant_loop`.
```
RED  QA_RESULT: FAIL
     QA_FAILURE: assert_state: player_cell expected [2.0, 4.0], got [3, 4]
     QA_FAILURE: expected event was never emitted: player_blocked
     QA_FAILURE: timeout (5.0s) waiting for event: dialogue_started subset={"conversation":"hedault_enchanting"} cursor=13
     QA_FAILURE: assert_state: gold expected 5.0, got 40
RESTORED  QA_RESULT: PASS
```
This is the one that matters most: it proves the re-anchored loop is now
pinned on *reaching* him, not merely on talking to him. The pre-#423
shape could not have produced this failure — the fixture was already
adjacent.

## T3. Wide verification — all foreground, sequential, alarm-wrapped

```
python3 scripts/data_lint.py
  -> data_lint: OK -- 129 files, 32 maps clean (advisory counts unchanged)

full unit bar, every tests/test_*.gd (33 suites)   -> ALL PASS, zero non-PASS
scripts/derive_qa_surfaces.py                      -> wrote surfaces for 239 script(s)
qa/ci_sweep.sh --touching <29 paths>               -> surfaces --check OK
qa/ci_sweep.sh --tier smoke                        -> ci_sweep: ALL 14 script(s) green, no grep hits
```

**The `--touching` selection over `skills.json` / `classes.json` /
`items.json` is effectively the whole corpus, so the FULL canonical
sweep was run instead — a strict superset.** It exceeds the 10-minute
per-invocation cap, so it was run as 7 sequential foreground chunks of
36 (`--only`), never backgrounded:
```
chunk 0/6  ci_sweep: ALL 36 script(s) green, no grep hits.
chunk 1/6  ci_sweep: ALL 36 script(s) green, no grep hits.
chunk 2/6  ci_sweep: ALL 36 script(s) green, no grep hits.
chunk 3/6  ci_sweep: ALL 36 script(s) green, no grep hits.
chunk 4/6  ci_sweep: ALL 36 script(s) green, no grep hits.
chunk 5/6  ci_sweep: ALL 36 script(s) green, no grep hits.
chunk 6/6  ci_sweep: ALL 23 script(s) green, no grep hits.
           = 239/239 canonicals green
```
`--touching` also emitted its standing WARNINGs that `AGENTS.md`,
`data/moods.json`, `docs/QA-SCRIPT-NOTES.md`, `qa/manifest.json` and the
three `tests/*.gd` files have no surface mapping and therefore derive no
crossing scripts — which is exactly why the full sweep plus the full
unit bar were run rather than the derived subset.

## T4. preflight.sh — one real fix, one PRE-EXISTING failure

First run surfaced two failures. Both were bisected against the lane base
`aef1fe82` (clean `git archive` of the base into a temp dir):

1. **`extract_prose self-test` — MINE, FIXED.** PASSES on base, failed on
   my tree: one new string reached the prose landmark heuristic with no
   ruled disposition —
   `map:invrisil/enchanter_work_room.json:$.entities[1].open_toast`, the
   work-room case's reward beat (`classify_row` reads it as
   landmark/payoff). Ruled **KEEP-AS-IS** with its `why` in
   `extract_prose.py`'s registry table, and
   `docs/prose-naturalization/landmark-registry.json` regenerated through
   the sanctioned path (`extract_prose.py landmarks --dir …`, never by
   hand):
   ```
   landmarks: 17 rows -> docs/prose-naturalization/landmark-registry.json
     KEEP-AS-IS=9 NOT-A-LANDMARK=6 RESTAGE=2 | beats 9/12 spent, 3 in reserve
   self-test: PASS
   ```
   Reserve arithmetic is UNMOVED (9/12 spent, 3 reserve) — a
   heuristic-landmark row is not a controller grant. **LANE-PROPOSED,
   controller may downgrade to NOT-A-LANDMARK** (CHOICE-LOG 28-H.6): the
   doctrine says ruling is a controller act, but preflight hard-fails on
   an unruled landmark, so the lane took the honest reading rather than
   the cheap one.

2. **`doc drift` — PRE-EXISTING, NOT TOUCHED.** `plan lacks DONE/ACTIVE
   header: docs/superpowers/plans/2026-08-10-reachability-wave-417-421-423-424.md`.
   Reproduced **identically on base `aef1fe82`**; `git diff aef1fe82 HEAD
   -- docs/superpowers/plans/` is empty (this lane never opened the plan).
   The plan doc is the wave's shared, coordinator-owned file — editing it
   from a lane would collide with composition. Left alone, disclosed.

Final preflight:
```
ok data_lint | ok verify-untouched | ok extract_prose self-test
ok qa surfaces --check | ok guidance mirrors | ok unit test_sprite_registry
FAIL doc drift   <- pre-existing, identical on base
```

## T5. CHOICE-LOG 28 fold-in — DONE (lane-side references, not a rewrite)

`docs/CHOICE-LOG.md` gains **28-H**, six sub-entries under the existing
ruling 28, recording only the calls the lane made executing it — the
`door_when`-not-`present_when` build and why, the `setting_commissioned`
trust beat, the wardstone band verdict + the orphan's root cause, the
door-audit NO-CONVERSION verdict, the interim icon, and the
lane-proposed landmark disposition. Ruling 28 itself is untouched.

## T6. Disclosure re: main having moved (#425/#426)

* The **#417 tooling** this lane stacks on (`derive_qa_surfaces` walking
  `install_fixture`) is what `enchanter_work_room`'s three-fixture
  manifest row depends on. It is now in main; my base carries it too, so
  the composed surfaces should derive identically. `--check` is green here.
* **#421 changed `witch_hollow` / `ruin_surface` locked_toasts and
  `world.gd`.** I own none of those strings. Audited every script this
  lane touched for waits on that prose:
  ```
  enchanter_work_room / invrisil_walkthrough / hedault_enchant_loop /
  hedault_fragment_loop / invrisil_setting_skill / invrisil_setting_talk /
  invrisil_v016_gate_check   -> 0 hits
  steel_thread (10 hits)     -> all map/cell TOLERANT legs + screenshot
                                names + one _comment; NO prose waits
  spine_reach (2 hits)       -> both are `"map": "witch_hollow"` teleport
                                keys; NO prose waits
  ```
  **No lane leg waits on a #421-changed string**, so nothing here is at
  risk from that merge. My 239/239 green is against BASE prose; the
  composed tree re-runs them, which is the controller's seam.
* No `world.gd` / `src/**` overlap: this lane still edits zero `src/**`.

## T7. Remaining, explicitly NOT done

* **Windowed eyes on the two new interiors.** They ship with no
  `floor_layers` (biome default) and reuse `temper_bench` / `price_board`
  / `chest`. `steel_thread`'s new plate and `invrisil_walkthrough`'s three
  new screenshots are the album/eye-gate surfaces for it, but both were
  run HEADLESS (no PNGs written). Four VISUAL-LOG rows are filed; a
  windowed `steel_thread` or `invrisil_walkthrough windowed` at
  composed-merge is the natural place to look.
* **The bespoke [Pick Lock] icon** (controller art call, VISUAL-LOG).
* **`hedaults_wardstone` re-point** (balance-touching, controller call).
* **The pre-existing doc-drift and the 12 stale maps-voice baselines**
  (§5) — both flagged, neither laundered.
