class_name WIGame
extends RefCounted

# Pure simulation: dependencies enter through config, seed, and the event sink; never reach into autoloads or the scene tree.

var grid_size: Vector2i
var current_map: String = ""
var player_cell: Vector2i
var player_facing := Vector2i.RIGHT
const PC_RACES: Array[String] = ["human", "drake", "gnoll"]
const PC_GENDERS: Array[String] = ["m", "f"]
const PC_NAME_MAX := 16
var pc_name: String = "Traveler"
var pc_race: String = "human"
var pc_gender: String = "m"
var player_skills: Array[String] = []
var accomplishments: Dictionary = {}
var entities: Dictionary = {}
var blocked_cells: Dictionary = {}
var skills: Dictionary = {}
var classes: Dictionary = {}
var combat: WICombat = null
var dialogue: WIDialogue = null
var started_quests: Array[String] = []
var removed_entities: Array[String] = []
var dormant_encounters: Array[String] = []
var generalist_classes: Array[String] = []
var used_skills: Array[String] = []
var seen_statuses: Array[String] = []
var pending_consolidation: Dictionary = {}
var inventory: Array[String] = []
# Every non-empty equipped id must also remain in inventory.
var equipped: Dictionary = {WIKeys.WEAPON: "", "armor": "", "accessory_1": "", "accessory_2": "", "accessory_3": ""}
var resonance_capacity: int = 2
var container_state: Dictionary = {}
var actions_since_sleep: int = 0
var gold: int = 0
var times_slept: int = 0
var accepted_bounty_id: String = ""
var accepted_bounty_baseline: Dictionary = {}
# Issue #163: rank locked at accept ("bronze"/"silver"/"gold"); turn-in pays
# the accepted tier even if the player's rank shifts before turning in. "" ==
# bronze (old saves, base-record postings).
var accepted_bounty_tier: String = ""
var board_last_seen_times_slept: int = 0
var accepted_delivery_id: String = ""
var accepted_delivery_baseline: Dictionary = {}
var delivery_failed: bool = false
var delivery_last_seen_times_slept: int = 0
var social_talked: Dictionary = {}
var entity_first_use: Dictionary = {}
var light_active := false
var well_fed := false
var pending_meal: Dictionary = {}
var frozen_cells: Dictionary = {}
var sneaking := false
var hotbar_loadout: Array[String] = []
var warded_encounters: Dictionary = {}
var companion: String = ""
## "animated" (fades at sleep) or "tamed" (persists sleep) -- one source-keyed
## branch at the sleep clear is the ONLY behavioral difference (GH#156).
var companion_source: String = ""
var rng := RandomNumberGenerator.new()

var _event_sink: Callable
var _combat_config: Dictionary = {}
var _maps: Dictionary = {}
var _map_blocked: Dictionary = {}
var _pending_encounter := ""
var _quest_progress: Dictionary = {}
var _items: Dictionary = {}
var _phase_config: Dictionary = {}
var _dialogue_conversation_id := ""
var _run_seed: int = 0
var _economy: WIEconomy
var _social: WISocial
var _field_skills: WIFieldSkills
var _interactions: WIInteractions
var _sleep_beat: WISleepBeat


func _init(scene_config: Dictionary, skill_config: Dictionary, event_sink: Callable, rng_seed: int = 0, combat_config: Dictionary = {}, phase_config: Dictionary = {}, creation_config: Dictionary = {}) -> void:
	_event_sink = event_sink
	_run_seed = rng_seed
	_economy = WIEconomy.new(event_sink, pickup, _set_gold)
	_social = WISocial.new(event_sink, accomplishment_count, record_accomplishment, find_entity)
	_field_skills = WIFieldSkills.new(event_sink, skills, _break_sneak, _toggle_sneak, _mark_skill_used, record_accomplishment, remove_entity, use_skill, _set_light_active, _blink_field, _ward_field, _animate_field)
	_interactions = WIInteractions.new(event_sink, _accomplishment_gate_met, record_accomplishment, _break_sneak, _talk_pool_line, start_dialogue, sleep, _interact_board, _interact_delivery_board, _interact_portal_menu, transition, _current_map_name, _resolve_skill_use_effect, _holds_weapon_family, known_skills, _apply_gold_effect, use_skill, _encounter_gate_met, start_combat, pickup)
	_sleep_beat = WISleepBeat.new(event_sink, record_accomplishment, accomplishment_count, known_skills, _class_display_name, _enriched_offer, _set_pending_consolidation, _bank_reached_two_classes_if_earned, _resolve_evolutions, _quests_completed_count, start_quest, _grow_resonance, skills)
	rng.seed = rng_seed
	for s: Dictionary in skill_config.get(WIKeys.SKILLS, []):
		skills[String(s[WIKeys.ID])] = s
	var p: Dictionary = scene_config["player"]
	player_cell = Vector2i(int(p[WIKeys.CELL][0]), int(p[WIKeys.CELL][1]))
	pc_name = _sanitize_pc_name(String(creation_config.get("pc_name", p.get(WIKeys.DISPLAY_NAME, "Traveler"))))
	pc_race = _sanitize_pc_race(String(creation_config.get("pc_race", "human")))
	pc_gender = _sanitize_pc_gender(String(creation_config.get("pc_gender", "m")))
	_combat_config = combat_config
	_phase_config = phase_config
	for it: Dictionary in (combat_config.get("items", {}) as Dictionary).get("items", []):
		_items[String(it[WIKeys.ID])] = it
	classes = (scene_config["player"].get("classes", {}) as Dictionary).duplicate(true)
	for sk: Variant in p.get(WIKeys.SKILLS, []):
		player_skills.append(String(sk))
	for it: Variant in p.get("inventory", []):
		inventory.append(String(it))
	var eq_raw: Dictionary = p.get("equipped", {})
	equipped = {
		WIKeys.WEAPON: String(eq_raw.get(WIKeys.WEAPON, "")),
		"armor": String(eq_raw.get("armor", "")),
		"accessory_1": String(eq_raw.get("accessory_1", "")),
		"accessory_2": String(eq_raw.get("accessory_2", "")),
		"accessory_3": String(eq_raw.get("accessory_3", "")),
	}
	for map_id: String in scene_config["maps"]:
		var m: Dictionary = scene_config["maps"][map_id]
		var ents := {}
		for e: Dictionary in m.get("entities", []):
			var ent: Dictionary = e.duplicate(true)
			ent[WIKeys.CELL] = Vector2i(int(e[WIKeys.CELL][0]), int(e[WIKeys.CELL][1]))
			ents[String(e[WIKeys.ID])] = ent
		var blocked := {}
		for cell: Array in m.get("blocked", []):
			blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
		for raw_seg: Variant in (m.get("walls", {}) as Dictionary).get("segments", []):
			if raw_seg is Dictionary:
				for seg_cell: Vector2i in segment_cells(raw_seg as Dictionary):
					blocked[seg_cell] = true
		var freezable := {}
		for cell: Array in m.get("freezable", []):
			var fc := Vector2i(int(cell[0]), int(cell[1]))
			freezable[fc] = true
			blocked[fc] = true
		_maps[map_id] = {
			"grid": Vector2i(int(m["grid"]["width"]), int(m["grid"]["height"])),
			"entities": ents,
			"blocked": blocked,
			"freezable": freezable,
			"arrival_toasts": m.get("arrival_toasts", []),
		}
	_bind_map(String(scene_config["start_map"]))
	_emit(WIEvents.SIM_INITIALIZED, {"seed": rng_seed})


static func _sanitize_pc_name(raw: String) -> String:
	var s := raw.strip_edges()
	if s.length() > PC_NAME_MAX:
		s = s.substr(0, PC_NAME_MAX).strip_edges()
	return s if s != "" else "Traveler"


static func _sanitize_pc_race(raw: String) -> String:
	return raw if raw in PC_RACES else "human"


static func _sanitize_pc_gender(raw: String) -> String:
	return raw if raw in PC_GENDERS else "m"


func pc_sprite_variant() -> String:
	return "pc_%s_%s" % [pc_race, pc_gender]


func _current_map_name() -> String:
	return current_map


func _bind_map(map_id: String) -> void:
	current_map = map_id
	grid_size = _maps[map_id]["grid"]
	entities = _maps[map_id]["entities"]
	_map_blocked = _maps[map_id]["blocked"]
	blocked_cells = _map_blocked


func bind_map_silent(map_id: String, cell: Vector2i) -> void:
	_bind_map(map_id)
	player_cell = cell


func has_map(map_id: String) -> bool:
	return _maps.has(map_id)


func transition(to_map: String, to_cell: Vector2i) -> void:
	_bind_map(to_map)
	player_cell = to_cell
	_emit(WIEvents.MAP_CHANGED, {"map": to_map, "cell": [to_cell.x, to_cell.y]})
	_emit_arrival_toast(to_map)


## #148 Tier 3: map-level re-orientation on arrival. Mirrors the portal
## arrival_toast emit (_travel_to_portal below) but reads a map's OWN
## `arrival_toasts` array (schema: [{requires:{counter:n}, hide_when:{counter:n},
## text:...}]). First SATISFIED entry wins (requires all met AND hide_when none
## met), at most one toast. Pure sim -- gate reads route through
## accomplishment_count, output through the event sink.
func _emit_arrival_toast(to_map: String) -> void:
	for entry: Variant in (_maps.get(to_map, {}) as Dictionary).get("arrival_toasts", []):
		if not (entry is Dictionary):
			continue
		if _arrival_gate_met((entry as Dictionary).get("requires", {}), (entry as Dictionary).get("hide_when", {})):
			_emit(WIEvents.TOAST, {"text": String((entry as Dictionary).get("text", ""))})
			return


func _arrival_gate_met(requires: Dictionary, hide_when: Dictionary) -> bool:
	for key: String in requires:
		if accomplishment_count(key) < int(requires[key]):
			return false
	for key: String in hide_when:
		if accomplishment_count(key) >= int(hide_when[key]):
			return false
	return true


func find_entity(id: String) -> Dictionary:
	for map_id: String in _maps:
		var map_entities: Dictionary = _maps[map_id]["entities"]
		if map_entities.has(id):
			return map_entities[id]
	return {}


static func segment_cells(seg: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from_raw: Array = seg.get("from", [])
	var to_raw: Array = seg.get("to", from_raw)
	if from_raw.size() < 2 or to_raw.size() < 2:
		return out
	var lo_x := mini(int(from_raw[0]), int(to_raw[0]))
	var hi_x := maxi(int(from_raw[0]), int(to_raw[0]))
	var lo_y := mini(int(from_raw[1]), int(to_raw[1]))
	var hi_y := maxi(int(from_raw[1]), int(to_raw[1]))
	for x in range(lo_x, hi_x + 1):
		for y in range(lo_y, hi_y + 1):
			out.append(Vector2i(x, y))
	return out


func is_cell_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return true
	if _map_blocked.has(cell) and not _is_frozen(cell):
		return true
	for ent: Dictionary in entities.values():
		if ent[WIKeys.CELL] == cell and entity_present(ent):
			return true
	return false


func _is_freezable(cell: Vector2i) -> bool:
	return (_maps.get(current_map, {}).get("freezable", {}) as Dictionary).has(cell)


func _is_frozen(cell: Vector2i) -> bool:
	return (frozen_cells.get(current_map, {}) as Dictionary).has(cell)


func frozen_cells_json() -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in frozen_cells:
		var cells: Array = []
		for cell: Vector2i in (frozen_cells[map_id] as Dictionary):
			cells.append([cell.x, cell.y])
		if not cells.is_empty():
			out[map_id] = cells
	return out


func set_frozen_cells_json(data: Dictionary) -> void:
	frozen_cells.clear()
	for map_id: Variant in data:
		var raw: Variant = data[map_id]
		if not (raw is Array):
			continue
		var inner: Dictionary = {}
		for pair: Variant in (raw as Array):
			if pair is Array and (pair as Array).size() == 2:
				inner[Vector2i(int(pair[0]), int(pair[1]))] = true
		if not inner.is_empty():
			frozen_cells[String(map_id)] = inner


func entity_at(cell: Vector2i) -> Dictionary:
	for ent: Dictionary in entities.values():
		if ent[WIKeys.CELL] == cell and entity_present(ent):
			return ent
	return {}


func move_player(dir: Vector2i) -> bool:
	if dialogue != null:
		return false
	player_facing = _nearest_cardinal(dir)
	var target := player_cell + dir
	if _is_diagonal(dir) and (is_cell_blocked(player_cell + Vector2i(dir.x, 0)) or is_cell_blocked(player_cell + Vector2i(0, dir.y))):
		_emit(WIEvents.PLAYER_BLOCKED, {"cell": [target.x, target.y], "facing": [player_facing.x, player_facing.y]})
		return false
	if is_cell_blocked(target):
		_emit(WIEvents.PLAYER_BLOCKED, {"cell": [target.x, target.y], "facing": [player_facing.x, player_facing.y]})
		return false
	player_cell = target
	_emit(WIEvents.PLAYER_MOVED, {"cell": [target.x, target.y]})
	_tick_action()
	# Proximity follows real moves; restore/teleport never trigger it, while
	# _blink_field deliberately calls it after landing. Encounters bypass confirms.
	_check_trigger_radius()
	_check_delivery_arrival()
	return true


static func _is_diagonal(dir: Vector2i) -> bool:
	return dir.x != 0 and dir.y != 0


static func _nearest_cardinal(dir: Vector2i) -> Vector2i:
	if _is_diagonal(dir):
		return Vector2i(dir.x, 0)
	return dir


func _check_trigger_radius(skipped_ids: Array[String] = []) -> void:
	if combat != null or dialogue != null:
		return
	for ent: Dictionary in entities.values():
		if String(ent.get(WIKeys.KIND, "")) != "encounter":
			continue
		if not ent.has("trigger_radius"):
			continue
		if not _encounter_gate_met(ent):
			continue
		var ent_id := String(ent[WIKeys.ID])
		if dormant_encounters.has(ent_id) or skipped_ids.has(ent_id) or warded_encounters.has(ent_id):
			continue
		var ent_cell: Vector2i = ent[WIKeys.CELL]
		var dist := maxi(absi(player_cell.x - ent_cell.x), absi(player_cell.y - ent_cell.y))
		if dist > int(ent["trigger_radius"]) - _wild_affinity_reduction(ent):
			continue
		if sneaking:
			# Credit one danger per entity when its live phase/range gate is met.
			var danger_key := "danger:%s" % ent_id
			if not entity_first_use.has(danger_key):
				entity_first_use[danger_key] = true
				record_accomplishment("sneaked_past_danger")
			continue
		start_combat(ent_id)
		return


func _check_delivery_arrival() -> void:
	if combat != null or dialogue != null:
		return
	if accepted_delivery_id == "":
		return
	var delivery := _delivery_by_id(accepted_delivery_id)
	if delivery.is_empty():
		return
	var parcel: Dictionary = delivery.get("parcel", {})
	var parcel_id := String(parcel.get("item_id", ""))
	if parcel_id == "" or not inventory.has(parcel_id):
		return
	var dest: Dictionary = delivery.get("destination", {})
	if current_map != String(dest.get("map", "")):
		return
	var raw_cell: Variant = dest.get("cell")
	var target_cell := Vector2i(int(raw_cell[0]), int(raw_cell[1])) if raw_cell is Array and raw_cell.size() == 2 else Vector2i(-9999, -9999)
	var anchor := String(dest.get("anchor_entity", ""))
	if anchor != "" and entities.has(anchor):
		target_cell = entities[anchor][WIKeys.CELL]
	var dist := maxi(absi(player_cell.x - target_cell.x), absi(player_cell.y - target_cell.y))
	if dist > 1:
		return
	record_accomplishment("delivered_%s" % accepted_delivery_id)
	record_accomplishment("completed_delivery")
	remove_item(parcel_id, accepted_delivery_id)
	_emit(WIEvents.TOAST, {"text": "Delivered: %s." % String(parcel.get("display_name", parcel_id))})


func interact() -> Dictionary:
	_tick_action()
	return _interactions.dispatch(entity_at(player_cell + player_facing), social_talked, entity_first_use, container_state)


func _resolve_skill_use_effect(effect: Dictionary) -> Dictionary:
	var resolved := effect.duplicate(true)
	for raw: Variant in effect.get("variants", []):
		if not (raw is Dictionary):
			continue
		var variant := raw as Dictionary
		if not _accomplishment_gate_met(variant.get("when", {}) as Dictionary):
			continue
		for key: String in variant:
			if key != "when":
				resolved[key] = variant[key]
	return resolved


func use_skill(skill_id: String, target_id: String) -> Dictionary:
	var target: Dictionary = entities.get(target_id, {})
	if not known_skills().has(skill_id):
		_emit(WIEvents.SKILL_UNKNOWN, {"skill": skill_id})
		var locked_toast := String(target.get("locked_toast", ""))
		if locked_toast == "":
			var is_door_shaped := String(target.get(WIKeys.KIND, "")) == "door" or target.has("door_when")
			locked_toast = "It doesn't budge." if is_door_shaped else "You don't know how to do that yet."
		_emit(WIEvents.TOAST, {"text": locked_toast})
		return {}
	if target.is_empty() or not target.has("on_skill_use"):
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": target_id})
		return {}
	# STRING | ARRAY CONTRACT (Wave D-1, #155): a bench prop's `requires_item` gate
	# and its `on_skill_use.remove_item` consume both accept either a single id
	# (String) or a list of ids (Array) -- mirrors the `on_victory`/`inherits`
	# String|Array idiom already used in this file. The gate is ALL-OR-NOTHING:
	# EVERY listed item must be in the pack, or the item-hint fires and NOTHING is
	# consumed (the gate loop returns before any effect resolves). This is the
	# component-consuming-recipe seam ([True Synthesis] eats solvent_phial +
	# mineral_salts). It is a bench-craft-only path -- combat never routes through
	# use_skill(), so the combat sim is untouched and sim_combat_batch.gd stays
	# byte-identical. SCOPE: this String|Array contract covers the BENCH seam only;
	# the dialogue-effect remove_item path (see _apply_dialogue_effects) remains
	# String-only by design.
	var req_items: Array = _as_item_list(target.get("requires_item", ""))
	for req_item: String in req_items:
		if not inventory.has(req_item):
			var item_hint := String(target.get("item_hint_toast", "Bare hands won't do it. Something in your pack might."))
			_emit(WIEvents.TOAST, {"text": item_hint})
			return {"item_hint": req_item}
	# GH#156 review M1: once_per_waking is OPT-IN here exactly as in interact()
	# and SHARES interact's serve: key -- one careful visit per waking TOTAL
	# (a soothe burns the mend and vice versa). Bench props never set the flag:
	# unbounded bench casts are the alchemist curve's DESIGN (trader-shaped,
	# grind-priced), so the gate must never become a default.
	if bool(target.get("once_per_waking", false)):
		var waking_key := "serve:%s" % target_id
		if entity_first_use.has(waking_key):
			_emit(WIEvents.TOAST, {"text": String(target.get("once_per_waking_toast", "Nothing more to carry out right now. Come back another day."))})
			return {"once_per_waking_spent": true}
		entity_first_use[waking_key] = true
	var effect: Dictionary = _resolve_skill_use_effect(target["on_skill_use"])
	# TRAP (#155 review M1): a CONSUMING recipe (both `item` and `remove_item`)
	# must refuse BEFORE any state changes when the output can't be picked up
	# (inventory never stacks, so a held duplicate blocks pickup) -- otherwise
	# the components vanish behind a success toast. All-or-nothing covers the
	# output slot, not just the ingredient gate. Produce-only props keep the
	# shipped bank-even-on-dup behavior (the basic_cooking precedent).
	if effect.has("item") and effect.has("remove_item") and inventory.has(String(effect["item"])):
		_emit(WIEvents.TOAST, {"text": "Your pack already holds one of those. The bench keeps its patience, and you keep your reagents."})
		return {"blocked_duplicate": String(effect["item"])}
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": target_id})
	_mark_skill_used(skill_id)
	record_accomplishment(String(effect["accomplishment"]))
	_emit(WIEvents.TOAST, {"text": String(effect["toast"])})
	if effect.has("gold"):
		# GH#202-adjacent (infinite-gold report): `gold_once_per_waking` caps
		# the PAYOUT without touching the counter/skill_used stream -- the
		# Helper curve is BUILT on same-day repeat cleans (work_loop pins
		# cleaned_the_inn 2 then 4), so gating the whole prop breaks a
		# shipped progression. Chore fiction: the work repeats, the tip
		# does not.
		if bool(target.get("gold_once_per_waking", false)):
			var gold_key := "gold:%s" % target_id
			if not entity_first_use.has(gold_key):
				entity_first_use[gold_key] = true
				_apply_gold_effect(int(effect["gold"]), target_id)
		else:
			_apply_gold_effect(int(effect["gold"]), target_id)
	if effect.has("item"):
		pickup(String(effect["item"]), target_id)
	if effect.has("remove_item"):
		for rem_item: String in _as_item_list(effect["remove_item"]):
			remove_item(rem_item, target_id)
	return effect


func _as_item_list(raw: Variant) -> Array:
	# String | Array -> Array[String], dropping the empty-string sentinel so a prop
	# with no `requires_item`/`remove_item` yields an empty (no-op) list.
	if raw is Array:
		var out: Array = []
		for entry: Variant in raw:
			out.append(String(entry))
		return out
	var single := String(raw)
	return [] if single == "" else [single]


func use_skill_field(skill_id: String) -> Dictionary:
	_tick_action()
	var known := known_skills().has(skill_id)
	var target := entity_at(player_cell + player_facing)
	if skill_id == "observe" and not target.is_empty() and (target.get("visual_states", []) as Array).any(func(s: Variant) -> bool: return s is Dictionary and (s as Dictionary).has("observe")):
		target = target.duplicate(true)
		target["observe"] = _resolve_observe_text(target)
	var faced_cell := player_cell + player_facing
	var is_freezable := _is_freezable(faced_cell)
	return _field_skills.dispatch(skill_id, known, target, faced_cell, current_map, frozen_cells, entity_first_use, is_freezable)


## Cardinal-only clear-line scan. Freezable cells are water leverage: blink
## may cross them but never land on them. Every other blocked cell is a wall
## and stops the ray; map edges stop it too. This wall-vs-water distinction
## is load-bearing overlap with [Snap Freeze].
func _blink_field(skill_id: String, skill: Dictionary) -> Dictionary:
	# Blink deliberately does not call _break_sneak: movement, not casting.
	var start := player_cell
	var crossed: Array[Vector2i] = []
	var landing: Variant = null
	for step: int in range(1, maxi(0, int(skill.get("blink_range", 0))) + 1):
		var cell := start + player_facing * step
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
			break
		if _is_freezable(cell):
			crossed.append(cell)
			continue
		if is_cell_blocked(cell):
			break
		crossed.append(cell)
		landing = cell
	if landing == null:
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
		_emit(WIEvents.TOAST, {"text": "No clear landing lies ahead."})
		return {}
	var destination := landing as Vector2i
	var landing_index := crossed.find(destination)
	crossed.resize(landing_index + 1)
	player_cell = destination
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
	_mark_skill_used(skill_id)
	_emit(WIEvents.PLAYER_TELEPORTED, {
		"skill": skill_id,
		"from": [start.x, start.y],
		"to": [destination.x, destination.y],
		"cell": [destination.x, destination.y],
	})
	var bypassed := _blink_bypassed_encounters(start, crossed, destination)
	_check_trigger_radius(bypassed)
	_check_delivery_arrival()
	return {"teleported": [destination.x, destination.y]}


func _wild_affinity_reduction(ent: Dictionary) -> int:
	# GH#156 [Wild Affinity] (-1) / [Peace of the Wild] (-2, supersedes):
	# beast-kind (`beast: true`) ambushes give a practiced handler more room.
	# AMBUSH CHECK ONLY -- ward targeting and blink-bypass credit keep the
	# authored radius, or warding gets harder as the tamer levels.
	# DELIBERATE (review M4): the sneak danger-credit branch sits behind this
	# same check, so an affinity holder banks no sneaked_past_danger from
	# beast ambushes -- never in danger, never credited.
	# AUTHORING NOTE (review M3): all shipped beast ambushes are radius 1, so
	# -1 already fully suppresses them; -2 only matters for radius >= 2
	# encounters -- give future beast ambushes radius 2+ if the druid upgrade
	# should read on them.
	if not bool(ent.get("beast", false)):
		return 0
	var known := known_skills()
	if known.has("peace_of_the_wild"):
		return 2
	if known.has("wild_affinity"):
		return 1
	return 0


func _blink_bypassed_encounters(start: Vector2i, crossed: Array[Vector2i], destination: Vector2i) -> Array[String]:
	var bypassed: Array[String] = []
	for ent: Dictionary in entities.values():
		if String(ent.get(WIKeys.KIND, "")) != "encounter" or not ent.has("trigger_radius"):
			continue
		var ent_id := String(ent[WIKeys.ID])
		if dormant_encounters.has(ent_id) or warded_encounters.has(ent_id) or not _encounter_gate_met(ent):
			continue
		var ent_cell: Vector2i = ent[WIKeys.CELL]
		var radius := int(ent["trigger_radius"])
		if _cell_in_radius(destination, ent_cell, radius):
			continue
		var touched := _cell_in_radius(start, ent_cell, radius)
		if not touched:
			for cell: Vector2i in crossed:
				if _cell_in_radius(cell, ent_cell, radius):
					touched = true
					break
		if not touched:
			continue
		bypassed.append(ent_id)
		# Sneak/blink share danger:<id>; one waking banks one counter per danger.
		var danger_key := "danger:%s" % ent_id
		if not entity_first_use.has(danger_key):
			entity_first_use[danger_key] = true
			record_accomplishment("blinked_past_danger")
	return bypassed


static func _cell_in_radius(cell: Vector2i, center: Vector2i, radius: int) -> bool:
	return maxi(absi(cell.x - center.x), absi(cell.y - center.y)) <= radius


func _ward_field(skill_id: String, skill: Dictionary, faced_cell: Vector2i) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var already_warded := false
	for ent: Dictionary in entities.values():
		if String(ent.get(WIKeys.KIND, "")) != "encounter" or not ent.has("trigger_radius"):
			continue
		var ent_id := String(ent[WIKeys.ID])
		if dormant_encounters.has(ent_id) or not _encounter_gate_met(ent):
			continue
		var ent_cell: Vector2i = ent[WIKeys.CELL]
		if warded_encounters.has(ent_id):
			if _cell_in_radius(faced_cell, ent_cell, int(ent["trigger_radius"])):
				already_warded = true
			continue
		if not _cell_in_radius(faced_cell, ent_cell, int(ent["trigger_radius"])):
			continue
		candidates.append({"id": ent_id, "distance": maxi(absi(faced_cell.x - ent_cell.x), absi(faced_cell.y - ent_cell.y))})
	if candidates.is_empty():
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
		var refusal := "The charm already holds here." if already_warded else "No hidden danger answers the charm."
		_emit(WIEvents.TOAST, {"text": refusal})
		return {}
	# TRAP: nearest wins; equal distance resolves by id, independent of Dictionary order.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["distance"]) < int(b["distance"]) \
			or (int(a["distance"]) == int(b["distance"]) and String(a["id"]) < String(b["id"]))
	)
	var encounter_id := String(candidates[0]["id"])
	var sleeps := maxi(1, int(skill.get("ward_sleeps", 1)))
	warded_encounters[encounter_id] = {"sleeps": sleeps, "map": current_map, "cell": [faced_cell.x, faced_cell.y]}
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": encounter_id})
	_mark_skill_used(skill_id)
	var ward_key := "ward:%s" % encounter_id
	if not entity_first_use.has(ward_key):
		entity_first_use[ward_key] = true
		record_accomplishment("warded_danger")
		record_accomplishment("witch_craft_used")
	_emit(WIEvents.WARD_PLACED, {"id": encounter_id, "map": current_map, "cell": [faced_cell.x, faced_cell.y], "sleeps": sleeps})
	_emit(WIEvents.TOAST, {"text": "The charm settles. Whatever waits there cannot cross it."})
	return {"warded": encounter_id}


func _animate_field(skill_id: String, skill: Dictionary, target: Dictionary) -> Dictionary:
	# GH#156 generalization: the prop declares its companion via
	# `companion_source: {companion_id, skill, taken_toast}` -- the old
	# hardcoded bone-pile id list is retired (Wave B review L1). The SKILL
	# decides the source kind: `animates` -> "animated" (fades at sleep),
	# `tames` -> "tamed" (persists sleep). Single companion slot: a new bond
	# releases the old one with a toast (canon: tamers bond few animals).
	var target_id := String(target.get(WIKeys.ID, ""))
	var kind := "tamed" if bool(skill.get("tames", false)) else "animated"
	var source: Dictionary = target.get("companion_source", {})
	# Match on source KIND, not skill id: any `animates` skill raises an
	# "animated" source, any `tames` skill bonds a "tamed" one. Pairs prop
	# families to skill families without pinning data to one skill id.
	if source.is_empty() or String(source.get("kind", "")) != kind:
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": target_id})
		var refusal := "No bones here will answer." if kind == "animated" else String(target.get("tame_refusal_toast", "Nothing here will take the bond."))
		_emit(WIEvents.TOAST, {"text": refusal})
		return {}
	if companion != "":
		if companion == String(source.get("companion_id", "")):
			_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": target_id})
			_emit(WIEvents.TOAST, {"text": "They already follow you."})
			return {}
		_clear_companion("released")
		_emit(WIEvents.TOAST, {"text": "Your old companion slips away; one bond at a time is all anyone holds."})
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": target_id})
	_mark_skill_used(skill_id)
	if kind == "tamed":
		record_accomplishment("tended_beasts")
	remove_entity(target_id)
	companion = String(source["companion_id"])
	companion_source = kind
	_emit(WIEvents.COMPANION_CHANGED, {"id": companion, "active": true, "reason": kind})
	_emit(WIEvents.TOAST, {"text": String(source.get("taken_toast", "The bones rise and fall into step behind you."))})
	return {"animated": target_id, "companion": companion, "source": kind}


func _clear_companion(reason: String) -> void:
	if companion == "":
		return
	var old_id := companion
	companion = ""
	companion_source = ""
	_emit(WIEvents.COMPANION_CHANGED, {"id": old_id, "active": false, "reason": reason})


func _resolve_observe_text(ent: Dictionary) -> String:
	# CONTRACT: any visual_states observe override needs a base observe;
	# otherwise Observe returns empty before its gate is met.
	var text := String(ent.get("observe", ""))
	for raw: Variant in ent.get("visual_states", []):
		if not (raw is Dictionary):
			continue
		var state := raw as Dictionary
		if not state.has("observe"):
			continue
		var when: Dictionary = state.get("when", {})
		if when.has("counter") and accomplishment_count(String(when["counter"])) >= int(when.get("at", 1)):
			text = String(state["observe"])
	return text


func _set_light_active(active: bool) -> void:
	light_active = active


func _set_gold(new_gold: int) -> void:
	gold = new_gold


func _toggle_sneak(skill_id: String) -> Dictionary:
	sneaking = not sneaking
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
	_mark_skill_used(skill_id)
	if sneaking:
		_emit(WIEvents.SNEAK_STARTED, {})
		_emit(WIEvents.TOAST, {"text": "You soften your step."})
	else:
		_emit(WIEvents.SNEAK_ENDED, {})
		_emit(WIEvents.TOAST, {"text": "You straighten up."})
	return {"sneaking": sneaking}


func _break_sneak() -> void:
	if not sneaking:
		return
	sneaking = false
	_emit(WIEvents.SNEAK_ENDED, {})
	_emit(WIEvents.TOAST, {"text": "You straighten up."})


func _talk_pool_line(target: Dictionary) -> Dictionary:
	return _social.talk_pool_line(target, social_talked)


func _mark_skill_used(skill_id: String) -> void:
	if skill_id == "" or used_skills.has(skill_id):
		return
	used_skills.append(skill_id)


func record_accomplishment(id: String, amount: int = 1) -> void:
	accomplishments[id] = int(accomplishments.get(id, 0)) + amount
	_emit(WIEvents.ACCOMPLISHMENT_RECORDED, {"id": id, "count": accomplishments[id]})
	_check_quests()


func accomplishment_count(id: String) -> int:
	return int(accomplishments.get(id, 0))


func earn_gold(amount: int, source: String) -> void:
	gold = _economy.earn(gold, amount, source)


func spend_gold(amount: int, source: String) -> bool:
	var result := _economy.spend(gold, amount, source)
	gold = int(result["gold"])
	return bool(result["ok"])


func _apply_gold_effect(amount: int, source: String) -> void:
	gold = _economy.apply_gold_effect(gold, amount, source)
	if amount <= -5:
		record_accomplishment("deliberate_commerce", 1)


## present_when = STRUCTURAL absence: is_cell_blocked/entity_at/_build_entities
## all skip the entity. NOT visual_states `hidden` (render-only — still blocks,
## still entity_at, still counts in ui_entities_rendered).
## Same-map banks are SAFE for present_when since world.gd's
## _reconcile_entity_presence began running on ACCOMPLISHMENT_RECORDED (the
## older different-map-only CONSTRAINT predated that reconciler; GH#150's
## rift-vermin gate is the first deliberate same-map consumer).
func entity_present(ent: Dictionary) -> bool:
	if not ent.has("present_when"):
		return true
	return _present_gate_met(ent["present_when"] as Dictionary)


func _present_gate_met(when: Dictionary) -> bool:
	if when.is_empty():
		return true
	if when.has("phase"):
		return (when["phase"] as Array).has(phase())
	if when.has("requires"):
		return _accomplishment_gate_met(when["requires"] as Dictionary)
	return true


func _encounter_gate_met(ent: Dictionary) -> bool:
	var when: Dictionary = ent.get("encounter_when", {})
	if when.is_empty():
		return true
	if when.has("phase"):
		return (when["phase"] as Array).has(phase())
	if when.has("requires"):
		return _accomplishment_gate_met(when["requires"] as Dictionary)
	return true


func _accomplishment_gate_met(req: Dictionary) -> bool:
	for key: String in req:
		if accomplishment_count(key) < int(req[key]):
			return false
	return true


func _skill_display_name(skill_id: String) -> String:
	var entry: Dictionary = skills.get(skill_id, {})
	var label := String(entry.get("display_name", ""))
	if label != "":
		return label
	return "[%s]" % skill_id.capitalize()


func known_skills() -> Array:
	var out: Array = player_skills.duplicate()
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for sk: Variant in WIProgression.granted_skills(classes, _combat_config["classes"], generalist_classes):
			if not out.has(String(sk)):
				out.append(String(sk))
	return out


static func apply_loadout(candidates: Array, loadout: Array) -> Array:
	if loadout.is_empty():
		return candidates.duplicate()
	var candidate_set: Dictionary = {}
	for raw: Variant in candidates:
		candidate_set[String(raw)] = true
	var out: Array = []
	for raw: Variant in loadout:
		var id := String(raw)
		if candidate_set.has(id):
			out.append(id)
	return out


func field_hotbar_loadout() -> Array:
	var candidates: Array = []
	for raw: Variant in known_skills():
		var id := String(raw)
		if bool((skills.get(id, {}) as Dictionary).get("field", false)):
			candidates.append(id)
	var skill_loadout: Array = []
	for raw: Variant in hotbar_loadout:
		if not String(raw).begins_with("item:"):
			skill_loadout.append(raw)
	return WIGame.apply_loadout(candidates, skill_loadout)


func loadout_toggle(skill_id: String) -> void:
	var already := hotbar_loadout.has(skill_id)
	if already:
		hotbar_loadout.erase(skill_id)
		if sneaking and bool(skills.get(skill_id, {}).get("sneaks", false)):
			_break_sneak()
	else:
		hotbar_loadout.append(skill_id)
	_emit(WIEvents.LOADOUT_CHANGED, {"skill": skill_id, "assigned": not already, "loadout": hotbar_loadout.duplicate()})


func _build_dialogue_ctx() -> Dictionary:
	# Dialogue snapshots phase; phase cannot change while a conversation is active.
	var names: Dictionary = {}
	for sk_id: String in skills:
		names[sk_id] = String(skills[sk_id].get(WIKeys.DISPLAY_NAME, sk_id))
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for cls: Dictionary in _combat_config["classes"]["classes"]:
			names[String(cls[WIKeys.ID])] = String(cls[WIKeys.DISPLAY_NAME])
	return {WIKeys.SKILLS: known_skills(), "classes": classes.duplicate(true), "accomplishments": accomplishments.duplicate(true), "names": names, "gold": gold, "items": _items, "inventory": inventory.duplicate(), "board_accepted": accepted_bounty_id != "", "delivery_accepted": accepted_delivery_id != "", "entity_first_use": entity_first_use.duplicate(true), "pc_race": pc_race, "phase": phase()}


func start_dialogue(conversation_id: String, source_entity_id: String) -> bool:
	if dialogue != null or combat != null:
		return false
	var graphs: Dictionary = _combat_config.get("dialogue", {})
	if not graphs.has(conversation_id):
		return false
	_dialogue_conversation_id = conversation_id
	_emit(WIEvents.DIALOGUE_STARTED, {"conversation": conversation_id, "entity": source_entity_id})
	dialogue = WIDialogue.new(graphs[conversation_id], _build_dialogue_ctx(), _event_sink)
	dialogue.begin()
	return true


func _begin_code_dialogue(graph: Dictionary, conversation_label: String, source_entity_id: String) -> bool:
	if dialogue != null or combat != null:
		return false
	_dialogue_conversation_id = conversation_label
	_emit(WIEvents.DIALOGUE_STARTED, {"conversation": conversation_label, "entity": source_entity_id})
	dialogue = WIDialogue.new(graph, _build_dialogue_ctx(), _event_sink)
	dialogue.begin()
	return true


func dialogue_choose(index: int) -> bool:
	if dialogue == null:
		return false
	var result: Dictionary = dialogue.choose(index)
	if result.is_empty():
		return false
	_emit(WIEvents.DIALOGUE_CHOICE, {"index": index})
	var walker := dialogue
	if bool(result["ended"]):
		dialogue = null
	var pending_combat := ""
	var pending_board_action := ""
	var pending_travel := ""
	var pending_sell_vendor := ""
	for effect: Dictionary in result["effects"]:
		if effect.has("start_combat"):
			# Snapshot precedes option effects; synchronous COMBAT_STARTED consumes it,
			# or DIALOGUE_EFFECT_FAILED disarms the snapshot guard.
			_emit(WIEvents.PRE_COMBAT_CHOICE, {"encounter": String(effect["start_combat"])})
			break
	for effect: Dictionary in result["effects"]:
		if effect.has("accomplishment"):
			record_accomplishment(String(effect["accomplishment"]))
		elif effect.has("quest"):
			start_quest(String(effect["quest"]))
		elif effect.has("remove_entity"):
			remove_entity(String(effect["remove_entity"]))
		elif effect.has("item"):
			pickup(String(effect["item"]), _dialogue_conversation_id)
		elif effect.has("gold"):
			_apply_gold_effect(int(effect["gold"]), _dialogue_conversation_id)
		elif effect.has("bank_first_use"):
			entity_first_use[String(effect["bank_first_use"])] = true
		elif effect.has("remove_item"):
			# GH#142: a dialogue swap implies consent -- unequip first, or an
			# EQUIPPED base hits remove_item's safety refusal and the player
			# pays the fee, keeps the base, AND gains the variant (exploit).
			# The bench/use_skill path keeps the plain guard: benches never
			# consume equipment.
			var removed_id := String(effect["remove_item"])
			for slot_name: String in equipped:
				if String(equipped[slot_name]) == removed_id:
					equipped[slot_name] = ""
			remove_item(removed_id, _dialogue_conversation_id)
		elif effect.has("well_fed"):
			well_fed = bool(effect["well_fed"])
		elif effect.has("start_combat"):
			pending_combat = String(effect["start_combat"])
		elif effect.has("travel_to"):
			pending_travel = String(effect["travel_to"])
		elif effect.has("accept_bounty"):
			accept_bounty(String(effect["accept_bounty"]))
		elif effect.has("accept_delivery"):
			accept_delivery(String(effect["accept_delivery"]))
		elif effect.has("sell_item"):
			sell_item(String(effect["sell_item"]))
		elif effect.has("open_board_picker"):
			pending_board_action = "picker"
		elif effect.has("open_board_turnin"):
			pending_board_action = "turnin"
		elif effect.has("open_board_abandon"):
			pending_board_action = "abandon"
		elif effect.has("open_delivery_picker"):
			pending_board_action = "delivery_picker"
		elif effect.has("open_delivery_turnin"):
			pending_board_action = "delivery_turnin"
		elif effect.has("open_sell_picker"):
			pending_board_action = "sell_picker"
			pending_sell_vendor = String(effect["open_sell_picker"]) if effect["open_sell_picker"] is String else "krshia"
	if not bool(result["ended"]):
		walker.set_ctx(_build_dialogue_ctx())
		walker.advance(String(result["next"]))
	if pending_combat != "":
		if not start_combat(pending_combat):
			_emit(WIEvents.DIALOGUE_EFFECT_FAILED, {"effect": "start_combat", "id": pending_combat})
	if pending_board_action == "picker":
		_open_board_picker_dialogue()
	elif pending_board_action == "turnin":
		_open_board_turnin_dialogue()
	elif pending_board_action == "abandon":
		_open_board_abandon_dialogue()
	elif pending_board_action == "delivery_picker":
		_open_delivery_picker_dialogue()
	elif pending_board_action == "delivery_turnin":
		_open_delivery_turnin_dialogue()
	elif pending_board_action == "sell_picker":
		_open_sell_dialogue(pending_sell_vendor)
	if pending_travel != "":
		_travel_to_portal(pending_travel)
	return true


func _bounty_pool() -> Array:
	return (_combat_config.get("bounties", {}) as Dictionary).get("bounties", [])


func _bounty_by_id(id: String) -> Dictionary:
	for bounty: Dictionary in _bounty_pool():
		if String(bounty["id"]) == id:
			return bounty
	return {}


func player_rank() -> String:
	# Issue #163: rank derives from effective_power at the interaction (read-only,
	# no new state). Empty catalog (bare unit contexts) degrades to bronze.
	var catalog: Dictionary = _combat_config.get("classes", {})
	if catalog.is_empty():
		return "bronze"
	return WIProgression.power_rank(classes, catalog)


func board_bounties() -> Array:
	var remaining: Array = []
	for bounty: Dictionary in _bounty_pool():
		var one_shot := String(bounty.get("condition_mode", "delta")) == "absolute"
		if one_shot and accomplishment_count("completed_bounty_%s" % String(bounty[WIKeys.ID])) >= 1:
			continue
		if not WIBounties.requires_met(bounty, Callable(self, "accomplishment_count")):
			continue
		remaining.append(bounty)
	# Rank resolves at POST time -- the slate carries the player's own tier's
	# condition/gold/copy; accept then LOCKS whatever tier was posted.
	var rank := player_rank()
	var resolved: Array = []
	for bounty: Dictionary in WIBounties.active_slate(remaining, times_slept):
		resolved.append(WIBounties.resolve_tier(bounty, rank))
	return resolved


func accept_bounty(id: String) -> void:
	if accepted_bounty_id != "":
		return
	var base := _bounty_by_id(id)
	if base.is_empty():
		return
	var bounty := WIBounties.resolve_tier(base, player_rank())
	if String(bounty.get("condition_mode", "delta")) == "absolute" and accomplishment_count("completed_bounty_%s" % id) >= 1:
		return
	accepted_bounty_id = id
	accepted_bounty_tier = String(bounty["rank"])
	if String(bounty.get("condition_mode", "delta")) == "absolute":
		accepted_bounty_baseline = {}
	else:
		var baseline: Dictionary = {}
		for key: String in (bounty.get("condition", {}) as Dictionary):
			baseline[key] = accomplishment_count(key)
		accepted_bounty_baseline = baseline
	record_accomplishment("accepted_bounty_%s" % id)


func accepted_bounty() -> Dictionary:
	# The accepted posting resolved at its LOCKED tier (never the current rank).
	if accepted_bounty_id == "":
		return {}
	var base := _bounty_by_id(accepted_bounty_id)
	if base.is_empty():
		return {}
	var tier := accepted_bounty_tier if accepted_bounty_tier != "" else "bronze"
	return WIBounties.resolve_tier(base, tier)


func _bounty_condition_met() -> bool:
	var bounty := accepted_bounty()
	if bounty.is_empty():
		return false
	return WIBounties.condition_met(bounty.get("condition", {}), accepted_bounty_baseline, Callable(self, "accomplishment_count"), String(bounty.get("condition_mode", "delta")))


func abandon_bounty() -> void:
	if accepted_bounty_id == "":
		return
	accepted_bounty_id = ""
	accepted_bounty_baseline = {}
	accepted_bounty_tier = ""


func turn_in_bounty() -> bool:
	if accepted_bounty_id == "" or not _bounty_condition_met():
		return false
	var bounty := accepted_bounty()
	var id := accepted_bounty_id
	earn_gold(int(bounty.get("gold", 0)), "bounty_%s" % id)
	record_accomplishment("completed_bounty_%s" % id)
	accepted_bounty_id = ""
	accepted_bounty_baseline = {}
	accepted_bounty_tier = ""
	return true


func _interact_board(target: Dictionary) -> Dictionary:
	record_accomplishment("read_the_board")
	var header := String(target["toast"])
	if accepted_bounty_id != "" and target.has("second_visit_toast"):
		header = String(target["second_visit_toast"])
	var lines: Array[String] = [header, ""]
	for bounty: Dictionary in board_bounties():
		lines.append(String(bounty["copy"]))
		lines.append("")
	for rumor: Dictionary in (target.get("board_rumors", []) as Array):
		lines.append(String(rumor["copy"]))
		lines.append("")
		record_accomplishment(String(rumor["banks_accomplishment"]))
	lines.append(String(target.get("observe", "")))
	var graph := {
		"start": "hub",
		"nodes": {
			"hub": {
				"speaker": String(target.get(WIKeys.DISPLAY_NAME, "The Request Board")),
				"text": "\n".join(lines),
				"options": [{"text": "Step back from the board.", "end": true}],
			},
		},
	}
	_begin_code_dialogue(graph, "the_request_board", String(target[WIKeys.ID]))
	return {"dialogue": true}


func _open_board_picker_dialogue() -> void:
	var slate := board_bounties()
	if times_slept != board_last_seen_times_slept:
		_emit(WIEvents.DIALOGUE_LINE, {"speaker": "Selys", "text": "New paper went up this morning. Old postings come down whether they're done or not. Ink's cheap, wall space isn't."})
	board_last_seen_times_slept = times_slept
	_begin_code_dialogue(WIBounties.build_picker_graph(slate), "board_picker", "selys")


func _open_board_turnin_dialogue() -> void:
	var met := turn_in_bounty()
	_begin_code_dialogue(WIBounties.build_turnin_graph(met), "board_turnin", "selys")


func _open_board_abandon_dialogue() -> void:
	abandon_bounty()
	_begin_code_dialogue(WIBounties.build_abandon_graph(), "board_abandon", "selys")


func _delivery_pool() -> Array:
	return (_combat_config.get("deliveries", {}) as Dictionary).get("deliveries", [])


func _delivery_by_id(id: String) -> Dictionary:
	for delivery: Dictionary in _delivery_pool():
		if String(delivery["id"]) == id:
			return delivery
	return {}


func delivery_board_deliveries() -> Array:
	var remaining: Array = []
	for delivery: Dictionary in _delivery_pool():
		if bool(delivery.get("standing", false)) or accomplishment_count("completed_delivery_%s" % String(delivery[WIKeys.ID])) < 1:
			remaining.append(delivery)
	return WIBounties.active_slate(remaining, times_slept)


func accept_delivery(id: String) -> void:
	if accepted_delivery_id != "":
		return
	var delivery := _delivery_by_id(id)
	if delivery.is_empty():
		return
	if not bool(delivery.get("standing", false)) and accomplishment_count("completed_delivery_%s" % id) >= 1:
		return
	accepted_delivery_id = id
	var baseline: Dictionary = {}
	for key: String in (delivery.get("condition", {}) as Dictionary):
		baseline[key] = accomplishment_count(key)
	accepted_delivery_baseline = baseline
	record_accomplishment("accepted_delivery_%s" % id)
	pickup(String((delivery.get("parcel", {}) as Dictionary).get("item_id", "")), id)


func _delivery_condition_met() -> bool:
	if accepted_delivery_id == "":
		return false
	var delivery := _delivery_by_id(accepted_delivery_id)
	if delivery.is_empty():
		return false
	return WIBounties.condition_met(delivery.get("condition", {}), accepted_delivery_baseline, Callable(self, "accomplishment_count"), String(delivery.get("condition_mode", "delta")))


func turn_in_delivery() -> bool:
	if accepted_delivery_id == "" or not _delivery_condition_met():
		return false
	var delivery := _delivery_by_id(accepted_delivery_id)
	var id := accepted_delivery_id
	earn_gold(int(delivery.get("gold", 0)), "delivery_%s" % id)
	record_accomplishment("completed_delivery_%s" % id)
	record_accomplishment("deliberate_commerce", 1)
	accepted_delivery_id = ""
	accepted_delivery_baseline = {}
	return true


func _interact_delivery_board(target: Dictionary) -> Dictionary:
	record_accomplishment("read_the_delivery_board")
	var header := String(target["toast"])
	if accepted_delivery_id != "" and target.has("second_visit_toast"):
		header = String(target["second_visit_toast"])
	var lines: Array[String] = [header, ""]
	for delivery: Dictionary in delivery_board_deliveries():
		lines.append(String(delivery["slip_copy"]))
		lines.append("")
	lines.append(String(target.get("observe", "")))
	var graph := {
		"start": "hub",
		"nodes": {
			"hub": {
				"speaker": String(target.get(WIKeys.DISPLAY_NAME, "The Delivery Board")),
				"text": "\n".join(lines),
				"options": [{"text": "Step back from the board.", "end": true}],
			},
		},
	}
	_begin_code_dialogue(graph, "the_delivery_board", String(target[WIKeys.ID]))
	return {"dialogue": true}


func _open_delivery_picker_dialogue() -> void:
	if delivery_failed:
		_emit(WIEvents.DIALOGUE_LINE, {"speaker": "Vess", "text": "Parcel came back on the night ledger. Happens. Happens ONCE, usually. Board's still live. Take another slip and run it like you mean it."})
		delivery_failed = false
	elif times_slept != delivery_last_seen_times_slept:
		_emit(WIEvents.DIALOGUE_LINE, {"speaker": "Vess", "text": "Board turned over while you slept. Grab a slip before somebody faster does."})
	delivery_last_seen_times_slept = times_slept
	_begin_code_dialogue(WIBounties.build_delivery_picker_graph(delivery_board_deliveries()), "delivery_picker", "vess")


func _open_delivery_turnin_dialogue() -> void:
	var met := turn_in_delivery()
	_begin_code_dialogue(WIBounties.build_delivery_turnin_graph(met), "delivery_turnin", "vess")


func _open_sell_dialogue(vendor_id: String) -> void:
	var records: Array = []
	for raw_id: Variant in sellable_items():
		var id := String(raw_id)
		var rec := item(id)
		records.append({"id": id, "name": String(rec.get("name", id)), "price": sell_price(int(rec.get(WIKeys.PRICE, 0)))})
	_begin_code_dialogue(WIShop.build_sell_graph(records, vendor_id), "%s_sell" % vendor_id, vendor_id)


func _portal_rows() -> Array:
	return (_combat_config.get("portals", {}) as Dictionary).get("portals", [])


func attuned_destinations() -> Array:
	return WIPortals.attuned_destinations(_portal_rows(), Callable(self, "accomplishment_count"), Callable(self, "has_map"))


func _interact_portal_menu() -> Dictionary:
	_begin_code_dialogue(WIPortals.build_portal_graph(attuned_destinations(), current_map), "portal_menu", "the_magical_door")
	return {"dialogue": true}


func _travel_to_portal(id: String) -> void:
	var dest := WIPortals.destination_by_id(_portal_rows(), id)
	if dest.is_empty():
		return
	if not has_map(String(dest.get("map", ""))):
		return
	transition(String(dest["map"]), Vector2i(int((dest[WIKeys.CELL] as Array)[0]), int((dest[WIKeys.CELL] as Array)[1])))
	var arrival_toast := String(dest.get("arrival_toast", ""))
	if arrival_toast != "":
		_emit(WIEvents.TOAST, {"text": arrival_toast})


func door_study_sleeps() -> int:
	return accomplishment_count("door_study_sleeps")


func second_door_study_sleeps() -> int:
	return accomplishment_count("second_door_study_sleeps")


func start_quest(id: String) -> void:
	if started_quests.has(id):
		return
	started_quests.append(id)
	_emit(WIEvents.QUEST_STARTED, {"id": id})
	var catalog: Dictionary = _combat_config.get("quests", {})
	if not catalog.is_empty():
		var now := WIQuests.evaluate(catalog, started_quests, accomplishments)
		if now.has(id):
			_quest_progress[id] = now[id]
	_emit(WIEvents.TOAST, {"text": "New quest: %s" % _quest_title(id)})


func _check_quests() -> void:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		return
	var now := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in now:
		var prev: Dictionary = _quest_progress.get(id, {"beat_index": 0, "completed": false})
		if int(now[id]["beat_index"]) > int(prev["beat_index"]) and not bool(now[id]["completed"]):
			_emit(WIEvents.QUEST_BEAT_COMPLETED, {"id": id, "beat": now[id]["beat_index"]})
			_emit(WIEvents.TOAST, {"text": "Quest updated: %s" % String(now[id]["beat_description"])})
		if bool(now[id]["completed"]) and not bool(prev["completed"]):
			_emit(WIEvents.QUEST_BEAT_COMPLETED, {"id": id, "beat": now[id]["beat_index"]})
			_emit(WIEvents.QUEST_COMPLETED, {"id": id})
			_emit(WIEvents.TOAST, {"text": "Quest complete: %s" % _quest_title(id)})
	_quest_progress = now


func reprime_quests() -> void:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		_quest_progress = {}
		return
	_quest_progress = WIQuests.evaluate(catalog, started_quests, accomplishments)


func quest_summary() -> Array:
	var catalog: Dictionary = _combat_config.get("quests", {})
	var out: Array = []
	var ev := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in started_quests:
		if not ev.has(id) or bool(ev[id]["completed"]):
			continue
		var title := _quest_title(id)
		var region := String(ev[id].get("region", ""))
		if region != "":
			title = "%s (%s)" % [title, region]
		out.append("%s — %s" % [title, String(ev[id]["beat_description"])])
	return out


func completed_quest_summary() -> Array:
	var catalog: Dictionary = _combat_config.get("quests", {})
	var out: Array = []
	var ev := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in started_quests:
		if not ev.has(id) or not bool(ev[id]["completed"]):
			continue
		var title := _quest_title(id)
		var region := String(ev[id].get("region", ""))
		if region != "":
			title = "%s (%s)" % [title, region]
		var path := String(ev[id].get("path", ""))
		if path != "":
			out.append("%s — %s" % [title, path])
		else:
			out.append("%s — Complete." % title)
	return out


func _quests_completed_count() -> int:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		return 0
	var ev := WIQuests.evaluate(catalog, started_quests, accomplishments)
	var n := 0
	for id: String in ev:
		if bool(ev[id]["completed"]):
			n += 1
	return n


func chronicle_facts() -> Dictionary:
	var held_classes: Array[Dictionary] = []
	var class_catalog: Dictionary = _combat_config.get("classes", {})
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		if not classes.has(id):
			continue
		var row: Dictionary = {
			"name": String(cls[WIKeys.DISPLAY_NAME]),
			"level": int(classes[id]),
		}
		held_classes.append(row)
	var facts: Dictionary = {
		"schema": 1,
		"name": _sanitize_pc_name(pc_name),
		"race": _sanitize_pc_race(pc_race).capitalize(),
		"classes": held_classes,
		"quests_completed": _quests_completed_count(),
		"victories": accomplishment_count("victories"),
		"sleeps": times_slept,
		"ending": _act_beat_text("seal_holds"),
	}
	return facts


func _act_beat_text(beat_id: String) -> String:
	var catalog: Dictionary = _combat_config.get("acts", {})
	for act: Dictionary in catalog.get("acts", []):
		for beat: Dictionary in act.get("beats", []):
			if String(beat.get(WIKeys.ID, "")) == beat_id:
				return String(beat.get("text", ""))
	return ""


func act_summary() -> Dictionary:
	var catalog: Dictionary = _combat_config.get("acts", {})
	if catalog.is_empty():
		return {}
	var ctx := {
		"classes_count": classes.size(),
		"quests_completed": _quests_completed_count(),
		"accomplishments": accomplishments,
	}
	return WIActs.evaluate(catalog, ctx)


func _quest_title(id: String) -> String:
	var catalog: Dictionary = _combat_config.get("quests", {})
	for quest: Dictionary in catalog.get("quests", []):
		if String(quest[WIKeys.ID]) == id:
			return String(quest.get("title", id))
	return id


func skills_journal() -> Array:
	var groups: Array = []
	if not player_skills.is_empty():
		groups.append({"heading": "Innate", "skills": _skill_entries(player_skills)})
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		var catalog: Array = _combat_config["classes"]["classes"]
		var catalog_by_id: Dictionary = {}
		for cls: Dictionary in catalog:
			catalog_by_id[String(cls[WIKeys.ID])] = cls
		for cls: Dictionary in catalog:
			var id := String(cls[WIKeys.ID])
			if not classes.has(id):
				continue
			var grants: Array = []
			_collect_class_grants(cls, int(classes[id]), catalog_by_id, grants, {id: true})
			if grants.is_empty():
				continue
			groups.append({"heading": String(cls.get(WIKeys.DISPLAY_NAME, id)), "skills": _skill_entries(grants)})
	return groups


func _collect_class_grants(cls: Dictionary, held: int, catalog_by_id: Dictionary, out: Array, visited: Dictionary) -> void:
	for lv: Dictionary in cls.get("levels", []):
		if int(lv["level"]) <= held:
			for sk: Variant in lv.get("grants", []):
				if not out.has(String(sk)):
					out.append(String(sk))
	var inherits_raw: Variant = cls.get("inherits")
	if inherits_raw == null:
		return
	var parent_ids: Array = inherits_raw if inherits_raw is Array else [inherits_raw]
	for parent: Variant in parent_ids:
		var parent_id := String(parent)
		if visited.has(parent_id) or not catalog_by_id.has(parent_id):
			continue
		visited[parent_id] = true
		_collect_class_grants(catalog_by_id[parent_id], held, catalog_by_id, out, visited)


func _skill_entries(ids: Array) -> Array:
	var out: Array = []
	for raw: Variant in ids:
		var id := String(raw)
		var sk: Dictionary = skills.get(id, {})
		var display := String(sk.get(WIKeys.DISPLAY_NAME, id))
		var revealed := used_skills.has(id)
		var text := display
		if revealed:
			var desc := String(sk.get("description", ""))
			if desc != "":
				text = "%s — %s" % [display, desc]
		out.append({WIKeys.ID: id, WIKeys.DISPLAY_NAME: display, "revealed": revealed, "text": text})
	return out


const GARDEN_MAP_ID := "garden_sanctuary"


func start_combat(entity_id: String) -> bool:
	if dialogue != null or combat != null or _combat_config.is_empty():
		return false
	if current_map == GARDEN_MAP_ID:
		return false
	var entity: Dictionary = find_entity(entity_id)
	if entity.is_empty() or String(entity[WIKeys.KIND]) != "encounter":
		return false
	if dormant_encounters.has(entity_id):
		return false
	var by_id := {}
	for c: Dictionary in _combat_config["combatants"]["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var cfgs: Array = [_build_player_combatant(by_id["pc"])]
	var allies: Array = (entity.get("allies", []) as Array).duplicate()
	var ally_req: Dictionary = entity.get("ally_requires", {})
	for key: String in ally_req:
		if accomplishment_count(key) < int(ally_req[key]):
			allies = []
			break
	var arena_id := String(entity["arena"])
	var repeat_arena_id := String(entity.get("repeat_arena", ""))
	if repeat_arena_id != "" and accomplishment_count(String(entity.get("tutorial_seen_when", ""))) > 0:
		arena_id = repeat_arena_id
	var arena: Dictionary = {}
	for a: Dictionary in _combat_config["arenas"]["arenas"]:
		if String(a[WIKeys.ID]) == arena_id:
			arena = a
	if arena.is_empty():
		return false
	# ORDER/CAPACITY: inject after ally_requires, before ally_hp_penalty.
	# PC + allies + companion must fit arena player_spawns.
	if companion != "" and by_id.has(companion) and not allies.has(companion):
		if allies.size() + 2 > (arena["player_spawns"] as Array).size():
			_emit(WIEvents.TOAST, {"text": "A crowded field. Your companion hangs back at its edge."})
		else:
			allies.append(companion)
	# GH#165 [Sworn Fang: Ride Together]: PC-side boon (inverse of the
	# companion boons below -- that carrier buffs the ally, this the PC).
	# Hidden hit_bonus folded into the PC kit while a companion rides; never
	# on the player-facing record (that fold would buff the PC always).
	# Mirrored in sim_combat_batch.gd.
	if companion != "" and known_skills().has("sworn_fang_ride_together"):
		var pc_skills: Array = (cfgs[0].get(WIKeys.SKILLS, []) as Array).duplicate()
		pc_skills.append("sworn_fang_boon")
		cfgs[0][WIKeys.SKILLS] = pc_skills
	var hp_penalties: Dictionary = entity.get("ally_hp_penalty", {})
	for ally: Variant in allies:
		var ally_cfg: Dictionary = (by_id[String(ally)] as Dictionary).duplicate(true)
		# GH#156 companion boons: [Animals: Basic Command]/[Pack Bond] carry NO
		# effect on the player-facing skill records (the PC kit fold would buff
		# the PC); the hidden *_boon carriers apply to the COMPANION only, here.
		if String(ally) == companion:
			var boons: Array = []
			if known_skills().has("animals_basic_command"):
				boons.append("basic_command_boon")
			if known_skills().has("pack_bond"):
				boons.append("pack_bond_boon")
			if not boons.is_empty():
				var comp_skills: Array = (ally_cfg.get(WIKeys.SKILLS, []) as Array).duplicate()
				comp_skills.append_array(boons)
				ally_cfg[WIKeys.SKILLS] = comp_skills
		var penalty: Dictionary = hp_penalties.get(String(ally), {})
		if not penalty.is_empty() and _accomplishment_gate_met(penalty.get("when", {}) as Dictionary):
			ally_cfg[WIKeys.HP_MOD] = int(ally_cfg.get(WIKeys.HP_MOD, 0)) + int(penalty.get("hp_mod", 0))
		cfgs.append(ally_cfg)
	# Issue #163: opt-in rank scaling on repeatable cull encounters only. Bronze
	# == identity; silver/gold step enemy HP/damage via THE one WIBountyScaling
	# site (mirrored in sim_combat_batch). Story/boss fights omit `scales`, so
	# never step (a validator forbids scales on respawns:false / quest-fed wins).
	var scale_rank := player_rank() if bool(entity.get("scales", false)) else "bronze"
	for enemy: Variant in entity.get("enemies", []):
		cfgs.append(WIBountyScaling.scale_enemy((by_id[String(enemy)] as Dictionary).duplicate(true), scale_rank))
	_break_sneak()
	_pending_encounter = entity_id
	combat = WICombat.new(arena, cfgs, skills_config_raw(), _combat_event_relay, rng.randi())
	combat.begin()
	return true


func _build_player_combatant(template: Dictionary) -> Dictionary:
	var pc: Dictionary = template.duplicate(true)
	pc[WIKeys.DISPLAY_NAME] = pc_name
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], classes, _combat_config["classes"])
	var kit: Array = WIProgression.granted_skills(classes, _combat_config["classes"], generalist_classes)
	var weapon := item(String(equipped.get(WIKeys.WEAPON, "")))
	pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills)
	pc[WIKeys.WEAPON_RANGE] = int(weapon.get(WIKeys.RANGE, 1))
	var armor := item(String(equipped.get("armor", "")))
	var accessories: Array = []
	for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
		accessories.append(item(String(equipped.get(slot_name, ""))))
	pc[WIKeys.SKILLS] = WICombatBuild.fold_abilities(pc[WIKeys.SKILLS] as Array, accessories)
	var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
	var meal_bonus: Dictionary = pending_meal
	pending_meal = {}
	pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD] + int(meal_bonus.get(WIKeys.DAMAGE_MOD, 0))
	pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD] + (2 if well_fed else 0) + int(meal_bonus.get(WIKeys.HP_MOD, 0)) + _room_tier_bonus()
	pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION] + int(meal_bonus.get(WIKeys.DAMAGE_REDUCTION, 0))
	return pc


func _room_tier_bonus() -> int:
	# GH#92 D3: inn room upgrades. Better rest = +1 max HP per held tier
	# (cumulative, cap +3). PERSISTENCE IS FREE: tiers are accomplishment
	# counters (room_tier_1/2/3, banked by Erin's purchase dialogue), which
	# already ride the save -- no new save field, unlike well_fed's
	# one-waking bool. Each tier banks at most once (hide_when-gated option).
	var bonus := 0
	for tier: String in ["room_tier_1", "room_tier_2", "room_tier_3"]:
		if accomplishment_count(tier) > 0:
			bonus += 1
	return bonus


func item(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


func _holds_weapon_family(family: String) -> bool:
	for item_id: String in inventory:
		if String(item(item_id).get("weapon_family", "")) == family:
			return true
	return false


func pickup(item_id: String, source_id: String) -> bool:
	if inventory.has(item_id):
		return false
	inventory.append(item_id)
	_emit(WIEvents.ITEM_GAINED, {"item": item_id, "source": source_id})
	var display := String(item(item_id).get("name", item_id))
	_emit(WIEvents.TOAST, {"text": "Got: %s" % display})
	return true


func remove_item(item_id: String, source_id: String) -> bool:
	if not inventory.has(item_id):
		return false
	for slot_name: String in equipped:
		if String(equipped[slot_name]) == item_id:
			return false
	inventory.erase(item_id)
	_emit(WIEvents.ITEM_LOST, {"item": item_id, "source": source_id})
	return true


func use_item(item_id: String) -> bool:
	if combat != null:
		return false
	if not inventory.has(item_id):
		return false
	var rec := item(item_id)
	if rec.is_empty():
		return false
	var result := WIItems.resolve_use(rec, null)
	if not bool(result.get("ok", false)):
		return false
	pending_meal = (result.get("pending_meal", {}) as Dictionary).duplicate(true)
	inventory.erase(item_id)
	_emit(WIEvents.ITEM_USED, {"item": item_id})
	_emit(WIEvents.TOAST, {"text": "Used: %s." % String(rec.get("name", item_id))})
	return true


func combat_use_item(item_id: String) -> bool:
	if combat == null:
		return false
	if not inventory.has(item_id):
		return false
	var rec := item(item_id)
	if rec.is_empty():
		return false
	var result := WIItems.resolve_use(rec, combat)
	if not bool(result.get("ok", false)):
		return false
	inventory.erase(item_id)
	var healed := int(result.get("healed", 0))
	_emit(WIEvents.ITEM_USED, {"item": item_id, "healed": healed})
	_emit(WIEvents.TOAST, {"text": "Used: %s. Healed %d HP." % [String(rec.get("name", item_id)), healed]})
	return true


func _trade_bonus() -> float:
	var bonus := 0.0
	for sk_id: Variant in known_skills():
		bonus += float(skills.get(String(sk_id), {}).get("trade_bonus", 0.0))
	return bonus


func sell_price(worth: int) -> int:
	return int(floor(float(worth) * 0.5 * (1.0 + _trade_bonus())))


func sellable_items() -> Array:
	var out: Array = []
	for raw_id: Variant in inventory:
		var id := String(raw_id)
		var rec := item(id)
		if rec.is_empty() or bool(rec.get("unsellable", false)):
			continue
		if int(rec.get(WIKeys.PRICE, 0)) <= 0:
			continue
		var equipped_here := false
		for slot_name: String in equipped:
			if String(equipped[slot_name]) == id:
				equipped_here = true
				break
		if equipped_here:
			continue
		out.append(id)
	return out


func sell_item(item_id: String) -> bool:
	var rec := item(item_id)
	if rec.is_empty() or bool(rec.get("unsellable", false)):
		return false
	var worth := int(rec.get(WIKeys.PRICE, 0))
	if worth <= 0:
		return false
	if not remove_item(item_id, _dialogue_conversation_id):
		return false
	earn_gold(sell_price(worth), _dialogue_conversation_id)
	record_accomplishment("deliberate_commerce", 1)
	return true


func _equipped_resonance_total() -> int:
	var total := 0
	for slot_name: String in equipped:
		total += int(item(String(equipped[slot_name])).get(WIKeys.RESONANCE, 0))
	return total


func resonance_used() -> int:
	return _equipped_resonance_total()


const _CAPACITY_REFUSAL_TOAST := "It buzzes once against the others, like a wasp against glass, and will not settle."
const _ACCESSORY_SLOTS_FULL_TOAST := "There's nowhere left on you for it to rest. It waits in your palm, patient as stone."


func equip(item_id: String) -> bool:
	if combat != null:
		return false
	if not inventory.has(item_id):
		return false
	var rec := item(item_id)
	if rec.is_empty():
		return false
	var kind := String(rec.get(WIKeys.KIND, ""))
	if kind != "weapon" and kind != "armor" and kind != "accessory":
		return false
	var target_slot := kind
	if kind == "accessory":
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(equipped.get(slot_name, "")) == item_id:
				return false
		target_slot = ""
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(equipped.get(slot_name, "")) == "":
				target_slot = slot_name
				break
		if target_slot == "":
			_emit(WIEvents.TOAST, {"text": _ACCESSORY_SLOTS_FULL_TOAST})
			return false
	var displaced_resonance := int(item(String(equipped.get(target_slot, ""))).get(WIKeys.RESONANCE, 0))
	var would_be_total := _equipped_resonance_total() - displaced_resonance + int(rec.get(WIKeys.RESONANCE, 0))
	if would_be_total > resonance_capacity:
		_emit(WIEvents.TOAST, {"text": _CAPACITY_REFUSAL_TOAST})
		return false
	equipped[target_slot] = item_id
	_emit(WIEvents.ITEM_EQUIPPED, {"item": item_id, "slot": target_slot})
	return true


func unequip(slot: String) -> bool:
	if combat != null:
		return false
	if not equipped.has(slot):
		return false
	if String(equipped.get(slot, "")) == "":
		return false
	equipped[slot] = ""
	_emit(WIEvents.ITEM_UNEQUIPPED, {"slot": slot})
	return true


func resolve_combat() -> void:
	if combat == null or not combat.finished:
		return
	# Merge skill discovery before victory/trivial branching; combat statuses
	# were already relayed live and must not be reconstructed here.
	for skill_id: String in (combat.used_skills_tally.get("pc", {}) as Dictionary):
		_mark_skill_used(skill_id)
	var entity: Dictionary = find_entity(_pending_encounter)
	if combat.outcome["victory"]:
		# CONTRACT: bank once per won encounter, outside the multi-id on_victory loop.
		record_accomplishment("victories")
		var victories: Variant = entity.get("on_victory", "won_combat")
		for vid: Variant in (victories if victories is Array else [victories]):
			record_accomplishment(String(vid))
		_bank_action_tally(entity)
		_roll_loot(entity)
		# GH#186: opt-in one-shot victory toast -- fires on the FIRST win of
		# this encounter only (first on_victory counter just reached 1); the
		# onboarding-beat seam (post-spar sleep nudge is the first user).
		var victory_toast := String(entity.get("victory_toast", ""))
		if victory_toast != "":
			var first_vid := String((victories if victories is Array else [victories])[0])
			if accomplishment_count(first_vid) == 1:
				_emit(WIEvents.TOAST, {"text": victory_toast})
		if bool(entity.get("respawns", false)):
			if not dormant_encounters.has(_pending_encounter):
				dormant_encounters.append(_pending_encounter)
		elif not bool(entity.get("persistent", false)):
			remove_entity(_pending_encounter)
		_emit(WIEvents.COMBAT_RESOLVED, {"victory": true})
	else:
		_emit(WIEvents.GAME_OVER, {})
	combat = null
	_pending_encounter = ""


func _bank_action_tally(entity: Dictionary) -> void:
	if bool(entity.get("trivial", false)) or bool(combat.arena_config.get("trivial", false)):
		return
	var tally: Dictionary = combat.action_tally.get("pc", {})
	var counters: Array = tally.keys()
	counters.sort()
	for counter: String in counters:
		record_accomplishment(counter, int(tally[counter]))


func _roll_loot(entity: Dictionary) -> void:
	gold = _economy.roll_loot(gold, _run_seed, entity)


func remove_entity(id: String) -> void:
	for map_id: String in _maps:
		var map_entities: Dictionary = _maps[map_id]["entities"]
		if map_entities.has(id):
			map_entities.erase(id)
			if not removed_entities.has(id):
				removed_entities.append(id)
			_emit(WIEvents.ENTITY_REMOVED, {"id": id})
			return


func erase_entity_silent(id: String) -> void:
	for map_id: String in _maps:
		var map_entities: Dictionary = _maps[map_id]["entities"]
		if map_entities.has(id):
			map_entities.erase(id)
			return


const _EVOLUTION_WAITING_TOASTS := {
	"warrior": "Your hands haven't chosen sword or spear yet.",
	"mage": "Your focus wavers between frost and flame.",
	"helper": "You haven't settled into serving or running yet.",
}


func sleep() -> void:
	for encounter_id: String in warded_encounters.keys():
		var ward: Dictionary = warded_encounters[encounter_id]
		var remaining := int(ward.get("sleeps", 1)) - 1
		if remaining <= 0:
			warded_encounters.erase(encounter_id)
		else:
			ward["sleeps"] = remaining
	# GH#156: tamed bonds PERSIST sleep (canon); only the animated working fades.
	if companion_source != "tamed":
		_clear_companion("sleep")
	dormant_encounters.clear()
	social_talked.clear()
	entity_first_use.clear()
	light_active = false
	well_fed = false
	frozen_cells.clear()
	sneaking = false
	if accepted_delivery_id != "":
		var failed_delivery := _delivery_by_id(accepted_delivery_id)
		var failed_parcel_id := String((failed_delivery.get("parcel", {}) as Dictionary).get("item_id", ""))
		if failed_parcel_id != "" and inventory.has(failed_parcel_id):
			remove_item(failed_parcel_id, accepted_delivery_id)
			_emit(WIEvents.TOAST, {"text": "The undelivered parcel goes back on the night ledger."})
			accepted_delivery_id = ""
			accepted_delivery_baseline = {}
			delivery_failed = true
	actions_since_sleep = 0
	# GH#165 [Supplies: Flarepepper Powder]: the Chef line restocks one at
	# each rest (canon [Supplies:] cadence). Never stacks -- pickup() no-ops
	# a held duplicate. known_skills() is empty when _combat_config is, so a
	# pre-class save simply skips this.
	if known_skills().has("flarepepper_supplies") and not inventory.has("flarepepper_powder"):
		pickup("flarepepper_powder", "flarepepper_supplies")
	times_slept += 1
	# GH#130: the only unconditional sleep counter -- talk-pool/dialogue gates can
	# now express "has slept" (times_slept is a plain var, invisible to gates).
	record_accomplishment("slept")
	_emit(WIEvents.PHASE_CHANGED, {"phase": phase()})
	_sleep_beat.run(classes, accomplishments, _combat_config)


func _bank_reached_two_classes_if_earned() -> void:
	if accomplishment_count("reached_two_classes") >= 1:
		return
	if classes.size() >= 2 or _holds_consolidated_class():
		record_accomplishment("reached_two_classes")


func _holds_consolidated_class() -> bool:
	var cfg: Dictionary = _combat_config.get("classes", {})
	for cons: Dictionary in cfg.get("consolidations", []):
		if classes.has(String((cons as Dictionary).get("target", ""))):
			return true
	return false


func _set_pending_consolidation(offer: Dictionary) -> void:
	pending_consolidation = offer


func _grow_resonance() -> void:
	resonance_capacity += 1


func _enriched_offer(offer: Dictionary) -> Dictionary:
	var enriched := offer.duplicate(true)
	var parent_ids: Array = offer["parents"]
	enriched["parents_display"] = [_class_display_name(String(parent_ids[0])), _class_display_name(String(parent_ids[1]))]
	enriched["target_display"] = _class_display_name(String(offer["target"]))
	return enriched


func pending_offer_display() -> Dictionary:
	if pending_consolidation.is_empty():
		return {}
	return _enriched_offer(pending_consolidation)


func _resolve_evolutions() -> bool:
	var anything_happened := false
	var evolutions := WIProgression.check_evolutions(classes, accomplishments, _combat_config["classes"], generalist_classes)
	for outcome: Dictionary in evolutions:
		var class_id := String(outcome["class"])
		if outcome.has("to"):
			var new_id := String(outcome["to"])
			var level := int(outcome["level"])
			var old_name := String(_class_display_name(class_id))
			var new_name := String(_class_display_name(new_id))
			classes[new_id] = level
			classes.erase(class_id)
			anything_happened = true
			_emit(WIEvents.CLASS_EVOLVED, {"from": class_id, "to": new_id, "level": level})
			var text := "[%s] has become [%s]!" % [old_name, new_name]
			if bool(outcome.get("off_interval", false)):
				text += " The change came later than most, but it holds all the same."
			_emit(WIEvents.TOAST, {"text": text})
		elif bool(outcome.get("generalist", false)):
			var grant_names: Array = []
			for sk: Variant in outcome.get("grants", []):
				var sk_id := String(sk)
				_emit(WIEvents.SKILL_UNLOCKED, {"skill": sk_id})
				grant_names.append(String(skills.get(sk_id, {}).get(WIKeys.DISPLAY_NAME, sk_id)))
			if not generalist_classes.has(class_id):
				generalist_classes.append(class_id)
			anything_happened = true
			var cls_name := String(_class_display_name(class_id))
			var text := "[%s] settles into a balanced mastery" % cls_name
			if not grant_names.is_empty():
				text += " — unlocked %s" % ", ".join(grant_names)
			_emit(WIEvents.TOAST, {"text": text})
		elif bool(outcome.get("waiting", false)) and _EVOLUTION_WAITING_TOASTS.has(class_id):
			anything_happened = true
			_emit(WIEvents.TOAST, {"text": String(_EVOLUTION_WAITING_TOASTS[class_id])})
	return anything_happened


func accept_consolidation() -> void:
	if pending_consolidation.is_empty():
		return
	var offer := pending_consolidation
	pending_consolidation = {}
	var parents: Array = offer["parents"]
	var target := String(offer["target"])
	var level := int(offer["level"])
	var parent_names: Array = []
	for parent_id: Variant in parents:
		var pid := String(parent_id)
		parent_names.append(String(_class_display_name(pid)))
		classes.erase(pid)
	classes[target] = level
	_emit(WIEvents.CONSOLIDATION_ACCEPTED, offer.duplicate(true))
	var target_name := String(_class_display_name(target))
	_emit(WIEvents.TOAST, {"text": "[%s] and [%s] merge into [%s]!" % [parent_names[0], parent_names[1], target_name]})
	_bank_reached_two_classes_if_earned()


func decline_consolidation() -> void:
	if pending_consolidation.is_empty():
		return
	pending_consolidation = {}
	_emit(WIEvents.CONSOLIDATION_DECLINED, {})
	if not _resolve_evolutions():
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})


func _class_display_name(id: String) -> String:
	for cls: Dictionary in _combat_config["classes"]["classes"]:
		if String(cls[WIKeys.ID]) == id:
			return String(cls[WIKeys.DISPLAY_NAME])
	return id


func skills_config_raw() -> Dictionary:
	return {WIKeys.SKILLS: skills.values()}


func snapshot() -> Dictionary:
	return {
		"current_map": current_map,
		"player_cell": [player_cell.x, player_cell.y],
		"player_facing": [player_facing.x, player_facing.y],
		"pc_name": pc_name,
		"pc_race": pc_race,
		"pc_gender": pc_gender,
		"pc_sprite": pc_sprite_variant(),
		"player_skills": player_skills.duplicate(),
		"accomplishments": accomplishments.duplicate(true),
		"classes": classes.duplicate(true),
		"removed_entities": removed_entities.duplicate(),
		"dormant_encounters": dormant_encounters.duplicate(),
		"generalist_classes": generalist_classes.duplicate(),
		"started_quests": started_quests.duplicate(),
		"pending_consolidation": pending_consolidation.duplicate(true),
		"used_skills": used_skills.duplicate(),
		"seen_statuses": seen_statuses.duplicate(),
		"inventory": inventory.duplicate(),
		"equipped": equipped.duplicate(true),
		"container_state": container_state.duplicate(true),
		"actions_since_sleep": actions_since_sleep,
		"light_active": light_active,
		"well_fed": well_fed,
		"frozen_cells": frozen_cells_json(),
		"phase": phase(),
		"sneaking": sneaking,
		"hotbar_loadout": hotbar_loadout.duplicate(),
		"warded_encounters": warded_encounters.duplicate(true),
		"companion": companion,
		"gold": gold,
		"times_slept": times_slept,
		"accepted_bounty_id": accepted_bounty_id,
		"accepted_bounty_tier": accepted_bounty_tier,
		"player_rank": player_rank(),
		"board_active_bounties": board_bounties().map(func(b: Dictionary) -> String: return String(b["id"])),
		"accepted_delivery_id": accepted_delivery_id,
		"delivery_failed": delivery_failed,
		"board_active_deliveries": delivery_board_deliveries().map(func(d: Dictionary) -> String: return String(d["id"])),
		"door_study_sleeps": door_study_sleeps(),
		"second_door_study_sleeps": second_door_study_sleeps(),
		"attuned_destinations": attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])),
	}


func phase() -> String:
	var dusk_at := int(_phase_config.get("dusk_at", 40))
	var night_at := int(_phase_config.get("night_at", 90))
	if actions_since_sleep >= night_at:
		return "night"
	if actions_since_sleep >= dusk_at:
		return "dusk"
	return "day"


func _tick_action() -> void:
	var before := phase()
	actions_since_sleep += 1
	var after := phase()
	if after != before:
		_emit(WIEvents.PHASE_CHANGED, {"phase": after})


func _combat_event_relay(type: String, payload: Dictionary) -> void:
	if type == WIEvents.TURN_STARTED and String(payload.get(WIKeys.ID, "")) == "pc":
		_tick_action()
	if type == WIEvents.STATUS_APPLIED:
		payload = _enrich_status_applied(payload)
	if type == WIEvents.COMBATANT_DOWNED and String(payload.get(WIKeys.ID, "")) == companion:
		_clear_companion("downed")
	if (type == WIEvents.REACTION_TRIGGERED or type == WIEvents.PASSIVE_APPLIED) \
			and String(payload.get(WIKeys.ID, "")) == "pc":
		var reaction_skill := String(payload.get("skill", ""))
		if reaction_skill != "" and not used_skills.has(reaction_skill):
			used_skills.append(reaction_skill)
	_emit(type, payload)


func _enrich_status_applied(payload: Dictionary) -> Dictionary:
	var out := payload.duplicate()
	var status_id := String(out.get("status", ""))
	var first_seen := status_id != "" and not seen_statuses.has(status_id)
	if first_seen:
		seen_statuses.append(status_id)
	out["first_seen"] = first_seen
	out["status_text"] = WIEffectText.status_line(status_id, skills.values()) if first_seen else ""
	return out


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
