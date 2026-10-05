# Asset candidates registry (generated — do not edit)

Regenerate: `python3 tools/asset_candidates.py` (after any new generation
batch or sprites.json change). Query, don't scroll:

```
python3 tools/find_asset.py crate                    # best candidates for a use
python3 tools/find_asset.py renn --kind rig
python3 tools/find_asset.py flame bolt --kind icon --tier owned
python3 tools/find_asset.py barrel --tier public --json
```

Verdict order: SHIPPED > READY > USABLE-WITH-FIX > ALT > UNREVIEWED > SUPERSEDED > REJECTED. Tiers: `owned-public` (PixelLab, 
redistributable), `owned-unverified` (Codex gpt-image, bundle-tier until
verified), `shipped-public` / `shipped-bundle` (wired in data/sprites.json),
`pack-bundle` (third-party, searched from docs/asset-index.json at query time).

## Rows by kind and tier

| kind | owned-public | owned-unverified | shipped-bundle | shipped-public |
|---|---|---|---|---|
| icon | 881 |  | 2 | 103 |
| prop | 556 | 20 | 59 | 119 |
| rig | 118 |  | 8 | 47 |
| setpiece | 83 |  |  |  |
| tileset | 29 |  |  |  |
| ui | 27 |  |  |  |

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
| pixellab_harvest_2026-10/L1_icons | MANIFEST.json | 698 |
| pixellab_harvest_2026-10/L2_props | MANIFEST.json | 339 |
| pixellab_harvest_2026-10/L3a_rigs | MANIFEST.json | 28 |
| pixellab_harvest_2026-10/L3b_npcs | MANIFEST.json | 35 |
| pixellab_harvest_2026-10/L4_tiles_ui_art | MANIFEST.json | 175 |
