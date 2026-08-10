extends SceneTree

## GH#424 (CHOICE-RULING 30, architecture split): the CELL-LEVEL half of the
## reachability wave. `data_lint.check_content_reachability` owns the ID-level
## graph (a Skill nothing grants, an item nothing hands out, a dialogue node
## nothing gotos, a map no door reaches). It deliberately stops at ids, because
## walkability is a SIM PREDICATE and the #413 lesson is that a sim predicate
## re-derived in a second language drifts from the engine and then lies.
##
## So this suite never re-derives anything: it boots the REAL `WIGame` over the
## REAL `WISceneCatalog.compose()` catalog, binds every shipped map through the
## REAL `bind_map_silent`, and floods with the REAL `is_cell_blocked`. What it
## adds on top is one question the engine never asks itself: can a player
## STAND somewhere that can talk to this thing?
##
## THE PREDICATE IT MIRRORS: `WIGame.interact()` dispatches on
## `entity_at(player_cell + player_facing)` (src/core/wi_game.gd:571), and
## `player_facing` is `_nearest_cardinal(dir)` -- diagonals collapse to a
## cardinal, so the faced cell is ALWAYS one of the four orthogonal neighbours.
## An interactable whose only free neighbours are diagonal is shipped content no
## player can ever reach, which is exactly the Hedault defect this wave found.
##
## BEST-CASE WORLD, ON PURPOSE (`_open_the_world`). "Unreachable" has to mean
## unreachable in EVERY state a player can get into, or the suite just
## rediscovers the game's own design: a skill-gated pocket (#398) is SUPPOSED to
## be walled off until you own the Skill, and a cold-boot flood reports all
## seven of them as defects. So the flood runs over the world at its most open:
## every Skill known, every freezable cell already ice, every `present_when`
## entity absent (they are all conditional by construction -- a wall that comes
## and goes is not a wall), and every `burnable`/`cuttable` blocker cleared
## (those flags exist precisely so a Skill removes them). What survives that is
## permanent geometry -- static `blocked` cells, wall segments, and props that
## are simply always there -- and content boxed in by permanent geometry is
## content no state of the game can reach. Hedault is the shipped example: a
## static wall, an always-present bench and an always-present door.
##
## The opening is done through the ENGINE's own hooks (`erase_entity_silent`,
## `set_frozen_cells_json`, `player_skills`) so `is_cell_blocked` stays the one
## authority on what a cell does -- nothing here re-decides blocking.
##
## Every entity is CHECKED though, gated or not: content that appears later
## still has to be reachable when it does.
##
## SEEDS are arrival cells, never door cells. You never land ON a door -- a door
## entity blocks its own cell, and `transition()` drops you on the source door's
## `to_cell`. So the flood starts from every `to_cell` aimed at this map
## (top-level `kind:"door"` rows AND the `door_when` props that carry the same
## pair), every `portals.json` row landing here, and `scene_root`'s own start
## cell for the start map.

const KNOWN_DEFECT_WAIVERS := {
	# waiver removed by #423 -- Hedault stands at mercantile_alleys (0,6) with
	# no orthogonally-adjacent standable cell, so his shop dialogue is shipped
	# content no walking player can open. #423 rebuilds the Invrisil alleys +
	# enchanter shop and lands him somewhere a player can face.
	"mercantile_alleys/hedault": "walk-unreachable today; #423 owns the layout fix",
}

## The interactable predicate, held deliberately tight (the issue's wording):
## an NPC, anything carrying a conversation, anything that banks an interact,
## and every door. Ambient `observe`/`toast`-only scenery is NOT in scope -- a
## bookshelf you can only look at from across a counter is set dressing, not a
## content dead end, and folding ~350 of them in would drown the signal.
const CONVERSATION_KEYS: Array[String] = ["conversation", "dialogue"]
const INTERACT_KEYS: Array[String] = ["on_interact_accomplishment"]

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {},
		"quests": _load_json("res://data/quests.json"),
		"items": _load_json("res://data/items.json"),
		"portals": _load_json("res://data/portals.json"),
	}


func _init() -> void:
	WITestWatchdog.arm(self)
	var scene: Dictionary = WISceneCatalog.compose()
	var game := WIGame.new(scene, _load_json("res://data/skills.json"), _sink, 12345, _combat_config())
	var maps: Dictionary = scene["maps"]
	var seeds := _arrival_cells(scene)
	_open_the_world(game, maps)

	var failures: Array[String] = []
	var waivers_fired: Dictionary = {}
	var checked := 0
	var maps_flooded := 0
	for map_id: String in maps:
		var map_doc: Dictionary = maps[map_id]
		var map_seeds: Array = seeds.get(map_id, [])
		if map_seeds.is_empty():
			# Not a duplicate of data_lint's door graph: that one asks whether the
			# map is reachable by ID. This asks whether the flood has anywhere to
			# start, which is the same fact from the cell side, and without it the
			# whole map would silently report "everything unreachable".
			failures.append("maps/%s: no arrival cell (no door `to_cell`, no portal row, not the start map) -- nothing on it can be reached" % map_id)
			continue
		var reachable := _flood(game, map_id, map_seeds)
		maps_flooded += 1
		if reachable.is_empty():
			failures.append("maps/%s: every arrival cell %s is blocked -- the flood never started" % [map_id, str(map_seeds)])
			continue
		for raw: Variant in map_doc.get("entities", []):
			if not (raw is Dictionary):
				continue
			var entity := raw as Dictionary
			if not _is_interactable(entity):
				continue
			checked += 1
			var cell := Vector2i(int(entity["cell"][0]), int(entity["cell"][1]))
			if _has_adjacent_stand(reachable, cell):
				continue
			var key := "%s/%s" % [map_id, String(entity.get("id", "?"))]
			if KNOWN_DEFECT_WAIVERS.has(key):
				waivers_fired[key] = true
				continue
			failures.append("%s (%s at %d,%d): no orthogonally-adjacent reachable standable cell -- interact() can never face it"
				% [key, String(entity.get("kind", "?")), cell.x, cell.y])

	# A waiver that stopped firing is a waiver hiding nothing, and leaving it in
	# would let the SAME defect ship again silently the day someone re-breaks the
	# layout. Retirement is forced, not optional -- when #423 lands, this arm is
	# what reds until the row is deleted.
	for key: String in KNOWN_DEFECT_WAIVERS:
		if not waivers_fired.has(key):
			failures.append("KNOWN_DEFECT_WAIVERS['%s'] is stale: the entity IS reachable now -- delete the row" % key)

	_check_detector(scene)

	if not failures.is_empty():
		print("test_interactable_reachability: %d failure(s)" % failures.size())
		for line: String in failures:
			print("INTERACT_REACH_FAIL " + line)
	# Asserted in _init's OWN frame: a failed assert inside a helper aborts that
	# frame only and the run walks on to quit(0), printing PASS over a real
	# failure (the #396 lane-d finding, same shape as test_reachability.gd:43).
	assert(failures.is_empty(), "walk-unreachable interactable(s): " + ", ".join(failures))
	print("PASS: interactable adjacency — %d interactables across %d maps, all orthogonally reachable (%d waived)"
		% [checked, maps_flooded, waivers_fired.size()])
	quit(0)


## Put the world in its most-open state, through the engine's own hooks only.
## Three moves, each answering one class of temporary obstacle:
##   1. every Skill known -- [Even Footing]'s passive read (is_cell_blocked ->
##      _even_footing_crosses) crosses `unsteady` cells for a PC who has it.
##   2. every freezable cell frozen -- the ice-tile crossing (the pond island
##      and the river islet are reachable ONLY across ice), fed through
##      set_frozen_cells_json off the loader's OWN freezable set, so a
##      water-tagged wall segment counts without this file expanding one.
##   3. every conditional or clearable blocker erased -- `present_when` props
##      (the slab you shoulder aside, the guardian you defeat) and
##      `burnable`/`cuttable` props (the briar you burn through).
## `_maps[..]["freezable"]` is read straight off the loader on purpose: it is
## the set the ENGINE built (map `freezable` list PLUS every cell of a
## `water: true` wall segment), so this file never expands a segment itself.
func _open_the_world(game: WIGame, maps: Dictionary) -> void:
	for raw: Variant in _load_json("res://data/skills.json").get("skills", []):
		if raw is Dictionary:
			game.player_skills.append(String((raw as Dictionary)[WIKeys.ID]))
	var frozen: Dictionary = {}
	for map_id: String in maps:
		var cells: Array = []
		for cell: Vector2i in (game._maps[map_id]["freezable"] as Dictionary):
			cells.append([cell.x, cell.y])
		if not cells.is_empty():
			frozen[map_id] = cells
		for raw: Variant in (maps[map_id] as Dictionary).get("entities", []):
			if not (raw is Dictionary):
				continue
			var entity := raw as Dictionary
			if entity.has("present_when") or bool(entity.get("burnable", false)) or bool(entity.get("cuttable", false)):
				game.erase_entity_silent(String(entity.get("id", "")))
	game.set_frozen_cells_json(frozen)


## kind:"npc" | carries a conversation | banks an interact | is a door (top-level
## `kind:"door"`, or the `door_when` props that are doors in everything but the
## kind field -- street's sewer_grate is the shipped example).
func _is_interactable(entity: Dictionary) -> bool:
	if not (entity.get("cell") is Array and (entity["cell"] as Array).size() == 2):
		return false
	var kind := String(entity.get("kind", ""))
	if kind == "npc" or kind == "door":
		return true
	if entity.has("door_when"):
		return true
	for key: String in CONVERSATION_KEYS:
		if String(entity.get(key, "")) != "":
			return true
	for key: String in INTERACT_KEYS:
		if entity.has(key):
			return true
	return false


func _has_adjacent_stand(reachable: Dictionary, cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if reachable.has(cell + step):
			return true
	return false


## Four-way flood over the REAL engine predicate. Cardinal-only on purpose: the
## sim's own diagonal step (move_player) refuses a diagonal whose two orthogonal
## legs are both blocked, so a cardinal flood is the conservative subset -- it
## can never claim a cell the player cannot actually walk to.
func _flood(game: WIGame, map_id: String, seed_cells: Array) -> Dictionary:
	var reachable: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for raw: Variant in seed_cells:
		var seed_cell: Vector2i = raw
		game.bind_map_silent(map_id, seed_cell)
		if game.is_cell_blocked(seed_cell) or reachable.has(seed_cell):
			continue
		reachable[seed_cell] = true
		frontier.append(seed_cell)
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if reachable.has(next) or game.is_cell_blocked(next):
				continue
			reachable[next] = true
			frontier.append(next)
	return reachable


## map_id -> Array[Vector2i] of every cell a player can be PUT on.
func _arrival_cells(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var add := func(map_id: String, cell: Vector2i) -> void:
		if not out.has(map_id):
			out[map_id] = []
		if not (out[map_id] as Array).has(cell):
			(out[map_id] as Array).append(cell)
	var player: Dictionary = scene.get("player", {})
	if player.get("cell") is Array:
		add.call(String(scene.get("start_map", "")), Vector2i(int(player["cell"][0]), int(player["cell"][1])))
	var transitions: Array = []
	for map_id: String in scene.get("maps", {}):
		_collect_transitions((scene["maps"][map_id] as Dictionary).get("entities", []), transitions)
	for pair: Dictionary in transitions:
		add.call(String(pair["to_map"]), Vector2i(int(pair["to_cell"][0]), int(pair["to_cell"][1])))
	for row: Variant in _load_json("res://data/portals.json").get("portals", []):
		if row is Dictionary and (row as Dictionary).get("cell") is Array:
			add.call(String((row as Dictionary).get("map", "")), Vector2i(int(row["cell"][0]), int(row["cell"][1])))
	return out


## RECURSIVE by necessity: a door pair is top-level on `kind:"door"` rows but
## nested inside `door_when` (and could nest inside a `variants` arm tomorrow).
## Matching on the PAIR rather than on a key path means a new nesting site is
## found the day it ships, with no edit here.
func _collect_transitions(node: Variant, out: Array) -> void:
	if node is Array:
		for child: Variant in (node as Array):
			_collect_transitions(child, out)
		return
	if not (node is Dictionary):
		return
	var dict := node as Dictionary
	if String(dict.get("to_map", "")) != "" and dict.get("to_cell") is Array:
		out.append({"to_map": String(dict["to_map"]), "to_cell": dict["to_cell"]})
	for key: Variant in dict:
		_collect_transitions(dict[key], out)


## NEGATIVE CONTROL. The assert above only ever proves "nothing is broken",
## which is also what a flood that silently marks every cell reachable prints.
## So: take a real map, wall the four neighbours of a real interactable in a
## SYNTHETIC copy of the catalog, and prove the detector says so. Never touches
## shipped data -- the mutation lives in an in-memory Dictionary.
func _check_detector(scene: Dictionary) -> void:
	var scene_copy: Dictionary = scene.duplicate(true)
	var maps: Dictionary = scene_copy["maps"]
	var probe_map := "inn"
	var probe: Dictionary = {}
	for raw: Variant in (maps[probe_map] as Dictionary)["entities"]:
		if raw is Dictionary and _is_interactable(raw as Dictionary) and String((raw as Dictionary).get("kind", "")) == "npc":
			probe = raw as Dictionary
			break
	assert(not probe.is_empty(), "detector control needs an NPC on the %s map" % probe_map)
	var cell := Vector2i(int(probe["cell"][0]), int(probe["cell"][1]))
	var blocked: Array = (maps[probe_map] as Dictionary).get("blocked", []).duplicate(true)
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		blocked.append([cell.x + step.x, cell.y + step.y])
	(maps[probe_map] as Dictionary)["blocked"] = blocked
	var walled := WIGame.new(scene_copy, _load_json("res://data/skills.json"), _sink, 12345, _combat_config())
	_open_the_world(walled, maps)
	var seeds := _arrival_cells(scene_copy)
	var reachable := _flood(walled, probe_map, seeds.get(probe_map, []))
	assert(not reachable.is_empty(), "detector control: the synthetic %s flood still has to start" % probe_map)
	assert(not _has_adjacent_stand(reachable, cell),
		"DETECTOR CONTROL: walling every neighbour of %s/%s must make it unreachable -- the flood is over-reporting"
			% [probe_map, String(probe.get("id", "?"))])
