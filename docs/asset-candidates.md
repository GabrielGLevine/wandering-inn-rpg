# Asset candidates registry (generated — do not edit)

Regenerate: `python3 tools/asset_candidates.py` (after any new generation
batch or sprites.json change). Query, don't scroll:

```
python3 tools/find_asset.py crate                    # best candidates for a use
python3 tools/find_asset.py renn --kind rig
python3 tools/find_asset.py flame bolt --kind icon --tier owned
python3 tools/find_asset.py barrel --tier public --json
python3 tools/find_asset.py brick --kind tileset     # material_labels match
```

Verdict order: SHIPPED > READY > USABLE-WITH-FIX > ALT > UNREVIEWED > SUPERSEDED > REJECTED. Tiers: `owned-public` (PixelLab, 
redistributable), `owned-unverified` (Codex gpt-image, bundle-tier until
verified), `shipped-public` / `shipped-bundle` (wired in data/sprites.json),
`pack-bundle` (third-party: atlas slices and tileset sheets are rows here; other
pack files are searched from docs/asset-index.json at query time).

## Rows by kind and tier

| kind | owned-public | owned-unverified | pack-bundle | shipped-bundle | shipped-public |
|---|---|---|---|---|---|
| icon | 881 |  |  |  | 106 |
| prop | 556 | 20 | 2489 | 65 | 243 |
| rig | 122 |  |  | 7 | 77 |
| setpiece | 83 |  |  |  |  |
| tileset | 29 |  | 76 |  |  |
| ui | 27 |  |  |  |  |

## Owned batches

| batch | read from | rows |
|---|---|---|
| codex_pixellab_2026-08-02 | MANIFEST.json | 20 |
| pixellab_2026-07-06 | MANIFEST.json | 118 |
| pixellab_2026-07-07 | MANIFEST.json | 18 |
| pixellab_2026-07-07_garden | (file listing) + manifest.json | 23 |
| pixellab_2026-07-07_invrisil | MANIFEST.json | 5 |
| pixellab_2026-07-07_pallass | (file listing) + manifest.json | 9 |
| pixellab_2026-07-07_riverfarm | (file listing) + manifest.json | 19 |
| pixellab_2026-07-08_invrisil_combat | MANIFEST.json | 1 |
| pixellab_2026-07-08_witch | MANIFEST.json | 2 |
| pixellab_2026-07-11_tilesets | MANIFEST.json | 2 |
| pixellab_2026-07-11_trap_props | MANIFEST.json | 4 |
| pixellab_2026-07-12_pallass_rigs | MANIFEST.json | 1 |
| pixellab_2026-07-14_visual_log | MANIFEST.json | 1 |
| pixellab_2026-07-16_drain | MANIFEST.json | 70 |
| pixellab_2026-07-18 | MANIFEST.json | 6 |
| pixellab_2026-07-19_198 | MANIFEST.json | 40 |
| pixellab_2026-08-04_390_rejects | MANIFEST.json | 2 |
| pixellab_2026-08-05_390 | MANIFEST.json | 1 |
| pixellab_2026-08-05_396 | MANIFEST.json | 1 |
| pixellab_2026-08-06 | MANIFEST.json | 96 |
| pixellab_2026-10-08_pallass_513 | MANIFEST.json | 4 |
| pixellab_harvest_2026-10/L1_icons | MANIFEST.json | 698 |
| pixellab_harvest_2026-10/L2_props | MANIFEST.json | 339 |
| pixellab_harvest_2026-10/L3a_rigs | MANIFEST.json | 28 |
| pixellab_harvest_2026-10/L3b_npcs | MANIFEST.json | 35 |
| pixellab_harvest_2026-10/L4_tiles_ui_art | MANIFEST.json | 175 |
| _sliced/Pixel Crawler - Castle Environment 0.3/Tiles | SLICES.json | 35 |
| _sliced/Pixel Crawler - Cave/Props | SLICES.json | 18 |
| _sliced/Pixel Crawler - Cave/Tiles | SLICES.json | 24 |
| _sliced/Pixel Crawler - Cemetery 0.4/Graves | SLICES.json | 25 |
| _sliced/Pixel Crawler - Cemetery 0.4/Props | SLICES.json | 20 |
| _sliced/Pixel Crawler - Cemetery 0.4/Roof | SLICES.json | 7 |
| _sliced/Pixel Crawler - Cemetery 0.4/TileSets_Floor | SLICES.json | 4 |
| _sliced/Pixel Crawler - Cemetery 0.4/Tree | SLICES.json | 16 |
| _sliced/Pixel Crawler - Cemetery 0.4/Walls | SLICES.json | 7 |
| _sliced/Pixel Crawler - Desert/Ground | SLICES.json | 11 |
| _sliced/Pixel Crawler - Desert/Props | SLICES.json | 21 |
| _sliced/Pixel Crawler - Desert/Sand | SLICES.json | 6 |
| _sliced/Pixel Crawler - Fairy Forest 1.7/Light | SLICES.json | 2 |
| _sliced/Pixel Crawler - Fairy Forest 1.7/Props | SLICES.json | 94 |
| _sliced/Pixel Crawler - Fairy Forest 1.7/Tree | SLICES.json | 140 |
| _sliced/Pixel Crawler - Forge 1.2/Tiles | SLICES.json | 28 |
| _sliced/Pixel Crawler - Free Pack/Alchemy_Alchemy_Table_01-Sheet | SLICES.json | 70 |
| _sliced/Pixel Crawler - Free Pack/Alchemy_Alchemy_Table_02-Sheet | SLICES.json | 51 |
| _sliced/Pixel Crawler - Free Pack/Alchemy_Alchemy_Table_03-Sheet | SLICES.json | 5 |
| _sliced/Pixel Crawler - Free Pack/Animated_Pan_01-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Animated_Pan_02-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Animated_Pan_03-Sheet | SLICES.json | 12 |
| _sliced/Pixel Crawler - Free Pack/Animated_Pan_04-Sheet | SLICES.json | 6 |
| _sliced/Pixel Crawler - Free Pack/Animated_Pan_05-Sheet | SLICES.json | 8 |
| _sliced/Pixel Crawler - Free Pack/Anvil_Anvil | SLICES.json | 7 |
| _sliced/Pixel Crawler - Free Pack/Anvil_Anvil_01-Sheet | SLICES.json | 50 |
| _sliced/Pixel Crawler - Free Pack/Anvil_Anvil_02-Sheet | SLICES.json | 67 |
| _sliced/Pixel Crawler - Free Pack/Anvil_Anvil_03-Sheet | SLICES.json | 5 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire | SLICES.json | 18 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_01-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_02-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_03-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_04-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_05-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_06-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_07-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_08-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_09-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Bonfire_10-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Fire_01-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Bonfire_Fire_02-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Butchery_Butchery_01-Sheet | SLICES.json | 1 |
| _sliced/Pixel Crawler - Free Pack/Butchery_Butchery_02 | SLICES.json | 1 |
| _sliced/Pixel Crawler - Free Pack/Butchery_Butchery_03 | SLICES.json | 1 |
| _sliced/Pixel Crawler - Free Pack/Butchery_Butchery_04 | SLICES.json | 2 |
| _sliced/Pixel Crawler - Free Pack/Cooker_Cooker_01 | SLICES.json | 1 |
| _sliced/Pixel Crawler - Free Pack/Cooker_Cooker_02 | SLICES.json | 1 |
| _sliced/Pixel Crawler - Free Pack/Cooker_Cooker_03-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Cooker_Cooker_04-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Cooking Station_Cooking Station | SLICES.json | 17 |
| _sliced/Pixel Crawler - Free Pack/Cooking Station_Estructure | SLICES.json | 16 |
| _sliced/Pixel Crawler - Free Pack/Dungeon_Props | SLICES.json | 20 |
| _sliced/Pixel Crawler - Free Pack/Esoteric | SLICES.json | 40 |
| _sliced/Pixel Crawler - Free Pack/Farm | SLICES.json | 81 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Bricks_01-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Bricks_02-Sheet | SLICES.json | 8 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Bricks_03-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Furnace | SLICES.json | 20 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Iron_01-Sheet | SLICES.json | 8 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Iron_02-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Iron_03-Sheet | SLICES.json | 1 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Stone_01-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Stone_02-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Furnace_Stone_03-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Furniture | SLICES.json | 93 |
| _sliced/Pixel Crawler - Free Pack/Grill_Grill_01-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Grill_Grill_02-Sheet | SLICES.json | 12 |
| _sliced/Pixel Crawler - Free Pack/Grill_Grill_03-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Grill_Grill_04-Sheet | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Interior_Props_01 | SLICES.json | 141 |
| _sliced/Pixel Crawler - Free Pack/Interior_Walls_01 | SLICES.json | 2 |
| _sliced/Pixel Crawler - Free Pack/Meat | SLICES.json | 33 |
| _sliced/Pixel Crawler - Free Pack/Model_01_Size_02 | SLICES.json | 20 |
| _sliced/Pixel Crawler - Free Pack/Model_01_Size_03 | SLICES.json | 6 |
| _sliced/Pixel Crawler - Free Pack/Model_01_Size_04 | SLICES.json | 12 |
| _sliced/Pixel Crawler - Free Pack/Model_01_Size_05 | SLICES.json | 12 |
| _sliced/Pixel Crawler - Free Pack/Model_02_Size_02 | SLICES.json | 8 |
| _sliced/Pixel Crawler - Free Pack/Model_02_Size_03 | SLICES.json | 7 |
| _sliced/Pixel Crawler - Free Pack/Model_02_Size_04 | SLICES.json | 7 |
| _sliced/Pixel Crawler - Free Pack/Model_02_Size_05 | SLICES.json | 7 |
| _sliced/Pixel Crawler - Free Pack/Model_03_Size_02 | SLICES.json | 12 |
| _sliced/Pixel Crawler - Free Pack/Model_03_Size_03 | SLICES.json | 7 |
| _sliced/Pixel Crawler - Free Pack/Model_03_Size_04 | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Model_03_Size_04-export | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Model_03_Size_05 | SLICES.json | 5 |
| _sliced/Pixel Crawler - Free Pack/Pan | SLICES.json | 53 |
| _sliced/Pixel Crawler - Free Pack/Props | SLICES.json | 19 |
| _sliced/Pixel Crawler - Free Pack/Resources | SLICES.json | 24 |
| _sliced/Pixel Crawler - Free Pack/Rocks | SLICES.json | 54 |
| _sliced/Pixel Crawler - Free Pack/Roofs | SLICES.json | 12 |
| _sliced/Pixel Crawler - Free Pack/Sawmill_Base | SLICES.json | 10 |
| _sliced/Pixel Crawler - Free Pack/Sawmill_Level_1 | SLICES.json | 2 |
| _sliced/Pixel Crawler - Free Pack/Sawmill_Level_2-Sheet | SLICES.json | 132 |
| _sliced/Pixel Crawler - Free Pack/Sawmill_Level_3-Sheet | SLICES.json | 180 |
| _sliced/Pixel Crawler - Free Pack/Tilesets_Dungeon_Tiles | SLICES.json | 9 |
| _sliced/Pixel Crawler - Free Pack/Tilesets_Floors_Tiles | SLICES.json | 4 |
| _sliced/Pixel Crawler - Free Pack/Tools | SLICES.json | 105 |
| _sliced/Pixel Crawler - Free Pack/Vegetation | SLICES.json | 87 |
| _sliced/Pixel Crawler - Free Pack/Walls | SLICES.json | 9 |
| _sliced/Pixel Crawler - Free Pack/Workbench_Workbench | SLICES.json | 24 |
| _sliced/Pixel Crawler - Garden Environment/Tiles | SLICES.json | 77 |
| _sliced/Pixel Crawler - Hideout 1.0/Light | SLICES.json | 2 |
| _sliced/Pixel Crawler - Hideout 1.0/Tiles | SLICES.json | 69 |
| _sliced/Pixel Crawler - Library/Tiles | SLICES.json | 57 |
| _sliced/Pixel Crawler - Sewer/Props | SLICES.json | 65 |
| _sliced/Pixel Crawler - Sewer/Tiles | SLICES.json | 20 |
| _sliced/goblin-huts-pack/goblin-huts-pack_goblin-huts-spritesheet | SLICES.json | 4 |
| _sliced/goblin_watchtower/goblin_watchtower_01_front | SLICES.json | 1 |
| _sliced/goblin_watchtower/goblin_watchtower_02_back | SLICES.json | 1 |
| _sliced/goblin_watchtower/goblin_watchtower_03_left | SLICES.json | 1 |
| _sliced/goblin_watchtower/goblin_watchtower_04_right | SLICES.json | 1 |
| _sliced/Pixel Crawler - Castle Environment 0.3 | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Cave | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Cemetery 0.4 | TILESETS.json | 3 |
| _sliced/Pixel Crawler - Desert | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Fairy Forest 1.7 | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Forge 1.2 | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Free Pack | TILESETS.json | 7 |
| _sliced/Pixel Crawler - Garden Environment | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Hideout 1.0 | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Library | TILESETS.json | 1 |
| _sliced/Pixel Crawler - Sewer | TILESETS.json | 2 |
| Admurins_Freebies-2 | (tileset folder/name) | 2 |
| Cute_Fantasy_Free | (tileset folder/name) | 8 |
| Ninja Adventure - Asset Pack | (tileset folder/name) | 23 |
| Pixel_16_interiors_v2_free | (tileset folder/name) | 1 |
| Tiny Swords | (tileset folder/name) | 2 |
| Tiny Swords (Free Pack) | (tileset folder/name) | 8 |
| topdown_floor_tiles_12 | (tileset folder/name) | 12 |
