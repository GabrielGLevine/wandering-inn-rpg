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


const TOAST_FIELDS := [
	"observe", "toast", "open_toast", "locked_toast", "sleep_toast",
	"burn_toast", "friendly_line", "gate_closed_toast", "second_visit_toast",
	"skill_hint_toast", "item_hint_toast", "once_per_waking_toast",
]

var _label: Label
var _font: Font
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
	await process_frame
	_font = _label.get_theme_font("font")
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
					_check_toast(loc + "." + field, String(entity[field]))
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
		requirement = "requires %s" % String(requires["item"]).capitalize()
	else:
		return ""  # accomplishment/board_accepted/etc -- hide_when-style gates never render a suffix
	var core := requirement.trim_prefix("requires ").trim_prefix("costs ")
	if option_text.contains(core):
		return ""
	return "  (%s)" % requirement


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
