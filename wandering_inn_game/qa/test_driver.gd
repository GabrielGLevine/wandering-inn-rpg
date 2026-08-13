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
var _out_dir := ""
## GH#324: how many evidence captures are settling right now (screenshot or
## display probe). Nonzero means "a PNG/probe is about to read the screen", and
## message_layer.gd holds its transient panels open until it drops back to
## zero. See `capture_in_flight` for why this seam exists at all.
var _capture_depth := 0
var _failures: PackedStringArray = []
var _events_seen: Array = []
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
	_events_seen.append({"type": type, "payload": payload})


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
		"assert_dialogue_displayed":
			await _assert_dialogue_displayed(step)
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
	_events_seen.append({"type": "qa_dialogue_displayed", "payload": state})


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
		JavaScriptBridge.eval("window.__WI_RESULT__ = %s" % JSON.stringify(result), true)
	else:
		get_tree().quit(0 if _failures.is_empty() else 1)
