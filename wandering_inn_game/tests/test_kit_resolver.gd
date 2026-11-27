extends SceneTree

## #607 lane A: WIKitResolver contract (index C3/C4). Pure data in, data out.

const KITS := {
	"_common": {"materials": {}, "roles": {"common_lamp": "street_lamp"}, "cast": []},
	"r": {
		"materials": {"floor_a": {"sheet": "res://a.png", "tile_px": 16, "coords": [1, 2], "tone": {"base": [0.1, 0.1, 0.1], "detail": 0.5}}},
		"roles": {
			"cargo": {"pick": "cell", "pool": ["c1", ["c2", 2], "c3", "c4", "c5"]},
			"seat": {"pick": "map", "pool": ["s1", "s2", "s3"]},
			"facade": {"pick": "cell", "module": true, "pool": ["f1", "f2", "f3"]},
			"door_x": {"pick": "door", "pool": ["d1", "d2", "d3"]},
			"lamp": {"pick": "map", "pool": ["l1", "l2"], "light": {"color": [1, 0.85, 0.5], "energy": 0.9, "radius": 32}},
			"fixed": "plaza_fountain",
		},
		"cast": [],
	},
}


func _cells(n: int, role: String) -> Array:
	var out: Array = []
	for i in n:
		out.append({"sprite": "@" + role, "cell": [i % 7, i / 7]})
	return out


# The pre-#608-cap cell pick (radius exclusion only), for before/after comparisons. Cells in (y, x) order.
func _uncapped(map_id: String, role_name: String, cells: Array, kits: Dictionary) -> Array:
	var role: Dictionary = kits["r"]["roles"][role_name]
	var pool := WIKitResolver.pool_of(role)
	var sub := WIKitResolver.subset(map_id, role_name, pool, WIKitResolver.subset_size(cells.size(), pool.size()))
	var r := WIKitResolver.radius_for(role)
	var chosen: Array = []
	var out: Array = []
	for c: Vector2i in cells:
		var rank := WIKitResolver.rank_for(map_id, role_name, sub, c)
		var v: String = rank[0]
		for cand: String in rank:
			var hit := false
			for o: Array in chosen:
				if o[1] == cand and maxi(absi(o[0].x - c.x), absi(o[0].y - c.y)) <= r:
					hit = true
			if not hit:
				v = cand
				break
		chosen.append([c, v])
		out.append(v)
	return out


func _counts(names: Array) -> Dictionary:
	var out := {}
	for n: String in names:
		out[n] = int(out.get(n, 0)) + 1
	return out


func _init() -> void:
	WITestWatchdog.arm(self)
	# hash: first 32 bits of SHA-256 over UTF-8 (pins computed with Python hashlib).
	assert(WIKitResolver.hash32("abc") == 3128432319 and WIKitResolver.hash32("x") == 762385986, "sha pins")
	assert(WIKitResolver.hash32("invrisil_boulevard|cargo|crate_lidded|12,7") == 537148620, "sha pin, placement key")
	assert(WIKitResolver.hash32("naïve|ρ|日本") == 2814704703, "sha pin, non-ASCII")
	# score: smaller for heavier weight; strictly positive; weight 1 reproduces -ln((H+0.5)/2^32).
	var k1 := "m|cargo|c1"
	assert(is_equal_approx(WIKitResolver.score(k1, 1.0), -log((float(WIKitResolver.hash32(k1)) + 0.5) / 4294967296.0)), "score formula")
	assert(WIKitResolver.score(k1, 2.0) < WIKitResolver.score(k1, 1.0), "weight divides the score")

	# identity: a map with no refs comes back equal (no sprite_role leaks).
	var plain := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "crate", "cell": [1, 1]}], "entities": [{"id": "x", "kind": "npc", "sprite": "townswoman", "cell": [2, 2]}]}
	var errs: Array = []
	assert(WIKitResolver.resolve_map(plain, "m", "r", KITS, errs) == plain and errs.is_empty(), "no refs => identity")

	# subset k: n=1 -> k=2 ; n=12 -> k=4 ; capped at 4 ; min(k, |pool|).
	assert(WIKitResolver.subset_size(1, 5) == 2 and WIKitResolver.subset_size(12, 5) == 4, "k = clamp(2 + n//6, 2, 4)")
	assert(WIKitResolver.subset_size(40, 5) == 4 and WIKitResolver.subset_size(40, 3) == 3, "k capped by 4 and by pool size")

	# cell mode: every pick is a pool member, carries sprite_role, keeps authored keys,
	# and no two same-role picks within Chebyshev 2 share a variant unless forced.
	var m := {"grid": {"width": 7, "height": 7}, "decor": _cells(14, "cargo"), "entities": []}
	var out: Dictionary = WIKitResolver.resolve_map(m, "m", "r", KITS, errs)
	assert(errs.is_empty(), "cell mode resolves: %s" % [errs])
	var pool := ["c1", "c2", "c3", "c4", "c5"]
	var used := {}
	for i in out["decor"].size():
		var row: Dictionary = out["decor"][i]
		assert(row["sprite_role"] == "cargo" and pool.has(row["sprite"]) and row["cell"] == m["decor"][i]["cell"], "row %d shape" % i)
		used[row["sprite"]] = true
	assert(used.size() <= 4 and used.size() >= 2, "subset of k=4 variants, got %s" % [used.keys()])
	assert(WIKitResolver.resolve_map(m, "m", "r", KITS) == out, "edit-stable: same input, same picks")
	var exact := ["c4", "c3", "c2", "c4", "c1", "c3", "c4", "c1", "c3", "c3", "c2", "c1", "c4", "c2"]
	for i in exact.size():
		assert(out["decor"][i]["sprite"] == exact[i], "pinned pick %d (python hashlib reference)" % i)
	# stability under pool reorder: picks depend on (map, role, cell), never on array order.
	var kits2: Dictionary = KITS.duplicate(true)
	kits2["r"]["roles"]["cargo"]["pool"] = ["c5", "c4", "c3", ["c2", 2], "c1"]
	assert(WIKitResolver.resolve_map(m, "m", "r", kits2) == out, "pool order must not change picks")

	# neighbour exclusion: two adjacent module placements (r=1) never share; r=2 for props.
	var two := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@facade", "cell": [3, 3]}, {"sprite": "@facade", "cell": [4, 3]}], "entities": []}
	var two_out: Dictionary = WIKitResolver.resolve_map(two, "m", "r", KITS)
	assert(two_out["decor"][0]["sprite"] != two_out["decor"][1]["sprite"], "module r=1 excludes the neighbour")
	var far := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@cargo", "cell": [0, 0]}, {"sprite": "@cargo", "cell": [2, 0]}], "entities": []}
	var far_out: Dictionary = WIKitResolver.resolve_map(far, "m", "r", KITS)
	assert(far_out["decor"][0]["sprite"] != far_out["decor"][1]["sprite"], "prop r=2 excludes distance-2 neighbour")
	# forced fallback: with a 2-variant pool and 3 mutually-adjacent placements the third takes rank_p[0].
	var kits3: Dictionary = KITS.duplicate(true)
	kits3["r"]["roles"]["tri"] = {"pick": "cell", "pool": ["t1", "t2"]}
	var tri := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@tri", "cell": [1, 1]}, {"sprite": "@tri", "cell": [2, 1]}, {"sprite": "@tri", "cell": [3, 1]}], "entities": []}
	var tri_out: Dictionary = WIKitResolver.resolve_map(tri, "m", "r", kits3)
	assert(tri_out["decor"][2]["sprite"] == WIKitResolver.rank_for("m", "tri", ["t1", "t2"], Vector2i(3, 1))[0], "all excluded => rank_p[0]")

	# map mode: every placement takes subset[0]; a role light fills only absent light.
	var seats := {"grid": {"width": 7, "height": 7}, "decor": _cells(5, "seat"), "entities": [{"id": "l1", "kind": "prop", "sprite": "@lamp", "cell": [6, 6]}, {"id": "l2", "kind": "prop", "sprite": "@lamp", "cell": [6, 5], "light": {"energy": 0.1}}]}
	var seat_out: Dictionary = WIKitResolver.resolve_map(seats, "m", "r", KITS)
	var first: String = seat_out["decor"][0]["sprite"]
	for row: Dictionary in seat_out["decor"]:
		assert(row["sprite"] == first and ["s1", "s2", "s3"].has(first), "map mode: one variant for the whole map")
	assert(seat_out["entities"][0]["light"] == KITS["r"]["roles"]["lamp"]["light"], "role light copied when absent")
	assert(seat_out["entities"][1]["light"] == {"energy": 0.1}, "row light wins")

	# door mode: seeded on the unordered pair, so both sides match; no cell component.
	var a := {"grid": {"width": 7, "height": 7}, "decor": [], "entities": [{"id": "a_to_b", "kind": "door", "to_map": "b", "sprite": "@door_x", "cell": [0, 0]}, {"id": "a_to_b2", "kind": "door", "to_map": "b", "sprite": "@door_x", "cell": [5, 5]}]}
	var b := {"grid": {"width": 7, "height": 7}, "decor": [], "entities": [{"id": "b_to_a", "kind": "door", "to_map": "a", "sprite": "@door_x", "cell": [3, 1]}]}
	var a_out: Dictionary = WIKitResolver.resolve_map(a, "a", "r", KITS)
	var b_out: Dictionary = WIKitResolver.resolve_map(b, "b", "r", KITS)
	assert(a_out["entities"][0]["sprite"] == b_out["entities"][0]["sprite"], "portal pair symmetry")
	assert(a_out["entities"][0]["sprite"] == a_out["entities"][1]["sprite"], "every portal between the same two maps shares one variant")
	var door_errs: Array = []
	WIKitResolver.resolve_map({"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@door_x", "cell": [1, 1]}], "entities": []}, "a", "r", KITS, door_errs)
	assert(door_errs.size() == 1, "door pick on a non-door row is an error")

	# fixed string role and _common fallback.
	var fx := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@fixed", "cell": [1, 1]}, {"sprite": "@common_lamp", "cell": [2, 2]}], "entities": []}
	var fx_out: Dictionary = WIKitResolver.resolve_map(fx, "m", "r", KITS)
	assert(fx_out["decor"][0]["sprite"] == "plaza_fountain" and fx_out["decor"][0]["sprite_role"] == "fixed", "plain string role")
	assert(fx_out["decor"][1]["sprite"] == "street_lamp" and fx_out["decor"][1]["sprite_role"] == "common_lamp", "_common fallback")

	# material merge fills only absent keys; cells stay authored; material_ref added; walls too.
	var mat := {"grid": {"width": 7, "height": 7}, "decor": [], "entities": [],
		"floor_layers": [{"material": "@floor_a", "cells": "all", "tone": {"base": [0.9, 0.9, 0.9], "detail": 0.1}}],
		"walls": {"material": "@floor_a", "segments": [{"material": "@floor_a", "from": [0, 0], "to": [3, 0], "cap": [9, 9]}]}}
	var mat_out: Dictionary = WIKitResolver.resolve_map(mat, "m", "r", KITS)
	var fl: Dictionary = mat_out["floor_layers"][0]
	assert(fl["sheet"] == "res://a.png" and fl["coords"] == [1, 2] and fl["cells"] == "all", "material supplies look, map keeps geometry")
	assert(fl["tone"]["detail"] == 0.1 and fl["material_ref"] == "floor_a" and not fl.has("material"), "authored tone wins; ref recorded")
	assert(mat_out["walls"]["sheet"] == "res://a.png" and mat_out["walls"]["segments"][0]["cap"] == [9, 9] and mat_out["walls"]["segments"][0]["from"] == [0, 0], "walls + segments merge")

	# unresolvable => error reported, row untouched, no assert.
	var bad := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@nope", "cell": [1, 1]}], "entities": [{"id": "e", "kind": "prop", "sprite": "@nope", "cell": [2, 2]}], "floor_layers": [{"material": "@nomat", "cells": "all"}]}
	var bad_errs: Array = []
	var bad_out: Dictionary = WIKitResolver.resolve_map(bad, "m", "r", KITS, bad_errs)
	assert(bad_errs.size() == 3, "one error per unresolved ref, got %s" % [bad_errs])
	assert(bad_out["decor"][0]["sprite"] == "@nope" and not bad_out["decor"][0].has("sprite_role"), "unresolved row returned unchanged")
	# region absent entirely => _common only.
	var nr: Array = []
	assert(WIKitResolver.resolve_map(fx, "m", "zz", KITS, nr)["decor"][1]["sprite"] == "street_lamp" and nr.size() == 1, "unknown region falls back to _common")

	# variety: sha-256 de-correlates variants across cells, maps and doors.
	var orders := {}
	for x in 10:
		for y in 10:
			orders[WIKitResolver.rank_for("m", "r", ["v1", "v2", "v3", "v4"], Vector2i(x, y))] = true
	assert(orders.size() >= 12, "rank orders over a 10x10 grid: %d" % orders.size())
	var subs := {}
	for i in 3:
		subs[WIKitResolver.subset("map%d" % i, "cargo", WIKitResolver.pool_of(KITS["r"]["roles"]["cargo"]), 4)] = true
	assert(subs.size() > 1, "subsets differ across maps")

	# door seed precondition: the map id alone would pick differently from the pair.
	var dpool := WIKitResolver.pool_of(KITS["r"]["roles"]["door_x"])
	assert(WIKitResolver.subset("a", "door_x", dpool, 1)[0] != "d3" and WIKitResolver.subset("b", "door_x", dpool, 1)[0] != "d3", "map-id seeds differ from pair seed")
	assert(a_out["entities"][0]["sprite"] == "d3", "pair seed a<>b picks d3 (python reference)")
	assert(door_errs.size() == 1, "door error row")
	var bad_door := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@door_x", "cell": [1, 1]}], "entities": []}
	assert(WIKitResolver.resolve_map(bad_door, "a", "r", KITS, []) == bad_door, "door-mode error row unchanged")

	# radius exactness: module r=1 reuses at distance 2; prop r=2 reuses at 3 but not 2.
	# three placements, so the #608 module cap (ceil(3/2) = 2) leaves room for the reuse
	var f2 := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@facade", "cell": [0, 0]}, {"sprite": "@facade", "cell": [2, 0]}, {"sprite": "@facade", "cell": [6, 6]}], "entities": []}
	var f2o: Dictionary = WIKitResolver.resolve_map(f2, "m", "r", KITS)
	assert(f2o["decor"][0]["sprite"] == "f2" and f2o["decor"][1]["sprite"] == "f2" and f2o["decor"][2]["sprite"] == "f3", "module may reuse at distance 2")
	var c3 := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@cargo", "cell": [0, 0]}, {"sprite": "@cargo", "cell": [3, 0]}], "entities": []}
	var c3o: Dictionary = WIKitResolver.resolve_map(c3, "m", "r", KITS)
	assert(c3o["decor"][0]["sprite"] == "c3" and c3o["decor"][1]["sprite"] == "c3", "prop may reuse at distance 3")
	var c2: Dictionary = WIKitResolver.resolve_map(far, "m", "r", KITS)
	assert(c2["decor"][0]["sprite"] == "c3" and c2["decor"][1]["sprite"] == "c2", "prop excludes at distance 2")
	# #608: a role's own "radius" overrides the default (door 0 / module 1 / prop 2); JSON hands it over as a float.
	assert(WIKitResolver.radius_for({"radius": 3}) == 3 and WIKitResolver.radius_for({"module": true, "radius": 3}) == 3, "radius override")
	assert(WIKitResolver.radius_for({"module": true, "radius": 0}) == 0 and WIKitResolver.radius_for({"pick": "door", "radius": 1}) == 1 and WIKitResolver.radius_for({"radius": 3.0}) == 3, "radius override, edges")
	var kits5: Dictionary = KITS.duplicate(true)
	kits5["r"]["roles"]["facade"]["radius"] = 3
	var f2w: Dictionary = WIKitResolver.resolve_map(f2, "m", "r", kits5)
	assert(f2w["decor"][0]["sprite"] == "f2" and f2w["decor"][1]["sprite"] == "f3" and f2w["decor"][2]["sprite"] == "f3", "radius 3 excludes the distance-2 neighbour (python reference: f2, f3, f3)")
	# #608 ruling: a module role's variant is used at most ceil(n/k) times per map, on top of the radius.
	var mrow := {"grid": {"width": 25, "height": 7}, "decor": [], "entities": []}
	var mcells: Array = []
	for i in 9:
		mrow["decor"].append({"sprite": "@facade", "cell": [3 * i, 1]})
		mcells.append(Vector2i(3 * i, 1))
	assert(_counts(_uncapped("m", "facade", mcells, KITS)).values().max() == 5, "precondition: the old rule draws one variant 5x")
	var mpicks: Array = []
	for row: Dictionary in WIKitResolver.resolve_map(mrow, "m", "r", KITS)["decor"]:
		mpicks.append(row["sprite"])
	assert(mpicks.size() == 9 and _counts(mpicks).values().max() <= 3, "module cap ceil(9/3) = 3, got %s" % [mpicks])
	var crow := {"grid": {"width": 25, "height": 7}, "decor": [], "entities": []}
	var ccells: Array = []
	for i in 9:
		crow["decor"].append({"sprite": "@cargo", "cell": [3 * i, 3]})
		ccells.append(Vector2i(3 * i, 3))
	var cwant := _uncapped("m", "cargo", ccells, KITS)
	var cpicks: Array = []
	for row: Dictionary in WIKitResolver.resolve_map(crow, "m", "r", KITS)["decor"]:
		cpicks.append(row["sprite"])
	assert(cpicks == cwant and int(_counts(cpicks).get("c3", 0)) == 5, "non-module roles are not capped: %s vs %s" % [cpicks, cwant])
	var f4 := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@facade", "cell": [0, 0]}, {"sprite": "@facade", "cell": [4, 0]}], "entities": []}
	assert(WIKitResolver.resolve_map(f4, "m", "r", kits5) == WIKitResolver.resolve_map(f4, "m", "r", KITS), "beyond the radius: picks untouched")

	# decor and entities share one count and one exclusion namespace.
	var mix := {"grid": {"width": 12, "height": 12}, "decor": [], "entities": []}
	for i in 12:
		mix["decor" if i < 6 else "entities"].append({"id": "p%d" % i, "sprite": "@cargo", "cell": [(i % 3) * 3, (i / 3) * 3]})
	var mix_out: Dictionary = WIKitResolver.resolve_map(mix, "m", "r", KITS)
	var mix_used := {}
	for row: Dictionary in mix_out["decor"] + mix_out["entities"]:
		mix_used[row["sprite"]] = true
	assert(mix_used.size() == 4, "12 combined placements => k=4 (split counts would give 3), got %s" % [mix_used.keys()])
	var same := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@cargo", "cell": [1, 1]}], "entities": [{"id": "e", "kind": "prop", "sprite": "@cargo", "cell": [1, 1]}]}
	var same_out: Dictionary = WIKitResolver.resolve_map(same, "m", "r", KITS)
	assert(same_out["decor"][0]["sprite"] == "c3" and same_out["entities"][0]["sprite"] == "c2", "same cell: decor visited first, entity excluded")

	# map mode takes the smallest variant-key score (python reference: yard -> s3).
	var yard: Dictionary = WIKitResolver.resolve_map({"grid": {"width": 7, "height": 7}, "decor": _cells(2, "seat"), "entities": []}, "yard", "r", KITS)
	assert(yard["decor"][0]["sprite"] == "s3" and yard["decor"][1]["sprite"] == "s3", "map mode smallest score")

	# error paths leave rows untouched: non-@ material, empty pool, @ row without cell.
	var nm := {"grid": {"width": 7, "height": 7}, "decor": [], "entities": [], "floor_layers": [{"material": "floor_a", "cells": "all"}]}
	var nm_errs: Array = []
	assert(WIKitResolver.resolve_map(nm, "m", "r", KITS, nm_errs) == nm and nm_errs.size() == 1, "non-@ material is an error")
	var kits4: Dictionary = KITS.duplicate(true)
	kits4["r"]["roles"]["empty"] = {"pick": "cell", "pool": []}
	var ep := {"grid": {"width": 7, "height": 7}, "decor": [{"sprite": "@empty", "cell": [1, 1]}, {"sprite": "@cargo"}], "entities": []}
	var ep_errs: Array = []
	assert(WIKitResolver.resolve_map(ep, "m", "r", kits4, ep_errs) == ep and ep_errs.size() == 2, "empty pool and missing cell: errors, rows untouched, got %s" % [ep_errs])

	var src: String = FileAccess.get_file_as_string("res://src/world/world.gd")
	var decor_body: String = src.get_slice("func _build_decor(", 1).get_slice("\nfunc ", 0)
	assert(decor_body.find("WIEvents.UI_DECOR_RENDERED") != -1 and decor_body.count("emit_domain_event") == 1, "one ui_decor_rendered per build")
	var emit_body: String = src.get_slice("func _emit_entity_visual_rendered(", 1).get_slice("\nfunc ", 0)
	assert(emit_body.find('"sprite_role"') != -1 and emit_body.find('ent.has("sprite_role")') != -1, "sprite_role rides the entity payload when present")
	assert(src.count("_emit_entity_visual_rendered(") == 4, "all three callers pass the entity row")
	var ev: String = FileAccess.get_file_as_string("res://src/core/wi_events.gd")
	assert(ev.find('const UI_DECOR_RENDERED := &"ui_decor_rendered"') != -1, "event registered in WIEvents")

	print("PASS test_kit_resolver")
	quit(0)
