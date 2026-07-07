# 8a Asset Assembly — the Magical Door's ruin + Task A1 garden pre-work

**Task A1, lane γ (parallel asset prep), issue #8 milestone 8a.** Region/
scale/anchor picks for D1's ruin map family (`ruin_surface`), the
`anchor_stone_pedestal` prop, and issue #9 pre-work (Garden of Sanctuary).
Companion docs: `docs/asset-catalog.md` sec. 3b (qualitative pack-choice
reasoning), `docs/asset-index.md` "8a Task A1 PIL-scan pass" (raw scan
numbers this table is derived from), `wandering_inn_game/assets_manifest.json`
(the 5 new licensed-path entries this task adds).

**Method note (binding, wi-art-and-sprites discipline):** every pixel
region below comes from a numeric PIL scan — 16px-cell mean-RGB +
luminance-stddev clustering for tile sheets, alpha-channel connected-
component bbox extraction for prop sheets. No pack PNG was ever rendered or
viewed. **These are candidates, not verified picks** — the skill's mandatory
rule stands: whoever wires a region into `sprites.json`/`biomes.json` (D1,
D4, or a future #9 pass) must confirm it with a windowed QA screenshot
before calling it done. This table gets you to the right pixel coordinates,
not around that step.

All source packs are licensed (Pixel Crawler, non-redistributable) — no PNG
was extracted or committed this pass. Every path below is manifest-only
(`bundle: true`, `fallback: "placeholder"`); it resolves to the runtime
placeholder chip (`WISpriteRegistry`'s R2 fallback-art contract, see
"Placeholder-fallback note" at the end) until a `bundle-vN` release
overlays the real art — a USER-gated step (`wi-shipping`), out of this
task's charter.

---

## 1. Ruin floor + wall tiles (`ruin_surface`, Task D1)

Primary pick: **Cemetery 0.4** (its own catalog casting note already reads
"crypts near the Ruins of Liscor" — the closest textual match to an actual
ruin, vs. Castle's "regal, still-standing interior"). Wired the same way
Cave's `Assets/Tiles.png` already is in `data/biomes.json` (native 16px =
1 world cell, `{sheet, tile_px:16, floor:[col,row], blocked:[col,row]}`
shape) — no `render_scale`/anchor applies to tile-sheet entries.

| Candidate | Source | Native px region `[x,y,w,h]` | col,row | Notes |
|---|---|---|---|---|
| Floor (primary) | `Pixel Crawler - Cemetery 0.4/.../Environment/TileSets/Floor.png` (400x400, 16px grid) | `[32,16,16,16]` | (2,1) | Flat dark-olive `rgb(60,58,24)`, std 1.6, alpha 1.00 — cleanest fully-opaque cell in the occupied 5x12 block (cols 0-5, rows 0-11; rest of the 400x400 canvas is empty). |
| Wall, clean fill (primary) | `.../Environment/Structures/Walls.png` (400x800, 16px grid) | `[32,32,16,16]` | (2,2) | Flat warm-grey `rgb(76,68,52)`, std 6.6, alpha 1.00. |
| Wall, masonry-textured (alt) | same sheet | `[32,272,16,16]` | (2,17) | Darker `rgb(50,49,42)`, std 20.3 — visibly rougher; use for a "crumbling" accent variant if D1 wants a second wall id. |
| Floor/wall, organic alt | `Pixel Crawler - Cave/.../Assets/Tiles.png` (already `IN USE` in `biomes.json`'s `cave` entry: `floor:[8,13]`, `blocked:[2,3]`) | n/a — reuse existing biome entry | (8,13) / (2,3) | "Ruins reclaimed by nature" read; Cave's own catalog note already names "deeper cave maps toward the Ruins." No new manifest entry needed — already wired. |
| Wall, intact-chamber alt | `Pixel Crawler - Castle Environment 0.3/.../Assets/Tiles.png` (already in manifest, `assets/tiles/castle/Tiles.png`) | `[96,32,16,16]` | (6,2) | Warm grey `rgb(90,82,70)`, std 14.1 — cleaner/less-weathered than Cemetery; reserve for an intact inner chamber (Warmage Thresk's own room) if the ruin design wants one, not the general ruin floor. |
| Floor/shadow, dark alt | Castle `Assets/Tiles.png` | `[32,32,16,16]` or `[32,48,16,16]` | (2,2) / (2,3) | Perfectly flat (std 0.0) dark blue-purple `rgb(28,23,44)` — reads as either a shadow fill or a very dark floor tile; flag for a windowed check before use (ambiguous at the numeric-scan level). |

**Manifest:** `assets/tiles/cemetery/Floor.png`, `assets/tiles/cemetery/Walls.png` (both new, this task). `assets/tiles/castle/Tiles.png`, `assets/tiles/cave/Tiles.png` already present — no new entries needed for those two.

## 2. `anchor_stone_pedestal` (Task D1)

Props-over-tiles rule applies — a real prop sprite, not a tile recolor.
Sizing convention follows the in-tree precedent (`boulder`: 32x43 native
@ `render_scale 0.5`; `crate`: 38x26 native @ 0.45; `table_brown`: 72x64
native @ 0.35) — target roughly 1.5-2 world cells tall for a small
standing monument.

| Candidate | Source | Native px region `[x,y,w,h]` | Proposed `render_scale` | Notes |
|---|---|---|---|---|
| Pedestal (primary) | `Pixel Crawler - Cemetery 0.4/.../Environment/Props/Props.png` | `[64,0,48,48]` | `0.5` (-> ~24x24 world px) | Isolated, dense (84% opaque) blob — compact blocky altar/monument silhouette. Tight alpha-cropped bbox, so `anchor:[0.5,1.0]` (the sprites.json default) should already sit at the true feet plane — no under-figure padding the way Body_A/Citizen_F had, because blob detection finds the tight opaque extent directly rather than a fixed sheet-grid frame. Still windowed-verify per the mandatory rule; a compact monument's "feet plane" read can be ambiguous even from a clean bbox. |
| Pedestal (tall alt) | `.../Environment/Props/Graves.png` | `[132,114,24,78]` | `0.35` (-> ~8x27 world px) or keep taller if D1 wants a more vertical "broken column" read | 96% opaque, tall standing-slab silhouette — a "broken monument" read rather than a compact altar. |

**Manifest:** `assets/props/cemetery/Props.png`, `assets/props/cemetery/Graves.png` (both new, this task).

## 3. Rubble scatter (Task D1)

Props-over-tiles again — 2-3 small debris props placed via the map's
`scatter` array, not a recolored floor tile, matching the barrel/crate/
boulder shadow convention (`shadow: true` if any piece reads taller than
one cell — none of these do).

| Candidate | Source | Native px region `[x,y,w,h]` | Proposed `render_scale` |
|---|---|---|---|
| Rubble piece A | Cemetery `Props.png` | `[65,48,14,34]` | `0.5` |
| Rubble piece B | Cemetery `Props.png` | `[82,49,11,31]` | `0.5` |
| Rubble piece C | Cemetery `Props.png` | `[96,64,31,16]` | `0.45` |

All three share the grey-brown stone palette family with the pedestal
candidates (same sheet) — a scatter of 2-3 of these around the pedestal
reads as broken masonry debris without needing a dedicated "rubble" tile.
`assets/props/cemetery/Props.png` covers all three (already listed above).

## 4. `pantry_door` awakened frame (Task D4)

**v1 needs zero new art.** Per the milestone plan's Global Constraints,
the awakened state ships via `visual_states` tint + a phase-gated
`PointLight2D` on the **existing** `door` sprite entry
(`data/sprites.json`, id `door`: Free Pack `Furniture.png` region
`[222,279,34,44]`, `render_scale 0.5`, already `IN USE`) — the exact
`unlit_lantern` precedent (tint `[1.4,1.25,0.75]` + warm `PointLight2D`
on `lit_the_common_room`). No Castle/Cemetery/Cave/Garden sheet in this
task's pack roster has an arcane-doorway motif worth swapping in over the
door prop already wired.

**Deferred PixelLab generation spec** (balance $0.00 as of 2026-07-07 —
**nothing generated this pass**; queue for when balance is topped up, per
the milestone plan's VISUAL-LOG deferral and the wi-art-and-sprites
PixelLab recipe conventions):

- Endpoint: `/inpaint` (v1) — dresses/modifies an EXISTING frame, preserves
  geometry/anchor (the documented "PC-outfit path"). Target frame: the
  current `door` crop (`assets/props/free_pack/Furniture.png` region
  `[222,279,34,44]`), so the awakened frame inherits the exact same
  anchor/footprint as `default`/`flicker` — zero re-anchoring risk.
- Prompt kernel: `"top-down RPG sprite, hard black outline, 16-bit, ancient
  wooden pantry door with faint glowing blue-white magical rune lines
  traced across the frame and panels, soft arcane glow, no figures"` —
  style kernel per the skill (`"top-down RPG sprite, hard black outline,
  16-bit"`), `view: "low top-down"` (standing object, matches the door's
  existing orientation).
- Size: `{"width": 34, "height": 44}` (matches the existing door crop
  exactly, so no rescale/re-anchor is needed downstream).
- Log destination once generated: `docs/VISUAL-LOG.md` (drained each
  milestone close, per Task DF) + `assets/LICENSES/pixellab-ai-generated-
  verdict.md` provenance note (user-owned + redistributable, TIER-PUBLIC).

## 5. Garden of Sanctuary pre-work (issue #9, picks only — out of 8a charter)

Confirms the existing catalog casting call ("near-literal fit," sec. 5).
No wiring, no manifest-consumption beyond the one new tile-sheet entry —
issue #9 does its own composition/windowed pass.

| Candidate | Source | Native px region `[x,y,w,h]` | col,row | Notes |
|---|---|---|---|---|
| Fountain water | `Pixel Crawler - Garden Environment/.../Assets/Tiles.png` (480x480, 16px grid) | `[336,112,16,16]` | (21,7) | Perfectly flat (std 0.0) teal `rgb(69,114,121)`, alpha 1.00 — basin-water fill tile only. **The full fountain structure (basin rim + statue) is a multi-cell composite not yet located** — needs a windowed read to compose correctly; deferred to #9's own pass. |
| Hedge (trimmed-topiary top-face) | same sheet | `[16,128,16,16]` | (1,8) | Bright yellow-green `rgb(114,122,35)`, std 26.8 (leafy texture), alpha 1.00. |
| Petals / flowerbed ambience (primary) | same sheet | `[16,416,16,16]` | (1,26) | Flat magenta/pink `rgb(143,2,79)` — closest match to the catalog mockup's "pink flowerbeds." Proposed as the source color for a petal `GPUParticles2D` ambience emitter (existing atmosphere-layer pattern, not a placed tile — see `wandering_inn_game/CLAUDE.md` "Ambience layer" block). |
| Flowerbed alt (red) | same sheet | `[64,416,16,16]` | (4,26) | `rgb(144,30,9)`. |
| Flowerbed alt (purple) | same sheet | `[112,416,16,16]` | (7,26) | `rgb(69,3,144)`. |

Garden ships **no dedicated Props.png** (confirmed via directory listing,
unlike Cave/Cemetery) — every decorative object (hedge, fountain, statue)
lives as a multi-cell region inside this one `Assets/Tiles.png`. A full
fountain/statue *object* crop (not just the flat water-fill tile) needs a
windowed screenshot to compose correctly; explicitly deferred to #9.

**Manifest:** `assets/tiles/garden/Tiles.png` (new, this task).

---

## Manifest cross-reference (all 5 new entries this task adds)

| Manifest path | Source pack | Covers |
|---|---|---|
| `assets/props/cemetery/Graves.png` | Pixel Crawler - Cemetery 0.4 | pedestal (tall alt) |
| `assets/props/cemetery/Props.png` | Pixel Crawler - Cemetery 0.4 | pedestal (primary), rubble A/B/C |
| `assets/tiles/cemetery/Floor.png` | Pixel Crawler - Cemetery 0.4 | ruin floor (primary) |
| `assets/tiles/cemetery/Walls.png` | Pixel Crawler - Cemetery 0.4 | ruin wall (primary + textured alt) |
| `assets/tiles/garden/Tiles.png` | Pixel Crawler - Garden Environment | #9: fountain water, hedge, petal swatches |

All five: `verdict: "FORBIDDEN"`, `bundle: true`, `fallback: "placeholder"`
— same shape as every existing Pixel Crawler entry. `assets/tiles/castle/
Tiles.png` and `assets/tiles/cave/Tiles.png` (used above as secondary/
existing-biome candidates) were already in the manifest before this task —
no new entries needed for those two. `.gitignore`'s GENERATED block was
regenerated from the manifest via the new `scripts/gen_asset_ignores.sh`
(see below); `scripts/leak_check.sh` runs clean.

## Placeholder-fallback note (scope correction from the dispatch brief)

The dispatch brief asked for "committed PLACEHOLDER fallback art files
where D1 needs paths to exist." Reading `src/world/sprite_registry.gd`
(the M-RELEASE R2 fallback-art contract) confirms this is **already fully
automatic**: any `sprites.json`/`biomes.json` sheet path that resolves to
a missing file gets a synthesized, deterministically-colored placeholder
texture at runtime (`_placeholder_texture`/`_placeholder_tile_texture`/
`_placeholder_strip_texture`) — no committed PNG is required for a public
checkout to boot clean. Since `data/sprites.json`/`data/biomes.json` are
lane-α files this task doesn't touch (D1 owns the actual wiring), and the
manifest paths above already carry `"fallback": "placeholder"`, **no
placeholder art files were created this pass** — creating throwaway PNGs
that duplicate an existing runtime mechanism would be scope creep with no
functional benefit. D1 gets a clean public boot for free once it wires
these paths into `sprites.json`/`biomes.json`.

## New tooling this task adds

`scripts/gen_asset_ignores.sh` — `scripts/fetch_private_assets.sh`'s
header comment has referenced this script by name since the unified-repo
transition (2026-07-07) but it was never actually written until now. It
regenerates the `.gitignore` GENERATED block from
`wandering_inn_game/assets_manifest.json` deterministically (manifest
order, path + `.import` sidecar per entry), replacing hand-editing. Used
to regen the block for this task's 5 new manifest entries; verified with
`scripts/leak_check.sh` (clean).

## Handoff to D1/D4

- Ruin floor/wall: wire `data/biomes.json`'s new `ruin_surface` (or
  equivalent) entry from sec. 1's primary picks; windowed-verify.
- `anchor_stone_pedestal`: wire `data/sprites.json` from sec. 2's primary
  pick; windowed-verify anchor/footprint against the pedestal's actual
  cell placement.
- Rubble scatter: wire 2-3 of sec. 3's pieces into `ruin_surface`'s
  `scatter` array.
- `pantry_door` awakened state: **no art dependency** — tint + light only
  (sec. 4). PixelLab spec is ready to fire whenever balance is topped up;
  no action needed for 8a to ship.
- Garden picks (sec. 5) are issue #9's to consume — not blocking 8a.
