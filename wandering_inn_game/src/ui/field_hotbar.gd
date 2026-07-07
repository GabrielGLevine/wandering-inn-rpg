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
##
## M-LEGIBILITY L3: a small readout panel lists every rendered slot's
## cost/effect summary -- v1's direct-fire design has no aim/selection step
## (unlike combat's single highlighted-slot info line), so ALL known field
## skills get one stacked row each rather than one line for "the current
## slot". Each row is `_readout_line`'s "Name — <L1 effect line> —
## description" (WIEffectText.skill_effect_lines, never hand-composed -- same
## formatter combat_hud.gd's slot-info line and journal.gd's revealed-skill
## row now use). Every currently-shipped field skill is exploration-only (no
## `effect` key), so `skill_effect_lines` returns `[]` for all of them today
## and every row degrades to "Name — description" -- the readout is still
## real infrastructure (a future field skill with a combat-shaped effect, or
## a status a field skill applies, sizes onto this seam with zero code
## changes here). No `_bb_escape` needed: `_readout_label` is a plain Label
## (same reasoning as the slot text-fallback above -- bracketed names render
## as literal text, not BBCode). UI_FIELD_HOTBAR_RENDERED's payload carries
## `readout_lines` (parallel to the rendered slots, in the same key order,
## the FULL untrimmed generated text) so QA can assert the exact generated
## content structurally, no OCR -- independent of whatever the panel visually
## fits.
##
## PLACEMENT (windowed-verified): anchored BOTTOM_LEFT, stacked directly
## above message_layer.gd's hint strip (y[-36,-8]) rather than centered above
## the hotbar -- a first pass centered above the bar (like combat's readout)
## put its right edge inside the toast panel's BOTTOM_RIGHT corner
## (TOAST_OFFSETS_DEFAULT x[width-472,width-24]) at 3 slots, a real overlap
## caught by this task's own windowed screenshot. BOTTOM_LEFT at this width
## (528px right edge) stays clear of that corner regardless of toast state
## (default or raised-for-dialogue) and of the dialogue panel (y[-220,-164])
## at every viewport width this repo assumes (1280 reference, same as every
## other hardcoded panel geometry).
##
## OVERFLOW: budgeted in WRAPPED lines exactly like `combat_hud.gd`'s feed
## panel (D2-7 #6: cut words, never widen the UI) -- `_wrapped_line_count`/
## `_line_capacity`/`_fit_to_lines` are the same font-metric-driven helpers,
## duplicated per-file by the same M6.5 zero-cross-dependency idiom (see
## `_bb_escape`'s doc comments elsewhere). Rows that don't fit the panel's
## real capacity are cut (words trimmed, "…" appended) or dropped entirely
## rather than spilling past the parchment -- the pre-fix behavior verified
## empirically at 3 slots (the 3rd row's wrapped 2nd line rendered BELOW the
## panel's opaque art).
const HOTBAR_SCRIPT := preload("res://src/ui/hotbar.gd")
# Sized wide (652) so every currently-shipped field skill's readout row fits
# on ONE wrapped line at "Small" (font_size 12) metrics -- measured directly
# (godot --script, font.get_multiline_string_size): the longest row
# ([Observe]'s) needs 620px to avoid a 2-line wrap; a first pass at 488px
# wrapped it to 2 lines and the wrapped 2nd line rendered outside the
# parchment's visible art (caught windowed, see the file doc comment's
# OVERFLOW note) even though the raw font-metric capacity math said it
# should fit -- the STRIP art's real safe text band is smaller than its
# nominal Control rect. Widening to avoid the wrap in the first place sidesteps
# that art-bbox uncertainty entirely, with `_fit_readout`'s cut-based budget
# as the fallback for any future longer description.
const READOUT_SIZE := Vector2(652.0, 110.0)
const READOUT_TEXT_WIDTH := 620.0
# K2 fix wave: RETUNED 90 -> 70. [Sneak]'s row is the first shipped field-skill
# readout row with a real effect segment (an active-cast Skill, not a plain
# flavor description) -- at 90 the nominal font-metric capacity (4 wrapped
# lines: 90px + 3px line_spacing over a 20px line pitch) exactly matched the
# 3-fixture-skill readout's total wrapped-line usage (1 + 2 + 1 = 4), so
# `_fit_readout` never engaged its cut/drop fallback at all -- it judged
# everything "fit" and rendered all 3 rows verbatim. A windowed
# `stealth_loop` screenshot (qa_output/stealth_loop/00_pre_sneak.png) caught
# the real result: the 3rd row ([Observe]) rendered with its text struck
# through the parchment's decorative bottom border/fold, genuinely illegible
# there -- a pixel scan of that screenshot found the STRIP art's actual
# legible cream band ends around y-offset ~77px into the 110px panel, not 90.
# 70 yields a 3-wrapped-line capacity (int((70+3)/20) == 3), comfortably under
# the measured ~77px edge; re-verified windowed with the same fixture: rows 1
# ([Basic Cleaning], 1 line) + 2 ([Sneak], 2 lines) now consume the full
# budget and row 3 ([Observe]) is dropped by `_fit_readout`'s existing
# budget-exhausted path (no partial word-cut needed, remaining reaches 0
# exactly) -- the two VISIBLE rows sit entirely inside the safe band, no
# fold bleed. `readout_lines` in `UI_FIELD_HOTBAR_RENDERED`'s payload is
# UNCHANGED (always the full untrimmed set) so no QA structural assertion
# is affected -- this only changes what's drawn on screen.
const READOUT_TEXT_HEIGHT := 70.0

var _hotbar: WIHotbar
var _readout_panel: Control
## True while a modal panel (dialogue/journal/inventory/pause) is open -- the
## readout hides for the modal's lifetime (L5 fix wave; see _on_domain_event).
var _modal_open := false
var _readout_label: Label
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
	# M-LEGIBILITY L3 readout: BOTTOM_LEFT, stacked above the hint strip --
	# see the file doc comment's PLACEMENT note for why this replaced an
	# initial centered-above-the-hotbar placement (toast-corner overlap at
	# 3 slots, caught windowed).
	_readout_panel = UIChrome.make_texture_panel(UIChrome.PARCHMENT_STRIP)
	_readout_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_readout_panel.custom_minimum_size = READOUT_SIZE
	_readout_panel.size = READOUT_SIZE
	UIChrome.set_offsets(_readout_panel, 8.0, -40.0 - READOUT_SIZE.y, 8.0 + READOUT_SIZE.x, -40.0)
	_readout_panel.hide()
	var readout_margin := MarginContainer.new()
	UIChrome.full_rect(readout_margin)
	UIChrome.add_margins(readout_margin, 16, 6, 16, 6)
	_readout_panel.add_child(readout_margin)
	_readout_label = UIChrome.make_label("", "Small")
	_readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout_margin.add_child(_readout_label)
	root.add_child(_readout_panel)
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
		# M-LEGIBILITY L5 fix wave: the readout panel (BOTTOM_LEFT) overlaps the
		# grown dialogue stall panel (L2) and the journal/inventory parchment --
		# caught by L5's windowed shop shot, where it hid three of Krshia's buy
		# options. While ANY modal panel is open the number keys are inert
		# (world.gd's _movement_gated), so the readout is dead info anyway: hide
		# it for the modal's lifetime. The slot bar itself stays (small, bottom-
		# center, never collided).
		WIEvents.UI_DIALOGUE_SHOWN, WIEvents.UI_JOURNAL_SHOWN, WIEvents.UI_INVENTORY_SHOWN, WIEvents.UI_PAUSE_SHOWN:
			_modal_open = true
			_readout_panel.hide()
		WIEvents.UI_DIALOGUE_HIDDEN, WIEvents.UI_JOURNAL_HIDDEN, WIEvents.UI_INVENTORY_HIDDEN, WIEvents.UI_PAUSE_HIDDEN:
			_modal_open = false
			_readout_panel.visible = not _field_skills.is_empty()


## Rebuilds the bar from the PC's current known field-tagged skills and hands the
## slot list to WIHotbar. `-1` selected index == the direct-fire resting state
## (no slot highlighted). Emits UI_FIELD_HOTBAR_RENDERED after actually
## rendering, per the bus's "UI confirms it drew something" convention.
## M-LEGIBILITY L3: also rebuilds the readout panel (see the file doc comment)
## from the SAME `_field_skills` list this method just built, so the readout
## can never list a skill the rendered slots don't also show.
func _render() -> void:
	_field_skills = _collect_field_skills()
	var slots: Array = []
	var readout_lines: Array = []
	var number := 1
	# M-LEGIBILITY L5 fix wave, Item 2: load the combatants catalog ONCE
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
	_hotbar.render(slots, -1)
	_readout_label.text = "\n".join(_fit_readout(readout_lines))
	_readout_panel.visible = not readout_lines.is_empty() and not _modal_open
	# `readout_lines` here is the FULL, untrimmed generated text -- the payload
	# is the structural QA-assertable proof, independent of the visual budget
	# `_fit_readout` applies to the drawn label.
	ObservableBus.emit_domain_event(WIEvents.UI_FIELD_HOTBAR_RENDERED, {"slots": _field_skills.size(), "readout_lines": readout_lines})


## The cost/effect summary row for one field skill (M-LEGIBILITY L3): "Name —
## <L1 effect line, if any> — description". `WIEffectText.skill_effect_lines`
## is the ONLY source of the mechanical segment (never hand-composed); every
## currently-shipped field skill is exploration-only (no `effect` key), so it
## returns `[]` and this degrades to "Name — description" (the item-card
## idiom: no effect line, no dangling dash).
func _readout_line(sk: Dictionary, id: String, combatants_catalog: Array = []) -> String:
	var display := String(sk.get("display_name", id))
	var desc := String(sk.get("description", ""))
	var effect_lines := WIEffectText.skill_effect_lines(sk, combatants_catalog)
	if effect_lines.is_empty():
		return "%s — %s" % [display, desc] if desc != "" else display
	# M-LEGIBILITY L5 fix wave, Item 4: guard the trailing-dash case (desc
	# empty but effect_lines non-empty) the same way the branch above already
	# does -- unreachable today (every shipped description is non-empty) but
	# a future skill with no description shouldn't render "Name — effect — ".
	if desc == "":
		return "%s — %s" % [display, effect_lines[0]]
	return "%s — %s — %s" % [display, effect_lines[0], desc]


## M-LEGIBILITY L5 fix wave, Item 2: the combatants catalog (the array under
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


## Budgets `lines` (the full, untrimmed per-slot readout rows) into the
## panel's real WRAPPED-line capacity (D2-7 #6: cut words, never widen the
## UI) -- a row that doesn't fit is word-cut with an ellipsis (`_fit_to_lines`)
## down to whatever budget remains; once the budget is exhausted, remaining
## rows are simply dropped rather than spilling past the parchment (verified
## empirically at 3 slots pre-fix: the 3rd row's wrapped 2nd line rendered
## outside the panel art). Returns the RENDERED (possibly cut/dropped) line
## list; `readout_lines` in the emitted event always stays the full text.
func _fit_readout(lines: Array) -> Array:
	var capacity := _line_capacity(_readout_label, READOUT_TEXT_HEIGHT)
	var out: Array = []
	var used := 0
	for line: String in lines:
		var remaining := capacity - used
		if remaining <= 0:
			break
		var fitted := _fit_to_lines(_readout_label, String(line), READOUT_TEXT_WIDTH, remaining)
		out.append(fitted)
		used += _wrapped_line_count(_readout_label, fitted, READOUT_TEXT_WIDTH)
	return out


## Duplicated from `combat_hud.gd`'s `_wrapped_line_count` (M6.5
## zero-cross-dependency idiom: tiny pure helpers stay per-file rather than
## sharing a home). Wrapped-line count for `text` at `width` using `label`'s
## resolved theme font/size.
func _wrapped_line_count(label: Label, text: String, width: float) -> int:
	if text == "":
		return 0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	return max(int(round(size.y / line_height)), 1)


## Duplicated from `combat_hud.gd`'s `_line_capacity`. How many wrapped lines
## `label` actually fits at `height`, from real font metrics.
func _line_capacity(label: Label, height: float) -> int:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	var line_spacing := float(label.get_theme_constant("line_spacing"))
	var pitch := line_height + line_spacing
	return max(int((height + line_spacing) / pitch), 1)


## Duplicated from `combat_hud.gd`'s `_fit_to_lines`. Cuts whole words and
## appends an ellipsis until `text` fits within `max_lines` wrapped lines at
## `width`. Returns `text` unchanged if it already fits.
func _fit_to_lines(label: Label, text: String, width: float, max_lines: int) -> String:
	if _wrapped_line_count(label, text, width) <= max_lines:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var candidate := " ".join(words) + "…"
		if _wrapped_line_count(label, candidate, width) <= max_lines:
			return candidate
	return (words[0] + "…") if words.size() > 0 else text


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
