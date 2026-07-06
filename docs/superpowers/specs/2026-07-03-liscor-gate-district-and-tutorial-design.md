# Liscor Gate District + Relc Combat Tutorial — Design Document

**Consultant deliverable #2, 2026-07-03.** Per brief
`docs/superpowers/specs/2026-07-03-consultant-brief-2-liscor-and-tutorial.md`.
Design + data only; nothing committed by the consultant. All new atlas
coordinates are starting picks pending controller screenshot verification
(flag tables in §D1-5 and §D2-7).

**Integration adjudications honored** (from the Floodplains integration):
POI-B fishing anchor is **(13,18)** (my (12,18) was inside the pond blocking
row); the pond water cap is **[1,7]** on `Water_tiles.png` (controller
re-pick); walls-v2 **per-segment sheet overrides are confirmed working** — the
pond design stands, and I reuse the confirmed override mechanism nowhere new
in this deliverable (the gate district walls are all castle-sheet, top-level).

**Sequencing note (applies to both deliverables):** everything below assumes
the door-retarget quiet window — `inn_door`/`street_door` flip to the
floodplains per the accepted Floodplains §2.5, making the floodplains
reachable. D1's encounter migration and D2's tutorial both live on that
route; they should land in the same QA re-path window so the ~10 affected
scripts are rewritten once, not twice.

---
---

# DELIVERABLE 1 — Liscor gate district (street → 32×20 world map)

**Grid: 32×20 at CELL=16** (512×320 px vs the 320×180 view — camera
clamp-follows both axes, world environment). Coordinate frame: x 0–31
west→east, y 0–19 north→south. The map keeps id `street` and biome `street`
(save-compat, no biome edits needed — dirt_01 floor + skirt already read as
packed-earth city ground; the skirt now implies "more Liscor" past every open
edge).

## D1-1. Composition overview

**Zone A — West gate plaza (x1–8, y1–6).** The preserved 10×6 street,
re-dressed. `street_door` stays at **(0,3)**, now "To the Floodplains" —
the gate through the west wall. The old x=5 crate/barrel barricade goes
(it existed to funnel the ambush; the goblins are leaving). The plaza gets
a distinct cobble slab (the goblin_ambush arena's *verified* cobble
neighborhood `[16,2]/[17,2]/[18,2]`), a brazier, gate clutter, and a Watch
guard at the gate — first proof the player is inside a garrisoned city.

**Zone B — Main street (y2–4, x0→31).** The existing cobble band pick
(`[17,1]/[18,1]`) extended east the full map width: gate → market → Watch
post → Adventurer's Guild. Row y4 stays obstacle-free end-to-end (the QA
transit lane). P4 straight-seam mitigation: the south edge of the band gets
a broken jitter line of single cobble cells at y5 — a paved street may be
straight, its wear-edge shouldn't be.

**Zone C — Market row (x10–19, y1).** Stalls backed against the north wall:
Library-pack desks/shelving as stall counters (per the catalog's
Selys-counter note) dressed with the proven food props, barrels and crates
between stalls. All stall cells are blocked (you don't walk through a
counter). One stall is an interactable prop entity: **Krshia's Stall**
(canon Gnoll [Shopkeeper]; Erin's epilogue line already name-drops her — no
NPC sprite exists for Gnolls, so the stall carries the name until one does).

**Zone D — Watch post (x21–24, y1–2).** A blocked building footprint with
roof-slab + facade composite (inn_roof/facade_plaster recipe from the
Floodplains inn). A Watch guardsman NPC stands post at (22,3) — **Royal
Crew Soldier sprite, flagged non-canon race** (canon Watch is Drakes/Gnolls;
same placeholder convention as Relc).

**Zone E — Adventurer's Guild (x26–30, y1–3) — the map's XL anchor.** The
widest facade on the street: double roof composite + forecourt slab. The
guild **door is a prop, not a door entity** — `door` entities require a
live `to_map`, and no interior exists yet; a prop with display name
"Adventurer's Guild" + a turn-away toast is the honest future-interior
anchor (flag #8). **Selys relocates here**: cell (26,4), behind a
Library-desk counter at (26,3), conversation `selys_delivery` unchanged —
her "Guild's closed for lunch" line finally makes literal sense.

**Zone F — South district (y6–19).** A dirt side street (x14–15) branches
south off the main street to the map edge — deliberately *unpaved*
(P1 material storytelling: the crown pavement is the gate road; alleys are
dirt). Four house footprints (roof+facade composites), a small cobble
square where the side street widens (x12–16, y10–12) with a brazier, and a
**sewer grate prop** at (16,11) — Liscor's sewers are canon (Skinner arc);
this is the POI anchor for a future sewer map, mirroring the Floodplains
POI convention. Skirt-margin facades on the south and east edges imply the
city continuing.

**Walls.** The castle-sheet wall band flips role per the brief: segments
frame the **north edge interior-side** (full y=0 run, cap+face — the same
`[2,11]`/`[2,13]` picks as the Floodplains south wall, which is this wall's
far side: material continuity for free) and the **west edge** (cap-only
vertical runs with the single-cell gate gap at y=3). East and south stay
open — the city continues off-map.

**Encounters: all three migrate OUT to the Floodplains POI anchors** (§D1-3).
The gate district ships with zero combat — inside the walls is safe, canon.

## D1-2. Data

### D1-2.1 `sprites.json` — new entries

```json
"library_desk": {
 "render_scale": 0.5,
 "animations": { "idle": {
  "sheet": "res://assets/tiles/library/Tiles.png",
  "region": [96, 272, 48, 32], "frame_size": [48, 32], "fps": 1 } },
 "shadow": true
},
"library_shelf": {
 "render_scale": 0.5,
 "animations": { "idle": {
  "sheet": "res://assets/tiles/library/Tiles.png",
  "region": [208, 144, 32, 48], "frame_size": [32, 48], "fps": 1 } },
 "shadow": true
},
"royal_soldier": {
 "animations": { "idle": {
  "sheet": "res://assets/sprites/royal_soldier/Idle-Sheet.png",
  "frame_size": [64, 64], "fps": 4 } }
},
"sewer_grate": {
 "render_scale": 0.6,
 "animations": { "idle": {
  "sheet": "res://assets/props/sewer/Props.png",
  "region": [64, 192, 32, 32], "frame_size": [32, 32], "fps": 1 } }
}
```

Notes: `library_desk`/`library_shelf`/`sewer_grate` regions are guesses on
never-opened sheets — flags #1/#2. `royal_soldier` is a single-facing
battler used as a *stationary field NPC* for the first time (no walk anim,
idle only, mirror via `facing`) — flag #3. D2 adds `a_hunter` and
`training_dummy` (§D2-3).

### D1-2.2 Asset sync additions (`tools/sync_assets.py` manifest)

| dest | source |
|---|---|
| `assets/tiles/library/Tiles.png` | `Pixel Crawler - Library/.../Assets/Tiles.png` (400×400) |
| `assets/sprites/royal_soldier/Idle-Sheet.png` | `Pixel Crawler - Castle Environment 0.3/.../Enemies/Royal Crew/Soldier/Idle-Sheet.png` (256×64, 4f) |
| `assets/props/sewer/Props.png` | `Pixel Crawler - Sewer/.../Assets/Props.png` (176×256) |
| `assets/sprites/a_hunter/Idle_{Down,Side,Up}-Sheet.png` | Cemetery `A_Hunter/Idle_Base/` (256×64, 4f each) — D2 |
| `assets/sprites/a_hunter/Run_{Down,Side,Up}-Sheet.png` | Cemetery `A_Hunter/Run_Base/` (384×64, 6f each) — D2 |

Everything else (Furniture.png for the training dummy, castle Tiles.png,
floor_tiles_12, Vegetation, Rocks) is already synced. Plus LICENSES
sidecars per pack convention.

### D1-2.3 `skeleton_scene.json` → `maps.street` — the complete replacement block

```json
"street": {
 "biome": "street",
 "grid": { "width": 32, "height": 20 },
 "_comment": "Liscor gate district (consultant design 2026-07-03, grown from the 10x6 street per accepted Floodplains sec.5). Zones: gate plaza W, main street y2-4, market row y1 x10-19, Watch post x21-24, Adventurer's Guild x26-30 (XL anchor), dirt side street x14-15 south, sewer-grate POI (16,11). All goblin encounters migrated to floodplains POI anchors. Row y4 is the clear transit lane.",
 "blocked": [
  [10, 1], [11, 1], [12, 1], [13, 1], [14, 1], [15, 1], [16, 1], [17, 1], [18, 1],
  [21, 1], [22, 1], [23, 1], [24, 1],
  [21, 2], [22, 2], [23, 2], [24, 2],
  [26, 1], [27, 1], [28, 1], [29, 1], [30, 1],
  [26, 2], [27, 2], [28, 2], [29, 2], [30, 2],
  [26, 3],
  [9, 8], [10, 8], [11, 8], [12, 8],
  [9, 9], [10, 9], [11, 9], [12, 9],
  [18, 8], [19, 8], [20, 8],
  [18, 9], [19, 9], [20, 9],
  [11, 14], [12, 14], [13, 14],
  [11, 15], [12, 15], [13, 15],
  [18, 15], [19, 15], [20, 15], [21, 15],
  [18, 16], [19, 16], [20, 16], [21, 16]
 ],
 "floor_layers": [
  {
   "_pick": "Main street cobble band, full width (existing street pick, extended)",
   "sheet": "res://assets/tiles/free_pack/Floors_Tiles.png",
   "tile_px": 16,
   "variants": [[17, 1], [18, 1]],
   "cells": { "rect": [0, 2, 32, 3] }
  },
  {
   "_pick": "Gate plaza slab: the goblin_ambush arena's VERIFIED cobble neighborhood, distinct tone from the street band",
   "sheet": "res://assets/tiles/free_pack/Floors_Tiles.png",
   "tile_px": 16,
   "variants": [[16, 2], [17, 2], [18, 2]],
   "cells": { "rect": [1, 1, 8, 5] }
  },
  {
   "_pick": "Guild forecourt slab, same verified neighborhood",
   "sheet": "res://assets/tiles/free_pack/Floors_Tiles.png",
   "tile_px": 16,
   "variants": [[16, 2], [17, 2], [18, 2]],
   "cells": { "rect": [24, 1, 8, 5] }
  },
  {
   "_pick": "P4 wear-edge jitter: broken cobble cells along the band's south lip",
   "sheet": "res://assets/tiles/free_pack/Floors_Tiles.png",
   "tile_px": 16,
   "variants": [[17, 1]],
   "cells": { "list": [[9, 5], [11, 5], [12, 5], [16, 5], [19, 5], [21, 5], [23, 5], [10, 1], [19, 1]] }
  },
  {
   "_pick": "South-district square where the side street widens",
   "sheet": "res://assets/tiles/free_pack/Floors_Tiles.png",
   "tile_px": 16,
   "variants": [[16, 2], [17, 2]],
   "cells": { "rect": [12, 10, 5, 3] }
  }
 ],
 "_comment_walls": "City wall interior-side: full north run (cap+face, same castle picks as the floodplains south wall -- it IS that wall's inside face) + west runs with the gate gap at y=3. Cap-only on verticals, matching the inn's side-wall precedent. East/south edges open: Liscor continues off-map.",
 "walls": {
  "sheet": "res://assets/tiles/castle/Tiles.png",
  "tile_px": 16,
  "segments": [
   { "from": [0, 0], "to": [31, 0], "cap": [2, 11], "face": [2, 13] },
   { "from": [0, 1], "to": [0, 2], "cap": [2, 11] },
   { "from": [0, 4], "to": [0, 19], "cap": [2, 11] }
  ]
 },
 "decor": [
  { "sprite": "campfire", "cell": [3, 5] },
  { "sprite": "crate", "cell": [1, 5] },
  { "sprite": "barrel", "cell": [2, 1] },
  { "sprite": "crate", "cell": [7, 1] },
  { "sprite": "library_desk", "cell": [10, 1] },
  { "sprite": "library_desk", "cell": [11, 1] },
  { "sprite": "library_shelf", "cell": [12, 1] },
  { "sprite": "barrel", "cell": [13, 1] },
  { "sprite": "library_desk", "cell": [14, 1] },
  { "sprite": "library_desk", "cell": [15, 1] },
  { "sprite": "library_shelf", "cell": [16, 1] },
  { "sprite": "crate", "cell": [17, 1] },
  { "sprite": "library_desk", "cell": [18, 1] },
  { "sprite": "food_basket", "cell": [10, 1] },
  { "sprite": "food_bread", "cell": [14, 1] },
  { "sprite": "food_ham", "cell": [15, 1] },
  { "sprite": "food_basket", "cell": [18, 1] },
  { "sprite": "inn_roof", "cell": [22, 1] },
  { "sprite": "facade_plaster", "cell": [22, 2] },
  { "sprite": "inn_roof", "cell": [27, 1] },
  { "sprite": "inn_roof", "cell": [29, 1] },
  { "sprite": "facade_plaster", "cell": [27, 2] },
  { "sprite": "facade_plaster", "cell": [29, 2] },
  { "sprite": "library_desk", "cell": [26, 3] },
  { "sprite": "inn_roof", "cell": [10, 8] },
  { "sprite": "facade_plaster", "cell": [10, 9] },
  { "sprite": "inn_roof", "cell": [19, 8] },
  { "sprite": "facade_plaster", "cell": [19, 9] },
  { "sprite": "inn_roof", "cell": [12, 14] },
  { "sprite": "facade_plaster", "cell": [12, 15] },
  { "sprite": "inn_roof", "cell": [19, 15] },
  { "sprite": "inn_roof", "cell": [21, 15] },
  { "sprite": "facade_plaster", "cell": [20, 16] },
  { "sprite": "campfire", "cell": [13, 10] },
  { "sprite": "sconce", "cell": [14, 7] },
  { "sprite": "sconce", "cell": [15, 12] },
  { "sprite": "sconce", "cell": [14, 17] },
  { "sprite": "tree_round", "cell": [23, 12] },
  { "sprite": "tree_round", "cell": [6, 13] },
  { "sprite": "crate", "cell": [5, 10] },
  { "sprite": "barrel", "cell": [6, 10] },
  { "sprite": "crate", "cell": [25, 8] },
  { "sprite": "barrel", "cell": [8, 17] },
  { "sprite": "crate", "cell": [24, 18] },
  { "sprite": "boulder", "cell": [3, 16] },
  { "sprite": "facade_plaster", "cell": [6, 20] },
  { "sprite": "facade_plaster", "cell": [15, 20] },
  { "sprite": "facade_plaster", "cell": [24, 20] },
  { "sprite": "facade_plaster", "cell": [32, 7] },
  { "sprite": "facade_plaster", "cell": [32, 14] }
 ],
 "scatter": [
  { "pool": ["grass_tuft", "pebble", "flower_tiny"], "density": 0.06, "cluster": 0.7, "seed": 5 },
  { "pool": ["flower_purple"], "density": 0.012, "cluster": 0.9, "seed": 11 }
 ],
 "entities": [
  {
   "id": "street_door",
   "kind": "door",
   "cell": [0, 3],
   "display_name": "To the Floodplains",
   "sprite": "door",
   "to_map": "floodplains",
   "to_cell": [31, 24]
  },
  {
   "id": "gate_guard",
   "kind": "npc",
   "cell": [1, 5],
   "display_name": "Watch Guard",
   "sprite": "royal_soldier",
   "facing": "up",
   "dialogue": [
    { "speaker": "Watch Guard", "text": "Keep the gate clear. And if you're headed out — the road's got goblins on it lately. Watch knows. Watch is dealing with it." }
   ]
  },
  {
   "id": "watch_guard",
   "kind": "npc",
   "cell": [22, 3],
   "display_name": "Watch Guard",
   "sprite": "royal_soldier",
   "facing": "down",
   "dialogue": [
    { "speaker": "Watch Guard", "text": "Watch post. Lost property, complaints, goblin sightings. In that order of how much I care." }
   ]
  },
  {
   "id": "krshia_stall",
   "kind": "prop",
   "cell": [14, 2],
   "display_name": "Krshia's Stall",
   "sprite": "food_basket",
   "on_interact_accomplishment": "browsed_market",
   "toast": "Silverfang goods, honest prices. The Gnoll shopkeeper is off haggling elsewhere — a sign says she remembers faces, and debts."
  },
  {
   "id": "guild_door",
   "kind": "prop",
   "cell": [28, 3],
   "display_name": "Adventurer's Guild",
   "sprite": "door",
   "on_interact_accomplishment": "visited_guild",
   "toast": "The Guild hall is packed with adventurers arguing over a bounty board. Selys handles the counter work outside today."
  },
  {
   "id": "selys",
   "kind": "npc",
   "cell": [26, 4],
   "display_name": "Selys",
   "sprite": "citizen_f",
   "tint": [0.45, 1.0, 0.55],
   "facing": "up",
   "conversation": "selys_delivery",
   "dialogue": [
    { "speaker": "Selys", "text": "Adventurers. Always tracking mud in." }
   ]
  },
  {
   "id": "sewer_grate",
   "kind": "prop",
   "cell": [16, 11],
   "display_name": "Sewer Grate",
   "sprite": "sewer_grate",
   "on_interact_accomplishment": "heard_the_sewers",
   "toast": "A heavy iron grate, rusted shut. Cold air rises from below, and something in the dark skitters away from your shadow."
  }
 ]
}
```

Consistency check: no blocked cell coincides with a door, NPC, or prop
entity (`selys` (26,4) sits south of her blocked desk (26,3); `guild_door`
(28,3) and `krshia_stall` (14,2) are on walkable street cells and read as
bump-to-interact obstacles, same as the inn's dirty_table). Row y4 is
walkable x0→31; the side street x14–15 is walkable y5→19; the square and
all house perimeters connect. Wall segments never touch the (0,3) gate.
Krshia's stall reuses `food_basket` as its marker sprite deliberately (a
distinct goods-pile pick from Library/Furniture is a nice-to-have — flag #7).

### D1-2.4 Music (optional, one-line)

Catalog casting has xDeviruchi **"Shop"** (2:52 loop) earmarked for the
Liscor market — if map-scoped music is cheap in `audio.json`, the gate
district is its home. Not load-bearing; skip if audio data doesn't already
support per-map tracks.

## D1-3. Encounter migration (street → floodplains)

All three street encounters move to the Floodplains POI anchors — goblins
inside the walls never made canon sense. Entity records are byte-identical
except `cell` (and one conversation text tweak); arenas, rosters, seeds,
and `on_victory` lists are untouched, so combat determinism is unaffected
*provided the roster is unchanged* (see the met_relc caveat in D1-4).

| encounter | old (street) | new (floodplains) | anchor | notes |
|---|---|---|---|---|
| `goblin_encounter_1` (Goblin Ambush) | (8,5) | **(21,12)** | POI-A road trouble | The widened shoulder built for exactly this. Move the existing `crate` decor (21,12)→(20,12) so the entity cell is clean. |
| `goblin_encounter_2` (Goblin Warband + `goblin_parley`) | (5,3) | **(28,18)** | road seg 3 (gate approach) | Sits ON the road bend, so it blocks the direct lane exactly as it blocked the old street gap — parley/fight/detour-through-grass are all live options. Conversation field migrates with the entity unchanged. |
| `chieftains_raid` (Chieftain's Raid) | (2,0) | **(31,7)** | POI-C ruin stones | The chieftain lairs at the ruin-stones outcrop; `cave_mouth` arena now reads as the stones' hollow. Victory removes the entity, freeing the anchor for the future Ruins content. |

`goblin_parley` text tweak (one word, canon sense): hub node "The goblins
fan out across the **street**" → "across the **road**". `street_cleared`
keeps its id (save/QA compat) — add a `_comment` in the entity noting the
semantic is now "road to the gate cleared".

Erin's errand line "Selys is out the door, past the... goblin situation"
becomes *literally true* on the new route (inn → goblin road → gate →
Selys) — no dialogue edit needed there.

Floodplains map edits summary: +3 encounter entities at the cells above,
+`relc` npc and +`relc_spar` encounter (D2, §D2-2), crate decor moved
(21,12)→(20,12), doors already retargeted per the accepted §2.5.

## D1-4. Transition graph + QA re-path map

```
inn (15,3)          ──> floodplains (7,6)
floodplains (7,5)   ──> inn (14,3)
floodplains (31,25) ──> street (1,3)    [arrive on the plaza, east of the gate]
street (0,3)        ──> floodplains (31,24)
```

Unchanged from the accepted Floodplains graph — the gate district grows
around the existing arrival cell (1,3), which stays adjacent-not-on the
door per the anti-retrigger convention.

**QA re-path map (project-side).** Two independent invalidation sources
land here: (a) route changes (floodplains transit + Selys at (26,4)), and
(b) **roster changes** once §6 met_relc gating is wired — any script that
fights with `relc` in `allies` must MEET RELC FIRST or the roster (hence
the whole fight trajectory) changes and canonical seeds break.

| script | route change | roster/seed risk |
|---|---|---|
| `load_gate`, `title_flow`, `title_peek` | none | none |
| `inn_walkthrough` | only if it exits the inn | none |
| `dialogue_walkthrough`, `save_load_roundtrip` | inn→floodplains→gate→street; Selys now (26,4) via y4 lane | none (no combat) |
| `quest_errand_parley` | same + warband now at floodplains (28,18) *on the way* — parley happens mid-route, which is better staging than before | fight not taken |
| `quest_errand_fight` | same; draw-steel path fights at (28,18) | **meet Relc first** or re-search seed |
| `combat_walkthrough` (9) | goblin_encounter_1 now floodplains (21,12) | **meet Relc first**, then seed 9 should hold (same roster/arena/seed) — re-verify |
| `level_up_loop` (11) | fight 2 `chieftains_raid` now (31,7) | **meet Relc first**; re-verify 11 |
| `defeat_reload` (1) | chieftains_raid at (31,7) | **meet Relc first**; the seed-1 loss should hold (identical fight), re-verify |
| `line_of_sight_denial` (9) | goblin_ambush encounter re-path | meet Relc first; re-verify |
| `combat_move_input` (9) | warband at (28,18) — route is now inn→floodplains only (shorter) | meet Relc first; cells in the script are arena cells, unchanged |
| `street_peek` | re-frame for 32×20 (peek cells) | none |
| `floodplains_peek` | can retire once floodplains is walkably reachable | none |

**New QA script (D1):** `gate_district_walkthrough` — enter from the
floodplains gate, assert `ui_map_rendered` (32×20 payload), walk the y4
lane end to end, interact with `krshia_stall` + `guild_door` +
`sewer_grate` (assert the three toasts/accomplishments), talk to a Watch
guard (assert `dialogue_line` + the non-canon-race stand-ins render), talk
to Selys at (26,4) (assert `ui_dialogue_shown`), windowed variant
screenshots: plaza, market row, Guild frontage, south square.

## D1-5. Uncertain picks — flag table (D1)

| # | Pick | Risk | Notes / fallback |
|---|---|---|---|
| 1 | `library/Tiles.png` desk `[96,272,48,32]` + shelf `[208,144,32,48]` | **HIGH — pure guesses.** 400×400 sheet never opened. | Screenshot the sheet grid first; any counter-ish and shelf-ish crop works. Fallback: `table_brown` + `shelf_bottles` (both proven) — the market survives without the Library pack. |
| 2 | `sewer/Props.png` grate `[64,192,32,32]` | **MED — guess** on a 176×256 props sheet. | Iterate on screenshot; fallback: `boulder` + display name carries the meaning. |
| 3 | `royal_soldier` battler-as-field-NPC | **MED — first single-facing battler used as a standing npc.** world.gd handling of non-directional npc sprites + `facing` mirror needs one look. | Fallback: `body_a` with a steel-blue tint. Race stand-in is non-canon (Watch = Drakes/Gnolls) — flagged, accepted convention. |
| 4 | Castle cap `[2,11]` / face `[2,13]` on the north wall | **MED.** Same picks as the floodplains wall (still unverified there); face orientation on a y=0 interior wall needs a look. | Cap-only fallback, per the inn side walls. |
| 5 | Plaza/forecourt cobble `[16,2]/[17,2]/[18,2]` | **LOW.** Verified in the goblin_ambush arena, but never against the `[17,1]/[18,1]` street band — the two-tone seam is the thing to eyeball. | Swap either neighborhood; same sheet family. |
| 6 | Roof/facade composites on Watch post, Guild, houses | **MED.** `inn_roof` region `[0,0,96,64]` was already flagged HIGH in the Floodplains doc and is reused ×8 here — verify ONCE there, this map inherits the fix. Multi-roof buildings (Guild x27+x29) may need spacing tweaks. | Iterate on the gate_district windowed pass. |
| 7 | Krshia's stall marker = `food_basket` | **LOW — deliberate reuse.** A distinct goods-pile crop would be better. | Upgrade when the Library/Furniture sheets get their screenshot pass. |
| 8 | Guild door as prop (not door entity) | **DECISION, not a pick.** `door` entities need a live `to_map`; pointing one at a nonexistent map is a crash/dead-end risk. Prop + toast is honest until the interior ships, then swap `kind` to `door`. | — |

---
---

# DELIVERABLE 2 — Combat tutorial (Relc, Floodplains road)

## D2-1. Design overview + constraint mapping

The tutorial hangs off the Relc road introduction (accepted Floodplains §6:
Relc npc at ~(12,13), `met_relc` accomplishment, roster gating). Relc —
Drake, Senior Guardsman, [Spearmaster] — drags two Watch **training
dummies** out of the gatehouse and coaches the player through one REAL
`WICombat` fight against them while heckling from the sideline.

| brief constraint | how it's met |
|---|---|
| (a) real WICombat fight | Real encounter entity `relc_spar` → arena `training_yard`, enemies are two real combatants with floor-tier stats. `trivial: true` on BOTH entity and arena (belt-and-braces; either alone suppresses the tally bank per `_bank_action_tally`). `"on_victory": []` — **critical**: the key's *default* is `won_combat`, an explicit empty list is what keeps the spar out of Fighter level math. |
| (b) teaches movement/Dash/hotbar/targeting/End Turn | Beat table §D2-5: arrows (beat 1–2), hotbar numbers + Attack on `1` (beat 2), Dash refill on `2` (beat 3–4), Tab/Enter targeting (beat 5), E to end turn (taught beat 6, confirmed beat 7). |
| (c) existing dialogue/toast systems only | Pre/post-fight teaching lives in the `relc_intro` conversation (existing dialogue system). In-fight lines ride the **existing combat prose feed** as `Relc:` lines, driven by a declarative `tutor_lines` block on the arena JSON — carried inertly by `arena_config.duplicate(true)` exactly like `decor`/`floor_layers` (proven passthrough contract), rendered by ~30 lines in `combat_screen.gd` that match bus events the screen already receives. No sim change, no new widget, no fake mode. §D2-4. |
| (d) skippable + repeatable | Declining in dialogue = nothing happens. Repeatable = re-talk to Relc. **Requires one 2-line sim change**: `persistent: true` entity flag honored in `resolve_combat` (today victory unconditionally removes the encounter AND records it in save-persisted `removed_entities` — repeatability is impossible without it). §D2-6. |
| (e) opaque-until-sleep | No meters, no XP/level words anywhere. The only progression reference is Relc's in-character line: practice "doesn't put anything in your bones — sleep does that." `on_victory` banks only `sparred_with_relc` (referenced by no class, no quest — exists purely for dialogue variants + QA assertions). |

**Defeat edge:** a spar loss follows the normal defeat rule (GAME_OVER →
auto-slot reload). With dummy damage floored at ~2 vs the PC's 32 HP, losing
requires ~16 unanswered hits — accepted as effectively unreachable rather
than special-cased (no new engine behavior).

## D2-2. Data — combatants, arena, entities

### `combatants.json` — additions

```json
{
 "id": "training_dummy_a",
 "display_name": "Training Dummy",
 "sprite": "training_dummy",
 "side": "enemy",
 "stats": { "str": 2, "dex": 2, "con": 1, "int": 1, "wis": 1, "cha": 1 },
 "weapon_die": 1,
 "ai": "melee",
 "skills": []
},
{
 "id": "training_dummy_b",
 "display_name": "Training Dummy",
 "sprite": "training_dummy",
 "side": "enemy",
 "stats": { "str": 2, "dex": 2, "con": 1, "int": 1, "wis": 1, "cha": 1 },
 "weapon_die": 1,
 "ai": "melee",
 "skills": []
}
```

Two distinct ids because `WICombat.combatants` is keyed by id — duplicate
ids in an `enemies` list would collide. Derived numbers: max_hp = 21 (2–3
PC hits each — enough turns for every beat, short enough to stay a
tutorial); damage vs PC = max(1, 1 + d1) = 2 (harmless but *real* — the
dummies fight back, which teaches better than target practice); dex 2 →
they act last (PC always opens — flag #5 on the initiative formula).
`ai: "melee"` means the dummies waddle toward you — Relc's dialogue hangs
a lampshade on the wheels. Two enemies is the minimum for Tab-cycling to
mean anything (beat 5).

### `arenas.json` — new arena

```json
{
 "id": "training_yard",
 "biome": "floodplains",
 "trivial": true,
 "grid": { "width": 12, "height": 8 },
 "blocked": [],
 "player_spawns": [[2, 3], [2, 4], [1, 3], [1, 4]],
 "enemy_spawns": [[7, 3], [7, 4], [8, 3], [8, 4]],
 "_comment_dressing": "Roadside practice ground: open grass, dressing outside the 12x8 grid per the standing rule. Enemy spawns are Chebyshev 5 from the player spawn ON PURPOSE: 3 free steps exhaust the pool short of contact (beat 3), Dash covers the rest with AP to spare for one attack -- the full teaching arc fits in turn 1.",
 "floor_layers": [
  {
   "_pick": "trampled practice-ground patch, whole-image tile",
   "sheet": "res://assets/tiles/floor_tiles_12/transition_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [5, 2, 4, 4] }
  }
 ],
 "decor": [
  { "sprite": "crate", "cell": [-1, 3] },
  { "sprite": "barrel", "cell": [-1, 5] },
  { "sprite": "training_dummy", "cell": [12, 2] },
  { "sprite": "boulder", "cell": [12, 6] }
 ],
 "tutor_lines": [ "...see D2-4/D2-5 for the full block..." ]
}
```

Empty `blocked` is deliberate: no walls, no LoS puzzles — nothing between
the player and the five inputs being taught.

### `skeleton_scene.json` → `maps.floodplains.entities` — additions

```json
{
 "id": "relc",
 "kind": "npc",
 "cell": [12, 13],
 "display_name": "Relc",
 "sprite": "a_hunter",
 "tint": [0.6, 1.0, 0.6],
 "facing": "left",
 "conversation": "relc_intro",
 "dialogue": [
  { "speaker": "Relc", "text": "Road's watched. You're welcome." }
 ]
},
{
 "id": "relc_spar",
 "kind": "encounter",
 "cell": [13, 12],
 "display_name": "Training Dummies",
 "sprite": "training_dummy",
 "arena": "training_yard",
 "enemies": ["training_dummy_a", "training_dummy_b"],
 "allies": [],
 "trivial": true,
 "persistent": true,
 "on_victory": ["sparred_with_relc"],
 "conversation": "dummies_note",
 "_comment": "Tutorial spar. persistent:true (new flag, D2-6) so victory does not remove it -- repeatable via Relc. conversation gate means bumping the dummies directly never starts the fight; only Relc's dialogue does. on_victory MUST stay [\"sparred_with_relc\"] only -- the key's absence would default to won_combat and leak progression."
}
```

Relc on the road at (12,13) per accepted §6 (before POI-A, so the meeting
precedes any road trouble); dummies visible beside him at (13,12), one cell
off the road. `allies: []` — Relc coaches, he doesn't steal kills. Sprite:
Cemetery `A_Hunter` green-tinted, the flagged non-canon Drake stand-in
(§6 decision; A_Hunter is the only other fully-directional character).

### `sprites.json` — additions

```json
"a_hunter": {
 "directional": true,
 "animations": {
  "idle": {
   "sheet_down": "res://assets/sprites/a_hunter/Idle_Down-Sheet.png",
   "sheet_side": "res://assets/sprites/a_hunter/Idle_Side-Sheet.png",
   "sheet_up": "res://assets/sprites/a_hunter/Idle_Up-Sheet.png",
   "frame_size": [64, 64], "fps": 6
  },
  "walk": {
   "sheet_down": "res://assets/sprites/a_hunter/Run_Down-Sheet.png",
   "sheet_side": "res://assets/sprites/a_hunter/Run_Side-Sheet.png",
   "sheet_up": "res://assets/sprites/a_hunter/Run_Up-Sheet.png",
   "frame_size": [64, 64], "fps": 8
  }
 }
},
"training_dummy": {
 "render_scale": 0.45,
 "animations": { "idle": {
  "sheet": "res://assets/props/free_pack/Furniture.png",
  "region": [640, 448, 32, 48], "frame_size": [32, 48], "fps": 1 } },
 "shadow": true
}
```

A_Hunter ships no Walk sheets — `walk` maps the Run sheets (fps-tamed).
The dummy is the Furniture.png **armor stand** (catalog-confirmed to exist
on that sheet; region is a guess — flag #1).

## D2-3. `relc_intro` conversation graph (replaces the §6 stub)

`data/dialogue/relc_intro.json` — complete file. Honors every M4 dialogue
rule: accomplishment-keyed `requires` are hidden-until-met (progress never
leaks); no mixed accomplishment+skill keys in one `requires`; every node
with vanishing options keeps a fully ungated exit; `start_combat` only on a
conversation-ending option.

```json
{
 "start": "meet",
 "nodes": {
  "meet": {
   "speaker": "Relc",
   "text": "Oi. Hold up. Big spear, bored Drake, official business — that's me covered. You came off the inn hill. Name and errand.",
   "text_variants": [
    { "requires": { "accomplishment": { "met_relc": 1 } }, "text": "Hah — the inn's errand-runner. Road's been quiet since you passed. Mostly." }
   ],
   "options": [
    { "text": "Just a traveler. Staying at the inn, heading for Liscor.", "hide_when": { "accomplishment": { "met_relc": 1 } }, "effects": [ { "accomplishment": "met_relc" } ], "goto": "banter" },
    { "text": "What's out here worth guarding?", "requires": { "accomplishment": { "met_relc": 1 } }, "goto": "warns" },
    { "text": "Got time to show me how to fight? (Spar)", "requires": { "accomplishment": { "met_relc": 1 } }, "goto": "spar_offer" },
    { "text": "Keep walking.", "end": true }
   ]
  },
  "banter": {
   "speaker": "Relc",
   "text": "Relc. Senior Guardsman, best spear in Liscor, currently guarding grass. The inn feeds you, the city taxes you — everything between is my road, so behave on it. There's goblins about, if the walk gets boring.",
   "options": [
    { "text": "You any good with that spear? (Spar)", "goto": "spar_offer" },
    { "text": "I'll behave.", "end": true }
   ]
  },
  "warns": {
   "speaker": "Relc",
   "text": "Goblins on the road since the thaw — a warband near the gate with a chief who's got actual teeth. Old stones to the north-east? Stay off them. And if the pond looks deep, that's because it is.",
   "options": [
    { "text": "Good to know.", "goto": "meet" },
    { "text": "I'll manage.", "end": true }
   ]
  },
  "spar_offer": {
   "speaker": "Relc",
   "text": "Ha! Good instinct — everyone swings wrong until someone laughs at them. Watch keeps training dummies in the gatehouse; I drag a couple out when gate duty gets slow. Don't ask about the wheels. Rules are simple: you move, you hit, you don't cry.",
   "text_variants": [
    { "requires": { "accomplishment": { "sparred_with_relc": 1 } }, "text": "Again? Fine. The dummies heal fast — perk of being straw. Same rules: move, hit, no crying." }
   ],
   "options": [
    { "text": "Ready when you are.", "effects": [ { "start_combat": "relc_spar" } ], "end": true },
    { "text": "Another time.", "end": true }
   ]
  }
 }
}
```

Plus the tiny gate conversation on the dummies themselves,
`data/dialogue/dummies_note.json` (stops direct-bump fight starts):

```json
{
 "start": "note",
 "nodes": {
  "note": {
   "speaker": "Training Dummies",
   "text": "Two battered Watch training dummies on little wheels. One has a face painted on. It has seen things. Relc runs the drills — talk to him.",
   "options": [ { "text": "Leave them be.", "end": true } ]
  }
 }
}
```

Design note on the walk-away edge: picking "Keep walking." on first contact
records nothing — `met_relc` means *properly introduced*, and a player who
snubs the Watch doesn't get Relc bleeding for them in fights. Canon-fine,
and it keeps the counter's meaning crisp for the roster gate.

## D2-4. In-fight teaching delivery — `tutor_lines` (data + one presentation hook)

Mechanism: the arena block carries a `tutor_lines` array (inert passthrough
through `arena_config.duplicate(true)`, like `decor`). `combat_screen.gd`
gets one small handler (~30 lines): on each domain event it already
receives, scan the active arena's `tutor_lines` for un-fired entries whose
trigger matches, push the line into the existing prose feed via
`_push_feed`-equivalent, mark fired, and emit
`ui_tutor_line_rendered {beat: id}` on the bus (standard `ui_*_rendered`
confirmation so QA can assert delivery, not just logic). Trigger schema
reuses TestDriver semantics on purpose — `event` + `payload_contains`
subset + optional `nth` (default 1: fire on first match):

```json
"tutor_lines": [
 { "id": "opening",    "on": { "event": "combat_started" },                                        "line": "Relc: Loose grip, dead stance — we'll fix both. Arrows move you. Three easy steps a turn, so use your legs before anything fancy." },
 { "id": "first_step", "on": { "event": "combatant_moved", "payload_contains": { "id": "pc" } },   "line": "Relc: That's walking. Now get next to one and press 1 — that's your arm. Numbers are your moves, remember them." },
 { "id": "pool_empty", "on": { "event": "combatant_moved", "payload_contains": { "id": "pc" }, "nth": 3 }, "line": "Relc: Steps run out, see? Slot 2 — [Dash]. Costs you wind, buys you stride." },
 { "id": "dash",       "on": { "event": "dashed", "payload_contains": { "id": "pc" } },            "line": "Relc: And the legs are back. Wind for stride — that trade wins fights." },
 { "id": "aim",        "on": { "event": "ui_targeting_shown" },                                    "line": "Relc: Tab swaps targets, Enter commits. A spear only argues with one thing at a time." },
 { "id": "first_blood","on": { "event": "attack_resolved", "payload_contains": { "id": "pc" } },   "line": "Relc: Ha! Straw everywhere. When you're spent, press E — end your turn on YOUR terms." },
 { "id": "watch",      "on": { "event": "turn_ended", "payload_contains": { "id": "pc" } },        "line": "Relc: Turn's done. Now stand there and watch what comes back at you. That's half of fighting." },
 { "id": "wrap",       "on": { "event": "combat_finished", "payload_contains": { "victory": true } }, "line": "Relc: Not bad for someone who smells of dish soap. Forget the dummies — sleep is where a fight settles into your bones." }
]
```

Payload key caveats (flag #4): confirm the `attack_resolved` attacker key
name (`id` vs `attacker`) and the exact `combat_finished` victory payload
against `wi_combat.gd` before wiring the two filters; the schema above uses
the same names the QA scripts match today. Feed width: the feed label is
narrow/3-line — if a line wraps badly in the windowed pass, cut clauses,
never add UI (flag #6).

Why `nth: 3` for pool_empty instead of a state condition: pool exhaustion
isn't a bus event, and inventing a state-watcher would be a new mechanism.
The pool is 3; the third pc move IS pool-empty. Declarative, zero new
semantics. (If the player dashes before move 3, the dash/pool_empty lines
fire in whatever order the player earned them — reactive coaching, all
lines still land.)

Beat ordering note: lines are reactive, not sequential — a player who ends
turn before attacking gets "watch" before "first_blood". Every line is
written to stand alone; the E instruction is taught in `first_blood` and
merely *confirmed* in `watch`, and E also sits on the hotbar the player is
already reading.

## D2-5. Beat-by-beat script table (player action → Relc line)

| # | player action / game moment | channel | Relc line (beat id) |
|---|---|---|---|
| 0 | accepts "Ready when you are." | dialogue → combat | (spar_offer text sets rules: "you move, you hit, you don't cry") |
| 1 | fight opens, PC acts first (dummies dex 2) | feed | `opening` — arrows, three free steps |
| 2 | first arrow step | feed | `first_step` — hotbar numbers, `1` = Attack |
| 3 | third step, pool hits 0 | feed | `pool_empty` — `2` = [Dash], AP-for-pool trade |
| 4 | presses 2, pool refills | feed | `dash` — trade confirmed |
| 5 | presses 1 adjacent, targeting opens | feed | `aim` — Tab cycles, Enter commits |
| 6 | first attack lands | feed | `first_blood` — praise + teaches E |
| 7 | presses E, dummies shuffle up and bonk (~2 dmg) | feed | `watch` — enemy turns matter |
| 8 | second dummy drops, victory | feed | `wrap` — the sleep hint, nothing more |
| 9 | re-talks to Relc afterwards | dialogue | `spar_offer` variant: "Again? Fine. The dummies heal fast — perk of being straw." |

Opacity audit of every line above: no XP, no levels, no counters, no
meters, no "this banks nothing" meta — the only progression text is the
in-character sleep idiom (beats 8), which is exactly the canon voice the
constraint asks for.

## D2-6. The one sim change — `persistent` encounter flag

`resolve_combat` today, victory branch: banks on_victory + tally, then
`remove_entity(_pending_encounter)` unconditionally, and `removed_entities`
persists in saves. Requirement (d) (repeatable) is unimplementable as data
without this:

```gdscript
# wi_game.gd, resolve_combat(), victory branch — replace the remove line:
if not bool(entity.get("persistent", false)):
	remove_entity(_pending_encounter)
```

Mirrors `trivial` exactly: an entity-level data flag read at resolve time,
sim-pure, save-compatible (absent = today's behavior). Unit tests to add in
`test_sim_core.gd` beside the trivial-flag pair: (1) persistent encounter
survives victory (`find_entity` non-empty, `removed_entities` untouched,
`entity_removed` never emitted) and can `start_combat` again; (2)
non-persistent behavior unchanged.

## D2-7. Uncertain picks — flag table (D2)

| # | Pick | Risk | Notes / fallback |
|---|---|---|---|
| 1 | `training_dummy` region `[640,448,32,48]` on Furniture.png | **HIGH — guess.** Armor stands are catalog-confirmed on the sheet, coordinates are not. | One windowed iteration. Fallback: `crate` sprite, display name carries "Training Dummy". |
| 2 | `a_hunter` green tint `[0.6,1.0,0.6]` as Drake-Relc | **LOW-MED.** Tint mechanism proven (Lyonette/Selys); whether green-on-dark-hood reads "Drake-ish" needs one look. Non-canon race stand-in — flagged, accepted §6 convention. | Adjust tint; worst case untinted + display name. |
| 3 | Dummy stats → intended feel | **MED.** Derived numbers (21 HP, 2 dmg, PC-first initiative) computed from formulas read in `wi_combat.gd`, not simulated. Also confirm dex actually drives initiative order. | One seeded playthrough; tune con/str down further if the spar drags or stings. Do NOT run the balance harness gate on this fight — `trivial` fights are exempt from win-rate tuning by design intent. |
| 4 | `attack_resolved`/`combat_finished` payload key names in tutor triggers | **MED.** Trigger filters must match emitted payloads byte-for-byte (TestDriver-subset semantics). | Check the two `_emit` sites; rename keys in `tutor_lines` to match, not vice versa. |
| 5 | `tutor_lines` hook placement in `combat_screen.gd` | **LOW-MED.** Must hook the same path that feeds the prose feed so lines interleave correctly with the paced AI playback queue (capture-at-enqueue rule!) — tutor lines for AI-turn events must ride the queue, not fire live. | Player-turn beats (all of them except `watch`'s follow-on) fire during the player's own input, where the queue is idle — risk is contained to ordering polish. |
| 6 | Line lengths vs the 3-line feed label | **LOW.** | Windowed pass; cut words, never widen UI. |
| 7 | `browsed_market`/`visited_guild`/`heard_the_sewers`/`sparred_with_relc` counters | **LOW — deliberate inert counters** (no class/quest references), used for toasts, dialogue variants, QA assertions, and future content hooks. Confirm `test_content.gd` doesn't reject accomplishments nothing consumes. | Drop the accomplishment key and keep toast-only if the prop path supports it. |

## D2-8. QA script outline — `relc_tutorial` (headless, seed 9 candidate)

Canonical-seed candidate 9 pending verification (manual key-injected moves
diverge from autoplay trajectories — same caveat as `combat_move_input` —
but vs 21-HP dummies the win is seed-robust; verify once, pin the seed).

1. `wait_for_event world_ready`; walk inn → out the door → floodplains.
2. Walk to Relc (12,13) neighborhood; `press interact`.
3. **Skippable negative first:** choose intro option (`confirm`) → banter →
   spar_offer → select "Another time." → `assert_event_absent
   combat_started`; assert `met_relc` recorded
   (`accomplishment_recorded` payload_contains).
4. Re-interact; hub → spar_offer → "Ready when you are." →
   `wait_for_event combat_started` + `ui_combat_shown` +
   `ui_tutor_line_rendered {beat: opening}`.
5. Assert `combat.active == pc`; drive the beats with real keys, asserting
   each `ui_tutor_line_rendered` beat id in order earned: 3× `move_right`
   (first_step, pool_empty), `hotbar_2` (dash after `dashed`), moves to
   adjacency, `hotbar_1` → `ui_targeting_shown` (aim) → Tab/`confirm` →
   `attack_resolved` (first_blood), `end_turn` key (watch).
6. `combat_autoplay` to victory → `combat_finished` (wrap beat) +
   `combat_resolved {victory: true}`.
7. **Opacity + trivial assertions (the teeth):** `assert_state`
   `accomplishments.sparred_with_relc == 1`; `won_combat` **absent/0**;
   `melee_hit` **absent/0** (tally suppressed); no `class_level_up`/
   `class_gained` events logged.
8. **Repeatability:** assert `relc_spar` still present in the floodplains
   snapshot (no `entity_removed {id: relc_spar}` logged); re-talk to Relc →
   spar_offer variant → "Ready" → second `combat_started`. End mid-fight
   (combat_move_input precedent).
9. Windowed variant: screenshots at opening beat, targeting, wrap.

Related (project-side, from accepted §6, not this script): extend the
floodplains walkthrough to assert `met_relc`, and the roster-gate positive/
negative combat assertions (Relc fields only when `met_relc ≥ 1`).

---

*End of deliverable. Both parts are proposals for the controller session to
apply in the door-retarget quiet window, screenshot-verify (D1 flags #1/#4/#6
and D2 flag #1 first — they gate the market row, the wall band, and the
dummies), and QA re-path per §D1-4.*

---

## Controller adjudication (Opus, 2026-07-03)

**Verdict: ACCEPT for integration** in the door-retarget quiet window. Load-bearing
sim claims verified against source; canon/engine calls sound. Integration notes:

1. **[RECONCILE WITH T2 — the one substantive change] The `persistent` insertion (§D2-6)
   was written against pre-T2 `resolve_combat`.** T2 (ba57faa) added a `respawns`/dormant
   branch to the victory path (`wi_game.gd:424-428`). The design's 2-line replacement is
   now a **third case**, an `elif`:
   ```gdscript
   if bool(entity.get("respawns", false)):
       if not dormant_encounters.has(_pending_encounter):
           dormant_encounters.append(_pending_encounter)
   elif not bool(entity.get("persistent", false)):
       remove_entity(_pending_encounter)
   # persistent && !respawns -> stays live, immediately re-fightable (the spar)
   ```
   `persistent` and `respawns` are **distinct and both needed**: `respawns` = dormant
   until the next sleep re-arms it; `persistent` = never consumed, immediately
   re-fightable. The spar needs the latter (re-talk to Relc without sleeping). Do NOT
   collapse them. `start_combat`'s T2 dormant-refusal does not fire on persistent
   (non-dormant) encounters, so repeat spars start fine — verified.

2. **[DOC NIT] §D2-1(a) prose vs §D2-2 JSON disagree on `on_victory`.** §D2-1 says
   `on_victory: []`; the actual `relc_spar` entity in §D2-2 correctly uses
   `["sparred_with_relc"]`. **Use the §D2-2 version.** Verified at `wi_game.gd:417-419`:
   the key's default is `"won_combat"`, and an explicit non-empty list overrides it — so
   `["sparred_with_relc"]` banks the spar counter WITHOUT leaking `won_combat`. Both an
   empty list and a `sparred_with_relc`-only list suppress `won_combat`; the one-element
   list is strictly better (gives the dialogue/QA counter).

3. **Verified load-bearing claims:** (a) `on_victory` default = `won_combat` ✅
   (`wi_game.gd:417`); (b) `trivial` on entity OR arena suppresses the tally bank ✅
   (`wi_game.gd:443`, confirmed in the T2 review); (c) `persistent` slots into the victory
   branch cleanly per note 1.

4. **Correctly deferred to implementation, unchanged:** all atlas/region picks
   (D1 #1-7, D2 #1-2) — screenshot-verify per pack workflow; payload-key names in
   `tutor_lines` (D2 #4) — grep the `_emit` sites and match keys to source, not vice
   versa; initiative-uses-dex (D2 #5) — confirm against `wi_combat.gd` at wiring time.

5. **Sound calls accepted as-is:** encounters migrating out of the walls; guild-door-as-prop
   (no live `to_map`); `met_relc` roster gating; the §D1-4 QA re-path ("meet Relc first or
   canonical seeds break" — this is the F-task seed re-derivation and must land in the same
   window). Off-grid skirt decor (x=32, y=20) is intentional per the standing
   dressing-outside-grid rule.

**Sequencing:** this is a DESIGN doc. Before implementation it needs a writing-plans pass
(folded into the Floodplains door-retarget lane), then subagent-driven execution — user
directs the quiet-window timing.
