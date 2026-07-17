extends SceneTree

const DIALOGUE_DIR := "res://data/dialogue"

## Single source of truth: the canonical code-banked list lives in
## test_shipped_ids.gd (synced with generate_shipped_ids.py per wi-shipping).
## A third hand-copy here was the review finding -- preload, never copy.
const _SHIPPED_IDS_TEST := preload("res://tests/test_shipped_ids.gd")


const KNOWN_ORPHAN_GATES := {}


func _init() -> void:
	WITestWatchdog.arm(self)
	var scene: Dictionary = WISceneCatalog.compose()
	var graphs: Dictionary = _load_dialogue_graphs()
	var quests := _load_json("res://data/quests.json")
	var acts := _load_json("res://data/acts.json")
	var classes := _load_json("res://data/classes.json")
	var skills := _load_json("res://data/skills.json")
	var bounties := _load_json("res://data/bounties.json")
	var deliveries := _load_json("res://data/deliveries.json")
	var portals := _load_json("res://data/portals.json")

	var consumed: Dictionary = {}
	_collect_dialogue_consumers(graphs, consumed)
	_collect_scene_consumers(scene, consumed)
	_collect_quest_consumers(quests, consumed)
	_collect_act_consumers(acts, consumed)
	_collect_class_consumers(classes, consumed)
	_collect_contract_consumers(bounties, "bounties", consumed)
	_collect_contract_consumers(deliveries, "deliveries", consumed)
	_collect_portal_consumers(portals, consumed)

	var produced: Dictionary = {}
	_collect_structural_producers(produced)
	_collect_skill_tally_producers(skills, produced)
	_collect_scene_producers(scene, produced)
	_collect_dialogue_producers(graphs, produced)
	_collect_contract_producers(bounties, deliveries, produced)

	_validate_known_orphans(consumed, produced)
	_validate_negative_control()
	var missing := _missing_producers(consumed, produced)
	if not missing.is_empty():
		print("test_reachability: %d zero-producer gate(s)" % missing.size())
		for counter: String in missing:
			print("REACHABILITY_FAIL %s consumed at %s" % [counter, ", ".join(consumed[counter])])
	assert(missing.is_empty(), "zero-producer accomplishment gate(s): " + ", ".join(missing))
	print("PASS: requires-gate reachability — %d consumed counters, %d real producers, 0 orphans" % [consumed.size(), produced.size()])
	quit(0)


func _collect_dialogue_consumers(graphs: Dictionary, consumed: Dictionary) -> void:
	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id].get("nodes", {})
		for node_id: String in nodes:
			var node: Dictionary = nodes[node_id]
			for variant_index: int in (node.get("text_variants", []) as Array).size():
				var variant: Dictionary = node["text_variants"][variant_index]
				_collect_dialogue_gate(variant.get("requires", {}), "%s.%s.text_variants[%d].requires" % [graph_id, node_id, variant_index], consumed)
			for option_index: int in (node.get("options", []) as Array).size():
				var option: Dictionary = node["options"][option_index]
				_collect_dialogue_gate(option.get("requires", {}), "%s.%s.options[%d].requires" % [graph_id, node_id, option_index], consumed)
				_collect_dialogue_gate(option.get("hide_when", {}), "%s.%s.options[%d].hide_when" % [graph_id, node_id, option_index], consumed)


func _collect_dialogue_gate(gate: Dictionary, label: String, consumed: Dictionary) -> void:
	_collect_counter_dict(gate.get("accomplishment", {}), label + ".accomplishment", consumed)


func _collect_scene_consumers(scene: Dictionary, consumed: Dictionary) -> void:
	for map_id: String in scene.get("maps", {}):
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var entity_id := String(entity.get("id", "?"))
			var label := "maps.%s.%s" % [map_id, entity_id]
			for gate_key: String in ["door_when", "encounter_when", "present_when", "contains_when"]:
				var gate: Dictionary = entity.get(gate_key, {})
				_collect_counter_dict(gate.get("requires", {}), "%s.%s.requires" % [label, gate_key], consumed)
			var portal_gate: Dictionary = entity.get("portal_menu_when", {})
			if portal_gate.has("requires"):
				_collect_counter_dict(portal_gate["requires"], label + ".portal_menu_when.requires", consumed)
			else:
				_collect_counter_dict(portal_gate, label + ".portal_menu_when", consumed)
			_collect_counter_dict(entity.get("ally_requires", {}), label + ".ally_requires", consumed)
			for ally_id: String in (entity.get("ally_hp_penalty", {}) as Dictionary):
				var penalty: Dictionary = entity["ally_hp_penalty"][ally_id]
				_collect_counter_dict(penalty.get("when", {}), "%s.ally_hp_penalty.%s.when" % [label, ally_id], consumed)
			for stage_index: int in (entity.get("talk_pool_stages", []) as Array).size():
				var stage: Dictionary = entity["talk_pool_stages"][stage_index]
				_collect_counter_dict(stage.get("requires_accomplishment", {}), "%s.talk_pool_stages[%d].requires_accomplishment" % [label, stage_index], consumed)
			for state_index: int in (entity.get("visual_states", []) as Array).size():
				var state: Variant = entity["visual_states"][state_index]
				if state is Dictionary:
					_collect_scalar_counter((state as Dictionary).get("when", {}).get("counter", ""), "%s.visual_states[%d].when.counter" % [label, state_index], consumed)
			for variant_index: int in (entity.get("variants", []) as Array).size():
				var variant: Variant = entity["variants"][variant_index]
				if variant is Dictionary:
					_collect_counter_dict((variant as Dictionary).get("when", {}), "%s.variants[%d].when" % [label, variant_index], consumed)
			var skill_use: Dictionary = entity.get("on_skill_use", {})
			for variant_index: int in (skill_use.get("variants", []) as Array).size():
				var variant: Dictionary = skill_use["variants"][variant_index]
				_collect_counter_dict(variant.get("when", {}), "%s.on_skill_use.variants[%d].when" % [label, variant_index], consumed)
			_collect_scalar_counter(entity.get("tutorial_seen_when", ""), label + ".tutorial_seen_when", consumed)


func _collect_quest_consumers(quests: Dictionary, consumed: Dictionary) -> void:
	for quest: Dictionary in quests.get("quests", []):
		var quest_id := String(quest.get("id", "?"))
		for beat: Dictionary in quest.get("beats", []):
			_collect_counter_dict(beat.get("complete_when", {}), "quests.%s.%s.complete_when" % [quest_id, String(beat.get("id", "?"))], consumed)
		for path_index: int in (quest.get("resolution_paths", []) as Array).size():
			var path: Dictionary = quest["resolution_paths"][path_index]
			_collect_scalar_counter(path.get("accomplishment", ""), "quests.%s.resolution_paths[%d].accomplishment" % [quest_id, path_index], consumed)


func _collect_act_consumers(acts: Dictionary, consumed: Dictionary) -> void:
	for act: Dictionary in acts.get("acts", []):
		var act_id := String(act.get("id", "?"))
		_collect_counter_dict((act.get("advance_when", {}) as Dictionary).get("accomplishments", {}), "acts.%s.advance_when.accomplishments" % act_id, consumed)
		for beat: Dictionary in act.get("beats", []):
			_collect_counter_dict((beat.get("when", {}) as Dictionary).get("accomplishments", {}), "acts.%s.%s.when.accomplishments" % [act_id, String(beat.get("id", "?"))], consumed)


func _collect_class_consumers(classes: Dictionary, consumed: Dictionary) -> void:
	for cls: Dictionary in classes.get("classes", []):
		var class_id := String(cls.get("id", "?"))
		_collect_counter_dict((cls.get("gained_by", {}) as Dictionary).get("accomplishment", {}), "classes.%s.gained_by.accomplishment" % class_id, consumed)
		for level: Dictionary in cls.get("levels", []):
			var label := "classes.%s.levels[%s]" % [class_id, str(level.get("level", "?"))]
			_collect_counter_dict(level.get("requires", {}), label + ".requires", consumed)
			_collect_counter_dict(level.get("requires_any", {}), label + ".requires_any", consumed)
		_collect_counter_dict((cls.get("evolution", {}) as Dictionary).get("targets", {}), "classes.%s.evolution.targets" % class_id, consumed)


func _collect_contract_consumers(catalog: Dictionary, key: String, consumed: Dictionary) -> void:
	for contract: Dictionary in catalog.get(key, []):
		var label := "%s.%s" % [key, String(contract.get("id", "?"))]
		_collect_counter_dict(contract.get("condition", {}), label + ".condition", consumed)
		_collect_counter_dict(contract.get("requires", {}), label + ".requires", consumed)


func _collect_portal_consumers(portals: Dictionary, consumed: Dictionary) -> void:
	for portal: Dictionary in portals.get("portals", []):
		_collect_scalar_counter(portal.get("requires_accomplishment", ""), "portals.%s.requires_accomplishment" % String(portal.get("id", "?")), consumed)


func _collect_structural_producers(produced: Dictionary) -> void:
	for counter: String in _SHIPPED_IDS_TEST.STRUCTURAL_LITERALS:
		_mark_produced(counter, "STRUCTURAL_LITERALS", produced)


func _collect_skill_tally_producers(skills: Dictionary, produced: Dictionary) -> void:
	for skill: Dictionary in skills.get("skills", []):
		var skill_id := String(skill.get("id", "?"))
		var weapon := String(skill.get("weapon", ""))
		if weapon != "":
			_mark_produced("%s_skill_used" % weapon, "skills.%s.weapon" % skill_id, produced)
		var element := String(skill.get("element", ""))
		if element != "":
			_mark_produced("spell_cast", "skills.%s.element" % skill_id, produced)
			_mark_produced("%s_cast" % element, "skills.%s.element" % skill_id, produced)


func _collect_scene_producers(scene: Dictionary, produced: Dictionary) -> void:
	for map_id: String in scene.get("maps", {}):
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var label := "maps.%s.%s" % [map_id, String(entity.get("id", "?"))]
			if String(entity.get("kind", "")) == "encounter":
				var victory: Variant = entity.get("on_victory", "won_combat")
				for counter: Variant in (victory if victory is Array else [victory]):
					_mark_produced(String(counter), label + ".on_victory", produced)
			var skill_use: Dictionary = entity.get("on_skill_use", {})
			_collect_scalar_producer(skill_use.get("accomplishment", ""), label + ".on_skill_use.accomplishment", produced)
			for variant_index: int in (skill_use.get("variants", []) as Array).size():
				var variant: Dictionary = skill_use["variants"][variant_index]
				_collect_scalar_producer(variant.get("accomplishment", ""), "%s.on_skill_use.variants[%d].accomplishment" % [label, variant_index], produced)
			if entity.has("on_interact_accomplishment"):
				_collect_scalar_producer(entity["on_interact_accomplishment"], label + ".on_interact_accomplishment", produced)
				for variant_index: int in (entity.get("variants", []) as Array).size():
					var variant: Variant = entity["variants"][variant_index]
					if variant is Dictionary:
						_collect_scalar_producer((variant as Dictionary).get("accomplishment", ""), "%s.variants[%d].accomplishment" % [label, variant_index], produced)
			_collect_scalar_producer(entity.get("on_enter_accomplishment", ""), label + ".on_enter_accomplishment", produced)
			_collect_scalar_producer(entity.get("on_open_accomplishment", ""), label + ".on_open_accomplishment", produced)
			if not (entity.get("talk_pool", []) as Array).is_empty():
				_mark_produced("heard_gossip", label + ".talk_pool", produced)
				_mark_produced("chatted_with_%s" % String(entity.get("id", "?")), label + ".talk_pool", produced)
			for rumor: Dictionary in entity.get("board_rumors", []):
				_collect_scalar_producer(rumor.get("banks_accomplishment", ""), label + ".board_rumors", produced)


func _collect_dialogue_producers(graphs: Dictionary, produced: Dictionary) -> void:
	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id].get("nodes", {})
		for node_id: String in nodes:
			var node: Dictionary = nodes[node_id]
			for option_index: int in (node.get("options", []) as Array).size():
				var option: Dictionary = node["options"][option_index]
				for effect_index: int in (option.get("effects", []) as Array).size():
					var effect: Dictionary = option["effects"][effect_index]
					_collect_scalar_producer(effect.get("accomplishment", ""), "%s.%s.options[%d].effects[%d].accomplishment" % [graph_id, node_id, option_index, effect_index], produced)


func _collect_contract_producers(bounties: Dictionary, deliveries: Dictionary, produced: Dictionary) -> void:
	for bounty: Dictionary in bounties.get("bounties", []):
		var bounty_id := String(bounty.get("id", "?"))
		_mark_produced("accepted_bounty_%s" % bounty_id, "bounties.%s accept" % bounty_id, produced)
		_mark_produced("completed_bounty_%s" % bounty_id, "bounties.%s turn-in" % bounty_id, produced)
	for delivery: Dictionary in deliveries.get("deliveries", []):
		var delivery_id := String(delivery.get("id", "?"))
		_mark_produced("accepted_delivery_%s" % delivery_id, "deliveries.%s accept" % delivery_id, produced)
		_mark_produced("delivered_%s" % delivery_id, "deliveries.%s arrival" % delivery_id, produced)
		_mark_produced("completed_delivery_%s" % delivery_id, "deliveries.%s turn-in" % delivery_id, produced)


func _collect_counter_dict(counters: Dictionary, label: String, consumed: Dictionary) -> void:
	for counter: String in counters:
		_collect_scalar_counter(counter, label, consumed)


func _collect_scalar_counter(raw_counter: Variant, label: String, consumed: Dictionary) -> void:
	var counter := String(raw_counter)
	if counter == "" or counter.begins_with("_"):
		return
	if not consumed.has(counter):
		consumed[counter] = []
	(consumed[counter] as Array).append(label)


func _collect_scalar_producer(raw_counter: Variant, label: String, produced: Dictionary) -> void:
	var counter := String(raw_counter)
	if counter != "":
		_mark_produced(counter, label, produced)


func _mark_produced(counter: String, label: String, produced: Dictionary) -> void:
	if not produced.has(counter):
		produced[counter] = []
	(produced[counter] as Array).append(label)


func _missing_producers(consumed: Dictionary, produced: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for counter: String in consumed:
		if not produced.has(counter) and not KNOWN_ORPHAN_GATES.has(counter):
			missing.append(counter)
	missing.sort()
	return missing


func _validate_known_orphans(consumed: Dictionary, produced: Dictionary) -> void:
	for counter: String in KNOWN_ORPHAN_GATES:
		assert(String(KNOWN_ORPHAN_GATES[counter]).begins_with("_comment:"), "KNOWN_ORPHAN_GATES.%s needs an _comment-style justification" % counter)
		assert(consumed.has(counter), "KNOWN_ORPHAN_GATES.%s is stale: no gate consumes it" % counter)
		assert(not produced.has(counter), "KNOWN_ORPHAN_GATES.%s is stale: a real producer now exists" % counter)


func _validate_negative_control() -> void:
	var synthetic_consumed := {"fixture_only_counter": ["synthetic gate"]}
	var missing := _missing_producers(synthetic_consumed, {})
	assert(missing == ["fixture_only_counter"], "NEGATIVE CONTROL: a counter absent from real producers must fail even if a fixture could hand-bank it")


func _load_dialogue_graphs() -> Dictionary:
	var graphs: Dictionary = {}
	var dir := DirAccess.open(DIALOGUE_DIR)
	assert(dir != null, "missing dialogue directory")
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			graphs[file_name.get_basename()] = _load_json(DIALOGUE_DIR.path_join(file_name))
	return graphs


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
