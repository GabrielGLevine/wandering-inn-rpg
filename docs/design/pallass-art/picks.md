# PALLASS — licensed-pack picks (PIL-measured, 2026-07-07)

Method (binding, wi-art-and-sprites discipline): every region below
comes from a numeric PIL scan — 16px-cell mean-RGB + luminance-stddev
clustering. **No pack PNG was rendered or viewed.** These are
CANDIDATES, not verified picks: whoever wires a region into
`sprites.json`/`biomes.json` must confirm it with a windowed QA
screenshot first (the 8a-asset-assembly precedent and format).

All Pixel Crawler picks: license verdict **FORBIDDEN** for the public
repo (non-redistributable) — manifest-only entries (`bundle: true`,
`fallback: "placeholder"`); they ship in official builds via the
private bundle. Nothing extracted or committed this pass.

Role note: with the PixelLab engineered-masonry families OWNED and
committable (see `pixellab-batch.md`), these licensed picks are
*bundle-tier reinforcements and alts*, not the primary tile families —
the inverse of the usual pack-first posture, because Drake-scale
industrial masonry doesn't exist in any in-hand pack (catalog gap
confirmed: Forge pack is "dwarven-foundry hellscape", warm red brick,
no cool slate anywhere in its sheet).

## 1. Forge tier — molten channel + dark brick (Pixel Crawler - Forge 1.2)

Sheet: `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png`
(400×400, 16px grid). The molten block occupies cols 19–24, rows 13–24.

| Candidate | Native px region `[x,y,w,h]` | col,row | Notes |
|---|---|---|---|
| Molten fill (primary) | `[320,224,16,16]` | (20,14) | Perfectly flat (std 0.0) `rgb(246,85,16)` — the pure molten-metal fill; repeats at (20,17), (20,20), (20,23) |
| Molten edge A | `[352,208,16,16]` | (22,13) | `rgb(240,97,27)` std 25.9 — channel rim variant |
| Molten edge B | `[304,208,16,16]` | (19,13) | `rgb(184,89,41)` std 51.5 — high-contrast bank/edge |
| Dark brick fill | `[32,32,16,16]` | (2,2) | Flat (std 0.0) `rgb(41,16,19)` — dark maroon brick fill; block spans (1,1)–(3,3) |
| Mauve floor fill | `[32,128,16,16]` | (2,8) | Near-flat (std 2.8) `rgb(72,41,56)` — the pack's floor family (rows 7–9, mauve-purple); alt walkable fill |
| Warm-pink stone (alt) | `[80,160,16,16]` | (5,10) | `rgb(90,59,62)` std 3.4 — lighter floor variant, rows 10–12 family |

Caution: the whole Forge sheet is WARM (red/maroon/orange) — usable
only on the forge tier band, never the market tier (palette
quarantine, see direction.md). The PixelLab `tileset_brick_over_molten`
family is the committable primary; these are its bundle-tier
upgrades/mix-ins (the pack's molten `rgb(246,85,16)` is redder and
closer to the ratified furnace-glow hex than the generated lava —
prefer it in-bundle where a flat fill is needed).

**Manifest entry required (NEW):** `assets/tiles/forge/Tiles.png`.

## 2. Market tier — slate checker floor alt (Pixel Crawler - Castle Environment 0.3)

Sheet: `.../Assets/Tiles.png` (416×400, 16px grid) — already in the
manifest as `assets/tiles/castle/Tiles.png` (8a), no new entry needed.
Two interleaved cool families in the block cols 12–17, rows 17–22:

| Candidate | Native px region `[x,y,w,h]` | col,row | Notes |
|---|---|---|---|
| Blue-slate checker (primary alt) | `[256,288,16,16]` | (16,18) | `rgb(35,44,59)` std 3.8 — flat cool slate; family at (15–17, 17–22) |
| Purple-slate checker | `[208,288,16,16]` | (13,18) | `rgb(45,39,68)` std 7.2 — the checkered partner family (12–14, 17–22) |

Use: interior floors (lift office, guild halls, clerk desks) where
the PixelLab slab family would be too plaza-like; also the closest
licensed match to the ratified slate row (`#212836`/`#39424E`).
These cells sit inside a multi-cell checkered-floor structure — the
windowed check must confirm they tile cleanly in isolation.

## 3. Under-tier shadow (Pixel Crawler - Cave)

Sheet: `.../Assets/Tiles.png` (272×304, 16px grid) — already wired in
`biomes.json` (`cave` entry), no new manifest entry.

| Candidate | Native px region | col,row | Notes |
|---|---|---|---|
| Dark void fill | `[32,32,16,16]` | (2,2) | Flat (std 0.0) `rgb(28,29,19)` — the existing cave `blocked:[2,3]` family; pure-dark under-tier fill if the PixelLab void tiles read too busy at 1× |

Note: the Cave dark leans warm-olive; the PixelLab void
(`#000018`–`#181860`, cool navy with faint glints) is the better
palette fit — Cave is the fallback only.

## 4. Explicitly rejected

- **Forge pack as market-tier source** — warm palette collides with
  the slate field; rejected on quarantine grounds.
- **Cemetery/Free Pack stone walls** for the rising tier wall — hand-
  laid rustic masonry reads "old stone town", not engineered; the
  bible demands "engineered, not laid". PixelLab `prop_tier_wall`
  instead.
- **Cute_Fantasy_Free** — FORBIDDEN source (non-commercial tier),
  charter rail; not scanned.
- **Anvils/props from Forge sheet** — no isolated props sheet exists
  in the pack (single Tiles.png; embedded objects are baked into
  multi-cell arrangements); a windowed read would be needed to crop
  them, and the PixelLab forge-station prop covers the role. Deferred
  unless the wiring pass wants a bundle-tier upgrade.
