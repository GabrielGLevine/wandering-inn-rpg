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


func _py_djb2(s: String) -> int:
	var h := 5381
	for i in s.length():
		h = (h * 33 + s.unicode_at(i)) & 0xFFFFFFFF
	return h


func _cells(n: int, role: String) -> Array:
	var out: Array = []
	for i in n:
		out.append({"sprite": "@" + role, "cell": [i % 7, i / 7]})
	return out


func _init() -> void:
	WITestWatchdog.arm(self)
	# hash: Godot String.hash() == djb2 over UTF-32 code points, incl. non-ASCII.
	for k: String in ["", "a", "inn|cargo|crate|3,4", "a<>b", "naïve|ρ|日本"]:
		assert(WIKitResolver.hash32(k) == k.hash() and WIKitResolver.hash32(k) == _py_djb2(k), "hash32 mismatch on %s" % k)
	assert(WIKitResolver.hash32("naïve|ρ|日本") == 413680424, "pinned non-ASCII hash (verified against Python 2026-10-08)")
	# score: smaller for heavier weight; strictly positive; weight 1 reproduces -ln((H+0.5)/2^32).
	var k1 := "m|cargo|c1"
	assert(is_equal_approx(WIKitResolver.score(k1, 1.0), -log((float(k1.hash()) + 0.5) / 4294967296.0)), "score formula")
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

	print("PASS test_kit_resolver")
	quit(0)
