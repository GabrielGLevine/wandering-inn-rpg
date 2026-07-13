extends SceneTree
## Issue #67 (finding 26): systematic copy-fit validator. Walks every
## authored player-facing string (skeleton_scene.json toast/bark fields,
## data/arenas.json tutor_lines, data/skills.json field_ambient/freeze_toast,
## data/dialogue/*.json node/option text) and asserts it fits its target
## panel's REAL wrapped-line/width budget, using the SAME
## `Font.get_multiline_string_size` math the panels themselves use
## (message_layer.gd / combat_hud.gd / dialogue_panel.gd) -- see CLAUDE.md's
## "Message panels budget WRAPPED LINES, not entries" gotcha.
##
## METHOD: exact font, not a char-count proxy. `UIChrome.THEME`'s Label type
## carries no custom .ttf (wi_ui_theme.tres has no `Label/fonts/font`
## override), so `get_theme_font("font")` resolves the engine's built-in
## fallback font -- confirmed loadable under bare `--script` mode, no window
## needed. TRAP found while building this: `get_theme_font_size` on a Label
## added to the tree in the SAME frame `theme = X` was set reports the
## engine default (16), not the theme's real value (14, wi_ui_theme.tres'
## `default_font_size`) -- theme propagation needs one `await process_frame`
## to settle before any metric is trustworthy. Every measurement below runs
## AFTER that settle.
##
## NOT COVERED (deliberate -- every surface below wraps AND grows/scrolls,
## so words are never lost, the failure this suite exists to catch):
## items.json descriptions (inventory lore card: autowrap + ScrollContainer),
## quest beat descriptions + journal section notes (journal body: autowrap +
## scroll), WIEffectText card lines (exact-pinned in test_effect_text.gd,
## rendered into wrapping sub-rows), and runtime-COMPOSED toast strings
## (earn/level toasts built from short templates). If any of those surfaces
## ever gains a fixed-width no-wrap row, add its corpus here.
##
## FIVE budgeted surfaces (mirrored from their real source consts, each with
## a drift-tripwire regex assertion below so a future const edit there fails
## THIS suite loudly instead of silently invalidating the mirrored budget):
##  - AMBIENT-BARK: message_layer.gd's `_dialogue_panel`/`_dialogue_label`
##    (the `dialogue_line` bark, WIEvents.DIALOGUE_LINE) -- the ONE panel
##    that actually LOSES words (`_fit_dialogue_line`, ellipsis-truncates at
##    DIALOGUE_LINE_CAPACITY). Corpus: skeleton_scene.json entity
##    `talk_pool`/`talk_pool_stages[].lines`/`dialogue[].text`.
##  - TOAST: message_layer.gd's `_toast_panel` (WIEvents.TOAST) -- GROWS to
##    fit any wrapped-line count (`_resize_toast_panel`, no hard cap), so it
##    never truncates; the only genuine hard-fail is a single word too wide
##    to wrap at all, plus a screen-bounds check (grown panel's top must not
##    run off-screen in the RAISED, mid-conversation anchor -- the tightest
##    case). Corpus: skeleton_scene.json entity observe/toast/open_toast/
##    locked_toast/sleep_toast/burn_toast/friendly_line/gate_closed_toast/
##    second_visit_toast/skill_hint_toast (found via `grep -n
##    "WIEvents.TOAST" src/core/*.gd`, beyond the issue's own named 5 fields)
##    + data/skills.json's field_ambient/freeze_toast (also found the same
##    way -- field_skills.gd routes both to WIEvents.TOAST).
##  - FEED: combat_hud.gd's `_feed_label` (`feed_push`) -- a single entry
##    longer than the grown-to-MAX panel can hold is ellipsis-truncated
##    (real word loss, same class as the ambient bark). Corpus:
##    data/arenas.json `tutor_lines[].line`/`.fallback_line`.
##  - DIALOGUE-PANEL: dialogue_panel.gd's conversation UI. Body `text`/
##    `text_variants[].text` is PAGINATED (`_paginate`, mirrored below) and
##    the panel auto-GROWS height to fit any page (`_fit_panel_height`, no
##    cap) -- verified empirically (see report) that this already keeps
##    every shipped body text within a small per-page line count, so body
##    text gets a generous per-page sanity budget, not a truncation
##    contract. Corpus also includes skeleton_scene.json entity
##    `board_rumors[].copy` (guild_board's rumor postings) -- `_interact_board`
##    (wi_game.gd) folds these into the SAME code-built dialogue node `text`
##    as the header/bounty-slate/observe footer, routed through the identical
##    paginated body surface; `_check_skeleton_scene` below walks the same
##    entities for TOAST_FIELDS/talk_pool/dialogue but never looked at
##    `board_rumors` -- a validator that never SEES a string passes
##    vacuously (the #65 review's finding, widened here). OPTION text
##    (`_rebuild_options`) is the real hard budget:
##    rendered as a plain `Label` with NO `autowrap_mode` set (confirmed:
##    `UIChrome.make_label()`'s default is autowrap OFF) inside a
##    fixed-WIDTH-only panel (720px, "never widen" -- D2-7 #6, genuinely
##    enforced for width, unlike height) -- an option line that doesn't fit
##    ONE line at the panel's real text width draws PAST the parchment art's
##    edge, a true, currently-reproducible overflow. This is the check that
##    actually flags real corpus lines (see report for measurements).
##  - HELP (issue #107): settings_panel.gd's Help reference sub-page
##    (`_build_help_panel`) -- the Controls sub-page's idiom, a FIXED
##    (HELP_PANEL_SIZE), NON-scrolling panel, so unlike TOAST/DIALOGUE-PANEL
##    there is no auto-grow safety net: a section that wraps past
##    HELP_SECTION_LINE_CAP lines draws past the panel's own fixed bottom
##    edge, a real overflow (the same class DIALOGUE-PANEL/option's
##    "never widen" width check catches, just on the vertical axis, because
##    this panel deliberately has no ScrollContainer -- see settings_panel.gd's
##    `_build_help_panel` doc comment). Corpus: `data/help_content.json`'s
##    `sections[].heading`/`.body`, rendered together as ONE wrapped Label
##    per section (`"%s — %s" % [heading, body]`, settings_panel.gd's
##    `_help_line`).
##
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_copy_fit.gd

const DIALOGUE_DIR := "res://data/dialogue"
const VIEWPORT_HEIGHT := 720.0

## ---- Mirrored budget constants (drift-tripwire checked against the real
## source files in `_check_drift_tripwires`, called first in `_init`) ----

# message_layer.gd
const TOAST_TEXT_WIDTH := 412.0
const TOAST_PANEL_BASE_HEIGHT := 96.0
const TOAST_FOLD_DANGER_PX := 30.0
const TOAST_BOTTOM_RAISED := -264.0
const DIALOGUE_TEXT_WIDTH := 656.0
const DIALOGUE_LINE_CAPACITY := 2

# combat_hud.gd
const FEED_TEXT_WIDTH := 248.0
const FEED_PANEL_MAX_HEIGHT := 220.0
const FEED_CONTENT_MARGIN_TOP := 8.0
const FEED_FOLD_DANGER_PX := 30.0

# dialogue_panel.gd
const PANEL_SIZE_X := 720.0
const PANEL_SIZE_Y := 232.0
const PAGE_CHAR_BUDGET := 200
const SENTENCE_BOUNDARY_WINDOW_FRACTION := 0.2
const DIALOGUE_PANEL_TEXT_WIDTH := PANEL_SIZE_X - 56.0  # `_ready()`'s 28+28 margin

# settings_panel.gd -- issue #107, Help reference sub-page. HELP_PANEL_WIDTH
# mirrors HELP_PANEL_SIZE.x (620.0); HELP_TEXT_WIDTH subtracts `_build_help_
# panel`'s 26+26 MarginContainer margins, same derivation the real const uses.
# HELP_SECTION_LINE_CAP (3) is the sizing pass's measured ceiling (the
# longest section, "The Boards", wraps to exactly 3 lines at this width;
# every other section wraps to 2) -- a future edit growing any body past 3
# lines would draw past HELP_PANEL_SIZE's fixed bottom edge (no ScrollContainer).
const HELP_PANEL_WIDTH := 620.0
const HELP_TEXT_WIDTH := HELP_PANEL_WIDTH - 52.0
const HELP_SECTION_LINE_CAP := 3


## Skeleton entity string fields that route to WIEvents.TOAST (traced via
## `grep -n "WIEvents.TOAST" src/core/*.gd`) -- the issue named the first 5;
## the rest were found the same way and are genuinely part of the same
## render surface, so they're in-scope too. `item_hint_toast`/
## `once_per_waking_toast` (GH#70's archery_butt gate / the #81 review's
## serving_tray wage-scrutiny fix) were the same kind of miss this list
## already exists to close -- added here rather than left to join
## board_rumors as a second invisible-to-this-suite surface.
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


## Regex-extracts `const NAME := VALUE` from the real source files and
## asserts the mirrored constants above still match -- a future edit to any
## of these consts fails THIS suite loudly instead of silently invalidating
## the budgets validated here.
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
	# PANEL_SIZE := Vector2(720.0, 232.0) -- checked as a substring, the
	# Vector2 literal form doesn't fit the simple `NAME := VALUE` regex above.
	var src := FileAccess.get_file_as_string("res://src/ui/dialogue_panel.gd")
	assert(src.contains("Vector2(720.0, 232.0)"), "dialogue_panel.gd's PANEL_SIZE literal drifted from the mirrored PANEL_SIZE_X/Y (720.0, 232.0) -- update this test's mirrored consts")
	# HELP_PANEL_SIZE/HELP_TEXT_WIDTH (issue #107) -- same substring-literal
	# reasoning (a Vector2 const + a derived-expression const, neither fits
	# the simple `NAME := VALUE` scalar regex above).
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


## Builds a themed Label (the SAME "Label" theme type every budgeted panel
## in this project uses -- toast/dialogue-bark/feed all call
## `UIChrome.make_label()` with no `type_variation`) and settles theme
## propagation with one `await process_frame` (see the file doc comment's
## TRAP note) before reading any font metric.
func _setup_font_metrics() -> void:
	var root := Control.new()
	get_root().add_child(root)
	UIChrome.apply_theme(root)
	_label = UIChrome.make_label("x")
	root.add_child(_label)
	await process_frame
	_font = _label.get_theme_font("font")
	_font_size = _label.get_theme_font_size("font_size")
	# Tripwire: if theme propagation ever regresses to the engine default
	# (16), every budget silently widens past the real panels' (over-strict
	# false alarms with no signal why). Pin the settled size.
	assert(_font_size == 14, "theme font_size did not settle to wi_ui_theme's 14 (got %d) -- the one-frame settle regressed" % _font_size)
	_line_spacing = float(_label.get_theme_constant("line_spacing"))
	_pitch = _font.get_height(_font_size) + _line_spacing
	assert(_font != null, "theme font failed to load headless -- exact-font method unavailable (see STOP trigger)")


## Mirrors message_layer.gd/combat_hud.gd's own `_wrapped_line_count`.
func _wrapped_line_count(text: String, width: float) -> int:
	if text == "":
		return 0
	var size := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, _font_size)
	var line_height := _font.get_height(_font_size)
	if line_height <= 0.0:
		return 1
	return max(int(round(size.y / line_height)), 1)


## Single-line (no-wrap) pixel width -- the real metric an `autowrap_mode
## OFF` Label (dialogue_panel.gd's option rows) actually draws at.
func _single_line_width(text: String) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x


## True if any single word in `text` is wider than `width` on its own -- an
## unrecoverable overflow for ANY word-wrapping panel (toast/feed/bark all
## use TextServer word-wrap, which cannot split a word mid-token).
func _has_unsplittable_word(text: String, width: float) -> bool:
	for word: String in text.split(" ", false):
		if _single_line_width(word) > width:
			return true
	return false


var _measured_count := 0


func _fail(surface: String, path: String, text: String, detail: String) -> void:
	_failures.append("[%s] %s: %s (\"%s\")" % [surface, path, detail, text.left(80)])


## ---- AMBIENT-BARK + TOAST corpus: skeleton_scene.json ----

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
					# 8b R1's `{"echo_of": entity_id}` shape (social.gd's
					# `_resolve_pool_line`) resolves to the ECHOED entity's own
					# CURRENT pool line at runtime, never a separate string --
					# that entity's own talk_pool/talk_pool_stages gets walked
					# and checked when THIS loop reaches its own entity record,
					# so skipping the echo marker here loses no coverage.
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


## ---- FEED corpus: data/arenas.json tutor_lines ----

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
				# Issue #88: the requires_ally split's third renderable string
				# (combat_hud.gd's _tutor_line_text) -- same feed budget.
				_check_feed(loc + ".solo_fallback_line", String(entry["solo_fallback_line"]))


## ---- TOAST corpus: data/skills.json field_ambient/freeze_toast ----

func _check_skill_toasts() -> void:
	var data := _load_json("res://data/skills.json")
	for skill: Dictionary in data.get("skills", []):
		var skill_id := String(skill.get("id", "?"))
		var loc := "data/skills.json[skills.%s]" % skill_id
		if skill.has("field_ambient") and String(skill["field_ambient"]) != "":
			_check_toast(loc + ".field_ambient", String(skill["field_ambient"]))
		if skill.has("freeze_toast"):
			_check_toast(loc + ".freeze_toast", String(skill["freeze_toast"]))


## ---- DIALOGUE-PANEL corpus: data/dialogue/*.json ----

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


## ---- DIALOGUE-PANEL corpus, part 2 (issue #72): data/bounties.json /
## data/deliveries.json copy ----
##
## THE REQUEST BOARD / DELIVERY BOARD render their `copy`/`slip_copy`
## strings into the SAME code-built dialogue-panel body surface a static
## data/dialogue/*.json node's `text` renders into (WIBounties.
## build_picker_graph/build_delivery_picker_graph compose the hub node's
## `text` from these fields, paginated via the SAME `_paginate` this file
## already mirrors) -- `_check_dialogue_graphs` above can't see it (these
## graphs are built at runtime from bounties.json/deliveries.json, never
## registered under DIALOGUE_DIR, exactly the reason test_content.gd's own
## cross-reference sweep skips them too, per bounties.gd's doc comment).
## This closes that gap: every `copy`/`slip_copy` string runs through the
## SAME `_check_dialogue_body` budget check a static node's `text` gets.
func _check_bounty_delivery_copy() -> void:
	var bounties := _load_json("res://data/bounties.json")
	for bounty: Dictionary in bounties.get("bounties", []):
		_check_dialogue_body("data/bounties.json[bounties.%s].copy" % String(bounty.get("id", "?")), String(bounty.get("copy", "")))
	var deliveries := _load_json("res://data/deliveries.json")
	for delivery: Dictionary in deliveries.get("deliveries", []):
		_check_dialogue_body("data/deliveries.json[deliveries.%s].slip_copy" % String(delivery.get("id", "?")), String(delivery.get("slip_copy", "")))


## DIALOGUE-PANEL/option corpus, part 2 (issue #72): the picker's OPTION
## rows. `WIBounties.build_picker_graph`/`build_delivery_picker_graph`
## render each slate entry as `"Take: %s. (%d gold)" % [title, gold]` on the
## SAME no-autowrap option Label `_check_dialogue_option` above checks --
## bounties.gd's own doc comment on `build_picker_graph` records a REAL
## windowed-screenshot bug this exact shape caused once (a full copy
## paragraph on an option row ran off the panel edge); this is the
## automated version of the "re-measure windowed if a longer title is ever
## added" warning that comment leaves as a manual TODO. Calls the REAL
## `WIBounties._posting_title`/`_delivery_title` formatters directly
## (static funcs, callable despite the underscore -- GDScript doesn't
## enforce privacy) rather than approximating them, so this is an EXACT
## match to what the picker renders, not a mirror that can drift. The
## slate index digit is always 1 (options 1-4, since `WIBounties.
## active_slate` never exceeds 3 live entries + "Never mind.") regardless
## of a posting's real position in the full pool, so "> 1. " is the correct
## constant-width prefix to check against for every id.
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


## ---- DIALOGUE-PANEL corpus, part 3: skeleton_scene.json board_rumors ----
##
## guild_board's `board_rumors[].copy` strings are NOT a static dialogue/*.json
## node and NOT a bounties.json/deliveries.json row -- `_interact_board`
## (wi_game.gd) joins the board's header + `board_bounties()` copy + every
## `board_rumors[].copy` + the entity's own `observe` into ONE code-built
## dialogue node's `text` (`_begin_code_dialogue`), rendered through the SAME
## paginated dialogue-panel body surface `_check_dialogue_body` already
## validates for bounty/delivery copy above. Mirrors that check's own
## simplification: each rumor's `copy` is measured on its own, not re-joined
## with the header/other rumors/observe text it ships alongside in the real
## render -- `_check_skeleton_scene` above walks these same entities but only
## looks at TOAST_FIELDS/talk_pool/dialogue, so `board_rumors` was invisible
## to every corpus walk until this pass (a validator that never SEES a
## string passes vacuously -- the #65 review's finding, widened here).
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


## ---- HELP corpus: data/help_content.json (issue #107) ----
##
## Mirrors `settings_panel.gd`'s `_help_line` EXACTLY (`"%s — %s" % [heading,
## body]`) so this measures the same string the panel actually renders, one
## Label per section, HELP_TEXT_WIDTH wide -- see the HELP budgeted-surface
## doc comment above for why this is a hard line-cap check (no ScrollContainer,
## no auto-grow) rather than TOAST/DIALOGUE-PANEL's generous-cap treatment.
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


## ---- Per-surface checks ----

## AMBIENT-BARK: message_layer.gd's `_fit_dialogue_line` hard-truncates
## (ellipsis) at DIALOGUE_LINE_CAPACITY wrapped lines -- a string that would
## need MORE lines than that loses real words at render time.
func _check_ambient_bark(loc: String, text: String) -> void:
	_measured_count += 1
	if _has_unsplittable_word(text, DIALOGUE_TEXT_WIDTH):
		_fail("AMBIENT-BARK", loc, text, "contains a single word wider than the %dpx bark width" % int(DIALOGUE_TEXT_WIDTH))
		return
	var lines := _wrapped_line_count(text, DIALOGUE_TEXT_WIDTH)
	if lines > DIALOGUE_LINE_CAPACITY:
		_fail("AMBIENT-BARK", loc, text, "%d wrapped lines > %d-line ellipsis-truncate budget" % [lines, DIALOGUE_LINE_CAPACITY])


## TOAST: `_toast_panel` grows to fit ANY wrapped-line count (no hard
## truncation cap) -- the two genuine hard-fails are (1) a single word wider
## than the box (can never wrap, clips regardless of panel height) and (2)
## the grown panel's computed height pushing its TOP off-screen in the
## RAISED anchor (TOAST_BOTTOM_RAISED, the tightest of the two toast
## positions -- mirrors `_toast_panel_height_for`'s formula).
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


## FEED: `feed_push` ellipsis-truncates a single entry that doesn't fit the
## panel GROWN TO ITS MAX (FEED_PANEL_MAX_HEIGHT) -- a real word-loss risk
## for a long tutor beat, same class as the ambient bark.
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


## DIALOGUE-PANEL body text: mirrors `_paginate` (word-boundary split at
## PAGE_CHAR_BUDGET chars, preferring a sentence-ending cut near the budget
## edge -- see dialogue_panel.gd's own doc comments), then checks each PAGE
## against a generous per-page sanity cap: the max wrapped-line count that
## fits PANEL_SIZE_Y with ZERO options showing (the most headroom the panel
## ever has for body text alone) -- computed once, lazily, from real theme
## metrics, not guessed.
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


## Empirically derives the per-page body-text line cap by measuring how many
## lines of `_dialogue_label`-equivalent text fit inside PANEL_SIZE_Y with
## ribbon-only overhead (42px ribbon + the stack's 6px separation + the
## content margin's 28+24=52px -- the SAME numbers dialogue_panel.gd's
## `_ready()`/`_fit_panel_height` use), rather than guessing "2" or "3" from
## the PAGE_CHAR_BUDGET doc comment's prose.
func _dialogue_body_page_line_cap() -> int:
	if _dialogue_body_cap_cache > 0:
		return _dialogue_body_cap_cache
	const RIBBON_HEIGHT := 42.0
	const STACK_SEPARATION := 6.0
	const CONTENT_MARGINS := 52.0  # 28 top + 24 bottom, dialogue_panel.gd's `_ready()`
	var available := PANEL_SIZE_Y - CONTENT_MARGINS - RIBBON_HEIGHT - STACK_SEPARATION
	_dialogue_body_cap_cache = max(int((available + _line_spacing) / _pitch), 1)
	return _dialogue_body_cap_cache


## DIALOGUE-PANEL option text: `_rebuild_options` renders each option as
## `"%s%d. %s%s" % [mark, i+1, opt_text, suffix]` on a PLAIN Label with NO
## autowrap (`UIChrome.make_label()`'s default) inside the panel's genuinely
## fixed 720px width -- this is the real "never widen" contract. `mark` is
## "> " or "  " (both 2 chars, same width) and `suffix` only renders when
## the option is LOCKED (`requires` unmet) -- mirrors `_requirement_text`/
## `_requirement_suffix`'s dedup logic with an id.capitalize() approximation
## for skill/class/item display names (no `names`/`items` ctx catalog
## available here; close enough for a length/width fit check).
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


## Best-effort mirror of `WIDialogue._requirement_text` + `dialogue_panel.gd`
## `_requirement_suffix`'s dedup -- see `_check_dialogue_option`'s doc
## comment for the id.capitalize() approximation caveat.
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


## Mirrors dialogue_panel.gd's `_paginate` + `_sentence_boundary_cut`
## verbatim (drift-tripwire checked against the real PAGE_CHAR_BUDGET/
## SENTENCE_BOUNDARY_WINDOW_FRACTION consts in `_check_drift_tripwires`).
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
