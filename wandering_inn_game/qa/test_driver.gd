extends Node
## Autoload QA driver. Inert unless `--qa-script=<path>` is passed after `--`.
## Executes a declarative JSON playtest script: injects real keyboard events
## (so the full input pipeline is exercised), waits for ObservableBus events,
## captures screenshots, asserts on the sim snapshot, and writes result.json.
##
## Input injection uses InputEventKey with physical keycodes (NOT
## InputEventAction — action events don't traverse the full input pipeline).

const ACTION_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"interact": KEY_E,
	"confirm": KEY_ENTER,
	"cancel": KEY_ESCAPE,
	"cycle": KEY_TAB,
	## Same physical key as "cycle" above (combat's target-cycle) -- harmless
	## overlap: hotbar_prime is checked only in world.gd's field context
	## (gated out entirely during combat by `_movement_gated()`), cycle only
	## in combat_screen.gd's own `_unhandled_input`; the two contexts never
	## both read a Tab press.
	"hotbar_prime": KEY_TAB,
	"journal": KEY_J,
	"inventory": KEY_I,
	## Digits activate numbered hotbar slots; End Turn shares E with interact
	## (combat consumes input first).
	"hotbar_1": KEY_1,
	"hotbar_2": KEY_2,
	"hotbar_3": KEY_3,
	## The field hotbar can carry more than three slots (a PC that knows
	## [Basic Cleaning]/[Light]/[Snap Freeze]/[Firefly] fills four), so map
	## the full 1..9 digit row the hotbar_N input actions already define --
	## sewers_walkthrough presses hotbar_4 for [Firefly].
	"hotbar_4": KEY_4,
	"hotbar_5": KEY_5,
	"hotbar_6": KEY_6,
	"hotbar_7": KEY_7,
	"hotbar_8": KEY_8,
	"hotbar_9": KEY_9,
	"end_turn": KEY_E,
}
const SCREENSHOT_SETTLE_SECONDS := 0.15
## Same 16px grid every render file (world.gd/board_renderer.gd/
## combat_screen.gd) keeps its own copy of -- the `click` step's cell-center
## math needs it too.
const CELL := 16

var _script_path := ""
var _out_dir := ""
var _failures: PackedStringArray = []
var _events_seen: Array = []
var _screenshots: PackedStringArray = []
## Advanced past the matched event's index (+1) on every successful
## wait_for_event, so the NEXT wait only considers events that happened
## after the previous wait resolved. `assert_event_logged`/`assert_event_absent`
## are audits over the whole run and intentionally do not use this cursor.
## `{"from_start": true}` on a wait_for_event step opts that single wait out
## (scans from index 0) for the rare case a script needs to re-check an
## earlier-window event.
var _wait_cursor := 0
## Set from the script's top-level `creation_ui` field in _run(). When
## true, title_screen's New Game drives the REAL character-creation screen
## instead of the default straight-to-reset skip (see title_screen._skip_creation).
var _wants_creation_ui := false


## True when a QA script is driving this run (native --qa-script or web bridge).
func active() -> bool:
	return not _script_path.is_empty()


## Whether this run opts into the real character-creation UI path.
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
	_install_fixture_saves(parsed.get("fixture_save"))
	if not bool(parsed.get("starts_at_title", false)):
		await _skip_title()
	for step: Dictionary in parsed["steps"]:
		await _execute(step)
	_finish()


## ⟦B6⟧ fixture_save harness affordance: a QA script's top-level `fixture_save`
## field copies `res://qa/fixtures/<name>.json` into an isolated `user://saves/
## <slot>.json` BEFORE the run starts (game.gd/pause_menu/title_screen read
## real save files, so this is the only way to hand a script a starting
## save without walking a live playthrough to it). Copying happens here
## (test_driver, not run_qa.sh) so it lands inside the per-run isolated HOME
## run_qa.sh already sets up -- writing into the real user dir would leak
## fixtures across runs. Accepts either a single fixture name (-> "manual"
## slot, the common case: a QA script that starts from a save via the pause
## menu's Load) or an Array of {"fixture": name, "slot": slot} Dictionaries
## when a script needs more than one slot seeded (save_migration's
## defeat-reload path needs a stale v1 save specifically in "auto", since
## the defeat path reloads that slot, not "manual").
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
		var src_path := "res://qa/fixtures/%s.json" % fixture
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


## The game now boots at the title screen (Main.swap_to_title()). Scripts that
## don't declare "starts_at_title": true don't care about the title beat, so
## auto-drive past it before step 1: one keypress for the "press any key"
## web-audio-gesture beat (src/ui/title_screen.gd), then a second to confirm
## the default-selected "New Game" row once the menu is up. Scripts that DO
## declare "starts_at_title" get raw title control instead (title_flow, S3).
func _skip_title() -> void:
	_inject_action("confirm")
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_for_event("ui_title_rendered", 5.0)
	var new_game_index := _events_seen.size()
	_inject_action("confirm")
	await get_tree().process_frame
	await get_tree().process_frame
	# New Game's Game.reset() emits "game_reset" as harness plumbing, not part
	# of the script's own story -- e.g. defeat_reload asserts game_reset is
	# absent over the WHOLE run to prove defeat reloads the auto slot instead
	# of resetting, and that assertion predates the title screen entirely.
	# Strip this one synthetic occurrence back out so scripts observe exactly
	# what they did before the title screen existed. wait_for_event is
	# untouched by this (it walks forward from _wait_cursor, not from index 0),
	# so downstream events like world_ready are unaffected either way.
	var i := _events_seen.size() - 1
	while i >= new_game_index:
		if _events_seen[i]["type"] == "game_reset":
			_events_seen.remove_at(i)
		i -= 1


func _execute(step: Dictionary) -> void:
	match String(step["action"]):
		"wait_frames":
			for i in int(step.get("frames", 1)):
				await get_tree().process_frame
		"press":
			_inject_action(String(step["name"]))
			await get_tree().process_frame
			await get_tree().process_frame
		"press_field_skill":
			# Casts a field skill BY ID through the real hotbar input path:
			# looks the skill up in the live loadout and injects that slot's
			# hotbar_N key -- scripts stay robust against loadout-order
			# shifts (new innate/class grants renumbering slots) instead of
			# hardcoding slot numbers. Fails loud if the skill isn't on the
			# bar (the explicit-hotbar ruling: interact never casts, so a
			# script that needs a cast MUST find it here).
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
			# World-cell click (issue #57): converts the cell to a screen
			# position via `Main.world_to_screen` -- the SAME forward
			# transform `Main.screen_to_world` (the feature's own click
			# handler) inverts -- so this exercises the real transform chain,
			# not a parallel hardcoded approximation. Clicks the cell's
			# CENTER (where a player's cursor naturally lands), not a corner.
			var cell := Vector2i(int(step["cell"][0]), int(step["cell"][1]))
			var world_pos := Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5
			var screen_pos: Variant = _world_to_screen(world_pos)
			if screen_pos == null:
				_fail("click: could not resolve Main.world_to_screen")
			else:
				_inject_mouse_click(screen_pos as Vector2)
			await get_tree().process_frame
			await get_tree().process_frame
		"click_screen":
			# Raw window-space click (issue #57) -- bypasses the cell->screen
			# math entirely, for a script that wants to click an exact pixel
			# (e.g. a UI element the world-cell form can't address).
			var pos := Vector2(float(step["pos"][0]), float(step["pos"][1]))
			_inject_mouse_click(pos)
			await get_tree().process_frame
			await get_tree().process_frame
		"click_slot":
			# Hotbar slot click (issue #57): resolves the REAL on-screen slot
			# rect at click time via `WIHotbar.slot_rect` (#58) -- field or
			# combat bar, whichever is currently live -- never a hardcoded
			# slot pixel offset, so a chrome/layout change can't silently
			# desync this from what a player would actually click.
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
		"click_pause_row":
			# Pause-menu row click (issue #84): resolves the LIVE PauseMenu
			# node's own `row_rect` (mirrors `click_slot`'s hotbar lookup) --
			# never a hardcoded row pixel offset.
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
			# Issue #78: the pause menu's Save/Load slot-picker row click --
			# same lookup shape as `click_pause_row`, resolving PauseMenu's
			# separate `slot_row_rect` (the picker's own rows, not ROWS).
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
		"click_consolidation_row":
			# Consolidation-prompt row click: resolves the LIVE
			# ConsolidationPrompt node's own `row_rect`, same lookup shape as
			# `click_pause_row` above.
			var cons_row_n := int(step["row"])
			var cp := get_tree().root.find_child("ConsolidationPrompt", true, false)
			if cp == null:
				_fail("click_consolidation_row: ConsolidationPrompt node not found")
			else:
				var cons_rect: Rect2 = cp.call("row_rect", cons_row_n - 1)
				if cons_rect.size == Vector2.ZERO:
					_fail("click_consolidation_row: row %d has no rendered rect" % cons_row_n)
				else:
					_inject_mouse_click(cons_rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_confirm_chip":
			# Issue #106: combat's tap-confirm chip -- resolves the LIVE
			# CombatScreen node's own `confirm_chip_rect()`, same lookup shape
			# as `click_slot`/`click_pause_row`. Empty rect (chip not armed/
			# visible) fails loud, same contract as every other click_* step.
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
			# Issue #106: the NAME step's tappable Begin control -- resolves
			# the LIVE CharCreation node's own `begin_button_rect()`, same
			# lookup shape as `click_char_creation_card`.
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
			# Character-creation sprite-grid card click: resolves the LIVE
			# CharCreation node's own `card_rect`, same lookup shape as
			# `click_pause_row` above.
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
			# Dialogue-option row click (issue #84): resolves the LIVE
			# DialoguePanel node's own `option_rect`, same lookup shape as
			# `click_pause_row` above.
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
			# Settings-panel row click (issue #77): resolves the LIVE
			# SettingsPanel node's own `row_rect`, same lookup shape as
			# `click_pause_row`/`click_title_row`.
			var settings_row_n := int(step["row"])
			var sp := get_tree().root.find_child("SettingsPanel", true, false)
			if sp == null:
				_fail("click_settings_row: SettingsPanel node not found")
			else:
				var rect: Rect2 = sp.call("row_rect", settings_row_n - 1)
				if rect.size == Vector2.ZERO:
					_fail("click_settings_row: row %d has no rendered rect" % settings_row_n)
				else:
					_inject_mouse_click(rect.get_center())
			await get_tree().process_frame
			await get_tree().process_frame
		"click_title_row":
			# Title-screen top-level-menu row click (issue #84): resolves the
			# LIVE TitleScreen node's own `row_rect`, same lookup shape as
			# `click_pause_row`/`click_dialogue_option` above.
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
			# Journal skill-row click (issue #84 QA-teeth): routes through the
			# LIVE Journal node's own `click_skill_row(flat_i)` -- see that
			# method's doc comment for why this targets by logical flat-index
			# rather than resolving a screen rect the way the other click_*
			# steps do (RichTextLabel BBCode meta spans expose no such rect).
			var jn := get_tree().root.find_child("Journal", true, false)
			if jn == null:
				_fail("click_journal_skill: Journal node not found")
			else:
				jn.call("click_skill_row", int(step["flat_index"]))
			await get_tree().process_frame
			await get_tree().process_frame
		"click_inventory_row":
			# Inventory carried-list row click (issue #84 QA-teeth): resolves
			# the LIVE Inventory node's own `item_row_rect`, same lookup shape
			# as `click_pause_row`/`click_settings_row` -- the click handler
			# itself (`_on_items_gui_input` -> `_hover_cursor` + `_confirm()`)
			# shipped with inventory.gd's original mouse-support wave; only
			# this QA-facing rect accessor was missing.
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
		"move_diag":
			# A genuine simultaneous-key-hold diagonal, through the REAL input
			# pipeline -- world.gd's
			# `_combined_move_dir` reads whether the OTHER axis's action is
			# STILL held at the moment an axis's press event dispatches, so
			# unlike `_inject_action` (press then immediate release, no held
			# state ever observable), this holds `a` down THROUGH `b`'s press
			# before releasing either. `a` alone dispatches first and is a
			# real move on its own (nothing else is held yet -- one honest
			# cardinal step), THEN `b`'s press dispatches with `a` still held,
			# which IS the diagonal (a's axis + b's axis combined). This is
			# exactly how two physical keys produce a diagonal -- true
			# simultaneity doesn't exist for sequential event dispatch, so a
			# `move_diag` step always resolves to one cardinal step (`a`)
			# immediately followed by one diagonal step (`a`+`b`), never a
			# lone diagonal -- scripts using this account for both steps.
			for i in int(step.get("steps", 1)):
				_inject_diag(String(step["a"]), String(step["b"]))
				await get_tree().process_frame
				await get_tree().process_frame
		"type_text":
			# Type a name into the char-creation field one real unicode
			# keystroke at a time (char_creation captures these in _unhandled_input,
			# exactly like a player keystroke -- LineEdit GUI focus is not relied on).
			var text := String(step["text"])
			for i in text.length():
				_inject_unicode(text[i])
				await get_tree().process_frame
				await get_tree().process_frame
		"wait_for_event":
			await _wait_for_event(String(step["type"]), float(step.get("timeout_sec", 5.0)), step.get("payload_contains", {}), bool(step.get("from_start", false)))
		"screenshot":
			await _screenshot(String(step["name"]))
		"assert_state":
			_assert_state(step)
		"assert_event_logged":
			if not _has_event(String(step["type"]), step.get("payload_contains", {})):
				_fail("expected event was never emitted: " + String(step["type"]))
		"assert_event_absent":
			if _has_event(String(step["type"]), step.get("payload_contains", {})):
				_fail("expected event to be absent but it was emitted: " + String(step["type"]))
		"assert_event_count":
			# Assert an event fired EXACTLY N times over the whole run
			# (arc_flow proves the epilogue rendered once and never re-fired --
			# absence will not do, since it DID fire once). Scans the full log like
			# _has_event, counting matches.
			var got := _count_events(String(step["type"]), step.get("payload_contains", {}))
			if got != int(step["count"]):
				_fail("event count mismatch for %s: expected %d, got %d" % [String(step["type"]), int(step["count"]), got])
		"assert_save_exists":
			var slot := String(step["slot"])
			if not FileAccess.file_exists("user://saves/%s.json" % slot):
				_fail("expected save slot to exist: " + slot)
		"assert_settings_file_exists":
			# Issue #77: settings.cfg lives under user:// (config-file idiom,
			# NOT save data) -- proves WISettings/WIAudio actually wrote it.
			if not FileAccess.file_exists("user://settings.cfg"):
				_fail("expected user://settings.cfg to exist")
		"assert_audio_bus_send":
			# Issue #77: the SFX-ignores-UI-bus fix, proven by bus GRAPH
			# structure (not by ear) -- `AudioServer.get_bus_send` is Server-side
			# metadata, real headless (see wi_audio.gd's `_setup_buses` doc
			# comment for why bus creation is no longer headless-gated).
			var send_bus_name := String(step["bus"])
			var send_idx := AudioServer.get_bus_index(send_bus_name)
			if send_idx == -1:
				_fail("assert_audio_bus_send: no such bus: " + send_bus_name)
			else:
				var got_send := AudioServer.get_bus_send(send_idx)
				var expected_send := String(step["sends_to"])
				if got_send != expected_send:
					_fail("assert_audio_bus_send: bus %s sends to %s, expected %s" % [send_bus_name, got_send, expected_send])
		"assert_audio_bus_volume":
			# Issue #77: exact volume_db proof for a real slider move -- mirrors
			# wi_audio.gd's own `set_bus_volume` formula (value_0_to_10 -> linear
			# -> linear_to_db) via the SAME builtin the engine uses, so this can
			# never drift from a hand-copied dB constant.
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
			# Issue #76: a RAW dB target, direct AudioServer.get_bus_volume_db read
			# -- the ducking proof (dialogue sidechains the Music bus by
			# WIAudio.MUSIC_DUCK_DB), which has no 0-10 slider formula to derive
			# an expected value from, unlike assert_audio_bus_volume above.
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
			# Issue #77: reads the LIVE WISettings autoload directly (the
			# authoritative in-memory state -- proves reduce_motion/fullscreen/
			# text_scale_step survive a save/load round-trip by construction:
			# WISettings is never touched by Game.load_slot/WISave).
			var settings_path := String(step["path"])
			var settings_got: Variant
			match settings_path:
				"reduce_motion":
					settings_got = WISettings.reduce_motion()
				"fullscreen":
					settings_got = WISettings.is_fullscreen()
				"text_scale_step":
					settings_got = WISettings.text_scale_step()
				_:
					_fail("assert_settings_value: unknown path " + settings_path)
					settings_got = null
			if settings_got != null and not _loosely_equal(settings_got, step["equals"]):
				_fail("assert_settings_value: %s expected %s, got %s" % [settings_path, str(step["equals"]), str(settings_got)])
		"assert_world_to_screen_camera_aware":
			_assert_world_to_screen_camera_aware()
		"assert_world_labels_in_view":
			_assert_world_labels_in_view(step)
		"combat_autoplay":
			await _combat_autoplay(int(step.get("max_turns", 200)))
		"load_all_resources":
			_load_all_resources()
		"teleport":
			# Debug affordance (Floodplains lane): drive the sim's own
			# transition to a map not yet wired into the door graph.
			Game.sim.transition(String(step["map"]), Vector2i(int(step["cell"][0]), int(step["cell"][1])))
			await get_tree().process_frame
			await get_tree().process_frame
		"combat_set_cells":
			# Debug affordance (GH#90 forcing canonical) -- `teleport`'s combat
			# twin: pre-places LIVE combatants at named cells so a geometry-
			# dependent AI arm (area_skill's >=2-no-ally gate) is forced by
			# CONSTRUCTION instead of seed-hunted. Emits the sim's own
			# COMBATANT_MOVED per placement so presentation re-syncs through
			# the SAME render arm a real move uses (no parallel visual path).
			# Never touches rng -- combat determinism unaffected. Fails loud
			# on no live combat, an unknown id, or a non-free cell.
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
			# Re-seeds a fixture into a save slot MID-RUN (same copy path as the
			# top-level `fixture_save` affordance, just deferred to a step).
			# save_migration uses this for its defeat-reload proof: reaching a
			# fightable encounter autosaves a fresh, VALID save over the auto
			# slot (map_changed autosave), so the only way to hold a
			# stale/incompatible auto slot at defeat time is to overwrite auto
			# with the old-version fixture after that autosave but before the
			# loss. Writes a file only; never touches the sim or its rng, so
			# combat determinism is unaffected.
			_install_fixture_saves([{"fixture": String(step["fixture"]), "slot": String(step.get("slot", "auto"))}])
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


## Presses `a` and holds it, THEN presses `b` while `a` is still down, then
## releases both -- see `move_diag`'s doc comment in `_execute`
## for why this (not two independent `_inject_action` calls) is what makes
## `b`'s dispatch see `a` as held via `Input.is_action_pressed`, the exact
## state `world.gd`'s `_combined_move_dir` reads to form a diagonal.
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


## Resolves `Main` and calls its `world_to_screen` (the forward transform;
## `click`'s only consumer) -- returns null if Main isn't found rather than
## crashing, so a mis-timed click step fails loud via `_fail` instead.
func _world_to_screen(world_pos: Vector2) -> Variant:
	var main := get_tree().root.find_child("Main", true, false)
	if main == null or not main.has_method("world_to_screen"):
		return null
	return main.call("world_to_screen", world_pos)


## Finds whichever hotbar is currently live -- combat's (while a fight is
## up) or the field's (otherwise) -- for `click_slot`'s real-geometry lookup.
## Both `combat_screen.gd` and `field_hotbar.gd` expose the SAME
## `hotbar_node()` accessor name on purpose, so this doesn't need to know
## which one it's calling.
func _resolve_hotbar_node() -> Node:
	var screen_name := "CombatScreen" if Game.sim.combat != null else "FieldHotbar"
	var owner_node := get_tree().root.find_child(screen_name, true, false)
	if owner_node == null or not owner_node.has_method("hotbar_node"):
		return null
	return owner_node.call("hotbar_node")


## Real InputEventMouseButton press+release at `pos`, in the ROOT viewport's
## own LOCAL/design coordinate space (1280x720, matching `Main.
## world_to_screen`'s output and `WIHotbar.slot_rect`'s `global_position`
## exactly) -- pushed straight into that viewport via `push_input(...,
## true)`, NOT `Input.parse_input_event`. TRAP found empirically: `Input.
## parse_input_event` treats the position as raw OS/physical-window pixels
## and Godot re-applies the window's stretch/DPI transform on top before any
## Control sees it -- under headless, that transform is NOT the identity
## (confirmed via a throwaway debug probe: an injected (480,328) arrived at
## Controls as roughly (9600,6280), a ~20x mismatch), so a design-space
## position fed through parse_input_event lands nowhere near the intended
## Control. `push_input(event, true)` bypasses that second transform
## entirely -- still the real GUI-input pipeline (`_gui_input`/mouse_filter
## hit-testing all apply normally), just injected at the viewport level
## instead of the OS/DisplayServer level, exactly as `Input.parse_input_event`
## already does for physical keyboard events (which have no such transform to
## dodge).
func _inject_mouse_click(pos: Vector2) -> void:
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


## Inject a single printable character as a real key event (unicode
## set), for the char-creation name field. keycode is left 0 so it can never
## coincide with a mapped action (confirm/cancel/etc.); the creation screen reads
## `event.unicode` for the character.
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


## How many logged events match type/subset (assert_event_count).
func _count_events(type: String, subset: Dictionary = {}) -> int:
	var n := 0
	for e: Dictionary in _events_seen:
		if _event_matches(e, type, subset):
			n += 1
	return n


## Returns the index of the first event at or after `from_index` matching
## type/subset, or -1 if none found yet.
func _find_event_since(type: String, subset: Dictionary, from_index: int) -> int:
	for i in range(from_index, _events_seen.size()):
		if _event_matches(_events_seen[i], type, subset):
			return i
	return -1


## Waits for an event matching type/subset at or after `_wait_cursor` (unless
## `from_start` opts out of the since-marker for this one wait). On success,
## advances `_wait_cursor` to the match index + 1 so the next wait only sees
## events that happened after this one -- this prevents a later wait from
## matching a STALE event that already satisfied an earlier wait in the same
## script (the cumulative-history bug class this since-marker exists to fix).
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
	_fail("timeout (%.1fs) waiting for event: %s" % [timeout_sec, type])


func _screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_events_seen.append({"type": "screenshot_skipped_headless", "payload": {"name": name}})
		return
	await get_tree().create_timer(SCREENSHOT_SETTLE_SECONDS).timeout
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__WI_QA_SHOT__ = %s" % JSON.stringify(name), true)
		var deadline := Time.get_ticks_msec() + 10000
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
	# `contains` (Array membership) instead of `equals`: the resolved value must
	# be an Array holding every wanted element (loosely). Accepts a single value
	# or a list of values. Used to assert a combat kit fields a granted skill.
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


## Anchor-relative WorldLabels probe. Each visible panel for `context` must
## sit within its holder's projected 64px cell rect, expanded by one cell on
## each side -- tighter than a viewport-only smoke test: a label can be
## on-screen and still be detached from the unit it names.
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


func _combat_autoplay(max_turns: int) -> void:
	for i in max_turns:
		var combat: WICombat = Game.sim.combat
		if combat == null or combat.finished:
			return
		var active: Dictionary = combat.combatants[combat.get_active()]
		if String(active["side"]) == "player" and String(active["ai"]) == "":
			WICombatAI.take_turn(combat)
		await get_tree().process_frame
	_fail("combat_autoplay: combat did not finish within %d turns" % max_turns)


## JSON numbers parse as floats; sim state uses ints/bools. Compare loosely.
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
	# Whole-Dictionary equals (e.g. asserting a full `classes` map after an
	# evolution/consolidation) hits the same int-vs-float mismatch as Array
	# elements above -- recurse per-key rather than falling through to strict
	# `==`, which Godot does NOT loosely coerce for numeric leaves.
	if a is Dictionary and b is Dictionary:
		if a.keys().size() != b.keys().size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _loosely_equal(a[key], b[key]):
				return false
		return true
	return a == b


## The script-load gate: load every .gd/.tscn/.tres in the project. A parse
## error in ANY script fails the run — this is the class of bug that shipped
## v2's dead quest chain (load-time parse error in level_up_toast.gd).
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


func _fail(msg: String) -> void:
	_failures.append(msg)


func _finish() -> void:
	var result := {
		"passed": _failures.is_empty(),
		"failures": Array(_failures),
		"screenshots": Array(_screenshots),
		"events_seen": _events_seen.size(),
		"script": _script_path,
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
