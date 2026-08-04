extends SceneTree

const DIALOGUE_DIR := "res://data/dialogue"
const VIEWPORT_HEIGHT := 720.0


const TOAST_TEXT_WIDTH := 412.0
const TOAST_PANEL_BASE_HEIGHT := 96.0
const TOAST_FOLD_DANGER_PX := 30.0
const TOAST_BOTTOM_RAISED := -264.0
const DIALOGUE_TEXT_WIDTH := 656.0
const DIALOGUE_LINE_CAPACITY := 2

const FEED_TEXT_WIDTH := 248.0
const FEED_PANEL_MAX_HEIGHT := 220.0
const FEED_CONTENT_MARGIN_TOP := 8.0
const FEED_FOLD_DANGER_PX := 30.0

const PANEL_SIZE_X := 720.0
const PANEL_SIZE_Y := 232.0
const PAGE_CHAR_BUDGET := 200
const SENTENCE_BOUNDARY_WINDOW_FRACTION := 0.2
const DIALOGUE_PANEL_TEXT_WIDTH := PANEL_SIZE_X - 56.0  # `_ready()`'s 28+28 margin
const PICKER_MAX_HEIGHT := 684.0
const PICKER_TITLE_TEXT_WIDTH := 520.0
const PICKER_DETAIL_TEXT_WIDTH := DIALOGUE_PANEL_TEXT_WIDTH - 20.0
const PICKER_FONT_SIZES := [
	{"default": 14, "menu": 18, "small": 12},
	{"default": 16, "menu": 21, "small": 14},
	{"default": 18, "menu": 23, "small": 16},
]

const HELP_PANEL_WIDTH := 620.0
const HELP_TEXT_WIDTH := HELP_PANEL_WIDTH - 52.0
const HELP_SECTION_LINE_CAP := 3

## v0.15 A4 — closes VISUAL-LOG VEIL-COPY/UNMEASURED (P4). sleep_veil.gd's own
## line tables hold the widest single-line strings in the game and NOTHING
## measured them: the 1114px Invrisil figure in that entry came from a
## throwaway script, not a gate. Mirrored from sleep_veil.gd with the same
## drift-tripwire idiom every other surface here uses.
const VEIL_PATH := "res://src/ui/sleep_veil.gd"
const VEIL_LINE_TEXT_WIDTH := 880.0
const VEIL_BLOCK_MAX_HEIGHT := 672.0
const VEIL_LINE_FONT_SIZE := 24
const VEIL_LINE_SEPARATIONS := [18, 14, 10, 6]
## A veil line may fold to a second row (that is the point of the wrap budget);
## a third row means the copy is a paragraph, not a line, and belongs in a
## dialogue panel.
const VEIL_LINE_MAX_ROWS := 2
## Every const table in sleep_veil.gd that holds player-facing copy. Counter ids
## share these arrays with their lines and are filtered out by
## `_looks_like_identifier` rather than by position, so a table gaining a third
## column cannot silently drop out of the sweep.
const VEIL_COPY_TABLES := [
	"OPENER_LINES", "FINALE_LINES_OPEN", "FINALE_ACT_LINES", "FINALE_REGION_LINES",
	"FINALE_CLOSE_LINES", "FINALE_LINK_LINE", "SEAL_TRANSITION_LINE",
	"WATCH_RUNNER_VEIL_LINE",
	"_EVOLUTION_RESULT_FLAVOR",
	# GH#372's defeat closers. `_defeat_lines()` composes line 3 from this table,
	# and the two gated variants only ever render behind a map+counter gate --
	# so without a row here they would be the only veil copy in the file that
	# ships unmeasured, and the next edit to them would be unmeasured too.
	# Dictionary-shaped exactly like _EVOLUTION_RESULT_FLAVOR: the keys
	# ("pre_spar"/"pre_sleep"/"default") are filtered by `_looks_like_identifier`.
	"DEFEAT_NUDGE_LINES",
]


const TOAST_FIELDS := [
	"observe", "toast", "open_toast", "locked_toast", "sleep_toast",
	"burn_toast", "friendly_line", "gate_closed_toast", "second_visit_toast",
	"skill_hint_toast", "item_hint_toast", "once_per_waking_toast",
]

var _label: Label
var _font: Font
## sleep_veil.gd draws through the "Header" type variation, which may carry its
## own font resource -- measuring the veil with the default label font would be
## a different typeface's metrics.
var _veil_font: Font
var _font_size: int
var _line_spacing: float
var _pitch: float

var _failures: Array[String] = []


func _init() -> void:
	WITestWatchdog.arm(self)
	_check_drift_tripwires()
	await _setup_font_metrics()

	_check_skeleton_scene()
	_check_arena_tutor_lines()
	_check_skill_toasts()
	_check_dialogue_graphs()
	_check_bounty_delivery_copy()
	_check_bounty_delivery_titles()
	_check_picker_layouts()
	_check_board_rumors()
	_check_help_content()
	_check_veil_lines()
	_check_combat_hint_lines()

	print("copy_fit: %d strings measured across all surfaces" % _measured_count)
	if not _failures.is_empty():
		print("copy_fit: %d OVERFLOW(S) FOUND:" % _failures.size())
		for f: String in _failures:
			print("  " + f)
	assert(_failures.is_empty(), "%d copy-fit overflow(s) -- see printed list above" % _failures.size())
	print("PASS: every authored player-facing string fits its panel budget")
	quit(0)


func _check_drift_tripwires() -> void:
	_assert_const_matches("res://src/ui/message_layer.gd", "TOAST_TEXT_WIDTH", str(TOAST_TEXT_WIDTH))
	_assert_const_matches("res://src/ui/message_layer.gd", "TOAST_FOLD_DANGER_PX", str(TOAST_FOLD_DANGER_PX))
	_assert_const_matches("res://src/ui/message_layer.gd", "TOAST_BOTTOM_RAISED", str(TOAST_BOTTOM_RAISED))
	_assert_const_matches("res://src/ui/message_layer.gd", "DIALOGUE_TEXT_WIDTH", str(DIALOGUE_TEXT_WIDTH))
	_assert_const_matches("res://src/ui/message_layer.gd", "DIALOGUE_LINE_CAPACITY", str(DIALOGUE_LINE_CAPACITY))
	_assert_const_matches("res://src/combat/combat_hud.gd", "FEED_TEXT_WIDTH", str(FEED_TEXT_WIDTH))
	_assert_const_matches("res://src/combat/combat_hud.gd", "FEED_PANEL_MAX_HEIGHT", str(FEED_PANEL_MAX_HEIGHT))
	_assert_const_matches("res://src/combat/combat_hud.gd", "FEED_CONTENT_MARGIN_TOP", str(FEED_CONTENT_MARGIN_TOP))
	_assert_const_matches("res://src/combat/combat_hud.gd", "FEED_FOLD_DANGER_PX", str(FEED_FOLD_DANGER_PX))
	_assert_const_matches(VEIL_PATH, "VEIL_LINE_TEXT_WIDTH", str(VEIL_LINE_TEXT_WIDTH))
	_assert_const_matches(VEIL_PATH, "VEIL_BLOCK_MAX_HEIGHT", str(VEIL_BLOCK_MAX_HEIGHT))
	_assert_const_matches(VEIL_PATH, "LINE_FONT_SIZE", str(VEIL_LINE_FONT_SIZE))
	_assert_const_matches(VEIL_PATH, "VEIL_LINE_SEPARATIONS", str(VEIL_LINE_SEPARATIONS))
	_assert_const_matches("res://src/ui/dialogue_panel.gd", "PAGE_CHAR_BUDGET", str(PAGE_CHAR_BUDGET))
	_assert_const_matches("res://src/ui/dialogue_panel.gd", "SENTENCE_BOUNDARY_WINDOW_FRACTION", str(SENTENCE_BOUNDARY_WINDOW_FRACTION))
	_assert_const_matches("res://src/ui/dialogue_panel.gd", "PICKER_MAX_HEIGHT", str(PICKER_MAX_HEIGHT))
	var src := FileAccess.get_file_as_string("res://src/ui/dialogue_panel.gd")
	assert(src.contains("Vector2(720.0, 232.0)"), "dialogue_panel.gd's PANEL_SIZE literal drifted from the mirrored PANEL_SIZE_X/Y (720.0, 232.0) -- update this test's mirrored consts")
	var settings_src := FileAccess.get_file_as_string("res://src/ui/settings_panel.gd")
	assert(settings_src.contains("const HELP_PANEL_SIZE := Vector2(620.0, 530.0)"), "settings_panel.gd's HELP_PANEL_SIZE literal drifted from the mirrored HELP_PANEL_WIDTH (620.0) -- update this test's mirrored consts")
	assert(settings_src.contains("const HELP_TEXT_WIDTH := HELP_PANEL_SIZE.x - 52.0"), "settings_panel.gd's HELP_TEXT_WIDTH derivation drifted from the mirrored HELP_TEXT_WIDTH (HELP_PANEL_WIDTH - 52.0) -- update this test's mirrored const")


func _assert_const_matches(path: String, const_name: String, expected_value: String) -> void:
	var src := FileAccess.get_file_as_string(path)
	assert(src != "", "could not read " + path)
	var re := RegEx.new()
	re.compile("const\\s+%s\\s*:=\\s*([^\\n]+)" % const_name)
	var m := re.search(src)
	assert(m != null, "%s: could not find `const %s := ...`" % [path, const_name])
	var found := m.get_string(1).strip_edges()
	assert(found == expected_value, "DRIFT: %s's `%s` is `%s` in source but this test mirrors `%s` -- update the mirrored const" % [path, const_name, found, expected_value])


func _setup_font_metrics() -> void:
	var root := Control.new()
	get_root().add_child(root)
	UIChrome.apply_theme(root)
	_label = UIChrome.make_label("x")
	root.add_child(_label)
	var veil_label := UIChrome.make_label("x", "Header")
	root.add_child(veil_label)
	await process_frame
	_font = _label.get_theme_font("font")
	_veil_font = veil_label.get_theme_font("font")
	assert(_veil_font != null, "the Header type variation's font failed to load headless -- the veil measurement would silently use the wrong typeface")
	_font_size = _label.get_theme_font_size("font_size")
	assert(_font_size == 14, "theme font_size did not settle to wi_ui_theme's 14 (got %d) -- the one-frame settle regressed" % _font_size)
	_line_spacing = float(_label.get_theme_constant("line_spacing"))
	_pitch = _font.get_height(_font_size) + _line_spacing
	assert(_font != null, "theme font failed to load headless -- exact-font method unavailable (see STOP trigger)")


func _wrapped_line_count(text: String, width: float) -> int:
	if text == "":
		return 0
	var size := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, _font_size)
	var line_height := _font.get_height(_font_size)
	if line_height <= 0.0:
		return 1
	return max(int(round(size.y / line_height)), 1)


func _single_line_width(text: String) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x


func _has_unsplittable_word(text: String, width: float) -> bool:
	for word: String in text.split(" ", false):
		if _single_line_width(word) > width:
			return true
	return false


var _measured_count := 0


func _fail(surface: String, path: String, text: String, detail: String) -> void:
	_failures.append("[%s] %s: %s (\"%s\")" % [surface, path, detail, text.left(80)])



func _check_skeleton_scene() -> void:
	var scene := WISceneCatalog.compose()
	for map_id: String in scene.get("maps", {}):
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var eid := String(entity.get("id", "?"))
			var loc := "data/skeleton_scene.json[maps.%s.entities.%s]" % [map_id, eid]
			for field: String in TOAST_FIELDS:
				if entity.has(field):
					# GH#334 ruling 3: `sleep_toast` may be an ARRAY of
					# `{when, text}` rungs (interactions.gd's
					# `_resolve_sleep_toast`), not just a String -- and a
					# late-tier rung is exactly the kind of copy that renders in
					# one game state only and so never meets a playtester's eye.
					# Measure every rung; a bare String still measures itself.
					if entity[field] is Array:
						for ri: int in (entity[field] as Array).size():
							var rung: Variant = entity[field][ri]
							if rung is Dictionary and (rung as Dictionary).has("text"):
								_check_toast("%s.%s[%d].text" % [loc, field, ri], String((rung as Dictionary)["text"]))
					else:
						_check_toast(loc + "." + field, String(entity[field]))
				# v0.15 A4: `<field>_variants` (interactions.gd's
				# LATER-SATISFIED-WINS entity contract) carries REPLACEMENT copy for
				# the same panel and was never measured. A variant is exactly where
				# an unmeasured overflow hides: it renders in one late game state
				# only, so no ordinary playtest pass sees it.
				for vi: int in (entity.get(field + "_variants", []) as Array).size():
					var raw_variant: Variant = entity[field + "_variants"][vi]
					if not (raw_variant is Dictionary):
						continue
					var variant: Dictionary = raw_variant
					if variant.has(field):
						_check_toast("%s.%s_variants[%d].%s" % [loc, field, vi, field], String(variant[field]))
			# v0.15 T3.2 (VISUAL-LOG TOAST/LENGTH). `skill_uses` toasts reach the
			# SAME panel through field_skills.gd's dispatch, and the longest toast
			# in the game is one of their variants (the [Detect Magic] quartet
			# payoff) -- measured by nothing until now, so the ceiling it set was
			# a claim rather than a gate.
			for skill_id: String in (entity.get("skill_uses", {}) as Dictionary):
				var use: Dictionary = entity["skill_uses"][skill_id]
				var use_loc := "%s.skill_uses.%s" % [loc, skill_id]
				if use.has("toast"):
					_check_toast(use_loc + ".toast", String(use["toast"]))
				for vi: int in (use.get("variants", []) as Array).size():
					var raw_use: Variant = use["variants"][vi]
					if not (raw_use is Dictionary):
						continue
					if (raw_use as Dictionary).has("toast"):
						_check_toast("%s.variants[%d].toast" % [use_loc, vi], String((raw_use as Dictionary)["toast"]))
			if entity.has("talk_pool"):
				for i: int in (entity["talk_pool"] as Array).size():
					var raw: Variant = entity["talk_pool"][i]
					if raw is String:
						_check_ambient_bark("%s.talk_pool[%d]" % [loc, i], String(raw))
			for si: int in (entity.get("talk_pool_stages", []) as Array).size():
				var stage: Dictionary = entity["talk_pool_stages"][si]
				for li: int in (stage.get("lines", []) as Array).size():
					var raw_line: Variant = stage["lines"][li]
					if raw_line is String:
						_check_ambient_bark("%s.talk_pool_stages[%d].lines[%d]" % [loc, si, li], String(raw_line))
			for di: int in (entity.get("dialogue", []) as Array).size():
				var line: Dictionary = entity["dialogue"][di]
				if line.has("text"):
					_check_ambient_bark("%s.dialogue[%d].text" % [loc, di], String(line["text"]))



func _check_arena_tutor_lines() -> void:
	var data := _load_json("res://data/arenas.json")
	for arena: Dictionary in data.get("arenas", []):
		var arena_id := String(arena.get("id", "?"))
		for i: int in (arena.get("tutor_lines", []) as Array).size():
			var entry: Dictionary = arena["tutor_lines"][i]
			var loc := "data/arenas.json[arenas.%s.tutor_lines[%d]]" % [arena_id, i]
			if entry.has("line"):
				_check_feed(loc + ".line", String(entry["line"]))
			if entry.has("fallback_line"):
				_check_feed(loc + ".fallback_line", String(entry["fallback_line"]))
			if entry.has("solo_fallback_line"):
				_check_feed(loc + ".solo_fallback_line", String(entry["solo_fallback_line"]))



func _check_skill_toasts() -> void:
	var data := _load_json("res://data/skills.json")
	for skill: Dictionary in data.get("skills", []):
		var skill_id := String(skill.get("id", "?"))
		var loc := "data/skills.json[skills.%s]" % skill_id
		if skill.has("field_ambient") and String(skill["field_ambient"]) != "":
			_check_toast(loc + ".field_ambient", String(skill["field_ambient"]))
		if skill.has("freeze_toast"):
			_check_toast(loc + ".freeze_toast", String(skill["freeze_toast"]))



func _check_dialogue_graphs() -> void:
	var dir := DirAccess.open(DIALOGUE_DIR)
	assert(dir != null, "missing dialogue directory")
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var full_path := DIALOGUE_DIR.path_join(file_name)
		var graph := _load_json(full_path)
		for node_id: String in graph.get("nodes", {}):
			if node_id.begins_with("_"):
				continue
			var node: Dictionary = graph["nodes"][node_id]
			var loc := "%s[nodes.%s]" % [full_path, node_id]
			if node.has("text"):
				_check_dialogue_body(loc + ".text", String(node["text"]))
			for vi: int in (node.get("text_variants", []) as Array).size():
				var variant: Dictionary = node["text_variants"][vi]
				if variant.has("text"):
					_check_dialogue_body("%s.text_variants[%d].text" % [loc, vi], String(variant["text"]))
			for oi: int in (node.get("options", []) as Array).size():
				var opt: Dictionary = node["options"][oi]
				_check_dialogue_option("%s.options[%d]" % [loc, oi], opt, oi)


func _check_bounty_delivery_copy() -> void:
	var bounties := _load_json("res://data/bounties.json")
	for bounty: Dictionary in bounties.get("bounties", []):
		_check_dialogue_body("data/bounties.json[bounties.%s].copy" % String(bounty.get("id", "?")), String(bounty.get("copy", "")))
	var deliveries := _load_json("res://data/deliveries.json")
	for delivery: Dictionary in deliveries.get("deliveries", []):
		_check_dialogue_body("data/deliveries.json[deliveries.%s].slip_copy" % String(delivery.get("id", "?")), String(delivery.get("slip_copy", "")))


func _check_bounty_delivery_titles() -> void:
	var bounties := _load_json("res://data/bounties.json")
	for bounty: Dictionary in bounties.get("bounties", []):
		var id := String(bounty.get("id", "?"))
		var rendered := "> 1. Take: %s. (%d gold)" % [WIBounties._posting_title(id), int(bounty.get("gold", 0))]
		_measured_count += 1
		var width := _single_line_width(rendered)
		if width > DIALOGUE_PANEL_TEXT_WIDTH:
			_fail("DIALOGUE-PANEL/option", "data/bounties.json[bounties.%s]" % id, rendered, "single-line width %.0fpx > %.0fpx panel width (no autowrap on option rows)" % [width, DIALOGUE_PANEL_TEXT_WIDTH])
	var deliveries := _load_json("res://data/deliveries.json")
	for delivery: Dictionary in deliveries.get("deliveries", []):
		var did := String(delivery.get("id", "?"))
		var drendered := "> 1. Take: %s. (%d gold)" % [WIBounties._delivery_title(did), int(delivery.get("gold", 0))]
		_measured_count += 1
		var dwidth := _single_line_width(drendered)
		if dwidth > DIALOGUE_PANEL_TEXT_WIDTH:
			_fail("DIALOGUE-PANEL/option", "data/deliveries.json[deliveries.%s]" % did, drendered, "single-line width %.0fpx > %.0fpx panel width (no autowrap on option rows)" % [dwidth, DIALOGUE_PANEL_TEXT_WIDTH])


func _check_picker_layouts() -> void:
	var bounty_pool: Array = _load_json("res://data/bounties.json").get("bounties", [])
	var delivery_pool: Array = _load_json("res://data/deliveries.json").get("deliveries", [])
	_check_picker_pool("bounty", bounty_pool, Callable(WIBounties, "build_picker_graph"))
	_check_picker_pool("delivery", delivery_pool, Callable(WIBounties, "build_delivery_picker_graph"))


func _check_picker_pool(kind: String, pool: Array, graph_builder: Callable) -> void:
	for start in pool.size():
		var slate: Array = []
		for offset in mini(3, pool.size()):
			slate.append(pool[(start + offset) % pool.size()])
		var graph: Dictionary = graph_builder.call(slate)
		var node: Dictionary = graph["nodes"]["hub"]
		var dialogue := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}}, Callable())
		dialogue.begin()
		var derived := WIPickerPresenter.derive(String(node["text"]), dialogue.current_options())
		var rows: Array = derived["rows"]
		if rows.size() != slate.size() + 1:
			_fail("PICKER", "%s slate start %d" % [kind, start], str(rows), "row count %d != slate+cancel %d" % [rows.size(), slate.size() + 1])
			continue
		for i in slate.size():
			var row: Dictionary = rows[i]
			if String(row["title"]).is_empty() or String(row["reward"]).is_empty() or String(row["detail"]).is_empty():
				_fail("PICKER", "%s slate start %d row %d" % [kind, start, i], str(row), "title/reward/detail hierarchy incomplete")
		if not bool((rows[-1] as Dictionary).get("cancel", false)):
			_fail("PICKER", "%s slate start %d" % [kind, start], str(rows[-1]), "final selectable row is not cancel")
		for scale_step in PICKER_FONT_SIZES.size():
			var needed := _picker_required_height(String(derived["prompt"]), rows, PICKER_FONT_SIZES[scale_step])
			_measured_count += rows.size()
			if needed > PICKER_MAX_HEIGHT:
				_fail("PICKER", "%s slate start %d scale %d" % [kind, start, scale_step], str(rows), "complete card list needs %.0fpx > %.0fpx viewport budget" % [needed, PICKER_MAX_HEIGHT])


func _picker_required_height(prompt: String, rows: Array, sizes: Dictionary) -> float:
	const CONTENT_MARGINS := 52.0
	const RIBBON_HEIGHT := 42.0
	const STACK_SEPARATIONS := 12.0
	const CARD_MARGINS_Y := 10.0
	const CARD_INNER_SEPARATION := 2.0
	const CARD_SEPARATIONS := 6.0
	var height := CONTENT_MARGINS + RIBBON_HEIGHT + STACK_SEPARATIONS
	height += maxf(24.0, _text_block_height(prompt, DIALOGUE_PANEL_TEXT_WIDTH, int(sizes["default"])))
	height += CARD_SEPARATIONS * max(rows.size() - 1, 0)
	for row: Dictionary in rows:
		var title_height := _text_block_height(String(row["title"]), PICKER_TITLE_TEXT_WIDTH, int(sizes["menu"]))
		var reward_height := _text_block_height(String(row["reward"]), PICKER_DETAIL_TEXT_WIDTH, int(sizes["menu"]))
		height += CARD_MARGINS_Y + maxf(title_height, reward_height)
		if not String(row["detail"]).is_empty():
			height += CARD_INNER_SEPARATION + _text_block_height(String(row["detail"]), PICKER_DETAIL_TEXT_WIDTH, int(sizes["small"]))
	return height


func _text_block_height(text: String, width: float, font_size: int) -> float:
	if text.is_empty():
		return 0.0
	var measured: Vector2 = _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height: float = _font.get_height(font_size)
	var lines: int = max(int(round(measured.y / line_height)), 1) if line_height > 0.0 else 1
	return float(lines) * line_height + float(max(lines - 1, 0)) * _line_spacing


func _check_board_rumors() -> void:
	var scene := WISceneCatalog.compose()
	for map_id: String in scene.get("maps", {}):
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var eid := String(entity.get("id", "?"))
			for ri: int in (entity.get("board_rumors", []) as Array).size():
				var rumor: Dictionary = entity["board_rumors"][ri]
				if rumor.has("copy"):
					_check_dialogue_body("data/skeleton_scene.json[maps.%s.entities.%s].board_rumors[%d].copy" % [map_id, eid, ri], String(rumor["copy"]))


func _check_help_content() -> void:
	var data := _load_json("res://data/help_content.json")
	var sections: Array = data.get("sections", [])
	for i in sections.size():
		var section: Dictionary = sections[i]
		var loc := "data/help_content.json[sections[%d]]" % i
		var line := "%s — %s" % [String(section.get("heading", "")), String(section.get("body", ""))]
		_measured_count += 1
		if _has_unsplittable_word(line, HELP_TEXT_WIDTH):
			_fail("HELP", loc, line, "contains a single word wider than the %dpx Help-panel width" % int(HELP_TEXT_WIDTH))
			continue
		var lines := _wrapped_line_count(line, HELP_TEXT_WIDTH)
		if lines > HELP_SECTION_LINE_CAP:
			_fail("HELP", loc, line, "%d wrapped lines > %d-line fixed-panel budget (HELP_PANEL_SIZE has no ScrollContainer)" % [lines, HELP_SECTION_LINE_CAP])



## VEIL-COPY/UNMEASURED (P4). Two arms: every authored veil string fits the
## column (wrapping to at most VEIL_LINE_MAX_ROWS), and the WORST-CASE finale
## block -- every region/act presence banked, the longest path close, and three
## held classes -- fits the viewport at some rung of the separation ladder, so
## `_apply_line_budget` never has to evict a line the player has not read.
func _check_veil_lines() -> void:
	var src := FileAccess.get_file_as_string(VEIL_PATH)
	assert(src != "", "could not read " + VEIL_PATH)
	for table: String in VEIL_COPY_TABLES:
		for line: String in _veil_copy_in(src, table):
			_check_veil_line("sleep_veil.gd[%s]" % table, line)
	for line: String in _veil_composed_lines():
		_check_veil_line("sleep_veil.gd[composed]", line)

	var worst: Array[String] = []
	worst.append_array(_veil_copy_in(src, "FINALE_LINES_OPEN"))
	# Three classes is the shipped ceiling a player can carry into the finale
	# (two starts plus one evolution/consolidation survivor); the recount prints
	# one line each, so they are part of the block whether or not they are copy.
	for i in 3:
		worst.append("[%s Level %d.]" % [_longest_class_name(), 20])
	worst.append_array(_veil_copy_in(src, "FINALE_ACT_LINES"))
	worst.append_array(_veil_copy_in(src, "FINALE_REGION_LINES"))
	worst.append(_longest_of(_veil_copy_in(src, "FINALE_CLOSE_LINES")))
	worst.append_array(_veil_copy_in(src, "FINALE_LINK_LINE"))
	var fitted := false
	var tightest_height := 0.0
	for raw_sep: Variant in VEIL_LINE_SEPARATIONS:
		tightest_height = _veil_block_height(worst, float(raw_sep))
		if tightest_height <= VEIL_BLOCK_MAX_HEIGHT:
			fitted = true
			break
	if not fitted:
		_fail("VEIL/BLOCK", "sleep_veil.gd[_finale_lines]", " / ".join(worst),
			"worst-case finale is %d lines and needs %.0fpx at the tightest separation > %.0fpx viewport budget -- lines would evict unread" % [worst.size(), tightest_height, VEIL_BLOCK_MAX_HEIGHT])


func _check_veil_line(loc: String, text: String) -> void:
	if text == "":
		return
	_measured_count += 1
	if _has_unsplittable_word_at(text, VEIL_LINE_TEXT_WIDTH, VEIL_LINE_FONT_SIZE):
		_fail("VEIL/LINE", loc, text, "contains a single word wider than the %dpx veil column" % int(VEIL_LINE_TEXT_WIDTH))
		return
	var rows := _wrapped_line_count_at(text, VEIL_LINE_TEXT_WIDTH, VEIL_LINE_FONT_SIZE)
	if rows > VEIL_LINE_MAX_ROWS:
		_fail("VEIL/LINE", loc, text, "%d wrapped rows > %d-row veil budget (this is a paragraph, not a GDI line)" % [rows, VEIL_LINE_MAX_ROWS])


## The runtime lines sleep_veil.gd composes from data rather than authoring:
## the class/skill/evolution announcements and the consolidation offer, built
## here with the LONGEST shipped display names so the widest real line is the
## one measured.
func _veil_composed_lines() -> Array[String]:
	var cls := _longest_class_name()
	var skill := _longest_skill_name()
	return [
		"[%s Class Obtained!]" % cls,
		"[Skill – %s Obtained!]" % skill,
		"[%s Level %d!]" % [cls, 20],
		"[%s Class → %s Class!]" % [cls, cls],
		"[%s and %s pull toward one another. The Design offers: %s.]" % [cls, cls, cls],
	]


func _longest_class_name() -> String:
	var best := ""
	for cls: Dictionary in _load_json("res://data/classes.json").get("classes", []):
		var name := String(cls.get("display_name", ""))
		if _single_line_width_at(name, VEIL_LINE_FONT_SIZE) > _single_line_width_at(best, VEIL_LINE_FONT_SIZE):
			best = name
	return best


func _longest_skill_name() -> String:
	var best := ""
	for skill: Dictionary in _load_json("res://data/skills.json").get("skills", []):
		var name := String(skill.get("display_name", ""))
		if _single_line_width_at(name, VEIL_LINE_FONT_SIZE) > _single_line_width_at(best, VEIL_LINE_FONT_SIZE):
			best = name
	return best


func _longest_of(lines: Array[String]) -> String:
	var best := ""
	for line: String in lines:
		if _single_line_width_at(line, VEIL_LINE_FONT_SIZE) > _single_line_width_at(best, VEIL_LINE_FONT_SIZE):
			best = line
	return best


func _veil_block_height(lines: Array[String], separation: float) -> float:
	var rows := 0
	for line: String in lines:
		rows += _wrapped_line_count_at(line, VEIL_LINE_TEXT_WIDTH, VEIL_LINE_FONT_SIZE)
	if rows == 0:
		return 0.0
	return float(rows) * _veil_font.get_height(VEIL_LINE_FONT_SIZE) + float(max(lines.size() - 1, 0)) * separation


## Pulls every double-quoted string out of one const block of sleep_veil.gd and
## drops the ones that are accomplishment ids rather than copy. Source-parsed on
## purpose: a mirrored copy of these tables would rot the first time a line is
## reworded, and the drift tripwires above already pin the numbers.
func _veil_copy_in(src: String, const_name: String) -> Array[String]:
	var after := src.get_slice("const %s" % const_name, 1)
	assert(after != "", "sleep_veil.gd has no `const %s` -- this test's VEIL_COPY_TABLES drifted" % const_name)
	var stop := after.length()
	for terminator: String in ["\nconst ", "\nvar ", "\nfunc ", "\nsignal "]:
		var at := after.find(terminator)
		if at != -1:
			stop = mini(stop, at)
	# COMMENT LINES OUT FIRST. A const's block runs to the NEXT declaration, which
	# means it swallows that declaration's own `##` doc comment -- and a doc
	# comment quoting a phrase ("known face") would otherwise be measured as veil
	# copy and counted into the finale's line budget.
	var block := ""
	for line: String in after.substr(0, stop).split("\n"):
		if not line.strip_edges().begins_with("#"):
			block += line + "\n"
	var re := RegEx.new()
	re.compile("\"([^\"]*)\"")
	var out: Array[String] = []
	for m: RegExMatch in re.search_all(block):
		var text := m.get_string(1)
		if text == "" or _looks_like_identifier(text):
			continue
		out.append(text)
	return out


func _looks_like_identifier(text: String) -> bool:
	if text.contains(" "):
		return false
	for i in text.length():
		var c := text[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true


func _wrapped_line_count_at(text: String, width: float, font_size: int) -> int:
	if text == "":
		return 0
	var size := _veil_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := _veil_font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	return max(int(round(size.y / line_height)), 1)


func _single_line_width_at(text: String, font_size: int) -> float:
	return _veil_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _has_unsplittable_word_at(text: String, width: float, font_size: int) -> bool:
	for word: String in text.split(" ", false):
		if _single_line_width_at(word, font_size) > width:
			return true
	return false


func _check_ambient_bark(loc: String, text: String) -> void:
	_measured_count += 1
	if _has_unsplittable_word(text, DIALOGUE_TEXT_WIDTH):
		_fail("AMBIENT-BARK", loc, text, "contains a single word wider than the %dpx bark width" % int(DIALOGUE_TEXT_WIDTH))
		return
	var lines := _wrapped_line_count(text, DIALOGUE_TEXT_WIDTH)
	if lines > DIALOGUE_LINE_CAPACITY:
		_fail("AMBIENT-BARK", loc, text, "%d wrapped lines > %d-line ellipsis-truncate budget" % [lines, DIALOGUE_LINE_CAPACITY])


func _check_toast(loc: String, text: String) -> void:
	_measured_count += 1
	if text == "":
		return
	if _has_unsplittable_word(text, TOAST_TEXT_WIDTH):
		_fail("TOAST", loc, text, "contains a single word wider than the %dpx toast width" % int(TOAST_TEXT_WIDTH))
		return
	var lines := _wrapped_line_count(text, TOAST_TEXT_WIDTH)
	var text_block := float(lines) * _pitch - _line_spacing
	var panel_height := maxf(TOAST_PANEL_BASE_HEIGHT, text_block + 2.0 * TOAST_FOLD_DANGER_PX)
	var bottom_y := VIEWPORT_HEIGHT + TOAST_BOTTOM_RAISED
	var top_y := bottom_y - panel_height
	if top_y < 0.0:
		_fail("TOAST", loc, text, "%d wrapped lines grows the toast panel to %.0fpx, pushing its top %.0fpx off-screen (raised anchor)" % [lines, panel_height, -top_y])


## combat_screen.gd composes one-shot disclosure lines straight into the feed,
## outside every data table this suite walks. They are held to the same feed
## budget as an arena's authored tutor line.
func _check_combat_hint_lines() -> void:
	var src := FileAccess.get_file_as_string("res://src/combat/combat_screen.gd")
	assert(src != "", "could not read combat_screen.gd")
	# GH#334 notes 19/28 added FIRST_HP_HINT_LINE beside the MP one -- and it is
	# the LONGER of the two, so measuring only the MP line would have left the
	# wider string unmeasured. Both are swept by name; a rename fails loud.
	for const_name: String in ["FIRST_MP_HINT_LINE", "FIRST_HP_HINT_LINE"]:
		var re := RegEx.new()
		re.compile("const %s := \"([^\"]*)\"" % const_name)
		var m := re.search(src)
		assert(m != null, "combat_screen.gd has no `const %s` -- this check drifted" % const_name)
		_check_feed("combat_screen.gd[%s]" % const_name, m.get_string(1))


func _check_feed(loc: String, text: String) -> void:
	_measured_count += 1
	if text == "":
		return
	if _has_unsplittable_word(text, FEED_TEXT_WIDTH):
		_fail("FEED", loc, text, "contains a single word wider than the %dpx feed width" % int(FEED_TEXT_WIDTH))
		return
	var capacity_height := FEED_PANEL_MAX_HEIGHT - FEED_CONTENT_MARGIN_TOP - FEED_FOLD_DANGER_PX
	var capacity: int = max(int((capacity_height + _line_spacing) / _pitch), 1)
	var lines := _wrapped_line_count(text, FEED_TEXT_WIDTH)
	if lines > capacity:
		_fail("FEED", loc, text, "%d wrapped lines > %d-line max-grown feed capacity" % [lines, capacity])


func _check_dialogue_body(loc: String, text: String) -> void:
	if text == "":
		return
	var cap := _dialogue_body_page_line_cap()
	for page: String in _paginate(text):
		_measured_count += 1
		if _has_unsplittable_word(page, DIALOGUE_PANEL_TEXT_WIDTH):
			_fail("DIALOGUE-PANEL/body", loc, page, "contains a single word wider than the %dpx dialogue-panel width" % int(DIALOGUE_PANEL_TEXT_WIDTH))
			continue
		var lines := _wrapped_line_count(page, DIALOGUE_PANEL_TEXT_WIDTH)
		if lines > cap:
			_fail("DIALOGUE-PANEL/body", loc, page, "page is %d wrapped lines > %d-line no-options sanity budget" % [lines, cap])


var _dialogue_body_cap_cache := -1


func _dialogue_body_page_line_cap() -> int:
	if _dialogue_body_cap_cache > 0:
		return _dialogue_body_cap_cache
	const RIBBON_HEIGHT := 42.0
	const STACK_SEPARATION := 6.0
	const CONTENT_MARGINS := 52.0  # 28 top + 24 bottom, dialogue_panel.gd's `_ready()`
	var available := PANEL_SIZE_Y - CONTENT_MARGINS - RIBBON_HEIGHT - STACK_SEPARATION
	_dialogue_body_cap_cache = max(int((available + _line_spacing) / _pitch), 1)
	return _dialogue_body_cap_cache


func _check_dialogue_option(loc: String, opt: Dictionary, index: int) -> void:
	var opt_text := String(opt.get("text", ""))
	if opt_text == "":
		return
	var rendered := "> %d. %s" % [index + 1, opt_text]
	var suffix := _mirrored_requirement_suffix(opt_text, opt.get("requires", {}))
	if suffix != "":
		rendered += suffix
	_measured_count += 1
	var width := _single_line_width(rendered)
	if width > DIALOGUE_PANEL_TEXT_WIDTH:
		_fail("DIALOGUE-PANEL/option", loc, rendered, "single-line width %.0fpx > %.0fpx panel width (no autowrap on option rows)" % [width, DIALOGUE_PANEL_TEXT_WIDTH])


func _mirrored_requirement_suffix(option_text: String, requires: Dictionary) -> String:
	if requires.is_empty():
		return ""
	var requirement := ""
	if requires.has("skill"):
		requirement = "requires %s" % String(requires["skill"]).capitalize()
	elif requires.has("class"):
		for id: String in (requires["class"] as Dictionary):
			requirement = "requires %s %d" % [id.capitalize(), int((requires["class"] as Dictionary)[id])]
			break
	elif requires.has("gold"):
		requirement = "costs %d gold" % int(requires["gold"])
	elif requires.has("item"):
		# GH#378 arm 1: the item arm reads the REAL catalog, because the rendered
		# suffix now composes two authored strings -- items.json's `name` and its
		# optional `source_hint` -- and a hint is exactly the kind of copy that
		# quietly runs the row past the panel edge. Option labels carry NO
		# autowrap (dialogue_panel.gd's `_rebuild_options` builds a plain
		# UIChrome.make_label), so an overflow CLIPS rather than folding: an
		# unmeasured hint would silently amputate the very signpost it exists to
		# give. Measured budget at font_size 14: the longest shipped Serve option
		# leaves ~190px for the hint body, roughly 21-24 characters.
		var rec: Dictionary = _item_catalog().get(String(requires["item"]), {})
		var item_label := String(rec.get("name", String(requires["item"]).capitalize()))
		var source_hint := String(rec.get("source_hint", ""))
		requirement = "requires %s" % item_label
		if source_hint != "":
			requirement = "requires %s — %s" % [item_label, source_hint]
	else:
		return ""  # accomplishment/board_accepted/etc -- hide_when-style gates never render a suffix
	var core := requirement.trim_prefix("requires ").trim_prefix("costs ")
	if option_text.contains(core):
		return ""
	return "  (%s)" % requirement


## data/items.json keyed by id, loaded once. Kept lazy rather than folded into
## `_init`'s setup so the suite's existing startup order is untouched.
var _items_by_id: Dictionary = {}
var _items_loaded := false


func _item_catalog() -> Dictionary:
	if not _items_loaded:
		_items_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
		if parsed is Dictionary:
			for rec: Variant in (parsed as Dictionary).get("items", []):
				if rec is Dictionary:
					_items_by_id[String((rec as Dictionary).get("id", ""))] = rec
	return _items_by_id


func _paginate(text: String) -> Array[String]:
	var pages: Array[String] = []
	var cur := ""
	for word: String in text.split(" ", false):
		var candidate := word if cur == "" else cur + " " + word
		if candidate.length() > PAGE_CHAR_BUDGET and cur != "":
			var cut := _sentence_boundary_cut(cur)
			if cut != -1:
				var remainder := cur.substr(cut + 1).strip_edges()
				pages.append(cur.substr(0, cut + 1))
				cur = ("%s %s" % [remainder, word]) if remainder != "" else word
			else:
				pages.append(cur + "…")
				cur = "…" + word
		else:
			cur = candidate
	if cur != "":
		pages.append(cur)
	if pages.is_empty():
		pages.append("")
	return pages


func _sentence_boundary_cut(cur: String) -> int:
	var window_start := int(PAGE_CHAR_BUDGET * (1.0 - SENTENCE_BOUNDARY_WINDOW_FRACTION))
	var best := -1
	for i in cur.length():
		var c := cur[i]
		if (c == "." or c == "!" or c == "?") and i >= window_start:
			best = i
	return best


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
