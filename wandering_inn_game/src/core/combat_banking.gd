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
## GH#211 challenge weighting. _challenge_cfg = data/progression.json's
## "challenge" dict (enabled:false -> the legacy integer path, byte-identical).
## _class_catalog = classes.json (player effective_power); _power_levels =
## combatant id -> authored power_level (enemy party power). classes and
## fractional_bank arrive per-resolve from the caller (never captured — the
## dormant_encounters per-call-binding precedent: save/load may replace them).
var _challenge_cfg: Dictionary = {}
var _class_catalog: Dictionary = {}
var _power_levels: Dictionary = {}


func _init(event_sink: Callable, mark_skill_used_cb: Callable, find_entity_cb: Callable, record_accomplishment_cb: Callable, accomplishment_count_cb: Callable, roll_loot_cb: Callable, remove_entity_cb: Callable, challenge_cfg: Dictionary = {}, class_catalog: Dictionary = {}, combatants_raw: Array = []) -> void:
	_event_sink = event_sink
	_mark_skill_used = mark_skill_used_cb
	_find_entity = find_entity_cb
	_record_accomplishment = record_accomplishment_cb
	_accomplishment_count = accomplishment_count_cb
	_roll_loot = roll_loot_cb
	_remove_entity = remove_entity_cb
	_challenge_cfg = challenge_cfg
	_class_catalog = class_catalog
	for c: Dictionary in combatants_raw:
		if c.has("power_level"):
			_power_levels[String(c[WIKeys.ID])] = float(c["power_level"])


## Weight for one fight: enemy-party power vs player power through the
## gamma/gray curve. Pure; ratio 1 => 1.0. ANY enemy missing an authored
## power_level (or an empty player class dict at power 0 vs nothing) falls
## back to 1.0 — neutral, rollout-safe.
static func challenge_weight(cfg: Dictionary, player_power: float, enemy_power: float) -> float:
	if enemy_power <= 0.0:
		return 1.0
	var ratio := enemy_power / maxf(player_power, 1.0)
	var weight := clampf(pow(ratio, float(cfg.get("weight_gamma", 1.6))), float(cfg.get("weight_floor", 0.0)), float(cfg.get("weight_cap", 2.0)))
	if ratio <= float(cfg.get("gray_ratio", 0.55)):
		weight *= float(cfg.get("gray_scale", 0.15))
	return weight


## Per-encounter repetition decay from prior wins of the SAME encounter
## (keyed on its first on_victory counter, banked once per win already).
static func repetition_decay(cfg: Dictionary, prior_wins: int) -> float:
	return 1.0 / (1.0 + float(cfg.get("decay_rate", 0.9)) * log(1.0 + float(maxi(prior_wins, 0))))


func _enemy_party_power(combat: WICombat) -> float:
	var levels: Array = []
	for id: String in combat.combatants:
		var c: Dictionary = combat.combatants[id]
		if String(c[WIKeys.SIDE]) != "enemy":
			continue
		if not _power_levels.has(id):
			return 0.0
		levels.append(_power_levels[id])
	if levels.is_empty():
		return 0.0
	var k: float = float((_class_catalog.get("meta", {}) as Dictionary).get("power_k", 1.55))
	var sum := 0.0
	for lv: Variant in levels:
		sum += pow(float(lv), k)
	return pow(sum, 1.0 / k)


## Fractional deposit: accumulate, bank the integer floor, keep the remainder.
func _deposit(counter: String, amount: float, fractional_bank: Dictionary) -> void:
	var acc := float(fractional_bank.get(counter, 0.0)) + amount
	var whole := int(floorf(acc))
	if whole > 0:
		_record_accomplishment.call(counter, whole)
	fractional_bank[counter] = acc - float(whole)


func resolve(combat: WICombat, encounter_id: String, dormant_encounters: Array[String], classes: Dictionary = {}, fractional_bank: Dictionary = {}) -> void:
	# Merge skill discovery before victory/trivial branching; combat statuses
	# were already relayed live and must not be reconstructed here.
	for skill_id: String in (combat.used_skills_tally.get("pc", {}) as Dictionary):
		_mark_skill_used.call(skill_id)
	var entity: Dictionary = _find_entity.call(encounter_id)
	if combat.outcome["victory"]:
		# CONTRACT: bank once per won encounter, outside the multi-id on_victory loop.
		# GH#211: `victories` (chronicle tally) and specific on_victory quest ids
		# ALWAYS bank integer-unconditional — only the literal won_combat counter
		# and the action tally take challenge weight; victory_toast carriers must
		# key their FIRST on_victory id on a quest-style counter (the sole
		# shipped carrier, relc_spar/sparred_with_relc, does).
		_record_accomplishment.call("victories", 1)
		var victories: Variant = entity.get("on_victory", "won_combat")
		var vid_list: Array = victories if victories is Array else [victories]
		var enabled := bool(_challenge_cfg.get("enabled", false))
		var adversity := 1.0
		if enabled:
			var prior_wins := int(_accomplishment_count.call(String(vid_list[0])))
			var player_power := WIProgression.effective_power(classes, _class_catalog)
			adversity = challenge_weight(_challenge_cfg, player_power, _enemy_party_power(combat)) \
					* repetition_decay(_challenge_cfg, prior_wins)
		for vid: Variant in vid_list:
			if enabled and String(vid) == "won_combat":
				_deposit("won_combat", adversity, fractional_bank)
			else:
				_record_accomplishment.call(String(vid), 1)
		_bank_action_tally(combat, entity, enabled, adversity, fractional_bank)
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


func _bank_action_tally(combat: WICombat, entity: Dictionary, enabled: bool = false, adversity: float = 1.0, fractional_bank: Dictionary = {}) -> void:
	if bool(entity.get("trivial", false)) or bool(combat.arena_config.get("trivial", false)):
		return
	var tally: Dictionary = combat.action_tally.get("pc", {})
	var counters: Array = tally.keys()
	counters.sort()
	for counter: String in counters:
		if enabled:
			_deposit(counter, float(int(tally[counter])) * adversity, fractional_bank)
		else:
			_record_accomplishment.call(counter, int(tally[counter]))


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
