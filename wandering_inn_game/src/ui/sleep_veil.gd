extends CanvasLayer
## PRESENTATION-ONLY, ZERO SIM CHANGE. The veil is a pure RENDERER over the
## world: it CONSUMES nothing (no set_input_as_handled), CHANGES no existing
## event, and never touches Game.sim state. The very same phase_changed /
## class_* / skill_unlocked / toast stream still fires beneath it — the toasts
## the veil re-voices are the identical toasts message_layer renders (they play
## out under the black), so every prior QA assertion holds untouched by
## construction. The one additive signal is UI_SLEEP_VEIL_RENDERED, a UI
## confirmation in the message_layer ui_*_rendered idiom (a brand-new type, so
## it interleaves with — never rewrites — any existing stream).
## TRIGGER: sleep() (wi_game.gd) emits phase_changed UNCONDITIONALLY as its
## first event, resetting the clock so phase() == "day" (actions_since_sleep is
## 0). A dusk/night threshold crossing during the day emits phase_changed with
## phase "dusk"/"night" and never "day" (see wi_game.gd `_tick_action` vs
## `sleep`), and no load/boot path re-emits phase_changed at all — so
## `phase_changed{phase:"day"}` is a precise, sim-change-free sleep signal. The
## announcements arrive as class_gained/class_level_up/skill_unlocked/
## class_evolved events fired SYNCHRONOUSLY right after that phase_changed in
## the same sleep() call; the veil buffers them, then a single call_deferred
## runs the reveal once the whole synchronous beat has unwound (so the buffer is
## complete). Assumes a phase config where the fresh-clock phase is "day"
## (dusk_at > 0), which is invariant for every shipped/data moods.json config.

const VEIL_LAYER := 30

const FADE_SECONDS := 0.6
const HOLD_BEFORE_TEXT := 0.35
const LINE_INTERVAL := 0.55
const LINE_FADE := 0.4
const READ_HOLD := 1.5
const EMPTY_HOLD := 0.4
const LINE_FONT_SIZE := 24

## The GDI new-game opener. A New Game opens on BLACK: the Grand Design's
## voice speaks a few arrival lines in this SAME gold-on-black device
## (reusing _black + _add_line + the layer-30 discipline above — one
## renderer, not a second), then fades into the inn. WIMain calls
## play_opener() ONLY on the GAME_RESET (fresh-world) path — never on
## Continue/load (see main.gd swap_to_world(new_game)). Under QA/headless
## it collapses to instant and emits UI_GDI_OPENER_RENDERED{lines} for
## coverage (title_flow asserts it); in real play it is SKIPPABLE —
## confirm/cancel advances line-by-line and, past the last line, fades to
## the inn, so a replaying player is never held hostage. This is the ONE
## interactive exception to the veil's "consumes nothing" invariant: the
## opener swallows ONLY confirm/cancel while it holds; the sleep path
## above still intercepts no input at all.
const OPENER_LINES: Array[String] = [
	"[Class: none.]",
	"[Skills: none.]",
	"This world watches what you do.",
	"[Begin.]",
]
const OPENER_HOLD_BEFORE_TEXT := 0.6
const OPENER_LINE_HOLD := 1.7
const OPENER_READ_HOLD := 2.2

const EPILOGUE_LINES_OPEN: Array[String] = [
	"[When you came to Liscor, there was nothing to record.]",
	"[This is no longer true.]",
]
const EPILOGUE_LINES_CLOSE: Array[String] = [
	"[The warren is sealed.]",
	"[The record remains open.]",
]
const EPILOGUE_LINK_LINE := "— The story continues at wanderinginn.com —"
const EPILOGUE_HOLD_BEFORE_TEXT := 0.8
const EPILOGUE_LINE_HOLD := 1.6
const EPILOGUE_READ_HOLD := 2.6

const _EVOLUTION_RESULT_FLAVOR := {
	"swordsman": "Your hands have chosen the sword.",
	"spearmaster": "Your hands have chosen the spear.",
	"ice_mage": "Your focus has settled on frost.",
	"fire_mage": "Your focus has settled on flame.",
	"barmaid": "You've settled into serving the room.",
	"server": "You've settled into running the city.",
}

var _class_names: Dictionary = {}
var _skill_names: Dictionary = {}
## class id -> its level-1 grant skill ids (same source classes.json the
## class_gained toast lists). A CLASS_GAINED event carries ONLY the class id;
## the sim fires NO skill_unlocked for the level-1 kit (check_level_ups starts
## at level+1), so the veil must expand the kit itself to voice the opening
## grants — matching the toast — the way later level-ups already read from
## their own skill_unlocked stream. Loaded once in _ready.
var _class_level1_grants: Dictionary = {}

var _black: ColorRect
var _line_box: VBoxContainer

var _running := false
var _reveal_queued := false
var _lines: Array[String] = []
var _sleep_has_consolidation := false

var _opener_running := false
var _opener_advance := false

var _epilogue_running := false
var _epilogue_armed := false

var _defeat_running := false
var _defeat_choice_pending := false
var _defeat_choice_result := true


func _ready() -> void:
	layer = VEIL_LAYER
	_load_display_names()

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never intercepts KEYBOARD input (zero behaviour change there -- a player
	# mashing keys under the brief black still drives the world exactly as
	# before; `world.gd`'s `_movement_gated()` gates that via
	# `veil_modal_active()`, not this Control). STOP for MOUSE (mouse-filter
	# audit, issue #57): the veil is a full-screen cover -- a click during it
	# must not leak through to a world click-to-walk/interact underneath the
	# black. `.show()`/`.hide()` below already gate this Control's own
	# visibility, so this is harmless while the veil is inactive. CanvasLayer
	# has no modulate, so fade the ColorRect's own alpha.
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	_black.hide()
	add_child(_black)

	_line_box = VBoxContainer.new()
	UIChrome.apply_theme(_line_box)
	_line_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_line_box.add_theme_constant_override("separation", 18)
	_line_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line_box)

	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.PHASE_CHANGED:
			if String(payload.get("phase", "")) == "day":
				_begin_sleep()
		WIEvents.CLASS_GAINED:
			if _running:
				var gained_id := String(payload.get("class", ""))
				_lines.append("[%s Class Obtained!]" % _class_name(gained_id))
				for sk: Variant in _class_level1_grants.get(gained_id, []):
					_lines.append("[Skill – %s Obtained!]" % _skill_name(String(sk)))
		WIEvents.CLASS_LEVEL_UP:
			if _running:
				_lines.append("[%s Level %d!]" % [_class_name(String(payload.get("class", ""))), int(payload.get("level", 0))])
		WIEvents.SKILL_UNLOCKED:
			if _running:
				_lines.append("[Skill – %s Obtained!]" % _skill_name(String(payload.get("skill", ""))))
		WIEvents.CLASS_EVOLVED:
			if _running:
				var to_id := String(payload.get("to", ""))
				_lines.append("[%s Class → %s Class!]" % [_class_name(String(payload.get("from", ""))), _class_name(to_id)])
				var flavor := String(_EVOLUTION_RESULT_FLAVOR.get(to_id, ""))
				if flavor != "":
					_lines.append(flavor)
		WIEvents.CONSOLIDATION_OFFERED:
			# The GDI ANNOUNCES the offer under the veil (user ruling: the
			# consolidation choice is delivered by the Grand Design during
			# sleep) -- one line in its own voice, riding the same collection
			# idiom as every other reveal. The CHOICE itself still happens in
			# consolidation_prompt.gd's modal AFTER the veil completes: the
			# input-dead-until-UI_SLEEP_VEIL_FINISHED contract (the
			# prompt-held rework) is untouched. Issue #87: also arms
			# `_sleep_has_consolidation`, forcing this sleep's whole reveal
			# unskippable (see the PLAIN-SLEEP SKIP guard doc comment).
			if _running:
				_sleep_has_consolidation = true
				var parents: Array = payload.get("parents", [])
				if parents.size() == 2:
					_lines.append("[%s and %s pull toward one another. The Design offers: %s.]" % [
						_class_name(String(parents[0])), _class_name(String(parents[1])),
						_class_name(String(payload.get("target", "")))])
		WIEvents.ACCOMPLISHMENT_RECORDED:
			if String(payload.get("id", "")) == "raskghar_sealed":
				_epilogue_armed = true
			if _running and String(payload.get("id", "")) == "door_awakened":
				_lines.append("[The inn has a Door. The Door has opinions.]")
			if _running and String(payload.get("id", "")) == "garden_door_unlocked":
				_lines.append("[A door opens that no one built. The Garden of Sanctuary remembers how to wait.]")
			if _running and String(payload.get("id", "")) == "resonance_grown":
				_lines.append("[The anchor stone gives up a sliver of itself. You have room for it now.]")
		WIEvents.DIALOGUE_ENDED:
			if _epilogue_armed:
				_epilogue_armed = false
				play_epilogue()


func _begin_sleep() -> void:
	if _running or _opener_running or _epilogue_running:
		return
	_running = true
	_lines = []
	_sleep_has_consolidation = false
	if not _reveal_queued:
		_reveal_queued = true
		_run_sequence.call_deferred()


func play_opener() -> void:
	if _running or _opener_running or _epilogue_running:
		return
	if _is_qa():
		_emit_opener_rendered(_opener_lines().size())
		return
	_opener_running = true
	_run_opener.call_deferred()


func _opener_lines() -> Array:
	return OPENER_LINES


func _run_opener() -> void:
	_black.modulate.a = 1.0
	_black.show()
	await _wait(OPENER_HOLD_BEFORE_TEXT)
	var lines := _opener_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		await _wait_or_advance(OPENER_READ_HOLD if last else OPENER_LINE_HOLD)
	_emit_opener_rendered(lines.size())
	await _fade(_black, 0.0)
	_opener_running = false
	_finish()


func _wait_or_advance(seconds: float) -> void:
	_opener_advance = false
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _opener_advance:
		await get_tree().process_frame


func modal_active() -> bool:
	return _running or _opener_running or _epilogue_running or _defeat_running


func _unhandled_input(event: InputEvent) -> void:
	if _defeat_choice_pending:
		if event.is_action_pressed("confirm"):
			_defeat_choice_result = true
			_defeat_choice_pending = false
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("cancel"):
			_defeat_choice_result = false
			_defeat_choice_pending = false
			get_viewport().set_input_as_handled()
		return
	if not (_running or _opener_running or _epilogue_running or _defeat_running):
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		_opener_advance = true
		get_viewport().set_input_as_handled()


func _emit_opener_rendered(count: int) -> void:
	# `race` predates the de-race-ification (the opener no longer branches
	# on it) but stays in the payload harmlessly per the copy-staging doc's
	# call — char_creation's payload_contains still pins it, no re-pin
	# needed since Game.sim.pc_race itself is unchanged.
	ObservableBus.emit_domain_event(WIEvents.UI_GDI_OPENER_RENDERED, {"lines": count, "race": Game.sim.pc_race})


func play_epilogue() -> void:
	if _running or _opener_running or _epilogue_running:
		return
	if Game.sim.accomplishment_count("post_game") > 0:
		return
	if _is_qa():
		_emit_epilogue_rendered(_epilogue_lines().size())
		_bank_post_game()
		return
	_epilogue_running = true
	_run_epilogue.call_deferred()


func _epilogue_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(EPILOGUE_LINES_OPEN)
	# Recount straight from the sim snapshot: {class_id: level}, in the order the
	# classes were earned (Dictionary insertion order). Names resolve through the
	# same data-loaded map the sleep/opener lines use, so no raw id ever leaks.
	var classes: Dictionary = Game.sim.snapshot().get("classes", {})
	for cid: Variant in classes:
		lines.append("[%s Level %d.]" % [_class_name(String(cid)), int(classes[cid])])
	lines.append_array(EPILOGUE_LINES_CLOSE)
	lines.append(EPILOGUE_LINK_LINE)
	return lines


func _run_epilogue() -> void:
	_black.show()
	await _fade(_black, 1.0)
	await _wait(EPILOGUE_HOLD_BEFORE_TEXT)
	var lines := _epilogue_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		await _wait_or_advance(EPILOGUE_READ_HOLD if last else EPILOGUE_LINE_HOLD)
	_emit_epilogue_rendered(lines.size())
	_bank_post_game()
	await _fade(_black, 0.0)
	_epilogue_running = false
	_finish()


func _bank_post_game() -> void:
	if Game.sim.accomplishment_count("post_game") == 0:
		Game.sim.record_accomplishment("post_game")


func _emit_epilogue_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_GDI_EPILOGUE_RENDERED, {"lines": count})


func play_defeat() -> void:
	if _running or _opener_running or _epilogue_running or _defeat_running:
		return
	if _is_qa():
		_emit_defeat_rendered(_defeat_lines().size())
		return
	_defeat_running = true
	_run_defeat.call_deferred()


func _defeat_lines() -> Array[String]:
	return [
		"[Defeat.]",
		"You wake at %s, the fight undone." % _map_display_name(String(Game.sim.current_map)),
		"Try again, or step more carefully.",
	]


func _map_display_name(map_id: String) -> String:
	var words := map_id.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


func _run_defeat() -> void:
	_black.modulate.a = 1.0
	_black.show()
	await _wait(HOLD_BEFORE_TEXT)
	var lines := _defeat_lines()
	for i in lines.size():
		_add_line(String(lines[i]))
		var last := i == lines.size() - 1
		await _wait_or_advance(READ_HOLD if last else LINE_INTERVAL)
	_emit_defeat_rendered(lines.size())
	_add_choice_rows()
	var continue_chosen := await _wait_for_defeat_choice()
	await _fade(_black, 0.0)
	_defeat_running = false
	_finish()
	if not continue_chosen:
		var main := get_parent()
		if main != null and main.has_method("swap_to_title"):
			main.call_deferred("swap_to_title")


func _add_choice_rows() -> void:
	var continue_row := UIChrome.make_label("Continue — %s" % WIInputHints.label("confirm"), "Menu")
	continue_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_row.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_row.gui_input.connect(_on_choice_row_input.bind(true))
	_line_box.add_child(continue_row)
	var title_row := UIChrome.make_label("Title Screen — %s" % WIInputHints.label("cancel"), "Menu")
	title_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_STOP
	title_row.gui_input.connect(_on_choice_row_input.bind(false))
	_line_box.add_child(title_row)


func _on_choice_row_input(event: InputEvent, continue_chosen: bool) -> void:
	if not _defeat_choice_pending:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_defeat_choice_result = continue_chosen
	_defeat_choice_pending = false


func _wait_for_defeat_choice() -> bool:
	_defeat_choice_pending = true
	while _defeat_choice_pending:
		await get_tree().process_frame
	return _defeat_choice_result


func _emit_defeat_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_DEFEAT_VEIL_RENDERED, {"lines": count, "map": String(Game.sim.current_map)})


## Playtest hotfix #8: NO special case for a consolidation-offering sleep any
## more -- it runs this exact same sequence as every other sleep, then emits
## UI_SLEEP_VEIL_FINISHED as its very last act. consolidation_prompt.gd holds
## a pending offer HIDDEN (input dead) until that event, so the offer
## surfaces with/after this sleep's own announcement lines, never on top of
## the black and never answerable blind. TRAP: the finished emit must fire in
## the QA-collapsed branch too, and must always come AFTER _finish() -- the
## whole ordering contract (rendered -> finished -> prompt) is pinned by
## consolidation_flow's forward-only event waits.
func _run_sequence() -> void:
	_reveal_queued = false
	var lines := _lines.duplicate()

	if _is_qa():
		# Collapsed: no visible hold — record coverage and clear the same beat so
		# no QA screenshot ever catches a black frame. The finished emit still
		# fires (after _finish, mirroring the real path below) so the
		# rendered -> finished -> prompt order is provable headless.
		_emit_rendered(lines.size())
		_finish()
		_emit_finished()
		return

	_black.show()
	await _fade(_black, 1.0)

	await _wait(HOLD_BEFORE_TEXT)
	var skippable := not _sleep_has_consolidation
	for line: String in lines:
		_add_line(line)
		if skippable:
			await _wait_or_advance(LINE_INTERVAL)
		else:
			await _wait(LINE_INTERVAL)
	_emit_rendered(lines.size())
	var final_hold := READ_HOLD if not lines.is_empty() else EMPTY_HOLD
	if skippable:
		await _wait_or_advance(final_hold)
	else:
		await _wait(final_hold)
	await _fade(_black, 0.0)
	_finish()
	_emit_finished()


func _add_line(text: String) -> void:
	var label := UIChrome.make_label(text, "Header")
	label.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.modulate.a = 0.0
	_line_box.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, LINE_FADE)


func _finish() -> void:
	_running = false
	_black.hide()
	_black.modulate.a = 0.0
	for child: Node in _line_box.get_children():
		child.queue_free()


func _emit_rendered(count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLEEP_VEIL_RENDERED, {"lines": count})


func _emit_finished() -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLEEP_VEIL_FINISHED, {})


## True while a SLEEP reveal is running or queued (from the sleep
## phase_changed until _run_sequence's finished emit) -- queried by
## consolidation_prompt.gd the instant an offer arrives, to decide
## wait-for-finished vs show-now. Sleep-mode only on purpose: the offer can
## only ever fire inside wi_game.gd's sleep() (whose UNCONDITIONAL
## phase_changed has already run _begin_sleep by the time the offer event
## lands, bus delivery being synchronous and in-order), so opener/epilogue
## states are irrelevant here -- if THEY blocked _begin_sleep (the rare race
## _begin_sleep's own guard covers), this correctly reads false and the
## prompt shows immediately rather than waiting for a finished emit that
## would never come.
func sleep_sequence_active() -> bool:
	return _running or _reveal_queued


func _fade(rect: ColorRect, to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", to_alpha, FADE_SECONDS)
	await tween.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


func _load_display_names() -> void:
	var classes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))
	if classes is Dictionary:
		for cls: Variant in (classes as Dictionary).get("classes", []):
			if cls is Dictionary and (cls as Dictionary).has("id"):
				var cid := String(cls["id"])
				_class_names[cid] = String((cls as Dictionary).get("display_name", cid))
				for lv: Variant in (cls as Dictionary).get("levels", []):
					if lv is Dictionary and int((lv as Dictionary).get("level", 0)) == 1:
						_class_level1_grants[cid] = ((lv as Dictionary).get("grants", []) as Array).duplicate()
	var skills: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	if skills is Dictionary:
		for sk: Variant in (skills as Dictionary).get("skills", []):
			if sk is Dictionary and (sk as Dictionary).has("id"):
				_skill_names[String(sk["id"])] = String((sk as Dictionary).get("display_name", sk["id"]))


func _class_name(id: String) -> String:
	if id == "":
		return id
	return String(_class_names.get(id, id))


func _skill_name(id: String) -> String:
	if id == "":
		return id
	var display := String(_skill_names.get(id, id))
	return display.trim_prefix("[").trim_suffix("]")
