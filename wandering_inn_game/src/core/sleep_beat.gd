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
	_log_system_bestowal_candidate(classes, accomplishments)
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
			var pool_grew := false
			if int(summary["hp_delta"]) > 0:
				growth.append("+%d Max HP" % int(summary["hp_delta"]))
				pool_grew = true
			if int(summary["dmg_delta"]) > 0:
				growth.append("+%d damage" % int(summary["dmg_delta"]))
			if int(summary["mp_delta"]) > 0 and has_mp_skill:
				growth.append("+%d Max MP" % int(summary["mp_delta"]))
				pool_grew = true
			if not growth.is_empty():
				text += " (%s)" % ", ".join(growth)
			# GH#334 notes 19/28: this line is the single largest source of the
			# false persistent-pool model (combat_screen.gd's own FIRST_MP_HINT
			# comment names it). A player told at bedtime that sleep raises Max
			# HP and Max MP reasonably infers a pool that sleep refills -- and
			# then reads the next fight's full bar as a bug. There is no pool:
			# `WICombat.build` sets HP = MAX_HP and MP = MAX_MP for every
			# combatant at every fight, and neither is a WIGame field or a save
			# key. Keep the numbers, say what they are, and say it only when a
			# pool number is actually on screen.
			if pool_grew:
				text += " — you start every fight full."
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

	# 2026-07-26 reframe: post_game means "Liscor counts you among its own",
	# banked at the first sleep after the seal -- the epilogue no longer owns
	# it (Phase 8 retired the epilogue entirely, moving the curtain to Act V's
	# seal_resolved). This bank has NO toast of its own, and must not grow one:
	# the beat is voiced ONCE, by the Grand Design, as sleep_veil.gd's
	# SEAL_TRANSITION_LINE under the black. But it IS voiced, so it counts as
	# something happening -- the "You sleep soundly." fallback would otherwise
	# render on top of the GDI announcing that the warren is sealed. (Task 1.2
	# left the flag alone because the bank was invisible then; Phase 8's line
	# supersedes that rationale, not the no-toast half of it.)
	if _count("raskghar_sealed") >= 1 and _count("post_game") < 1:
		_record_accomplishment.call("post_game", 1)
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
			# GH#271: the bank was silent -- the Dungeon row just appeared in
			# the portal menu. Nudge idiom (GH#167), lore = read-backable.
			_emit(WIEvents.TOAST, {"text": "The Door hums against the wardwork below the city. Somewhere under Liscor, something answers it now.", "lore": true})
			anything_happened = true

	if _count("door_awakened") >= 1 and _count("resonance_grown") < 1:
		_record_accomplishment.call("catalyst_attunement_sleeps", 1)
		if _count("catalyst_attunement_sleeps") >= 2:
			_record_accomplishment.call("resonance_grown", 1)
			_grow_resonance.call()
			# GH#379: the growth used to be felt and never named -- sleep_veil's
			# line under the black ("You have room for it now.") is the beat, but
			# it is gone the moment the veil lifts and it never says Resonance.
			# Same `lore: true` toast idiom the dungeon_attuned bank above uses
			# (zero new mechanism), so the word lands in the journal's Lore
			# section where the player can read it back at leisure.
			_emit(WIEvents.TOAST, {"text": "Resonance is how much enchantment you can wear at once before the pieces start arguing. Yours grew by one in the night. The anchor stone paid for it.", "lore": true})
			anything_happened = true

	_bank_garden_unlock_if_earned()

	if not anything_happened:
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})


## v018-W2, issue #347 PROTOTYPE. Placement is the spec's own (§3.2): between
## the class-gains block and the level-ups block, so the eventual REAL bestowal
## step drops in exactly here and inherits the retroactive level chain. This
## wave it only LOGS -- flag off (the default, and every shipped run) it does
## not even read the table, and with the flag on it still grants nothing, banks
## nothing, and leaves `anything_happened` alone, so the "You sleep soundly."
## fallback and every downstream beat behave identically in both modes. The
## payload is the whole point: which rule, which counters, and why not.
func _log_system_bestowal_candidate(classes: Dictionary, accomplishments: Dictionary) -> void:
	if not WISystemBestowal.log_enabled():
		return
	_emit(WIEvents.SYSTEM_BESTOWAL_CANDIDATE, WISystemBestowal.evaluate(
		WISystemBestowal.rules(), classes, accomplishments))


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
	# sticky = "this line must not be lost" (GH#273); the queue now guarantees
	# that structurally, and `lore` makes the pointer READ-BACKABLE -- VISUAL-LOG
	# UI/QUEST-START is precisely a player left holding a quest title with no
	# person or destination to pursue.
	_emit(WIEvents.TOAST, {"text": "A Watch runner is looking for you.", "sticky": true, "lore": true})
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
