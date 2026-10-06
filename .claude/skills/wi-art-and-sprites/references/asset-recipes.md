# Asset recipes

## Selection and public fallbacks

The approved #564/#554 ruling is best art wins per asset within a coherent
scene. Compare candidates with co-visible materials, figures and UI at actual
gameplay scale in windowed official and public builds. Replace a licensed
primary only when the owned candidate reads better; otherwise keep the primary
and register the owned public fallback. READY is a candidate label, not runtime
acceptance. Preserve explicit rejections for weapon/facing/death discontinuity.

`fallback_sprite` selects a complete registry entry through
`WISpriteRegistry.resolved_id()`: if any primary animation sheet is unavailable,
all animations, frame geometry, scale and anchor come from the owned entry.
Targets must be public, one-hop and non-player-only; do not chain fallbacks or
use a `pc_*` target. A selected player rig is a direct primary registration.
Pin expected animation counts and measure alpha bounds before wiring it.

Terrain `fallback_render` is likewise a complete descriptor. Resolve original
biome/wall inheritance first, then replace render fields with the owned sheet,
unit, coordinates, scale, anchor, tone and optional underlay. Keep topology and
simulation properties. Owned Wang atlases use their own documented corner-bit
coordinates; UI regions and NinePatch margins come from the selected artwork.

Record target, winner, reason and both gameplay screenshots in the issue PR.
Append source/tool/prompt/hash provenance to the current license record, then
rebuild `docs/asset-candidates.*` with `python3 tools/asset_candidates.py` and
provider mirrors with `python3 scripts/sync_agent_guidance.py --write`.

## Registry

`data/sprites.json` entries may be static or directional. Directional
animations identify down/side/up sheets or regions; the fourth direction may
mirror side. Each animation records sheet/region, frame size, and frame timing.
`render_scale` adapts native art to world scale, `anchor` is a fraction of the
frame, and optional contact shadow supports tall objects. Read
`WISpriteRegistry` and sibling entries for exact current fields.

Find the lowest nontransparent row with an alpha-channel scan and set
`anchor.y = feet_plane / frame_height`, then confirm adjacency windowed. Register
every animation’s expected frame count in the sprite test. Distinct
`visual_states` use the current resolver’s `when` shape; windowed verification
is required because malformed conditions can silently show the base sprite.

## Generation when available

Character art must follow the profile’s species/palette/silhouette and deliver
directional animated sheets; static outputs are suitable for props. Generate a
small bounded candidate set, select by silhouette/readability at game scale,
and preserve prompt/tool/provenance in the project’s current license record.
Large landmarks benefit from a clear 3/4 top-down concept followed by true pixel
conversion; integrate at measured scale. One-shot scene images are look-dev or
flat set pieces, not replacements for grid/wall/entity map data.

Every generation batch lives in its own `potential_assets/<source>_<date>[/<lane>]/`
directory with a standard `MANIFEST.json` (schema in `tools/asset_candidates.py`:
path, kind, targets, verdict READY/USABLE-WITH-FIX/ALT/REJECTED, ids, prompt,
notes, rig feet plane, contact sheet). Record every kept output there as you
download it, then rebuild `docs/asset-candidates.*` with
`python3 tools/asset_candidates.py` so the next session's query finds it.
Never create `MANIFEST.json` beside a legacy lowercase `manifest.json`; macOS
treats them as one file.

Check current tool documentation/endpoints rather than relying on historic API
recipes. Never state that a generation service is connected until its callable
tool is visible in the session. Poll only with bounded attempts and keep raw
outputs outside tracked/public paths until licensing and selection are settled.
