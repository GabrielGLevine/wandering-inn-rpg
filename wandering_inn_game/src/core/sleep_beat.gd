class_name WISleepBeat
extends RefCounted

## Issue #194a seam 2: the sleep-beat ORCHESTRATION + toast stream moved
## VERBATIM out of WIGame.sleep() behind injected Callables — sim event
## streams must stay byte-identical at pinned seeds. WIGame.sleep() keeps the
## waking-state reset (wards/companion/first-use/delivery/phase) and calls
## run() after PHASE_CHANGED. Shared helpers stay in WIGame behind Callables:
## _resolve_evolutions (decline_consolidation also runs it), _enriched_offer
## (pending_offer_display), _bank_reached_two_classes_if_earned
## (accept_consolidation), _class_display_name, _quests_completed_count.
## Sleep-only helpers moved in: tremor pointer, garden earn/unlock, class
## gained toast (signatures gain a combat-config/classes-cfg param — the only
## non-verbatim drift, bodies unchanged). `classes`/`accomplishments`/
## `combat_config` are by-ref run() args; `skills` is injected at construction.

var _event_sink: Callable
var _record_accomplishment: Callable
var _accomplishment_count: Callable
var _known_skills: Callable
var _class_display_name: Callable
var _enriched_offer: Callable
var _set_pending_consolidation: Callable
var _bank_reached_two_classes: Callable
var _resolve_evolutions: Callable
var _quests_completed_count: Callable
var _start_quest: Callable
var _grow_resonance: Callable
var _skills: Dictionary


func _init(event_sink: Callable, record_accomplishment_cb: Callable, accomplishment_count_cb: Callable, known_skills_cb: Callable, class_display_name_cb: Callable, enriched_offer_cb: Callable, set_pending_consolidation_cb: Callable, bank_reached_two_classes_cb: Callable, resolve_evolutions_cb: Callable, quests_completed_count_cb: Callable, start_quest_cb: Callable, grow_resonance_cb: Callable, skills: Dictionary) -> void:
	_event_sink = event_sink
	_record_accomplishment = record_accomplishment_cb
	_accomplishment_count = accomplishment_count_cb
	_known_skills = known_skills_cb
	_class_display_name = class_display_name_cb
	_enriched_offer = enriched_offer_cb
	_set_pending_consolidation = set_pending_consolidation_cb
	_bank_reached_two_classes = bank_reached_two_classes_cb
	_resolve_evolutions = resolve_evolutions_cb
	_quests_completed_count = quests_completed_count_cb
	_start_quest = start_quest_cb
	_grow_resonance = grow_resonance_cb
	_skills = skills


func run(classes: Dictionary, accomplishments: Dictionary, combat_config: Dictionary) -> void:
	if combat_config.is_empty():
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})
		return
	var anything_happened := false
	var gained_classes := WIProgression.check_class_gains(classes, accomplishments, combat_config["classes"])
	for class_id: String in gained_classes:
		classes[class_id] = 1
		anything_happened = true
		_emit(WIEvents.CLASS_GAINED, {"class": class_id})
		_emit(WIEvents.TOAST, {"text": _class_gained_toast(class_id, combat_config)})
	var gains := WIProgression.check_level_ups(classes, accomplishments, combat_config["classes"])
	if not gains.is_empty():
		anything_happened = true
		var order: Array[String] = []
		var summaries: Dictionary = {}
		var gi := 0
		while gi < gains.size():
			var class_id := String((gains[gi] as Dictionary)["class"])
			var from_level := int(classes[class_id])
			var before_bonuses := WIProgression.derived_stat_bonuses(classes, combat_config["classes"])
			var names: Array = []
			while gi < gains.size() and String((gains[gi] as Dictionary)["class"]) == class_id:
				var gain: Dictionary = gains[gi]
				classes[class_id] = int(gain["level"])
				_emit(WIEvents.CLASS_LEVEL_UP, {"class": class_id, "level": gain["level"]})
				for sk: Variant in gain["grants"]:
					_emit(WIEvents.SKILL_UNLOCKED, {"skill": String(sk)})
					names.append(String(_skills.get(String(sk), {}).get(WIKeys.DISPLAY_NAME, String(sk))))
				gi += 1
			var after_bonuses := WIProgression.derived_stat_bonuses(classes, combat_config["classes"])
			order.append(class_id)
			summaries[class_id] = {
				"from": from_level,
				"to": int(classes[class_id]),
				"names": names,
				"hp_delta": int(after_bonuses.get("con", 0)) - int(before_bonuses.get("con", 0)),
				# TRAP: floor(bonus/2) equals combat's floor((base+bonus)/2) delta ONLY
				# because PC base str/int are EVEN (combatants.json pc: str 12, int 8);
				# odd base drifts this toast +-1 vs real delta — re-derive both clauses
				# if a base stat edit lands.
				"dmg_delta": int(after_bonuses.get("str", 0)) / 2 - int(before_bonuses.get("str", 0)) / 2,
				"mp_delta": int(after_bonuses.get("int", 0)) / 2 - int(before_bonuses.get("int", 0)) / 2,
			}
		var has_mp_skill := false
		for sk_id: String in (_known_skills.call() as Array):
			if (_skills.get(sk_id, {}) as Dictionary).has(WIKeys.MP_COST):
				has_mp_skill = true
				break
		for class_id: String in order:
			var summary: Dictionary = summaries[class_id]
			var cls_name := String(_class_display_name.call(class_id))
			var text := "[%s Level %d]" % [cls_name, int(summary["to"])]
			if int(summary["to"]) > int(summary["from"]) + 1:
				text = "[%s Level %d → %d]" % [cls_name, int(summary["from"]), int(summary["to"])]
			var names: Array = summary["names"]
			if not names.is_empty():
				text += " — unlocked %s" % ", ".join(names)
			var growth: Array[String] = []
			if int(summary["hp_delta"]) > 0:
				growth.append("+%d Max HP" % int(summary["hp_delta"]))
			if int(summary["dmg_delta"]) > 0:
				growth.append("+%d damage" % int(summary["dmg_delta"]))
			if int(summary["mp_delta"]) > 0 and has_mp_skill:
				growth.append("+%d Max MP" % int(summary["mp_delta"]))
			if not growth.is_empty():
				text += " (%s)" % ", ".join(growth)
			_emit(WIEvents.TOAST, {"text": text})

	_bank_reached_two_classes.call()

	var offer := WIProgression.check_consolidation(classes, combat_config["classes"])
	if not offer.is_empty():
		_set_pending_consolidation.call(offer)
		_emit(WIEvents.CONSOLIDATION_OFFERED, _enriched_offer.call(offer))
		return

	if bool(_resolve_evolutions.call()):
		anything_happened = true

	if _maybe_fire_tremor_pointer():
		anything_happened = true

	if _count("door_understood") >= 1 and _count("recovered_anchor_stone") >= 1 and _count("bought_catalyst") >= 1 and _count("door_awakened") < 1:
		_record_accomplishment.call("door_study_sleeps", 1)
		if _count("door_study_sleeps") >= 3:
			_record_accomplishment.call("door_awakened", 1)
			anything_happened = true

	if _count("door_awakened") >= 1 and _count("heard_pisces_second_door") >= 1 and _count("dungeon_attuned") < 1:
		_record_accomplishment.call("second_door_study_sleeps", 1)
		if _count("second_door_study_sleeps") >= 2:
			_record_accomplishment.call("dungeon_attuned", 1)
			anything_happened = true

	if _count("door_awakened") >= 1 and _count("resonance_grown") < 1:
		_record_accomplishment.call("catalyst_attunement_sleeps", 1)
		if _count("catalyst_attunement_sleeps") >= 2:
			_record_accomplishment.call("resonance_grown", 1)
			_grow_resonance.call()
			anything_happened = true

	_bank_garden_unlock_if_earned()

	if not anything_happened:
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})


func _maybe_fire_tremor_pointer() -> bool:
	if _count("watch_runner_pointed") >= 1:
		return false
	if _count("heard_the_deep_tremor") >= 1:
		return false
	if _count("reached_two_classes") < 1 or int(_quests_completed_count.call()) < 3:
		return false
	_record_accomplishment.call("watch_runner_pointed", 1)
	# GH#167: the toast is a NUDGE; the durable direction is the journal
	# quest started here (the arc was the only thread without one).
	_start_quest.call("something_beneath")
	# GH#273: sticky -- this nudge is the arc's only route clue and queues
	# LAST at a wake beat; without the flag, leaving the bedroom wiped it.
	_emit(WIEvents.TOAST, {"text": "A Watch runner is looking for you.", "sticky": true})
	return true


func _garden_earn_met() -> bool:
	if _count("reached_two_classes") < 1 or int(_quests_completed_count.call()) < 3:
		return false
	var legs := ["cleaned_the_inn", "goblins_spared", "sign_defended", "resolved_wrong_order"]
	var met := 0
	for leg: String in legs:
		if _count(leg) >= 1:
			met += 1
	return met >= 2


func _bank_garden_unlock_if_earned() -> void:
	if _count("garden_door_unlocked") >= 1:
		return
	if not _garden_earn_met():
		return
	_record_accomplishment.call("garden_door_unlocked", 1)


func _class_gained_toast(class_id: String, combat_config: Dictionary) -> String:
	var base := "[%s] class gained!" % String(_class_display_name.call(class_id))
	var names: Array[String] = []
	for cls: Dictionary in combat_config["classes"]["classes"]:
		if String(cls[WIKeys.ID]) == class_id:
			for lv: Dictionary in cls.get("levels", []):
				if int(lv.get("level", 0)) == 1:
					for sk: Variant in lv.get("grants", []):
						names.append(String(_skills.get(String(sk), {}).get(WIKeys.DISPLAY_NAME, String(sk))))
			break
	if names.is_empty():
		return base
	return "%s — %s" % [base, ", ".join(names)]


func _count(id: String) -> int:
	return int(_accomplishment_count.call(id))


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
