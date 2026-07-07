# Invrisil art — handoff to the post-Door wiring task

What the integration pass (Magical Door pipeline owns it) needs from
this lane. Everything below is STAGED — no game data file was touched.

## Where the art is

- **OWNED (PixelLab, redistributable):**
  `potential_assets/pixellab_2026-07-07_invrisil/` — wang tileset
  (`tileset_marble_wang4x4.png` + `tileset_marble_meta.json`),
  `fountain_v2.png`, `streetlamp_v2.png`, `shop_sign_v2.png`,
  `guild_banner_v2.png`, plus `job_*.json` provenance. At wiring time
  these become REAL committed files (suggested:
  `assets/tiles/invrisil/` + `assets/sprites/invrisil/`), with a
  provenance note in `assets/LICENSES/pixellab-ai-generated-verdict.md`
  — they ship in the public repo, no manifest entries, no bundle.
- **LICENSED (manifest-only):** region tables in `picks.md`; two NEW
  manifest entries needed (`assets/tiles/hideout/Tiles.png`,
  `assets/props/sewer/Props.png`) + possibly `Farm.png` if the fence
  read passes. New licensed asset = manifest entry + ignore-block
  regen + bundle release FIRST (wi-shipping).
- **Mockups (taste-review surface, licensed-mixed → gitignored,
  NEVER commit):** `potential_assets/pixellab_2026-07-07_invrisil/
  mockups/mockup_licensed_invrisil_boulevard_320.png` + `_4x.png`.
  Compose scripts preserved in the session scratchpad (mockup5.py is
  the shipped iteration).

## Staged biome fragment (values, not a data file)

```jsonc
// biomes.json — DRAFT. The wang tileset is 4x4 tiles of 16px; the
// engine's biome shape takes single [col,row] picks: pure paving =
// wang id 0, pure marble = wang id 15 (positions per
// tileset_marble_meta.json tile order: id0 -> col 2 row 1;
// id15 -> col 0 row 3 in the assembled 4x4 sheet).
"invrisil_street": {
  "sheet": "res://assets/tiles/invrisil/tileset_marble_wang4x4.png",
  "tile_px": 16,
  "floor": [2, 1],              // wang id 0 — cool grey paving
  "blocked_sheet": "res://assets/tiles/free_pack/Wall_Tiles.png",
  "blocked": [8, 2],            // cool blue-grey stone (picks.md §2)
  "blocked_tile_px": 16,
  "skirt_sheet": "res://assets/tiles/invrisil/tileset_marble_wang4x4.png",
  "skirt_tile_px": 16,
  "skirt": [2, 1]
},
"invrisil_plaza": {             // if the plaza is its own map/layer;
  "sheet": "res://assets/tiles/invrisil/tileset_marble_wang4x4.png",
  "tile_px": 16,                // otherwise use floor_layers with the
  "floor": [0, 3],              // wang id 15 marble + curb tiles
  "blocked_sheet": "res://assets/tiles/free_pack/Wall_Tiles.png",
  "blocked": [8, 2],
  "blocked_tile_px": 16
}
```

```jsonc
// sprites.json — DRAFT owned-prop entries (anchors PIL-measured
// feet-plane, alpha-bbox method; windowed adjacency check still
// mandatory before done):
"plaza_fountain": {
  "render_scale": 0.6, "shadow": true, "anchor": [0.4938, 0.9583],
  "animations": { "idle": { "sheet": "res://assets/sprites/invrisil/fountain_v2.png",
    "frame_size": [80, 96], "fps": 1 } }
},
"street_lamp": {                // gold lamp — mood pass adds the warm
  "render_scale": 0.6, "shadow": true, "anchor": [0.5312, 0.9531],
  "animations": { "idle": { "sheet": "res://assets/sprites/invrisil/streetlamp_v2.png",
    "frame_size": [32, 64], "fps": 1 } }   // PointLight2D, NON-flicker
},
"coin_shop_sign": {
  "render_scale": 0.75, "anchor": [0.4688, 0.9375],
  "animations": { "idle": { "sheet": "res://assets/sprites/invrisil/shop_sign_v2.png",
    "frame_size": [32, 32], "fps": 1 } }
},
"guild_banner": {
  "render_scale": 0.5, "anchor": [0.5, 0.9688],
  "animations": { "idle": { "sheet": "res://assets/sprites/invrisil/guild_banner_v2.png",
    "frame_size": [32, 64], "fps": 1 } }
}
```

Facade assembly recipe (per mockup v5, all licensed pieces from
picks.md §1-2): cornice band (Wall_Tiles (8,2)) → cream plaster rows
(Building_Walls (26,2)) → leaded-glass ground-floor rows
(Building_Walls (13,35)) → 6px pilaster strips every 3 cells → wired
`door` prop punched into the glass line → owned signs/banners/lamps
as ornament. Mood-card draft values: `direction.md`.

## Open questions for the wiring pass / user taste gate

1. **Day tint:** may Invrisil-only maps carry a cool day grade
   (`[0.96,0.98,1.04]`-ish), or does the "day = identity everywhere"
   floor stand? Draft assumes identity day; the cool read comes from
   the materials themselves.
2. **Plaza geometry:** one boulevard map with a marble plaza AREA
   (wang curb transition, as mocked) vs a separate small plaza map.
   Art supports either; the fountain wants ≥5×6 free cells.
3. **Upper-floor windows:** dropped from the mockup (window_blue read
   as dark slabs at 0.75). Needs a windowed pick pass over
   Building_Walls' window rows, or accept clean plaster + banners.
4. **Fences in the alleys:** Farm.png candidates are speculative
   (picks.md §4) — if they fail the windowed read, the lantern-maze
   card runs on crates + lantern pools alone, no new manifest entry.
5. **Banner emblem:** re-roll for a sharper crossed-swords read?
   (queued spec in pixellab-batch.md; 2s-read currently fine.)

## Canon flags

- **The Adventurer's Fountain is ORIGINAL** (canon-aligned with the
  "City of Adventurers" epithet; wiki lists no plaza fountain). If a
  canonical landmark is preferred, the wiki names streets (Sedia
  Street, Satin's Way/Cloth District) usable as district labels
  instead — no art change needed, only naming.
- No named Brothers members referenced in any art surface (profiles
  lane owns them); parlor direction uses only "shabby-genteel"
  set-dressing values. Spoiler bar: nothing post-Book-17 introduced.
- Crowd walk-ons (6-8 pool-less citizen dressers, fashion variance)
  are the spec's population layer — CHARACTER-pipeline work
  (PixelLab v2 character endpoints), deliberately outside this map-art
  lane. The boulevard layout leaves the mid-street clear for them.
