# PALLASS — art-lane handoff (to the post-Door wiring task, issue #16)

This lane delivered direction + assets + mockups ONLY. Nothing is
wired: `skeleton_scene.json`, `biomes.json`, `sprites.json`,
`moods.json` untouched (charter bounds). Everything below is staged
for the 8e execution lane.

## Asset locations

- **Owned (PixelLab, redistributable):**
  `potential_assets/pixellab_2026-07-07_pallass/` — 2 Wang tilesets
  (atlas + corner-map JSON each) + 7 props + `manifest.json`
  (prompt/params per file). These CAN be committed into `assets/`
  at wiring time (TIER-PUBLIC; add provenance line to
  `assets/LICENSES/pixellab-ai-generated-verdict.md`).
- **Licensed (bundle-tier):** region tables in `picks.md`; ONE new
  manifest entry needed (`assets/tiles/forge/Tiles.png`) + ignore-block
  regen (`scripts/gen_asset_ignores.sh`) + bundle release BEFORE any
  overlay ships (wi-shipping order).

## Staged biome fragments (values DRAFT — wire + windowed-verify)

The engine's `biomes.json` shape is `{sheet, tile_px, floor:[c,r],
blocked:[c,r]}` per biome — single-tile floor/blocked, no Wang
support today. Two wiring options, decide at plan time:

**Option A (no engine change):** consume the PixelLab atlases as
plain sheets — flat fills only, parapet edges become decor rows:

```json
{
  "pallass_market": {
    "sheet": "assets/tiles/pallass/slate_over_void_atlas.png",
    "tile_px": 16,
    "floor": [3, 3],
    "blocked": [0, 0],
    "_comment": "floor = all-upper Wang cell (see tileset_slate_over_void_meta.json ids 15/atlas cell [3,3]); blocked = all-lower void cell (id 0). DRAFT - confirm cells against the meta JSON + windowed screenshot; atlas cell indices here are corner-map lookups, not guesses, but the mandatory windowed check stands."
  },
  "pallass_forge": {
    "sheet": "assets/tiles/pallass/brick_over_molten_atlas.png",
    "tile_px": 16,
    "floor": [3, 3],
    "blocked": [0, 0],
    "_comment": "floor = all-upper dark brick; blocked = all-lower molten fill (lava blocks movement). Same DRAFT caveat."
  }
}
```

**Option B (the better read, small engine ask):** teach the tile
layer to place specific atlas cells per map cell (or pre-bake band
strips as decor images). The parapet edge tiles (mixed Wang corners)
are the tier-read's best pixels — Option A loses them except as
props. Flag to the 8e planner: the shelf grammar (direction.md) wants
edge tiles placeable; if the engine ask is too big for v1, pre-baked
edge-strip PROPS (long thin images laid along band edges) get the
same look with zero engine change.

## Sprite-entry drafts (sprites.json shapes, DRAFT scales)

| id | sheet (after commit into assets/) | native | render_scale | anchor | shadow | notes |
|---|---|---|---|---|---|---|
| `great_lift` | `prop_great_elevator.png` | 64×96 | 1.0 | `[0.5,1.0]` | true | landmark, ~4×6 cells; alpha bbox is tight (PIL-checked) so default anchor holds; interact cell = gate center |
| `crystal_lamp` | `prop_crystal_lamp.png` | 32×64 | 0.5 | `[0.5,1.0]` | true | place in ruler-straight rows; pair with STEADY white PointLight2D (`#E9EEF2`), never flicker |
| `steam_vent` | `prop_steam_vent.png` | 32×48 | 0.5 | `[0.5,1.0]` | false | add white GPUParticles steam emitter (ambience-layer pattern); the baked puff is fine at mockup only |
| `price_board` | `prop_price_board.png` | 48×48 | 0.5 | `[0.5,1.0]` | true | the anti-Invrisil posted-prices tell; observe-target candidate |
| `forge_station` | `prop_forge_station.png` | 48×64 | 0.6 | `[0.5,1.0]` | true | the forge-tier interactable ([Tactician]/[Engineer] observe content); anvil-read retry queued (pixellab-batch.md) |
| `market_stall_pallass` | `prop_market_stall.png` | 64×48 | 0.75 | `[0.5,1.0]` | true | place IDENTICAL stalls in rows — uniformity is the QUALIFY tell; do NOT reuse Liscor stall sprites |
| `tier_wall` | `prop_tier_wall.png` | 128×48 | 0.5–1.0 | `[0.5,1.0]` | false | rising-wall band at 0.5 (24px strip, mockup precedent); full scale = parapet/facade |

All DRAFT: the wi-art-and-sprites mandatory rule applies — windowed
QA screenshot before any entry is called done.

## Mood cards

DRAFT values in direction.md §mood-card (market: cool day-graded;
forge: time-invariant warm-dark). NOT wired.

## Open questions for the 8e planner/user

1. **Band-edge rendering** (Option A/B above) — the one engine
   decision this direction depends on.
2. **Slab brightness:** generated market slabs run lighter/bluer than
   the ratified slate row — mood tint may be enough; if not, ONE
   regen of `tileset_slate_over_void` with "dark slate" phrasing
   (~5 gens) fixes it at the source. User taste call.
3. **Two maps, one screen?** The mockup shows both bands in one
   320×180 frame for the taste read. In-game each tier is its own
   map; the composite read then lives in (a) each map carrying its
   own rising-wall + parapet zones (the shelf grammar) and (b) the
   lift transition. If the milestone wants the literal two-band
   screen (a "cross-section" vista moment at the lift), that's a
   single tall map with a mid-band void row — cheap and very
   Pallass; flag for the spec.
4. **Seed label:** bible "8f" vs GOAL-CHAIN "8e" (direction.md flag)
   — controller should reconcile the bible text at some boundary.

## Canon flags

- Forge tier ABOVE market tier (wiki: Blacksmith's Quarter floor 9,
  markets 1–3) — the composite and any tier-picker UI must not
  invert this. Liscor door lands on floor 8 (between the two — a
  gift for the arrival beat: you step out BETWEEN the tiers you'll
  traverse).
- Tier count: bible says nine, wiki reads 10+ — keep player-facing
  text vague ("the tiers", "floors of the machine"), never a total.
- Grand Lifts are canon-named ("Grand Lifts", eight counterweight
  platforms) — safe name through Vol 7 scope (structure described on
  the wiki's Pallass page, city established pre-cutoff); Runner-lane
  stairway discipline is canon and free flavor for lane-marking
  decals + signage copy.
- Population (Drakes, Gnolls, Dullahans, Garuda; Humans rare) — the
  race-variant dialogue seam is the 8e content lane's surface, not
  art's; noted so the extras batch doesn't ship Human-crowd sprites.
