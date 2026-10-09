class_name WIKitResolver
extends RefCounted

## #607 regional kits: resolves "@role" sprites and "@material" looks at compose
## time (index C3/C4). Pure static -- no I/O, no autoloads. Mirror:
## scripts/wi_kits_lib.py; tests/test_kit_parity.gd pins both runtimes together.
## H is the first 32 bits of SHA-256 (djb2 is linear and correlates variants).
## Picks depend only on (map, role, cell), never on pool order. An unresolvable
## ref is appended to `errors` and its row is returned untouched; the CATALOG
## asserts, because an assert here would hang every --script suite.

const MATERIAL_FIELDS := ["sheet", "tile_px", "coords", "variants", "tone", "wang_corners", "cap", "face", "fallback_render"]
const TWO_32 := 4294967296.0


static func hash32(key: String) -> int:
	return key.sha256_text().substr(0, 8).hex_to_int()


static func score(key: String, weight: float) -> float:
	return -log((float(hash32(key)) + 0.5) / TWO_32) / weight


static func subset_size(n_placements: int, pool_size: int) -> int:
	return mini(clampi(2 + n_placements / 6, 2, 4), pool_size)


static func lookup(kits: Dictionary, region: String, section: String, name: String) -> Variant:
	for scope: String in [region, "_common"]:
		var block: Dictionary = kits.get(scope, {})
		var table: Dictionary = block.get(section, {})
		if table.has(name):
			return table[name]
	return null


## [[id, weight], ...] with weights as floats; plain ids weigh 1.
static func pool_of(role: Variant) -> Array:
	var out: Array = []
	if role is String:
		return [[role, 1.0]]
	for entry: Variant in (role as Dictionary).get("pool", []):
		if entry is Array:
			out.append([String(entry[0]), float(entry[1])])
		else:
			out.append([String(entry), 1.0])
	return out


static func subset(map_key: String, role_name: String, pool: Array, k: int) -> Array:
	var scored: Array = []
	for p: Array in pool:
		scored.append([score("%s|%s|%s" % [map_key, role_name, p[0]], p[1]), p[0]])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out: Array = []
	for i in mini(k, scored.size()):
		out.append(scored[i][1])
	return out


static func rank_for(map_id: String, role_name: String, variants: Array, cell: Vector2i) -> Array:
	var scored: Array = []
	for v: String in variants:
		scored.append([score("%s|%s|%s|%d,%d" % [map_id, role_name, v, cell.x, cell.y], 1.0), v])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out: Array = []
	for s: Array in scored:
		out.append(s[1])
	return out


static func radius_for(role: Variant) -> int:
	if role is Dictionary:
		if (role as Dictionary).has("radius"):  # #608: a role's own radius overrides the defaults below
			return int((role as Dictionary)["radius"])
		if String((role as Dictionary).get("pick", "cell")) == "door":
			return 0
		if bool((role as Dictionary).get("module", false)):
			return 1
	return 2


static func resolve_map(map: Dictionary, map_id: String, region: String, kits: Dictionary, errors: Array = []) -> Dictionary:
	var out: Dictionary = map.duplicate(true)
	_resolve_materials(out, map_id, region, kits, errors)
	# Placements grouped by role across decor AND entities (one namespace per map),
	# visited in (y, x) order, ties by layer then authored index.
	var by_role: Dictionary = {}
	for layer: String in ["decor", "entities"]:
		var rows: Array = out.get(layer, [])
		for i in rows.size():
			var row: Variant = rows[i]
			if not (row is Dictionary):
				continue
			var spr: String = String((row as Dictionary).get("sprite", ""))
			if not spr.begins_with("@"):
				continue
			var role_name := spr.substr(1)
			var cell_v: Variant = (row as Dictionary).get("cell", null)
			if not (cell_v is Array) or (cell_v as Array).size() < 2:
				errors.append("maps/%s: %s[%d] sprite '@%s' has no cell" % [map_id, layer, i, role_name])
				continue
			if not by_role.has(role_name):
				by_role[role_name] = []
			by_role[role_name].append({"layer": layer, "index": i, "row": row,
				"cell": Vector2i(int(row["cell"][0]), int(row["cell"][1]))})
	for role_name: String in by_role:
		var role: Variant = lookup(kits, region, "roles", role_name)
		var placements: Array = by_role[role_name]
		if role == null:
			for p: Dictionary in placements:
				errors.append("maps/%s: %s[%d] sprite '@%s' does not resolve (region %s, _common)" % [map_id, p["layer"], p["index"], role_name, region])
			continue
		if pool_of(role).is_empty():
			for p: Dictionary in placements:
				errors.append("maps/%s: %s[%d] role '%s' has an empty pool" % [map_id, p["layer"], p["index"], role_name])
			continue
		placements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["cell"].y != b["cell"].y:
				return a["cell"].y < b["cell"].y
			if a["cell"].x != b["cell"].x:
				return a["cell"].x < b["cell"].x
			if a["layer"] != b["layer"]:
				return a["layer"] < b["layer"]
			return a["index"] < b["index"])
		_resolve_role(placements, role_name, role, map_id, errors)
	return out


static func _resolve_role(placements: Array, role_name: String, role: Variant, map_id: String, errors: Array) -> void:
	var pool := pool_of(role)
	var pick: String = String((role as Dictionary).get("pick", "cell")) if role is Dictionary else "fixed"
	if pick == "door":
		for p: Dictionary in placements:
			var row: Dictionary = p["row"]
			if String(row.get("kind", "")) != "door" or not row.has("to_map"):
				errors.append("maps/%s: %s[%d] '@%s' is a door pick on a row that is not a door with to_map" % [map_id, p["layer"], p["index"], role_name])
				continue
			var to_map := String(row["to_map"])
			var pair := "%s<>%s" % [mini_str(map_id, to_map), maxi_str(map_id, to_map)]
			_apply(row, role_name, role, subset(pair, role_name, pool, 1)[0])
		return
	var sub: Array = subset(map_id, role_name, pool, subset_size(placements.size(), pool.size()))
	if pick == "map" or pick == "fixed":
		for p: Dictionary in placements:
			_apply(p["row"], role_name, role, sub[0])
		return
	var r := radius_for(role)
	var chosen: Array = []  # [[cell, variant], ...] already visited
	for p: Dictionary in placements:
		var cell: Vector2i = p["cell"]
		var rank := rank_for(map_id, role_name, sub, cell)
		var taken := {}
		for c: Array in chosen:
			if maxi(absi(c[0].x - cell.x), absi(c[0].y - cell.y)) <= r:
				taken[c[1]] = true
		var variant: String = rank[0]
		for v: String in rank:
			if not taken.has(v):
				variant = v
				break
		chosen.append([cell, variant])
		_apply(p["row"], role_name, role, variant)


static func _apply(row: Dictionary, role_name: String, role: Variant, variant: String) -> void:
	row["sprite"] = variant
	row["sprite_role"] = role_name
	if role is Dictionary and (role as Dictionary).has("light") and not row.has("light"):
		row["light"] = ((role as Dictionary)["light"] as Dictionary).duplicate(true)


static func mini_str(a: String, b: String) -> String:
	return a if a <= b else b


static func maxi_str(a: String, b: String) -> String:
	return b if a <= b else a


static func _resolve_materials(out: Dictionary, map_id: String, region: String, kits: Dictionary, errors: Array) -> void:
	var targets: Array = []
	for i in (out.get("floor_layers", []) as Array).size():
		targets.append(["floor_layers[%d]" % i, out["floor_layers"][i]])
	var walls: Variant = out.get("walls", null)
	if walls is Dictionary:
		targets.append(["walls", walls])
		for i in ((walls as Dictionary).get("segments", []) as Array).size():
			targets.append(["walls.segments[%d]" % i, walls["segments"][i]])
	for t: Array in targets:
		var row: Variant = t[1]
		if not (row is Dictionary) or not (row as Dictionary).has("material"):
			continue
		var ref := String(row["material"])
		if not ref.begins_with("@"):
			errors.append("maps/%s: %s material '%s' must be an @reference" % [map_id, t[0], ref])
			continue
		var mat: Variant = lookup(kits, region, "materials", ref.substr(1))
		if not (mat is Dictionary):
			errors.append("maps/%s: %s material '%s' does not resolve (region %s, _common)" % [map_id, t[0], ref, region])
			continue
		for key: String in MATERIAL_FIELDS:
			if (mat as Dictionary).has(key) and not row.has(key):
				row[key] = ((mat as Dictionary)[key] as Variant).duplicate(true) if mat[key] is Dictionary or mat[key] is Array else mat[key]
		row.erase("material")
		row["material_ref"] = ref.substr(1)
