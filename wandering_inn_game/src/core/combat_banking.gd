class_name WICombatBanking
extends RefCounted

## Issue #194a seam 3: post-fight banking moved VERBATIM out of
## WIGame.resolve_combat() behind injected Callables — sim event streams must
## stay byte-identical at pinned seeds. The caller keeps the finished-guard
## and clears combat/_pending_encounter AFTER resolve() returns (synchronous
## COMBAT_RESOLVED handlers may read sim.combat — clearing first would be a
## behavior change). _roll_loot stays in WIGame (gold/_economy/_run_seed)
## behind roll_loot_cb. This module is #211's landing zone: challenge weight
## and repetition decay wrap the _bank_action_tally deposit path HERE, not in
## wi_game.gd.

var _event_sink: Callable
var _mark_skill_used: Callable
var _find_entity: Callable
var _record_accomplishment: Callable
var _accomplishment_count: Callable
var _roll_loot: Callable
var _remove_entity: Callable


func _init(event_sink: Callable, mark_skill_used_cb: Callable, find_entity_cb: Callable, record_accomplishment_cb: Callable, accomplishment_count_cb: Callable, roll_loot_cb: Callable, remove_entity_cb: Callable) -> void:
	_event_sink = event_sink
	_mark_skill_used = mark_skill_used_cb
	_find_entity = find_entity_cb
	_record_accomplishment = record_accomplishment_cb
	_accomplishment_count = accomplishment_count_cb
	_roll_loot = roll_loot_cb
	_remove_entity = remove_entity_cb


func resolve(combat: WICombat, encounter_id: String, dormant_encounters: Array[String]) -> void:
	# Merge skill discovery before victory/trivial branching; combat statuses
	# were already relayed live and must not be reconstructed here.
	for skill_id: String in (combat.used_skills_tally.get("pc", {}) as Dictionary):
		_mark_skill_used.call(skill_id)
	var entity: Dictionary = _find_entity.call(encounter_id)
	if combat.outcome["victory"]:
		# CONTRACT: bank once per won encounter, outside the multi-id on_victory loop.
		_record_accomplishment.call("victories", 1)
		var victories: Variant = entity.get("on_victory", "won_combat")
		for vid: Variant in (victories if victories is Array else [victories]):
			_record_accomplishment.call(String(vid), 1)
		_bank_action_tally(combat, entity)
		_roll_loot.call(entity)
		# GH#186: opt-in one-shot victory toast -- fires on the FIRST win of
		# this encounter only (first on_victory counter just reached 1); the
		# onboarding-beat seam (post-spar sleep nudge is the first user).
		var victory_toast := String(entity.get("victory_toast", ""))
		if victory_toast != "":
			var first_vid := String((victories if victories is Array else [victories])[0])
			if int(_accomplishment_count.call(first_vid)) == 1:
				_emit(WIEvents.TOAST, {"text": victory_toast})
		if bool(entity.get("respawns", false)):
			if not dormant_encounters.has(encounter_id):
				dormant_encounters.append(encounter_id)
		elif not bool(entity.get("persistent", false)):
			_remove_entity.call(encounter_id)
		_emit(WIEvents.COMBAT_RESOLVED, {"victory": true})
	else:
		_emit(WIEvents.GAME_OVER, {})


func _bank_action_tally(combat: WICombat, entity: Dictionary) -> void:
	if bool(entity.get("trivial", false)) or bool(combat.arena_config.get("trivial", false)):
		return
	var tally: Dictionary = combat.action_tally.get("pc", {})
	var counters: Array = tally.keys()
	counters.sort()
	for counter: String in counters:
		_record_accomplishment.call(counter, int(tally[counter]))


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
