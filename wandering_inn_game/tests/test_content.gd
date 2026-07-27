extends SceneTree

const DIALOGUE_DIR := "res://data/dialogue"

const PLAYER_STRING_FILES := [
	"res://data/items.json",
	"res://data/skills.json",
	"res://data/quests.json",
	"res://data/acts.json",
	"res://data/classes.json",
	"res://data/combatants.json",
	"res://data/arenas.json",
	"res://data/bounties.json",
	"res://data/deliveries.json",
	"res://data/portals.json",
	"res://data/fence_stock.json",
]



## GH#211 review LOW-4: a victory_toast carrier's FIRST on_victory id keys the
## first-win==1 toast check; under challenge weighting the literal won_combat
## counter is fractional, so a won_combat-first carrier would toast on the
## wrong win. Data rule: victory_toast requires a quest-style first id.
func _validate_victory_toast_keys(maps: Dictionary) -> void:
	for map_id: String in maps:
		for ent: Dictionary in maps[map_id].get("entities", []):
			if not ent.has("victory_toast"):
				continue
			var victories: Variant = ent.get("on_victory", "won_combat")
			var first := String((victories if victories is Array else [victories])[0])
			assert(first != "won_combat", "%s/%s: victory_toast carrier's first on_victory id must not be won_combat (fractional under GH#211 weighting)" % [map_id, String(ent.get("id", "?"))])


## GH#155 review L2: on a skill-gated prop, every id in on_skill_use.remove_item
## (and its variants) must also appear in requires_item -- otherwise the gate
## passes without the item and remove_item silently no-ops (free craft).
func _validate_consume_subset(maps: Dictionary) -> void:
	for map_id: String in maps:
		for ent: Dictionary in maps[map_id].get("entities", []):
			if not ent.has("on_skill_use"):
				continue
			var req: Array = []
			var raw_req: Variant = ent.get("requires_item", "")
			if raw_req is Array: req = raw_req
			elif String(raw_req) != "": req = [String(raw_req)]
			var payloads: Array = [ent["on_skill_use"]]
			for v: Variant in (ent["on_skill_use"].get("variants", []) if ent["on_skill_use"] is Dictionary else []):
				payloads.append(v)
			for payload: Variant in payloads:
				if not (payload is Dictionary) or not payload.has("remove_item"):
					continue
				var rems: Variant = payload["remove_item"]
				var rem_list: Array = rems if rems is Array else [String(rems)]
				for rem: String in rem_list:
					assert(req.has(rem), "%s/%s: remove_item '%s' not in requires_item (silent free-craft)" % [map_id, ent.get("id","?"), rem])

## #92 D1: every CONSUMABLE (use_effect-bearing item) dispensed by a priced
## shop-buy option or an alchemist/kitchen craft bench must carry price>0 (a
## defined sell-back worth); and any component-consuming craft's output must be
## worth strictly MORE than its components summed (no infinite-gold craft loop).
## Non-consumables (reputation tokens, free comfort meals) are exempt by design.
func _validate_economy_prices(scene: Dictionary, graphs: Dictionary, items: Dictionary) -> void:
	var price: Dictionary = {}
	var is_consumable: Dictionary = {}
	for entry: Dictionary in items.get("items", []):
		var iid := String(entry["id"])
		price[iid] = int(entry.get("price", 0))
		is_consumable[iid] = entry.has("use_effect")
	# Shop buys: an option that charges gold AND grants a consumable.
	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				if not (option.get("requires", {}) as Dictionary).has("gold"):
					continue
				for effect: Dictionary in (option.get("effects", []) as Array):
					if not effect.has("item"):
						continue
					var bought := String(effect["item"])
					if not bool(is_consumable.get(bought, false)):
						continue
					assert(int(price.get(bought, 0)) > 0, "%s/%s: shop-buy option sells consumable '%s' but it has no price>0 (no sell margin) -- #92 D1" % [graph_id, node_id, bought])
	# Crafts: a bench prop's on_skill_use output; consumable outputs must be
	# priced, and any output that consumes components must beat their sum.
	for map_id: String in scene["maps"]:
		for ent: Dictionary in scene["maps"][map_id].get("entities", []):
			if not ent.has("on_skill_use"):
				continue
			var payloads: Array = [ent["on_skill_use"]]
			for v: Variant in (ent["on_skill_use"].get("variants", []) if ent["on_skill_use"] is Dictionary else []):
				payloads.append(v)
			for payload: Variant in payloads:
				if not (payload is Dictionary) or not payload.has("item"):
					continue
				var out_id := String(payload["item"])
				var rems: Variant = payload.get("remove_item", [])
				var rem_list: Array = rems if rems is Array else ([String(rems)] if String(rems) != "" else [])
				if bool(is_consumable.get(out_id, false)):
					assert(int(price.get(out_id, 0)) > 0, "%s/%s: craft yields consumable '%s' but it has no price>0 -- #92 D1" % [map_id, ent.get("id", "?"), out_id])
				if rem_list.is_empty():
					continue
				var comp_sum := 0
				for rem: String in rem_list:
					comp_sum += int(price.get(String(rem), 0))
				assert(int(price.get(out_id, 0)) > comp_sum, "%s/%s: craft output '%s' (price %d) is not worth more than its components (%d summed) -- infinite-gold craft loop, #92 D1" % [map_id, ent.get("id", "?"), out_id, int(price.get(out_id, 0)), comp_sum])


func _init() -> void:
	WITestWatchdog.arm(self)
	var graphs: Dictionary = _load_dialogue_graphs()
	var quests: Dictionary = _load_json("res://data/quests.json")
	var scene: Dictionary = WISceneCatalog.compose()
	var skills: Dictionary = _load_json("res://data/skills.json")
	var classes: Dictionary = _load_json("res://data/classes.json")
	var items: Dictionary = _load_json("res://data/items.json")
	var bounties: Dictionary = _load_json("res://data/bounties.json")
	var deliveries: Dictionary = _load_json("res://data/deliveries.json")

	var skill_ids: Dictionary = _ids_from_catalog(skills, "skills")
	var class_ids: Dictionary = _ids_from_catalog(classes, "classes")
	var quest_ids: Dictionary = _ids_from_catalog(quests, "quests")
	var item_ids: Dictionary = _ids_from_catalog(items, "items")
	var entity_ids: Dictionary = _entity_ids(scene)
	var produced_accomplishments: Dictionary = {}

	_collect_scene_accomplishments(scene, produced_accomplishments)
	produced_accomplishments["observed_things"] = true
	produced_accomplishments["befriended_moments"] = true
	produced_accomplishments["deliberate_commerce"] = true
	produced_accomplishments["completed_delivery"] = true
	# door_awakened is banked in code (wi_game.gd's sleep hook, the Act IV gate), never
	# by a scene/dialogue effect the scanner can see -- register it here so quest beats may
	# gate on it (the door chain's `attune` beat, #148). Mirrors STRUCTURAL_LITERALS in
	# test_shipped_ids.gd, which already lists door_awakened as a code-produced counter.
	produced_accomplishments["door_awakened"] = true
	# garden_door_unlocked: same class (code-banked at the qualifying sleep,
	# STRUCTURAL_LITERALS member) -- registered for the garden door's
	# present_when (GH#167). If a third one appears, import the whole
	# STRUCTURAL_LITERALS set via the test_reachability preload pattern.
	produced_accomplishments["garden_door_unlocked"] = true
	# b4 #219: the combat action-tally trio is code-banked per fight
	# (combat_banking's _bank_action_tally) — registered so bounty/quest
	# conditions may key on them (the fought_* synthesis precedent).
	produced_accomplishments["melee_hit"] = true
	produced_accomplishments["spell_cast"] = true
	produced_accomplishments["ranged_hit"] = true
	_validate_conversations(scene, graphs)
	_validate_enchant_pairs(graphs, items)
	_validate_dialogue_graphs(graphs, skill_ids, class_ids, item_ids, quest_ids, entity_ids, produced_accomplishments)
	_validate_quests(quests, produced_accomplishments)
	_validate_bounties(bounties, produced_accomplishments)
	_validate_fence(_load_json("res://data/fence_stock.json"), item_ids)
	_validate_bounty_payout_anchors(bounties, items)
	_validate_encounter_scaling(scene, quests)
	_validate_deliveries(deliveries, produced_accomplishments)
	_validate_hide_when_nodes_have_always_available_exit(graphs)
	_validate_class_gains(classes, produced_accomplishments)
	_validate_class_level_tables(classes)
	_validate_consume_subset(WISceneCatalog.compose()["maps"])
	_validate_victory_toast_keys(WISceneCatalog.compose()["maps"])
	_validate_economy_prices(scene, graphs, items)
	_validate_class_skill_grant_ids(classes, skill_ids)
	_validate_class_skill_grant_ids_shape_cases()
	_validate_props(scene)
	_validate_talk_pool_stages_ascending(scene)
	_validate_encounter_when(scene, produced_accomplishments)
	_validate_encounter_gate_counters(scene, produced_accomplishments)
	_validate_present_when(scene, produced_accomplishments)
	_validate_skill_uses(scene, skill_ids, produced_accomplishments)
	_validate_visual_states_phase(scene)
	_validate_talk_pool_echo_of(scene, entity_ids)
	_validate_effect_text_opacity()
	_validate_player_string_vocab()
	_validate_once_per_waking_shape_cases()
	_validate_travel_beat_place_naming(quests, scene, graphs)
	_validate_place_naming_shape_cases()
	_validate_tutor_line_help_consistency()

	print("PASS: errand content is fully cross-referenced")
	quit(0)


func _validate_effect_text_opacity() -> void:
	var attr := RegEx.new()
	attr.compile("(?i)\\b(str|dex|con|int|wis|cha)\\b")
	var lines: Array[String] = []
	for item: Dictionary in _load_json("res://data/items.json").get("items", []):
		lines.append_array(WIEffectText.item_effect_lines(item))
	for skill: Dictionary in _load_json("res://data/skills.json").get("skills", []):
		lines.append_array(WIEffectText.skill_effect_lines(skill))
	var status_ids: Dictionary = {}
	for skill: Dictionary in _load_json("res://data/skills.json").get("skills", []):
		var applies: Dictionary = (skill.get("effect", {}) as Dictionary).get("applies", {})
		for status_id: String in applies:
			status_ids[status_id] = true
	for status_id: String in status_ids:
		lines.append(WIEffectText.status_line(status_id))
	for line: String in lines:
		assert(attr.search(line) == null, "effect_text emits a forbidden attribute token: " + line)
		assert(not line.contains("%"), "effect_text emits a forbidden percent-toward token: " + line)


func _validate_player_string_vocab() -> void:
	var attr := RegEx.new()
	attr.compile("(?i)\\b(str|dex|con|int|wis|cha)\\b")
	var provenance := RegEx.new()
	provenance.compile("(?i)Task [A-Z]?\\d+|issue #\\d+")
	for path: String in PLAYER_STRING_FILES:
		_scan_player_strings(_load_json(path), path, attr, provenance)
	_scan_player_strings(WISceneCatalog.compose(), "res://data/maps/** (composed)", attr, provenance)
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			var full_path := DIALOGUE_DIR.path_join(file_name)
			_scan_player_strings(_load_json(full_path), full_path, attr, provenance)


func _scan_player_strings(node: Variant, path: String, attr: RegEx, provenance: RegEx) -> void:
	if node is Dictionary:
		for key: String in (node as Dictionary):
			if key.begins_with("_"):
				continue
			_scan_player_strings((node as Dictionary)[key], "%s.%s" % [path, key], attr, provenance)
	elif node is Array:
		for i: int in (node as Array).size():
			_scan_player_strings((node as Array)[i], "%s[%d]" % [path, i], attr, provenance)
	elif node is String:
		var s := node as String
		assert(attr.search(s) == null, "%s carries a forbidden attribute token: %s" % [path, s])
		assert(not s.contains("%"), "%s carries a forbidden percent-toward token: %s" % [path, s])
		assert(provenance.search(s) == null, "%s carries a dev-provenance leak (Task/issue citation): %s" % [path, s])


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _load_dialogue_graphs() -> Dictionary:
	var graphs: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	assert(dir != null, "missing dialogue directory")
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			graphs[file_name.get_basename()] = _load_json(DIALOGUE_DIR.path_join(file_name))
	assert(not graphs.is_empty(), "no dialogue graphs found")
	return graphs


func _ids_from_catalog(catalog: Dictionary, key: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in catalog.get(key, []):
		out[String(entry["id"])] = true
	return out


func _entity_ids(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			out[String(entity["id"])] = true
	return out


func _collect_scene_accomplishments(scene: Dictionary, produced: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if String(entity.get("kind", "")) == "encounter":
				# GH#211: combat_banking banks fought_<encounter_id> on every
				# weighted victory -- a real code-banked producer per encounter.
				produced["fought_%s" % String(entity["id"])] = true
			var victory: Variant = entity.get("on_victory", [])
			if victory is Array:
				for id: Variant in victory:
					produced[String(id)] = true
			elif victory is String:
				produced[String(victory)] = true
			if entity.has("on_skill_use"):
				var skill_use: Dictionary = entity["on_skill_use"]
				if skill_use.has("accomplishment"):
					produced[String(skill_use["accomplishment"])] = true
				for variant: Dictionary in (skill_use.get("variants", []) as Array):
					if variant.has("accomplishment"):
						produced[String(variant["accomplishment"])] = true
			for sid: String in (entity.get("skill_uses", {}) as Dictionary):
				var arm: Dictionary = (entity["skill_uses"] as Dictionary)[sid]
				if arm.has("accomplishment"):
					produced[String(arm["accomplishment"])] = true
			if entity.has("on_interact_accomplishment"):
				produced[String(entity["on_interact_accomplishment"])] = true
				for variant: Dictionary in (entity.get("variants", []) as Array):
					if variant.has("accomplishment"):
						produced[String(variant["accomplishment"])] = true
			# Task 2.3: on_open_accomplishment is String|Array (the on_victory
			# contract) -- a multi-bank open must register EVERY id it produces.
			var open_banks: Variant = entity.get("on_open_accomplishment", [])
			for counter: Variant in (open_banks if open_banks is Array else [open_banks]):
				produced[String(counter)] = true
			if entity.has("on_enter_accomplishment"):
				produced[String(entity["on_enter_accomplishment"])] = true
			if entity.has("talk_pool") and not (entity["talk_pool"] as Array).is_empty():
				produced["heard_gossip"] = true
				produced["chatted_with_%s" % String(entity["id"])] = true
			for rumor: Dictionary in (entity.get("board_rumors", []) as Array):
				produced[String(rumor["banks_accomplishment"])] = true


func _validate_talk_pool_stages_ascending(scene: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var stages: Array = entity.get("talk_pool_stages", [])
			if stages.size() < 2:
				continue
			var seen: Dictionary = {}
			for stage: Dictionary in stages:
				var req: Dictionary = stage.get("requires_accomplishment", {})
				for key: String in req:
					var threshold := int(req[key])
					if seen.has(key):
						assert(threshold >= int(seen[key]), "entity %s talk_pool_stages authored OUT OF ORDER: stage %s's %s threshold (%d) is lower than an earlier stage's (%d)" % [String(entity["id"]), String(stage.get("id", "?")), key, threshold, int(seen[key])])
					seen[key] = threshold


const VALID_PHASES := ["day", "dusk", "night"]


func _validate_encounter_when(scene: Dictionary, produced_accomplishments: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if not entity.has("encounter_when"):
				continue
			var entity_id: String = String(entity["id"])
			assert(String(entity.get("kind", "")) == "encounter", "entity %s carries encounter_when but is not kind:encounter" % entity_id)
			var when: Dictionary = entity["encounter_when"]
			assert(when.has("phase") or when.has("requires") or when.has("absent"), "entity %s encounter_when has no recognized shape (only 'phase'/'requires'/'absent' are sanctioned)" % entity_id)
			if when.has("phase"):
				for p: Variant in when["phase"]:
					assert(VALID_PHASES.has(String(p)), "entity %s encounter_when references unknown phase: %s" % [entity_id, p])
			if when.has("requires"):
				assert(when["requires"] is Dictionary, "entity %s encounter_when.requires must be a Dictionary" % entity_id)
				for acc_id: String in (when["requires"] as Dictionary):
					assert(
						produced_accomplishments.has(acc_id),
						"entity %s encounter_when.requires waits on unproduced accomplishment: %s" % [entity_id, acc_id]
					)
			if when.has("absent"):
				for counter_id: String in (when["absent"] as Dictionary):
					assert(produced_accomplishments.has(counter_id), "entity %s encounter_when.absent references unproduced counter: %s (a typo here silently never gates -- GH#199 review MEDIUM-3)" % [entity_id, counter_id])

func _validate_encounter_gate_counters(scene: Dictionary, produced_accomplishments: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var entity_id: String = String(entity.get("id", "?"))
			for acc_id: String in (entity.get("ally_requires", {}) as Dictionary):
				assert(
					produced_accomplishments.has(acc_id),
					"entity %s ally_requires waits on unproduced accomplishment: %s" % [entity_id, acc_id]
				)
			var penalties: Dictionary = entity.get("ally_hp_penalty", {})
			for ally_id: String in penalties:
				var arm: Dictionary = penalties[ally_id]
				assert(arm.has("hp_mod"), "entity %s ally_hp_penalty.%s missing hp_mod" % [entity_id, ally_id])
				for acc_id: String in (arm.get("when", {}) as Dictionary):
					assert(
						produced_accomplishments.has(acc_id),
						"entity %s ally_hp_penalty.%s.when waits on unproduced accomplishment: %s" % [entity_id, ally_id, acc_id]
					)


func _validate_skill_uses(scene: Dictionary, skill_ids: Dictionary, produced_accomplishments: Dictionary) -> void:
	## Pantry-door consolidation: `skill_uses` = per-skill on_skill_use arms.
	## Every key must be a real skill id; every arm needs accomplishment +
	## toast; arm accomplishments register as produced (callers bank them).
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if not entity.has("skill_uses"):
				continue
			var entity_id: String = String(entity["id"])
			var uses: Dictionary = entity["skill_uses"]
			assert(not uses.is_empty(), "entity %s: skill_uses must not be empty" % entity_id)
			for sid: String in uses:
				assert(skill_ids.has(sid), "entity %s skill_uses references unknown skill: %s" % [entity_id, sid])
				var arm: Dictionary = uses[sid]
				assert(arm.has("accomplishment") and arm.has("toast"), "entity %s skill_uses[%s] needs accomplishment + toast" % [entity_id, sid])


func _validate_present_when(scene: Dictionary, produced_accomplishments: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		# #247 review MINOR-3: all guest entities on a map share ONE rotation
		# (each computes active_guests over its OWN roster/seats), so a divergent
		# roster would silently desync who is on-shift. Pin that they match.
		var map_guest_ref: Dictionary = {}
		var map_guest_ref_id := ""
		for entity: Dictionary in map.get("entities", []):
			if not entity.has("present_when"):
				continue
			var entity_id: String = String(entity["id"])
			var when: Dictionary = entity["present_when"]
			assert(
				String(entity.get("kind", "")) != "encounter",
				"entity %s: present_when is forbidden on kind:encounter -- _check_trigger_radius never consults presence, so a present_when encounter would be invisible/unblocked yet still ambush; use encounter_when" % entity_id
			)
			assert(when.has("requires") or when.has("phase") or when.has("absent") or when.has("guest"), "entity %s present_when has no recognized shape (only 'requires'/'phase'/'absent'/'guest' are sanctioned)" % entity_id)
			if when.has("phase"):
				for p: Variant in when["phase"]:
					assert(VALID_PHASES.has(String(p)), "entity %s present_when references unknown phase: %s" % [entity_id, p])
			if when.has("guest"):
				# d1 #247 Friends of the Inn rotation arm. Roster members are
				# met via their auto-banked chatted_with_<id> counter (registered
				# produced for every talk_pool entity, above) -- a typo in the
				# roster would silently never seat that guest, so pin production.
				assert(when["guest"] is Dictionary, "entity %s present_when.guest must be a Dictionary" % entity_id)
				var g: Dictionary = when["guest"]
				assert(g.has("npc") and g.has("roster"), "entity %s present_when.guest needs npc + roster" % entity_id)
				assert(g["roster"] is Array and not (g["roster"] as Array).is_empty(), "entity %s present_when.guest roster must be a non-empty Array" % entity_id)
				assert((g["roster"] as Array).has(String(g["npc"])), "entity %s present_when.guest npc %s must be in its own roster" % [entity_id, String(g["npc"])])
				for npc: Variant in (g["roster"] as Array):
					var met_counter := "chatted_with_" + String(npc)
					assert(produced_accomplishments.has(met_counter), "entity %s present_when.guest roster member %s: met counter %s is unproduced" % [entity_id, String(npc), met_counter])
				# All guests on a map must agree on roster + seats (MINOR-3).
				var this_spec := {"roster": g["roster"], "seats": int(g.get("seats", 2))}
				if map_guest_ref.is_empty():
					map_guest_ref = this_spec
					map_guest_ref_id = entity_id
				else:
					assert(this_spec == map_guest_ref, "entity %s present_when.guest roster/seats %s diverges from %s's %s on map %s -- co-located guests must share ONE rotation" % [entity_id, this_spec, map_guest_ref_id, map_guest_ref, map_id])
			if when.has("requires"):
				assert(when["requires"] is Dictionary, "entity %s present_when.requires must be a Dictionary" % entity_id)
				for acc_id: String in (when["requires"] as Dictionary):
					assert(
						produced_accomplishments.has(acc_id),
						"entity %s present_when.requires waits on unproduced accomplishment: %s" % [entity_id, acc_id]
					)
			if when.has("absent"):
				for counter_id: String in (when["absent"] as Dictionary):
					assert(produced_accomplishments.has(counter_id), "entity %s encounter_when.absent references unproduced counter: %s (a typo here silently never gates -- GH#199 review MEDIUM-3)" % [entity_id, counter_id])

func _validate_visual_states_phase(scene: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			for state: Variant in (entity.get("visual_states", []) as Array):
				if not (state is Dictionary):
					continue
				var when: Dictionary = (state as Dictionary).get("when", {})
				if not when.has("phase"):
					continue
				for p: Variant in when["phase"]:
					assert(VALID_PHASES.has(String(p)), "entity %s visual_states references unknown phase: %s" % [String(entity["id"]), p])


func _validate_talk_pool_echo_of(scene: Dictionary, entity_ids: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			for raw: Variant in (entity.get("talk_pool", []) as Array):
				if not (raw is Dictionary):
					continue
				var entry := raw as Dictionary
				assert(entry.has("echo_of") and entry.size() == 1, "entity %s talk_pool carries a Dictionary entry with an unrecognized shape (only {echo_of: id} is sanctioned): %s" % [String(entity["id"]), entry])
				var echo_id: String = String(entry["echo_of"])
				assert(entity_ids.has(echo_id), "entity %s echo_of references unknown entity: %s" % [String(entity["id"]), echo_id])
				var echo_target: Dictionary = _find_entity_by_id(scene, echo_id)
				var echo_pool: Array = echo_target.get("talk_pool", [])
				assert(not echo_pool.is_empty(), "entity %s echo_of target %s has no talk_pool to echo" % [String(entity["id"]), echo_id])
				for echo_line: Variant in echo_pool:
					assert(echo_line is String, "entity %s echo_of target %s's talk_pool contains a non-string entry (echo_of does not chain -- social.gd resolves one level only)" % [String(entity["id"]), echo_id])


func _find_entity_by_id(scene: Dictionary, id: String) -> Dictionary:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if String(entity["id"]) == id:
				return entity
	return {}


func _validate_conversations(scene: Dictionary, graphs: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if entity.has("conversation"):
				var conversation_id: String = String(entity["conversation"])
				assert(graphs.has(conversation_id), "entity %s conversation has no graph: %s" % [String(entity["id"]), conversation_id])


func _validate_dialogue_graphs(
	graphs: Dictionary,
	skill_ids: Dictionary,
	class_ids: Dictionary,
	item_ids: Dictionary,
	quest_ids: Dictionary,
	entity_ids: Dictionary,
	produced_accomplishments: Dictionary
) -> void:
	for graph_id: String in graphs:
		var graph: Dictionary = graphs[graph_id]
		var nodes: Dictionary = graph["nodes"]
		assert(nodes.has(String(graph["start"])), "%s start node missing: %s" % [graph_id, String(graph["start"])])
		for node_id: String in nodes:
			var node: Dictionary = nodes[node_id]
			_validate_node(graph_id, node_id, node, skill_ids, class_ids, item_ids)
			for option_index: int in (node.get("options", []) as Array).size():
				var option: Dictionary = (node.get("options", []) as Array)[option_index]
				_validate_option(graph_id, node_id, option_index, option, nodes, skill_ids, class_ids, item_ids, quest_ids, entity_ids, produced_accomplishments)


func _validate_node(graph_id: String, node_id: String, node: Dictionary, skill_ids: Dictionary, class_ids: Dictionary, item_ids: Dictionary) -> void:
	var label: String = "%s.%s" % [graph_id, node_id]
	assert(node.has("speaker"), label + " missing speaker")
	assert(node.has("text"), label + " missing text")
	if node.has("text_variants"):
		assert(node["text_variants"] is Array, label + " text_variants must be an array")
		for variant_index: int in (node["text_variants"] as Array).size():
			var variant: Dictionary = (node["text_variants"] as Array)[variant_index]
			var variant_label: String = "%s text_variants[%d]" % [label, variant_index]
			assert(variant.has("text"), variant_label + " missing text")
			assert(variant.has("requires"), variant_label + " missing requires")
			assert(variant["requires"] is Dictionary, variant_label + " requires must be a dictionary")
			_validate_requires(variant_label, variant["requires"], skill_ids, class_ids, item_ids)


func _validate_option(
	graph_id: String,
	node_id: String,
	option_index: int,
	option: Dictionary,
	nodes: Dictionary,
	skill_ids: Dictionary,
	class_ids: Dictionary,
	item_ids: Dictionary,
	quest_ids: Dictionary,
	entity_ids: Dictionary,
	produced_accomplishments: Dictionary
) -> void:
	var label: String = "%s.%s[%d]" % [graph_id, node_id, option_index]
	var has_goto: bool = option.has("goto")
	var has_end: bool = option.has("end")
	assert(has_goto != has_end, label + " must have exactly one of goto/end")
	if has_goto:
		assert(nodes.has(String(option["goto"])), label + " goto target missing: " + String(option["goto"]))
	if has_end:
		assert(bool(option["end"]), label + " end must be true")
	if option.has("requires"):
		_validate_requires(label, option["requires"], skill_ids, class_ids, item_ids)
	if option.has("hide_when"):
		assert(_hide_when_gate_keys_allowed(option["hide_when"]), label + " hide_when must not carry once_per_waking (requires-only gate, Issue #23)")
		_validate_requires(label + " hide_when", option["hide_when"], skill_ids, class_ids, item_ids)
	for effect: Dictionary in option.get("effects", []):
		_validate_effect(label, effect, quest_ids, class_ids, item_ids, entity_ids, produced_accomplishments)
	if option.has("requires") and (option["requires"] as Dictionary).has("gold"):
		var gold_requirement := int((option["requires"] as Dictionary)["gold"])
		for effect: Dictionary in option.get("effects", []):
			if effect.has("gold"):
				assert(int(effect["gold"]) == -gold_requirement, "%s requires.gold (%d) has a mismatched effects.gold (%d) -- WIDialogue.choose()'s [Bargain] price_mod can only discount an effect matching -requires.gold exactly" % [label, gold_requirement, int(effect["gold"])])
		var option_text := String(option.get("text", ""))
		if option_text.contains("gold)"):
			assert(option_text.contains("(%d gold)" % gold_requirement), "%s bakes a price into its text but not as '(%d gold)' (requires.gold) -- WIDialogue._priced_text's discount rewrite would miss it and the display could contradict the charge" % [label, gold_requirement])


func _validate_requires(label: String, requires: Dictionary, skill_ids: Dictionary, class_ids: Dictionary, item_ids: Dictionary) -> void:
	var gate_keys := 0
	if requires.has("skill"):
		gate_keys += 1
		var skill_id: String = String(requires["skill"])
		assert(skill_ids.has(skill_id), label + " requires unknown skill: " + skill_id)
	if requires.has("class"):
		gate_keys += 1
		var classes_required: Dictionary = requires["class"]
		for class_id: String in classes_required:
			assert(class_ids.has(class_id), label + " requires unknown class: " + class_id)
	if requires.has("accomplishment"):
		gate_keys += 1
	if requires.has("board_accepted"):
		gate_keys += 1
		assert(requires["board_accepted"] is bool, label + " board_accepted must be a bool")
	if requires.has("delivery_accepted"):
		gate_keys += 1
		assert(requires["delivery_accepted"] is bool, label + " delivery_accepted must be a bool")
	if requires.has("gold"):
		gate_keys += 1
		assert(int(requires["gold"]) > 0, label + " gold requirement must be a positive price")
	if requires.has("once_per_waking"):
		gate_keys += 1
		assert(_is_valid_verb_entity_key(requires["once_per_waking"]), label + " once_per_waking must be a \"<verb>:<entity>\" string with both segments non-empty")
	if requires.has("item"):
		gate_keys += 1
		var item_id: String = String(requires["item"])
		assert(item_ids.has(item_id), label + " requires unknown item: " + item_id)
	if requires.has("race"):
		gate_keys += 1
		var race_id: String = String(requires["race"])
		assert(["human", "drake", "gnoll"].has(race_id), label + " requires unknown race: " + race_id)
	if requires.has("phase"):
		gate_keys += 1
		assert(requires["phase"] is Array, label + " requires.phase must be an array")
		var phase_ids: Array = requires["phase"]
		assert(not phase_ids.is_empty(), label + " requires.phase must not be empty")
		for phase_id: Variant in phase_ids:
			assert(["day", "dusk", "night"].has(String(phase_id)), label + " requires unknown phase: " + String(phase_id))
	if gate_keys == 2:
		var sanctioned_gold_accomplishment := requires.has("gold") and requires.has("accomplishment")
		var sanctioned_stage_once := requires.has("accomplishment") and requires.has("once_per_waking")
		var sanctioned_stage_class := requires.has("accomplishment") and requires.has("class")
		var sanctioned_once_item := requires.has("once_per_waking") and requires.has("item")
		var sanctioned_stage_skill := requires.has("accomplishment") and requires.has("skill")
		# {gold, item}: priced item-services (GH#142 Hedault enchanting --
		# hold the base item AND afford the fee; both gates show-locked).
		var sanctioned_gold_item := requires.has("gold") and requires.has("item")
		assert(sanctioned_gold_accomplishment or sanctioned_stage_once or sanctioned_stage_class or sanctioned_once_item or sanctioned_stage_skill or sanctioned_gold_item, label + " the only sanctioned compound requires are {gold, accomplishment}, {accomplishment, once_per_waking}, {accomplishment, class}, {once_per_waking, item}, {accomplishment, skill}, and {gold, item}")
		return
	assert(gate_keys == 1, label + " requires must use exactly one gate type")


func _is_valid_verb_entity_key(value: Variant) -> bool:
	if not (value is String):
		return false
	var parts: PackedStringArray = String(value).split(":", true, 1)
	return parts.size() == 2 and not parts[0].is_empty() and not parts[1].is_empty()


func _hide_when_gate_keys_allowed(hide_when: Dictionary) -> bool:
	return not hide_when.has("once_per_waking")


func _validate_once_per_waking_shape_cases() -> void:
	assert(_is_valid_verb_entity_key("meal:erin"), "verb:entity accepted (Erin's meal)")
	assert(_is_valid_verb_entity_key("wager:relc"), "verb:entity accepted (Relc's wager)")
	assert(_is_valid_verb_entity_key("observe:gossip_npc"), "verb:entity accepted (existing entity_first_use shape)")
	assert(not _is_valid_verb_entity_key("meal"), "missing colon rejected")
	assert(not _is_valid_verb_entity_key(":erin"), "empty verb segment rejected")
	assert(not _is_valid_verb_entity_key("meal:"), "empty entity segment rejected")
	assert(not _is_valid_verb_entity_key(""), "empty string rejected")
	assert(not _is_valid_verb_entity_key(true), "non-string bool value rejected")
	assert(not _is_valid_verb_entity_key(5), "non-string numeric value rejected")
	assert(not _is_valid_verb_entity_key(["meal", "erin"]), "non-string array value rejected")
	assert(_is_valid_verb_entity_key("meal:erin:extra"), "extra colon still splits into two non-empty segments")
	assert(not _hide_when_gate_keys_allowed({"once_per_waking": "meal:erin"}), "hide_when carrying once_per_waking rejected (requires-only gate)")
	assert(not _hide_when_gate_keys_allowed({"accomplishment": {"x": 1}, "once_per_waking": "meal:erin"}), "hide_when carrying once_per_waking alongside another key still rejected")
	assert(_hide_when_gate_keys_allowed({"accomplishment": {"has_package": 1}}), "accomplishment hide_when still accepted")
	assert(_hide_when_gate_keys_allowed({"board_accepted": true}), "board_accepted hide_when still accepted")
	assert(_hide_when_gate_keys_allowed({}), "empty hide_when accepted (never authored, but not this rule's business)")


const DIALOGUE_EFFECT_VERBS := [
	"accomplishment", "quest", "remove_entity", "dormant_entity", "item", "gold",
	"bank_first_use", "remove_item", "well_fed", "start_combat", "travel_to",
	"accept_bounty", "accept_delivery", "sell_item", "open_board_picker",
	"open_board_turnin", "open_board_abandon", "open_delivery_picker",
	"open_delivery_turnin", "open_sell_picker",
]


func _validate_effect(
	label: String,
	effect: Dictionary,
	quest_ids: Dictionary,
	class_ids: Dictionary,
	item_ids: Dictionary,
	entity_ids: Dictionary,
	produced_accomplishments: Dictionary
) -> void:
	var verb_count := 0
	for key: String in effect:
		if key == "_comment":
			continue
		assert(DIALOGUE_EFFECT_VERBS.has(key) or key == "class", label + " carries unrecognized effect key: " + key)
		verb_count += 1
	assert(verb_count == 1, label + " effect dict must carry exactly ONE verb (got %d): %s" % [verb_count, str(effect.keys())])
	if effect.has("accomplishment"):
		produced_accomplishments[String(effect["accomplishment"])] = true
	if effect.has("quest"):
		var quest_id: String = String(effect["quest"])
		assert(quest_ids.has(quest_id), label + " starts unknown quest: " + quest_id)
	if effect.has("remove_entity"):
		var remove_id: String = String(effect["remove_entity"])
		assert(entity_ids.has(remove_id), label + " removes unknown entity: " + remove_id)
	if effect.has("dormant_entity"):
		var dormant_id: String = String(effect["dormant_entity"])
		assert(entity_ids.has(dormant_id), label + " removes unknown entity: " + dormant_id)
	if effect.has("start_combat"):
		var combat_id: String = String(effect["start_combat"])
		assert(entity_ids.has(combat_id), label + " starts combat for unknown entity: " + combat_id)
	if effect.has("class"):
		var class_id: String = String(effect["class"])
		assert(class_ids.has(class_id), label + " references unknown class: " + class_id)
	if effect.has("item"):
		var granted_item_id: String = String(effect["item"])
		assert(item_ids.has(granted_item_id), label + " grants unknown item: " + granted_item_id)
	if effect.has("bank_first_use"):
		assert(_is_valid_verb_entity_key(effect["bank_first_use"]), label + " bank_first_use must be a \"<verb>:<entity>\" string with both segments non-empty")


func _validate_hide_when_nodes_have_always_available_exit(graphs: Dictionary) -> void:
	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			var node: Dictionary = nodes[node_id]
			var options: Array = node.get("options", [])
			var has_vanishing_option := false
			for option: Dictionary in options:
				var opt_requires: Dictionary = option.get("requires", {})
				if option.has("hide_when") or opt_requires.has("accomplishment") or opt_requires.has("board_accepted") or opt_requires.has("delivery_accepted") or opt_requires.has("once_per_waking"):
					has_vanishing_option = true
					break
			if not has_vanishing_option:
				continue
			var has_always_available := false
			for option: Dictionary in options:
				if not option.has("hide_when") and not option.has("requires"):
					has_always_available = true
					break
			assert(has_always_available, "%s.%s has hide_when/progress-gated options but no always-available option -- risk of softlock" % [graph_id, node_id])


func _validate_class_gains(classes: Dictionary, produced_accomplishments: Dictionary) -> void:
	for cls: Dictionary in classes.get("classes", []):
		if not cls.has("gained_by"):
			continue
		var condition: Dictionary = (cls["gained_by"] as Dictionary).get("accomplishment", {})
		for accomplishment_id: String in condition:
			assert(
				produced_accomplishments.has(accomplishment_id),
				"class %s gained_by waits on unproduced accomplishment: %s" % [String(cls["id"]), accomplishment_id]
			)


func _validate_class_level_tables(classes: Dictionary) -> void:
	var catalog_list: Array = classes.get("classes", [])

	var floor_candidates: Dictionary = {}

	for cls: Dictionary in catalog_list:
		var evo: Dictionary = cls.get("evolution", {})
		var targets: Dictionary = evo.get("targets", {})
		if targets.is_empty():
			continue
		var at_level := int(evo.get("at_level", 0))
		for key: String in targets:
			var target_id := String(targets[key])
			if not floor_candidates.has(target_id):
				floor_candidates[target_id] = []
			(floor_candidates[target_id] as Array).append(at_level)

	for entry: Dictionary in classes.get("consolidations", []):
		var target_id := String(entry.get("target", ""))
		var min_parent_level := int(entry.get("min_parent_level", 0))
		var min_combined_level := int(entry.get("min_combined_level", 0))
		var s_min := maxi(min_combined_level, 2 * min_parent_level)
		var level_a := s_min / 2
		var level_b := s_min - level_a
		var merged := WIProgression._consolidation_merged_level(level_a, level_b)
		if not floor_candidates.has(target_id):
			floor_candidates[target_id] = []
		(floor_candidates[target_id] as Array).append(merged)

	var class_table_max: Dictionary = {}

	for cls: Dictionary in catalog_list:
		var id := String(cls["id"])
		var levels: Array = cls.get("levels", [])
		assert(not levels.is_empty(), "class %s has no levels entries" % id)

		var level_set: Dictionary = {}
		var max_level := 0
		var min_level := 999999
		for lv: Dictionary in levels:
			var l := int(lv["level"])
			level_set[l] = true
			max_level = maxi(max_level, l)
			min_level = mini(min_level, l)
		class_table_max[id] = max_level

		var reqs: Dictionary = (cls.get("gained_by", {}) as Dictionary).get("accomplishment", {})
		var has_gained_by := not reqs.is_empty()

		var floor_level := 1
		var is_evolution_only := false
		if not has_gained_by and floor_candidates.has(id):
			is_evolution_only = true
			floor_level = 999999
			for f: Variant in (floor_candidates[id] as Array):
				floor_level = mini(floor_level, int(f))

		assert(min_level >= floor_level, "class %s has a levels entry (level %d) below its derived floor %d -- sub-floor entries are unreachable padding (GH#54 sparse-table convention)" % [id, min_level, floor_level])

		for l in range(floor_level, max_level + 1):
			assert(level_set.has(l), "class %s is missing a levels entry at %d (floor %d, max %d) -- the level-up/evolution walk could arrive at an uncovered level" % [id, l, floor_level, max_level])

		if is_evolution_only:
			assert(min_level == floor_level, "class %s (evolution-only, reachable only via Replacement/consolidation) must start EXACTLY at its derived floor %d, found its lowest authored entry at %d" % [id, floor_level, min_level])

	for entry: Dictionary in classes.get("consolidations", []):
		var target_id := String(entry.get("target", ""))
		var lines: Array = entry.get("parent_lines", [])
		if lines.size() != 2:
			continue
		var line_ceilings: Array = []
		for line: Variant in lines:
			var line_max := 0
			for line_id: Variant in (line as Array):
				line_max = maxi(line_max, int(class_table_max.get(String(line_id), 0)))
			line_ceilings.append(line_max)
		var merged_ceiling := WIProgression._consolidation_merged_level(int(line_ceilings[0]), int(line_ceilings[1]))
		var target_max := int(class_table_max.get(target_id, 0))
		assert(
			target_max >= merged_ceiling,
			"consolidation target %s table max %d cannot hold the merge formula's top-end %d (parent lines' own table maxes: %d, %d) -- a player who levels both parent lines to their real ceiling before consolidating is assigned a held level with no levels entry (HP/MP growth and grants silently stop, GH#61)" % [target_id, target_max, merged_ceiling, line_ceilings[0], line_ceilings[1]]
		)


func _missing_class_skill_grant_ids(classes: Dictionary, skill_ids: Dictionary) -> Array:
	var missing: Array = []
	for cls: Dictionary in classes.get("classes", []):
		var cls_id := String(cls.get("id", "?"))
		for lv: Dictionary in cls.get("levels", []):
			var lv_num := str(lv.get("level", "?"))
			for sk: Variant in lv.get("grants", []):
				var sk_id := String(sk)
				if not skill_ids.has(sk_id):
					missing.append("class %s L%s grants unknown skill id: %s" % [cls_id, lv_num, sk_id])
		var evo: Dictionary = cls.get("evolution", {})
		for sk: Variant in evo.get("balanced_grants", []):
			var sk_id := String(sk)
			if not skill_ids.has(sk_id):
				missing.append("class %s evolution.balanced_grants unknown skill id: %s" % [cls_id, sk_id])
	return missing


func _validate_class_skill_grant_ids(classes: Dictionary, skill_ids: Dictionary) -> void:
	var missing := _missing_class_skill_grant_ids(classes, skill_ids)
	assert(missing.is_empty(), "class grant(s) reference unknown skill id(s) -- ghost grants (#96 hardening): " + ", ".join(missing))


func _validate_class_skill_grant_ids_shape_cases() -> void:
	var skill_ids: Dictionary = {"real_skill": true}

	var clean: Dictionary = {"classes": [{
		"id": "x",
		"levels": [{"level": 1, "grants": ["real_skill"]}],
		"evolution": {"balanced_grants": ["real_skill"]},
	}]}
	assert(_missing_class_skill_grant_ids(clean, skill_ids).is_empty(), "clean catalog should report no missing grant ids")

	var bad_level: Dictionary = {"classes": [{
		"id": "x",
		"levels": [{"level": 1, "grants": ["ghost_skill"]}],
	}]}
	assert(not _missing_class_skill_grant_ids(bad_level, skill_ids).is_empty(), "NEGATIVE CONTROL: a typo'd levels[].grants id must be caught")

	var bad_balanced: Dictionary = {"classes": [{
		"id": "x",
		"levels": [{"level": 1, "grants": []}],
		"evolution": {"balanced_grants": ["ghost_skill"]},
	}]}
	assert(not _missing_class_skill_grant_ids(bad_balanced, skill_ids).is_empty(), "NEGATIVE CONTROL: a typo'd evolution.balanced_grants id must be caught")


func _validate_quests(quests: Dictionary, produced_accomplishments: Dictionary) -> void:
	for quest: Dictionary in quests.get("quests", []):
		for beat: Dictionary in quest.get("beats", []):
			var complete_when: Dictionary = beat.get("complete_when", {})
			for accomplishment_id: String in complete_when:
				assert(
					produced_accomplishments.has(accomplishment_id),
					"quest %s beat %s waits on unproduced accomplishment: %s" % [String(quest["id"]), String(beat["id"]), accomplishment_id]
				)


const LANDMARK_TOKENS := {
	"inn": ["inn"],
	"inn_upstairs": ["upstairs"],
	"street": ["market", "square", "gate"],
	"floodplains": ["floodplains"],
	"sewers": ["sewer", "cistern"],
	"deep_tunnels": ["deep tunnels", "tunnels"],
	"guild": ["guild"],
	"barracks": ["barracks"],
	"runners_guild": ["runner"],
	"ruin_surface": ["ruin", "floodplains"],
	"garden_sanctuary": ["garden"],
	"riverfarm_village": ["riverfarm"],
	"riverfarm_longhouse": ["longhouse"],
	# 2026-07-26 (Phase 6, the pilgrimage spine): a sub-map accepts its REGION's
	# token as well as its own, the widening `ruin_surface` already carries for
	# "floodplains". The spine's beats name each stop by region ("Riverfarm" /
	# "Invrisil" / "Pallass"), which is the honest landmark for a beat whose whole
	# subject is a region opening up; the region-hub maps already tokenize that
	# word (riverfarm_village "riverfarm", invrisil_boulevard "invrisil",
	# pallass_market "pallass") and only their SIDE maps lacked it, so a correctly
	# aimed beat read as unlandmarked. Widening the table, not the copy -- every
	# pre-existing token still satisfies every pre-existing beat.
	"witch_hollow": ["hollow", "riverfarm"],
	"invrisil_boulevard": ["boulevard", "invrisil"],
	"mercantile_alleys": ["alleys", "counting house", "invrisil"],
	"brothers_parlor": ["parlor"],
	"dungeon_approach": ["dungeon"],
	"trapped_halls": ["trapped halls", "halls"],
	"pallass_market": ["pallass", "market tier"],
	"pallass_forge": ["forge tier", "grand lift"],
}


func _conversation_maps(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if entity.has("conversation"):
				var conv_id: String = String(entity["conversation"])
				if not out.has(conv_id):
					out[conv_id] = {}
				out[conv_id][map_id] = true
	return out


func _accomplishment_producer_maps(scene: Dictionary, graphs: Dictionary, conversation_maps: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var victory: Variant = entity.get("on_victory", [])
			var victory_ids: Array = victory if victory is Array else [victory] if victory is String else []
			for id: Variant in victory_ids:
				_mark_producer(out, String(id), map_id)
			if entity.has("on_skill_use") and (entity["on_skill_use"] as Dictionary).has("accomplishment"):
				_mark_producer(out, String((entity["on_skill_use"] as Dictionary)["accomplishment"]), map_id)
			for su_variant: Dictionary in ((entity.get("on_skill_use", {}) as Dictionary).get("variants", []) as Array):
				if su_variant.has("accomplishment"):
					_mark_producer(out, String(su_variant["accomplishment"]), map_id)
			if entity.has("on_interact_accomplishment"):
				_mark_producer(out, String(entity["on_interact_accomplishment"]), map_id)
			for variant: Dictionary in (entity.get("variants", []) as Array):
				if variant.has("accomplishment"):
					_mark_producer(out, String(variant["accomplishment"]), map_id)
			var open_banks: Variant = entity.get("on_open_accomplishment", [])
			for counter: Variant in (open_banks if open_banks is Array else [open_banks]):
				_mark_producer(out, String(counter), map_id)
			for rumor: Dictionary in (entity.get("board_rumors", []) as Array):
				_mark_producer(out, String(rumor["banks_accomplishment"]), map_id)
	for graph_id: String in graphs:
		var maps_for_graph: Dictionary = conversation_maps.get(graph_id, {})
		if maps_for_graph.is_empty():
			continue
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				for effect: Dictionary in (option.get("effects", []) as Array):
					if effect.has("accomplishment"):
						for map_id: String in maps_for_graph:
							_mark_producer(out, String(effect["accomplishment"]), map_id)
	return out


func _mark_producer(producer_maps: Dictionary, accomplishment_id: String, map_id: String) -> void:
	if not producer_maps.has(accomplishment_id):
		producer_maps[accomplishment_id] = {}
	producer_maps[accomplishment_id][map_id] = true


func _quest_giver_maps(graphs: Dictionary, conversation_maps: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for graph_id: String in graphs:
		var maps_for_graph: Dictionary = conversation_maps.get(graph_id, {})
		if maps_for_graph.is_empty():
			continue
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				for effect: Dictionary in (option.get("effects", []) as Array):
					if effect.has("quest"):
						var quest_id: String = String(effect["quest"])
						if not out.has(quest_id):
							out[quest_id] = {}
						for map_id: String in maps_for_graph:
							out[quest_id][map_id] = true
	return out


func _beat_needs_place_name(beat_maps: Dictionary, giver_maps: Dictionary) -> bool:
	if beat_maps.is_empty():
		return false
	for map_id: String in beat_maps:
		if giver_maps.has(map_id):
			return false
	return true


func _description_names_place(description: String, tokens: Array) -> bool:
	var lower := description.to_lower()
	for token: String in tokens:
		if lower.contains(String(token).to_lower()):
			return true
	return false


func _validate_travel_beat_place_naming(quests: Dictionary, scene: Dictionary, graphs: Dictionary) -> void:
	var conversation_maps: Dictionary = _conversation_maps(scene)
	var producer_maps: Dictionary = _accomplishment_producer_maps(scene, graphs, conversation_maps)
	var giver_maps: Dictionary = _quest_giver_maps(graphs, conversation_maps)
	for quest: Dictionary in quests.get("quests", []):
		var quest_id := String(quest["id"])
		var quest_giver_maps: Dictionary = giver_maps.get(quest_id, {})
		for beat: Dictionary in quest.get("beats", []):
			var complete_when: Dictionary = beat.get("complete_when", {})
			var beat_maps: Dictionary = {}
			for accomplishment_id: String in complete_when:
				for map_id: String in (producer_maps.get(accomplishment_id, {}) as Dictionary):
					beat_maps[map_id] = true
			if not _beat_needs_place_name(beat_maps, quest_giver_maps):
				continue
			var tokens: Array = []
			for map_id: String in beat_maps:
				assert(LANDMARK_TOKENS.has(map_id), "quest %s beat %s needs a travel landmark on map %s, which has no LANDMARK_TOKENS entry" % [quest_id, String(beat["id"]), map_id])
				tokens.append_array(LANDMARK_TOKENS[map_id])
			var description := String(beat.get("description", ""))
			assert(
				_description_names_place(description, tokens),
				"quest %s beat %s is a travel-only beat (giver map(s) %s, producer map(s) %s) but its description names no landmark from %s: %s" % [quest_id, String(beat["id"]), quest_giver_maps.keys(), beat_maps.keys(), tokens, description]
			)


func _validate_place_naming_shape_cases() -> void:
	assert(not _beat_needs_place_name({"inn": true}, {"inn": true}), "same-map beat needs no landmark")
	assert(_beat_needs_place_name({"guild": true}, {"inn": true}), "guild-only beat, inn-given quest, needs a landmark")
	assert(not _beat_needs_place_name({"inn": true, "street": true}, {"inn": true}), "a beat with ANY same-map route needs no landmark, even with a foreign alternate route")
	assert(not _beat_needs_place_name({}, {"inn": true}), "no known producer map -- nothing to cross-check, not this check's business")
	assert(_beat_needs_place_name({"guild": true}, {}), "an unresolvable quest-giver map (empty set) can share no map with anything -- fails loud (requires naming) rather than silently skipping the beat")

	# 2026-07-26 (Task 2.3): "ruin" joined LANDMARK_TOKENS["ruin_surface"] --
	# horns_dig's join_dig/breach beats are ruin-produced but inn/dungeon-given,
	# so they arm this check and the ruin is the landmark a player steers by.
	# The old negative control ("...from the ruin and buy Krshia's catalyst")
	# names the ruin, so it is no longer a no-landmark string; the control below
	# is the same sentence with every landmark word removed, preserving intent.
	var ruin_tokens: Array = LANDMARK_TOKENS["ruin_surface"] + LANDMARK_TOKENS["street"]
	assert(_description_names_place("Recover the anchor stone from the ruin east past the gate road, on the floodplains, and buy Krshia's catalyst to attune it.", ruin_tokens), "fixed recover beat names the ruin/floodplains")
	assert(_description_names_place("Get the Horns through the ruin's sealed pedestal level -- fight what guards it, walk the plates, or read the wardwork.", ruin_tokens), "horns_dig's breach beat names the ruin")
	assert(not _description_names_place("Recover the anchor stone and buy Krshia's catalyst to attune it.", ruin_tokens), "NEGATIVE CONTROL: a recovery beat naming no landmark at all")

	var guild_tokens: Array = LANDMARK_TOKENS["guild"]
	assert(_description_names_place("Decide what to do with Selys's reward, there at the Guild.", guild_tokens), "fixed decide beat names the Guild")
	assert(not _description_names_place("Decide what to do with Selys's reward.", guild_tokens), "NEGATIVE CONTROL: the pre-fix decide beat names no landmark")

	var boulevard_tokens: Array = LANDMARK_TOKENS["invrisil_boulevard"]
	assert(_description_names_place("Find out exactly where Coyle's operation actually runs, along the boulevard, before you make a move on him.", boulevard_tokens), "fixed scout beat names the boulevard")
	assert(not _description_names_place("Find out exactly where Coyle's operation actually runs, before you make a move on him.", boulevard_tokens), "NEGATIVE CONTROL: the pre-fix scout beat names no landmark")
	assert(_description_names_place("Clear Farley's name — corner Master Coyle, back on the boulevard, however you see fit.", boulevard_tokens), "fixed resolve beat names the boulevard")
	assert(not _description_names_place("Clear Farley's name — corner Master Coyle however you see fit.", boulevard_tokens), "NEGATIVE CONTROL: the pre-fix resolve beat names no landmark")

## b2 #218: the fence pool is builder-consumed (code-built graph — never
## scanned by the dialogue validators), so its records get the bounty-style
## static check: item exists, price positive, patter non-empty.
func _validate_fence(fence: Dictionary, item_ids: Dictionary) -> void:
	for rec: Dictionary in fence.get("stock", []):
		var rid := String(rec.get("id", "?"))
		assert(item_ids.has(String(rec.get("item", ""))), "fence record %s references unknown item: %s" % [rid, rec.get("item")])
		assert(int(rec.get("price", 0)) > 0, "fence record %s needs a positive price" % rid)
		assert(String(rec.get("patter", "")) != "", "fence record %s needs a patter line" % rid)


func _validate_bounties(bounties: Dictionary, produced_accomplishments: Dictionary) -> void:
	for bounty: Dictionary in bounties.get("bounties", []):
		var condition: Dictionary = bounty.get("condition", {})
		for accomplishment_id: String in condition:
			assert(
				produced_accomplishments.has(accomplishment_id),
				"bounty %s condition waits on unproduced accomplishment: %s" % [String(bounty["id"]), accomplishment_id]
			)
		# #163: every tier's condition keys must be producible too.
		for rank: String in (bounty.get("tiers", {}) as Dictionary):
			var tier: Dictionary = (bounty["tiers"] as Dictionary)[rank]
			for accomplishment_id: String in (tier.get("condition", {}) as Dictionary):
				assert(
					produced_accomplishments.has(accomplishment_id),
					"bounty %s tier %s condition waits on unproduced accomplishment: %s" % [String(bounty["id"]), rank, accomplishment_id]
				)


## #163 payout-anchor VALIDATOR (consumes #92's price ladder so a price move
## fails loud HERE instead of drifting purchasing power). Per tiered posting:
## silver.gold is a multiple of crude_draught's price (the entry rung), gold.gold
## a multiple of tonic_of_the_clear_eye's price (the tonic tier); higher rank
## never pays less (monotonicity); a top-tier COMBAT bounty clears the
## purchasing-power floor (>= 2x mending_draught, its expected consumable burn).
func _validate_bounty_payout_anchors(bounties: Dictionary, items: Dictionary) -> void:
	var price: Dictionary = {}
	for it: Dictionary in items.get("items", []):
		price[String(it["id"])] = int(it.get("price", 0))
	var crude := int(price.get("crude_draught", 0))
	var tonic := int(price.get("tonic_of_the_clear_eye", 0))
	var mending := int(price.get("mending_draught", 0))
	assert(crude > 0 and tonic > 0 and mending > 0, "#163 anchor items (crude_draught/tonic_of_the_clear_eye/mending_draught) must all carry price>0")
	for bounty: Dictionary in bounties.get("bounties", []):
		var tiers: Dictionary = bounty.get("tiers", {})
		if tiers.is_empty():
			continue
		var bid := String(bounty["id"])
		var prev_gold := int(bounty.get("gold", 0))
		for rank: String in ["silver", "gold"]:
			if not tiers.has(rank):
				continue
			var g := int((tiers[rank] as Dictionary).get("gold", 0))
			assert(g > prev_gold, "%s tier %s gold %d must exceed the lower rank's %d (monotonicity, #163)" % [bid, rank, g, prev_gold])
			prev_gold = g
			if rank == "silver":
				assert(g % crude == 0, "%s silver gold %d is not a multiple of crude_draught price %d (payout anchor, #163/#92)" % [bid, g, crude])
			else:
				assert(g % tonic == 0, "%s gold gold %d is not a multiple of tonic_of_the_clear_eye price %d (payout anchor, #163/#92)" % [bid, g, tonic])
		if String(bounty.get("pillar", "")) == "fight" and tiers.has("gold"):
			var top := int((tiers["gold"] as Dictionary).get("gold", 0))
			assert(top >= 2 * mending, "%s top-tier combat gold %d below purchasing-power floor 2x mending_draught (%d) (#163)" % [bid, top, 2 * mending])


## #163 engine-seam guard: `scales:true` (rank-stepped enemies at start_combat)
## is legal ONLY on a repeatable cull -- an encounter with respawns:true whose
## on_victory counter feeds NO quest. Story/boss fights (respawns:false, or an
## on_victory a quest beat waits on) must never scale. Rule DERIVED from data:
## the forbidden-counter set is every quest beat's complete_when keys.
func _validate_encounter_scaling(scene: Dictionary, quests: Dictionary) -> void:
	var quest_counters: Dictionary = {}
	for quest: Dictionary in quests.get("quests", []):
		for beat: Dictionary in quest.get("beats", []):
			for key: String in (beat.get("complete_when", {}) as Dictionary):
				quest_counters[key] = true
	for map_id: String in scene["maps"]:
		for ent: Dictionary in scene["maps"][map_id].get("entities", []):
			if not bool(ent.get("scales", false)):
				continue
			var eid := String(ent.get("id", "?"))
			assert(String(ent.get("kind", "")) == "encounter", "%s has scales:true but is not an encounter (#163)" % eid)
			assert(bool(ent.get("respawns", false)), "%s has scales:true but respawns:false -- only repeatable culls scale (#163)" % eid)
			# on_victory is String-or-Array (wi_game accepts both) -- iterate
			# the same way or the Array form crashes the String() ctor
			# (review LOW: probe-proven on snare_nest_slot's list form).
			var raw_ov: Variant = ent.get("on_victory", "")
			var victories: Array = []
			if raw_ov is Array:
				victories = raw_ov
			elif String(raw_ov) != "":
				victories = [raw_ov]
			assert(not victories.is_empty(), "%s has scales:true but no on_victory counter (#163)" % eid)
			for ov_raw: Variant in victories:
				var ov := String(ov_raw)
				assert(not quest_counters.has(ov), "%s has scales:true but its on_victory '%s' feeds a quest counter -- story/quest fights never scale (#163)" % [eid, ov])


func _validate_deliveries(deliveries: Dictionary, produced_accomplishments: Dictionary) -> void:
	var produced := produced_accomplishments.duplicate()
	for delivery: Dictionary in deliveries.get("deliveries", []):
		produced["delivered_%s" % String(delivery["id"])] = true
	for delivery: Dictionary in deliveries.get("deliveries", []):
		var condition: Dictionary = delivery.get("condition", {})
		for accomplishment_id: String in condition:
			assert(
				produced.has(accomplishment_id),
				"delivery %s condition waits on unproduced accomplishment: %s" % [String(delivery["id"]), accomplishment_id]
			)


func _validate_props(scene: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var entity_id: String = String(entity["id"])
			if entity.has("on_interact_accomplishment"):
				var toast: String = String(entity.get("toast", ""))
				assert(
					not toast.is_empty(),
					"entity %s has on_interact_accomplishment but empty or missing toast" % entity_id
				)
			if String(entity.get("kind", "")) == "prop":
				var has_sleep: bool = bool(entity.get("sleep", false))
				var has_accomplishment: bool = entity.has("on_interact_accomplishment")
				assert(
					not (has_sleep and has_accomplishment),
					"prop %s cannot combine sleep with on_interact_accomplishment" % entity_id
				)


func _validate_tutor_line_help_consistency() -> void:
	var arenas: Dictionary = _load_json("res://data/arenas.json")
	var help: Dictionary = _load_json("res://data/help_content.json")
	var classes_body := ""
	for section: Dictionary in (help.get("sections", []) as Array):
		if String(section.get("heading", "")) == "Classes & Levels":
			classes_body = String(section.get("body", ""))
	assert(not classes_body.is_empty(), "help_content.json missing its 'Classes & Levels' section")
	var found := false
	for arena: Dictionary in (arenas.get("arenas", []) as Array):
		if String(arena.get("id", "")) != "goblin_ambush_tutorial":
			continue
		for entry: Dictionary in (arena.get("tutor_lines", []) as Array):
			if String(entry.get("id", "")) != "real_ones":
				continue
			found = true
			var solo_line := String(entry.get("solo_fallback_line", ""))
			assert(
				solo_line == classes_body,
				"real_ones.solo_fallback_line has drifted from help_content.json's Classes & Levels wording"
			)
	assert(found, "goblin_ambush_tutorial's real_ones tutor line is missing (arenas.json)")


## GH#142: enchant pairs are the dialogue-effect swap triple (negative gold
## fee + remove_item base + item variant in ONE option). Derived from the
## graphs, no list to maintain. Economics: variant price > base price +
## fee/2 (Hedault charges for real value), both records accessories.
func _validate_enchant_pairs(graphs: Dictionary, items: Dictionary) -> void:
	var by_id: Dictionary = {}
	for it: Dictionary in items.get("items", []):
		by_id[String(it["id"])] = it
	for conv_id: String in graphs:
		for node_id: String in (graphs[conv_id] as Dictionary).get("nodes", {}):
			var node: Dictionary = graphs[conv_id]["nodes"][node_id]
			for opt: Variant in node.get("options", []):
				var fee := 0
				var removed := ""
				var granted := ""
				for effect: Dictionary in (opt as Dictionary).get("effects", []):
					if effect.has("gold") and int(effect["gold"]) < 0:
						fee = -int(effect["gold"])
					elif effect.has("remove_item"):
						removed = String(effect["remove_item"])
					elif effect.has("item"):
						granted = String(effect["item"])
				if fee == 0 or removed == "" or granted == "":
					continue
				var base: Dictionary = by_id.get(removed, {})
				var variant: Dictionary = by_id.get(granted, {})
				assert(not base.is_empty() and not variant.is_empty(), "%s/%s enchant references unknown items %s -> %s" % [conv_id, node_id, removed, granted])
				assert(String(variant.get("kind", "")) == "accessory" and String(base.get("kind", "")) == "accessory", "%s enchant pair must be accessories" % conv_id)
				assert(
					int(variant.get("price", 0)) * 2 > int(base.get("price", 0)) * 2 + fee,
					"%s enchant %s->%s: variant price %d must exceed base %d + fee %d/2 (paid work must hold value)" % [conv_id, removed, granted, int(variant.get("price", 0)), int(base.get("price", 0)), fee]
				)
