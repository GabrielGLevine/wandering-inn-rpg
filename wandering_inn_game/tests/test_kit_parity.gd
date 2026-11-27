extends SceneTree

## #607 parity, GD half: fixtures vs the Python-generated golden, and the real
## tree's resolved rows (dumped to $WI_KIT_PARITY_OUT for scripts/tests/test_kit_parity.py).

const FIX := "res://tests/fixtures/kits"


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# Parsed JSON numbers are floats; cells are normalised to int on both sides.
func _norm_rows(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append({"layer": String(row["layer"]), "cell": [int(row["cell"][0]), int(row["cell"][1])], "sprite_role": String(row["sprite_role"]), "sprite": String(row["sprite"]), "light": row["light"]})
	return out


func _rows(doc: Dictionary) -> Array:
	var out: Array = []
	for layer: String in ["decor", "entities"]:
		for row: Variant in doc.get(layer, []):
			if row is Dictionary and (row as Dictionary).has("sprite_role"):
				out.append({"layer": layer, "cell": row["cell"], "sprite_role": row["sprite_role"], "sprite": row["sprite"], "light": row.get("light", null)})
	return _norm_rows(out)


func _materials(doc: Dictionary) -> Array:
	var targets: Array = []
	for i in (doc.get("floor_layers", []) as Array).size():
		targets.append(["floor_layers[%d]" % i, doc["floor_layers"][i]])
	var walls: Variant = doc.get("walls", null)
	if walls is Dictionary:
		targets.append(["walls", walls])
		for i in ((walls as Dictionary).get("segments", []) as Array).size():
			targets.append(["walls.segments[%d]" % i, walls["segments"][i]])
	var out: Array = []
	for t: Array in targets:
		var row: Dictionary = t[1]
		if row.has("material_ref"):
			var fields: Dictionary = {}
			for key: String in WIKitResolver.MATERIAL_FIELDS:
				if row.has(key):
					fields[key] = row[key]
			out.append({"layer": t[0], "material_ref": row["material_ref"], "fields": fields})
	return out


func _parity(doc: Dictionary) -> Dictionary:
	return {"rows": _rows(doc), "materials": _materials(doc)}


func _init() -> void:
	WITestWatchdog.arm(self)
	var kits: Dictionary = _json(FIX + "/kits.json")
	var golden: Dictionary = _json(FIX + "/golden.json")
	var got: Dictionary = {}
	var docs: Dictionary = {}
	var top := DirAccess.open(FIX + "/maps")
	assert(top != null, "fixtures/kits/maps missing")
	for region: String in top.get_directories():
		var sub := DirAccess.open(FIX + "/maps/" + region)
		for f: String in sub.get_files():
			if not f.ends_with(".json"):
				continue
			var doc: Dictionary = _json(FIX + "/maps/" + region + "/" + f)
			var map_id := f.get_basename()
			var errs: Array = []
			docs[map_id] = WIKitResolver.resolve_map(doc, map_id, String(doc.get("kit", region)), kits, errs)
			got[map_id] = _parity(docs[map_id])
			assert(errs.is_empty(), "fixture %s: %s" % [map_id, errs])
	assert(got.keys().size() == golden.keys().size(), "fixture set drifted from golden: %s vs %s" % [got.keys(), golden.keys()])
	for map_id: String in golden:
		var want: Dictionary = {"rows": _norm_rows(golden[map_id]["rows"]), "materials": golden[map_id]["materials"]}
		assert(got[map_id] == want, "parity miss on %s:\n GD %s\n PY %s" % [map_id, JSON.stringify(got[map_id]), JSON.stringify(golden[map_id])])
	assert((got["fx_material"]["materials"] as Array).size() == 6, "fx_material must merge 6 materials")
	# Spec 2.2: fx_material's walls.segments[2] nulls its face, so it renders the material's cap [2, 0]
	# on its own cells and never the face [3, 0].
	var board := Node2D.new()
	WITileBoardBuilder.build_walls(board, docs["fx_material"]["walls"], Vector2i(7, 7), {"sheet": "res://assets/tiles/harvest/plaster_wall.png", "tile_px": 16}, WISpriteRegistry)
	var caps_only := board.get_child(board.get_child_count() - 1) as TileMapLayer
	var used: Array[Vector2i] = caps_only.get_used_cells()
	assert(used.size() == 2 and used.has(Vector2i(2, 0)) and used.has(Vector2i(3, 0)), "face-null segment must cover exactly its cells: %s" % [used])
	for cell: Vector2i in used:
		assert(caps_only.get_cell_atlas_coords(cell) == Vector2i(2, 0), "face-null segment must draw cap tiles only, got %s at %s" % [caps_only.get_cell_atlas_coords(cell), cell])
	board.free()
	# #608 final review M2: on fx_cap_fallback (five adjacent module cells, radius 3, two variants) the
	# radius excludes both variants from the third cell on, so the cap fallback picks; neither tops ceil(5/2).
	var cap_counts: Dictionary = {}
	for row: Dictionary in got["fx_cap_fallback"]["rows"]:
		cap_counts[row["sprite"]] = int(cap_counts.get(row["sprite"], 0)) + 1
	assert(cap_counts.size() == 2 and int(cap_counts.values().max()) <= 3, "fx_cap_fallback must cap each variant at 3: %s" % cap_counts)
	var real: Dictionary = {}
	var maps: Dictionary = WISceneCatalog.compose()["maps"]
	for map_id: String in maps:
		real[map_id] = _parity(maps[map_id])
	# #608: real maps carry resolved rows now; scripts/tests/test_kit_parity.py diffs them against Python.
	var out_path := OS.get_environment("WI_KIT_PARITY_OUT")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		assert(f != null, "cannot write " + out_path)
		f.store_string(JSON.stringify(real, "\t", true))
		f.close()
	print("PASS test_kit_parity (%d fixture maps, %d real maps)" % [golden.size(), real.size()])
	quit(0)
