extends SceneTree
## GH#436 self-test for `qa/oracle.gd`, the headless state-query tool.
##
## The oracle is a diagnostic instrument, and an instrument nobody checks
## becomes a confident liar: its whole value is that an author trusts its row
## counts and routes instead of re-running a script to find out. So the three
## load-bearing queries answer here against a REAL shipped fixture
## (`near_invrisil`), with the expectations written as "why this number" rather
## than as recorded output, and each one paired with a mutation that must move
## the answer -- a pin that cannot fail is not a pin.
##
## HOW IT GETS AT THE CODE: `oracle.gd` is `extends SceneTree` (it is a
## `--script` entry point), so it cannot simply be instantiated inside another
## SceneTree. It is compiled here from source with that one line swapped for
## `extends RefCounted` -- the autoload-stubbed-copy idiom `test_combat_visuals`
## already uses on `qa/test_driver.gd`. Consequence worth knowing: this test
## also IS the oracle's compile gate, so a parse error in the tool reds CI
## instead of surfacing the next time somebody happens to run it.
##
## `_initialize()` and `_load_sim()` are the only members that touch the tree;
## every query takes its `WIGame` as an argument, which is what makes them
## testable at all.

const FIXTURE := "res://qa/fixtures/near_invrisil.json"


func _init() -> void:
	WITestWatchdog.arm(self)
	var oracle := _compile_oracle()
	var sim := _sim_from_fixture()

	_check_visible_options(oracle, sim)
	_check_path(oracle, sim)
	_check_field_bar(oracle, sim)
	_check_state_and_inventory(oracle, sim)

	print("PASS: oracle answers visible_options / path / field_bar correctly against near_invrisil")
	quit()


func _compile_oracle() -> RefCounted:
	var source := FileAccess.get_file_as_string("res://qa/oracle.gd")
	assert(source.contains("extends SceneTree"), "oracle.gd must remain a --script entry point (extends SceneTree)")
	var script := GDScript.new()
	# `quit` and `root` are SceneTree members the entry point uses and the
	# queries do not; stubbing them (the driver-copy idiom) keeps the swap to a
	# single line and leaves every query body byte-identical to what ships.
	script.source_code = source.replace(
		"extends SceneTree",
		"extends RefCounted\n\nvar root: Variant = null\n\nfunc quit(_code: int = 0) -> void:\n\tpass\n")
	var err := script.reload()
	assert(err == OK, "qa/oracle.gd failed to compile: %d" % err)
	return script.new()


## The fixture is applied to a sim built the way `test_fixture_coherence` builds
## one, EXCEPT that the dialogue graphs are loaded and bank-expanded: the whole
## point of `visible_options` is the graph evaluation, and a sim with
## `"dialogue": {}` would make the key query untestable.
func _sim_from_fixture() -> WIGame:
	var shared_banks: Dictionary = WIDialogueBanks.load_shared()
	var graphs: Dictionary = {}
	var dir := DirAccess.open("res://data/dialogue")
	assert(dir != null, "data/dialogue must exist")
	for f: String in dir.get_files():
		if f.ends_with(".json") and not f.begins_with("_"):
			graphs[f.get_basename()] = WIDialogueBanks.expand(_load_json("res://data/dialogue/" + f), shared_banks)
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"quests": _load_json("res://data/quests.json"),
		"acts": _load_json("res://data/acts.json"),
		"leads": _load_json("res://data/leads.json"),
		"items": _load_json("res://data/items.json"),
		"bounties": _load_json("res://data/bounties.json"),
		"deliveries": _load_json("res://data/deliveries.json"),
		"portals": _load_json("res://data/portals.json"),
		"progression": _load_json("res://data/progression.json"),
		"fence": _load_json("res://data/fence_stock.json"),
		"dialogue": graphs,
	}
	WISceneCatalog.reset()
	var game := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"),
			func(_t: String, _p: Dictionary) -> void: pass, 9, combat_config)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert(parsed is Dictionary, "%s is not JSON" % FIXTURE)
	assert(WISave.apply(game, parsed as Dictionary), "%s must load -- the oracle's own input contract" % FIXTURE)
	return game


## THE key query. `erin_errand`'s hub authors FOURTEEN options; under
## near_invrisil's accomplishments only three survive, because accomplishment
## gates DROP their row instead of locking it and three more rows are
## `hide_when`-spent. A script that counted 14 (or 11) `move down` presses would
## WRAP and silently confirm the wrong row -- the failure this query exists to
## prevent -- so the count, the order, and the drop reasons are all pinned.
func _check_visible_options(oracle: RefCounted, sim: WIGame) -> void:
	var answer: Dictionary = oracle.call("_q_visible_options", sim, ["erin_errand", "hub"])
	assert(not answer.has("error"), "visible_options errored: %s" % str(answer.get("error", "")))
	var node: Dictionary = (sim._combat_config["dialogue"]["erin_errand"]["nodes"] as Dictionary)["hub"]
	var authored: int = (node["options"] as Array).size()
	assert(authored == 14, "erin_errand.hub authors 14 options (re-derive this test if the graph changes): got %d" % authored)
	assert(int(answer["count"]) == 3, "near_invrisil sees 3 of erin_errand.hub's 14 rows: got %d" % int(answer["count"]))
	assert(int(answer["count"]) + (answer["dropped"] as Array).size() == authored,
			"every authored row is either visible or explained as dropped")
	var rows: Array = answer["options"]
	assert(String((rows[0] as Dictionary)["text"]) == "I'll take the package.",
			"cursor 0 is the package row: got %s" % String((rows[0] as Dictionary)["text"]))
	for i in rows.size():
		var row: Dictionary = rows[i]
		assert(int(row["cursor_index"]) == i, "cursor_index is the 0-based move-down count")
		assert(int(row["click_option"]) == i + 1, "click_option is the 1-based click_dialogue_option argument")
	# authored_index 5 sits behind FOUR dropped rows: the whole reason the oracle
	# reports both numbers is that they diverge exactly here.
	assert(int((rows[2] as Dictionary)["authored_index"]) == 5,
			"the third visible row is authored index 5, not 2 -- the drop shift the cursor must not be counted against")
	var reasons: Dictionary = {}
	for d: Dictionary in (answer["dropped"] as Array):
		reasons[int(d["authored_index"])] = String(d["reason"])
		assert(not String(d["reason"]).begins_with("unknown"),
				"drop reason for authored index %d is unmodelled: %s" % [int(d["authored_index"]), String(d["reason"])])
	assert(String(reasons.get(2, "")).contains("progress gate"),
			"authored index 2 is accomplishment-gated -- DROPPED, never locked")
	assert(String(reasons.get(9, "")).contains("hide_when"),
			"authored index 9 is a spent choice removed by hide_when")

	# Falsifiable: banking the gate a dropped row waits on must ADD that row.
	# `went_fishing` is chosen because authored index 13 gates on it ALONE and
	# nothing else in the hub hides on it -- most gates here are paired with a
	# hide_when on the same counter, so raising them swaps one row for another
	# and a naive "count went up" pin would sit inert forever.
	var before: int = int(answer["count"])
	sim.accomplishments["went_fishing"] = 1
	var after: Dictionary = oracle.call("_q_visible_options", sim, ["erin_errand", "hub"])
	assert(int(after["count"]) == before + 1,
			"banking went_fishing must reveal authored index 13 (%d -> %d) -- otherwise this query is inert"
					% [before, int(after["count"])])
	sim.accomplishments.erase("went_fishing")

	var missing: Dictionary = oracle.call("_q_visible_options", sim, ["no_such_graph"])
	assert(missing.has("error"), "an unknown graph is an error, not an empty option list")


## BFS over `is_cell_blocked` -- the game's own blocker, so entities count. Erin
## STANDS on inn [7,2], which is the ordinary case for an interact target: the
## route is walkable but the cell is not standable, and the useful answer is the
## adjacent cell plus the bump direction that faces her from it.
func _check_path(oracle: RefCounted, sim: WIGame) -> void:
	var answer: Dictionary = oracle.call("_q_path", sim, ["inn", "13,6", "7,2"])
	assert(not answer.has("error"), "path errored: %s" % str(answer.get("error", "")))
	assert(bool(answer["reachable"]), "inn [13,6] -> [7,2] is walkable")
	assert(bool(answer["target_blocked"]), "[7,2] is occupied, so it is blocked")
	assert(not bool(answer["enterable"]), "a blocked target is reachable-to-face but never enterable")
	assert(String(answer["target_entity"]) == "erin", "the occupant is named: got %s" % String(answer["target_entity"]))
	var approach: Dictionary = answer["approach"]
	assert(_cells_equal(approach["cell"], [7, 3]), "the cheapest standable neighbour is [7,3]: got %s" % str(approach["cell"]))
	assert(String(approach["bump"]) == "up", "from [7,3], bumping UP faces Erin: got %s" % String(approach["bump"]))

	# The emitted driver steps must actually walk the emitted cells. This is the
	# claim an author acts on, so it is replayed rather than eyeballed.
	assert(_cells_equal(_replay(Vector2i(13, 6), answer["driver_steps"]), [7, 2]),
			"driver_steps must land on the target cell")
	assert(_cells_equal(_replay(Vector2i(13, 6), approach["driver_steps"]), [7, 3]),
			"the approach driver_steps must land on the standable cell")
	var walked: Array = answer["cells"]
	assert(walked.size() == int(answer["steps"]) + 1, "steps counts moves, cells counts cells")
	for i in range(1, walked.size()):
		var a: Array = walked[i - 1]
		var b: Array = walked[i]
		assert(absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1])) == 1,
				"the route is cardinal, one cell at a time")

	# Falsifiable control: a cell outside the grid can never be reached, and the
	# query must say so instead of inventing a route.
	var nowhere: Dictionary = oracle.call("_q_path", sim, ["inn", "13,6", "-1,-1"])
	assert(not bool(nowhere["reachable"]), "an off-grid cell is unreachable")
	assert(nowhere["approach"] == null, "an off-grid cell has no standable approach either")
	var bad_map: Dictionary = oracle.call("_q_path", sim, ["not_a_map", "0,0", "1,1"])
	assert(bad_map.has("error"), "an unknown map is an error")


## The field bar is EQUIPMENT-dependent (worn-accessory abilities are known
## while worn, ruling 2026-08-11), which is exactly why a script's `hotbar_N`
## press rots: an equip two steps earlier renumbers every slot after it. The
## mutation below is that rot, reproduced.
func _check_field_bar(oracle: RefCounted, sim: WIGame) -> void:
	var answer: Dictionary = oracle.call("_q_field_bar", sim)
	var ids: Array = (answer["slots"] as Array).map(func(s: Dictionary) -> String: return String(s["skill"]))
	assert(ids == sim.field_hotbar_loadout(), "the oracle reports field_hotbar_loadout() verbatim, in order")
	assert(ids == ["basic_cleaning", "sneak", "observe", "basic_swordwork"],
			"near_invrisil (warrior 2, no accessory) fields exactly these four: got %s" % str(ids))
	for slot: Dictionary in (answer["slots"] as Array):
		assert(bool(slot["number_key_reachable"]), "four slots are all inside hotbar_1..9")
		assert(String(slot["press"]) == "hotbar_%d" % int(slot["slot"]), "each slot names the driver action that presses it")
	assert((answer["number_key_unreachable"] as Array).is_empty(), "nothing overflows past slot 9 here")

	# Equipping an ability-bearing accessory must move the bar -- the ruling, and
	# the reason this query exists rather than reading player_skills.
	sim.equipped["accessory_1"] = "moon_bone_amulet"
	var worn: Dictionary = oracle.call("_q_field_bar", sim)
	var worn_ids: Array = (worn["slots"] as Array).map(func(s: Dictionary) -> String: return String(s["skill"]))
	assert(worn_ids.has("invisibility"),
			"a worn moon_bone_amulet puts [Invisibility] on the FIELD bar: got %s" % str(worn_ids))
	assert(int(worn["count"]) == int(answer["count"]) + 1, "the equip adds exactly one slot")
	var known: Dictionary = oracle.call("_q_known_skills", sim)
	var worn_rows: Array = known["worn"]
	assert(worn_rows.size() == 1 and String((worn_rows[0] as Dictionary)["skill"]) == "invisibility",
			"known_skills attributes the ability to the item that grants it")
	sim.equipped["accessory_1"] = ""


func _check_state_and_inventory(oracle: RefCounted, sim: WIGame) -> void:
	var gold: Dictionary = oracle.call("_q_state", sim, ["gold"])
	assert(int(gold["value"]) == sim.gold, "state reads snapshot(): gold")
	var nested: Dictionary = oracle.call("_q_state", sim, ["classes.warrior"])
	assert(int(nested["value"]) == int(sim.classes["warrior"]), "state walks dotted paths")
	var whole: Dictionary = oracle.call("_q_state", sim, [])
	assert((whole["value"] as Dictionary).has("current_map"), "an empty path dumps the whole snapshot")
	var missing: Dictionary = oracle.call("_q_state", sim, ["classes.no_such_class"])
	assert(missing.has("error"), "a missing path errors (assert_state's own behaviour) instead of reporting null")

	var inv: Dictionary = oracle.call("_q_inventory", sim)
	var inv_ids: Array = (inv["items"] as Array).map(func(r: Dictionary) -> String: return String(r["id"]))
	assert(inv_ids == sim.inventory, "inventory is reported in INSERTION order -- that is the picker cursor order")
	for i in (inv["items"] as Array).size():
		assert(int((inv["items"][i] as Dictionary)["row"]) == i + 1, "row is the 1-based click_inventory_row argument")

	var portals: Dictionary = oracle.call("_q_portal_rows", sim)
	var indices: Array = []
	for row: Dictionary in (portals["rows"] as Array):
		if row["menu_index"] != null:
			indices.append(int(row["menu_index"]))
		if bool(row["excluded_current_map"]):
			assert(row["menu_index"] == null, "the current map never gets a menu row")
	indices.sort()
	var expected: Array = []
	for i in indices.size():
		expected.append(i + 1)
	assert(indices == expected, "menu_index is a dense 1-based cursor order: got %s" % str(indices))
	assert(int(portals["never_mind_index"]) == indices.size() + 1,
			"'Let it be.' is the last cursor stop -- the row a wrapped cursor lands on")


func _replay(from: Vector2i, driver_steps: Array) -> Array:
	var cur := from
	var deltas := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
	for step: Dictionary in driver_steps:
		assert(String(step["action"]) == "move", "driver_steps emit the driver's own `move` action")
		for i in int(step["steps"]):
			cur += deltas[String(step["direction"])] as Vector2i
	return [cur.x, cur.y]


func _cells_equal(a: Variant, b: Array) -> bool:
	# JSON/int boundary: oracle cells are int Arrays, but a caller's literal may
	# not be, so compare numerically rather than with Array ==.
	if not (a is Array) or (a as Array).size() != b.size():
		return false
	for i in b.size():
		if int((a as Array)[i]) != int(b[i]):
			return false
	return true


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
