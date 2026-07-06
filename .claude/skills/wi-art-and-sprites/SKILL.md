---
name: wi-art-and-sprites
description: Use when adding a sprite, icon, prop, or tile to the Wandering Inn RPG, picking an asset pack, choosing atlas regions/scale, or setting a sprite anchor in `data/sprites.json`.
---

# Art and Sprites

## Core principle
Content is data + codegen — no hand-authored `.tscn`. Every visual comes
from a `data/sprites.json` entry consumed by `WISpriteRegistry`
(presentation-only). **Every region/scale pick MUST be verified by a
windowed QA screenshot read by the controller** — text-guessed atlas
coordinates have been wrong repeatedly.

## The BINDING asset-discovery workflow — never skip a step
1. `docs/asset-catalog.md` — *qualitative*: which pack/family fits the
   entity, casting suggestions, licensing notes. Read first.
2. `docs/asset-index.md`/`.json` — *mechanical*: exact PNG paths, sheet
   dimensions, frame counts, once the catalog names the pack.
3. `docs/scene-assembly-guide.md` — layout/composition principles if
   building a whole scene, not one sprite.
4. `data/sprites.json` — what's already wired in; extend, don't re-derive.
**Never browse pack PNGs directly into context.**

## `sprites.json` record anatomy
| Field | Notes |
|---|---|
| `directional: true` | separate `sheet_down`/`side`/`up` per animation; side sheet mirrors for the 4th facing |
| `animations.<name>` | `{sheet \| sheet_down/side/up, frame_size:[w,h], fps}`; optional `region`/`region_down/side/up:[x,y,w,h]` crops a shared sheet |
| `render_scale` | downscales an oversized native sheet (e.g. `goblin_base: 0.09`) to the 16px world scale |
| `anchor:[x,y]` | ground-contact fraction of frame size; default `[0.5,1.0]` |
| `shadow: true` | registry emits a contact shadow underneath |

## THE ANCHOR RULE (a real, twice-costly bug)
Default anchor `[0.5,1.0]` feet-anchors the **frame bottom**, not the
figure's feet. A sheet with transparent padding under the figure (Body_A/
Citizen_F: 16px padding in a 64px frame, figure spans y 18-47) draws the
character a full cell above its logical cell — looks adjacent to a
door/prop but is physically a row off, so `interact` hits nothing.
Procedure: (1) measure the figure's bbox with a PIL alpha-channel scan
(lowest non-transparent row); (2) `anchor.y = feet_plane / frame_height`
(Body_A/Citizen_F ship `[0.5,0.75]` from ~47/64); (3) verify with a
windowed adjacency screenshot, don't trust the math alone.

## Style families — never mix inside one scene layer
| Family | Signature | Use |
|---|---|---|
| `PC16` (Pixel Crawler) | 16px grid, 64px frames, hard outline | world-art backbone |
| `CUSTOM-HD` (goblins) | 256-640px native, soft/painterly | downscaled via `render_scale` next to PC16 — proven (goblins, bat) |
| `ADMURIN` | chibi ~16-24px in 32/64px frames | skill icons, font, iconography, monsters — softer hand, keep in own encounters; no-AI-training clause (ship rendered OK) |
| `TS-CARTOON` (Tiny Swords) | chunky ~192px cartoon | UI chrome + cropped VFX ONLY — clashes as world art |
| `PIXELLAB-AI` (Relc) | 128px, 8 static rotations, zero animation | provisional, unverified scale, not yet wired |

## Props-over-tiles (user-mandated, repo-wide)
Furniture/barricade/obstacle objects use **prop sprites** (`table_brown`,
`dirty_table`, `door`), never a recolored environment tile — applies to
combat cover as much as world dressing.

## Max fidelity always (user-mandated 2026-07-04)
Incremental work ships at the highest fidelity available NOW: pick the
best-candidate sprite from in-hand packs — never a rectangle, never a
bare recolor standing in for a real thing. If the true asset doesn't
exist, choose the closest semantic match AND log it in
`docs/VISUAL-LOG.md` (the repo-level visual-fix log every milestone
drains). Semantic mismatches between label and art (a "Sewer Grate" that
looks like a boulder) go in the log too.

## Interactables must read at a glance
A prop should fill most of its cell or carry a marker — check against a
windowed screenshot, not just "is the region correct" (a 9x14px
`unlit_lantern` is a known-thin case).

## Licenses
`potential_assets/` — gitignored, **never commit**; packs there are
user-attested fully licensed (standing decision). Curated extracts ship in
`assets/`, notes in `assets/LICENSES/`. Two nuances (neither blocks use):
Admurin's Freebies (no-AI-training clause); Super Dialogue Audio Pack (CC
BY 4.0, credit Dillon Becker if shipped).

## Example: adding a new prop
Catalog → pick pack/entity → index for exact path/dims → add a
`sprites.json` entry (`sheet`, `region`, `frame_size`, `render_scale` if
oversized, `shadow: true` if taller than 1 cell — see `barrel`/`crate`/
`boulder`) → wire into a map's `entities`/`decor`/`scatter` in
`skeleton_scene.json` → `run_qa.sh <script> windowed` and READ the
screenshot before calling it done.

## Common mistakes
Skipping the anchor measurement on a sheet with under-figure padding
(reproduces the Body_A bug); trusting text-guessed atlas coordinates
without a screenshot; mixing style families in one layer; recoloring a
tile instead of using a real prop sprite; browsing raw PNGs into context;
forgetting the STR/DEX-hidden and canon-name rules apply to any new
player-facing label (tooltips, hover text).

## Cross-references
`wi-verifying-changes` (screenshot requirement, gate table),
`wi-adding-a-class-or-skill` (skill `icon` ids resolve through this same
file), `wi-adding-dialogue-and-quests` (NPC sprites referenced by
conversation entities).

## PixelLab AI generation (proven pipeline, 2026-07-06)
Key `docs/pixellab_api_key.txt` (gitignored); free tier generates at $0
balance. Endpoints (api.pixellab.ai/v1 + openapi.json): POST
`/generate-image-pixflux` `{"description", "image_size":{"width":64,
"height":64}, "no_background": true}` → `{"image":{"base64"}}`;
`/animate-with-text` (holds identity at 64px — walk/cast cycles);
`/inpaint` (dress/modify EXISTING frames — preserves geometry/anchors;
the PC-outfit path); `/rotate` (**DRIFTS identity at 64px** — doubled
Relc's spear; avoid, ship non-directional instead: consumers fall back
idle_down→idle cleanly). Style prompt kernel: "top-down RPG sprite,
hard black outline, 16-bit"; `view:"high top-down"` = flat overhead
(flat-swap props), `"low top-down"` = 3/4 iso (standing objects/chars).
≤6 candidates per subject, stop on pass; park rejects in
potential_assets/pixellab_<date>/. Outputs are user-owned +
redistributable (ToS verified) — TIER-PUBLIC, note provenance in
assets/LICENSES/pixellab-ai-generated-verdict.md.

## combat_scale (the Relc lesson, 2026-07-06)
A tall field sprite can sprawl over combat neighbours' bars —
`combatants.json` supports per-combatant `combat_scale` (combat visuals
only; field keeps the canon-tall render_scale). Contained bar ≈ ≤1.6
cells, feet-anchored so overlap goes UP into air.

## Two-tier licensing (user policy 2026-07-06)
NOTHING is excluded from the GAME: redistribution-limited packs (incl.
non-commercial tiers like Cute Fantasy Free) ship in official builds
via the PRIVATE BUNDLE (assets_manifest.json bundle:true); only the
PUBLIC REPO excludes them (fallback art/silence). Flag any quality
DOWNGRADE-for-licensing to the user BEFORE substituting — the better
asset stays in the game via the bundle (the E1 Kenney-swap got
flagged retroactively; don't repeat).

## PixelLab v2 API (user-surfaced 2026-07-06 — SUPERSEDES v1 for characters)
Base https://api.pixellab.ai/v2 (same Bearer; openapi at /v2/openapi.json;
most endpoints ASYNC — poll GET /background-jobs/{job_id}). Game-changers
vs v1: `POST /create-character-with-4-directions` (consistent 4-dir —
KILLS the v1 /rotate drift problem; 8-dir + -pro + -v3 variants exist),
`POST /animate-character` (animate an existing character id),
`POST /transfer-outfit-v2` (outfit between characters), `POST /inpaint-v3`,
tileset generation (`/create-tileset` top-down!), `GET /characters/{id}/zip`
(full bundle export), `GET /balance`. User holds a PAID SUBSCRIPTION (2026-07-06): Pro endpoints
(create-character-pro/-v3, transfer-outfit-v2, inpaint-v3,
interpolation-v2) are available — use the best tool, don't ration. Prefer v2 character endpoints for ALL new
character work; v1 recipes above remain valid for quick 1-frame props.

## CHARACTER SPRITES = v2 character pipeline (USER DIRECTIVE 2026-07-06)
All character work produces WORKING SPRITES (directional + animated),
never static single-facings: `/v2/create-character-with-8-directions`
(or -pro/-v3) → `/v2/animate-character` (walk + combat set) →
`/v2/characters/{id}/zip`. Map onto sprites.json directional shape
(keep 4 of 8 facings; side mirrors; park diagonals). Statics are
acceptable only for PROPS. The existing non-directional integrations
(relc, pisces, olesm, zevara) are UPGRADE-QUEUE items under this
directive.

## Generation prompts derive from character profiles (2026-07-06)
`docs/design/character-profiles.md` carries each character's species/
palette/silhouette contract — PixelLab prompts MUST be written from the
profile (and the profile wiki-verified first). A generated sprite
contradicting its profile fails the read regardless of quality.
