# Invrisil — art direction card ("marble and coin")

Region lane 8c, Fable art-director pass 2026-07-07. Spec:
`docs/superpowers/specs/2026-07-06-invrisil-design.md`; disciplines:
`docs/design/city-identity-bible.md` (verb: **DEAL** — everything is
negotiable, including you). This card directs; the post-Door wiring
task integrates (see `handoff.md`). Nothing here touches
`skeleton_scene.json`/`biomes.json`/`sprites.json`/`moods.json`.

## The identity claim (what the postcard says in 2 seconds)

A pale marble plaza with a gilded adventurer fountain, faced by a
colonnade of glass-fronted shops hung with coin-gold signage — a city
that is BIG, COOL-TONED, and expensive. Liscor is warm timber you can
see over; Invrisil is cool stone that looms and glitters. Wealth reads
in ORNAMENT (gold trim, glass, banners), never in map size — v1 is a
district postcard, not a metropolis.

Taste-review surface (gitignored, licensed-mixed — never commit):
`potential_assets/pixellab_2026-07-07_invrisil/mockups/
mockup_licensed_invrisil_boulevard_320.png` (+`_4x.png`).

## Palette (hex swatches + quarantine check)

| Role | Hex | Source |
|---|---|---|
| Marble plaza (base) | `#f4f2ec` (seams `#d9d4c8`) | OWNED PixelLab wang tileset, pure-upper tile |
| Street paving (base) | `#736c77` (cool grey-violet) | OWNED wang tileset, pure-lower tile |
| Facade plaster (upper floor) | `#ddccb8` cream | licensed Building_Walls flat cell |
| Facade stone (cornice/pilaster) | `#516467` cool blue-grey | licensed Wall_Tiles flat cell |
| Storefront glass | `#8ac6e0` leaded panes | licensed Building_Walls glass cells |
| **ACCENT: coin-gold** | mid `#e1b12f` / `#d9a92f`, highlight `#fedb7e`–`#ffe29f`, shade `#8a6b1e` | OWNED PixelLab ornament props ONLY |
| Water (fountain) | `#4f9fe0` clear blue | OWNED fountain |

**Palette-quarantine check (bible discipline #2) — PASS, measured not
eyeballed:** coin-gold sits at hue ≈43° saturated yellow METAL.
Liscor's amber is hue ≈25° orange LIGHT (`#ff8c40` family, warm timber
`#6d533d`, warm plank floors); Pallass's forge-bronze is hue ≈31°
desaturated brown metal (`#b67d46` — this exact family EXISTS in the
Castle pack's trim cells at Tiles.png cols 10–11 rows 7–10 and is
therefore **banned from Invrisil picks**; noted in picks.md). No
shared accent hue. Invrisil's grounds are the COOLEST of the three
cities (grey-violet paving, blue-grey stone) so even the neutral
layers separate. Deliberate scarcity rule: gold appears only on
generated ornament props (signs, lamps, fountain, banner trim), never
as a tile fill — scarce gold is what makes it read as money.

## Landmark reads (first-time player, 2 seconds each)

1. **The Adventurer's Fountain** (plaza focal point, OWNED
   `fountain_v2.png` 80×96): two-tiered white marble, gold statue of
   a sword-raising adventurer — "this is the City of Adventurers."
   NOT canon-named (no canonical plaza fountain exists on the wiki
   page — original, canon-ALIGNED with the epithet; flag in handoff).
2. **The glass shopfront line**: continuous leaded-glass ground floor
   under cream plaster — "shops with GLASS = money" (canon: Invrisil
   markets sell magical items and wondrous things; the Cloth
   District / Satin's Way supports the fashion-forward storefront
   read — wiki.wanderinginn.com/Invrisil).
3. **Coin-gold shop signs + lamp row**: hanging coin-emblem boards and
   gold-capped lampposts repeating down the street — the transactional
   rhythm; nothing here is a neighbor's front door.

## Tile-family inventory

- **Floor — OWNED (committable, public-build-real):** PixelLab wang
  corner tileset `tileset_marble_wang4x4.png` (16 tiles, 16px,
  corner-id = NW·8+NE·4+SW·2+SE·1): lower=cool grey paving,
  upper=pale marble, engraved curb transitions. Boulevard carriageway
  = paving; plaza = marble with proper wang curb (mockup demonstrates
  the rounded corner). Alleys reuse the paving tile with the night
  mood card doing the darkening — same stone, meaner hour.
- **Walls/structures — LICENSED (manifest-only, picks.md):** facade
  built from ATOMIC pieces, not module crops: cream plaster fill +
  cool blue-grey stone fill (cornice band + 6px pilaster verticals
  every 3 cells — the spec's "vertical LINES") + leaded-glass pane
  fill for the ground floor + framed plate-window bay + wired `door`
  prop punched into the glass line. **Lesson recorded:** my first
  mockup used 6×7-cell "storefront module" region guesses from the
  numeric scan and they composed as autotile fragments — the atomic
  rebuild is the direction. Whole-module crops from Building_Walls
  are NOT usable without an in-editor read.
- **Decor/ornament — OWNED:** `streetlamp_v2.png` 32×64 (lamp rows ×8
  budget per spec — the light-anchor signature), `shop_sign_v2.png`
  32×32 (coin emblem, per-shop), `guild_banner_v2.png` 32×64 (cream +
  gold, hangs on facades). Licensed support: crate/barrel (already
  wired) stacked at alley mouths — CLIMBABLE flavor per spec, and the
  Brothers' parlor set (picks.md §3).
- **Scatter:** none on the boulevard (a moneyed street is SWEPT — the
  absence of Liscor's pebbles/mud is itself a texture read). Alleys
  get crate/barrel clusters instead of organic scatter.
- **Ambience/light notes:** lamp rows = warm gold PointLight2D pool
  chain (8 anchors, non-flicker — city lamps are SERVICED, unlike
  Liscor's flickering hearths; flicker in Invrisil would read poor).
  Dusk trick: facade glass rows get 2-3 warm interior-glow lights
  BEHIND the glass line ("wealth reads as light you can't afford" —
  the player walks in cool blue street light past windows full of
  warmth). Optional particle: none for v1 (crowd walk-ons are the
  boulevard's motion; particles would fight them).

## Mood-card DRAFT (values only — NOT wired; calibrate per pilot lessons)

- **boulevard "marble and coin":** day `[1,1,1]` identity (keep the
  hard zero-behavior-change floor unless the wiring pass proves
  Invrisil-only maps can carry a cool day tint safely) · dusk
  `[0.44, 0.48, 0.80]` (cooler-bluer than floodplains' `[0.45,0.50,
  0.92]` is NOT true — ours is darker+less blue-heavy: it must stay
  distinct from gate district's `[0.35,0.40,0.65]`; the gold lamp
  pools carry the evening) · night `[0.30, 0.34, 0.62]` · vignette
  `0.35` (below gate-district's 0.44 — Invrisil nights are LIT, not
  murky).
- **alleys "lantern maze":** dusk `[0.36, 0.40, 0.66]` · night
  `[0.22, 0.26, 0.46]` · vignette `0.48` — darker than the boulevard
  at every hour (the stealth playground needs shadow to sneak in);
  sparse fence-lantern anchors, wider gaps between pools than the
  boulevard's serviced rhythm.
- **parlor "borrowed elegance":** time-invariant warm-dim
  `[0.72, 0.62, 0.52]` · vignette `0.42` — candlelit shabby-gentility;
  one warm hero light over the card table, the good rug in its pool.

## Manifest entries required (licensed picks — controller lands these)

| Path | Pack | New? |
|---|---|---|
| `assets/props/free_pack/Building_Walls.png` | Free Pack 2.1 | already in manifest (facade_plaster) |
| `assets/tiles/free_pack/Wall_Tiles.png` | Free Pack 2.1 | already in manifest (biomes blocked) |
| `assets/props/free_pack/Furniture.png` | Free Pack 2.1 | already in manifest (door/crate/barrel) |
| `assets/props/free_pack/Interior_Props_01.png` | Free Pack 2.1 | already in manifest |
| `assets/tiles/library/Tiles.png` | Library | already in manifest (library_desk/shelf) |
| `assets/tiles/hideout/Tiles.png` | Hideout 1.0 | **NEW** (parlor walls/floor candidates) |
| `assets/props/sewer/Props.png` | Sewer | **NEW** (alley wall-lantern candidates) |

OWNED art (PixelLab, redistributable, needs NO manifest entry —
ships in the public repo as real files at wiring time): wang tileset,
fountain, streetlamp, shop sign, guild banner
(`potential_assets/pixellab_2026-07-07_invrisil/`).

## Self-review against the bible's disciplines

1. **Verb-first:** every surface above serves DEAL — glass display
   fronts, priced-looking signage, lamp rows that read as a service
   someone pays for, a plaza built to impress arrivals. No cozy
   surface anywhere; the one warm room (parlor) is warmth-as-brand. ✓
2. **Palette quarantine:** measured PASS above; Castle bronze-trim
   family explicitly banned; no warm-timber facade family used
   (that's Liscor's). ✓
3. **Population texture:** the direction assumes crowds (6-8 walk-on
   dressers per spec) as the boulevard's motion layer — art leaves
   the mid-street clear for them; not this lane's asset scope
   (character pipeline), flagged in handoff. ✓
4. **Traversal signature (alleys around fronts):** alley family =
   same paving + darker mood + crate stacks + sparse lanterns behind
   the glass line — the back-of-house world one wall away from
   ornament. ✓
5. **PC race read:** dialogue-lane concern, no art dependency. n/a
6. **Music keys:** strings-forward — audio out of this lane's scope,
   noted for wiring. n/a

Known honest gaps (recorded, not hidden): upper-floor windows were
dropped from the mockup (the `window_blue` prop read as dark slabs at
scale — a proper upper-window pick needs a windowed in-engine read);
the banner emblem reads "X" more than crossed-swords at 4×
(acceptable, re-roll queued in pixellab-batch.md); crate/barrel alley
dressing barely registers at postcard distance (fine — it's alley
content, not boulevard content).

## Canon citations

- wiki.wanderinginn.com/Invrisil — "City of Adventurers" (largest
  population of active and retired adventurers in Izril); markets of
  magical items; Cloth District / Satin's Way; first appearance ch.
  2.09 (Vol 2 — well inside the Book 17 bar).
- Spoiler check: no post-Book-17 element introduced; the Brothers
  (grandfathered 8c scope) appear in this lane only via the parlor
  interior direction, no named members referenced in art.
