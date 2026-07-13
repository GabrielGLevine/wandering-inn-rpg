extends SceneTree
## tools/scene_dynamism.gd -- Issue #73: scene-dynamism score.
##
## A measurable 0-100 composite score for a map's visual dynamism, so a
## less-intuitive model/subagent can tell "undifferentiated brown box"
## (the pre-#49 Brothers' Hideout) apart from a dressed scene BEFORE a
## human windowed read. Pure reads of data/skeleton_scene.json,
## data/sprites.json, data/moods.json, data/biomes.json, and the
## repo-root docs/asset-index.json -- writes nothing but the report file
## below. Report + soft floor, NOT a CI gate (taste isn't pass/fail).
##
## USAGE
##   godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd
##     -> prints the scorecard table, regenerates docs/design/scene-dynamism-report.md
##        (deterministic: stable sort, no timestamps -- safe to diff in review).
##   godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd -- --calibration
##     -> ALSO scores tools/calibration/brothers_parlor_prefeedback.json (the
##        pre-#49 parlor, injected as a 20th scene under its own biome so the
##        historical Library-pack floor pick isn't clobbered by the since-fixed
##        current `brothers_parlor` biome entry) and prints the calibration
##        verdict table. Never writes the report file in this mode.
##
## PROPOSED wi-adding-a-scene ADDITION (controller-only file; paragraph parked
## here per dispatch instructions -- see docs/design/scene-dynamism-report.md's
## own "Usage" section for the same text, which IS committed):
##   Score every new/edited map with the command above before calling a scene
##   done. New scenes should target composite >=50; the component breakdown
##   tells you WHAT to add -- low internal variety means pull decor from more
##   than one asset-pack family (not just more decor from the SAME family);
##   low composition means add an off-center focal light/prop and dress the
##   border band, not just the dead center; low cross-scene distinctiveness
##   means the biome/sprite picks read like a different region entirely (the
##   brothers_parlor pre-#49 smell: it borrowed the inn's exact floor tile).
##   Scores under 30 print a loud advisory -- treat that as a near-certain
##   brown box and fix before spending a windowed screenshot on it.
##
## FAMILY DERIVATION RULE (the one mechanical rule this whole tool leans on)
##   Every sprite/tile sheet path is `res://assets/<A>/<B>/<file>`. A
##   sprite/tile's PACK FAMILY = "<A>/<B>" (the first two path segments under
##   assets/, e.g. "props/free_pack", "tiles/cave", "sprites/pc_gnoll_m").
##   This is a coarser signal than the true source pack for character rigs
##   (assets/sprites/<name>/ is one directory PER CHARACTER, not per pack --
##   `pc_gnoll_m` and `relc` both trace back to the same donor pack but read
##   as two families here) but it is exactly derivable from data alone (no
##   dependency on tools/sync_assets.py's manifest or docs/asset-index.json's
##   pack census, which don't cover every asset), and it is the RIGHT
##   granularity for assets/props/* and assets/tiles/* -- those subdirectories
##   ARE one per source pack (props/cave, tiles/cemetery, tiles/garden, ...),
##   which is exactly the "6 sprites from one pack < 6 from 3 packs" signal
##   component 1 wants. Documented once here rather than re-derived per call.
##
## REGION GROUPS (cross-scene distinctiveness's grouping table -- assign
## every CURRENT map; an unrecognized future map name defaults to its own
## singleton group and prints a report note instead of crashing)
##   liscor:    street, floodplains, sewers, deep_tunnels, ruin_surface
##              (Liscor city + its exterior/tunnel environs)
##   riverfarm: riverfarm_village, riverfarm_longhouse, witch_hollow
##   invrisil:  invrisil_boulevard, mercantile_alleys, brothers_parlor
##   dungeon:   dungeon_approach, trapped_halls
##   interiors: inn, inn_upstairs, guild, barracks, runners_guild
##              (every one of these shares the Free Pack Interior_Walls/
##              Furniture family -- the generic "indoor room" visual language)
##   garden_sanctuary gets its OWN singleton group ("sanctuary"), not
##   "interiors": it is the one interior built entirely from a distinct,
##   owned PixelLab garden pack with zero Free-Pack furniture -- forcing it
##   into "interiors" would punish it for NOT resembling the inn/guild/
##   barracks, which is backwards (that distinctness is the point). A
##   singleton group's in-region similarity check is N/A (no siblings to
##   compare against), not a failure -- see the neutral-credit note in
##   _score_all().
##
## THE FIVE COMPONENTS + FINAL WEIGHTS (kept at the spec's starting 30/25/
## 25/10/10 top-level split -- the calibration contract below was satisfied
## by tuning each component's INTERNAL sub-signal formulas, never the
## headline split, so the spec's own percentages stand as shipped):
##   1. Internal variety (30, `_score_variety`): sprite density
##      (sqrt(walkable_area)-normalized, not raw-area -- raw-area punishes
##      small rooms into needing near-zero decor and rewards huge empty
##      rooms for having "room to spare"), per-family spread ratio
##      (family_count/sprite_count -- THE "one pack vs three packs" signal,
##      weighted highest inside this component on purpose), floor tile
##      family count, scatter pool diversity, light+ambience budget
##      utilization, and RAW decor+entity item count (a small room can nail
##      every density/spread ratio with 2 well-chosen sprites and still read
##      sparse to a human -- this sub-signal is what actually separates
##      brothers_parlor's 5-6 total items from the rest of the roster and is
##      what pushes the calibration contract's bottom-decile requirement
##      home; capped at a modest target of 8 items so small-but-adequately-
##      dressed rooms like garden_sanctuary/runners_guild aren't penalized
##      just for being small).
##   2. Cross-scene distinctiveness (25, `_score_distinctiveness`): Jaccard
##      similarity of {placed sprite ids} u {tile families} u {mood-grade
##      bucket} against every OTHER scored scene, split in-region vs
##      cross-region. In-region rewards the 0.4-0.7 band but floors at 0.55
##      credit below it (a scene sharing nothing with its siblings is a
##      softer smell than one impersonating a DIFFERENT region) --
##      cross-region rewards <0.3 and falls off faster with a 0 floor (the
##      actual "brown box" tell: brothers_parlor's pre-#49 wall pick was the
##      SAME family as the inn's, a cross-region collision). Weighted 0.6
##      cross / 0.4 in-region for that reason. A singleton region group gets
##      flat 0.85 in-region credit (N/A, not a failure).
##   3. Composition best-practices (25, `_score_composition`): off-center
##      focal point (a light or a >=2-cell-footprint prop, verified off dead
##      center); border-vs-interior framing DENSITY RATIO computed over
##      decor + non-door entities only (doors sit on the border by
##      construction in every map -- including them would trivially max this
##      sub-score for any sparsely-dressed room and carry zero signal, so
##      they're excluded; a 2-cell border band, not 1, since framing props
##      commonly sit one cell off the wall, not glued to it); walkable-open
##      occupied-fraction healthy band (8%-35%, spec's own clutter guard);
##      position variance via distinct-rows+cols/2*item_count (grid-aligned
##      rows read as symmetric/lazy, spread positions read as authored);
##      accent contrast (a light's warm/cool bucket vs the scene's own
##      mood-grade bucket).
##   4. Asset utilization (10, `_score_utilization`): PER-SCENE score is
##      novelty only -- fraction of this scene's placed (decor+entity, not
##      scatter) sprite ids that appear on NO other scored scene. The
##      "what fraction of the catalog's families has the repo used anywhere"
##      half of this component is a REPO-LEVEL line (see
##      `_compute_catalog_family_coverage`), reported once in the report
##      header, not folded into any single scene's composite (spec's own
##      "not per-scene" instruction).
##   5. Clutter penalty (10, subtractive, `_score_clutter`): scatter spec
##      density over an authored 0.15 cap; more than the already-asserted
##      8-light budget; 3+ decor entries stacked on one cell (2-layer
##      composites like a fountain basin+statue, or a table+its own light,
##      are normal authoring and are NOT penalized -- only 3+ is treated as
##      likely mis-authoring).
##
## CONTENT-FLOOR GATE (applied to the composite AFTER components 1-5, in
## `_score_all`): a totally empty room trivially MAXIMIZES component 2 --
## an empty content set shares nothing with anything, which a pure Jaccard
## measure rewards as if it were a deliberate stylistic choice, not a stub.
## Caught during calibration: a synthetic 1-item empty box (border walls +
## one door, nothing else) scored ~48/100 and never tripped the <30
## advisory. The composite is multiplied by min(1, (decor_count+
## entity_count)/5.0) -- every real current map already carries >=5 items
## (untouched by this gate); only genuine stub content is pulled down (the
## same synthetic empty box now scores ~10/100).
##
## CALIBRATION CONTRACT (issue #73's own verification -- run with
## --calibration to reproduce): scored against the full 19-map roster plus
## the injected tools/calibration/brothers_parlor_prefeedback.json (the
## parlor as of commit 422e788, before ANY of the #49 window/bench dressing
## wave -- see that file's header for the exact git provenance)...
##   - pre-#49 brothers_parlor MUST land in the bottom decile.       -> PASS
##   - street (the gate plaza's own map), garden_sanctuary, and inn
##     MUST land in the upper half.                                  -> PASS
##   - no obvious pair inverted (current brothers_parlor outscores its
##     own pre-#49 self; no near-empty map outranks a densely-dressed one
##     by a margin that would read as broken to a human).             -> held
## Full numeric table: run with --calibration, or see the task report.
##
## NON-GOALS (spec's own list, repeated so a future editor doesn't "fix" a
## gap that was never in scope): no pixel-level palette analysis (families +
## mood-grade buckets are the proxy); no combat-arena scoring; no auto-fix.

const REGION_GROUPS := {
	"inn": "interiors", "inn_upstairs": "interiors", "guild": "interiors",
	"barracks": "interiors", "runners_guild": "interiors",
	"garden_sanctuary": "sanctuary",
	"street": "liscor", "floodplains": "liscor", "sewers": "liscor",
	"deep_tunnels": "liscor", "ruin_surface": "liscor",
	"riverfarm_village": "riverfarm", "riverfarm_longhouse": "riverfarm", "witch_hollow": "riverfarm",
	"invrisil_boulevard": "invrisil", "mercantile_alleys": "invrisil", "brothers_parlor": "invrisil",
	"dungeon_approach": "dungeon", "trapped_halls": "dungeon",
	"pallass_market": "pallass", "pallass_forge": "pallass",
}

## moods.json keys the map name verbatim except this one mismatch.
const MOOD_NAME_MAP := {"garden_sanctuary": "garden"}

const ADVISORY_FLOOR := 30.0
const CALIBRATION_MAP_ID := "brothers_parlor_prefeedback"
const REPORT_PATH := "res://docs/design/scene-dynamism-report.md"
const SCATTER_DENSITY_CAP := 0.15  # authored per-spec density cap (component 5)

var skeleton_data: Dictionary
var sprites_data: Dictionary
var moods_data: Dictionary
var biomes_data: Dictionary
var asset_index_data: Dictionary
var repo_root: String

var _family_cache: Dictionary = {}
var _unassigned_regions: Array = []


func _init() -> void:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	repo_root = project_root.get_base_dir()

	skeleton_data = WISceneCatalog.compose()
	sprites_data = _load_json_res("res://data/sprites.json")
	moods_data = _load_json_res("res://data/moods.json")
	biomes_data = _load_json_res("res://data/biomes.json")
	var asset_index_path := repo_root.path_join("docs/asset-index.json")
	asset_index_data = _load_json_abs(asset_index_path)
	if asset_index_data.is_empty():
		push_error("STOP: docs/asset-index.json missing or empty at %s -- component 4's repo-level line cannot be computed." % asset_index_path)
		quit(1)
		return

	var calibration: bool = OS.get_cmdline_user_args().has("--calibration")

	var maps: Dictionary = skeleton_data.get("maps", {})
	var analyzed: Dictionary = {}
	for map_name: String in maps:
		analyzed[map_name] = _analyze_map(map_name, maps[map_name])

	if calibration:
		var calib_map: Dictionary = _load_json_res("res://tools/calibration/brothers_parlor_prefeedback.json")
		var calib_biome: Dictionary = _load_json_res("res://tools/calibration/brothers_parlor_prefeedback_biome.json")
		biomes_data[CALIBRATION_MAP_ID] = calib_biome
		analyzed[CALIBRATION_MAP_ID] = _analyze_map(CALIBRATION_MAP_ID, calib_map)

	var results: Dictionary = _score_all(analyzed)

	_print_table(results, analyzed, calibration)

	if calibration:
		_print_calibration_verdict(results)
	else:
		var report := _build_report(results, analyzed)
		var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		f.store_string(report)
		f.close()
		print("\nWrote %s" % REPORT_PATH)

	quit()


# ---------------------------------------------------------------- loading --

func _load_json_res(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		push_error("Could not read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	return parsed as Dictionary if parsed is Dictionary else {}


func _load_json_abs(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed as Dictionary if parsed is Dictionary else {}


# ------------------------------------------------------------- families --

## "res://assets/<A>/<B>/<file>" -> "<A>/<B>". Returns "" if the path
## doesn't contain an assets/ segment with at least two path parts after it.
func _family_from_path(path: String) -> String:
	var marker := "assets/"
	var idx := path.find(marker)
	if idx == -1:
		return ""
	var rest := path.substr(idx + marker.length())
	var parts := rest.split("/")
	if parts.size() < 2:
		return parts[0] if parts.size() == 1 else ""
	return "%s/%s" % [parts[0], parts[1]]


## Resolves a sprite id (data/sprites.json key) to its PACK FAMILY by
## scanning every animation's sheet path(s) for the first one found
## (directional sprites carry sheet_down/sheet_side/sheet_up -- any one
## resolves the same family since a rig's directions always share a pack).
func _sprite_family(sprite_id: String) -> String:
	if _family_cache.has(sprite_id):
		return _family_cache[sprite_id]
	var fam := ""
	var entry: Dictionary = sprites_data.get(sprite_id, {})
	var anims: Dictionary = entry.get("animations", {})
	for anim_name: String in anims:
		var anim: Dictionary = anims[anim_name]
		for key: String in anim:
			if key.contains("sheet") and anim[key] is String:
				fam = _family_from_path(anim[key])
				break
		if fam != "":
			break
	_family_cache[sprite_id] = fam
	return fam


## Native pixel footprint of a sprite's idle frame, in CELL units (16px/
## cell), after render_scale. Used only for the composition component's
## "big prop" focal-point heuristic -- a coarse proxy, not exact collision.
func _sprite_frame_area(sprite_id: String) -> float:
	var entry: Dictionary = sprites_data.get(sprite_id, {})
	var anims: Dictionary = entry.get("animations", {})
	if anims.is_empty():
		return 0.0
	var idle: Dictionary = anims.get("idle", anims.values()[0])
	var fs: Array = idle.get("frame_size", [])
	if fs.size() < 2:
		return 0.0
	var scale: float = entry.get("render_scale", 1.0)
	var w: float = float(fs[0]) * scale
	var h: float = float(fs[1]) * scale
	return (w / 16.0) * (h / 16.0)


# ---------------------------------------------------------------- walls --

## Mirrors WIGame.segment_cells (src/core/wi_game.gd) -- reimplemented here
## rather than imported: tools sit outside the sim purity boundary either
## way (no autoload/scene-tree deps to protect), and this keeps the tool a
## single self-contained file. Inclusive rect spanned by from/to.
func _segment_cells(seg: Dictionary) -> Array:
	var out: Array = []
	var from_raw: Array = seg.get("from", [])
	var to_raw: Array = seg.get("to", from_raw)
	if from_raw.size() < 2 or to_raw.size() < 2:
		return out
	var lo_x: int = mini(int(from_raw[0]), int(to_raw[0]))
	var hi_x: int = maxi(int(from_raw[0]), int(to_raw[0]))
	var lo_y: int = mini(int(from_raw[1]), int(to_raw[1]))
	var hi_y: int = maxi(int(from_raw[1]), int(to_raw[1]))
	for x in range(lo_x, hi_x + 1):
		for y in range(lo_y, hi_y + 1):
			out.append(Vector2i(x, y))
	return out


# ---------------------------------------------------------------- mood --

func _mood_bucket(map_name: String) -> String:
	var base := map_name.trim_suffix("_prefeedback")
	var key: String = MOOD_NAME_MAP.get(base, base)
	var entry: Dictionary = (moods_data.get("moods", {}) as Dictionary).get(key, {})
	if entry.is_empty():
		return "identity"
	var day: Array = entry.get("day", [1.0, 1.0, 1.0])
	return _color_bucket(day)


func _color_bucket(rgb: Array) -> String:
	var r: float = float(rgb[0])
	var g: float = float(rgb[1])
	var b: float = float(rgb[2])
	if absf(r - 1.0) < 1e-6 and absf(g - 1.0) < 1e-6 and absf(b - 1.0) < 1e-6:
		return "identity"
	var avg := (r + g + b) / 3.0
	if avg < 0.35:
		return "dark"
	if r > b + 0.05:
		return "warm"
	if b > r + 0.05:
		return "cool"
	return "neutral"


func _region_for(map_name: String) -> String:
	if REGION_GROUPS.has(map_name):
		return REGION_GROUPS[map_name]
	if map_name == CALIBRATION_MAP_ID:
		return "invrisil"  # shares brothers_parlor's real region for the calibration check
	if not _unassigned_regions.has(map_name):
		_unassigned_regions.append(map_name)
	return map_name  # unknown future map: its own singleton group, never a crash


# ------------------------------------------------------------- analysis --

## Raw (unscored) per-map stats: walkable area, placed sprites/families,
## tile families, lights/ambience, framing geometry, clutter signals. Every
## _score_* function below consumes this dict; no JSON access happens
## outside this function and _init()'s loader calls.
func _analyze_map(name: String, m: Dictionary) -> Dictionary:
	var grid: Dictionary = m.get("grid", {"width": 0, "height": 0})
	var w: int = int(grid.get("width", 0))
	var h: int = int(grid.get("height", 0))
	var grid_area: int = w * h

	var blocked: Dictionary = {}
	for cell: Array in m.get("blocked", []):
		blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
	var walls: Dictionary = m.get("walls", {})
	for raw_seg: Variant in walls.get("segments", []):
		if raw_seg is Dictionary:
			for c: Vector2i in _segment_cells(raw_seg):
				blocked[c] = true
	for cell: Array in m.get("freezable", []):
		blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
	var walkable_area: int = maxi(1, grid_area - blocked.size())

	var decor: Array = m.get("decor", [])
	var entities: Array = m.get("entities", [])
	var scatter: Array = m.get("scatter", [])

	var decor_sprites: Array = []
	var decor_cells: Array = []
	for d: Dictionary in decor:
		if d.has("sprite"):
			decor_sprites.append(String(d["sprite"]))
		if d.has("cell"):
			decor_cells.append(Vector2i(int(d["cell"][0]), int(d["cell"][1])))

	var entity_sprites: Array = []
	var entity_cells: Array = []
	for e: Dictionary in entities:
		if e.has("sprite"):
			entity_sprites.append(String(e["sprite"]))
		if e.has("cell"):
			entity_cells.append(Vector2i(int(e["cell"][0]), int(e["cell"][1])))

	var scatter_pool_ids: Dictionary = {}
	for s: Dictionary in scatter:
		for p: Variant in s.get("pool", []):
			scatter_pool_ids[String(p)] = true

	var placed_sprite_ids: Dictionary = {}  # decor + entity sprites only (excludes procedural scatter)
	for sid in decor_sprites:
		placed_sprite_ids[sid] = true
	for sid in entity_sprites:
		placed_sprite_ids[sid] = true

	var distinct_sprite_ids: Dictionary = placed_sprite_ids.duplicate()
	for sid in scatter_pool_ids:
		distinct_sprite_ids[sid] = true

	var families: Dictionary = {}
	for sid: String in distinct_sprite_ids:
		var fam := _sprite_family(sid)
		if fam != "":
			families[fam] = true

	var biome_id: String = String(m.get("biome", ""))
	var biome_def: Dictionary = biomes_data.get(biome_id, {})
	var tile_families: Dictionary = {}
	for key in ["sheet", "blocked_sheet", "skirt_sheet"]:
		if biome_def.has(key):
			var fam := _family_from_path(String(biome_def[key]))
			if fam != "":
				tile_families[fam] = true
	for fl: Dictionary in m.get("floor_layers", []):
		if fl.has("sheet"):
			var fam := _family_from_path(String(fl["sheet"]))
			if fam != "":
				tile_families[fam] = true

	var lights: Array = []  # Array of {cell: Vector2i, light: Dictionary}
	for d: Dictionary in decor:
		if d.has("light") and d.has("cell"):
			lights.append({"cell": Vector2i(int(d["cell"][0]), int(d["cell"][1])), "light": d["light"]})
	for e: Dictionary in entities:
		if e.has("light") and e.has("cell"):
			lights.append({"cell": Vector2i(int(e["cell"][0]), int(e["cell"][1])), "light": e["light"]})

	var ambience_count: int = (m.get("ambience", []) as Array).size()

	# Border band (2 cells wide -- framing props typically sit off the wall,
	# not glued to it) walkable-cell census, for the composition framing
	# ratio. Doors are excluded from the framing item census (every room's
	# door sits on the border by construction -- see header rationale).
	var border: int = 2
	var border_walkable: int = 0
	var interior_walkable: int = 0
	for x in range(w):
		for y in range(h):
			var c := Vector2i(x, y)
			if blocked.has(c):
				continue
			if x < border or x >= w - border or y < border or y >= h - border:
				border_walkable += 1
			else:
				interior_walkable += 1

	var framing_cells: Array = decor_cells.duplicate()
	for e: Dictionary in entities:
		if e.get("kind", "") != "door" and e.has("cell"):
			framing_cells.append(Vector2i(int(e["cell"][0]), int(e["cell"][1])))
	var border_items := 0
	for c: Vector2i in framing_cells:
		if c.x < border or c.x >= w - border or c.y < border or c.y >= h - border:
			border_items += 1
	var interior_items: int = framing_cells.size() - border_items
	var border_frac: float = float(border_items) / float(maxi(1, border_walkable))
	var interior_frac: float = float(interior_items) / float(maxi(1, interior_walkable))

	var cx: float = float(w - 1) / 2.0
	var cy: float = float(h - 1) / 2.0
	var dist_thresh: float = 0.15 * float(mini(w, h))
	var big_sprite_present := false
	var off_center_ok := false
	for sid in placed_sprite_ids:
		if _sprite_frame_area(sid) >= 2.0:
			big_sprite_present = true
	for d: Dictionary in decor:
		if d.has("sprite") and d.has("cell") and _sprite_frame_area(String(d["sprite"])) >= 2.0:
			var c: Vector2i = Vector2i(int(d["cell"][0]), int(d["cell"][1]))
			if Vector2(c).distance_to(Vector2(cx, cy)) > dist_thresh:
				off_center_ok = true
	for e: Dictionary in entities:
		if e.has("sprite") and e.has("cell") and _sprite_frame_area(String(e["sprite"])) >= 2.0:
			var c: Vector2i = Vector2i(int(e["cell"][0]), int(e["cell"][1]))
			if Vector2(c).distance_to(Vector2(cx, cy)) > dist_thresh:
				off_center_ok = true
	for entry: Dictionary in lights:
		var c: Vector2i = entry["cell"]
		if Vector2(c).distance_to(Vector2(cx, cy)) > dist_thresh:
			off_center_ok = true
	var has_focal: bool = lights.size() >= 1 or big_sprite_present

	var all_placed_cells: Array = decor_cells + entity_cells
	var n_items: int = all_placed_cells.size()
	var rows: Dictionary = {}
	var cols: Dictionary = {}
	for c: Vector2i in all_placed_cells:
		rows[c.y] = true
		cols[c.x] = true
	var alignment_ratio: float = 1.0
	if n_items > 0:
		alignment_ratio = float(rows.size() + cols.size()) / float(2 * n_items)

	var occupied_fraction: float = float(n_items) / float(walkable_area)

	var scene_mood := _mood_bucket(name)
	var accent_contrast := false
	for entry: Dictionary in lights:
		var light: Dictionary = entry["light"]
		if light.has("color"):
			var lb := _color_bucket(light["color"])
			if lb == "warm" or lb == "cool":
				if scene_mood == "identity":
					accent_contrast = true
				elif lb != scene_mood and scene_mood != "neutral":
					accent_contrast = true

	var scatter_overflow := 0.0
	for s: Dictionary in scatter:
		scatter_overflow += maxf(0.0, float(s.get("density", 0.0)) - SCATTER_DENSITY_CAP)
	var light_overflow: int = maxi(0, lights.size() - 8)
	var decor_cell_counts: Dictionary = {}
	for c: Vector2i in decor_cells:
		decor_cell_counts[c] = decor_cell_counts.get(c, 0) + 1
	var stacked_cells := 0
	for c in decor_cell_counts:
		if decor_cell_counts[c] > 2:
			stacked_cells += 1

	return {
		"name": name,
		"grid_area": grid_area, "walkable_area": walkable_area,
		"decor_count": decor.size(), "entity_count": entities.size(),
		"distinct_sprite_ids": distinct_sprite_ids, "placed_sprite_ids": placed_sprite_ids,
		"families": families, "tile_families": tile_families,
		"scatter_pool_ids": scatter_pool_ids,
		"n_lights": lights.size(), "ambience": ambience_count,
		"border_frac": border_frac, "interior_frac": interior_frac,
		"has_focal": has_focal, "off_center_ok": off_center_ok,
		"alignment_ratio": alignment_ratio, "occupied_fraction": occupied_fraction,
		"accent_contrast": accent_contrast,
		"scatter_overflow": scatter_overflow, "light_overflow": light_overflow,
		"stacked_cells": stacked_cells,
		"region": _region_for(name), "biome_id": biome_id, "mood_bucket": scene_mood,
	}


# ----------------------------------------------------------------- score --

func _jaccard(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() and b.is_empty():
		return 0.0
	var inter := 0
	for k in a:
		if b.has(k):
			inter += 1
	var union_size: int = a.size() + b.size() - inter
	if union_size == 0:
		return 0.0
	return float(inter) / float(union_size)


func _full_set(a: Dictionary) -> Dictionary:
	var out: Dictionary = a["distinct_sprite_ids"].duplicate()
	for fam in a["tile_families"]:
		out["tile:%s" % fam] = true
	out["mood:%s" % a["mood_bucket"]] = true
	return out


func _score_all(analyzed: Dictionary) -> Dictionary:
	var usage: Dictionary = {}
	for name in analyzed:
		var a: Dictionary = analyzed[name]
		for sid in a["placed_sprite_ids"]:
			usage[sid] = int(usage.get(sid, 0)) + 1

	var results: Dictionary = {}
	for name in analyzed:
		var a: Dictionary = analyzed[name]
		var c1 := _score_variety(a)
		var c2d := _score_distinctiveness(a, analyzed, name)
		var c3 := _score_composition(a)
		var c4 := _score_utilization(a, usage)
		var c5 := _score_clutter(a)
		var raw_composite: float = c1 + c2d["score"] + c3 + c4 - c5
		# A near-empty room trivially maximizes component 2 (an empty content
		# set shares nothing with anything, which a pure Jaccard measure
		# rewards as if it were a deliberate stylistic choice) -- gate the
		# WHOLE composite on having enough authored content to be judged at
		# all. Every real current map carries >=5 decor+entity items; this
		# only bites content that's still a stub (verified against a
		# synthetic 1-item empty room during calibration: scores ~10/100).
		var content_count: int = a["decor_count"] + a["entity_count"]
		var content_mult: float = minf(1.0, float(content_count) / 5.0)
		var composite: float = clampf(raw_composite * content_mult, 0.0, 100.0)
		results[name] = {
			"c1": c1, "c2": c2d["score"], "c3": c3, "c4": c4, "c5": c5,
			"composite": composite,
			"avg_in": c2d["avg_in"], "avg_cross": c2d["avg_cross"],
		}
	return results


## Component 1 (30 pts): internal variety.
func _score_variety(a: Dictionary) -> float:
	var distinct_count: int = a["distinct_sprite_ids"].size()
	var sprite_density: float = float(distinct_count) / sqrt(float(a["walkable_area"]))
	const DENSITY_TARGET := 1.1
	var density_score: float = minf(1.0, sprite_density / DENSITY_TARGET)

	var spread_ratio: float = float(a["families"].size()) / float(maxi(1, distinct_count))

	var tile_fam_score: float = minf(1.0, float(a["tile_families"].size()) / 2.0)

	var scatter_div: float = minf(1.0, float(a["scatter_pool_ids"].size()) / 3.0)

	var light_amb_score: float = 0.5 * minf(1.0, float(a["n_lights"]) / 3.0) + 0.5 * minf(1.0, float(a["ambience"]) / 2.0)

	var raw_count_score: float = minf(1.0, float(a["decor_count"] + a["entity_count"]) / 8.0)

	return 30.0 * (
		0.20 * density_score +
		0.25 * spread_ratio +
		0.15 * tile_fam_score +
		0.05 * scatter_div +
		0.10 * light_amb_score +
		0.25 * raw_count_score
	)


## Component 2 (25 pts): cross-scene distinctiveness. Returns score + the
## two raw averages (surfaced in the report for auditability).
func _score_distinctiveness(a: Dictionary, analyzed: Dictionary, self_name: String) -> Dictionary:
	var my_region: String = a["region"]
	var my_set: Dictionary = _full_set(a)
	var in_sims: Array = []
	var cross_sims: Array = []
	for other_name in analyzed:
		if other_name == self_name:
			continue
		var b: Dictionary = analyzed[other_name]
		var sim: float = _jaccard(my_set, _full_set(b))
		if b["region"] == my_region:
			in_sims.append(sim)
		else:
			cross_sims.append(sim)

	var in_score: float
	var avg_in: float
	if in_sims.is_empty():
		# Singleton region group: the in-region axis is UNMEASURED — this is a
		# CREDIT, not a score. TRAP: giving a poorly-scoring scene its own
		# singleton group converts 40% of c2 into this free 0.85; any new
		# singleton in REGION_GROUPS needs its rationale documented in the
		# header (see garden_sanctuary) and the report disclosure kept true.
		avg_in = -1.0  # N/A: singleton region group, not a failure
		in_score = 0.85
	else:
		avg_in = _mean(in_sims)
		if avg_in >= 0.4 and avg_in <= 0.7:
			in_score = 1.0
		elif avg_in < 0.4:
			in_score = 0.55 + 0.45 * (avg_in / 0.4)
		else:
			in_score = maxf(0.4, 1.0 - (avg_in - 0.7) / 0.3)

	var avg_cross: float = _mean(cross_sims) if not cross_sims.is_empty() else 0.0
	var cross_score: float
	if avg_cross <= 0.3:
		cross_score = 1.0
	else:
		cross_score = maxf(0.0, 1.0 - (avg_cross - 0.3) / 0.35)

	var score: float = 25.0 * (0.4 * in_score + 0.6 * cross_score)
	return {"score": score, "avg_in": avg_in, "avg_cross": avg_cross}


func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())


## Component 3 (25 pts): composition best-practices.
func _score_composition(a: Dictionary) -> float:
	var focal_score: float
	if a["has_focal"] and a["off_center_ok"]:
		focal_score = 1.0
	elif a["has_focal"]:
		focal_score = 0.5
	else:
		focal_score = 0.0

	var ratio: float
	if a["interior_frac"] > 1e-9:
		ratio = a["border_frac"] / a["interior_frac"]
	else:
		ratio = 2.0 if a["border_frac"] > 0.0 else 1.0
	var framing_score: float = minf(1.0, ratio / 1.3)

	var occ: float = a["occupied_fraction"]
	var open_score: float
	if occ >= 0.08 and occ <= 0.35:
		open_score = 1.0
	elif occ < 0.08:
		open_score = maxf(0.0, occ / 0.08)
	else:
		open_score = maxf(0.0, 1.0 - (occ - 0.35) / 0.35)

	var position_score: float = a["alignment_ratio"]

	var accent_score: float = 1.0 if a["accent_contrast"] else 0.5

	return 25.0 * (
		0.30 * focal_score +
		0.20 * framing_score +
		0.25 * open_score +
		0.15 * position_score +
		0.10 * accent_score
	)


## Component 4 (10 pts): asset utilization, PER-SCENE half only (novelty).
## The repo-level catalog-family-coverage half is reported once, globally
## (see _compute_catalog_family_coverage), not folded in here.
func _score_utilization(a: Dictionary, usage: Dictionary) -> float:
	var placed: Dictionary = a["placed_sprite_ids"]
	if placed.is_empty():
		return 0.0
	var novel := 0
	for sid in placed:
		if int(usage.get(sid, 0)) <= 1:
			novel += 1
	return 10.0 * (float(novel) / float(placed.size()))


## Component 5 (10 pts, subtractive): clutter penalty.
func _score_clutter(a: Dictionary) -> float:
	var pen := 0.0
	pen += minf(5.0, a["scatter_overflow"] * 20.0)
	pen += minf(3.0, float(a["light_overflow"]))
	pen += minf(5.0, float(a["stacked_cells"]) * 2.0)
	return minf(10.0, pen)


# ---------------------------------------------------------- catalog line --

func _normalize_token(s: String) -> String:
	var out := ""
	for c in s.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


## Repo-level: what fraction of the docs/asset-index.json catalog's packs
## has this repo drawn a family from ANYWHERE (not per-scene). Fuzzy
## name-token matching (normalized substring) -- there's no structured
## pack->family manifest covering every asset (tools/sync_assets.py only
## covers the original extraction batch), so this is an approximate
## repo-level indicator, not a scored/gated number. A pack with no
## plausible match is very likely a PixelLab-owned/bespoke-commissioned
## asset (e.g. Wilovan/Olesm/etc's rigs) that was never meant to show up
## here, not a missed catalog family -- reported as "uncounted", not wrong.
func _compute_catalog_family_coverage() -> Dictionary:
	var used_tokens: Dictionary = {}
	for sprite_id in sprites_data:
		var fam := _sprite_family(sprite_id)
		if fam != "":
			var second: String = fam.split("/")[1]
			used_tokens[_normalize_token(second)] = true
	for biome_id in biomes_data:
		var biome_def: Dictionary = biomes_data[biome_id]
		for key in ["sheet", "blocked_sheet", "skirt_sheet"]:
			if biome_def.has(key):
				var fam := _family_from_path(String(biome_def[key]))
				if fam != "":
					used_tokens[_normalize_token(fam.split("/")[1])] = true

	var total := 0
	var matched := 0
	var unmatched_packs: Array = []
	for pack_name in asset_index_data:
		total += 1
		var norm_pack := _normalize_token(pack_name)
		var hit := false
		for token in used_tokens:
			if token.length() >= 4 and (norm_pack.contains(token) or token.contains(norm_pack)):
				hit = true
				break
		if hit:
			matched += 1
		else:
			unmatched_packs.append(pack_name)

	return {
		"matched": matched, "total": total,
		"fraction": (float(matched) / float(total)) if total > 0 else 0.0,
		"unmatched": unmatched_packs,
	}


# --------------------------------------------------------------- output --

func _verdict(composite: float) -> String:
	if composite < ADVISORY_FLOOR:
		return "ADVISORY: brown-box risk"
	if composite < 50.0:
		return "adequate"
	return "dynamic"


func _sorted_names(results: Dictionary) -> Array:
	var names: Array = results.keys()
	names.sort_custom(func(x, y):
		var cx: float = results[x]["composite"]
		var cy: float = results[y]["composite"]
		if cx != cy:
			return cx > cy
		return String(x) < String(y)
	)
	return names


func _print_table(results: Dictionary, analyzed: Dictionary, calibration: bool) -> void:
	print("\nscene-dynamism scorecard%s" % (" (calibration mode)" if calibration else ""))
	print("%-28s %8s %6s %6s %6s %6s %6s  %s" % ["scene", "composite", "c1", "c2", "c3", "c4", "c5", "verdict"])
	for name in _sorted_names(results):
		var r: Dictionary = results[name]
		print("%-28s %8.2f %6.2f %6.2f %6.2f %6.2f %6.2f  %s" % [
			name, r["composite"], r["c1"], r["c2"], r["c3"], r["c4"], r["c5"], _verdict(r["composite"])
		])
	if not _unassigned_regions.is_empty():
		print("\nNOTE: map(s) with no region-group entry (defaulted to their own singleton group): %s" % [_unassigned_regions])


func _print_calibration_verdict(results: Dictionary) -> void:
	var names := _sorted_names(results)
	var n := names.size()
	var prefeed_rank := names.find(CALIBRATION_MAP_ID) + 1
	var bottom_decile_count: int = maxi(1, int(round(float(n) / 10.0)))
	var decile_cut: int = n - bottom_decile_count + 1
	print("\ncalibration verdict:")
	print("  brothers_parlor_prefeedback rank %d/%d (bottom decile = rank >= %d): %s" % [
		prefeed_rank, n, decile_cut, "PASS" if prefeed_rank >= decile_cut else "FAIL"
	])
	var half: int = n / 2
	for check in ["street", "garden_sanctuary", "inn"]:
		var rank: int = names.find(check) + 1
		print("  %s rank %d/%d (upper half = rank <= %d): %s" % [
			check, rank, n, half, "PASS" if rank <= half else "FAIL"
		])
	var current_rank: int = names.find("brothers_parlor") + 1
	print("  brothers_parlor (current) rank %d/%d vs prefeedback rank %d/%d: %s" % [
		current_rank, n, prefeed_rank, n,
		"current outranks prefeedback (expected)" if current_rank < prefeed_rank else "INVERTED -- investigate"
	])


func _build_report(results: Dictionary, analyzed: Dictionary) -> String:
	var catalog := _compute_catalog_family_coverage()
	var lines: Array = []
	lines.append("# Scene dynamism report")
	lines.append("")
	lines.append("Generated by `tools/scene_dynamism.gd` (issue #73). Deterministic: re-running")
	lines.append("with no data changes regenerates this file byte-identical (stable sort by")
	lines.append("composite desc / name asc, no timestamps). Report + soft floor, NOT a CI gate.")
	lines.append("")
	lines.append("## Usage")
	lines.append("")
	lines.append("Score every new/edited map with the command below before calling a scene done.")
	lines.append("New scenes should target composite >=50; the component breakdown tells you WHAT")
	lines.append("to add -- low internal variety (c1) means pull decor from more than one")
	lines.append("asset-pack family, not just more decor from the same one; low composition (c3)")
	lines.append("means add an off-center focal light/prop and dress the border band, not just")
	lines.append("the dead center; low cross-scene distinctiveness (c2) means the biome/sprite")
	lines.append("picks read like a different region entirely (the brothers_parlor pre-#49")
	lines.append("smell: it borrowed the inn's exact floor tile) or share too little visual")
	lines.append("language with the scene's own region siblings. Scores under 30 print a loud")
	lines.append("advisory below -- treat that as a near-certain brown box and fix before")
	lines.append("spending a windowed screenshot on it.")
	lines.append("")
	lines.append("```")
	lines.append("godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd")
	lines.append("```")
	lines.append("")
	lines.append("## What this metric cannot see")
	lines.append("")
	lines.append("No pixel/palette analysis -- visual harmony is proxied via asset-pack")
	lines.append("families + mood-grade buckets, so the score is blind to actual color/pixel")
	lines.append("clash inside a family. Combat arenas (data/arenas.json) are out of scope.")
	lines.append("A scene in a SINGLETON region group (currently garden_sanctuary; any unknown")
	lines.append("future map by default) gets a flat 0.85 CREDIT on the in-region half of c2")
	lines.append("because there are no siblings to measure against -- garden_sanctuary's")
	lines.append("upper-half calibration placement depends on that grouping decision (in the")
	lines.append("'interiors' group it would rank mid-table). The windowed screenshot read")
	lines.append("stays the final authority; this tool only catches the brown-box class early.")
	lines.append("")
	lines.append("## Weights (30/25/25/10/10, per the spec's own starting split -- unchanged;")
	lines.append("only each component's internal formula was tuned to satisfy calibration)")
	lines.append("")
	lines.append("| # | Component | Weight |")
	lines.append("|---|---|---|")
	lines.append("| 1 | Internal variety | 30 |")
	lines.append("| 2 | Cross-scene distinctiveness | 25 |")
	lines.append("| 3 | Composition best-practices | 25 |")
	lines.append("| 4 | Asset utilization (per-scene: novelty only) | 10 |")
	lines.append("| 5 | Clutter penalty (subtractive) | 10 |")
	lines.append("")
	lines.append("Full formula + rationale for each sub-signal: `tools/scene_dynamism.gd`'s own")
	lines.append("header comment (single source of truth -- not duplicated here).")
	lines.append("")
	lines.append("## Repo-level asset catalog utilization (component 4's non-per-scene half)")
	lines.append("")
	lines.append("%d/%d catalog packs (docs/asset-index.json) have a plausibly-matched family in" % [catalog["matched"], catalog["total"]])
	lines.append("use somewhere in the repo (%.0f%%). Fuzzy name-token match, not a structured" % (catalog["fraction"] * 100.0))
	lines.append("manifest -- packs with no match are very likely PixelLab-owned/bespoke rigs")
	lines.append("that were never meant to show up here (uncounted, not a gap).")
	lines.append("")
	lines.append("## Scorecard")
	lines.append("")
	lines.append("| Scene | Region | Composite | c1 variety | c2 distinct | c3 composition | c4 utilization | c5 clutter | Verdict |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for name in _sorted_names(results):
		var r: Dictionary = results[name]
		var a: Dictionary = analyzed[name]
		lines.append("| %s | %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %s |" % [
			name, a["region"], r["composite"], r["c1"], r["c2"], r["c3"], r["c4"], r["c5"], _verdict(r["composite"])
		])
	lines.append("")
	if not _unassigned_regions.is_empty():
		lines.append("NOTE: map(s) with no region-group table entry (defaulted to their own")
		lines.append("singleton group, not a crash): %s" % [_unassigned_regions])
		lines.append("")
	return "\n".join(lines) + "\n"
