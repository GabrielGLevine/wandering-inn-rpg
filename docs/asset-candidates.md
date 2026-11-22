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

| kind | shipped-bundle | shipped-public |
|---|---|---|
| icon |  | 106 |
| prop | 137 | 264 |
| rig | 8 | 79 |

## Owned batches

| batch | read from | rows |
|---|---|---|
