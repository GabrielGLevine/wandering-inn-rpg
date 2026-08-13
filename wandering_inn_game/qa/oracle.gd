extends SceneTree
## GH#436 -- the STATE ORACLE. Answers "what state is the sim in / what would
## this dialogue show / is this cell reachable" in ~2 seconds, against a save
## file, WITHOUT running the driver.
##
## Before this existed the only way to ask those questions was to insert a
## deliberately-failing `assert_state` probe into a QA script and full-run it --
## minutes per question, one question per run, and the answer arrived as a
## failure string. This is the cheap version: one process, one JSON answer,
## arbitrarily many invocations.
##
##   godot --headless --path wandering_inn_game --script res://qa/oracle.gd -- \
##       --save=<path> --query="visible_options krshia_shop start"
##
## Both `--k=v` and `--k v` spellings are accepted; a bare `--query` swallows
## the rest of the command line, so the quotes above are optional.
##
## SAVE INPUT: any WISave the game itself can load -- `qa/fixtures/*.json`, a
## `user://saves/*.json`, or a `dump_checkpoint` artifact from GH#435. Older
## versions migrate through `WISave._migrated` exactly as a real load does.
## Omitting `--save` answers against a FRESH new-game sim.
##
## WHY THIS RUNS AS A SceneTree SCRIPT AND STILL SEES AUTOLOADS: Godot skips
## autoload registration for `--script` runs only until `_initialize()`; by the
## time that callback fires, `/root/Game` and friends are in the tree. So the
## oracle builds its sim with `Game._make_sim()` -- the game's OWN config
## assembly (dialogue banks, portals, items, phase thresholds) rather than a
## hand-rolled copy that would silently rot the first time a data file joins
## the loader. `_init()` is TOO EARLY (root has no children yet).
##
## OUTPUT: one line, `ORACLE_JSON: <compact json>`, so the answer survives the
## engine's own stdout noise (fallback_art warnings, leaked-RID lines). The
## `QA_RESULT:` prefix convention. `--out=<path>` additionally writes the bare
## JSON to a file. Exit code 0 on an answer, 1 on an error (the JSON then
## carries an `error` key and nothing else is guaranteed).

## Queries whose name is the first token of --query. Kept as data so `--query
## help` can list them and an unknown query names its alternatives.
const QUERIES := {
	"visible_options": "<graph_id> [<node_id>] -- rows dialogue.gd would SHOW under this state",
	"path": "<map> <x,y> <x,y> -- BFS over the map's blocked grid + entity cells",
	"state": "<dot.path> -- anything WIGame.snapshot() reaches (omit for the whole snapshot)",
	"progression_preview": "-- class gains, levels, the automatic consolidation, and evolution outcomes at the next sleep",
	"field_bar": "-- field_hotbar_loadout() with slot numbers and number-key reachability",
	"known_skills": "-- known_skills() split by source (innate / class grant / worn)",
	"portal_rows": "-- portals.json x accomplishments x current-map exclusion",
	"inventory": "-- carried items in insertion order (= picker cursor order)",
}

## world.gd binds number keys 1..9 only; slot ten and up are reachable by
## hotbar_prime + cursor or by touch, never by a digit. The driver has
## `hotbar_1`..`hotbar_9`, so a script cannot press past this.
const NUMBER_KEY_SLOTS := 9

const DIRECTIONS := {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var queries_path := String(args.get("queries", ""))
	if queries_path != "":
		_run_batch(queries_path, String(args.get("save", "")), String(args.get("out", "")))
		return
	var query := String(args.get("query", "")).strip_edges()
	var out_path := String(args.get("out", ""))
	var answer: Dictionary
	if query.is_empty() or query == "help":
		answer = {"queries": QUERIES}
		_emit(answer, out_path)
		quit(0)
		return
	var tokens := query.split(" ", false)
	var verb := String(tokens[0])
	var rest: Array = []
	for i in range(1, tokens.size()):
		rest.append(String(tokens[i]))
	if not QUERIES.has(verb):
		_emit({"error": "unknown query: %s" % verb, "known": QUERIES.keys()}, out_path)
		quit(1)
		return
	var sim_or_error: Variant = _load_sim(String(args.get("save", "")))
	if sim_or_error is Dictionary:
		_emit(sim_or_error as Dictionary, out_path)
		quit(1)
		return
	var sim: WIGame = sim_or_error
	match verb:
		"visible_options":
			answer = _q_visible_options(sim, rest)
		"path":
			answer = _q_path(sim, rest)
		"state":
			answer = _q_state(sim, rest)
		"progression_preview":
			answer = _q_progression_preview(sim)
		"field_bar":
			answer = _q_field_bar(sim)
		"known_skills":
			answer = _q_known_skills(sim)
		"portal_rows":
			answer = _q_portal_rows(sim)
		"inventory":
			answer = _q_inventory(sim)
		_:
			answer = {"error": "unhandled query: " + verb}
	answer["query"] = verb
	_emit(answer, out_path)
	quit(1 if answer.has("error") else 0)


## Accepts `--k=v` (QAPaths.parse_args' only shape) AND `--k v`, because the
## issue spells the interface `--save <path> --query <q>` and a tool nobody can
## type from memory does not get used. A bare `--query` with no `=` swallows
## every following token that is not itself a flag, so the quotes around a
## multi-word query are optional.
func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var i := 0
	while i < argv.size():
		var a := String(argv[i])
		if not a.begins_with("--"):
			i += 1
			continue
		var body := a.trim_prefix("--")
		if body.contains("="):
			var kv := body.split("=", true, 1)
			out[kv[0]] = kv[1]
			i += 1
			continue
		var words: Array = []
		var j := i + 1
		while j < argv.size() and not String(argv[j]).begins_with("--"):
			words.append(String(argv[j]))
			j += 1
		out[body] = " ".join(words)
		i = j
	return out


func _emit(answer: Variant, out_path: String) -> void:
	var text := JSON.stringify(answer)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
	print("ORACLE_JSON: " + text)


## Batch mode deliberately rebuilds a sim per row. It amortizes process boot
## without letting one query leak mutations into the next. Rows are either a
## query String or `{query, save?}`; the command's `--save` is the fallback.
func _run_batch(path: String, default_save: String, out_path: String) -> void:
	if not FileAccess.file_exists(path):
		_emit([{"error": "no such queries file: %s" % path}], out_path)
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		_emit([{"error": "queries file must be a JSON array: %s" % path}], out_path)
		quit(1)
		return
	var answers: Array = []
	var failed := false
	for raw: Variant in parsed:
		var request: Dictionary = raw if raw is Dictionary else {"query": String(raw)}
		var query := String(request.get("query", "")).strip_edges()
		if query.is_empty():
			answers.append({"error": "batch query is empty"})
			failed = true
			continue
		var tokens := query.split(" ", false)
		var verb := String(tokens[0])
		var rest: Array = []
		for i in range(1, tokens.size()):
			rest.append(String(tokens[i]))
		if not QUERIES.has(verb):
			answers.append({"error": "unknown query: %s" % verb, "known": QUERIES.keys()})
			failed = true
			continue
		var sim_or_error: Variant = _load_sim(String(request.get("save", default_save)))
		if sim_or_error is Dictionary:
			answers.append(sim_or_error)
			failed = true
			continue
		var answer := _answer_query(sim_or_error as WIGame, verb, rest)
		answer["query"] = verb
		answers.append(answer)
		failed = failed or answer.has("error")
	_emit(answers, out_path)
	quit(1 if failed else 0)


func _answer_query(sim: WIGame, verb: String, rest: Array) -> Dictionary:
	match verb:
		"visible_options":
			return _q_visible_options(sim, rest)
		"path":
			return _q_path(sim, rest)
		"state":
			return _q_state(sim, rest)
		"progression_preview":
			return _q_progression_preview(sim)
		"field_bar":
			return _q_field_bar(sim)
		"known_skills":
			return _q_known_skills(sim)
		"portal_rows":
			return _q_portal_rows(sim)
		"inventory":
			return _q_inventory(sim)
		_:
			return {"error": "unhandled query: " + verb}


## Returns a WIGame, or a Dictionary describing why it could not.
func _load_sim(save_path: String) -> Variant:
	var game_autoload: Variant = root.get_node_or_null("Game")
	if game_autoload == null:
		return {"error": "Game autoload not in the tree -- oracle must run from _initialize(), not _init()"}
	var sim: WIGame = game_autoload.call("_make_sim")
	if save_path == "":
		return sim
	var resolved := save_path
	if not resolved.begins_with("res://") and not resolved.begins_with("user://") \
			and not FileAccess.file_exists(resolved):
		# Bare fixture name convenience: `--save=near_invrisil`.
		var candidate := "res://qa/fixtures/%s.json" % save_path.get_file().get_basename()
		if FileAccess.file_exists(candidate):
			resolved = candidate
	if not FileAccess.file_exists(resolved):
		return {"error": "no such save: %s" % save_path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(resolved))
	if not (parsed is Dictionary):
		return {"error": "save is not a JSON object: %s" % resolved}
	if not WISave.apply(sim, parsed as Dictionary):
		return {"error": "WISave.apply REJECTED %s -- check apply()'s type guards (player_facing is a 2-vector, rng_state is a String) before blaming the version" % resolved}
	return sim


# ---------------------------------------------------------------- queries ---


## THE key query. `_visible_options` DROPS accomplishment-gated rows outright
## while skill/item/gold gates render LOCKED-but-present, and the option cursor
## WRAPS -- so a mis-counted hub silently selects the WRONG row instead of
## timing out. This answers "how many rows, in what order, which are locked"
## from the same function the panel renders from, and additionally names every
## authored row that got dropped and why.
func _q_visible_options(sim: WIGame, argv: Array) -> Dictionary:
	if argv.is_empty():
		return {"error": "visible_options needs a graph id: %s" % QUERIES["visible_options"]}
	var graph_id := String(argv[0])
	var graph := _resolve_graph(sim, graph_id)
	if graph.is_empty():
		return {"error": "no dialogue graph: %s" % graph_id}
	var node_id := String(argv[1]) if argv.size() > 1 else String(graph["start"])
	if not (graph["nodes"] as Dictionary).has(node_id):
		return {"error": "graph %s has no node %s" % [graph_id, node_id],
			"nodes": (graph["nodes"] as Dictionary).keys()}
	var walker := WIDialogue.new(graph, sim._build_dialogue_ctx(), Callable())
	walker.current_id = node_id
	var node: Dictionary = (graph["nodes"] as Dictionary)[node_id]
	# `current_options()` is the panel's own source; `_visible_options()` carries
	# the authored indices the panel throws away. Both, so the answer maps a
	# cursor position back to the line in the graph JSON.
	var rendered: Array = walker.current_options()
	var visible: Array = walker._visible_options()
	var rows: Array = []
	var visible_authored: Dictionary = {}
	for i in visible.size():
		var authored_index := int(visible[i]["authored_index"])
		visible_authored[authored_index] = true
		var row: Dictionary = (rendered[i] as Dictionary).duplicate(true)
		row["cursor_index"] = i          # 0-based: `move down` count from the top
		row["click_option"] = i + 1      # 1-based: `click_dialogue_option` takes this
		row["authored_index"] = authored_index
		row["goto"] = String((visible[i]["option"] as Dictionary).get("goto", ""))
		row["end"] = bool((visible[i]["option"] as Dictionary).get("end", false))
		rows.append(row)
	var dropped: Array = []
	var authored: Array = node.get("options", [])
	for authored_index in authored.size():
		if visible_authored.has(authored_index):
			continue
		var opt: Dictionary = authored[authored_index]
		dropped.append({
			"authored_index": authored_index,
			"text": String(opt.get("text", "")),
			"reason": _drop_reason(walker, opt),
		})
	return {
		"graph": graph_id,
		"node": node_id,
		"speaker": String(node.get("speaker", "")),
		"text": walker._resolved_text(node),
		"count": rows.size(),
		"options": rows,
		"dropped": dropped,
	}


## Mirrors `_visible_options`' two skip branches for EXPLANATION only -- the
## visible set itself is taken from the real function, so a future third skip
## branch degrades to "unknown" here instead of reporting a wrong row count.
func _drop_reason(walker: WIDialogue, opt: Dictionary) -> String:
	var hide_when: Dictionary = opt.get("hide_when", {})
	if not hide_when.is_empty() and walker._meets_hide_when(hide_when):
		return "hide_when satisfied (spent choice)"
	var req: Dictionary = opt.get("requires", {})
	if walker._progress_gated(req) and not walker._meets_progress(req):
		return "progress gate unmet (accomplishment/board/delivery/once_per_waking) -- DROPPED, not locked"
	return "unknown (a skip branch this oracle does not model)"


func _resolve_graph(sim: WIGame, graph_id: String) -> Dictionary:
	# The menus the game BUILDS in code have no file in data/dialogue/, and each
	# is a cursor surface a script has to count rows on, so they answer here
	# under the conversation label the driver's events carry.
	if graph_id == "portal_menu":
		return WIPortals.build_portal_graph(sim.attuned_destinations(), sim.current_map)
	var graphs: Dictionary = sim._combat_config.get("dialogue", {})
	if graphs.has(graph_id):
		return graphs[graph_id]
	# A sell picker is `<vendor>_sell`, built from the CURRENT pack by
	# `_open_sell_dialogue`. Checked only after the file lookup misses, so a
	# future data/dialogue/*_sell.json would still win. Rows carry the price
	# in their own text ("Sell: <name>. (+N gold)"), which is how a caller
	# reads a sale's worth without recomputing the [Skill] trade bonus.
	if graph_id.ends_with("_sell"):
		var vendor_id := graph_id.trim_suffix("_sell")
		var records: Array = []
		for raw_id: Variant in sim.sellable_items():
			var id := String(raw_id)
			var rec: Dictionary = sim.item(id)
			records.append({
				"id": id,
				"name": String(rec.get("name", id)),
				"price": sim.sell_price(int(rec.get(WIKeys.PRICE, 0))),
			})
		return WIShop.build_sell_graph(records, vendor_id)
	return {}


## BFS over exactly what the game blocks on: `is_cell_blocked`, which folds the
## map's `blocked` grid, walls segments, freezable/unsteady cells (minus the
## player's own [Even Footing] / frozen-tile exemptions) and every PRESENT
## entity's cell. Cardinal only -- the driver's `move` action is cardinal, and a
## diagonal it cannot corner-cut is not a route it can walk.
##
## An interactable's own cell is nearly always blocked (the NPC stands in it),
## so an unreachable target additionally reports the cheapest ADJACENT cell plus
## the bump direction that faces the target from there -- the walkthroughs' own
## idiom (a blocked move sets facing without moving).
func _q_path(sim: WIGame, argv: Array) -> Dictionary:
	if argv.size() < 3:
		return {"error": "path needs: %s" % QUERIES["path"]}
	var map_id := String(argv[0])
	if not sim.has_map(map_id):
		return {"error": "no such map: %s" % map_id}
	var raw_from: Variant = _parse_cell(String(argv[1]))
	var raw_to: Variant = _parse_cell(String(argv[2]))
	if raw_from == null or raw_to == null:
		return {"error": "cells must be x,y -- got %s and %s" % [argv[1], argv[2]]}
	var from_cell: Vector2i = raw_from
	var to_cell: Vector2i = raw_to
	sim.bind_map_silent(map_id, from_cell)
	var target_blocked := sim.is_cell_blocked(to_cell)
	var out := {
		"map": map_id,
		"from": [from_cell.x, from_cell.y],
		"to": [to_cell.x, to_cell.y],
		"target_blocked": target_blocked,
		"target_entity": String(sim.entity_at(to_cell).get(WIKeys.ID, "")),
	}
	var route: Variant = _bfs(sim, from_cell, to_cell)
	# `reachable` = a walk reaches the target cell with the target's OWN blocker
	# exempted, so the emitted `driver_steps` end in a bump-move that faces the
	# target (blocked move sets facing without moving) -- paste them, then
	# `press interact`. `enterable` is the stricter "you can stand there".
	out["reachable"] = route != null
	out["enterable"] = route != null and not target_blocked
	if route != null:
		out["steps"] = (route as Array).size() - 1
		out["cells"] = _cells_json(route as Array)
		out["driver_steps"] = _driver_steps(route as Array)
	if target_blocked:
		var best: Variant = null
		var best_dir := ""
		for dir_name: String in DIRECTIONS:
			var neighbour: Vector2i = to_cell - (DIRECTIONS[dir_name] as Vector2i)
			if sim.is_cell_blocked(neighbour) and neighbour != from_cell:
				continue
			var leg: Variant = _bfs(sim, from_cell, neighbour)
			if leg == null:
				continue
			if best == null or (leg as Array).size() < (best as Array).size():
				best = leg
				best_dir = dir_name
		if best == null:
			out["approach"] = null
		else:
			var stand: Vector2i = (best as Array)[(best as Array).size() - 1]
			out["approach"] = {
				"cell": [stand.x, stand.y],
				"steps": (best as Array).size() - 1,
				"driver_steps": _driver_steps(best as Array),
				"bump": best_dir,
			}
	return out


func _bfs(sim: WIGame, from_cell: Vector2i, to_cell: Vector2i) -> Variant:
	if from_cell == to_cell:
		return [from_cell]
	# The start cell is exempt from the blocked test: the player may legitimately
	# be standing ON a prop's cell (a door transition lands there), and refusing
	# to path out of that would be a false "unreachable".
	var came_from: Dictionary = {from_cell: from_cell}
	var frontier: Array[Vector2i] = [from_cell]
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for dir_name: String in DIRECTIONS:
				var step: Vector2i = cell + (DIRECTIONS[dir_name] as Vector2i)
				if came_from.has(step):
					continue
				if step != to_cell and sim.is_cell_blocked(step):
					continue
				came_from[step] = cell
				if step == to_cell:
					return _reconstruct(came_from, from_cell, to_cell)
				next_frontier.append(step)
		frontier = next_frontier
	return null


func _reconstruct(came_from: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var out: Array = [to_cell]
	var cur := to_cell
	while cur != from_cell:
		cur = came_from[cur]
		out.push_front(cur)
	return out


func _cells_json(route: Array) -> Array:
	var out: Array = []
	for cell: Vector2i in route:
		out.append([cell.x, cell.y])
	return out


## Run-length compression straight into the driver's own `move` step shape, so
## the answer is paste-ready rather than a coordinate list to hand-count.
func _driver_steps(route: Array) -> Array:
	var out: Array = []
	for i in range(1, route.size()):
		var delta: Vector2i = (route[i] as Vector2i) - (route[i - 1] as Vector2i)
		var dir_name := ""
		for candidate: String in DIRECTIONS:
			if DIRECTIONS[candidate] == delta:
				dir_name = candidate
				break
		if not out.is_empty() and String((out[out.size() - 1] as Dictionary)["direction"]) == dir_name:
			var last: Dictionary = out[out.size() - 1]
			last["steps"] = int(last["steps"]) + 1
		else:
			out.append({"action": "move", "direction": dir_name, "steps": 1})
	return out


func _parse_cell(raw: String) -> Variant:
	var parts := raw.replace("[", "").replace("]", "").split(",", false)
	if parts.size() != 2 or not String(parts[0]).strip_edges().is_valid_int() \
			or not String(parts[1]).strip_edges().is_valid_int():
		return null
	return Vector2i(int(String(parts[0]).strip_edges()), int(String(parts[1]).strip_edges()))


## `assert_state`'s path walker, minus the failing run. Omitting the path dumps
## the whole snapshot -- the sanctioned replacement for the deliberately-failing
## probe idiom when you do not yet know which key you want.
func _q_state(sim: WIGame, argv: Array) -> Dictionary:
	var snap := sim.snapshot()
	if argv.is_empty() or String(argv[0]).is_empty():
		return {"path": "", "value": snap}
	var path := String(argv[0])
	var cur: Variant = snap
	for key: String in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(key):
			cur = (cur as Dictionary)[key]
		elif cur is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (cur as Array).size():
			cur = (cur as Array)[int(key)]
		else:
			return {"error": "path not found: %s" % path,
				"available": (cur as Dictionary).keys() if cur is Dictionary else null}
	return {"path": path, "value": cur}


## This is the sleep beat's own progression ordering, evaluated on copies:
## gains at level 1, all eligible level-ups, then (#472) AT MOST ONE
## consolidation APPLIED, then evolutions. Nothing defers any more -- the beat
## no longer returns early on a merge, so this preview runs the same straight
## line the real beat does.
func _q_progression_preview(sim: WIGame) -> Dictionary:
	var catalog: Dictionary = sim._combat_config.get("classes", {})
	var before: Dictionary = sim.classes.duplicate(true)
	var classes: Dictionary = before.duplicate(true)
	var generalist: Array = sim.generalist_classes.duplicate()
	var class_gains := WIProgression.check_class_gains(classes, sim.accomplishments, catalog)
	for class_id: String in class_gains:
		classes[class_id] = 1
	var level_ups := WIProgression.check_level_ups(classes, sim.accomplishments, catalog)
	for gain: Dictionary in level_ups:
		classes[String(gain["class"])] = int(gain["level"])
	var consolidation := WIProgression.check_consolidation(classes, catalog)
	if not consolidation.is_empty():
		for parent_id: Variant in consolidation["parents"]:
			classes.erase(String(parent_id))
		classes[String(consolidation["target"])] = int(consolidation["level"])
	var evolutions := WIProgression.check_evolutions(classes, sim.accomplishments, catalog, generalist)
	for outcome: Dictionary in evolutions:
		var class_id := String(outcome["class"])
		if outcome.has("to"):
			classes.erase(class_id)
			classes[String(outcome["to"])] = int(outcome["level"])
		elif bool(outcome.get("generalist", false)) and not generalist.has(class_id):
			generalist.append(class_id)
	return {
		"classes_before": before,
		"classes_after": classes,
		"generalist_classes_after": generalist,
		"class_gains": class_gains,
		"level_ups": level_ups,
		"consolidation": consolidation,
		"evolutions": evolutions,
	}


## Worn-accessory abilities are known WHILE WORN (ruling 2026-08-11), so the bar
## is equipment-dependent: this is the query that catches "the script presses
## hotbar_3 and the equip two steps earlier moved everything down one".
func _q_field_bar(sim: WIGame) -> Dictionary:
	var bar: Array = sim.field_hotbar_loadout()
	var slots: Array = []
	for i in bar.size():
		slots.append({
			"slot": i + 1,
			"skill": String(bar[i]),
			"press": "hotbar_%d" % (i + 1) if i < NUMBER_KEY_SLOTS else null,
			"number_key_reachable": i < NUMBER_KEY_SLOTS,
		})
	return {
		"count": bar.size(),
		"slots": slots,
		"custom_loadout": sim.hotbar_loadout.duplicate(),
		"number_key_unreachable": bar.slice(NUMBER_KEY_SLOTS) if bar.size() > NUMBER_KEY_SLOTS else [],
	}


func _q_known_skills(sim: WIGame) -> Dictionary:
	var worn: Array = []
	for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
		var item_id := String(sim.equipped.get(slot_name, ""))
		if item_id == "":
			continue
		for ability: Variant in (sim.item(item_id).get(WIKeys.ABILITIES, []) as Array):
			worn.append({"item": item_id, "skill": String(ability)})
	var known: Array = sim.known_skills()
	var innate: Array = sim.player_skills.duplicate()
	var worn_ids: Array = worn.map(func(w: Dictionary) -> String: return String(w["skill"]))
	var from_class: Array = []
	for raw: Variant in known:
		var id := String(raw)
		if not innate.has(id) and not worn_ids.has(id):
			from_class.append(id)
	return {
		"count": known.size(),
		"known_skills": known,
		"innate": innate,
		"class_granted": from_class,
		"worn": worn,
		"classes": sim.classes.duplicate(true),
	}


## portals.json rows crossed with accomplishments and the current-map exclusion.
## `menu_index` is the row's 1-based position in the portal picker (the cursor
## order a script counts `move down` against); the trailing "Let it be." row is
## included because it is a real cursor stop and the wrap lands on it.
func _q_portal_rows(sim: WIGame) -> Dictionary:
	var rows: Array = sim._portal_rows()
	var attuned: Array = sim.attuned_destinations()
	var attuned_ids: Dictionary = {}
	for dest: Dictionary in attuned:
		attuned_ids[String(dest.get("id", ""))] = true
	var menu_index := 0
	var out: Array = []
	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		var map_id := String(row.get("map", ""))
		var is_attuned: bool = attuned_ids.has(id)
		var excluded: bool = map_id == sim.current_map
		var index: Variant = null
		if is_attuned and not excluded:
			menu_index += 1
			index = menu_index
		out.append({
			"id": id,
			"map": map_id,
			"display_name": String(row.get("display_name", "")),
			"requires_accomplishment": String(row.get("requires_accomplishment", "")),
			"attuned": is_attuned,
			"map_exists": sim.has_map(map_id),
			"excluded_current_map": excluded,
			"menu_index": index,
		})
	menu_index += 1
	return {
		"current_map": sim.current_map,
		"rows": out,
		"menu_row_count": menu_index,
		"never_mind_index": menu_index,
	}


## Insertion order IS the picker cursor order, so the index printed here is the
## number of `move down` presses (and the `click_inventory_row` argument).
func _q_inventory(sim: WIGame) -> Dictionary:
	var items: Array = []
	for i in sim.inventory.size():
		var id := String(sim.inventory[i])
		var rec: Dictionary = sim.item(id)
		items.append({
			"cursor_index": i,
			"row": i + 1,
			"id": id,
			"name": String(rec.get("name", id)),
			"slot": String(rec.get("slot", "")),
		})
	return {
		"count": items.size(),
		"items": items,
		"equipped": sim.equipped.duplicate(true),
		"gold": sim.gold,
	}
