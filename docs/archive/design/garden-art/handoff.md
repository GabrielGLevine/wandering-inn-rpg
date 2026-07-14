# Garden of Sanctuary — wiring handoff (post-Door)

For the future issue-#9 implementation task. Everything here is STAGED
ONLY — no data file in `wandering_inn_game/` was touched by this lane.
Hard prerequisite: issue #8's portal_menu machinery (the Garden is
reached through the awakened Door) and the ratified earn conditions
(spec §5: `act ≥ III` + K-of-N inn accomplishments; it is ERIN's Skill;
combat can never start on the garden map — sim guard, not convention).

## Staged biome fragment (`data/biomes.json`)

```json
"garden": {
  "sheet": "res://assets/tiles/garden/Tiles.png",
  "tile_px": 16,
  "floor": [0, 0],
  "blocked": [1, 8],
  "_comment_blocked": "trimmed-hedge top-face -- the Garden has NO wall family; the hedge hem IS the enclosure (sanctuary = absence of architecture).",
  "skirt_sheet": "res://assets/props/pixellab/sky_mist_final.png",
  "skirt_tile_px": 32,
  "skirt": [0, 0],
  "_comment_skirt": "THE IMPOSSIBLE SKY (spec 2/direction card): beyond the hedge there is no terrain, only bright glinting sky-mist -- the one map that floats. Owned PixelLab tile, committable to assets/."
}
```

Floor variants (grass B/C/D + sandstone path cells + flowerbed fills)
via `floor_layers` per the M5 E3 environment schema — exact cells in
`picks.md` §1/§1b/§1c.

## Staged mood fragment (`data/moods.json`) — the direction card's §Mood

```json
"garden": {
  "day":   [1.0, 1.0, 1.0],
  "dusk":  [1.0, 1.0, 1.0],
  "night": [1.0, 1.0, 1.0],
  "vignette": 0.0
}
```

- Verify `atmosphere.gd` treats a time-invariant IDENTITY pin correctly
  (issue #9's danger list already flags this — sewers/inn_upstairs prove
  invariant DARK pins; invariant identity should be the same code path,
  but prove it, don't assume).
- NO `arena_moods` entry, ever (combat impossible here).
- Zero PointLight2D, zero light budget spent. Ambience: petal drift =
  leaf preset recolored to `#8F024F` family, always-on at every phase
  (note: `light_energy_by_phase.day = 0.0` gates LIGHTS, not emitters —
  the sewers' always-on ambience is the precedent); hill mist = a slow
  white ground-fog emitter (nearest preset: sewers dust, recolored).

## Staged sprite fragments (`data/sprites.json`)

Owned (committable into `assets/`, e.g. `assets/props/pixellab/` —
sources in `potential_assets/pixellab_2026-07-07_garden/`):

```json
"garden_door_inner":   {"animations": {"default": {"sheet": "res://assets/props/pixellab/garden_door_v2.png", "frame_size": [34, 48], "fps": 0}}, "render_scale": 1.0, "shadow": true},
"memorial_plinth":     {"animations": {"default": {"sheet": "res://assets/props/pixellab/plinth_empty_stone.png", "frame_size": [32, 32], "fps": 0}}, "render_scale": 0.6},
"memorial_statue_human":  {"animations": {"default": {"sheet": "res://assets/props/pixellab/statue_human_stone.png",  "frame_size": [32, 48], "fps": 0}}, "render_scale": 0.5, "shadow": true},
"memorial_statue_gnoll":  {"animations": {"default": {"sheet": "res://assets/props/pixellab/statue_gnoll_v4_stone.png","frame_size": [32, 48], "fps": 0}}, "render_scale": 0.5, "shadow": true},
"memorial_statue_drake":  {"animations": {"default": {"sheet": "res://assets/props/pixellab/statue_drake_stone.png",  "frame_size": [32, 48], "fps": 0}}, "render_scale": 0.5, "shadow": true},
"memorial_statue_goblin": {"animations": {"default": {"sheet": "res://assets/props/pixellab/statue_goblin_v2_stone.png","frame_size": [32, 44], "fps": 0}}, "render_scale": 0.5, "shadow": true}
```

Licensed (manifest-first — the three NEW entries in picks.md — then
region crops; fallback placeholder keeps public boots clean):

```json
"garden_fountain_basin": {"animations": {"default": {"sheet": "res://assets/tiles/garden/Tiles.png", "region": [320, 80, 80, 78], "frame_size": [80, 78], "fps": 0}}, "render_scale": 1.0},
"garden_fountain_statue": {"animations": {"default": {"sheet": "res://assets/props/garden/Feminine-Idle-Sheet.png", "region": [24, 34, 16, 30], "frame_size": [16, 30], "fps": 0}}, "render_scale": 1.0}
```

(Cypresses, bench, lily pond, parterres: regions in picks.md §1c/§3.)
ALL PixelLab statue anchors: alpha-tight crops, feet plane ≈ frame
bottom, default `[0.5,1.0]` expected fine — but the ANCHOR RULE stands:
PIL-remeasure each final PNG + windowed adjacency screenshot before
done. Same for the fountain composite (a 5-cell prop; check the basin's
"feet" read).

## The memorial data seam (issue #9's "grows with story beats")

Direction card §memorial-vocabulary is the spec. Mechanically:
`visual_states` on plinth/statue entities keyed to accomplishment
counters (the dirty_table/unlit_lantern seam — already supports sprite
swap). Suggested map data shape: N memorial plots on the rise, each a
prop entity with `visual_states: [{when: "<counter>", sprite:
"memorial_statue_<race>"}]`, default sprite `memorial_plinth` for the
NEXT unclaimed plot and nothing for plots beyond it. Statue interact =
one `dialogue_line` remembrance (present tense, no numbers, no
progress). The scene-contract gotcha applies: test the WIRING (the beat
increments the counter AND the garden map's entity references it), not
just the seam.

## Composition (from the committed direction card + benchmark grammar)

Formal axis, south→north: vine door (the only entrance; pairs with the
inn-side door via the portal machinery) → sandstone path → statue-
fountain (basin + centerpiece) → the misted rise (memorial arc + the
waiting plinth). Mirrored wings: hedge-framed magenta parterres,
topiary cypresses, statue-island lily ponds (statue-in-water =
DRESSING grammar only). Rest-bed placement is the implementer's call —
recommend east wing, facing the rise (a bed under the open sky is the
"rest anywhere" read).

## Open questions / canon flags

1. **Memorial location** — this card puts remembrances on the misted
   rise (canon: the sacred hill, Ch. 7.11). The controller floated the
   benchmark's statue-in-water as the memorial grammar instead —
   overruled here (canon hill + the overnight/mist idiom needs dry
   ground), but it's a taste call the user may re-make.
2. **Canon simplification flag**: the wiki says the hill shows each
   VIEWER their own dead (7.11). The game shows one shared set (the
   inn's remembrances). Deliberate simplification — note it if a
   lore-precise player ever asks.
3. **Erin's presence** — whether Erin visibly appears in her own garden
   (a chair, her journal, herself on story beats) is a taste-gate item;
   queued PixelLab spec exists (pixellab-batch.md).
4. **The rise as a real mound** — the mockup fakes elevation with a
   radial light lift + mist. In-engine options: lighter-grass
   `floor_layers` ring + the mist emitter (cheap, recommended) vs. a
   real elevation illusion (not worth new machinery).
5. **Music**: recommend near-silence — wind, chimes, distant birdsong;
   no melody until a remembrance beat. (Bible discipline 6: the Garden's
   "key" is quiet.) Audio is out of this lane's scope.
6. **Hedge blocking** — the hem is `blocked` tiles, not walls.segments;
   confirm reachability QA treats the door gap as the single seam.
7. The unidentified large stone object `[338,388,78,92]` (arch?) needs
   a windowed read before anyone uses it.

## Where things live

- Owned art (committable): `potential_assets/pixellab_2026-07-07_garden/`
  → keeps listed in pixellab-batch.md; `stoneify.py` alongside (the
  remembrance recolor idiom — reusable).
- Licensed mockups (NEVER commit): same dir, `mockups/
  mockup_licensed_garden_320.png` + `_4x.png` — the user's taste-review
  surface for the full scene.
- Committed owned mockup: `docs/archive/design/garden-art/
  mockup_owned_memorial_vocab.png` (memorial vocabulary + roster).
