# Asset intake coverage (generated — do not edit)

Regenerate with `python3 tools/asset_coverage.py`. The gate is
`python3 tools/asset_coverage.py --check` (run by `scripts/preflight.sh`):
0 UNCLASSIFIED before any pool read. Every PNG under `potential_assets/`
(except `_sliced/` and `license-notes/`) sits in exactly one class; the
rules are in the `tools/asset_coverage.py` docstring, and the explicit
pending rulings and exclusions in `docs/asset-coverage-exclusions.json`.

**14940 PNGs: 207 sliced, 94 tileset, 9686 rig_or_animation, 3325 ui_or_icon, 1 audio, 659 owned_wired, 33 pending_ruling, 935 excluded.**

## Pending rulings (33)

Usable art that waits on a named decision. It does not fail the gate and is
not excluded: settle each ruling, then slice, register or exclude the files.

- **`Ninja Adventure - Asset Pack/**/Backgrounds/Animated/**`** (23 PNGs): NINJA16 animated map pieces (flags, mills, water ripples, waterfall): the family is unverified beside PC16 (asset-catalog sec. 1, LOW-CONFIDENCE). Needs a windowed side-by-side ruling, then slice or exclude
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Conveyor Belt/Left.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Conveyor Belt/Middle.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Conveyor Belt/Right.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagBlack16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagBlue16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagBrown16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagGray16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagGreen16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagRed16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagWhite16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flag/FlagYellow16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Flower/SpriteSheet16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/MillPropeller/MillPropeller_A_64x64.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/MillPropeller/MillPropeller_B_64x64.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Plant/SpriteSheet16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/QuickSand/QuickSand32x32.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Water Ripples/SpriteSheet16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Water Ripples/SpriteSheetPurple.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/WaterMill/Watermill_A_34x36.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/WaterMill/Watermill_B_34x36.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Waterfall/BottomSheet16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Waterfall/MiddleSheet16x16.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Animated/Waterfall/TopSheet16x16.png`
- **`Ninja Adventure - Asset Pack/**/Backgrounds/Vehicles/**`** (5 PNGs): NINJA16 boat, crane, sail and nets: the family is unverified beside PC16 (asset-catalog sec. 1, LOW-CONFIDENCE). Needs a windowed side-by-side ruling, then slice or exclude
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Vehicles/Boat.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Vehicles/Crane.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Vehicles/FishNet.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Vehicles/FishNetFull.png`
  - `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Vehicles/Sail.png`
- **`pixellab_harvest_2026-10/L2_props/*__after.png`** (4 PNGs): needs L2_props MANIFEST row + verdict (harvest after-states with no manifest row)
  - `pixellab_harvest_2026-10/L2_props/garden_bed_weedy__after.png`
  - `pixellab_harvest_2026-10/L2_props/halls_gallery_cache__after.png`
  - `pixellab_harvest_2026-10/L2_props/inn_table_dirty__after.png`
  - `pixellab_harvest_2026-10/L2_props/seal_kept_door__after.png`
- **`pixellab_harvest_2026-10/L2_props/forge_molten_trough_wide.png`** (1 PNGs): needs L2_props MANIFEST row + verdict (wide variant of forge_molten_trough)
  - `pixellab_harvest_2026-10/L2_props/forge_molten_trough_wide.png`

## Per pack

`sliced` counts source sheets, with their slices in brackets; a byte-identical
copy (Free Pack 2.1) or an atlas cell's frame export counts as sliced, but its
slices are counted once, under the atlas. `rig/anim` is rig_or_animation,
`owned` is owned_wired and `pending` is pending_ruling.

| pack | PNGs | sliced [slices] | tileset | rig/anim | ui/icon | audio | owned | pending | excluded | UNCLASSIFIED |
|---|---|---|---|---|---|---|---|---|---|---|
| 28 High Quality 16-bit RPG Music | 1 |  |  |  |  | 1 |  |  |  |  |
| _benchmarks | 6 |  |  |  |  |  |  |  | 6 |  |
| Admurins_Freebies-2 | 334 |  | 2 | 295 | 32 |  |  |  | 5 |  |
| art_direction_review_2026-10-05 | 177 |  |  |  |  |  |  |  | 177 |  |
| Bat_Fur | 15 |  |  | 15 |  |  |  |  |  |  |
| codex_pixellab_2026-08-02 | 20 |  |  |  |  |  | 20 |  |  |  |
| Cute_Fantasy_Free | 23 |  | 8 | 8 |  |  |  |  | 7 |  |
| goblin-huts-pack | 10 | 9 [4] |  |  |  |  |  |  | 1 |  |
| goblin-pack | 78 |  |  | 78 |  |  |  |  |  |  |
| goblin_watchtower | 4 | 4 [4] |  |  |  |  |  |  |  |  |
| Ninja Adventure - Asset Pack | 1915 |  | 23 | 1367 | 492 |  |  | 28 | 5 |  |
| Pixel Crawler - Castle Environment 0.3 | 22 | 1 [35] |  | 16 |  |  |  |  | 5 |  |
| Pixel Crawler - Cave | 42 | 2 [42] |  | 16 |  |  |  |  | 24 |  |
| Pixel Crawler - Cemetery 0.4 | 114 | 6 [79] | 1 | 40 |  |  |  |  | 67 |  |
| Pixel Crawler - Desert | 45 | 3 [38] |  | 12 |  |  |  |  | 30 |  |
| Pixel Crawler - Fairy Forest 1.7 | 268 | 3 [236] | 1 | 16 |  |  |  |  | 248 |  |
| Pixel Crawler - Forge 1.2 | 19 | 1 [28] |  | 12 |  |  |  |  | 6 |  |
| Pixel Crawler - Free Pack | 178 | 86 [1733] | 3 | 81 |  |  |  |  | 8 |  |
| Pixel Crawler - Free Pack 2.1 | 178 | 86 [0] | 3 | 81 |  |  |  |  | 8 |  |
| Pixel Crawler - Garden Environment | 21 | 1 [77] |  | 16 |  |  |  |  | 4 |  |
| Pixel Crawler - Hideout 1.0 | 22 | 2 [71] |  | 16 |  |  |  |  | 4 |  |
| Pixel Crawler - Library | 21 | 1 [57] |  | 16 |  |  |  |  | 4 |  |
| Pixel Crawler - Sewer | 20 | 2 [85] | 1 | 12 |  |  |  |  | 5 |  |
| Pixel_16_interiors_v2_free | 1 |  | 1 |  |  |  |  |  |  |  |
| pixellab_2026-07-06 | 1916 |  |  | 1832 |  |  | 82 |  | 2 |  |
| pixellab_2026-07-07 | 222 |  |  | 211 |  |  | 11 |  |  |  |
| pixellab_2026-07-07_garden | 26 |  |  |  |  |  | 23 |  | 3 |  |
| pixellab_2026-07-07_invrisil | 8 |  | 1 |  |  |  | 4 |  | 3 |  |
| pixellab_2026-07-07_pallass | 11 |  | 2 |  |  |  | 7 |  | 2 |  |
| pixellab_2026-07-07_riverfarm | 23 |  | 1 |  |  |  | 18 |  | 4 |  |
| pixellab_2026-07-08_invrisil_combat | 38 |  |  | 38 |  |  |  |  |  |  |
| pixellab_2026-07-08_witch | 2 |  |  |  |  |  | 2 |  |  |  |
| pixellab_2026-07-11_tilesets | 2 |  | 2 |  |  |  |  |  |  |  |
| pixellab_2026-07-11_trap_props | 4 |  |  |  |  |  | 4 |  |  |  |
| pixellab_2026-07-12_pallass_rigs | 1 |  |  | 1 |  |  |  |  |  |  |
| pixellab_2026-07-14_visual_log | 139 |  |  | 139 |  |  |  |  |  |  |
| pixellab_2026-07-16_drain | 114 |  |  | 46 | 58 |  | 10 |  |  |  |
| pixellab_2026-07-18 | 6 |  |  |  |  |  | 6 |  |  |  |
| pixellab_2026-07-19_198 | 62 |  |  | 24 |  |  | 38 |  |  |  |
| pixellab_2026-08-04_390_rejects | 28 |  |  | 28 |  |  |  |  |  |  |
| pixellab_2026-08-05_390 | 59 |  |  | 59 |  |  |  |  |  |  |
| pixellab_2026-08-05_396 | 41 |  |  | 41 |  |  |  |  |  |  |
| pixellab_2026-08-06 | 96 |  |  |  |  |  | 96 |  |  |  |
| pixellab_2026-10-08_pallass_513 | 142 |  |  | 142 |  |  |  |  |  |  |
| pixellab_harvest_2026-10 | 7275 |  | 23 | 4418 | 2491 |  | 338 | 5 |  |  |
| Relc | 8 |  |  | 8 |  |  |  |  |  |  |
| Relc1 | 8 |  |  | 8 |  |  |  |  |  |  |
| research_2026-07-05 | 98 |  |  | 21 | 6 |  |  |  | 71 |  |
| Small_Bat | 15 |  |  | 15 |  |  |  |  |  |  |
| Tiny Swords | 230 |  | 2 | 92 | 92 |  |  |  | 44 |  |
| Tiny Swords (Free Pack) | 820 |  | 8 | 466 | 154 |  |  |  | 192 |  |
| topdown_floor_tiles_12 | 12 |  | 12 |  |  |  |  |  |  |  |

## Exclusions in use

| glob | class | PNGs | reason |
|---|---|---|---|
| `Pixel Crawler - */**/Social/**` | excluded | 43 | Social/: 4x promo upscales and mockups of the Assets/ sheets (slicer SKIPPED promo_render) |
| `Pixel Crawler - Free Pack*/**/MockUps/**` | excluded | 4 | MockUps/: finished tavern scene renders (slicer SKIPPED promo_render) |
| `Pixel Crawler - */**/Weapons/**` | excluded | 15 | held-weapon item sheets for character rigs and gear UI, not world art (slicer SKIPPED weapon_sheet) |
| `Pixel Crawler - */**/Weapon/**` | excluded | 1 | held-weapon item sheets for character rigs and gear UI, not world art (slicer SKIPPED weapon_sheet) |
| `Pixel Crawler - */**/Shadows.png` | excluded | 6 | shadow overlay without one opaque pixel (slicer SKIPPED translucent_overlay) |
| `Pixel Crawler - */**/Smoke-Sheet.png` | excluded | 2 | translucent smoke strip (slicer SKIPPED translucent_overlay) |
| `Pixel Crawler - */**/Shadown.png` | excluded | 1 | one-colour shadow silhouettes (slicer SKIPPED flat_overlay) |
| `Pixel Crawler - */_sliced/**` | excluded | 341 | stale in-pack slicer output from before the top-level potential_assets/_sliced/ root; superseded copies |
| `**/__MACOSX/**` | excluded | 102 | macOS AppleDouble resource forks (._ files), not images |
| `Tiny Swords*/**/Buildings/**` | excluded | 40 | TS-CARTOON world art clashes with PC16 maps (asset-catalog sec. 1); only its UI kit and VFX are used |
| `Tiny Swords*/**/Terrain/**` | excluded | 60 | TS-CARTOON terrain dressing (resources, decorations, water, bridge) clashes with PC16 maps (asset-catalog sec. 1); its Tileset/ and Ground/ tilemaps are registered |
| `Tiny Swords/**/Deco/**` | excluded | 18 | TS-CARTOON world art clashes with PC16 maps (asset-catalog sec. 1); only its UI kit and VFX are used |
| `Tiny Swords/**/Resources/**` | excluded | 16 | TS-CARTOON resource and sheep sprites clash with PC16 maps (asset-catalog sec. 1) |
| `Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/*.png` | excluded | 5 | pack preview renders, palette and music cover |
| `Cute_Fantasy_Free/**/Outdoor decoration/**` | excluded | 7 | CUTE16 decorations: the pack licence is non-commercial (asset-catalog sec. 1), so they stay out of pools |
| `Admurins_Freebies-2/**/Canines/**` | rig_or_animation | 29 | ADMURIN creature animation sheets |
| `Admurins_Freebies-2/**/Gollux/**` | rig_or_animation | 6 | ADMURIN creature animation sheets |
| `Admurins_Freebies-2/**/PixelHorse_V1.0/**` | rig_or_animation | 30 | ADMURIN layered horse animation sheets |
| `Admurins_Freebies-2/**/Animated Chests/**` | rig_or_animation | 2 | ADMURIN animated loot-chest strips (5 tiers x 8 frames; asset-catalog sec. 3) |
| `Admurins_Freebies-2/**/5/MCBlocks*.png` | excluded | 2 | ADMURIN block sprite sheets: over a thousand outlined block icons, icon-scale, not PC16 world art; searchable through docs/asset-index.json |
| `Admurins_Freebies-2/**/Tileset Scroller - Summer/**` | excluded | 3 | preview, thumbnail and map renders of the Summer scroller (its tile sheets are registered) |
| `goblin-pack/**` | rig_or_animation | 78 | CUSTOM-HD goblin rigs: frames, sheets and source references (in use as goblin_base/female/sword) |
| `goblin-huts-pack/source-reference.png` | excluded | 1 | opaque concept reference render of the hut atlas, not a sprite (slicer SKIPPED promo_render) |
| `_benchmarks/**` | excluded | 6 | art-direction benchmark renders: reference images, not assets |
| `art_direction_review_2026-10-05/**` | excluded | 177 | art-direction review captures and contact sheets of the game, not assets |
| `research_2026-07-05/**` | excluded | 71 | research copy of the Ninja Adventure Godot demo (themes, system sprites); duplicates pack art |
| `pixellab_*/**/mockups/**` | excluded | 5 | PixelLab-era mockup scene renders, not assets |
| `pixellab_*/**/*_4x*.png` | excluded | 6 | 4x preview upscales of registered sheets (asset_candidates skips _4x) |
| `pixellab_*/**/palette_*.png` | excluded | 1 | palette swatch, not an asset |
| `pixellab_*/**/preview_*.png` | excluded | 2 | PixelLab preview renders of a registered rig |
| `pixellab_2026-10-08_pallass_513/sheets/**` | rig_or_animation | 11 | assembled animation sheets of the #513 rigs, whose rig folders are registered |

## UNCLASSIFIED (0)

None.
