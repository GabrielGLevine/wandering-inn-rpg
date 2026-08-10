extends SceneTree

## GH#424 (CHOICE-RULING 30, architecture split): the CELL-LEVEL half of the
## reachability wave. `data_lint.check_content_reachability` owns the ID-level
## graph (a Skill nothing grants, an item nothing hands out, a dialogue node
## nothing gotos, a map no door reaches) AND the gate-carrier join (whether a
## LEARNABLE Skill still clears each burnable/cuttable/freezable gate -- review
## I-3). It stops at ids on purpose, because walkability is a SIM PREDICATE and
## the #413 lesson is that a sim predicate re-derived in a second language
## drifts from the engine and then lies.
##
## THE DIVISION, stated once so neither side grows into the other:
##   * lint  -- CAPABILITY. Which Skills can a player actually learn, and does
##              every gate still have a live carrier among them?
##   * suite -- GEOMETRY under maximum capability. Given every Skill, is there
##              anywhere to STAND? That is why `_open_the_world` below grants
##              everything and never asks whether a grant path exists: asking
##              would be re-deriving the lint's graph in GDScript.
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
## be walled off until you own the Skill, and a cold-boot flood reported five of
## them as defects on this lane's first run. So the flood runs over the world at
## its most open: every Skill known, every freezable cell already ice, every
## `present_when` entity absent (they are all conditional by construction -- a
## wall that comes and goes is not a wall), and every `burnable`/`cuttable`
## blocker cleared (those flags exist precisely so a Skill removes them). What
## survives that is permanent geometry -- static `blocked` cells, wall segments,
## and props that are simply always there -- and content boxed in by permanent
## geometry is content no state of the game can reach. Hedault is the shipped
## example: a static wall, an always-present bench and an always-present door.
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

## DEFECTS, waived because a named issue is fixing them. A row here that stops
## firing FAILS the suite -- retirement is forced, never optional, so the
## exemption cannot outlive the bug and quietly cover the next one.
const KNOWN_DEFECT_WAIVERS := {
	# Empty since #423 landed Hedault walk-reachable in his enchanter shop --
	# the suite's first stale-waiver retirement, forced by CI on the composed
	# tree exactly as designed. Add rows ONLY with a named owning issue.
}

## NOT defects: content DELIBERATELY parked out of walking reach, each row
## backed by the entity's own `_comment` in the map file. Different semantics
## from the list above on purpose (review I-1): these are permanent, so an
## unfired row is NOT an error -- the day the layout changes and the entity
## becomes reachable, nothing is broken and nothing needs saying.
const DESIGN_WAIVERS := {
	# mercantile_alleys.broker_hands `_comment`: "#318 beat 2 FIGHT arm,
	# committed from the hub only. present_when is FORBIDDEN on encounters, so
	# the rig parks hidden on wall cell (5,4), which has no walkable neighbour.
	# start_combat resolves by id and reads neither adjacency nor
	# encounter_when, so `call_them` is the single door."
	"mercantile_alleys/broker_hands": "dialogue-committed encounter rig, parked hidden by design (#318 beat 2)",
}

## THE INTERACTABLE PREDICATE = every arm `WIInteractions.dispatch` actually
## has. The `npc`, `door` and `encounter` kinds dispatch whole; a `prop`
## dispatches on whichever of `WIInteractions.PROP_ARM_KEYS` it carries. A prop
## with NONE of them falls through to the bare `_use_skill("")` refusal --
## ambient scenery, excluded, but COUNTED and reported so it is never silent.
##
## The key list is NOT copied here (review I-1): it lives on WIInteractions,
## beside the match block it describes, and a python tripwire in
## scripts/tests/test_data_lint.py re-extracts the arms from interactions.gd's
## OWN text and asserts the const still equals them. A second hand-copy here --
## with hand-maintained line citations that were already 8-for-8 stale -- is the
## exact drift that contract exists to prevent.
const INTERACTABLE_KINDS: Array[String] = ["npc", "door", "encounter"]

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
	var blockers := _open_the_world(game, maps)

	var failures: Array[String] = []
	var waivers_fired: Dictionary = {}
	var design_waived := 0
	var reported: Dictionary = {}
	var total := 0
	var checked := 0
	var ambient := 0
	var malformed := 0
	var gates_checked := 0
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
			total += 1
			if not _has_cell(entity):
				# Review M-5: never drop a row silently. check_maps fails hard on
				# a malformed cell, so this counter should read 0 forever -- and
				# if it ever does not, the PASS line says so out loud.
				malformed += 1
				continue
			if not _is_interactable(entity):
				ambient += 1
				continue
			checked += 1
			var cell := _cell_of(entity)
			var key := "%s/%s" % [map_id, String(entity.get("id", "?"))]
			if _has_adjacent_stand(reachable, cell):
				continue
			if DESIGN_WAIVERS.has(key):
				design_waived += 1
				continue
			if KNOWN_DEFECT_WAIVERS.has(key):
				waivers_fired[key] = true
				continue
			reported[key] = true
			failures.append("%s (%s at %d,%d): no orthogonally-adjacent reachable standable cell -- interact() can never face it"
				% [key, String(entity.get("kind", "?")), cell.x, cell.y])
		# Review I-4: a GATE you cannot stand next to seals its own pocket. The
		# blocker was erased before the flood, so `reachable` is exactly "the
		# world with this obstacle gone" -- if nothing borders it even then, no
		# player can ever aim the clearing Skill at it.
		for blocker: Dictionary in blockers.get(map_id, []):
			gates_checked += 1
			var bcell: Vector2i = blocker["cell"]
			var bkey := "%s/%s" % [map_id, String(blocker["id"])]
			if _has_adjacent_stand(reachable, bcell) or reported.has(bkey) or DESIGN_WAIVERS.has(bkey) or KNOWN_DEFECT_WAIVERS.has(bkey):
				continue
			reported[bkey] = true
			# Review-minor: the two blocker classes clear by DIFFERENT means, so
			# they must not share a sentence. A burnable/cuttable gate is cleared
			# by a Skill AIMED at it from an adjacent cell, so no adjacent cell
			# means no cast is possible -- a hard defect. A `present_when` blocker
			# clears when a world counter banks, which needs no adjacency at all;
			# what its missing neighbour costs is the ability to interact with the
			# thing itself while it is there.
			if String(blocker["why"]) == "burnable/cuttable":
				failures.append("%s (burnable/cuttable gate at %d,%d): no orthogonally-adjacent standable cell even with the gate itself removed -- no Skill can ever be aimed at it, so whatever it seals is unreachable"
					% [bkey, bcell.x, bcell.y])
			else:
				failures.append("%s (present_when blocker at %d,%d): no orthogonally-adjacent standable cell even with the blocker itself removed -- its counter may still flip it, but nothing on this map can be interacted with from beside it"
					% [bkey, bcell.x, bcell.y])

	# A waiver that stopped firing is a waiver hiding nothing, and leaving it in
	# would let the SAME defect ship again silently the day someone re-breaks the
	# layout. Retirement is forced, not optional -- when #423 lands, this arm is
	# what reds until the row is deleted. DESIGN_WAIVERS deliberately has no such
	# arm: a permanent park that becomes reachable is not news.
	for key: String in KNOWN_DEFECT_WAIVERS:
		if not waivers_fired.has(key):
			failures.append("KNOWN_DEFECT_WAIVERS['%s'] is stale: the entity IS reachable now -- delete the row" % key)

	# Review I-2: the control's own verdict joins `failures` instead of
	# asserting in its own frame. A failed assert inside a helper aborts that
	# frame only, so the run walked on to quit(0) and printed PASS over a broken
	# detector -- the exact #396 lane-d shape this suite documents elsewhere.
	failures.append_array(_detector_failures(scene))

	if not failures.is_empty():
		print("test_interactable_reachability: %d failure(s)" % failures.size())
		for line: String in failures:
			print("INTERACT_REACH_FAIL " + line)
	# Asserted in _init's OWN frame, for that same reason.
	assert(failures.is_empty(), "walk-unreachable interactable(s): " + ", ".join(failures))
	print("PASS: interactable adjacency — checked %d/%d catalog entities across %d maps (excluded %d: %d ambient scenery with no dispatch arm, %d malformed cell), %d gate blockers, %d known-defect waiver(s), %d design waiver(s)"
		% [checked, total, maps_flooded, ambient + malformed, ambient, malformed, gates_checked, waivers_fired.size(), design_waived])
	print("test_interactable_reachability: DISCLOSURE — blink traversal is unmodelled (review M-6): a pocket whose ONLY way in is [Double Step]/[Flash Step] would false-red here. None ships today; every shipped blink mode is a SECOND mode beside a property or arm mode.")
	quit(0)


## Put the world in its most-open state, through the engine's own hooks only.
## Returns map_id -> Array of {id, cell, why} for every blocker it erased, so
## the caller can hold each gate to the same adjacency rule (review I-4).
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
##
## NOT MODELLED (review M-6, deliberate, disclosed in the output): BLINK. A
## `blinks` Skill jumps the PC over blocked cells entirely, which no flood step
## can express, so a pocket whose only entrance is a blink would false-red.
## Nothing ships in that shape -- every `mechanism: "blink"` row in a map's
## `skill_gates` registry is the SECOND mode beside a property or arm mode that
## this flood does model -- and modelling it means teaching the flood to hop,
## which is re-deriving a sim rule. Revisit if a blink-only pocket ever ships.
func _open_the_world(game: WIGame, maps: Dictionary) -> Dictionary:
	var blockers: Dictionary = {}
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
		blockers[map_id] = []
		for raw: Variant in (maps[map_id] as Dictionary).get("entities", []):
			if not (raw is Dictionary):
				continue
			var entity := raw as Dictionary
			if not _has_cell(entity):
				continue
			var why := ""
			if bool(entity.get("burnable", false)) or bool(entity.get("cuttable", false)):
				why = "burnable/cuttable"
			elif entity.has("present_when"):
				why = "present_when"
			if why == "":
				continue
			(blockers[map_id] as Array).append({
				"id": String(entity.get("id", "?")), "cell": _cell_of(entity), "why": why,
			})
			game.erase_entity_silent(String(entity.get("id", "")))
	game.set_frozen_cells_json(frozen)
	return blockers


func _has_cell(entity: Dictionary) -> bool:
	return entity.get("cell") is Array and (entity["cell"] as Array).size() == 2


func _cell_of(entity: Dictionary) -> Vector2i:
	return Vector2i(int(entity["cell"][0]), int(entity["cell"][1]))


## Every arm `WIInteractions.dispatch` has -- see WIInteractions.PROP_ARM_KEYS.
func _is_interactable(entity: Dictionary) -> bool:
	if not _has_cell(entity):
		return false
	if INTERACTABLE_KINDS.has(String(entity.get("kind", ""))):
		return true
	for key: String in WIInteractions.PROP_ARM_KEYS:
		var value: Variant = entity.get(key, null)
		if value == null:
			continue
		if value is String:
			if String(value) != "":
				return true
		elif value is Dictionary:
			if not (value as Dictionary).is_empty():
				return true
		elif value is Array:
			if not (value as Array).is_empty():
				return true
		elif bool(value):
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
##
## RETURNS its verdict (review I-2) rather than asserting: an assert in here
## aborts this frame only, prints SCRIPT ERROR, and lets `_init` run on to
## quit(0) -- rc 0 with PASS on a broken detector, which is worse than no
## control at all.
func _detector_failures(scene: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var scene_copy: Dictionary = scene.duplicate(true)
	var maps: Dictionary = scene_copy["maps"]
	var probe_map := "inn"
	var probe: Dictionary = {}
	for raw: Variant in (maps[probe_map] as Dictionary)["entities"]:
		if raw is Dictionary and String((raw as Dictionary).get("kind", "")) == "npc" and _has_cell(raw as Dictionary):
			probe = raw as Dictionary
			break
	if probe.is_empty():
		out.append("DETECTOR CONTROL: no NPC on the %s map to probe with" % probe_map)
		return out
	var cell := _cell_of(probe)
	var blocked: Array = (maps[probe_map] as Dictionary).get("blocked", []).duplicate(true)
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		blocked.append([cell.x + step.x, cell.y + step.y])
	(maps[probe_map] as Dictionary)["blocked"] = blocked
	var walled := WIGame.new(scene_copy, _load_json("res://data/skills.json"), _sink, 12345, _combat_config())
	_open_the_world(walled, maps)
	var seeds := _arrival_cells(scene_copy)
	var reachable := _flood(walled, probe_map, seeds.get(probe_map, []))
	if reachable.is_empty():
		out.append("DETECTOR CONTROL: the synthetic %s flood never started, so it proves nothing" % probe_map)
		return out
	if _has_adjacent_stand(reachable, cell):
		out.append("DETECTOR CONTROL: walling every neighbour of %s/%s must make it unreachable -- the flood is over-reporting"
			% [probe_map, String(probe.get("id", "?"))])
	return out
