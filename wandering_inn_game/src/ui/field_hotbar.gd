class_name WIFieldHotbar
extends CanvasLayer
## Three Pillars P2: the overworld ("field") skill bar -- the field-mode twin of
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
##
## RENDER TRIGGERS (bus): WORLD_READY (covers cold boot + every load/reset,
## since main.gd respawns the world -- and this layer -- on GAME_LOADED/
## GAME_RESET, re-emitting WORLD_READY) and CLASS_GAINED / CLASS_LEVEL_UP /
## CLASS_EVOLVED (a newly granted field skill appears the instant it's earned).
## Emits UI_FIELD_HOTBAR_RENDERED `{slots: <count>}` after every render so QA
## can assert the bar reflects the current known set -- including `slots: 0` for
## a classless cold start (an empty bar renders zero-width/invisible chrome; the
## event still fires, which is the least-noisy option that stays QA-observable).

const HOTBAR_SCRIPT := preload("res://src/ui/hotbar.gd")

var _hotbar: WIHotbar
## The ordered field-skill ids currently shown (slot i == this[i]). The SINGLE
## source of truth for the number-key -> skill mapping: world.gd's input routing
## queries `skill_for_slot(n)` against this same list, so a pressed number can
## never diverge from what the rendered slot shows.
var _field_skills: Array = []


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


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	match type:
		WIEvents.WORLD_READY, WIEvents.CLASS_GAINED, WIEvents.CLASS_LEVEL_UP, WIEvents.CLASS_EVOLVED:
			_render()
		WIEvents.COMBAT_STARTED:
			visible = false
		WIEvents.UI_COMBAT_HIDDEN:
			visible = true


## Rebuilds the bar from the PC's current known field-tagged skills and hands the
## slot list to WIHotbar. `-1` selected index == the direct-fire resting state
## (no slot highlighted). Emits UI_FIELD_HOTBAR_RENDERED after actually
## rendering, per the bus's "UI confirms it drew something" convention.
func _render() -> void:
	_field_skills = _collect_field_skills()
	var slots: Array = []
	var number := 1
	for id: String in _field_skills:
		var sk: Dictionary = Game.sim.skills.get(id, {})
		slots.append({
			"type": "skill",
			"id": id,
			"label": String(sk.get("display_name", id)),
			"icon": String(sk.get("icon", "")),
			"key_hint": str(number),
		})
		number += 1
	_hotbar.render(slots, -1)
	ObservableBus.emit_domain_event(WIEvents.UI_FIELD_HOTBAR_RENDERED, {"slots": _field_skills.size()})


## The PC's KNOWN skills (innate + class-granted, via the sim's own
## `known_skills()` -- the same derivation the journal reads) filtered to those
## skills.json tags `field: true`. Preserves known_skills()'s order (innate
## first, then kit order) so slot numbering is stable across renders.
func _collect_field_skills() -> Array:
	var out: Array = []
	for raw: Variant in Game.sim.known_skills():
		var id := String(raw)
		if bool((Game.sim.skills.get(id, {}) as Dictionary).get("field", false)):
			out.append(id)
	return out
