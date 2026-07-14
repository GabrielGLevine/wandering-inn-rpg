class_name WITileBoardBuilder

const CELL := 16


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
	for raw_seg: Variant in walls_cfg.get("segments", []):
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
