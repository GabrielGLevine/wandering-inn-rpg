extends Node
## Declarative QA driver. Event waits advance a cursor to prevent stale
## matches; whole-run absence/count assertions intentionally ignore it.

const ACTION_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"interact": KEY_E,
	"confirm": KEY_ENTER,
	"cancel": KEY_ESCAPE,
	"cycle": KEY_TAB,
	"hotbar_prime": KEY_TAB,
	"field_readout": KEY_H,
	"journal": KEY_J,
	"inventory": KEY_I,
	"hotbar_1": KEY_1,
	"hotbar_2": KEY_2,
	"hotbar_3": KEY_3,
	"hotbar_4": KEY_4,
	"hotbar_5": KEY_5,
	"hotbar_6": KEY_6,
	"hotbar_7": KEY_7,
	"hotbar_8": KEY_8,
	"hotbar_9": KEY_9,
	"end_turn": KEY_E,
}
const ACTION_JOYPAD_BUTTONS := {
	"move_up": JOY_BUTTON_DPAD_UP,
	"move_down": JOY_BUTTON_DPAD_DOWN,
	"move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT,
	"confirm": JOY_BUTTON_A,
	"cancel": JOY_BUTTON_B,
}
const SCREENSHOT_SETTLE_SECONDS := 0.15
## The two bounded waits a capture can sit in after its base settle: #119's
## live-tween drain (every capture) and the web export's browser-side PNG
## handshake (`_capture_png`'s web branch only). Named consts because
## `capture_hold_ceiling_msec` below has to add them up -- see there.
const TWEEN_DRAIN_CAP_MSEC := 3000
const WEB_CAPTURE_DEADLINE_MSEC := 10000
## Slack on the derived ceiling: frame waits, timer granularity, and the
## `_probe_dialogue_display` bookkeeping after the settle.
const CAPTURE_HOLD_MARGIN_MSEC := 2000
const CELL := 16

var _script_path := ""
## GH#196: scripts set "qa_real_paging": true to OPT OUT of the dialogue
## panel's jump-to-last-page QA contract -- required by any script that
## exercises the paging surface itself (mobile_tap_check).
var real_paging := false
var real_message_timing := false
## #506: `qa_real_presentation_timing` keeps the shipped sleep-veil, world-step,
## map-transition and combat-beat delays under the driver so a browser-touch
## route waits on real presentation. Toasts keep `real_message_timing`; a
## headless run still collapses everything.
var real_presentation_timing := false
var _out_dir := ""
## GH#324: how many evidence captures are settling right now (screenshot or
## display probe). Nonzero means "a PNG/probe is about to read the screen", and
## message_layer.gd holds its transient panels open until it drops back to
## zero. See `capture_in_flight` for why this seam exists at all.
var _capture_depth := 0
var _failures: PackedStringArray = []
var _events_seen: Array = []
var _last_purchase_buy_pos := Vector2.ZERO
var _screenshots: PackedStringArray = []
var _wait_cursor := 0
var _wants_creation_ui := false
## GH#436 fail-fast. OFF by default: the sweep wants every failure a run can
## show. ON for AUTHORING, because the driver otherwise CONTINUES past a red and
## every later step runs against whatever state the failure left -- including a
## defeat-reload after a lost fight -- which is how a genuinely broken run
## reported a single flattering failure (Act V lane, 2026-08-11). Set by
## `--fail-fast=1`, `QA_FAIL_FAST=1`, or `"fail_fast": true` in the script root.
var _fail_fast := false
var _aborted := false
var _step_index := 0
var _steps_run := 0
var _steps_total := 0
## GH#435 `--checkpoint-at=N[,N...]`: 1-based step numbers still owed a
## checkpoint. Serviced after each step, deferred past combat/dialogue.
var _checkpoint_pending: Array[int] = []


func active() -> bool:
	return not _script_path.is_empty()


## GH#324. A transient panel (toast strip, standalone line) collapses its hold
## to a 0.4s WALL-CLOCK floor under windowed QA -- a number chosen against
## `SCREENSHOT_SETTLE_SECONDS` (0.15s) back when the settle WAS that constant.
## #119 then made a capture settle 0.15s PLUS up to 3s of live-tween drain, and
## that arithmetic quietly stopped holding: with the boot music crossfade
## (1.0s) or a bark's own music duck (0.2s) still running, the capture landed
## AFTER the panel had already retired, so the PNG showed an empty slot while
## `ui_dialogue_rendered` carried the full string. That is GH#324 end to end --
## a verification-boundary defect, not a rendering one (an unattended session
## never collapses the hold and always shows the line for its authored 3s+).
## Rather than guess a larger floor (the same arithmetic, one round later),
## message_layer.gd asks THIS: while a capture is settling, a transient panel
## does not retire. Zero effect outside a windowed QA run -- both capture paths
## return before touching the counter in headless, and a real session has no
## TestDriver at all.
func capture_in_flight() -> bool:
	return _capture_depth > 0


## The panel-hold ceiling message_layer.gd brackets that wait with, DERIVED
## from the waits it actually has to outlast rather than picked by hand
## (v0.17 fix wave, adversarial finding #5: the hand-picked 6.0s was justified
## against the native settle only and was SHORTER than the web path's own
## worst case -- 0.15s + 3s drain + a 10s browser handshake ~= 13.2s -- so any
## slow web shot silently re-opened the #324 race with no failure signal).
## Adding a wait to a capture now moves this number automatically.
func capture_hold_ceiling_msec() -> int:
	var web_msec := WEB_CAPTURE_DEADLINE_MSEC if OS.has_feature("web") else 0
	return int(SCREENSHOT_SETTLE_SECONDS * 1000.0) + TWEEN_DRAIN_CAP_MSEC \
			+ web_msec + CAPTURE_HOLD_MARGIN_MSEC


func wants_creation_ui() -> bool:
	return _wants_creation_ui


func _ready() -> void:
	_out_dir = QAPaths.out_dir()
	_script_path = String(QAPaths.user_args().get("qa-script", ""))
	if _script_path.is_empty() and OS.has_feature("web"):
		var js_cfg: Variant = JavaScriptBridge.eval("window.__WI_QA__ ? window.__WI_QA__.script : ''", true)
		_script_path = String(js_cfg) if js_cfg != null else ""
	if _script_path.is_empty():
		set_process(false)
		return
	_fail_fast = _truthy(String(QAPaths.user_args().get("fail-fast", ""))) \
			or _truthy(OS.get_environment("QA_FAIL_FAST"))
	for raw: String in String(QAPaths.user_args().get("checkpoint-at", "")).split(",", false):
		if raw.strip_edges().is_valid_int():
			_checkpoint_pending.append(int(raw.strip_edges()))
	ObservableBus.domain_event.connect(_on_domain_event)
	_run.call_deferred()


func _on_domain_event(type: String, payload: Dictionary) -> void:
	var event := {"type": type, "payload": payload}
	if OS.has_feature("web"):
		event["browser_time_ms"] = JavaScriptBridge.eval("performance.now()", true)
		if type == "ui_purchase_confirm_rendered":
			var panel := get_tree().root.find_child("PurchaseConfirm", true, false)
			var buy_rect: Rect2 = panel.call("row_rect", 1)
			var buy_pos := get_viewport().get_screen_transform() * buy_rect.get_center()
			event["buy_window_pos"] = [buy_pos.x, buy_pos.y]
	_events_seen.append(event)


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_script_path))
	if parsed == null or not (parsed is Dictionary) or not parsed.has("steps"):
		_fail("could not parse qa script: " + _script_path)
		_finish()
		return
	_wants_creation_ui = bool(parsed.get("creation_ui", false))
	real_paging = bool(parsed.get("qa_real_paging", false))
	real_presentation_timing = bool(parsed.get("qa_real_presentation_timing", false))
	real_message_timing = bool(parsed.get("qa_real_message_timing", false)) \
		or _truthy(String(QAPaths.user_args().get("qa-real-message-timing", "")))
	_fail_fast = _fail_fast or bool(parsed.get("fail_fast", false))
	_install_fixture_saves(parsed.get("fixture_save"))
	if not bool(parsed.get("starts_at_title", false)):
		await _skip_title()
	var steps: Array = parsed["steps"]
	_steps_total = steps.size()
	for i: int in steps.size():
		_step_index = i
		_steps_run = i + 1
		await _execute(steps[i] as Dictionary)
		_service_checkpoints(i + 1)
		if _fail_fast and not _failures.is_empty():
			_aborted = true
			print("QA_FAIL_FAST: aborted at step %d/%d (action=%s) -- %d step(s) NOT run" % [
				i + 1, _steps_total, String((steps[i] as Dictionary).get("action", "?")),
				_steps_total - (i + 1)])
			break
	_finish()


func _install_fixture_saves(spec: Variant) -> void:
	if spec == null:
		return
	var entries: Array = []
	if spec is String:
		entries.append({"fixture": spec, "slot": "manual"})
	elif spec is Array:
		for e: Variant in spec:
			if not (e is Dictionary):
				_fail("fixture_save: array entries must be {fixture, slot} Dictionaries")
				return
			entries.append(e as Dictionary)
	else:
		_fail("fixture_save: expected a String or Array, got " + str(spec))
		return
	for entry: Dictionary in entries:
		var fixture := String(entry["fixture"])
		var slot := String(entry.get("slot", "manual"))
		# GH#435: a bare name still resolves under qa/fixtures/, but a PATH
		# (anything with a slash or a .json suffix) is taken literally, so a
		# scratch authoring script can point `fixture_save` straight at a
		# `dump_checkpoint` artifact in qa_output/ without a throwaway file
		# landing in qa/fixtures/ -- where test_fixture_coherence would then
		# validate it as if it were a shipped story position.
		var src_path := fixture
		if not (fixture.contains("/") or fixture.ends_with(".json")):
			src_path = "res://qa/fixtures/%s.json" % fixture
		if not FileAccess.file_exists(src_path):
			_fail("fixture_save: no such fixture: " + fixture)
			continue
		var contents := FileAccess.get_file_as_string(src_path)
		DirAccess.make_dir_recursive_absolute("user://saves")
		var dst := FileAccess.open("user://saves/%s.json" % slot, FileAccess.WRITE)
		if dst == null:
			_fail("fixture_save: could not write user://saves/%s.json" % slot)
			continue
		dst.store_string(contents)
		dst.close()


func _skip_title() -> void:
	_inject_action("confirm")
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_for_event("ui_title_rendered", 5.0)
	var new_game_index := _events_seen.size()
	_inject_action("confirm")
	await get_tree().process_frame
	await get_tree().process_frame
	var i := _events_seen.size() - 1
	while i >= new_game_index:
		if _events_seen[i]["type"] == "game_reset":
			_events_seen.remove_at(i)
		i -= 1


func _execute(step: Dictionary) -> void:
	var required_args: Dictionary = step.get("when_user_args", {})
	for arg_name: String in required_args:
		if QAPaths.user_args().get(arg_name, "") != String(required_args[arg_name]):
			return
	match String(step["action"]):
		"wait_frames":
			for i in int(step.get("frames", 1)):
				await get_tree().process_frame
		"press":
			if String(step.get("device", "keyboard")) == "gamepad":
				_inject_gamepad_action(String(step["name"]))
			else:
				_inject_action(String(step["name"]))
			await get_tree().process_frame
			await get_tree().process_frame
		"press_field_skill":
			var cast_skill := String(step["skill"])
			var slot_idx: int = (Game.sim.field_hotbar_loadout() as Array).find(cast_skill)
			if slot_idx == -1:
				_fail("press_field_skill: not on the bar: " + cast_skill)
			else:
				_inject_action("hotbar_%d" % (slot_idx + 1))
				await get_tree().process_frame
				await get_tree().process_frame
		"move":
			for i in int(step.get("steps", 1)):
				_inject_action("move_" + String(step["direction"]))
				await get_tree().process_frame
				await get_tree().process_frame
		"click":
			var cell := Vector2i(int(step["cell"][0]), int(step["cell"][1]))
			var world_pos := Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5
			var screen_pos: Variant = _world_to_screen(world_pos)
			if screen_pos == null:
				_fail("click: could not resolve Main.world_to_screen")
			else:
				_inject_mouse_click(screen_pos as Vector2)
			await get_tree().process_frame
			await get_tree().process_frame
		"drag_journal_body":
			# a4 #216: drag UP inside the journal body to scroll DOWN. Reads
			# the body rect from the Journal node, drags from 70% to 25% of
			# its height at mid-width.
			var jn := get_tree().root.find_child("Journal", true, false)
			if jn == null:
				_fail("drag_journal_body: Journal node not found")
			else:
				var br: Rect2 = jn.call("body_rect")
				if br.size == Vector2.ZERO:
					_fail("drag_journal_body: body has no rendered rect")
				else:
					var cx := br.position.x + br.size.x * 0.5
					_inject_drag(Vector2(cx, br.position.y + br.size.y * 0.7), Vector2(cx, br.position.y + br.size.y * 0.25), int(step.get("steps", 8)))
			await get_tree().process_frame
			await get_tree().process_frame
		"tap_journal_body":
			# v0.15 Task 2.1 fix round 1: the POSITIVE control for the pan/tap
			# latch. Presses and releases at ONE point -- the exact point
			# `drag_journal_body` above lets go at (mid-width, 25% of body
			# height), so the two legs aim identically and differ only in whether
			# the gesture moved. Aimed off `body_rect` for the same reason the
			# drag is: a hard-coded coordinate rots the moment the panel or the
			# viewport budget shifts.
			var tap_jn := get_tree().root.find_child("Journal", true, false)
			if tap_jn == null:
				_fail("tap_journal_body: Journal node not found")
			else:
				var tap_br: Rect2 = tap_jn.call("body_rect")
				if tap_br.size == Vector2.ZERO:
					_fail("tap_journal_body: body has no rendered rect")
				else:
					_inject_mouse_click(Vector2(
						tap_br.position.x + tap_br.size.x * 0.5,
						tap_br.position.y + tap_br.size.y * float(step.get("at_height_fraction", 0.25))))
			await get_tree().process_frame
			await get_tree().process_frame
		"assert_journal_scrolled":
			var jn2 := get_tree().root.find_child("Journal", true, false)
			if jn2 == null:
				_fail("assert_journal_scrolled: Journal node not found")
			else:
				var val: float = jn2.call("body_scroll_value")
				var want_gt := float(step.get("greater_than", 0.0))
				if val <= want_gt:
					_fail("assert_journal_scrolled: scroll value %.1f not > %.1f" % [val, want_gt])
			await get_tree().process_frame
		"drag":
			# a4 #216: press at `from`, step motion (button held) to `to`,
			# release — a mouse-drag the journal body reads as a scroll pan.
			var d_from := Vector2(float(step["from"][0]), float(step["from"][1]))
			var d_to := Vector2(float(step["to"][0]), float(step["to"][1]))
			_inject_drag(d_from, d_to, int(step.get("steps", 8)))
			await get_tree().process_frame
			await get_tree().process_frame
		"click_screen":
			var pos := Vector2(float(step["pos"][0]), float(step["pos"][1]))
			_inject_mouse_click(pos)
			await get_tree().process_frame
			await get_tree().process_frame
		"click_slot":
			var slot_n := int(step["slot"])
			var hb := _resolve_hotbar_node()
			if hb == null:
				_fail("click_slot: no live hotbar node found")
			else:
				var rect: Rect2 = hb.call("slot_rect", slot_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_slot: slot %d has no rendered rect" % slot_n)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_field_readout":
			var field_hotbar := get_tree().root.find_child("FieldHotbar", true, false)
			if field_hotbar == null:
				_fail("click_field_readout: FieldHotbar node not found")
			else:
				var toggle_rect: Rect2 = field_hotbar.call("toggle_rect")
				if toggle_rect.size == Vector2.ZERO:
					_fail("click_field_readout: toggle has no rendered rect")
				else:
					_inject_mouse_click(toggle_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_pause_row":
			var row_n := int(step["row"])
			var pm := get_tree().root.find_child("PauseMenu", true, false)
			if pm == null:
				_fail("click_pause_row: PauseMenu node not found")
			else:
				var rect: Rect2 = pm.call("row_rect", row_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_pause_row: row %d has no rendered rect" % row_n)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_pause_slot_row":
			var slot_row_n := int(step["row"])
			var slot_pm := get_tree().root.find_child("PauseMenu", true, false)
			if slot_pm == null:
				_fail("click_pause_slot_row: PauseMenu node not found")
			else:
				var slot_rect: Rect2 = slot_pm.call("slot_row_rect", slot_row_n - 1)
				if slot_rect.size == Vector2.ZERO:
					_fail("click_pause_slot_row: row %d has no rendered rect" % slot_row_n)
				else:
					_inject_mouse_click(slot_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_confirm_chip":
			var cs := get_tree().root.find_child("CombatScreen", true, false)
			if cs == null:
				_fail("click_confirm_chip: CombatScreen node not found")
			else:
				var chip_rect: Rect2 = cs.call("confirm_chip_rect")
				if chip_rect.size == Vector2.ZERO:
					_fail("click_confirm_chip: chip has no rendered rect (not armed?)")
				else:
					_inject_mouse_click(chip_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_char_creation_begin":
			var ccb := get_tree().root.find_child("CharCreation", true, false)
			if ccb == null:
				_fail("click_char_creation_begin: CharCreation node not found")
			else:
				var begin_rect: Rect2 = ccb.call("begin_button_rect")
				if begin_rect.size == Vector2.ZERO:
					_fail("click_char_creation_begin: Begin button has no rendered rect")
				else:
					_inject_mouse_click(begin_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_char_creation_card":
			var card_n := int(step["card"])
			var cc := get_tree().root.find_child("CharCreation", true, false)
			if cc == null:
				_fail("click_char_creation_card: CharCreation node not found")
			else:
				var card_rect: Rect2 = cc.call("card_rect", card_n - 1)
				if card_rect.size == Vector2.ZERO:
					_fail("click_char_creation_card: card %d has no rendered rect" % card_n)
				else:
					_inject_mouse_click(card_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_dialogue_option":
			var opt_n := int(step["option"])
			var dp := get_tree().root.find_child("DialoguePanel", true, false)
			if dp == null:
				_fail("click_dialogue_option: DialoguePanel node not found")
			else:
				var rect: Rect2 = dp.call("option_rect", opt_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_dialogue_option: option %d has no rendered rect" % opt_n)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"touch_screen":
			# #503 REAL-TOUCH TIER: on the web build the tap is performed by the
			# Playwright runner (page.touchscreen.tap) at the WINDOW coordinate
			# this position maps to -- a genuine browser touch, never an
			# engine-injected event. Natively there is no browser, so the tap is
			# EMULATED via the mouse-click injector and labelled so in the
			# `qa_touch` event (real:false). No keyboard/mouse fallback exists on
			# web: an unserviced request FAILS the step (see _touch_at).
			await _touch_at(Vector2(float(step["pos"][0]), float(step["pos"][1])), "screen")
		"touch_cell":
			await _touch_world_cell(Vector2i(int(step.cell[0]), int(step.cell[1])))
		"touch_walk":
			await _touch_walk(Vector2i(int(step.to[0]), int(step.to[1])))
		"wait_touch_ready":
			await _wait_touch_ready()
		"touch_field_skill":
			await _touch_field_skill(String(step.skill))
		"touch_talk":
			await _touch_talk(Vector2i(int(step.cell[0]), int(step.cell[1])), String(step.get("conversation", "")))
		"touch_dialogue_continue":
			await _touch_dialogue_continue()
		"touch_combat_slot":
			await _touch_combat_slot(String(step.slot))
		"touch_combat_rounds":
			await _touch_combat_rounds(int(step.get("max_turns", 40)))
		"touch_inventory_item":
			await _touch_inventory_item(String(step.item))
		"touch_combat_dismiss":
			var cs := _combat_screen_node()
			var board: Rect2 = cs.board_view_rect() if cs != null else Rect2()
			if _combat_mode() != MODE_BANNER:
				_fail("touch_combat_dismiss: no result banner is showing (mode %d); a board contact would move or aim instead" % _combat_mode())
			elif not board.has_area():
				_fail("touch_combat_dismiss: no rendered combat board")
			else:
				await _touch_at(board.get_center(), "touch_combat_dismiss")
		"touch_creation_control":
			var control := String(step.control)
			var method := {"back": "back_button_rect", "begin": "begin_button_rect", "card": "card_rect", "choice": "choice_row_rect"}
			if not method.has(control):
				_fail("touch_creation_control: unknown control " + control)
			else:
				await _touch_rect_of("CharCreation", method[control], step.get("index"), "touch_creation_" + control)
		"touch_hotbar_slot":
			var hotbar := _resolve_hotbar_node()
			if hotbar == null:
				_fail("touch_hotbar_slot: no live hotbar node found")
			else:
				var rect: Rect2 = hotbar.call("slot_rect", int(step["slot"]) - 1)
				if rect.size == Vector2.ZERO:
					_fail("touch_hotbar_slot: slot has no rendered rect")
				else:
					await _touch_at(rect.get_center(), "touch_hotbar_slot")
		"touch_title_row":
			await _touch_rect_of("TitleScreen", "row_rect", int(step["row"]) - 1, "touch_title_row")
		"touch_dialogue_option":
			await _touch_rect_of("DialoguePanel", "option_rect", int(step["option"]) - 1, "touch_dialogue_option", step.get("gesture", {}))
		"touch_field_chip":
			await _touch_rect_of("FieldChips", "chip_rect", String(step["chip"]), "touch_field_chip")
		"touch_field_details":
			var field := get_tree().root.find_child("FieldHotbar", true, false)
			if field == null or field.toggle_rect().size == Vector2.ZERO:
				_fail("touch_field_details: no visible details control")
			else:
				await _touch_at(field.toggle_rect().get_center(), "touch_field_details")
		"touch_combat_control":
			await _touch_rect_of("CombatScreen", "mobile_control_rect", String(step["control"]), "touch_combat_control", step.get("gesture", {}))
		"touch_combat_pages":
			await _touch_combat_pages(step)
		"touch_field_pages":
			await _touch_field_pages()
		"touch_scroll_field_to_end":
			await _touch_scroll_field_to_end()
		"touch_inventory_row":
			await _touch_rect_of("Inventory", "item_row_rect", int(step["row"]) - 1, "touch_inventory_row", step.get("gesture", {}))
		"touch_journal_skill":
			await _touch_rect_of("Journal", "skill_row_rect", int(step["index"]), "touch_journal_skill", step.get("gesture", {}))
		"touch_journal_tab":
			await _touch_rect_of("Journal", "tab_rect", String(step["tab"]), "touch_journal_tab")
		"touch_inventory_equipment":
			var inventory := get_tree().root.find_child("Inventory", true, false)
			if inventory == null or inventory.equipment_rect().size == Vector2.ZERO:
				_fail("touch_inventory_equipment: no visible equipment control")
			else:
				await _touch_at(inventory.equipment_rect().get_center(), "touch_inventory_equipment")
		"touch_scroll_inventory", "touch_scroll_equipment":
			var action := String(step["action"])
			var inventory := get_tree().root.find_child("Inventory", true, false)
			if inventory == null:
				_fail("touch_scroll_inventory: Inventory is absent")
			else:
				var rect: Rect2 = inventory.visible_content_rect() if action == "touch_scroll_equipment" else inventory.list_rect()
				var start := rect.position + rect.size * Vector2(0.5, 0.8)
				var end := rect.position + rect.size * Vector2(0.5, 0.2)
				var window_end := get_viewport().get_screen_transform() * end
				await _touch_at(start, action, {"drag": true, "end_x": window_end.x, "end_y": window_end.y})
		"assert_equipment_bottom_visible":
			await _settle_for_capture()
			var inventory := get_tree().root.find_child("Inventory", true, false)
			if inventory == null or not bool(inventory.get("_equipment_expanded")):
				_fail("assert_equipment_bottom_visible: equipment is not expanded")
			else:
				var labels: Array = inventory.get("_accessory_labels")
				var last: Label = labels.back()
				if not inventory.visible_content_rect().encloses(last.get_global_rect()):
					_fail("assert_equipment_bottom_visible: last accessory is clipped")
		"touch_settings_row":
			await _touch_rect_of("SettingsPanel", "row_rect", int(step["row"]) - 1, "touch_settings_row")
		"touch_purchase_row":
			await _touch_rect_of("PurchaseConfirm", "row_rect", 1 if String(step["row"]) == "buy" else 0, "touch_purchase_row", step.get("gesture", {}))
		"click_purchase_row":
			# #504: tap a row of the purchase confirmation -- "cancel" or "buy".
			# Reads the modal's own rendered rect, so a tap before the modal is
			# armed proves the swallow contract rather than passing vacuously.
			var purchase_row := 1 if String(step["row"]) == "buy" else 0
			var pc := get_tree().root.find_child("PurchaseConfirm", true, false)
			if pc == null:
				_fail("click_purchase_row: PurchaseConfirm node not found")
			else:
				var rect: Rect2 = pc.call("row_rect", purchase_row)
				if rect.size == Vector2.ZERO:
					_fail("click_purchase_row: %s row has no rendered rect" % String(step["row"]))
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_settings_row":
			var settings_row_n := int(step["row"])
			var sp := get_tree().root.find_child("SettingsPanel", true, false)
			if sp == null:
				_fail("click_settings_row: SettingsPanel node not found")
			else:
				var rect: Rect2 = sp.call("row_rect", settings_row_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_settings_row: row %d has no rendered rect" % settings_row_n)
				else:
					# a4 #216: optional "half" taps the left/right of the row
					# (volume +/- decrement/increment); default centre = activate.
					var half := String(step.get("half", ""))
					var pt: Vector2 = rect.get_center()
					if half == "left":
						pt = Vector2(rect.position.x + rect.size.x * 0.25, rect.get_center().y)
					elif half == "right":
						pt = Vector2(rect.position.x + rect.size.x * 0.75, rect.get_center().y)
					_inject_mouse_click(pt)
			await get_tree().process_frame
			await get_tree().process_frame
		"click_credits_link":
			var link_key := String(step["key"])
			var spc := get_tree().root.find_child("SettingsPanel", true, false)
			if spc == null:
				_fail("click_credits_link: SettingsPanel node not found")
			else:
				var rect: Rect2 = spc.call("credits_link_rect", link_key)
				if rect.size == Vector2.ZERO:
					_fail("click_credits_link: link '%s' has no rendered rect" % link_key)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_credits_back":
			var spb := get_tree().root.find_child("SettingsPanel", true, false)
			if spb == null:
				_fail("click_credits_back: SettingsPanel node not found")
			else:
				var rect: Rect2 = spb.call("credits_back_rect")
				if rect.size == Vector2.ZERO:
					_fail("click_credits_back: back label has no rendered rect")
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_playtest_page":
			var tsp := get_tree().root.find_child("TitleScreen", true, false)
			if tsp == null:
				_fail("click_playtest_page: TitleScreen node not found")
			else:
				var rect: Rect2 = tsp.call("playtest_page_rect")
				if rect.size == Vector2.ZERO:
					_fail("click_playtest_page: page label has no rendered rect")
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_playtest_back":
			var tsb := get_tree().root.find_child("TitleScreen", true, false)
			if tsb == null:
				_fail("click_playtest_back: TitleScreen node not found")
			else:
				var rect: Rect2 = tsb.call("playtest_back_rect")
				if rect.size == Vector2.ZERO:
					_fail("click_playtest_back: back label has no rendered rect")
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"assert_playtest_page":
			var tsa := get_tree().root.find_child("TitleScreen", true, false)
			if tsa == null:
				_fail("assert_playtest_page: TitleScreen node not found")
			else:
				var got: int = tsa.call("playtest_cursor_page")
				var want := int(step["equals"])
				if got != want:
					_fail("assert_playtest_page: page %d != %d" % [got, want])
			await get_tree().process_frame
		"click_title_row":
			var title_row_n := int(step["row"])
			var ts := get_tree().root.find_child("TitleScreen", true, false)
			if ts == null:
				_fail("click_title_row: TitleScreen node not found")
			else:
				var rect: Rect2 = ts.call("row_rect", title_row_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_title_row: row %d has no rendered rect" % title_row_n)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_journal_skill":
			var jn := get_tree().root.find_child("Journal", true, false)
			if jn == null:
				_fail("click_journal_skill: Journal node not found")
			else:
				jn.call("click_skill_row", int(step["flat_index"]))
			await get_tree().process_frame
			await get_tree().process_frame
		"click_journal_tab":
			# Issue #209: tap one of the journal's three tab labels
			# (Quests/Skills/History) by its rendered rect, mirroring the
			# credits/playtest label-tap pattern. `tab` is the tab id string.
			var jt := get_tree().root.find_child("Journal", true, false)
			if jt == null:
				_fail("click_journal_tab: Journal node not found")
			else:
				var tab_rect: Rect2 = jt.call("tab_rect", String(step["tab"]))
				if tab_rect.size == Vector2.ZERO:
					_fail("click_journal_tab: tab '%s' has no rendered rect" % String(step["tab"]))
				else:
					_inject_mouse_click(tab_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_inventory_row":
			var inv_row_n := int(step["row"])
			var inv := get_tree().root.find_child("Inventory", true, false)
			if inv == null:
				_fail("click_inventory_row: Inventory node not found")
			else:
				var rect: Rect2 = inv.call("item_row_rect", inv_row_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_inventory_row: row %d has no rendered rect" % inv_row_n)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"drag_inventory_list":
			# GH#334 note 1: drag UP inside the carried list to scroll DOWN --
			# `drag_journal_body`'s twin, aimed off the list's own rendered rect
			# for the same reason (a hard-coded coordinate rots the moment the
			# panel or the viewport budget shifts). The gesture ends ON a row, so
			# it is simultaneously the proof that the pan-slop latch keeps
			# `_confirm()` from firing on the row it let go over.
			var dinv := get_tree().root.find_child("Inventory", true, false)
			if dinv == null:
				_fail("drag_inventory_list: Inventory node not found")
			else:
				var lr: Rect2 = dinv.call("list_rect")
				if lr.size == Vector2.ZERO:
					_fail("drag_inventory_list: list has no rendered rect")
				else:
					var lcx := lr.position.x + lr.size.x * 0.5
					_inject_drag(
						Vector2(lcx, lr.position.y + lr.size.y * float(step.get("from_height_fraction", 0.7))),
						Vector2(lcx, lr.position.y + lr.size.y * float(step.get("to_height_fraction", 0.25))),
						int(step.get("steps", 8)))
			await get_tree().process_frame
			await get_tree().process_frame
		"assert_inventory_scrolled":
			var sinv := get_tree().root.find_child("Inventory", true, false)
			if sinv == null:
				_fail("assert_inventory_scrolled: Inventory node not found")
			else:
				var sval: float = sinv.call("list_scroll_value")
				var sw_gt := float(step.get("greater_than", 0.0))
				if sval <= sw_gt:
					_fail("assert_inventory_scrolled: scroll value %.1f not > %.1f" % [sval, sw_gt])
			await get_tree().process_frame
		"click_field_chip":
			var chip_name := String(step["chip"])
			var fc := get_tree().root.find_child("FieldChips", true, false)
			if fc == null:
				_fail("click_field_chip: FieldChips node not found")
			else:
				var chip_rect: Rect2 = fc.call("chip_rect", chip_name)
				if chip_rect.size == Vector2.ZERO:
					_fail("click_field_chip: chip '%s' has no rendered rect" % chip_name)
				else:
					_inject_mouse_click(chip_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"move_diag":
			for i in int(step.get("steps", 1)):
				_inject_diag(String(step["a"]), String(step["b"]))
				await get_tree().process_frame
				await get_tree().process_frame
		"type_text":
			var text := String(step["text"])
			for i in text.length():
				_inject_unicode(text[i])
				await get_tree().process_frame
				await get_tree().process_frame
		"wait_for_event":
			await _wait_for_event(String(step["type"]), float(step.get("timeout_sec", 5.0)), step.get("payload_contains", {}), bool(step.get("from_start", false)))
		"screenshot":
			await _screenshot(String(step["name"]))
		"assert_message_layout":
			await _assert_message_layout(String(step.get("kind", "dialogue")))
		"assert_dialogue_layout":
			await _assert_dialogue_layout()
		"assert_dialogue_displayed":
			await _assert_dialogue_displayed(step)
		"assert_field_layout":
			await _assert_field_layout()
		"assert_combat_layout":
			await _assert_combat_layout(step)
		"assert_panel_layout":
			await _assert_panel_layout(String(step["panel"]))
		"assert_state":
			_assert_state(step)
		"assert_field_skill_absent":
			# #398 P5 review L5: the NEGATIVE of `press_field_skill`, reading the
			# very same `field_hotbar_loadout()` source of truth, so a weapon-gated
			# Skill's absence from the bar is PROVEN rather than inferred from a
			# downstream refusal. Falsifiable by construction: equip the matching
			# weapon family in the fixture and this assert reds.
			var absent_field_skill := String(step["skill"])
			if (Game.sim.field_hotbar_loadout() as Array).has(absent_field_skill):
				_fail("assert_field_skill_absent: %s is on the field bar" % absent_field_skill)
		"assert_event_logged":
			if not _has_event(String(step["type"]), step.get("payload_contains", {})):
				_fail("expected event was never emitted: " + String(step["type"]))
		"assert_event_absent":
			if _has_event(String(step["type"]), step.get("payload_contains", {})):
				_fail("expected event to be absent but it was emitted: " + String(step["type"]))
		"assert_event_count":
			var got := _count_events(String(step["type"]), step.get("payload_contains", {}))
			if got != int(step["count"]):
				_fail("event count mismatch for %s: expected %d, got %d" % [String(step["type"]), int(step["count"]), got])
		"assert_save_exists":
			var slot := String(step["slot"])
			if not FileAccess.file_exists("user://saves/%s.json" % slot):
				_fail("expected save slot to exist: " + slot)
		"assert_settings_file_exists":
			if not FileAccess.file_exists("user://settings.cfg"):
				_fail("expected user://settings.cfg to exist")
		"assert_audio_bus_send":
			var send_bus_name := String(step["bus"])
			var send_idx := AudioServer.get_bus_index(send_bus_name)
			if send_idx == -1:
				_fail("assert_audio_bus_send: no such bus: " + send_bus_name)
			else:
				var got_send := AudioServer.get_bus_send(send_idx)
				var expected_send := String(step["sends_to"])
				if got_send != expected_send:
					_fail("assert_audio_bus_send: bus %s sends to %s, expected %s" % [send_bus_name, got_send, expected_send])
		"set_audio_bus_volume":
			var audio := get_node_or_null("/root/WIAudio")
			if audio == null:
				_fail("set_audio_bus_volume: WIAudio autoload missing")
			else:
				audio.set_bus_volume(String(step["bus"]), float(step["value_0_to_10"]))
		"assert_audio_bus_volume":
			var vol_bus_name := String(step["bus"])
			var vol_idx := AudioServer.get_bus_index(vol_bus_name)
			if vol_idx == -1:
				_fail("assert_audio_bus_volume: no such bus: " + vol_bus_name)
			else:
				var expected_linear := clampf(float(step["value_0_to_10"]), 0.0, 10.0) / 10.0
				var expected_db := linear_to_db(maxf(expected_linear, 0.0001))
				var got_db := AudioServer.get_bus_volume_db(vol_idx)
				if not is_equal_approx(got_db, expected_db):
					_fail("assert_audio_bus_volume: bus %s expected %.4f db, got %.4f db" % [vol_bus_name, expected_db, got_db])
		"assert_audio_bus_volume_db":
			var db_bus_name := String(step["bus"])
			var db_idx := AudioServer.get_bus_index(db_bus_name)
			if db_idx == -1:
				_fail("assert_audio_bus_volume_db: no such bus: " + db_bus_name)
			else:
				var expected_db_raw := float(step["expected_db"])
				var got_db_raw := AudioServer.get_bus_volume_db(db_idx)
				if not is_equal_approx(got_db_raw, expected_db_raw):
					_fail("assert_audio_bus_volume_db: bus %s expected %.4f db, got %.4f db" % [db_bus_name, expected_db_raw, got_db_raw])
		"assert_settings_value":
			var settings_path := String(step["path"])
			var settings_got: Variant
			match settings_path:
				"reduce_motion":
					settings_got = WISettings.reduce_motion()
				"fullscreen":
					settings_got = WISettings.is_fullscreen()
				"text_scale_step":
					settings_got = WISettings.text_scale_step()
				"combat_speed_step":
					settings_got = WISettings.combat_speed_step()
				"field_readout_expanded":
					settings_got = WISettings.field_readout_expanded()
				_:
					_fail("assert_settings_value: unknown path " + settings_path)
					settings_got = null
			if settings_got != null and not _loosely_equal(settings_got, step["equals"]):
				_fail("assert_settings_value: %s expected %s, got %s" % [settings_path, str(step["equals"]), str(settings_got)])
		"resize_browser":
			await _resize_browser(step)
		"set_text_scale_step":
			WISettings.set_text_scale_step(int(step["step"]))
			await get_tree().process_frame
			await get_tree().process_frame
		"assert_world_to_screen_camera_aware":
			_assert_world_to_screen_camera_aware()
		"assert_world_labels_in_view":
			_assert_world_labels_in_view(step)
		"combat_autoplay":
			await _combat_autoplay(
				int(step.get("max_turns", 200)),
				String(step.get("policy", WICombatPolicies.DUMB))
			)
		"load_all_resources":
			_load_all_resources()
		"teleport":
			Game.sim.transition(String(step["map"]), Vector2i(int(step["cell"][0]), int(step["cell"][1])))
			await get_tree().process_frame
			await get_tree().process_frame
		"combat_set_cells":
			var live_combat: WICombat = Game.sim.combat
			if live_combat == null:
				_fail("combat_set_cells: no live combat")
			else:
				for cid: String in (step["cells"] as Dictionary):
					if not live_combat.combatants.has(cid):
						_fail("combat_set_cells: unknown combatant id: " + cid)
						break
					var want: Array = step["cells"][cid]
					var want_cell := Vector2i(int(want[0]), int(want[1]))
					if not live_combat.is_cell_free(want_cell):
						_fail("combat_set_cells: cell %s not free for %s" % [str(want_cell), cid])
						break
					live_combat.combatants[cid][WIKeys.CELL] = want_cell
					live_combat._emit(WIEvents.COMBATANT_MOVED, {"id": cid, "cell": [want_cell.x, want_cell.y]})
			await get_tree().process_frame
			await get_tree().process_frame
		"install_fixture":
			_install_fixture_saves([{"fixture": String(step["fixture"]), "slot": String(step.get("slot", "auto"))}])
			await get_tree().process_frame
		"toggle_overlay":
			# GH#279: node-call step (drag_journal_body precedent) -- no
			# input-map change; the human keybind lives in the overlay.
			WIDebugOverlay.toggle()
			await get_tree().process_frame
			await get_tree().process_frame
		"reload_data":
			# GH#278: rebuild the sim from disk JSON via the save round-trip.
			# expect:false proves the refusal leg (combat/dialogue/
			# consolidation); the refusal must be observable, so scripts
			# pair it with an assert on the refusal TOAST.
			var reload_expect: bool = bool(step.get("expect", true))
			var reload_ok: bool = Game.reload_data()
			if reload_ok != reload_expect:
				_fail("reload_data returned %s, expected %s" % [reload_ok, reload_expect])
			await get_tree().process_frame
			await get_tree().process_frame
		"dump_state":
			# GH#436: the SANCTIONED form of the deliberately-failing
			# `assert_state` probe. That idiom answered ONE unknown per full run
			# and reported it as a failure string; this answers all of them, in
			# a PASSING run, on the bus -- so it lands in events.jsonl
			# (`grep qa_state_dump`) and in _events_seen, where
			# `assert_event_logged` can pin it if a script wants the probe
			# itself to be the assertion.
			ObservableBus.emit_domain_event("qa_state_dump", {
				"label": String(step.get("label", "")),
				"step": _step_index,
				"snapshot": Game.sim.snapshot(),
				"field_bar": Game.sim.field_hotbar_loadout(),
				"known_skills": Game.sim.known_skills(),
				"dialogue": _dialogue_dump(),
				"combat": _combat_dump(),
			})
			await get_tree().process_frame
		"dump_checkpoint":
			# GH#435: authoring scaffolding, never shipped inside a script.
			_dump_checkpoint(String(step.get("slot", "checkpoint")))
			await get_tree().process_frame
		_:
			_fail("unknown action: " + String(step["action"]))


func _inject_action(action_name: String) -> void:
	if not ACTION_KEYS.has(action_name):
		_fail("no key mapping for action: " + action_name)
		return
	var key: Key = ACTION_KEYS[action_name]
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.keycode = key
	release.pressed = false
	Input.parse_input_event(release)


func _inject_gamepad_action(action_name: String) -> void:
	if not ACTION_JOYPAD_BUTTONS.has(action_name):
		_fail("no gamepad mapping for action: " + action_name)
		return
	var button: JoyButton = ACTION_JOYPAD_BUTTONS[action_name]
	var press := InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventJoypadButton.new()
	release.button_index = button
	release.pressed = false
	Input.parse_input_event(release)


func _inject_diag(a: String, b: String) -> void:
	if not ACTION_KEYS.has(a) or not ACTION_KEYS.has(b):
		_fail("no key mapping for diagonal action: %s / %s" % [a, b])
		return
	var key_a: Key = ACTION_KEYS[a]
	var key_b: Key = ACTION_KEYS[b]
	var press_a := InputEventKey.new()
	press_a.physical_keycode = key_a
	press_a.keycode = key_a
	press_a.pressed = true
	Input.parse_input_event(press_a)
	var press_b := InputEventKey.new()
	press_b.physical_keycode = key_b
	press_b.keycode = key_b
	press_b.pressed = true
	Input.parse_input_event(press_b)
	var release_a := InputEventKey.new()
	release_a.physical_keycode = key_a
	release_a.keycode = key_a
	release_a.pressed = false
	Input.parse_input_event(release_a)
	var release_b := InputEventKey.new()
	release_b.physical_keycode = key_b
	release_b.keycode = key_b
	release_b.pressed = false
	Input.parse_input_event(release_b)


func _world_to_screen(world_pos: Vector2) -> Variant:
	var main := get_tree().root.find_child("Main", true, false)
	if main == null or not main.has_method("world_to_screen"):
		return null
	return main.call("world_to_screen", world_pos)


func _resolve_hotbar_node() -> Node:
	var screen_name := "CombatScreen" if Game.sim.combat != null else "FieldHotbar"
	var owner_node := get_tree().root.find_child(screen_name, true, false)
	if owner_node == null or not owner_node.has_method("hotbar_node"):
		return null
	return owner_node.call("hotbar_node")


func _inject_drag(from: Vector2, to: Vector2, steps: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	get_tree().root.push_input(press, true)
	var prev := from
	for i in range(1, steps + 1):
		var pt := from.lerp(to, float(i) / float(steps))
		var motion := InputEventMouseMotion.new()
		motion.position = pt
		motion.global_position = pt
		motion.relative = pt - prev
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(motion, true)
		prev = pt
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	get_tree().root.push_input(release, true)


## #503: resolve a node's rendered rect and touch its centre (real on web,
## emulated natively). `arg` is the rect method's single argument.
func _wait_touch_ready() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var main := get_tree().root.find_child("Main", true, false)
		var world := get_tree().root.find_child("World", true, false)
		var tween: Tween = world.get("_player_tween") if world != null else null
		if main != null and not main.veil_modal_active() and not main.map_transition_active() and (tween == null or not tween.is_valid() or not tween.is_running()):
			return true
		await get_tree().process_frame
	_fail("touch route: presentation did not finish")
	return false


func _touch_world_cell(cell: Vector2i) -> bool:
	if not await _wait_touch_ready():
		return false
	var main := get_tree().root.find_child("Main", true, false)
	var pos: Variant = _world_to_screen(Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5)
	if pos == null or not (main.world_view_rect() as Rect2).has_point(pos):
		_fail("touch_cell: cell %s is outside the visible playfield" % cell)
		return false
	await _touch_at(pos, "cell")
	return true


## #506: bounded touch travel. Every step is one real contact on the visibly
## adjacent next cell of the world's own click-path BFS (the same walkability
## the shipped tap-to-walk uses), so a route never teleports and never clamps
## an off-screen goal onto an unrelated contact. An encounter that interrupts
## the route fails the step unless the goal itself was just reached.
func _touch_walk(goal: Vector2i) -> void:
	for attempt in 160:
		if Game.sim.player_cell == goal:
			await _wait_touch_ready()
			return
		if Game.sim.combat != null:
			_fail("touch_walk: encounter interrupted route to %s" % goal)
			return
		if not await _wait_touch_ready():
			return
		var world := get_tree().root.find_child("World", true, false)
		if world == null:
			_fail("touch_walk: no World node")
			return
		var cell: Vector2i = Game.sim.player_cell
		var came_from: Dictionary = world.call("_bfs_from", cell)
		if not came_from.has(goal):
			_fail("touch_walk: no walkable route from %s to %s" % [cell, goal])
			return
		var path: Array = world.call("_reconstruct_path", came_from, cell, goal)
		var next: Vector2i = path[0]
		if not await _touch_world_cell(next):
			return
		var deadline := Time.get_ticks_msec() + 3000
		while Game.sim.player_cell != next and Time.get_ticks_msec() < deadline:
			if Game.sim.combat != null:
				break
			await get_tree().process_frame
		if Game.sim.player_cell != next and Game.sim.combat == null:
			_fail("touch_walk: contact from %s did not reach %s" % [cell, next])
			return
	_fail("touch_walk: exceeded bounded route length")


## #506: talk to the adjacent entity at `cell` by touch. A fresh waking's first
## contact may only emit the ambient talk-pool line; wait for that line to
## tear down and contact again (bounded) until `dialogue_started` opens the
## graph. The player must already stand cardinally adjacent.
func _touch_talk(cell: Vector2i, conversation: String) -> void:
	for attempt in 3:
		var before := _events_seen.size()
		if not await _touch_world_cell(cell):
			return
		var deadline := Time.get_ticks_msec() + 5000
		var line_seen := false
		while Time.get_ticks_msec() < deadline:
			var subset := {} if conversation.is_empty() else {"conversation": conversation}
			var started := _find_event_since("dialogue_started", subset, before)
			if started != -1:
				_wait_cursor = started + 1
				return
			if _find_event_since("dialogue_line", {}, before) != -1:
				line_seen = true
				if _find_event_since("ui_dialogue_line_hidden", {}, before) != -1:
					break
			await get_tree().process_frame
		if not line_seen:
			_fail("touch_talk: contact on %s opened neither a conversation nor an ambient line" % cell)
			return
		await get_tree().process_frame
		await get_tree().process_frame
	_fail("touch_talk: %s never opened a conversation after ambient lines" % cell)


## #506: advance a paged dialogue node by touching its visible "More" hint
## until the option rows render. Each page turn is a real contact and must
## produce its own `ui_dialogue_page_rendered`.
func _touch_dialogue_continue() -> void:
	var panel := get_tree().root.find_child("DialoguePanel", true, false)
	if panel == null:
		_fail("touch_dialogue_continue: DialoguePanel not found")
		return
	for attempt in 12:
		var settle := Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < settle and not (panel.option_rect(0) as Rect2).has_area() and not (panel.more_hint_rect() as Rect2).has_area():
			await get_tree().process_frame
		if (panel.option_rect(0) as Rect2).has_area():
			return
		var more: Rect2 = panel.more_hint_rect()
		if not more.has_area():
			_fail("touch_dialogue_continue: neither options nor a More hint is rendered")
			return
		var before := _events_seen.size()
		await _touch_at(more.get_center(), "touch_dialogue_continue")
		var deadline := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline and _find_event_since("ui_dialogue_page_rendered", {}, before) == -1:
			await get_tree().process_frame
		if _find_event_since("ui_dialogue_page_rendered", {}, before) == -1:
			_fail("touch_dialogue_continue: page contact rendered no new page")
			return
	_fail("touch_dialogue_continue: options never rendered within 12 pages")


func _combat_screen_node() -> Node:
	return get_tree().root.find_child("CombatScreen", true, false)


## #506: touch a combat action-bar slot by its bar `type` (attack, dash,
## end_turn) or skill/item id, paging the phone action bar with its real
## page control until the slot has a rendered rect.
func _touch_combat_slot(slot_id: String) -> bool:
	var cs := _combat_screen_node()
	if cs == null:
		_fail("touch_combat_slot: CombatScreen not found")
		return false
	var slots: Array = cs.get("_bar_slots")
	var index := -1
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if String(slot.get("type", "")) == slot_id or String(slot.get("id", "")) == slot_id:
			index = i
			break
	if index < 0:
		_fail("touch_combat_slot: no bar slot %s (bar: %s)" % [slot_id, JSON.stringify(slots.map(func(s: Dictionary) -> String: return String(s.get("id", s.get("type", "")))))])
		return false
	for attempt in 8:
		var rect: Rect2 = cs.hotbar_node().slot_rect(index)
		if rect.has_area():
			await _touch_at(rect.get_center(), "touch_combat_slot_" + slot_id)
			return true
		var next: Rect2 = cs.mobile_control_rect("page_next")
		if not next.has_area():
			break
		await _touch_at(next.get_center(), "touch_combat_page_next")
	_fail("touch_combat_slot: no reachable action page shows " + slot_id)
	return false


## CombatScreen.Mode indices (INACTIVE, HOTBAR, ATTACK, SKILL_TARGET,
## DASH_CONFIRM, WAIT_AI, BANNER) read through `_mode` for touch routing.
const MODE_HOTBAR := 1
const MODE_ATTACK := 2
const MODE_SKILL_TARGET := 3
const MODE_DASH_CONFIRM := 4
const MODE_BANNER := 6


func _combat_mode() -> int:
	var cs := _combat_screen_node()
	return int(cs.get("_mode")) if cs != null else 0


## #506: finish the current fight with real contacts only. Each PC turn plans
## read-only (nearest living enemy by the AI's own arena path length, the
## shipped weapon range, the bar's own Piercing Strikes when affordable) and
## then performs every decision as a visible browser contact: action slot ->
## tap the offered target -> Confirm; step one adjacent cell along the AI's
## path helper; Dash + Confirm when the step pool is empty; End Turn. AI turns
## are waited out. Stops at the result banner, which the script dismisses.
func _touch_combat_rounds(max_turns: int) -> void:
	if Game.sim.combat == null:
		_fail("touch_combat_rounds: no active combat")
		return
	for turn in max_turns:
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline:
			if Game.sim.combat == null or Game.sim.combat.finished or _combat_mode() == MODE_BANNER:
				return
			if _combat_mode() == MODE_HOTBAR and Game.sim.combat.get_active() == "pc":
				break
			await get_tree().process_frame
		if _combat_mode() != MODE_HOTBAR:
			_fail("touch_combat_rounds: no PC turn within 60s (mode %d)" % _combat_mode())
			return
		for action in 8:
			var combat: WICombat = Game.sim.combat
			if combat == null or combat.finished or _combat_mode() != MODE_HOTBAR:
				break
			var snap: Dictionary = combat.snapshot()
			var pc: Dictionary = snap["combatants"]["pc"]
			var pc_cell := Vector2i(int(pc["cell"][0]), int(pc["cell"][1]))
			var reach := int(pc.get("weapon_range", 1))
			if int(pc["ap"]) < WICombat.ATTACK_COST:
				break
			# Read-only plan: the arena's own tutor line says "stay behind me",
			# so with a living ally the PC only closes on enemies already
			# engaged (adjacent to) that ally, never Dashing ahead alone.
			var allies: Array[String] = []
			for id: String in snap["combatants"]:
				var c: Dictionary = snap["combatants"][id]
				if id != "pc" and String(c["side"]) == "player" and bool(c["alive"]):
					allies.append(id)
			var target := ""
			var best := 1 << 30
			for id: String in snap["combatants"]:
				var c: Dictionary = snap["combatants"][id]
				if String(c["side"]) != "enemy" or not bool(c["alive"]):
					continue
				var cell := Vector2i(int(c["cell"][0]), int(c["cell"][1]))
				var engaged := allies.is_empty() or combat.in_weapon_range("pc", id)
				for ally: String in allies:
					if combat.is_adjacent(ally, id):
						engaged = true
				if not engaged:
					continue
				var dist: int = WICombatAI._path_len(combat, pc_cell, cell, reach)
				if dist < 0:
					dist = absi(cell.x - pc_cell.x) + absi(cell.y - pc_cell.y) + 1000
				if dist < best:
					best = dist
					target = id
			if target.is_empty():
				break
			var target_cell_raw: Array = snap["combatants"][target]["cell"]
			var target_cell := Vector2i(int(target_cell_raw[0]), int(target_cell_raw[1]))
			if _touch_combat_can_strike(combat, pc_cell, target_cell, reach):
				if not await _touch_combat_strike(target, target_cell):
					return
				continue
			if int(pc["move_pool"]) <= 0:
				if not allies.is_empty() or int(pc["ap"]) < WICombat.DASH_COST + WICombat.ATTACK_COST:
					break
				if not await _touch_combat_dash():
					return
			var step := Vector2i.ZERO
			for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if combat.is_cell_free(pc_cell + dir) and _touch_combat_can_strike(combat, pc_cell + dir, target_cell, reach):
					step = dir
					break
			if step == Vector2i.ZERO:
				step = WICombatAI._path_step(combat, pc_cell, target_cell, reach)
			if step == Vector2i.ZERO:
				break
			var before := _events_seen.size()
			if not await _touch_world_cell(pc_cell + step):
				return
			var wait := Time.get_ticks_msec() + 3000
			while Time.get_ticks_msec() < wait and _find_event_since("combatant_moved", {"id": "pc"}, before) == -1:
				await get_tree().process_frame
			if _find_event_since("combatant_moved", {"id": "pc"}, before) == -1:
				_fail("touch_combat_rounds: contact on %s moved nobody" % (pc_cell + step))
				return
		if Game.sim.combat != null and not Game.sim.combat.finished and _combat_mode() == MODE_HOTBAR:
			var before_end := _events_seen.size()
			if not await _touch_combat_slot("end_turn"):
				return
			var wait_end := Time.get_ticks_msec() + 5000
			while Time.get_ticks_msec() < wait_end and _find_event_since("turn_ended", {"id": "pc"}, before_end) == -1:
				await get_tree().process_frame
			if _find_event_since("turn_ended", {"id": "pc"}, before_end) == -1:
				_fail("touch_combat_rounds: End Turn contact ended no turn")
				return
	_fail("touch_combat_rounds: fight did not finish within %d PC turns" % max_turns)


## Mirrors the targeting controller's own melee rule (Chebyshev reach AND a
## supercover line of sight over arena-blocked cells) so the planner never
## asks for a strike the real aim surface will refuse.
func _touch_combat_can_strike(combat: WICombat, from: Vector2i, target_cell: Vector2i, reach: int) -> bool:
	if maxi(absi(from.x - target_cell.x), absi(from.y - target_cell.y)) > reach:
		return false
	for cell: Vector2i in combat._supercover(from, target_cell):
		if cell != from and cell != target_cell and combat.blocked.has(cell):
			return false
	return true


## One touch-driven strike: Piercing Strikes when the bar offers it and AP
## allows, else Attack; then the offered target's cell, then Confirm.
func _touch_combat_strike(target: String, target_cell: Vector2i) -> bool:
	var cs := _combat_screen_node()
	var slots: Array = cs.get("_bar_slots")
	var slot_id := "attack"
	for slot: Dictionary in slots:
		if String(slot.get("id", "")) == "piercing_strikes" and bool(slot.get("affordable", true)):
			slot_id = "piercing_strikes"
	if not await _touch_combat_slot(slot_id):
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var targeting: RefCounted = cs.get("_targeting")
	if (_combat_mode() != MODE_ATTACK and _combat_mode() != MODE_SKILL_TARGET) or not targeting.has_valid_target():
		_fail("touch_combat_strike: %s offered no target for %s in range" % [slot_id, target])
		return false
	if not await _touch_world_cell(target_cell):
		return false
	var state: Dictionary = targeting.state()
	if String((state["targets"] as Array)[int(state["index"])]) != target:
		_fail("touch_combat_strike: contact on %s did not select %s" % [target_cell, target])
		return false
	var before := _events_seen.size()
	await _touch_rect_of("CombatScreen", "mobile_control_rect", "confirm", "touch_combat_confirm")
	var wait := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < wait and _find_event_since("attack_resolved", {"attacker": "pc"}, before) == -1 and _find_event_since("skill_resolved", {"actor": "pc"}, before) == -1:
		await get_tree().process_frame
	if _find_event_since("attack_resolved", {"attacker": "pc"}, before) == -1 and _find_event_since("skill_resolved", {"actor": "pc"}, before) == -1:
		_fail("touch_combat_strike: confirmed %s on %s never resolved" % [slot_id, target])
		return false
	return true


func _touch_combat_dash() -> bool:
	if not await _touch_combat_slot("dash"):
		return false
	await get_tree().process_frame
	if _combat_mode() != MODE_DASH_CONFIRM:
		_fail("touch_combat_dash: the Dash contact armed no confirmation (mode %d)" % _combat_mode())
		return false
	var before := _events_seen.size()
	await _touch_rect_of("CombatScreen", "mobile_control_rect", "confirm", "touch_combat_confirm")
	var wait := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < wait and _find_event_since("dashed", {"id": "pc"}, before) == -1:
		await get_tree().process_frame
	if _find_event_since("dashed", {"id": "pc"}, before) == -1:
		_fail("touch_combat_dash: confirmed Dash never resolved")
		return false
	return true


## #506: touch the inventory row of a carried item found by id through a
## read-only lookup of the panel's rendered row order.
func _touch_inventory_item(item: String) -> void:
	var inventory := get_tree().root.find_child("Inventory", true, false)
	if inventory == null or not bool(inventory.get("open")):
		_fail("touch_inventory_item: Inventory is not open")
		return
	var ids: Array = inventory.get("_item_ids")
	var index := ids.find(item)
	if index < 0:
		_fail("touch_inventory_item: %s is not carried (rows: %s)" % [item, JSON.stringify(ids)])
		return
	var rect: Rect2 = inventory.item_row_rect(index)
	if not rect.has_area() or not (inventory.visible_content_rect() as Rect2).encloses(rect):
		_fail("touch_inventory_item: row for %s is not fully visible" % item)
		return
	await _touch_at(rect.get_center(), "touch_inventory_item_" + item)


func _touch_field_skill(skill: String) -> void:
	var field := get_tree().root.find_child("FieldHotbar", true, false)
	if field == null:
		_fail("touch_field_skill: no field bar")
		return
	var index := -1
	for slot in field.slot_count():
		if field.skill_for_slot(slot + 1) == skill:
			index = slot
	if index < 0:
		_fail("touch_field_skill: skill is not on the earned field bar: " + skill)
		return
	for attempt in field.slot_count():
		var rect: Rect2 = field.hotbar_node().slot_rect(index)
		if rect.has_area():
			await _touch_at(rect.get_center(), "touch_field_skill_" + skill)
			return
		var next: Rect2 = field.page_control_rect("next")
		if not next.has_area():
			break
		await _touch_at(next.get_center(), "touch_field_page_next")
	_fail("touch_field_skill: no reachable page contains " + skill)


func _touch_rect_of(node_name: String, rect_method: String, arg: Variant, label: String, gesture: Dictionary = {}) -> void:
	var node := get_tree().root.find_child(node_name, true, false)
	if node == null:
		_fail("%s: %s node not found" % [label, node_name])
		return
	var rect: Rect2 = node.call(rect_method) if arg == null else node.call(rect_method, arg)
	if rect.size == Vector2.ZERO:
		_fail("%s: %s has no rendered rect" % [label, str(arg)])
		return
	if node_name == "PurchaseConfirm":
		var buy_rect: Rect2 = node.call("row_rect", 1)
		_last_purchase_buy_pos = get_viewport().get_screen_transform() * buy_rect.get_center()
	if bool(gesture.get("follow_purchase_buy", false)):
		if _last_purchase_buy_pos == Vector2.ZERO:
			_fail("follow_purchase_buy needs a prior rendered modal touch at this viewport")
			return
		gesture = gesture.duplicate()
		gesture["follow_x"] = _last_purchase_buy_pos.x
		gesture["follow_y"] = _last_purchase_buy_pos.y
	if gesture.has("delta_css"):
		gesture = gesture.duplicate()
		var end := get_viewport().get_screen_transform() * rect.get_center() + Vector2(float(gesture.delta_css[0]), float(gesture.delta_css[1]))
		gesture["end_x"] = end.x
		gesture["end_y"] = end.y
		gesture.erase("delta_css")
	await _touch_at(rect.get_center(), label, gesture)


## The one seam every touch_* step rides. Web: publish the request in WINDOW
## pixels (the root viewport's screen transform folds in canvas_items
## stretch + letterbox offset, so the runner taps exactly where a finger
## would), then wait for the runner to report the tap performed. A runner
## not in --touch mode never answers, so the step FAILS rather than falling
## back -- that absence of fallback is the contract #503 asks for.
const TOUCH_SERVICE_DEADLINE_MSEC := 4000

func _touch_at(pos: Vector2, label: String, gesture: Dictionary = {}) -> void:
	if OS.has_feature("web"):
		var window_pos: Vector2 = get_viewport().get_screen_transform() * pos
		JavaScriptBridge.eval("window.__WI_QA_TOUCH_REQ__ = {x: %f, y: %f, label: %s, gesture: %s}" % [window_pos.x, window_pos.y, JSON.stringify(label), JSON.stringify(gesture)], true)
		var before := int(JavaScriptBridge.eval("window.__WI_QA_TOUCH_DONE__ || 0", true))
		var deadline := Time.get_ticks_msec() + TOUCH_SERVICE_DEADLINE_MSEC
		var serviced := false
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if int(JavaScriptBridge.eval("window.__WI_QA_TOUCH_DONE__ || 0", true)) > before:
				serviced = true
				break
		if not serviced:
			JavaScriptBridge.eval("window.__WI_QA_TOUCH_REQ__ = null", true)
			_fail("%s: real touch at (%d,%d) was never performed by the runner (not in --touch mode?) -- no fallback" % [label, int(pos.x), int(pos.y)])
			return
		ObservableBus.emit_domain_event("qa_touch", {"label": label, "x": pos.x, "y": pos.y, "window_x": window_pos.x, "window_y": window_pos.y, "real": true, "mode": "browser_touch", "gesture": gesture})
	else:
		if not gesture.is_empty():
			_fail("timed touch gestures require the browser runner with --touch")
			return
		_inject_mouse_click(pos)
		ObservableBus.emit_domain_event("qa_touch", {"label": label, "x": pos.x, "y": pos.y, "real": false, "mode": "emulated_native_click"})
	await get_tree().process_frame
	await get_tree().process_frame


func _inject_mouse_click(pos: Vector2) -> void:
	# Viewport-local injection avoids Input.parse_input_event applying the
	# headless window stretch twice; GUI hit-testing still runs normally.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	get_tree().root.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	get_tree().root.push_input(release, true)


func _inject_unicode(ch: String) -> void:
	if ch.is_empty():
		return
	var press := InputEventKey.new()
	press.unicode = ch.unicode_at(0)
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.unicode = ch.unicode_at(0)
	release.pressed = false
	Input.parse_input_event(release)


func _event_matches(e: Dictionary, type: String, subset: Dictionary) -> bool:
	if e["type"] != type:
		return false
	for key: String in subset:
		var p: Dictionary = e["payload"]
		if not p.has(key) or not _loosely_equal(p[key], subset[key]):
			return false
	return true


func _has_event(type: String, subset: Dictionary = {}) -> bool:
	for e: Dictionary in _events_seen:
		if _event_matches(e, type, subset):
			return true
	return false


func _count_events(type: String, subset: Dictionary = {}) -> int:
	var n := 0
	for e: Dictionary in _events_seen:
		if _event_matches(e, type, subset):
			n += 1
	return n


func _find_event_since(type: String, subset: Dictionary, from_index: int) -> int:
	for i in range(from_index, _events_seen.size()):
		if _event_matches(_events_seen[i], type, subset):
			return i
	return -1


func _wait_for_event(type: String, timeout_sec: float, subset: Dictionary = {}, from_start: bool = false) -> void:
	var start_index := 0 if from_start else _wait_cursor
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var match_index := _find_event_since(type, subset, start_index)
		if match_index != -1:
			if not from_start:
				_wait_cursor = match_index + 1
			return
		await get_tree().process_frame
	_fail("timeout (%.1fs) waiting for event: %s subset=%s cursor=%d" % [timeout_sec, type, JSON.stringify(subset), _wait_cursor])


func _screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_events_seen.append({"type": "screenshot_skipped_headless", "payload": {"name": name}})
		return
	_capture_depth += 1
	await _capture_png(name)
	_capture_depth -= 1


## GH#324: `_screenshot`'s body, split out so the capture-in-flight counter can
## bracket EVERY exit path (the web branch has two early returns of its own) in
## one place instead of being decremented at each `return`.
func _capture_png(name: String) -> void:
	await _settle_for_capture()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__WI_QA_SHOT__ = %s" % JSON.stringify(name), true)
		var deadline := Time.get_ticks_msec() + WEB_CAPTURE_DEADLINE_MSEC
		while Time.get_ticks_msec() < deadline:
			var pending: Variant = JavaScriptBridge.eval("window.__WI_QA_SHOT__", true)
			if pending == null:
				_screenshots.append(name + ".png")
				return
			await get_tree().process_frame
		_fail("web screenshot never acknowledged: " + name)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var path := _out_dir.path_join(name + ".png")
	img.save_png(path)
	_screenshots.append(path)


## CONTRACT (#119): before evidence is captured, settle -- base delay, then
## drain live VISUAL tweens (bounded 3s) + two clean frames. A completion
## signal, not a machine-speed guess; kills the pinned wait_frames-before-
## evidence class (#91 whack-a-mole), so scripts should not stack extra sleeps
## in front of a capture.
## GH#324: shared by `_screenshot` and `assert_dialogue_displayed` so the probe
## reports the panel state at exactly the moment the PNG would be taken -- a
## probe that settled differently would prove something no screenshot sees.
func _settle_for_capture() -> void:
	await get_tree().create_timer(SCREENSHOT_SETTLE_SECONDS).timeout
	var tween_deadline_ms := Time.get_ticks_msec() + TWEEN_DRAIN_CAP_MSEC
	while not get_tree().get_processed_tweens().is_empty() \
			and Time.get_ticks_msec() < tween_deadline_ms:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _assert_message_layout(kind: String) -> void:
	_capture_depth += 1
	await _settle_for_capture()
	var layer := get_tree().root.find_child("MessageLayer", true, false)
	var panel: Control = layer.get("_toast_panel" if kind == "toast" else "_dialogue_panel") if layer != null else null
	var label: Label = layer.get("_toast_label" if kind == "toast" else "_dialogue_label") if layer != null else null
	if panel == null or label == null or not panel.is_visible_in_tree() or label.text.is_empty():
		_fail("assert_message_layout: requested message is not visible")
	else:
		var bounds := panel.get_global_rect()
		if not WIResponsiveLayout.safe_rect(get_viewport()).encloses(bounds):
			_fail("assert_message_layout: message is outside safe viewport")
		var font_size := label.get_theme_font_size("font_size")
		if font_size * WIResponsiveLayout.css_scale(get_viewport()) + 0.01 < WIResponsiveLayout.MIN_TEXT_CSS * WISettings.TEXT_SCALE_STEPS[WISettings.text_scale_step()]:
			_fail("assert_message_layout: message text is too small")
		var field := get_tree().root.find_child("FieldHotbar", true, false)
		if field != null and field.visible and bounds.end.y > field.world_bottom() + 0.01:
			_fail("assert_message_layout: message overlaps field controls or details")
		ObservableBus.emit_domain_event("qa_message_layout_measured", {"kind": kind, "font_css": font_size * WIResponsiveLayout.css_scale(get_viewport()), "text_scale": WISettings.text_scale_label()})
	_capture_depth -= 1


func _resize_browser(step: Dictionary) -> void:
	if not OS.has_feature("web"):
		_fail("resize_browser: requires real browser viewport resize")
		return
	var request := {"width": int(step.get("width", 0)), "height": int(step.get("height", 0)), "restore": bool(step.get("restore", false))}
	JavaScriptBridge.eval("window.__WI_QA_RESIZE__ = %s" % JSON.stringify(request), true)
	var deadline := Time.get_ticks_msec() + WEB_CAPTURE_DEADLINE_MSEC
	while Time.get_ticks_msec() < deadline:
		if JavaScriptBridge.eval("window.__WI_QA_RESIZE__", true) == null:
			await _settle_for_capture()
			ObservableBus.emit_domain_event("qa_browser_resized", request)
			return
		await get_tree().process_frame
	_fail("resize_browser: viewport request was not acknowledged")


func _assert_dialogue_layout() -> void:
	await _settle_for_capture()
	var panel := get_tree().root.find_child("DialoguePanel", true, false)
	if panel == null or not bool(panel.get("_shown")):
		_fail("assert_dialogue_layout: dialogue is not visible")
		return
	var root: Control = panel.get("_root")
	var bounds := root.get_global_rect()
	if not get_viewport().get_visible_rect().encloses(bounds):
		_fail("assert_dialogue_layout: panel is outside viewport")
	var messages := get_tree().root.find_child("MessageLayer", true, false)
	var toast: Control = messages.get("_toast_panel") if messages != null else null
	if toast != null and toast.is_visible_in_tree() and toast.get_global_rect().intersects(bounds):
		_fail("assert_dialogue_layout: toast overlaps conversation")
	var body: Label = panel.get("_text_label")
	var font := body.get_theme_font("font")
	var font_size := body.get_theme_font_size("font_size")
	var text_height := font.get_multiline_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, body.size.x, font_size).y
	if text_height > body.size.y + 1.0 or not bounds.encloses(body.get_global_rect()):
		_fail("assert_dialogue_layout: body text is clipped")
	var css_font := font_size * WIResponsiveLayout.css_scale(get_viewport())
	if css_font + 0.01 < WIResponsiveLayout.MIN_TEXT_CSS * WISettings.TEXT_SCALE_STEPS[WISettings.text_scale_step()]:
		_fail("assert_dialogue_layout: body text is too small")
	var scroll: ScrollContainer = panel.get("_options_scroll")
	var options: Array = panel.get("_option_controls")
	for control: Control in options:
		var rect := control.get_global_rect()
		if not scroll.get_global_rect().intersects(rect):
			continue
		var visible_rect := scroll.get_global_rect().intersection(rect)
		if visible_rect.intersects(body.get_global_rect()):
			_fail("assert_dialogue_layout: option overlaps dialogue text")
		var css := WIResponsiveLayout.css_rect(get_viewport(), rect)
		if minf(css.size.x, css.size.y) + 0.01 < WIResponsiveLayout.MIN_TOUCH_CSS:
			_fail("assert_dialogue_layout: option is smaller than 44 CSS pixels")
	ObservableBus.emit_domain_event("qa_dialogue_layout_measured", {"text_scale": WISettings.text_scale_label(), "font_css": css_font, "panel_height": bounds.size.y})


func _assert_panel_layout(panel_name: String) -> void:
	await _settle_for_capture()
	var panel := get_tree().root.find_child(panel_name, true, false)
	var chips := get_tree().root.find_child("FieldChips", true, false)
	if panel == null or not bool(panel.get("open")) or chips == null:
		_fail("assert_panel_layout: requested panel is not open")
		return
	var root: Control = panel.get("_root")
	var bounds := root.get_global_rect()
	if not get_viewport().get_visible_rect().encloses(bounds):
		_fail("assert_panel_layout: panel extends outside the viewport")
	var chip_name := "inventory" if panel_name == "Inventory" else "journal"
	var close_rect: Rect2 = chips.chip_rect(chip_name)
	if close_rect.size == Vector2.ZERO or close_rect.intersects(bounds) or not get_viewport().get_visible_rect().encloses(close_rect):
		_fail("assert_panel_layout: close control is absent or covered")
	var content: Rect2 = panel.visible_content_rect() if panel_name == "Inventory" else panel.body_rect()
	if not bounds.encloses(content):
		_fail("assert_panel_layout: scrolling content extends outside its panel")
	var content_css := WIResponsiveLayout.css_rect(get_viewport(), content)
	if content_css.size.y < WIResponsiveLayout.MIN_TOUCH_CSS:
		_fail("assert_panel_layout: fewer than 44 CSS pixels remain for scrolling content")
	var controls := {"close": close_rect}
	if panel_name == "Journal":
		for tab: String in ["quests", "skills", "history"]:
			controls[tab] = panel.tab_rect(tab)
	else:
		controls["equipment"] = panel.equipment_rect()
		if not bool(panel.get("_equipment_expanded")):
			controls["first_item"] = panel.item_row_rect(0)
	for id: String in controls:
		var rect: Rect2 = controls[id]
		var parent_bounds: Rect2 = get_viewport().get_visible_rect() if id == "close" else (content if id == "first_item" else bounds)
		if not parent_bounds.encloses(rect):
			_fail("assert_panel_layout: %s is clipped or outside its visible area" % id)
		for other_id: String in controls:
			if other_id != id and rect.intersects(controls[other_id]):
				_fail("assert_panel_layout: %s overlaps %s" % [id, other_id])
		var css := WIResponsiveLayout.css_rect(get_viewport(), rect)
		if minf(css.size.x, css.size.y) < WIResponsiveLayout.MIN_TOUCH_CSS - 0.01:
			_fail("assert_panel_layout: %s is smaller than 44 CSS pixels" % id)
	ObservableBus.emit_domain_event("qa_panel_layout_measured", {"panel": panel_name, "text_scale": WISettings.text_scale_label(), "content_height_css": content_css.size.y})


func _touch_combat_pages(step: Dictionary) -> void:
	var screen := get_tree().root.find_child("CombatScreen", true, false)
	if screen == null:
		_fail("touch_combat_pages: no combat screen")
		return
	var tutor := String(step.get("mode", "details")) == "tutor"
	var page_key := "tutor_page" if tutor else "details_page"
	var pages_key := "tutor_pages" if tutor else "details_pages"
	var text_key := "tutor_text" if tutor else "details_text"
	var control := "note_next" if tutor else "drawer_next"
	var snapshot: Dictionary = screen.responsive_layout_snapshot()
	if int(snapshot.get(page_key, -1)) != 0 or int(snapshot.get(pages_key, 0)) < 1:
		_fail("touch_combat_pages: must begin at first rendered page")
		return
	var count := int(snapshot[pages_key])
	if count < int(step.get("min_pages", 1)):
		_fail("touch_combat_pages: expected at least %d pages, got %d" % [int(step.min_pages), count])
		return
	var text := String(snapshot[text_key])
	for page in range(1, count):
		await _touch_rect_of("CombatScreen", "mobile_control_rect", control, "touch_combat_pages")
		await _wait_for_event("ui_combat_layout_rendered" if tutor else "ui_combat_details_rendered", 5.0, {page_key: page})
		await _assert_combat_layout({"equals": {page_key: page}})
		snapshot = screen.responsive_layout_snapshot()
		text += "\n" + String(snapshot[text_key])
		await _screenshot("%s_%d" % [String(step.get("name", "combat_pages")), page])
	for expected: String in step.get("contains", []):
		if not text.replace("\n", " ").contains(expected):
			_fail("touch_combat_pages: rendered pages omit %s" % expected)
	ObservableBus.emit_domain_event("qa_combat_pages_read", {"mode": "tutor" if tutor else "details", "pages": count, "text": text})


func _touch_field_pages() -> void:
	var field := get_tree().root.find_child("FieldHotbar", true, false)
	if field == null:
		_fail("touch_field_pages: no field controls")
		return
	for attempt in 30:
		var previous: Rect2 = field.page_control_rect("previous")
		if not previous.has_area():
			break
		await _touch_at(previous.get_center(), "touch_field_pages")
		await _wait_for_event("ui_field_hotbar_rendered", 5.0, {"reason": "page"})
	var seen: Array[int] = []
	for page in 30:
		await _assert_field_layout()
		for child: Control in field.hotbar_node().get_children():
			var index := int(child.get_meta("slot_index"))
			if not seen.has(index):
				seen.append(index)
		var next: Rect2 = field.page_control_rect("next")
		if not next.has_area():
			break
		await _touch_at(next.get_center(), "touch_field_pages")
		await _wait_for_event("ui_field_hotbar_rendered", 5.0, {"reason": "page", "page": page + 1})
	if seen != range(field.slot_count()):
		_fail("touch_field_pages: not every original slot was reached in order")
	ObservableBus.emit_domain_event("qa_field_pages_read", {"visible_indices": seen, "slots": field.slot_count()})


func _touch_scroll_field_to_end() -> void:
	var field := get_tree().root.find_child("FieldHotbar", true, false)
	if field == null or not bool(field.get("_expanded")):
		_fail("touch_scroll_field_to_end: details must be expanded")
		return
	var scroll := field.get("_readout_scroll") as ScrollContainer
	var label := field.get("_readout_label") as Label
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value <= bar.page:
		_fail("touch_scroll_field_to_end: fixture does not overflow")
		return
	for attempt in 80:
		if scroll.scroll_vertical >= bar.max_value - bar.page - 1.0:
			break
		var rect := scroll.get_global_rect()
		var end := rect.position + rect.size * Vector2(0.5, 0.15)
		var window_end := get_viewport().get_screen_transform() * end
		await _touch_at(rect.position + rect.size * Vector2(0.5, 0.85), "touch_scroll_field", {"drag": true, "end_x": window_end.x, "end_y": window_end.y})
		await _settle_for_capture()
	if scroll.scroll_vertical < bar.max_value - bar.page - 1.0 or label.get_global_rect().end.y > scroll.get_global_rect().end.y + 1.0:
		_fail("touch_scroll_field_to_end: final readout line remains clipped")
	ObservableBus.emit_domain_event("qa_field_readout_end_visible", {"scroll": scroll.scroll_vertical, "text": label.text})


func _assert_combat_layout(step: Dictionary) -> void:
	await _settle_for_capture()
	var screen := get_tree().root.find_child("CombatScreen", true, false)
	var main := get_tree().root.find_child("Main", true, false)
	if screen == null or main == null or Game.sim.combat == null:
		_fail("assert_combat_layout: no live combat")
		return
	var snapshot: Dictionary = screen.responsive_layout_snapshot()
	if not bool(snapshot.get("mobile", false)):
		_fail("assert_combat_layout: requires the mobile browser layout")
		return
	var safe := WIResponsiveLayout.css_rect(get_viewport(), WIResponsiveLayout.safe_rect(get_viewport()))
	var rects: Dictionary = {}
	for id: String in snapshot["controls"]:
		var value: Dictionary = snapshot["controls"][id]
		var rect := Rect2(value["x"], value["y"], value["width"], value["height"])
		if minf(rect.size.x, rect.size.y) < 43.99 or not safe.grow(0.1).encloses(rect):
			_fail("assert_combat_layout: clipped or undersized control %s: %s" % [id, rect])
		for other: String in rects:
			if rect.intersects(rects[other]):
				_fail("assert_combat_layout: %s overlaps %s" % [id, other])
		rects[id] = rect
	if float(snapshot["font_css"]) < 14.0 * float(snapshot["text_scale"]) - 0.01:
		_fail("assert_combat_layout: unreadable text size")
	var text_rects: Array[Rect2] = []
	for value: Dictionary in snapshot["text_rects"].values():
		var text_rect := Rect2(value["x"], value["y"], value["width"], value["height"])
		if not safe.grow(0.1).encloses(text_rect):
			_fail("assert_combat_layout: important text exceeds safe bounds")
		for id: String in rects:
			if text_rect.intersects(rects[id]):
				_fail("assert_combat_layout: important text overlaps %s" % id)
		for other: Rect2 in text_rects:
			if text_rect.intersects(other):
				_fail("assert_combat_layout: important text regions overlap")
		text_rects.append(text_rect)
	for key: String in step.get("equals", {}):
		if snapshot.get(key) != step["equals"][key]:
			_fail("assert_combat_layout: %s expected %s, got %s" % [key, step["equals"][key], snapshot.get(key)])
	for key: String in step.get("contains", {}):
		if not String(snapshot.get(key, "")).contains(String(step["contains"][key])):
			_fail("assert_combat_layout: %s is missing %s" % [key, step["contains"][key]])
	if not bool(snapshot["details_open"]):
		var board: Rect2 = main.world_view_rect()
		var board_css := WIResponsiveLayout.css_rect(get_viewport(), board)
		for id: String in rects:
			if board_css.intersects(rects[id]):
				_fail("assert_combat_layout: board overlaps %s" % id)
		var origin: Vector2 = main.world_to_screen(Vector2.ZERO)
		var edge: Vector2 = main.world_to_screen(Vector2(CELL, CELL))
		var cell_size := (edge - origin) * WIResponsiveLayout.css_scale(get_viewport())
		if minf(cell_size.x, cell_size.y) < 43.99:
			_fail("assert_combat_layout: board cells smaller than 44 CSS pixels")
		var combat: WICombat = Game.sim.combat
		var focus := String(snapshot["focused_id"])
		if focus.is_empty():
			focus = combat.get_active()
		var cell: Vector2i = combat.combatants[focus][WIKeys.CELL]
		var position: Vector2 = main.world_to_screen(Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5)
		if not board.has_point(position):
			_fail("assert_combat_layout: focused fighter is outside the visible board")
	ObservableBus.emit_domain_event("qa_combat_layout_measured", snapshot)


func _assert_field_layout() -> void:
	await _settle_for_capture()
	var main := get_tree().root.find_child("Main", true, false)
	var field := get_tree().root.find_child("FieldHotbar", true, false)
	var chips := get_tree().root.find_child("FieldChips", true, false)
	if main == null or field == null or chips == null or not field.visible:
		_fail("assert_field_layout: exploration controls are not visible")
		return
	var rects: Dictionary = {}
	for chip_name: String in ["inventory", "journal", "pause"]:
		rects[chip_name] = chips.chip_rect(chip_name)
	var hotbar: Node = field.hotbar_node()
	for child: Control in hotbar.get_children():
		rects["slot_%d" % int(child.get_meta("slot_index"))] = child.get_global_rect()
	for page_name: String in ["FieldPagePrevious", "FieldPageNext"]:
		var control := field.find_child(page_name, true, false) as Control
		if control != null and control.is_visible_in_tree():
			rects[page_name] = control.get_global_rect()
	rects["details"] = field.toggle_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var measurements: Dictionary = {}
	for id: String in rects:
		var rect: Rect2 = rects[id]
		if rect.size == Vector2.ZERO or not viewport_rect.encloses(rect):
			_fail("assert_field_layout: %s is absent or clipped: %s" % [id, rect])
		var css: Rect2 = WIResponsiveLayout.css_rect(get_viewport(), rect)
		measurements[id] = [css.position.x, css.position.y, css.size.x, css.size.y]
		if WIResponsiveLayout.uses_touch_layout() and minf(css.size.x, css.size.y) < WIResponsiveLayout.MIN_TOUCH_CSS - 0.01:
			_fail("assert_field_layout: %s is smaller than 44 CSS pixels: %s" % [id, css])
		for other: String in rects:
			if id < other and rect.intersects(rects[other]):
				_fail("assert_field_layout: %s overlaps %s" % [id, other])
	var world_rect: Rect2 = main.world_view_rect()
	var player_position: Vector2 = main.world_to_screen(Vector2(Game.sim.player_cell) * CELL + Vector2.ONE * CELL * 0.5)
	if not world_rect.has_point(player_position):
		_fail("assert_field_layout: player lies outside the usable world")
	for id: String in rects:
		if world_rect.intersects(rects[id]):
			_fail("assert_field_layout: world view overlaps %s" % id)
	var readout := field.find_child("FieldReadout", true, false) as Control
	if readout != null and readout.visible and world_rect.intersects(readout.get_global_rect()):
		_fail("assert_field_layout: expanded details cover the world view")
	ObservableBus.emit_domain_event("qa_field_layout_measured", {"controls_css": measurements, "touch_layout": WIResponsiveLayout.uses_touch_layout(), "text_scale": WISettings.text_scale_label(), "player": [player_position.x, player_position.y]})


## GH#324 DISPLAY PROOF. `ui_dialogue_rendered` is a bus confirmation that the
## renderer STARTED a line, not proof the panel is on screen when evidence is
## taken -- the issue's own finding. This settles exactly as `_screenshot` does
## and then reads message_layer.gd's live panel state, so "the line is visible"
## becomes a hard assertion instead of an inference from an event payload.
## Optional `contains` pins the composed text (speaker prefix included).
## WINDOWED-ONLY, exactly like `screenshot` and for the same reason: headless
## has no display to prove anything about, and every transient panel's headless
## hold is a near-zero frame-bounded collapse, so a headless probe would only
## ever restate that collapse. A headless run records the skip and moves on.
func _assert_dialogue_displayed(step: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		_events_seen.append({"type": "dialogue_display_skipped_headless", "payload": {}})
		return
	_capture_depth += 1
	await _probe_dialogue_display(step)
	_capture_depth -= 1


func _probe_dialogue_display(step: Dictionary) -> void:
	await _settle_for_capture()
	var main := get_tree().root.find_child("Main", true, false)
	if main == null:
		_fail("assert_dialogue_displayed: Main not found")
		return
	var layer := main.get_node_or_null("MessageLayer")
	if layer == null or not layer.has_method("dialogue_display_state"):
		_fail("assert_dialogue_displayed: MessageLayer.dialogue_display_state not found")
		return
	var state: Dictionary = layer.call("dialogue_display_state")
	if not bool(state["visible"]):
		_fail("assert_dialogue_displayed: line panel is NOT visible at capture time (state %s)" % JSON.stringify(state))
		return
	if not bool(state["on_screen"]):
		_fail("assert_dialogue_displayed: line panel rect is off screen (state %s)" % JSON.stringify(state))
		return
	if String(state["text"]).strip_edges() == "":
		_fail("assert_dialogue_displayed: line panel is visible but empty (state %s)" % JSON.stringify(state))
		return
	var want := String(step.get("contains", ""))
	if want != "" and not String(state["text"]).contains(want):
		_fail("assert_dialogue_displayed: displayed line %s does not contain %s" % [JSON.stringify(String(state["text"])), JSON.stringify(want)])
		return
	# #509 acceptance 1: visible-and-on-screen is not READABLE if another
	# panel draws over it. The field readout (expanded until the first sleep)
	# is the shipped occluder; measure the overlap against its rect and its
	# canvas layer instead of trusting the rendered event.
	var occluder := _dialogue_occluder(state)
	# The measurement itself lands in events.jsonl, so a windowed read can be
	# audited without re-running: what covered what, by how much, on which layer.
	var readout := get_tree().root.find_child("FieldReadout", true, false) as Control
	ObservableBus.emit_domain_event("qa_dialogue_display_probe", {
		"line_rect": state.get("rect", []), "line_layer": int(state.get("layer", 0)),
		"readout_visible": readout != null and readout.is_visible_in_tree(),
		"readout_rect": [readout.get_global_rect().position.x, readout.get_global_rect().position.y, readout.get_global_rect().size.x, readout.get_global_rect().size.y] if readout != null else [],
		"readout_layer": _canvas_layer_of(readout) if readout != null else -1,
		"occluder": occluder,
	})
	if not occluder.is_empty():
		_fail("assert_dialogue_displayed: line panel is OCCLUDED by %s (overlap %d%% of the line, layer %d vs %d; state %s)" % [String(occluder["name"]), int(occluder["overlap_pct"]), int(occluder["layer"]), int(state.get("layer", 0)), JSON.stringify(state)])
		return
	state["occluder"] = ""
	_events_seen.append({"type": "qa_dialogue_displayed", "payload": state})


## The panels that can sit in the line's band, checked by rect AND by canvas
## layer (a higher-or-equal layer added later draws on top). Returns {} when
## nothing covers more than OCCLUSION_PCT of the line panel.
const OCCLUSION_PCT := 20.0

static func _canvas_layer_of(node: Node) -> int:
	var cur := node
	while cur != null:
		if cur is CanvasLayer:
			return (cur as CanvasLayer).layer
		cur = cur.get_parent()
	return 0


func _dialogue_occluder(state: Dictionary) -> Dictionary:
	var r: Array = state.get("rect", [0, 0, 0, 0])
	var line_rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	if line_rect.get_area() <= 0.0:
		return {}
	var line_layer := int(state.get("layer", 0))
	for node_name: String in ["FieldReadout"]:
		var ctrl := get_tree().root.find_child(node_name, true, false) as Control
		if ctrl == null or not ctrl.is_visible_in_tree():
			continue
		var overlap := line_rect.intersection(ctrl.get_global_rect())
		var pct := 100.0 * overlap.get_area() / line_rect.get_area()
		if pct >= OCCLUSION_PCT and _canvas_layer_of(ctrl) >= line_layer:
			return {"name": node_name, "overlap_pct": pct, "layer": _canvas_layer_of(ctrl)}
	return {}


func _assert_state(step: Dictionary) -> void:
	var path := String(step["path"])
	var cur: Variant
	if path.begins_with("combat."):
		if Game.sim.combat == null:
			_fail("assert_state: no active combat for path " + path)
			return
		cur = Game.sim.combat.snapshot()
		path = path.trim_prefix("combat.")
	else:
		cur = Game.sim.snapshot()
	for key: String in path.split("."):
		if cur is Dictionary and cur.has(key):
			cur = cur[key]
		elif cur is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (cur as Array).size():
			cur = cur[int(key)]
		else:
			_fail("assert_state: path not found: " + String(step["path"]))
			return
	if step.has("contains"):
		if not (cur is Array):
			_fail("assert_state: %s is not an Array for `contains` (got %s)" % [String(step["path"]), str(cur)])
			return
		var wants: Array = step["contains"] if step["contains"] is Array else [step["contains"]]
		for want: Variant in wants:
			var found := false
			for have: Variant in (cur as Array):
				if _loosely_equal(have, want):
					found = true
					break
			if not found:
				_fail("assert_state: %s does not contain %s (got %s)" % [String(step["path"]), str(want), str(cur)])
				return
		return
	if not _loosely_equal(cur, step["equals"]):
		_fail("assert_state: %s expected %s, got %s" % [String(step["path"]), str(step["equals"]), str(cur)])


func _assert_world_to_screen_camera_aware() -> void:
	var main := get_tree().root.find_child("Main", true, false)
	if main == null or not main.has_method("world_to_screen"):
		_fail("world_to_screen probe: Main.world_to_screen not found")
		return
	var container := main.get_node_or_null("WorldContainer") as SubViewportContainer
	if container == null:
		_fail("world_to_screen probe: WorldContainer not found")
		return
	var sub_viewport := container.get_node_or_null("WorldViewport") as SubViewport
	if sub_viewport == null:
		_fail("world_to_screen probe: WorldViewport not found")
		return
	var original_transform := sub_viewport.canvas_transform
	var world_pos := Vector2(40.0, 40.0)
	sub_viewport.canvas_transform = Transform2D(0.0, Vector2.ZERO)
	var p0: Vector2 = main.call("world_to_screen", world_pos)
	sub_viewport.canvas_transform = Transform2D(0.0, Vector2(-10.0, -5.0))
	var p1: Vector2 = main.call("world_to_screen", world_pos)
	sub_viewport.canvas_transform = original_transform
	var expected := Vector2(-40.0, -20.0)
	var actual := p1 - p0
	if not actual.is_equal_approx(expected):
		_fail("world_to_screen probe: expected camera delta %s, got %s" % [expected, actual])


func _assert_world_labels_in_view(step: Dictionary) -> void:
	var context := String(step.get("context", "field"))
	var main := get_tree().root.find_child("Main", true, false)
	if main == null:
		_fail("world_labels_in_view probe: Main not found")
		return
	var labels := main.get_node_or_null("WorldLabels")
	if labels == null or not labels.has_method("panel_projections"):
		_fail("world_labels_in_view probe: WorldLabels not found")
		return
	var projections: Array = labels.call("panel_projections", context)
	if projections.is_empty():
		_fail("world_labels_in_view probe: no visible panels for context " + context)
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	for projection: Dictionary in projections:
		var panel_pos: Vector2 = projection["panel_position"]
		var panel_size: Vector2 = projection["panel_size"]
		var panel_rect := Rect2(panel_pos, panel_size)
		if panel_rect.position.x < 0.0 or panel_rect.position.y < 0.0 or panel_rect.end.x > view_size.x or panel_rect.end.y > view_size.y:
			_fail("world_labels_in_view probe: panel %s rect %s outside view %s (context %s)" % [String(projection["id"]), panel_rect, view_size, context])
			return
		var cell_min: Vector2 = projection["cell_min"]
		var cell_max: Vector2 = projection["cell_max"]
		var cell_size: Vector2 = projection["cell_size"]
		var allowed := Rect2(
			cell_min - cell_size,
			(cell_max - cell_min) + cell_size * 2.0
		)
		if not allowed.encloses(panel_rect):
			_fail("world_labels_in_view probe: panel %s rect %s outside anchor cell allowance %s (context %s)" % [String(projection["id"]), panel_rect, allowed, context])
			return


## `policy` selects who drives the PC's turns. Default `dumb` IS `WICombatAI`
## — the melee profile every pre-2026-08-12 victory pin was authored against,
## kept as the default so no existing script changes behaviour.
##
## `competent` swaps in `WICombatPolicies` (qa/combat_policies.gd, #437): the
## same instrument the balance sims tune against, now drivable from a QA run.
## The steel thread runs ALL its fights on it, because the floor policy never
## casts and [Mage] levels 3+ bank on `spell_cast` — a continuous run under
## `dumb` cannot level a caster past 2 no matter how long it plays
## (docs/design/balance-bands-and-policy.md; CHOICE-LOG 2026-08-12).
##
## Ally and enemy turns are untouched in BOTH modes: they never reach this
## loop (their `ai` is non-empty) and `WICombatPolicies.driven` only names the
## PC, so enemies keep their shipped profiles exactly as in the game.
func _combat_autoplay(max_turns: int, policy: String = WICombatPolicies.DUMB) -> void:
	if policy != WICombatPolicies.DUMB and policy != WICombatPolicies.COMPETENT:
		_fail("combat_autoplay: unknown policy %s (expected dumb|competent)" % policy)
		return
	# One instance per FIGHT: the pack it spends is re-read from the live
	# inventory each time, so draughts bought between fights are carried and
	# draughts drunk are gone for good.
	var driver_policy: WICombatPolicies = null
	if policy == WICombatPolicies.COMPETENT:
		driver_policy = _competent_policy()
	for i in max_turns:
		var combat: WICombat = Game.sim.combat
		if combat == null or combat.finished:
			return
		var active: Dictionary = combat.combatants[combat.get_active()]
		if String(active["side"]) == "player" and String(active["ai"]) == "":
			if driver_policy != null:
				driver_policy.take_turn(combat)
			else:
				WICombatAI.take_turn(combat)
		await get_tree().process_frame
	_fail("combat_autoplay: combat did not finish within %d turns" % max_turns)


## Seed the competent policy from the LIVE run: its pack is the PC's actual
## inventory, and drinking routes through `WIGame.combat_use_item` — the same
## call the hotbar's item slot makes — so the item leaves the real pack and
## emits `item_used` + its toast, instead of the sim harness's stand-in.
func _competent_policy() -> WICombatPolicies:
	var p := WICombatPolicies.new(WICombatPolicies.COMPETENT)
	var by_id := {}
	for raw: Variant in Game.sim.inventory:
		var item_id := String(raw)
		if by_id.has(item_id):
			continue
		var rec: Dictionary = Game.sim.item(item_id)
		if not rec.is_empty():
			by_id[item_id] = rec
	p.items_by_id = by_id
	p.carried = {"pc": Array(Game.sim.inventory).duplicate()}
	p.use_item_fn = Callable(Game.sim, "combat_use_item")
	return p


func _loosely_equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _loosely_equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.keys().size() != b.keys().size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _loosely_equal(a[key], b[key]):
				return false
		return true
	return a == b


func _load_all_resources() -> void:
	var to_scan: Array[String] = ["res://"]
	var loaded := 0
	while not to_scan.is_empty():
		var dir_path: String = to_scan.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.include_hidden = false
		for sub: String in dir.get_directories():
			if sub.begins_with(".") or sub in ["addons", "build", "node_modules"]:
				continue
			to_scan.append(dir_path.path_join(sub))
		for f: String in dir.get_files():
			if f.get_extension() in ["gd", "tscn", "tres"]:
				var p := dir_path.path_join(f)
				var res := ResourceLoader.load(p)
				if res == null:
					_fail("failed to load resource: " + p)
				elif res is Script and not (res as Script).can_instantiate():
					_fail("script failed to compile (cannot instantiate): " + p)
				else:
					loaded += 1
	_events_seen.append({"type": "load_gate_done", "payload": {"loaded": loaded}})
	if loaded == 0:
		_fail("load gate scanned zero resources — scan is broken")


func _truthy(raw: String) -> bool:
	return raw.strip_edges().to_lower() in ["1", "true", "yes", "on"]


## GH#436. Every failure line carries the state that produced it. Previously
## only the dialogue-timeout arm printed anything situational (its subset +
## event cursor), so every other red -- a blocked move, a missing toast, a
## wrong `assert_state` -- arrived with no answer to "where was the PC, what
## panel was open, what fight was live", and the next question cost a full
## re-run. Kept to ONE line and deliberately shallow (option TEXT, not the
## whole option dicts; roster hp/side, not the combat snapshot) because
## `load_all_resources` alone can raise dozens of failures.
func _state_dump() -> Dictionary:
	if Game == null or Game.sim == null:
		return {"sim": "none"}
	var sim: WIGame = Game.sim
	var out := {
		"step": _step_index,
		"map": sim.current_map,
		"cell": [sim.player_cell.x, sim.player_cell.y],
		"facing": [sim.player_facing.x, sim.player_facing.y],
		"gold": sim.gold,
		"phase": sim.phase(),
	}
	var dlg := _dialogue_dump()
	if not dlg.is_empty():
		out["dialogue"] = dlg
	var cbt := _combat_dump()
	if not cbt.is_empty():
		out["combat"] = cbt
	return out


## The open conversation as the PLAYER sees it: the visible option rows (the
## only list a `move` step walks) plus the panel's live cursor. The cursor is
## read off DialoguePanel because it lives in the view, not the sim -- and it is
## the number a wrapped mis-count silently corrupts.
func _dialogue_dump() -> Dictionary:
	if Game == null or Game.sim == null or Game.sim.dialogue == null:
		return {}
	var walker: WIDialogue = Game.sim.dialogue
	var texts: Array = []
	for row: Dictionary in walker.current_options():
		texts.append("%s%s" % ["[LOCKED] " if bool(row.get("locked", false)) else "", String(row.get("text", ""))])
	var out := {"node": walker.current_id, "finished": walker.finished, "options": texts}
	var panel := get_tree().root.find_child("DialoguePanel", true, false)
	if panel != null:
		out["cursor"] = panel.get("_cursor")
	return out


func _combat_dump() -> Dictionary:
	if Game == null or Game.sim == null or Game.sim.combat == null:
		return {}
	var combat: WICombat = Game.sim.combat
	var roster: Array = []
	for id: String in combat.combatants:
		var c: Dictionary = combat.combatants[id]
		roster.append("%s(%s hp=%s/%s%s)" % [id, String(c[WIKeys.SIDE]), c[WIKeys.HP],
				c[WIKeys.MAX_HP], "" if bool(c[WIKeys.ALIVE]) else " DEAD"])
	return {
		"round": combat.round_number,
		"active": combat.get_active() if not combat.turn_order.is_empty() else "",
		"finished": combat.finished,
		"roster": roster,
	}


## GH#435 -- can a checkpoint be taken right now? `WISave.serialize` captures
## neither combat nor dialogue, so a checkpoint taken inside one would resume as
## "the moment before, minus the panel": a fixture that lies. Same states
## `save_manual` refuses, for the same reason.
func _sim_quiet() -> bool:
	return Game != null and Game.sim != null and Game.sim.combat == null \
			and Game.sim.dialogue == null


## GH#435. `run_qa.sh` already gives every run an isolated HOME, so the sim's own
## `user://saves/<slot>.json` write is invisible the moment the run ends -- the
## COPY-OUT into `qa_output/<script>/` is what makes a checkpoint survive to be
## the next iteration's `fixture_save`. Returns success; the caller decides
## whether a refusal is a failure (the explicit action) or a reason to wait (the
## `--checkpoint-at` flag).
func _write_checkpoint(slot: String) -> bool:
	var text := JSON.stringify(WISave.serialize(Game.sim))
	DirAccess.make_dir_recursive_absolute("user://saves")
	var slot_file := FileAccess.open("user://saves/%s.json" % slot, FileAccess.WRITE)
	if slot_file == null:
		_fail("checkpoint(%s): could not write user://saves/%s.json" % [slot, slot])
		return false
	slot_file.store_string(text)
	slot_file.close()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var copy_path := _out_dir.path_join("checkpoint_%s.json" % slot)
	var copy_file := FileAccess.open(copy_path, FileAccess.WRITE)
	if copy_file == null:
		_fail("checkpoint(%s): could not copy out to %s" % [slot, copy_path])
		return false
	copy_file.store_string(text)
	copy_file.close()
	print("QA_CHECKPOINT: %s -> %s (step %d, %s %s)" % [slot, copy_path, _step_index,
			Game.sim.current_map, str(Game.sim.player_cell)])
	ObservableBus.emit_domain_event("qa_checkpoint_dumped", {
		"slot": slot,
		"path": copy_path,
		"step": _step_index,
		"map": Game.sim.current_map,
		"cell": [Game.sim.player_cell.x, Game.sim.player_cell.y],
	})
	return true


## The explicit `dump_checkpoint {slot}` action: the author chose this spot, so a
## refusal is a scripting error and says so.
func _dump_checkpoint(slot: String) -> void:
	if Game == null or Game.sim == null:
		_fail("dump_checkpoint: no live sim")
		return
	if not _sim_quiet():
		_fail("dump_checkpoint(%s): refused -- serialize() captures no combat/dialogue, so the checkpoint would not be the state you are standing in" % slot)
		return
	_write_checkpoint(slot)


## GH#435, the flag half: `--checkpoint-at=N[,N...]` checkpoints an EXISTING
## continuous script at step N without editing it -- which matters because the
## script being iterated is usually the one whose purity is the deliverable
## (steel_thread's grep gate), and an authoring edit there is exactly what
## must not happen.
##
## A requested step can land mid-fight or mid-conversation, where a checkpoint
## is not takeable. Rather than failing the run (a diagnostic aid that reds a
## green canonical is a bad trade, and under --fail-fast it would abort it), the
## request DEFERS to the first quiet step after N and the artifact records the
## step it actually landed on. Still owed at the end of the run = a real
## failure: the author asked for a checkpoint and has none.
func _service_checkpoints(step_number: int) -> void:
	if _checkpoint_pending.is_empty() or not _sim_quiet():
		return
	var due: Array[int] = []
	for want: int in _checkpoint_pending:
		if step_number >= want:
			due.append(want)
	for want: int in due:
		_checkpoint_pending.erase(want)
		if _write_checkpoint("step_%d" % want) and step_number != want:
			print("QA_CHECKPOINT_DEFERRED: step %d was inside combat/dialogue; taken at step %d instead" % [want, step_number])


func _fail(msg: String) -> void:
	_failures.append("%s | state=%s" % [msg, JSON.stringify(_state_dump())])


func _finish() -> void:
	if not _checkpoint_pending.is_empty() and not _aborted:
		_fail("checkpoint-at: never found a quiet step for %s -- the whole tail of the run was inside combat/dialogue" % str(_checkpoint_pending))
	var result := {
		"passed": _failures.is_empty(),
		"failures": Array(_failures),
		"screenshots": Array(_screenshots),
		"events_seen": _events_seen.size(),
		"script": _script_path,
		"fail_fast": _fail_fast,
		"aborted": _aborted,
		"steps_run": _steps_run,
		"steps_total": _steps_total,
	}
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var f := FileAccess.open(_out_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	print("QA_RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	for failure: String in _failures:
		print("QA_FAILURE: " + failure)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__WI_QA_EVENTS__ = %s" % JSON.stringify(_events_seen), true)
		JavaScriptBridge.eval("window.__WI_RESULT__ = %s" % JSON.stringify(result), true)
	else:
		get_tree().quit(0 if _failures.is_empty() else 1)
