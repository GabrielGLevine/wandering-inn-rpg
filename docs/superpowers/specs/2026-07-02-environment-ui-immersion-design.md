# Environment & UI Immersion Design (Fable design spike)

**Mandate (user, 2026-07-02):** "Spend some real time on designing environments and the UI
to make them feel immersive and not merely functional." Timed to land INSIDE M5: Lane R4
and Lane H briefs implement from this doc; anything that doesn't fit M5 carries as the
M6-adjacent dressing backlog (§6). Authority for looks: controller screenshot review
against the reference images named here.

**North star image:** `Pixel Crawler - Free Pack/MockUps/Tavern_02.png` — the pack author's
own inn. Its immersion comes from four devices we currently lack, all data-expressible:
1. **Wall structure** — rooms have a tall top-wall band (stone/wainscot + hung decor), not
   floating obstacle blocks on an endless floor.
2. **Dense prop dressing** — tables with dishes, stools at the bar, sconces, plants,
   chests, rugs. Most props are non-blocking set dressing.
3. **Floor variation** — plank flooring with area rugs and room-to-room material changes,
   never one tile repeated wall-to-wall.
4. **Warm light accents** — sconce/chandelier sprites (animated fire frames exist in the
   Bonfire sheets) reading as light sources even without a lighting engine.

## 1. Schema (extends existing data patterns — no new architecture)

`skeleton_scene.json` maps (and `arenas.json`) gain:
- `"floor_layers"`: ordered list of `{coords: [x,y] | variants: [[x,y],...], cells: "all" | rect | list}`
  — floor variation + rugs as data. Variant lists pick per-cell via a POSITION-SEEDED hash
  (deterministic, save/QA-stable, no RNG stream touched).
- `"walls"`: `{band_rows: N, sheet, base_coords, top_coords}` — perimeter/top wall band
  rendered as 1-cell-deep structure (visual; blocking already comes from `blocked`).
- `"decor"`: list of `{sprite, cell, blocking: false}` — set-dressing props rendered via
  the existing sprite registry (region entries), Y-sorted with entities. Blocking props
  remain `entities` as today.
- Sim passthrough only: `WIGame` never reads these; world/combat renderers do (same
  pattern as `biome`).

## 2. The Wandering Inn (interior) — target composition

Trace Tavern_02's common room at our 10×6 grid scale:
- Floor: warm plank tiles (Floors_Tiles wood family) with a green/red rug variant under
  the table zone (rug tiles exist in Interior_Props/mockup sheets — locate exact coords at
  implementation with screenshot iteration).
- North wall band (row 0): stone-top + wainscot band; hang 2–3 decor pieces from
  Interior_Props (mounted weapons, trophy head, "menu" board near Erin).
- Dressing: bar counter segment + stools near Erin's post; 2 clothed tables (red + blue)
  with tankard/plate props; wall sconces ×2 (Bonfire small-flame animated frames as decor
  sprites); plant pots at the door; chest near the bed; window tiles on the south band.
- Existing interactables (Bed, Dirty Table, Dusty Scroll, door) stay blocking entities —
  restyle Dirty Table to a *clothed* table variant so "dirty" reads (plates/mess sprite).

## 3. Liscor street — target composition

Liscor is a stone Drake city (canon): cobble road (Floors_Tiles cobble family) with dirt
transition edges (topdown_floor_tiles_12 `transition/` set for road shoulders), building
facades as south/north wall bands (Castle pack `Assets/Tiles.png` stone + Buildings
walls/roofs from the free pack), market-stall dressing near Selys (crate/barrel/awning
props from Furniture/Interior sheets), lamp/sconce posts, occasional grass tufts
(floor_tiles_12 `grass/` variants) between cobbles. The two encounter markers keep chips
until E2 sprites; arena skirts reuse the same materials so combat feels in-place.
Goblin-huts pack reserved for M7 goblin-territory content (fits the raid-camp arena
dressing backlog).

## 4. Arenas

`goblin_ambush` (street biome): cobble center, dirt-transition edges, 1–2 crate/barrel
decor at the skirt rim. `cave_mouth`: cave floor + rock band skirt, mushroom decor
(cave pack has mushroom props) at edges. Dressing sits OUTSIDE spawn/walk cells —
readability of the tactical grid wins every conflict (decor never on playable cells).

## 5. UI chrome (Lane H implements; replaces "a Theme resource" with a designed kit)

Source: Tiny Swords `UI/` (user-attested licensed).
- **Dialogue panel + journal:** `Banners/Banner_Vertical.png`-family parchment as
  NinePatchRect (the scroll look fits TWI's bookish identity perfectly); dark-brown text
  on parchment; speaker name on a small ribbon header (`Ribbons/`).
- **Hotbar:** `Carved_9Slides.png` carved-wood slot frames; pressed/hover button states
  from `Buttons/` for the selected slot; keybind number badges top-left of each slot.
- **Title screen:** game name on a large ribbon banner over a dressed inn-interior
  backdrop (render the actual inn map behind the menu — cheap and diegetic); menu rows
  as Tiny Swords buttons (blue idle / hover / pressed).
- **Toasts:** small parchment strip, slide-in; **pause/settings:** carved panel.
- **Fonts:** parchment UI wants a warm serif-ish pixel font — shortlist m5x7 vs
  Pixel Operator at implementation (agent-sourced → real license check per memory rule);
  body text stays the readable default at native res if the pixel font hurts legibility
  (hybrid rule from the M5 spec stands).
- **HP/MP:** in-world bars stay minimal pixel bars; the hotbar strip carries the framed
  AP/MP readout so combat chrome lives in ONE place.

## 6. Fit into M5 vs carry

- **R4 brief absorbs §1–§4 structure**: floor_layers + walls + decor schema, inn/street
  compositions, arena skirts (supersedes the plan's bare "skirt tiles" — same lane, same
  files, richer data).
- **H1/H3 briefs absorb §5.**
- **Carry to backlog (M6-adjacent, not gating M5):** animated sconce flames if the decor
  sprite path can't do AnimatedSprite2D cheaply, goblin-camp dressing (M7 content),
  portrait busts, weather/ambience layers.
- Every composition gets controller screenshot iteration against Tavern_02 — "does this
  read as a place?" is the exit bar, not "tiles rendered".

## 7. Asset extraction additions (sync manifest)

Tiny Swords UI (Banners/Ribbons/Buttons/Carved), floor_tiles_12 (grass/dirt/transition),
Castle Assets/Tiles.png, Interior_Props_02/decor sheets as needed, Bonfire flame frames.
Curated-only as always; licenses user-attested.

## 8. E3 addendum (post-playtest REV, 2026-07-02 late) — environment art pass

User's mid-M5 playtest verdict: inn/street/arena still below bar. Bar = 6 Pixel Crawler
showcase scenes user attached (tavern interior, cabin+farm exterior, dark forest, garden,
sewer, forge dungeon). §2–4 described the right targets; the R4 execution missed on
three axes: **enclosure** (rooms read as rooms only when walled on all sides), **zoning**
(distinct functional areas — bar/kitchen/dining — not scattered props), and **density**
(tables carry food/plates; walls carry mounted decor; floors change material per zone).

### Engine additions (small, in `world.gd`)

- **`walls` v2 — `segments`:** keep the existing north band; add optional
  `"segments": [{"from":[x,y], "to":[x,y], "cap":[cx,cy], "face":[cx,cy], "sheet":..., "tile_px":...}]`.
  Each segment paints cap tile at each cell and face tile at the cell below (showcase
  walls are 2-tile: dark top cap + lit front face). All painted cells become blocked.
  Painted above floor, below entities — player can never overlap (blocked), so no
  Y-sort complexity. Enables perimeter walls on all 4 sides AND interior partitions.
- **Bigger grids where zones need room:** inn 10×6 → ~16×10 (camera already clamps/
  follows on maps larger than the 20×11 visible cells). Interactable/NPC positions in
  skeleton_scene.json re-placed accordingly.

### Asset extraction (after H1 lands — sync_assets.py manifest is H1's file until then)

From `Pixel Crawler - Free Pack 2.1` (supersedes old free pack where richer):
`Interior_Props_01`, `Furniture`, `Meat` (table food), `Tools`, `Esoteric`,
`Vegetation`, `Farm`, `Rocks`, `Trees/Model_01..03`, `Buildings/{Walls,Roofs,Shadows,Props}`,
`Wall_Variations`, `Water_tiles`, Furnace station sheets, animated `Pan_*` sheets.
From `Pixel Crawler - Cave`: `Assets/Props.png` (mushrooms, spore roots, rocks).
Curated regions only, as always.

### Per-scene REV targets

- **Inn:** full 4-side perimeter walls; interior partition splitting off a kitchen
  corner (furnace + pan station + shelf); bar zone (counter run + stools + Erin's post);
  dining zone (2–3 tables WITH food/tankard props, rug beneath); wall-mounted decor on
  north face (weapons/trophy/menu board); windows on south wall.
- **Street:** north edge = building facades with ROOFS + shadows (Buildings sheets),
  not bare wall band; fence runs + gate; market stall near Selys (crates/barrels/awning);
  trees (Model_02/03) + vegetation tufts; road keeps cobble w/ dirt shoulders.
- **Cave arena + street arena:** cave = Cave-pack floor/wall re-pick + mushroom/spore
  props at skirt rim; street arena inherits street facade skirts. Decor never on
  playable cells (unchanged rule).

### Process + definition of done

Controller-executed (composition = design judgment; every region/scale pick gets a
windowed screenshot check — R4 history proves first-guess picks fail). Runs after H1
merge; H2 (input) can run in parallel ONLY after the world.gd walls-v2 commit lands
(file ownership: E3 owns data/*.json + world.gd walls renderer; H2 owns input paths).
DoD: windowed screenshots of inn/street/cave judged side-by-side against the user's
showcase bar; final verdict at next user playtest.
