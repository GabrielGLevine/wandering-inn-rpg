extends CanvasLayer
## Quest journal — lists started-quest progress via `Game.sim.quest_summary()`
## and (UI wave item 19) known [Skills] grouped by class via
## `Game.sim.skills_journal()` (UI stays out of sim internals — WIGame builds
## the strings/structure, this renders them). Toggled by the `journal` action.
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): journal only toggles/consumes input when
## combat is inactive, no dialogue is open, and BOTH the pause menu and the
## inventory (M7 E4) are closed — world.gd wires `pause_menu_ref`/
## `inventory_ref` after creating all three components so this check does
## not need a scene-tree lookup; world.gd itself checks `journal.open` before
## handling movement/interact.
##
## Layout fix (VISUAL-LOG "UI — Journal layout issues", UI wave item 11):
## `WIWorldLabels` (world-space entity name labels, its own CanvasLayer) is
## created lazily by `world.gd` during `Main._spawn_world()`, which runs
## AFTER `Main._spawn_ui_layers()` adds this journal — so with both
## CanvasLayers left at the default `layer` (1), WorldLabels' add-order win
## painted entity names (e.g. "You", an NPC's nameplate) OVER the journal's
## opaque parchment, bleeding through the title ribbon (confirmed in the
## pre-fix screenshot). `layer = 10` below wins on the explicit CanvasLayer
## stacking rule regardless of add order.

const PANEL_SIZE := Vector2(640.0, 560.0)

## True while the journal panel is visible; world.gd and pause_menu.gd gate on this.
var open := false

## Set by world.gd right after both components are instantiated.
var pause_menu_ref: Node = null
## Set by world.gd/main.gd alongside pause_menu_ref (M7 E4 three-way
## mutual exclusion -- see inventory.gd's file doc comment).
var inventory_ref: Node = null

var _root: Control
var _title_label: Label
var _body_label: RichTextLabel
## CF-review affordance: a "▼" cue shown at the panel foot only when the body
## has more content below the fold (4-quest+ states can overflow the fixed
## 560px panel). The RichTextLabel already scroll_active-scrolls, but silently
## — this arrow signals there's more, and up/down scroll it into view.
var _scroll_hint: Label


func _ready() -> void:
	# See the file doc comment: must outrank WIWorldLabels regardless of
	# scene-tree add order.
	layer = 10
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	add_child(_root)

	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var content := MarginContainer.new()
	UIChrome.full_rect(content)
	UIChrome.add_margins(content, 34, 36, 34, 34)
	_root.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	content.add_child(stack)

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(220.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_title_label = UIChrome.make_label("", "Header")
	_title_label.text = "Journal"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_title_label)
	ribbon.add_child(_title_label)

	# RichTextLabel (not UIChrome.make_rich_label, which is tuned for the
	# tiny fit-content combat readout): BBCode bolds the "Quests"/"Skills"/
	# per-class headings, and it scroll_active-scrolls internally as a safety
	# net if a future many-classes state ever overflows the panel, rather
	# than clipping or forcing the whole modal to grow unboundedly.
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.scroll_active = true
	_body_label.fit_content = false
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_body_label)

	# Bottom-foot "more below" cue, over the parchment (added after content so
	# it draws on top). Hidden until _update_scroll_hint proves overflow.
	_scroll_hint = UIChrome.make_label("▼")
	_scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	_scroll_hint.hide()
	_root.add_child(_scroll_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if not open and not _can_open():
			return
		if open:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
		return
	# While open, up/down scroll the body (world movement is already gated on
	# `open`, so these keys are free to claim here) and re-evaluate the cue.
	if open and event.is_action_pressed("move_down"):
		_scroll_body(1)
		get_viewport().set_input_as_handled()
	elif open and event.is_action_pressed("move_up"):
		_scroll_body(-1)
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	if Game.sim.combat != null or Game.sim.dialogue != null:
		return false
	if not Game.sim.pending_consolidation.is_empty():
		return false
	if pause_menu_ref != null and bool(pause_menu_ref.get("open")):
		return false
	if inventory_ref != null and bool(inventory_ref.get("open")):
		return false
	return true


func _open() -> void:
	open = true
	var act: Dictionary = Game.sim.act_summary()
	var quest_lines: Array = Game.sim.quest_summary()
	var skill_groups: Array = Game.sim.skills_journal()
	_body_label.text = _build_body_text(act, quest_lines, skill_groups)
	_root.show()
	# The RichTextLabel's scrollbar geometry is only valid after a layout pass,
	# so evaluate the overflow cue on the next idle frame (reset scroll to top
	# first so a re-open always starts at the top with the cue if there's more).
	var vbar := _body_label.get_v_scroll_bar()
	if vbar != null:
		vbar.value = 0.0
	_update_scroll_hint.call_deferred()
	var headings: Array = []
	var revealed_skills: Array = []
	var skill_count := 0
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		headings.append(String(group["heading"]))
		for raw_skill: Variant in (group["skills"] as Array):
			var skill := raw_skill as Dictionary
			skill_count += 1
			if bool(skill["revealed"]):
				revealed_skills.append(String(skill["id"]))
	# Payload extended for the UI wave (item 19): QA can assert the panel
	# actually rendered the grouped-by-class structure and the first-use
	## reveal state, not just that the (opaque, empty) event fired.
	# M-ARC Task A1 extends it again with the act-line data (current act id +
	# achieved-beat count) so arc_flow/journal QA can gate act progression.
	var act_beats: Array = act.get("beats", [])
	var act_beats_achieved := 0
	for raw_beat: Variant in act_beats:
		if bool((raw_beat as Dictionary).get("achieved", false)):
			act_beats_achieved += 1
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_SHOWN, {
		"quest_lines": quest_lines.size(),
		"skill_groups": headings,
		"skill_count": skill_count,
		"revealed_skills": revealed_skills,
		"act_id": String(act.get("id", "")),
		"act_beats": act_beats.size(),
		"act_beats_achieved": act_beats_achieved,
	})


func _close() -> void:
	open = false
	_root.hide()
	if _scroll_hint != null:
		_scroll_hint.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_HIDDEN, {})


## Nudges the body scroll by one step and re-tests the "more below" cue.
func _scroll_body(dir: int) -> void:
	var vbar := _body_label.get_v_scroll_bar()
	if vbar == null:
		return
	vbar.value += float(dir) * 48.0
	_update_scroll_hint()


## Shows the "▼" cue only when the body has content scrolled below the fold
## (value can still increase). Safe pre-layout: a zero page/max just hides it.
func _update_scroll_hint() -> void:
	if _scroll_hint == null:
		return
	var vbar := _body_label.get_v_scroll_bar()
	var more_below := vbar != null and vbar.value < (vbar.max_value - vbar.page - 1.0)
	_scroll_hint.visible = open and more_below


## Builds the BBCode body text: a "Quests" section (unchanged content, from
## `quest_summary()`) then a "Skills" section, one sub-heading per
## `skills_journal()` group ("Innate" first, then held classes) listing each
## skill's `text` verbatim (name-only pre-first-use, name + description
## after — the opacity split lives entirely in WIGame.skills_journal/
## _skill_entries; this file only renders the string it's handed).
func _build_body_text(act: Dictionary, quest_lines: Array, skill_groups: Array) -> String:
	var parts: Array = []
	# M-ARC Task A1: the act-line section leads the journal -- the current act
	# header + its milestone beats (results-only copy), achieved beats marked.
	# Absent only if no acts catalog loaded (degrades to Quests-first as before).
	if not act.is_empty():
		parts.append("[b]%s[/b]" % _bb_escape(String(act.get("header", ""))))
		for raw_beat: Variant in act.get("beats", []):
			var beat := raw_beat as Dictionary
			var marker := "✓ " if bool(beat.get("achieved", false)) else "· "
			parts.append("%s%s" % [marker, _bb_escape(String(beat.get("text", "")))])
		parts.append("")
	parts.append("[b]Quests[/b]")
	if quest_lines.is_empty():
		parts.append("No quests yet.")
	else:
		for line: Variant in quest_lines:
			parts.append(_bb_escape(String(line)))
	parts.append("")
	parts.append("[b]Skills[/b]")
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		parts.append("")
		parts.append("[b]%s[/b]" % _bb_escape(String(group["heading"])))
		for raw_skill: Variant in (group["skills"] as Array):
			var skill := raw_skill as Dictionary
			parts.append(_bb_escape(String(skill["text"])))
	return "\n".join(parts)


## Skill display names/descriptions carry literal `[`/`]` (e.g.
## "[Basic Cleaning]") that BBCode would otherwise parse as tags. MUST route
## through placeholder chars: the naive two-line
## `.replace("[", "[lb]").replace("]", "[rb]")` chain is self-colliding —
## the FIRST replace's own output ("[lb]") contains a "]" that the SECOND
## replace then re-matches and mangles too (verified empirically:
## "[Basic Cleaning]" would escape to the corrupted
## "[lb[rb]Basic Cleaning[rb]"). Identical fixed copy in combat_hud.gd /
## targeting_controller.gd (UI wave review closed all three) — tiny pure
## helper, deliberately duplicated per file (M6.5 idiom); keep in sync.
func _bb_escape(s: String) -> String:
	var placeholder_open := char(1)
	var placeholder_close := char(2)
	return s.replace("[", placeholder_open).replace("]", placeholder_close) \
			.replace(placeholder_open, "[lb]").replace(placeholder_close, "[rb]")
