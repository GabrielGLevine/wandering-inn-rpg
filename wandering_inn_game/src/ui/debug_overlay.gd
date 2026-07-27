extends CanvasLayer

## GH#279: dev-only read-only sim-state inspector (autoload WIDebugOverlay).
## Root-level autoload CanvasLayer BY DESIGN: Main._clear_ui_layers frees
## Main's own children on every title/game transition -- an autoload layer
## is never touched (the survivor-trap dissolver ruled at adjudication).
## READ-ONLY, verbatim guard: this overlay must never mutate sim state --
## a state-poking debug console is a different, more dangerous tool.
## Ship exclusion: OS.is_debug_build() (the Playtest-States idiom,
## title_screen.gd) -- release exports build with --export-release, so the
## overlay never constructs UI, connects, or listens there.
## Captures are FULL-WINDOW (D4): the overlay is hidden by default and
## only the F3 keybind or the toggle_overlay QA step shows it -- a normal
## FEEL capture with the overlay visible is contaminated evidence
## (overlay_loop pins hidden-by-default; qa/MACHINE-PLAYTEST.md rule).

const TAIL_MAX := 20
const REFRESH_MIN_SEC := 0.25

var _panel: PanelContainer
var _label: RichTextLabel
var _tail: Array[Dictionary] = []  # {line: String, counter: String("" = none)}
var _recent_counters: Dictionary = {}  # counter id -> live tail-entry count
var _dirty := false
var _cooldown := 0.0
var _quests_cache: Dictionary = {}


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return
	layer = 90  # above journal (10), below MapTransitionLayer (100)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.62
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.self_modulate = Color(1, 1, 1, 0.92)
	# Review M1: default MOUSE_FILTER_STOP made the right third of the
	# window a click-dead zone with the overlay up (world clicks die in
	# the panel -- reads exactly like the "clicking does nothing" bug
	# class). IGNORE everywhere; the wheel-scroll trade is accepted (the
	# tail is 20 lines).
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	_label = RichTextLabel.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.scroll_active = false
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 11)
	margin.add_child(_label)
	_panel.add_child(margin)
	add_child(_panel)
	ObservableBus.domain_event.connect(_on_domain_event)


func visible_now() -> bool:
	return _panel != null and _panel.visible


func toggle() -> void:
	if _panel == null:
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_render()
		ObservableBus.emit_domain_event(WIEvents.UI_DEBUG_OVERLAY_RENDERED, _payload())
	else:
		_dirty = false  # review L4: no stray hidden render on the next frame
		ObservableBus.emit_domain_event(WIEvents.UI_DEBUG_OVERLAY_HIDDEN, {})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()


func _on_domain_event(type: String, payload: Dictionary) -> void:
	# Own emissions are excluded from the tail (re-entrancy + noise).
	if type == WIEvents.UI_DEBUG_OVERLAY_RENDERED or type == WIEvents.UI_DEBUG_OVERLAY_HIDDEN:
		return
	var summary := type
	for key in ["id", "map", "cell", "reason", "text", "conversation", "quest"]:
		if payload.has(key):
			summary += " %s=%s" % [key, str(payload[key]).left(40)]
			break
	var counter := ""
	if type == WIEvents.ACCOMPLISHMENT_RECORDED:
		counter = String(payload.get("id", ""))
		_recent_counters[counter] = int(_recent_counters.get(counter, 0)) + 1
	_tail.append({"line": summary, "counter": counter})
	if _tail.size() > TAIL_MAX:
		# Review M2: prune the highlight when its event leaves the tail, so
		# the "banked in the last N events" label stays TRUE.
		var evicted: Dictionary = _tail.pop_front()
		var ev_counter := String(evicted.get("counter", ""))
		if ev_counter != "" and _recent_counters.has(ev_counter):
			_recent_counters[ev_counter] = int(_recent_counters[ev_counter]) - 1
			if int(_recent_counters[ev_counter]) <= 0:
				_recent_counters.erase(ev_counter)
	if type == WIEvents.GAME_LOADED or type == WIEvents.GAME_RESET:
		_quests_cache = {}
		_recent_counters = {}
	if _panel != null and _panel.visible:
		_dirty = true


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _dirty and _cooldown == 0.0:
		_dirty = false
		_cooldown = REFRESH_MIN_SEC
		_render()


func _quest_catalog() -> Dictionary:
	# Disk read, NOT the sim's own _combat_config copy (private). Same file,
	# different load moment: after an on-disk quests.json edit but BEFORE
	# reload_data, beats shown here are evaluated against the NEW catalog
	# with the OLD sim's counters (review L2) -- reload to reconverge.
	if _quests_cache.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/quests.json"))
		_quests_cache = parsed if parsed is Dictionary else {}
	return _quests_cache


func _payload() -> Dictionary:
	var snap: Dictionary = Game.sim.snapshot()
	return {
		"map": String(snap.get("current_map", "")),
		"cell": "%s" % [snap.get("player_cell", [])],
		"counters": (snap.get("accomplishments", {}) as Dictionary).size(),
	}


func _render() -> void:
	var snap: Dictionary = Game.sim.snapshot()
	var out: Array[String] = []
	out.append("[b]WI DEBUG[/b] (read-only, F3)  map=[b]%s[/b] cell=%s face=%s phase=%s gold=%s" % [
		snap.get("current_map"), snap.get("player_cell"),
		snap.get("player_facing"), snap.get("phase"), snap.get("gold")])
	out.append("rng.state=%d  slept=%s  classes=%s" % [
		Game.sim.rng.state, snap.get("times_slept"), snap.get("classes")])
	out.append("save: last_slot=%s  last_autosave_trigger=%s" % [
		Game.last_save_slot, Game.last_autosave_trigger])
	var started: Array = snap.get("started_quests", [])
	out.append("[b]quests[/b] started=%s" % [started])
	var catalog := _quest_catalog()
	if not catalog.is_empty() and not started.is_empty():
		var evaluated: Dictionary = WIQuests.evaluate(
			catalog, started, snap.get("accomplishments", {}))
		out.append("  beats: %s" % JSON.stringify(evaluated).left(300))
	out.append("[b]counters[/b] (▲ = banked in the last %d events)" % TAIL_MAX)
	var counters: Dictionary = snap.get("accomplishments", {})
	var keys := counters.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		var mark := "▲" if _recent_counters.has(String(k)) else ""
		parts.append("%s%s:%s" % [mark, k, counters[k]])
	out.append("  " + ", ".join(parts))
	out.append("[b]events (last %d)[/b]" % _tail.size())
	for entry in _tail:
		out.append("  " + String(entry.get("line", "")))
	_label.text = "\n".join(out)
