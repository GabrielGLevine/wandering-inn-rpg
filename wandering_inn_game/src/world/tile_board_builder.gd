class_name WITileBoardBuilder

const CELL := 16
const GROUND_TONE_SHADER := preload("res://src/world/shaders/ground_tone.gdshader")
const _WATER_NEIGHBORS := [
	[Vector2i(0, -1), 1], [Vector2i(1, -1), 2],
	[Vector2i(1, 0), 4], [Vector2i(1, 1), 8],
	[Vector2i(0, 1), 16], [Vector2i(-1, 1), 32],
	[Vector2i(-1, 0), 64], [Vector2i(-1, -1), 128],
]
const _WATER_CARDINALS := 1 | 4 | 16 | 64
const _WATER_DIAGONALS := 2 | 8 | 32 | 128


static func water_segment_cell_set(segments: Array) -> Dictionary:
	var water_cells := {}
	for raw_segment: Variant in segments:
		if not (raw_segment is Dictionary) or not bool((raw_segment as Dictionary).get("water", false)):
			continue
		for cell: Vector2i in WIGame.segment_cells(raw_segment as Dictionary):
			water_cells[cell] = true
	return water_cells


static func water_neighbor_mask(cell: Vector2i, water_cells: Dictionary) -> int:
	var mask := 0
	for neighbor: Array in _WATER_NEIGHBORS:
		if water_cells.has(cell + (neighbor[0] as Vector2i)):
			mask |= int(neighbor[1])
	return mask


## DUAL-GRID SHORELINE (issue #411, second pass after the windowed read).
## Per-cell edge tiles cannot render 1-wide channels (no sheet has a
## water-strip-with-two-lips tile -- the sewers were a no-op) and the pack's
## bank tiles carry foreign grass. Instead: a HALF-OFFSET overlay paints one
## tile per cell VERTEX, corners sampled from the 4 cells that meet there,
## from a terrain-neutral generated sheet (water + waterline lip, land side
## TRANSPARENT so each map's own ground shows through). Every corner combo is
## a real tile -- the mapping is a total function, so strips, necks and
## double-diagonal cells are ordinary cases, not fallbacks.
##
## Sheet: assets/tiles/generated/water_shoreline_16.png -- PixelLab
## create_topdown_tileset id 8b0b91aa-194b-4aee-921f-e8d97d9aea90 (water ->
## flat-magenta upper, transition 0.25 "dark wet waterline lip", 16px,
## lineless, basic shading), then chroma-keyed: blue-dominant kept,
## magenta family -> alpha, dark lip kept within 2px of bright water. Corner bits below say
## which of the vertex's 4 cells are WATER: NW=1, NE=2, SW=4, SE=8.
const SHORELINE_SHEET := "res://assets/tiles/generated/water_shoreline_16.png"
const SHORELINE_TILE_PX := 16
## bits(water corners) -> atlas coord. 0 (no water) is never painted;
## 15 (all water) is skipped -- the base water layer already covers it.
const SHORELINE_WANG_COORDS := {
	1: Vector2i(3, 3), 2: Vector2i(0, 2), 4: Vector2i(0, 0), 8: Vector2i(1, 3),
	3: Vector2i(1, 2), 12: Vector2i(3, 0), 5: Vector2i(3, 2), 10: Vector2i(1, 0),
	6: Vector2i(2, 3), 9: Vector2i(0, 1),
	7: Vector2i(3, 1), 11: Vector2i(2, 2), 13: Vector2i(2, 0), 14: Vector2i(1, 1),
	15: Vector2i(2, 1),
}


static func vertex_water_bits(vertex: Vector2i, water_cells: Dictionary) -> int:
	var bits := 0
	if water_cells.has(vertex + Vector2i(-1, -1)):
		bits |= 1
	if water_cells.has(vertex + Vector2i(0, -1)):
		bits |= 2
	if water_cells.has(vertex + Vector2i(-1, 0)):
		bits |= 4
	if water_cells.has(vertex + Vector2i(0, 0)):
		bits |= 8
	return bits


## Builds the half-offset shoreline overlay for a map's water segments.
## Returns null when the map has no water. The caller owns the material:
## the world attaches the shimmer shader to THIS layer (single-copy water,
## so animation cannot ghost -- review M1/M2 resolution 2026-08-09).
static func build_shoreline_overlay(segments: Array, registry) -> TileMapLayer:
	var water_cells := water_segment_cell_set(segments)
	if water_cells.is_empty():
		return null
	var layer := TileMapLayer.new()
	layer.tile_set = registry.tile_set_for(SHORELINE_SHEET, SHORELINE_TILE_PX)
	layer.scale = Vector2(float(CELL) / float(SHORELINE_TILE_PX), float(CELL) / float(SHORELINE_TILE_PX))
	layer.position = Vector2(-CELL / 2.0, -CELL / 2.0)
	var seen := {}
	for cell: Vector2i in water_cells:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var vertex: Vector2i = cell + corner
			if seen.has(vertex):
				continue
			seen[vertex] = true
			var bits := vertex_water_bits(vertex, water_cells)
			if bits == 0:
				continue
			layer.set_cell(vertex, 0, SHORELINE_WANG_COORDS[bits])
	return layer


## CONTRACT: map id + cell only; field cover never consumes gameplay RNG.
static func field_blocked_prop_index(map_id: String, cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	var h := hash(Vector3i(cell.x * 73856093, cell.y * 19349663, map_id.hash()))
	return int(h & 0x7FFFFFFF) % count


static func field_blocked_render_plan(
	map_id: String,
	blocked: Dictionary,
	segment_covered: Dictionary,
	cover_skip: Dictionary,
	authored_covered: Dictionary,
	pool: Array,
) -> Dictionary:
	var props := {}
	var fallback: Array[Vector2i] = []
	for cell: Vector2i in blocked:
		if segment_covered.has(cell) or cover_skip.has(cell) or authored_covered.has(cell):
			continue
		if pool.is_empty():
			fallback.append(cell)
		else:
			props[cell] = String(pool[field_blocked_prop_index(map_id, cell, pool.size())])
	return {"props": props, "fallback": fallback}


static func field_authored_cover_cells(map_cfg: Dictionary) -> Dictionary:
	var covered := {}
	for key: String in ["decor", "entities"]:
		for raw_entry: Variant in map_cfg.get(key, []):
			if not (raw_entry is Dictionary):
				continue
			var entry := raw_entry as Dictionary
			var cell: Array = entry.get("cell", [])
			if cell.size() < 2 or String(entry.get("sprite", "")).is_empty():
				continue
			if key == "entities" and bool(entry.get("hide_sprite", false)):
				continue
			covered[Vector2i(int(cell[0]), int(cell[1]))] = true
	return covered


## TRAP: cover_skip suppresses both fallback tiles and props; stale entries must fail loud.
static func cover_skip_errors(
	blocked: Dictionary,
	segment_covered: Dictionary,
	cover_skip: Dictionary,
	authored_covered: Dictionary,
	prop_cells: Dictionary,
) -> PackedStringArray:
	var errors := PackedStringArray()
	for cell: Vector2i in cover_skip:
		if not blocked.has(cell):
			errors.append("cover_skip %s is not blocked" % cell)
		elif segment_covered.has(cell):
			errors.append("cover_skip %s is obsolete: wall segment already covers it" % cell)
		if prop_cells.has(cell):
			errors.append("cover_skip %s also receives biome prop %s" % [cell, prop_cells[cell]])
	for cell: Vector2i in prop_cells:
		if not blocked.has(cell):
			errors.append("biome prop %s is not blocked" % cell)
		elif segment_covered.has(cell):
			errors.append("biome prop %s overlaps a wall segment" % cell)
		elif authored_covered.has(cell):
			errors.append("biome prop %s overlaps authored field art" % cell)
	return errors


## Resolves a `cells` spec ("all" | {"rect":[x,y,w,h]} | {"list":[[x,y],...]})
## into the concrete cell list it addresses. Rect/list cells may fall outside
## `grid` on purpose (arena skirt dressing sits outside the playable grid by
## contract) -- callers that only want in-grid cells (the "all" case) get
## that naturally since "all" is generated from `grid` directly.
static func resolve_layer_cells(spec: Variant, grid: Vector2i) -> Array:
	var out: Array[Vector2i] = []
	if spec is String and spec == "all":
		for x in grid.x:
			for y in grid.y:
				out.append(Vector2i(x, y))
	elif spec is Dictionary:
		var d := spec as Dictionary
		if d.has("rect"):
			var r: Array = d["rect"]
			var rx := int(r[0])
			var ry := int(r[1])
			var rw := int(r[2])
			var rh := int(r[3])
			for x in range(rx, rx + rw):
				for y in range(ry, ry + rh):
					out.append(Vector2i(x, y))
		elif d.has("list"):
			for c: Array in d["list"]:
				out.append(Vector2i(int(c[0]), int(c[1])))
	return out


static func make_tile_layer(parent: Node2D, sheet_path: String, tile_px: int, registry) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = registry.tile_set_for(sheet_path, tile_px)
	layer.scale = Vector2(float(CELL) / float(tile_px), float(CELL) / float(tile_px))
	return layer


static func apply_ground_tone(layer: TileMapLayer, tone: Dictionary) -> void:
	if tone.is_empty():
		return
	var base: Array = tone.get("base", [])
	if base.size() != 3:
		return
	var material := ShaderMaterial.new()
	material.shader = GROUND_TONE_SHADER
	material.set_shader_parameter("ground_base", Color(float(base[0]), float(base[1]), float(base[2])))
	material.set_shader_parameter("ground_detail", clampf(float(tone.get("detail", 1.0)), 0.0, 1.0))
	layer.material = material


static func build_vistas(parent: Node2D, config: Array, registry: Variant) -> int:
	var count := 0
	for row: Dictionary in config:
		var sprite_id := String(row["sprite"])
		var entry: Dictionary = registry.entry_for(sprite_id)
		var frames: SpriteFrames = registry.frames_for(sprite_id)
		if frames == null or not frames.has_animation("idle"):
			continue
		var texture := frames.get_frame_texture("idle", 0)
		var scale_value := float(entry.get("render_scale", 1.0))
		var anchor: Array = entry.get("anchor", [0.5, 1.0])
		var cell: Array = row["cell"]
		var vista := Sprite2D.new()
		vista.texture = texture
		vista.centered = false
		vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vista.z_index = 0 if bool(row.get("foreground", false)) else -10
		vista.scale = Vector2.ONE * scale_value
		vista.position = Vector2(float(cell[0]), float(cell[1])) * CELL \
			- Vector2(float(anchor[0]), float(anchor[1])) * texture.get_size() * scale_value
		var tint: Array = row.get("tint", [1, 1, 1])
		vista.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3]) if tint.size() == 4 else 1.0)
		parent.add_child(vista)
		count += 1
	return count


const TILE_RENDER_FIELDS := [
	"sheet", "tile_px", "coords", "variants", "cap", "face", "top_coords", "base_coords",
	"floor", "blocked_sheet", "blocked_tile_px", "blocked", "skirt_sheet", "skirt_tile_px", "skirt",
	"tone", "floor_tone", "blocked_tone", "skirt_tone", "wang_corners", "terrain_lower_cells", "underlay",
]


static func _tile_descriptor_available(config: Dictionary, registry) -> bool:
	if not registry.tile_sheet_available(String(config.get("sheet", ""))):
		return false
	for key: String in ["blocked_sheet", "skirt_sheet"]:
		if config.has(key) and not registry.tile_sheet_available(String(config[key])):
			return false
	var underlay: Variant = config.get("underlay", {})
	return underlay is Dictionary and (underlay.is_empty() or registry.tile_sheet_available(String(underlay.get("sheet", ""))))


static func _select_tile_render(primary: Dictionary, registry) -> Dictionary:
	if _tile_descriptor_available(primary, registry):
		return primary
	var fallback: Variant = primary.get("fallback_render", {})
	if not fallback is Dictionary or fallback.is_empty() or fallback.has("fallback_render"):
		return primary
	if not fallback.has("tile_px") or not _tile_descriptor_available(fallback, registry):
		return primary
	var resolved := primary.duplicate(true)
	for key: String in TILE_RENDER_FIELDS:
		resolved.erase(key)
	for key: String in fallback:
		if TILE_RENDER_FIELDS.has(key):
			resolved[key] = fallback[key]
	resolved["_using_fallback"] = true
	return resolved


static func resolve_biome_render(config: Dictionary, registry) -> Dictionary:
	return _select_tile_render(config.duplicate(true), registry)


## Inheritance is expanded before selection; old coordinates never inherit an owned fallback sheet.
static func resolve_tile_render(config: Dictionary, original_parent: Dictionary, registry) -> Dictionary:
	var primary := config.duplicate(true)
	primary["sheet"] = String(config.get("sheet", original_parent["sheet"]))
	primary["tile_px"] = int(config.get("tile_px", original_parent["tile_px"]))
	return _select_tile_render(primary, registry)


static func terrain_vertex_bits(vertex: Vector2i, lower_cells: Dictionary) -> int:
	return 15 ^ vertex_water_bits(vertex, lower_cells)


static func build_ground_transition(parent: Node2D, config: Dictionary, grid: Vector2i,
		biome_cfg: Dictionary, registry) -> void:
	var lower := {}
	for cell: Vector2i in resolve_layer_cells(config["terrain_lower_cells"], grid):
		lower[cell] = true
	var sheet := String(config.get("sheet", biome_cfg["sheet"]))
	var tile_px := int(config.get("tile_px", biome_cfg["tile_px"]))
	var layer := make_tile_layer(parent, sheet, tile_px, registry)
	layer.set_meta("owned_terrain_fallback", bool(config.get("_using_fallback", false)))
	layer.position = Vector2(-CELL / 2.0, -CELL / 2.0)
	apply_ground_tone(layer, config.get("tone", {}))
	var corners: Array = config["wang_corners"]
	for x in grid.x + 1:
		for y in grid.y + 1:
			var vertex := Vector2i(x, y)
			var coord: Array = corners[terrain_vertex_bits(vertex, lower)]
			layer.set_cell(vertex, 0, Vector2i(int(coord[0]), int(coord[1])))
	parent.add_child(layer)


## Renders `floor_layers` entries (data/maps/** / data/arenas.json
## schema): each entry paints either a fixed `coords` tile or a
## position-hashed pick from `variants` over the cells selected by `cells`
## ("all" | {"rect":[x,y,w,h]} | {"list":[[x,y],...]}). One TileMapLayer per
## entry, added (under `parent`) in array order so later entries draw over
## earlier ones.
static func build_floor_layers(parent: Node2D, layers_cfg: Array, grid: Vector2i, biome_cfg: Dictionary, registry) -> int:
	var transitions := 0
	for raw: Variant in layers_cfg:
		if not (raw is Dictionary):
			continue
		var layer_cfg := resolve_tile_render(raw as Dictionary, biome_cfg, registry)
		if layer_cfg.has("underlay"):
			var underlay: Dictionary = layer_cfg["underlay"].duplicate(true)
			underlay["cells"] = layer_cfg.get("cells", "all")
			underlay["_using_fallback"] = bool(layer_cfg.get("_using_fallback", false))
			build_floor_layers(parent, [underlay], grid, biome_cfg, registry)
		if layer_cfg.has("wang_corners"):
			build_ground_transition(parent, layer_cfg, grid, biome_cfg, registry)
			transitions += 1
			continue
		var sheet := String(layer_cfg.get("sheet", biome_cfg["sheet"]))
		var tile_px := int(layer_cfg.get("tile_px", biome_cfg["tile_px"]))
		var tile_layer := make_tile_layer(parent, sheet, tile_px, registry)
		tile_layer.set_meta("owned_terrain_fallback", bool(layer_cfg.get("_using_fallback", false)))
		apply_ground_tone(tile_layer, layer_cfg.get("tone", {}))
		var cells := resolve_layer_cells(layer_cfg.get("cells", "all"), grid)
		var variants: Array = layer_cfg.get("variants", [])
		var fixed_coord: Variant = layer_cfg.get("coords", null)
		var painted := false
		for cell: Vector2i in cells:
			var coord: Vector2i
			if not variants.is_empty():
				var idx: int = registry.cell_variant_index(cell, variants.size())
				var v: Array = variants[idx]
				coord = Vector2i(int(v[0]), int(v[1]))
			elif fixed_coord != null:
				coord = Vector2i(int(fixed_coord[0]), int(fixed_coord[1]))
			else:
				continue
			tile_layer.set_cell(cell, 0, coord)
			painted = true
		if painted:
			parent.add_child(tile_layer)
		else:
			tile_layer.queue_free()

	return transitions


static func build_skirt(parent: Node2D, grid: Vector2i, margin: int, biome_cfg: Dictionary, registry) -> void:
	if not biome_cfg.has("skirt"):
		return
	var sheet := String(biome_cfg.get("skirt_sheet", biome_cfg["sheet"]))
	var tile_px := int(biome_cfg.get("skirt_tile_px", biome_cfg["tile_px"]))
	var coord := Vector2i(int(biome_cfg["skirt"][0]), int(biome_cfg["skirt"][1]))
	var layer := make_tile_layer(parent, sheet, tile_px, registry)
	layer.z_index = -20
	layer.set_meta("owned_terrain_fallback", bool(biome_cfg.get("_using_fallback", false)))
	apply_ground_tone(layer, biome_cfg.get("skirt_tone", {}))
	var lo := Vector2i(-margin, -margin)
	var hi := Vector2i(grid.x + margin, grid.y + margin)
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			layer.set_cell(Vector2i(x, y), 0, coord)
	parent.add_child(layer)


static func build_walls(parent: Node2D, walls_cfg: Dictionary, grid: Vector2i, biome_cfg: Dictionary, registry) -> Dictionary:
	var covered := {}
	if walls_cfg.is_empty():
		return covered
	var parent_config := resolve_tile_render(walls_cfg, biome_cfg, registry)
	var original_parent := walls_cfg.duplicate(true)
	original_parent["sheet"] = walls_cfg.get("sheet", biome_cfg["sheet"])
	original_parent["tile_px"] = walls_cfg.get("tile_px", biome_cfg["tile_px"])
	var sheet := String(parent_config["sheet"])
	var tile_px := int(parent_config["tile_px"])
	if parent_config.has("top_coords"):
		var band_rows := int(parent_config.get("band_rows", 1))
		var top_coords := Vector2i(int(parent_config["top_coords"][0]), int(parent_config["top_coords"][1]))
		var base_raw: Variant = parent_config.get("base_coords", null)
		var base_coords := Vector2i(int(base_raw[0]), int(base_raw[1])) if base_raw != null else top_coords
		var layer := make_tile_layer(parent, sheet, tile_px, registry)
		layer.set_meta("owned_terrain_fallback", bool(parent_config.get("_using_fallback", false)))
		apply_ground_tone(layer, parent_config.get("tone", {}))
		for row_offset in band_rows:
			var y := -band_rows + row_offset
			var coord := top_coords if row_offset == 0 else base_coords
			for x in grid.x:
				layer.set_cell(Vector2i(x, y), 0, coord)
		parent.add_child(layer)
	var segments: Array = walls_cfg.get("segments", [])
	for raw_seg: Variant in segments:
		if not (raw_seg is Dictionary):
			continue
		var seg := resolve_tile_render(raw_seg as Dictionary, original_parent, registry)
		var cells := WIGame.segment_cells(seg)
		if cells.is_empty():
			continue
		var seg_sheet := String(seg.get("sheet", sheet))
		var seg_tile_px := int(seg.get("tile_px", tile_px))
		var seg_layer := make_tile_layer(parent, seg_sheet, seg_tile_px, registry)
		seg_layer.set_meta("owned_terrain_fallback", bool(seg.get("_using_fallback", false)))
		apply_ground_tone(seg_layer, seg.get("tone", {}))
		var cell_set := {}
		for cell: Vector2i in cells:
			cell_set[cell] = true
			covered[cell] = true
		var face_raw: Variant = seg.get("face", null)
		var cap_raw: Variant = seg.get("cap", null)
		if face_raw != null:
			var face := Vector2i(int(face_raw[0]), int(face_raw[1]))
			var cap := Vector2i(int(cap_raw[0]), int(cap_raw[1])) if cap_raw != null else face
			for cell: Vector2i in cells:
				var above := cell + Vector2i(0, -1)
				if not cell_set.has(above):
					seg_layer.set_cell(above, 0, cap)
			for cell: Vector2i in cells:
				seg_layer.set_cell(cell, 0, face)
		elif cap_raw != null:
			var cap_only := Vector2i(int(cap_raw[0]), int(cap_raw[1]))
			for cell: Vector2i in cells:
				seg_layer.set_cell(cell, 0, cap_only)
		parent.add_child(seg_layer)
	return covered
