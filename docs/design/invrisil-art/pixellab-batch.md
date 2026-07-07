# Invrisil — PixelLab generation batch (2026-07-07)

Lane budget ≤35 generations. **Spent: 7** (subscription pool read
761 → shared with parallel region lanes, so only per-job `usage`
figures below are attributable to this lane). All outputs user-owned +
redistributable (TIER-PUBLIC), cached at
`potential_assets/pixellab_2026-07-07_invrisil/` with per-job
`job_*.json` records (endpoint + full params). Base
`https://api.pixellab.ai/v2`, async via `/background-jobs/{id}`.

## Fired

| # | Endpoint | Subject | Params (key) | Output | Cost | Verdict |
|---|---|---|---|---|---|---|
| 1 | `/create-tileset` | cobble↔marble wang set | lower="worn grey cobblestone street, small tightly fitted rounded cobbles, muted warm grey"; upper="pale ivory marble plaza floor, large smooth rectangular flagstone slabs with thin seams, elegant white stone"; transition="clean stone curb edge"; 16px, high top-down, single color black outline, basic shading, medium detail | `tileset_marble_wang4x4.png` (64×64, 16 tiles, corner-id = NW·8+NE·4+SW·2+SE·1, order in `tileset_marble_meta.json`; tileset_id `bb9a3d67-a59e-4532-9787-840c90d7866e`) | 3 | **KEEP** — pure tiles measure `#736c77` (paving) / `#f4f2ec` (marble); curb transitions compose correctly (mockup demonstrates the wang corner) |
| 2 | `/map-objects` | plaza fountain (LANDMARK) | "grand two-tiered white marble plaza fountain… gold statue of a heroic adventurer raising a sword… gold trim on the basin rim, 16-bit RPG map object, hard black outline"; 80×96, low top-down, medium shading, high detail | `fountain_v2.png` | 1 | **KEEP** — first-try hero; marble+gold+blue water, reads in <2s |
| 3 | `/map-objects` | street lamppost | "tall slender street lamppost, dark wrought iron pole with ornate gold trim, one square glass lantern glowing warm at the top…"; 32×64, low top-down | `streetlamp_v2.png` | 1 | **KEEP** — gold-capped silhouette reads at 0.6 scale |
| 4 | `/map-objects` | hanging coin shop sign | "small hanging shop sign, dark wood board hanging from a black iron bracket, bright gold coin emblem…"; 32×32, low top-down | `shop_sign_v2.png` | 1 | **KEEP** — coin emblem unmistakable |
| 5 | `/map-objects` | vertical guild banner | "long vertical hanging cloth banner, cream ivory fabric with gold trim borders and a gold crossed-swords emblem…"; 32×64, low top-down | `guild_banner_v2.png` | 1 | **KEEP (soft)** — emblem reads "X" more than crossed swords at 4×; acceptable; re-roll queued below |

## Failed (cost 0 — documented so nobody repeats it)

The first volley of all four `/map-objects` jobs included a
`color_image` forced-palette PNG (my own 14-swatch coin-gold strip).
**Every job with `color_image` failed server-side** ("Generation
failed. Please try again.", usage $0.00); identical payloads without
`color_image` succeeded. Primary verdict: avoid `color_image` on
`/map-objects` for now — palette words in the prompt were sufficient.
Confound to note honestly: the failed four were submitted as a
SIMULTANEOUS volley alongside the tileset job (see ops rule below),
so account-wide concurrency pressure can't be fully excluded — if
`color_image` is ever wanted again, test it with ONE sequential job
before concluding. Failed job ids: 46d59e91, 52662803, 26727ca0,
a33fcb9a (records in `job_fountain.json` etc.).

## Ops rules for firing the queued specs (coordinator directive 2026-07-07)

- **Submit generation jobs SEQUENTIALLY** — one job, poll
  `/background-jobs/{id}` to completion, then the next. PixelLab
  Tier 1 caps 8 concurrent background jobs ACCOUNT-WIDE and parallel
  region lanes share the account; parallel volleys risk 429s/queue
  rejections. (This lane's parallel volleys predate the directive and
  happened to clear.)
- **Count generations by your own jobs' `usage` fields**, never by
  balance deltas — siblings spend from the same pool concurrently
  (already the method used in the accounting below).

## Queued — deliberately NOT spent (specs ready to fire)

| Subject | Endpoint + params | Why queued |
|---|---|---|
| Banner re-roll (sharper crossed-swords emblem) | `/map-objects`, same params, prompt swap "a clear gold emblem of two crossed swords"; seed sweep ×2 | current banner passes at postcard distance; spend only if the user's taste read objects |
| Silver/gold tea service (parlor prop) | `/map-objects` 32×32 low top-down "silver tea service, ornate teapot and two cups on a small tray, gold rims" | parlor is the smallest map; licensed Furniture blob scan couldn't name a tea set — owned gen is the clean answer, but wiring pass should first check `Esoteric.png`/`Interior_Props_01` windowed |
| Gilded wall clock or scale-of-trade (merchant interior read) | `/map-objects` 32×32 | counting-house is stage-2 of the wiring; don't dress it before the map exists |
| Awning (cream+teal striped, storefront) | `/map-objects` 48×32 low top-down | mockup proved the facade reads without it; one awning family risks fighting the pilaster rhythm — decide after the first in-engine windowed pass |
| Marble balustrade strip (plaza edge) | `/create-1-direction-object` 64px | wang curb already gives the plaza a worked edge; only if the wiring pass wants a blocked plaza rim |

## Budget accounting

- `GET /v2/balance` before lane: 761 generations remaining (of 2000).
- After lane: 727 remaining — **but** parallel region lanes draw from
  the same subscription concurrently; summing this lane's per-job
  `usage` fields gives the attributable figure: **3+1+1+1+1 = 7**.
- Remaining lane headroom if queued specs are fired later: 28.
