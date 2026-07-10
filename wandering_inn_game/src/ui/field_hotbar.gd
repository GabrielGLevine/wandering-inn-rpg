class_name WIFieldHotbar
extends CanvasLayer
## The overworld ("field") skill bar -- the field-mode twin of
## combat's action hotbar (combat_hud.gd). Shows the PC's KNOWN field-tagged
## skills (skills the PC actually has via `Game.sim.known_skills()`, filtered by
## skills.json `field: true`) as numbered carved slots; pressing the matching
## number key in field mode DIRECT-FIRES `Game.sim.use_skill_field(<skill>)`
## (P1's dispatch -- faced-prop parity, then `field_ambient`, then refusal). v1
## is direct-fire: press == use, no selection/aim step, so slots render with
## `selected_index == -1` (nothing highlighted), same resting state combat's
## bar uses between actions.
##
## Rendering REUSES `WIHotbar` verbatim (src/ui/hotbar.gd) -- the exact UIChrome
## 52x52 carved-slot component combat draws, so the two bars read as one visual
## grammar (spec §3). This layer owns NO slot chrome of its own: it builds the
## slot dict list and hands it to `WIHotbar.render(slots, -1)`. Field skills
## carry no `icon` id in skills.json today, so each slot falls to WIHotbar's
## text-label path (the same path combat's End Turn slot uses) rendering the
## skill's `display_name` -- a PLAIN Label (not RichText), so the bracketed name
## ("[Basic Cleaning]") is literal text and no BBCode `_bb_escape` is needed
## here (the placeholder-form escape only applies to RichText/BBCode sinks; a
## future icon/RichText addition would need it). A later art pass can add
## `icon` ids to the field skills (wi-art-and-sprites) with zero code change.
##
## VISIBILITY: a native-res CanvasLayer sibling of MessageLayer (spawned by
## main.gd's `_spawn_ui_layers`, torn down with the other UI layers on every
## world/title swap). Field-only -- hides on COMBAT_STARTED and shows again on
## UI_COMBAT_HIDDEN, the same field-only-hide idiom message_layer.gd uses for
## its hint panel (combat_screen owns its OWN hotbar; the two never coexist).
## DIALOGUE gate: this layer is added to the tree AFTER `DialoguePanel`
## (main.gd's `_spawn_ui_layers` order) and neither sets an explicit
## CanvasLayer `layer`, so at the shared default it drew ON TOP of the
## conversation panel's bottom-anchored option rows. RULING: dialogue always
## wins -- HIDE (never reposition/shift; a moving hotbar reads as jitter)
## while a conversation is open. Gated on `_dialogue_open`, tracked from the
## SAME DIALOGUE_STARTED/DIALOGUE_ENDED pair message_layer.gd's own
## `_conversation_open` already keys off (the dialogue-open state the UI
## already tracks) -- combined with `_combat_hidden` via `_apply_visibility`
## since combat and a real conversation never overlap (combat_screen ends
## any open dialogue first) but both independently want this layer hidden.
##
## RENDER TRIGGERS (bus): WORLD_READY (covers cold boot + every load/reset,
## since main.gd respawns the world -- and this layer -- on GAME_LOADED/
## GAME_RESET, re-emitting WORLD_READY) and CLASS_GAINED / CLASS_LEVEL_UP /
## CLASS_EVOLVED (a newly granted field skill appears the instant it's earned).
## Emits UI_FIELD_HOTBAR_RENDERED `{slots: <count>}` after every render so QA
## can assert the bar reflects the current known set -- including `slots: 0` for
## a classless cold start (an empty bar renders zero-width/invisible chrome; the
## event still fires, which is the least-noisy option that stays QA-observable).
##
## PLAYTEST WAVE (uiwave2, item 1): the ALWAYS-ON bottom-left legend/readout
## panel (previously rendered here) is REMOVED per user
## ruling -- the journal's loadout UI already surfaces per-skill cost/effect
## info, and the hotbar slots keep their key-hint numerals, so the panel was
## pure redundancy competing for screen space. `_readout_line`/
## `_load_combatants_catalog` (the pure TEXT GENERATORS, not the panel widget)
## are KEPT and still feed `readout_lines` on the emitted
## UI_FIELD_HOTBAR_RENDERED payload -- disclosed choice: `field_skills_loop`
## and `rogue_earn_loop` pin `readout_lines`' exact generated strings
## structurally (grepped before this change), so the smaller, honest diff is
## "keep generating the data, stop drawing it" rather than breaking those
## QA scripts' pins. A future consumer (or a re-pin wave) can drop the key
## outright once nothing asserts on it. All PANEL/FIT machinery (the panel
## Control, its Label, the wrapped-line budget/collapse-to-compact-strip
## fallback, and the per-modal show/hide gating) is deleted outright -- there
## is no more on-screen surface for any of it to fit or hide.
const HOTBAR_SCRIPT := preload("res://src/ui/hotbar.gd")

var _hotbar: WIHotbar
## The ordered field-skill ids currently shown (slot i == this[i]). The SINGLE
## source of truth for the number-key -> skill mapping: world.gd's input routing
## queries `skill_for_slot(n)` against this same list, so a pressed number can
## never diverge from what the rendered slot shows.
var _field_skills: Array = []
## The last slot-dict list `_render` built,
## cached so `set_selected` can redraw with a different highlight WITHOUT
## rebuilding the list or re-emitting UI_FIELD_HOTBAR_RENDERED (world.gd owns
## the pad-cursor index, mirroring combat's `_bar_index` idiom -- this file
## stays a pure renderer, same division of labor `_render`'s doc comment
## already establishes for slot data vs. drawing).
var _last_slots: Array = []
## CONSTRAINT: never toggle `visible` directly from either event handler --
## always go through `_apply_visibility` so the combat and dialogue gates
## compose (either one hidden hides the layer) instead of the later event
## clobbering the earlier one's hide.
var _combat_hidden := false
var _dialogue_open := false


func _ready() -> void:
	# WIHotbar anchors CENTER_BOTTOM against its parent's rect, so it needs a
	# full-rect Control host (a bare CanvasLayer has no size) -- same host
	# pattern message_layer.gd builds for its panels.
	var root := Control.new()
	UIChrome.apply_theme(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_hotbar = HOTBAR_SCRIPT.new()
	_hotbar.name = "FieldHotbarBar"
	root.add_child(_hotbar)
	ObservableBus.domain_event.connect(_on_domain_event)


## Slot n (1-based, matching the `hotbar_n` key hint) -> the field skill id, or
## "" when no field skill occupies that slot. Called by world.gd's number-key
## dispatch. Reads the SAME `_field_skills` list `_render` built, so the mapping
## is guaranteed identical to the rendered bar.
func skill_for_slot(n: int) -> String:
	var idx := n - 1
	if idx < 0 or idx >= _field_skills.size():
		return ""
	return String(_field_skills[idx])


## Controller support (S1): count of slots currently shown -- world.gd bounds
## its pad-cursor index against this before moving/confirming.
func slot_count() -> int:
	return _field_skills.size()


## Controller support (S1): redraws the SAME slot list (`_last_slots`, built
## by the last `_render()`) with a different highlighted index, for the
## `slot_prev`/`slot_next` pad idiom. `-1` clears the highlight (the v1
## direct-fire resting state `_render` itself uses). Deliberately does NOT
## re-emit UI_FIELD_HOTBAR_RENDERED -- that event means "the slot LIST
## changed", not "the highlight moved", so QA's pinned counts/payloads for it
## are unaffected by pad navigation (no canonical script uses slot_prev/next
## today; this is manual-pass-only per the plan).
func set_selected(index: int) -> void:
	_hotbar.render(_last_slots, index)


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	match type:
		WIEvents.WORLD_READY:
			# Self-heal both visibility gates: they are otherwise only ever
			# CLEARED by their matching UI_COMBAT_HIDDEN/DIALOGUE_ENDED arm
			# below, so if any combat-exit or dialogue-teardown path ever
			# skips that emit (a malformed/edge-case encounter, or any
			# future branch this presentation-only file can't see from
			# here), the bar stays hidden for the rest of the run even
			# though the player is plainly back in the field with nothing
			# open. WORLD_READY is a genuine "definitely field, not combat,
			# not mid-conversation" checkpoint -- it fires on every fresh
			# map build, cold boot, and load/reset, and never fires
			# mid-combat or mid-dialogue -- so resetting here makes a stuck
			# hide unable to survive a map transition. Re-render still runs
			# every time (unchanged behavior for the normal boot/load case).
			_combat_hidden = false
			_dialogue_open = false
			_apply_visibility()
			_render()
		# LOADOUT_CHANGED (a journal assign/unassign
		# toggle) re-renders the bar with the newly chosen subset, the same
		# trigger-list idiom as a class gain/level-up/evolution.
		WIEvents.CLASS_GAINED, WIEvents.CLASS_LEVEL_UP, WIEvents.CLASS_EVOLVED, WIEvents.LOADOUT_CHANGED:
			_render()
		WIEvents.COMBAT_STARTED:
			_combat_hidden = true
			_apply_visibility()
		WIEvents.UI_COMBAT_HIDDEN:
			_combat_hidden = false
			_apply_visibility()
		WIEvents.DIALOGUE_STARTED:
			_dialogue_open = true
			_apply_visibility()
		WIEvents.DIALOGUE_ENDED:
			_dialogue_open = false
			_apply_visibility()


## Single write site for `visible` (see the two gate vars' doc comment) --
## hidden while EITHER combat or a real conversation is open.
func _apply_visibility() -> void:
	visible = not (_combat_hidden or _dialogue_open)


## Rebuilds the bar from the PC's current known field-tagged skills and hands the
## slot list to WIHotbar. `-1` selected index == the direct-fire resting state
## (no slot highlighted). Emits UI_FIELD_HOTBAR_RENDERED after actually
## rendering, per the bus's "UI confirms it drew something" convention.
## `readout_lines` is still generated (see the file doc comment's PLAYTEST WAVE
## note) even though nothing draws it on screen any more -- QA pins its exact
## text.
func _render() -> void:
	_field_skills = _collect_field_skills()
	var slots: Array = []
	var readout_lines: Array = []
	var number := 1
	# Load the combatants catalog ONCE
	# before the per-skill loop (mirrors journal.gd's identical fix) --
	# every field-tagged skill today is exploration-only (no spell_damage
	# effect, so `_readout_line`'s `skill_effect_lines` call never actually
	# reaches the combatants.json read), but the per-row shape is identical
	# to journal.gd's, so threading it here now means a future spell-shaped
	# field skill can never regress this the same way.
	var combatants_catalog := _load_combatants_catalog()
	for id: String in _field_skills:
		var sk: Dictionary = Game.sim.skills.get(id, {})
		slots.append({
			"type": "skill",
			"id": id,
			"label": String(sk.get("display_name", id)),
			"icon": String(sk.get("icon", "")),
			"key_hint": str(number),
		})
		readout_lines.append("%d  %s" % [number, _readout_line(sk, id, combatants_catalog)])
		number += 1
	_last_slots = slots
	_hotbar.render(slots, -1)
	ObservableBus.emit_domain_event(WIEvents.UI_FIELD_HOTBAR_RENDERED, {"slots": _field_skills.size(), "readout_lines": readout_lines})


## The cost/effect summary row for one field skill: "Name —
## <L1 effect line, if any> — description". `WIEffectText.skill_effect_lines`
## is the ONLY source of the mechanical segment (never hand-composed); every
## currently-shipped field skill is exploration-only (no `effect` key), so it
## returns `[]` and this degrades to "Name — description" (the item-card
## idiom: no effect line, no dangling dash). Text generator only (the file
## doc comment's PLAYTEST WAVE note) -- feeds `readout_lines` on the emitted
## event; no longer drawn anywhere.
func _readout_line(sk: Dictionary, id: String, combatants_catalog: Array = []) -> String:
	var display := String(sk.get("display_name", id))
	var desc := String(sk.get("description", ""))
	var effect_lines := WIEffectText.skill_effect_lines(sk, combatants_catalog)
	if effect_lines.is_empty():
		return "%s — %s" % [display, desc] if desc != "" else display
	# Guard the trailing-dash case (desc
	# empty but effect_lines non-empty) the same way the branch above already
	# does -- unreachable today (every shipped description is non-empty) but
	# a future skill with no description shouldn't render "Name — effect — ".
	if desc == "":
		return "%s — %s" % [display, effect_lines[0]]
	return "%s — %s — %s" % [display, effect_lines[0], desc]


## The combatants catalog (the array under
## combatants.json's "combatants" key), loaded ONCE per `_render()` call and
## threaded through `_readout_line` -- mirrors `WIEffectText._load_combatants`'s
## own FileAccess+JSON.parse idiom (kept as a per-file copy, same M6.5
## zero-cross-dependency reasoning as `_wrapped_line_count`/`_bb_escape`
## elsewhere, rather than exposing a new formatter-side public loader). A
## missing/unparseable file degrades to `[]`, which the caller already treats
## the same as "no override" (falls back to the formatter's own default load).
func _load_combatants_catalog() -> Array:
	const COMBATANTS_PATH := "res://data/combatants.json"
	if not FileAccess.file_exists(COMBATANTS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has("combatants"):
		return (parsed as Dictionary)["combatants"]
	return []


## The field hotbar's slot list now comes straight from
## the sim's own `field_hotbar_loadout()` (moved there so the FILTER lives on
## the sim, per the plan's "sim owns state + filters" rule -- this file used
## to duplicate the known_skills()-filtered-by-field derivation inline; it now
## only asks for the already-filtered result). AUTO (loadout empty) is
## byte-identical to the pre-K2b order: innate skills first, then kit order.
func _collect_field_skills() -> Array:
	var loadout: Array = Game.sim.field_hotbar_loadout()
	# Defensive filter: a skill id no longer in `Game.sim.skills` at all (a
	# rename or data edit the sim's own field:true filter wouldn't catch,
	# since it only checks the TAG, not that the catalog entry still exists)
	# must never produce a broken/blank slot that reads as part of the bar
	# having vanished. CONSTRAINT: `_render()` builds `slots` AND
	# `skill_for_slot`'s mapping straight off this list, so filter HERE (not
	# inside `_render()`'s per-skill loop) to keep both in lockstep -- a
	# skipped id is skipped everywhere, not just in the visual row.
	return loadout.filter(func(id: Variant) -> bool: return Game.sim.skills.has(String(id)))
