class_name WITileBoardBuilder

const CELL := 16
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
## Sheet: assets/tiles/generated/water_shoreline_16.png (PixelLab Wang-16,
## chroma-keyed; provenance in the test's sheet pin). Corner bits below say
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
## Returns null when the map has no water. The overlay is STATIC (no shimmer
## material) -- animated water must never drag the banks (review I3).
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
			if bits == 0 or bits == 15:
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


## Renders `floor_layers` entries (data/maps/** / data/arenas.json
## schema): each entry paints either a fixed `coords` tile or a
## position-hashed pick from `variants` over the cells selected by `cells`
## ("all" | {"rect":[x,y,w,h]} | {"list":[[x,y],...]}). One TileMapLayer per
## entry, added (under `parent`) in array order so later entries draw over
## earlier ones.
static func build_floor_layers(parent: Node2D, layers_cfg: Array, grid: Vector2i, biome_cfg: Dictionary, registry) -> void:
	for raw: Variant in layers_cfg:
		if not (raw is Dictionary):
			continue
		var layer_cfg := raw as Dictionary
		var sheet := String(layer_cfg.get("sheet", biome_cfg["sheet"]))
		var tile_px := int(layer_cfg.get("tile_px", biome_cfg["tile_px"]))
		var tile_layer := make_tile_layer(parent, sheet, tile_px, registry)
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


static func build_skirt(parent: Node2D, grid: Vector2i, margin: int, biome_cfg: Dictionary, registry) -> void:
	if not biome_cfg.has("skirt"):
		return
	var sheet := String(biome_cfg.get("skirt_sheet", biome_cfg["sheet"]))
	var tile_px := int(biome_cfg.get("skirt_tile_px", biome_cfg["tile_px"]))
	var coord := Vector2i(int(biome_cfg["skirt"][0]), int(biome_cfg["skirt"][1]))
	var layer := make_tile_layer(parent, sheet, tile_px, registry)
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
	var sheet := String(walls_cfg.get("sheet", biome_cfg["sheet"]))
	var tile_px := int(walls_cfg.get("tile_px", biome_cfg["tile_px"]))
	if walls_cfg.has("top_coords"):
		var band_rows := int(walls_cfg.get("band_rows", 1))
		var top_coords := Vector2i(int(walls_cfg["top_coords"][0]), int(walls_cfg["top_coords"][1]))
		var base_raw: Variant = walls_cfg.get("base_coords", null)
		var base_coords := Vector2i(int(base_raw[0]), int(base_raw[1])) if base_raw != null else top_coords
		var layer := make_tile_layer(parent, sheet, tile_px, registry)
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
		var seg := raw_seg as Dictionary
		var cells := WIGame.segment_cells(seg)
		if cells.is_empty():
			continue
		var seg_sheet := String(seg.get("sheet", sheet))
		var seg_tile_px := int(seg.get("tile_px", tile_px))
		var seg_layer := make_tile_layer(parent, seg_sheet, seg_tile_px, registry)
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
