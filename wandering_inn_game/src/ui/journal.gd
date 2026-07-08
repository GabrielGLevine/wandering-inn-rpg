extends CanvasLayer
## Quest journal — lists started-quest progress via `Game.sim.quest_summary()`
## and known [Skills] grouped by class via `Game.sim.skills_journal()` (UI
## stays out of sim internals — WIGame builds the strings/structure, this
## renders them). Toggled by the `journal` action.
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): journal only toggles/consumes input when
## combat is inactive, no dialogue is open, and BOTH the pause menu and the
## inventory are closed — world.gd wires `pause_menu_ref`/`inventory_ref`
## after creating all three components so this check does not need a
## scene-tree lookup; world.gd itself checks `journal.open` before handling
## movement/interact.
##
## `WIWorldLabels` (world-space entity name labels, its own CanvasLayer) is
## created lazily by `world.gd` during `Main._spawn_world()`, which runs
## AFTER `Main._spawn_ui_layers()` adds this journal — so with both
## CanvasLayers left at the default `layer` (1), WorldLabels' add-order win
## painted entity names (e.g. "You", an NPC's nameplate) OVER the journal's
## opaque parchment, bleeding through the title ribbon. `layer = 10` below
## wins on the explicit CanvasLayer stacking rule regardless of add order.

const PANEL_SIZE := Vector2(640.0, 560.0)

## True while the journal panel is visible; world.gd and pause_menu.gd gate on this.
var open := false

## Set by world.gd right after both components are instantiated.
var pause_menu_ref: Node = null
## Set by world.gd/main.gd alongside pause_menu_ref (three-way mutual
## exclusion -- see inventory.gd's file doc comment).
var inventory_ref: Node = null

var _root: Control
var _title_label: Label
var _body_label: RichTextLabel
## A "▼" cue shown at the panel foot only when the body has more content
## below the fold (4-quest+ states can overflow the fixed 560px panel). The
## RichTextLabel already scroll_active-scrolls, but silently — this arrow
## signals there's more, and the cursor auto-scrolls it into view.
var _scroll_hint: Label

## The assignment surface. `_flat_skill_ids` is every known skill id in the
## SAME order `_build_body_text` renders its rows (Innate group first, then
## one entry per held class in catalog order, mirroring `skills_journal()`'s
## own grouping) -- rebuilt once per `_open()` (the group/skill SET can't
## change while the journal is open: movement/interact/sleep are all gated
## shut by `_can_open`'s modal-exclusivity check, so nothing can grant/level
## a class mid-session). `_cursor_index` indexes into it (-1 when the PC
## knows zero skills, an edge case not reachable in shipped content but
## guarded anyway). Up/Down move the cursor (repurposed from the old
## manual-scroll idiom -- nothing QA-asserts the pre-existing scroll
## behavior); Enter toggles the cursored skill on/off the shared
## `hotbar_loadout`.
var _flat_skill_ids: Array[String] = []
var _cursor_index := -1
## Cached at `_open()` so a later toggle/cursor-move rebuilds the body from
## the SAME inputs without re-querying Game.sim (none of these change while
## the journal is open -- see `_flat_skill_ids`' doc comment above).
var _open_act: Dictionary = {}
var _open_quest_lines: Array = []
var _open_skill_groups: Array = []
var _open_seen_statuses: Array = []
var _open_combatants_catalog: Array = []


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

	ObservableBus.domain_event.connect(_on_domain_event)


## Rebuild the open panel's body on a device swap so the skills-section
## toggle hint (composed through WIInputHints in `_build_body_text`) can't
## go stale while the journal is open. `_rebuild_body_follow_cursor`
## re-renders from the cached `_open_*` state (same call the loadout toggle
## uses), so no fresh sim queries happen. No-op while closed (the next
## `_open()` composes fresh anyway). QA-invisible: the harness only injects
## keys, so the device never changes during a canonical run.
func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.INPUT_DEVICE_CHANGED and open:
		_rebuild_body_follow_cursor()


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
	# While open, Up/Down move the skill-row cursor (world movement is
	# already gated on `open`, so these keys are free to claim here) and
	# Enter toggles the cursored skill on/off the shared hotbar loadout.
	if open and event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif open and event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif open and event.is_action_pressed("confirm"):
		_toggle_cursor_skill()
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
	## Every status id the player has ever watched apply (Game.sim.
	## seen_statuses -- any combatant's application counts, not just the
	## PC's). Duplicated so `_build_body_text` never holds a live reference
	## into the sim.
	var seen_statuses: Array = Game.sim.seen_statuses.duplicate()
	# Load the combatants catalog ONCE per journal open -- each
	# spell_damage skill's `skill_effect_lines` call otherwise triggers its
	# own uncached FileAccess+JSON.parse of combatants.json
	# (WIEffectText._load_combatants), one per revealed spell per render.
	# Threaded through both call sites that need it below: the render loop
	# (`_build_body_text` -> `_revealed_skill_line`) and the event-payload
	# loop further down, via the formatter's existing `combatants_catalog`
	# override param.
	var combatants_catalog := _load_combatants_catalog()
	# Cache this open's inputs so a later cursor move or assign/unassign
	# toggle can rebuild the body without re-querying Game.sim (see these
	# fields' own doc comment -- nothing can change the known-skill set
	# while the journal is open).
	_open_act = act
	_open_quest_lines = quest_lines
	_open_skill_groups = skill_groups
	_open_seen_statuses = seen_statuses
	_open_combatants_catalog = combatants_catalog
	_flat_skill_ids = _flatten_skill_ids(skill_groups)
	_cursor_index = 0 if not _flat_skill_ids.is_empty() else -1
	var built := _build_body_text(act, quest_lines, skill_groups, seen_statuses, combatants_catalog, _cursor_index)
	_body_label.text = String(built["text"])
	_root.show()
	# The RichTextLabel's scrollbar geometry is only valid after a layout pass,
	# so evaluate the overflow cue on the next idle frame (reset scroll to top
	# first so a re-open always starts at the top with the cue if there's more
	# -- the journal opens showing the TOP of the panel, not jumping straight
	# to the cursor's first-skill-row position).
	var vbar := _body_label.get_v_scroll_bar()
	if vbar != null:
		vbar.value = 0.0
	_update_scroll_hint.call_deferred()
	var headings: Array = []
	var revealed_skills: Array = []
	## Parallel to `revealed_skills` (same index order) -- each entry is that
	## skill's `WIEffectText.skill_effect_lines` output (0 or 1 strings), so
	## QA can assert the mechanical content STRUCTURALLY (the exact
	## generated line) rather than by screenshot/OCR. An exploration-only
	## revealed skill (e.g. basic_cleaning) carries `[]` here -- no formatter
	## phrase, same as its card showing no effect row below.
	var revealed_effect_lines: Array = []
	var skill_count := 0
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		headings.append(String(group["heading"]))
		for raw_skill: Variant in (group["skills"] as Array):
			var skill := raw_skill as Dictionary
			skill_count += 1
			if bool(skill["revealed"]):
				var skill_id := String(skill["id"])
				revealed_skills.append(skill_id)
				revealed_effect_lines.append(WIEffectText.skill_effect_lines(Game.sim.skills.get(skill_id, {}), combatants_catalog))
	# QA can assert the panel actually rendered the grouped-by-class
	# structure and the first-use reveal state, not just that the (opaque,
	# empty) event fired. Also carries the act-line data (current act id +
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
		"revealed_effect_lines": revealed_effect_lines,
		"act_id": String(act.get("id", "")),
		"act_beats": act_beats.size(),
		"act_beats_achieved": act_beats_achieved,
		"seen_statuses": seen_statuses,
	})


func _close() -> void:
	open = false
	_root.hide()
	if _scroll_hint != null:
		_scroll_hint.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_HIDDEN, {})


## Every known skill id, in the SAME order `_build_body_text` renders its
## rows (Innate group first, then one group per held class in catalog
## order) -- see `_flat_skill_ids`' own doc comment.
func _flatten_skill_ids(skill_groups: Array) -> Array[String]:
	var out: Array[String] = []
	for raw_group: Variant in skill_groups:
		for raw_skill: Variant in (raw_group as Dictionary)["skills"]:
			out.append(String((raw_skill as Dictionary)["id"]))
	return out


## Moves the cursor by `delta` rows, clamped to the flattened list's bounds
## (no wrap), then rebuilds the body so the new cursor row highlights and
## scrolls into view. A no-op when the PC knows zero skills.
func _move_cursor(delta: int) -> void:
	if _flat_skill_ids.is_empty():
		return
	_cursor_index = clampi(_cursor_index + delta, 0, _flat_skill_ids.size() - 1)
	_rebuild_body_follow_cursor()


## Toggles the cursored skill on/off the shared `hotbar_loadout` via
## `Game.sim.loadout_toggle` (the sim mutation + LOADOUT_CHANGED emit, which
## re-renders both bars through their own existing render triggers), then
## rebuilds THIS panel's body (the ✓/blank marker) and emits
## UI_JOURNAL_LOADOUT_RENDERED so QA can assert the live in-panel update.
func _toggle_cursor_skill() -> void:
	if _cursor_index < 0 or _cursor_index >= _flat_skill_ids.size():
		return
	var skill_id := _flat_skill_ids[_cursor_index]
	Game.sim.loadout_toggle(skill_id)
	_rebuild_body_follow_cursor()
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_LOADOUT_RENDERED, {
		"skill": skill_id,
		"assigned": Game.sim.hotbar_loadout.has(skill_id),
		"cursor_index": _cursor_index,
	})


## Rebuilds the body from this open session's cached inputs (see
## `_open_act`/etc.'s doc comment) at the CURRENT cursor position, and scrolls
## the cursor's row into view -- used by both cursor movement and the toggle
## (unlike `_open()`, which deliberately resets to the panel's top instead).
func _rebuild_body_follow_cursor() -> void:
	var built := _build_body_text(_open_act, _open_quest_lines, _open_skill_groups, _open_seen_statuses, _open_combatants_catalog, _cursor_index)
	_body_label.text = String(built["text"])
	var cursor_line := int(built["cursor_line"])
	if cursor_line >= 0:
		# Deferred for the same reason `_open()`'s scroll reset is: the
		# RichTextLabel's line/scroll geometry is only valid after a layout pass.
		_body_label.scroll_to_line.call_deferred(cursor_line)
	_update_scroll_hint.call_deferred()


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
## `skills_journal()` group ("Innate" first, then held classes). Pre-reveal a
## skill row is `text` verbatim (name-only — the opacity/reveal split lives
## entirely in WIGame.skills_journal/_skill_entries). Post-reveal the row is
## built HERE by `_revealed_skill_line` instead of using `text` (which only
## ever carried "Name — description") -- name + the GENERATED effect line +
## description, the same "revealed CONTENT gets mechanical" treatment item
## cards get. Adds a trailing "Effects" section, one line per status id in
## `seen_statuses` (any combatant's application counts -- the player watched
## it happen). OMITTED ENTIRELY when empty (no "None yet" filler) -- a fresh
## game with no status ever seen shows the same journal as before.
## Every skill row leads with a "✓ "/"  " assign marker (reading
## `Game.sim.hotbar_loadout` directly — journal.gd already references
## Game.sim freely, it isn't purity-constrained) and the `cursor_index`'th
## row (in the SAME flattened order `_flatten_skill_ids` produces) is
## wrapped in `[b]...[/b]` with a "▶ " lead glyph. Returns a Dictionary
## `{text: String, cursor_line: int}` instead of a bare String --
## `cursor_line` is the 0-based BBCode line the cursor row landed on (-1 if
## `cursor_index` didn't match any row), so the caller can `scroll_to_line`
## it into view without a second, drift-prone line-counting pass.
func _build_body_text(act: Dictionary, quest_lines: Array, skill_groups: Array, seen_statuses: Array, combatants_catalog: Array = [], cursor_index: int = -1) -> Dictionary:
	var parts: Array = []
	var cursor_line := -1
	# The act-line section leads the journal -- the current act header + its
	# milestone beats (results-only copy), achieved beats marked. Absent
	# only if no acts catalog loaded (degrades to Quests-first as before).
	if not act.is_empty():
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(String(act.get("header", ""))))
		for raw_beat: Variant in act.get("beats", []):
			var beat := raw_beat as Dictionary
			var marker := "✓ " if bool(beat.get("achieved", false)) else "· "
			parts.append("%s%s" % [marker, UIChrome.bb_escape(String(beat.get("text", "")))])
		parts.append("")
	parts.append("[b]Quests[/b]")
	if quest_lines.is_empty():
		parts.append("No quests yet.")
	else:
		for line: Variant in quest_lines:
			parts.append(UIChrome.bb_escape(String(line)))
	parts.append("")
	parts.append("[b]Skills[/b]")
	# The assignment surface's one-line disclosure, matching the established
	# hint-copy grammar (char_creation.gd's "Up/Down to choose  •  Enter to
	# confirm  •  Esc to go back"). Composed through WIInputHints (kb-mode
	# byte-identical to the old literal -- no QA pin exists on this line,
	# but the discipline still applies).
	parts.append("Slotted skills appear on your bars.  •  Up/Down to move  •  %s to toggle" % WIInputHints.label("confirm"))
	var flat_i := 0
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		parts.append("")
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(String(group["heading"])))
		for raw_skill: Variant in (group["skills"] as Array):
			var skill := raw_skill as Dictionary
			var row_text: String
			if bool(skill["revealed"]):
				row_text = _revealed_skill_line(String(skill["id"]), String(skill["display_name"]), combatants_catalog)
			else:
				row_text = String(skill["text"])
			var marker := "✓ " if Game.sim.hotbar_loadout.has(String(skill["id"])) else "  "
			var line := marker + UIChrome.bb_escape(row_text)
			if flat_i == cursor_index:
				cursor_line = parts.size()
				line = "[b]▶ %s[/b]" % line
			parts.append(line)
			flat_i += 1
	if not seen_statuses.is_empty():
		parts.append("")
		parts.append("[b]Effects[/b]")
		for status_id: Variant in seen_statuses:
			parts.append(UIChrome.bb_escape(WIEffectText.status_line(String(status_id), Game.sim.skills.values())))
	return {"text": "\n".join(parts), "cursor_line": cursor_line}


## The post-reveal skill row -- "Name — <effect line> — description", the
## same grammar `combat_hud.gd`'s slot-info line uses (both surfaces share
## the one WIEffectText formatter; never hand-composed). Reads the full
## record straight off `Game.sim.skills` (same direct-dictionary-read idiom
## `field_hotbar.gd` already established) rather than through WIGame.
## skills_journal's `text` field, which only ever carried "Name —
## description". Exploration-only skills (light/frost_touch/kindle/
## basic_cleaning/dangersense) have no mapped effect phrase, so
## `skill_effect_lines` returns `[]` and the row degrades to "Name —
## description" (the item-card idiom: no effect line, no dangling dash) --
## exactly the pre-reveal text, so a skill with no mechanics to disclose
## looks unchanged.
func _revealed_skill_line(id: String, display_name: String, combatants_catalog: Array = []) -> String:
	var record: Dictionary = Game.sim.skills.get(id, {})
	var desc := String(record.get("description", ""))
	var effect_lines := WIEffectText.skill_effect_lines(record, combatants_catalog)
	if effect_lines.is_empty():
		return "%s — %s" % [display_name, desc] if desc != "" else display_name
	# Guard the trailing-dash case (desc empty but effect_lines non-empty)
	# the same way the branch above already does -- unreachable today (every
	# shipped description is non-empty) but a future skill with no
	# description shouldn't render "Name — effect — ".
	if desc == "":
		return "%s — %s" % [display_name, effect_lines[0]]
	return "%s — %s — %s" % [display_name, effect_lines[0], desc]


## The combatants catalog (the array under combatants.json's "combatants"
## key), loaded ONCE per journal open and threaded through every
## `WIEffectText.skill_effect_lines` call site in this file via its
## `combatants_catalog` override param -- mirrors `WIEffectText.
## _load_combatants`'s own FileAccess+JSON.parse idiom (kept as a
## deliberate per-file copy, zero-cross-dependency reasoning; NOTE:
## `_bb_escape` was promoted to `UIChrome.bb_escape` -- this loader is NOT
## part of that promotion). A missing/unparseable file degrades to `[]`,
## which every caller already treats the same as "no override" (falls back
## to the formatter's own default load).
func _load_combatants_catalog() -> Array:
	const COMBATANTS_PATH := "res://data/combatants.json"
	if not FileAccess.file_exists(COMBATANTS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has("combatants"):
		return (parsed as Dictionary)["combatants"]
	return []


## Skill display names/descriptions carry literal `[`/`]` (e.g.
## "[Basic Cleaning]") that BBCode would otherwise parse as tags -- escaped
## via `UIChrome.bb_escape` (promoted off a per-file copy here/combat_hud.gd/
## targeting_controller.gd -- the zero-cross-dependency idiom, amended for
## this one case since this file already references UIChrome for its panel
## chrome, so calling `bb_escape` too adds no new dependency). See
## `UIChrome.bb_escape`'s own doc comment for the self-collision bug the
## placeholder-char technique fixes.
