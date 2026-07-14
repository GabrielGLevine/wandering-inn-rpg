# PALLASS — PixelLab generation log (2026-07-07)

API: `https://api.pixellab.ai/v2`, async jobs polled via
`GET /background-jobs/{job_id}`. Raw outputs + `manifest.json` (prompt
+ params per file) in the gitignored central cache:
`potential_assets/pixellab_2026-07-07_pallass/`.
All outputs user-owned + redistributable (TIER-PUBLIC).

**Budget: ≤35 generations. Spent: 17.**
`GET /v2/balance` read 761 generations before this lane's first job;
713 after its last — but the account is SHARED with the other art
lanes running today (their tilesets are visible in `GET /tilesets`),
so the lane-accurate count is per-job usage: 2 tilesets × 5 + 7 map
objects × 1 = **17**. Ops note for other lanes: Tier 1 caps the
account at 8 concurrent background jobs — parallel batch submits 429
when lanes overlap; submit sequentially with backoff.

## Fired

| # | Name | Endpoint | Key params | Prompt kernel | Output | Verdict |
|---|---|---|---|---|---|---|
| 1 | `tileset_slate_over_void` | `/create-tileset` (5 gens) | 16px, transition_size 0.25 | lower "dark abyss below a city tier…faint steam haze" / upper "engineered slate flagstone plaza…thin bronze metal seams, hard geometric masonry, machine city" / transition "carved slate parapet edge with bronze trim" | `tileset_slate_over_void_atlas.png` (16 Wang tiles, 64×64 atlas + `_meta.json` corner map) | **KEEP** — slabs read engineered grid; bronze-trimmed drop edge IS the tier-edge signature; void's sparse glints read as the tier below. Flag: slabs lighter/bluer than the ratified slate row — re-grade via mood tint at wiring, or regen darker if user wants |
| 2 | `prop_great_elevator` | `/map-objects` (1) | 64×96, low top-down, high detail | "massive bronze and iron freight elevator machine, riveted metal cage with open gate, large gears and glowing pale crystal power core, dark slate stone shaft tower behind" | `prop_great_elevator.png` | **KEEP** — the hero prop; tall riveted tower, glowing gate; measured bronze `#C09048`/`#786048` on navy |
| 3 | `prop_crystal_lamp` | `/map-objects` (1) | 32×64, low top-down | "tall slim bronze lamppost with glowing white crystal lantern head, geometric riveted industrial design" | `prop_crystal_lamp.png` | **KEEP** — white crystal head `#F0F0F0` on bronze `#906030`; the white-not-amber lamp rule embodied |
| 4 | `prop_steam_vent` | `/map-objects` (1) | 32×48, low top-down | "round bronze steam vent grate set into slate stone, white steam puff rising, riveted metal ring" | `prop_steam_vent.png` | **KEEP** — radial bronze grate; runtime steam should be a GPUParticles emitter, not the baked puff |
| 5 | `prop_price_board` | `/map-objects` (1) | 48×48, low top-down | "official notice board on bronze stand, dark slate panel with neat white chalk price list rows and a wax seal stamp, orderly bureaucratic" | `prop_price_board.png` | **KEEP** — slate panel, white rows, bronze stand; chalk rows are unreadable glyphs at 16px (by design — no stat/price text rendered) |
| 6 | `tileset_brick_over_molten` | `/create-tileset` (5 gens) | 16px, transition_size 0.25 | lower "glowing molten bronze metal flowing in a channel" / upper "dark charcoal slate engineered brick floor…bronze rivet seams, industrial forge hall" / transition "riveted bronze channel rim" | `tileset_brick_over_molten_atlas.png` (+ meta) | **KEEP** — dark brick (reads cool charcoal-navy: stays in the slate field) as walkable floor, molten channels via Wang edges. Flag: lava leans yellower than the ratified furnace hex `#F65510`; forge-tier mood grade pulls it back, and the licensed Forge molten fill (redder) is the bundle-tier upgrade (picks.md §1) |
| 7 | `prop_tier_wall` | `/map-objects` (1) | 128×48, low top-down | "long engineered slate masonry wall, precisely cut cool grey-blue stone blocks with bronze pilasters and rivet bands, machine city facade, repeating architectural segment" | `prop_tier_wall.png` | **KEEP** — tiles horizontally (used ×5 across 320px in the mockup at half scale); doubles as parapet at full scale |
| 8 | `prop_forge_station` | `/map-objects` (1) | 48×64, low top-down, high detail | "public forge station, heavy anvil on slate stone base beside a small furnace with glowing orange mouth and bronze chimney pipe, hammer resting" | `prop_forge_station.png` | **KEEP with flag** — furnace + chimney read strongly; the anvil reads more grindstone than anvil at small scale. Good enough for the band's identity; queue 1 retry ("blacksmith anvil on stone block, side-lit by furnace") if the wiring pass wants a cleaner interactable read |
| 9 | `prop_market_stall` | `/map-objects` (1) | 64×48, low top-down | "orderly market stall with riveted bronze frame and slate stone counter, neat grey canvas awning, small posted price placard, uniform civic design, no vendor" | `prop_market_stall.png` | **KEEP** — bronze frame, dark counter; awning came out lilac-tan rather than grey (still reads civic-uniform, not Liscor-brown; two identical stalls side-by-side in the mockup carry the "uniform stalls" tell) |

(One earlier submit attempt of #6–#9 as a parallel batch 429'd on the
shared concurrency cap — no generations consumed; logged in
`manifest.json` history only as the successful sequential runs.)

## Queued, deliberately NOT fired (budget discipline)

- **Anvil-retry for `prop_forge_station`** (see #8 flag) — 1 gen.
- **Permit/stamp clerk kiosk** (tier clerk's desk — the QUALIFY
  interactable at the lift gate): "bronze-grilled ticket kiosk with
  slate counter and stamp pad", 48×48. The price board covers the
  bureaucracy read in v1 mockup; the kiosk belongs with the elevator-
  puzzle wiring task.
- **Lane-marking decal strip** (canon Runner-lane stairway discipline):
  a 16×16 painted-line tile family (white/bronze lane stripes). Cheap
  and very Pallass; deferred because it's best generated against the
  final floor tile via `/inpaint` once tiles are wired.
- **Stair-forge / great stairway segment** (bible's second traversal
  landmark): big multi-cell piece, wants its own composition pass
  with the elevator-puzzle map layout in hand.
- **Dullahan/Garuda walk-on extras** (canon floor population): OUT of
  this lane — character pipeline (v2 character endpoints) per the
  wi-art-and-sprites character directive, profiles first
  (`character-profiles-staging.md` §Pallass says generate LAST).

## Mockups

- `docs/archive/design/pallass-art/mockup_owned_pallass_two_tiers.png`
  (320×180 native) + `_4x.png` — composed PURELY from the PixelLab
  outputs above (committable; the charter's licensed-mockup rule
  doesn't apply). No licensed-pack mockup was composed — the owned
  set covered every band element, so nothing needed staging in the
  gitignored mockups dir.
- Composer script (repro): scratchpad `compose_mockup.py` (session
  scratch; layout law documented in direction.md §shelf grammar —
  the doc, not the script, is the durable artifact).
