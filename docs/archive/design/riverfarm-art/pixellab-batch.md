# Riverfarm — PixelLab generation batch log (2026-07-07)

Lane budget: ≤35 generations. **Spent: 16 accepted job submissions**
(429-rejected submits consumed nothing; counted by MY submissions per the
shared-account ops note — balance deltas are polluted by sibling lanes).
Account balance readings: 752 generations remaining at lane start,
707 at lane end (2000 total, Tier 1 — pool shared with sibling lanes the
whole time). Raw outputs + `manifest.json` (prompt+params per file) +
driver (`rf_gen.py`) + fetcher (`rf_fetch.py`) + mockup composer
(`rf_mockup.py`) live in the gitignored central cache:
`potential_assets/pixellab_2026-07-07_riverfarm/`.

Ops lesson (inherited mid-lane): Tier 1 caps 8 concurrent background jobs
ACCOUNT-WIDE — submit sequentially; my wave-1 parallel batch hit 429s and
was resubmitted with backoff.

All outputs: user-owned + redistributable (TIER-PUBLIC) — committable at
wiring time with a provenance note in
`assets/LICENSES/pixellab-ai-generated-verdict.md`.

Shared prompt kernel: `"16-bit pixel art, hard dark outline"` (PC16-match
per wi-art-and-sprites); structures at `view: "low top-down"`, flat-swap
water objects at `"high top-down"`; all at final native pixel size (16px
world density — no downstream render_scale needed).

## Fired

| # | Name | Endpoint | Size | Verdict |
|---|---|---|---|---|
| 1 | `tileset_wheat_over_loam` | /create-tileset | 16px wang (16 tiles) | **KEEP** — matte gold `#d8c060` wheat over `#603030` loam; corner bits SE=1/SW=2/NE=4/NW=8 (from tileset metadata `corners`); tile 0 doubles as the tilled-plot loam base. Assembled 4x4 sheet id-row-major in cache. |
| 2 | `prop_cottage_thatch_a` | /map-objects | 64x64 | **KEEP** — golden thatch, clay-daub timber frame, warm window; THE village house. |
| 3 | `prop_cottage_thatch_b` | /map-objects | 64x64 | **KEEP** — steeper whitewashed variant; second silhouette so houses don't clone. |
| 4 | `prop_longhouse_thatch` | /map-objects | 112x64 | **KEEP** — one long thatch ridge; communal center. Door read at 16px needs the windowed check. |
| 5 | `prop_windmill` | /map-objects | 64x96 | **KEEP** — wood tower, 4 sails, fieldstone base; the 2-second landmark. |
| 6 | `prop_haystack` | /map-objects | 32x32 | **KEEP**. |
| 7 | `prop_scarecrow` | /map-objects | 32x48 | **KEEP** — cross-pole, sack head, floppy hat. |
| 8 | `prop_earthwork_rampart` | /map-objects | 112x32 | **KEEP** (north-edge dressing) — reads slightly wall-like up close; fine as edge dressing, retry only if the windowed check disagrees. |
| 9 | `prop_witch_cottage` | /map-objects | 80x80 | **KEEP** — mossy sagging roof, crooked chimney, warm windows. Note: multiple windows glow at native; the "ONE warm light" is enforced by the mood grade + a single PointLight2D at wiring. |
| 10 | `prop_village_well` | /map-objects | 32x40 | **KEEP** — fieldstone well, thatch cap. |
| 11 | `prop_fence_h` | /map-objects | 48x32 | **REJECT** (kept in cache) — flat grey rails, reads metallic. |
| 12 | `prop_fence_v` | /map-objects | 32x48 | **KEEP** — front-face post-and-rail; THE east-west fence segment. |
| 13 | `prop_fence_ns` | /map-objects | 32x64 | **KEEP** — overhead post column for north-south runs; slightly ladder-like, verify in a windowed run. |
| 14 | `prop_dock_pier` | /map-objects | 32x48 | **REJECT** — came out as a purple totem (file kept as `*_REJECT.png`). |
| 15 | `prop_rowboat` | /map-objects | 32x48 | **KEEP** — clean overhead rowboat. |
| 16 | `prop_dock_pier2` | /map-objects | 32x64 | **KEEP** — plank jetty, reads as dock beside the boat/water. |

## Queued — deliberately NOT spent this lane (19 budget headroom left)

- **The Witch / headman / charmed villager sprites** — character work is
  profile-gated (spec §2 "profiles-first"; wi-art-and-sprites: prompts
  MUST derive from wiki-verified `character-profiles.md` entries, and
  characters use the v2 create-character-with-8-directions → animate →
  zip pipeline, ~heavier spend). Content-time. The witch's two idle
  variants (elderly-by-day/young-by-dusk via visual_states) will need
  TWO character states — budget ~8-12 gens in the 8b content lane.
- **Briar collector combatant (2 variants)** — new plant-class combatant
  (spec §5); needs encounter design first (arena, silhouette
  distinctness vs Fungus crew). Suggested kernel: "animated briar
  bramble creature, thorned vine limbs, dark green + wound-red berries".
- **Wheat-sway animation frames** — juice; possible /animate-with-text
  pass over the field tile or a shader at wiring. VISUAL-LOG item.
- **Windmill sail animation** — option A: /animate-with-text on the
  windmill; option B: Ninja Adventure `MillPropeller_A_64x64.png`
  (CC0, 4-frame) as an overlay — style-seam risk, test only if free.
- **Village gate / palisade section** — if the wiring pass wants the
  north rampart to have a gate interaction.
- **Hollow ritual-stone unique centerpiece** — Fairy Forest stones cover
  the ring; a bespoke "knotted threshold stone" only if [Observe]'s
  "true knot" needs a distinct interactable sprite.
