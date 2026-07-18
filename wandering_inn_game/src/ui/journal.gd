extends CanvasLayer
## `WIWorldLabels` (world-space entity name labels, its own CanvasLayer) is
## created lazily by `world.gd` during `Main._spawn_world()`, which runs
## AFTER `Main._spawn_ui_layers()` adds this journal — so with both
## CanvasLayers left at the default `layer` (1), WorldLabels' add-order win
## painted entity names (e.g. "You", an NPC's nameplate) OVER the journal's
## opaque parchment, bleeding through the title ribbon. `layer = 10` below
## wins on the explicit CanvasLayer stacking rule regardless of add order.

const PANEL_SIZE := Vector2(640.0, 560.0)

## Issue #60 item 1: the Skills section's one-line disclosure that combat
## kit is class+weapon-DERIVED, not player-assigned (there is no loadout
## editor for combat skills -- only field/hotbar assignment, handled by the
## toggle hint right below this one). Threaded into `ui_journal_shown`'s
## payload too (`skills_note` field) so QA can assert the exact copy without
## reading the rendered RichTextLabel.
const COMBAT_KIT_NOTE := "Combat skills follow your classes and weapon."

const _POSTING_TITLES := {
	"bounty_road_cull": "Goblin Cull, Floodplains Road",
	"bounty_settle_dispute": "Settle a Quarrel",
	"bounty_gossip_tea": "Gather Gossip for Krshia",
	"bounty_observe_survey": "District Observation Log",
	"bounty_sewer_survey": "Drainage Gallery Check",
	"bounty_silk_line": "Mark the Silk Line",
	"bounty_inn_hands": "Extra Hands at the Inn",
	"bounty_evening_stew": "Evening Stew Shift",
	"bounty_vermin_grate": "Vermin Under the Grate",
	"bounty_lamp_upkeep": "Keep the Common Room Lit",
	"bounty_tavern_tables": "Wipe the Tables Down",
	"bounty_market_watch": "Watch the Market Stalls",
	"bounty_barracks_checkin": "Check In at the Barracks",
	"bounty_charm_offensive": "A Friendly Word or Three",
	"bounty_bow_practice": "Archery Butt Practice",
	"bounty_guild_census": "Guild Headcount",
	"bounty_alley_cull": "Clear the Boulevard Alleys",
	"bounty_second_watch": "Settle Two More Quarrels",
	"bounty_pond_keepsakes": "Report the Pond Cache",
	"bounty_crab_cull": "Rock Crab Cull, East Hills",
	"bounty_standing_den_watch": "Standing Order: the Approach Den",
	"bounty_standing_lantern_line": "Standing Order: the Lantern-Line",
	"bounty_standing_road_order": "Standing Order: the Roads",
}

## `WIBounties._delivery_title`'s exact twin, same lockstep contract as
## `_POSTING_TITLES` above (and already bakes in BOTH parcel + destination
## name in one string, e.g. "Wool Bolt to Silverfang Stall" — no separate
## destination-entity lookup needed here).
const _DELIVERY_TITLES := {
	"delivery_krshia_wool": "Wool Bolt to Silverfang Stall",
	"delivery_pisces_parcel": "Ticking Parcel to the Necromancer",
	"delivery_gate_dispatch": "Dispatches to the Gate",
	"delivery_grate_phials": "Glass Phials to the Grate",
	"delivery_inn_hamper": "Fruit Hamper to the Inn",
	"delivery_barracks_gear": "Gambesons to the Barracks",
	"delivery_guild_ledger": "Sealed Ledger to the Guild Desk",
	"delivery_tactics_brief": "Tactics Brief to Olesm",
	"delivery_boulevard_letter": "Sealed Letter to the Boulevard",
	"delivery_riverfarm_seed": "Seed Grain to Riverfarm",
	"delivery_standing_dispatch_run": "The Morning Dispatch Run",
	"delivery_standing_inn_hamper": "The Inn's Standing Order",
	"delivery_standing_barracks_kit": "The Barracks Kit Rotation",
}

var open := false

var pause_menu_ref: Node = null
var inventory_ref: Node = null

var _root: Control
var _title_label: Label
var _body_label: RichTextLabel
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
var _open_act: Dictionary = {}
var _open_quest_lines: Array = []
var _open_completed_quest_lines: Array = []
var _open_skill_groups: Array = []
var _open_seen_statuses: Array = []
var _open_combatants_catalog: Array = []
var _open_bounty_pool: Array = []
var _open_delivery_pool: Array = []
var _open_class_levels: Dictionary = {}
var _open_class_aspirations: Dictionary = {}
var _open_chronicle_facts: Dictionary = {}


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
	# STOP (mouse-filter audit, issue #57): the panel must swallow a click
	# landing on it while open -- not the repo-wide chrome-panel IGNORE
	# default -- so it can never leak through to a world click-to-walk/
	# interact underneath. Safe unconditionally: `.hide()`/`.show()` below
	# already gate this Control's own visibility (an invisible Control
	# receives no input regardless of mouse_filter).
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
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

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.scroll_active = true
	_body_label.fit_content = false
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.meta_underlined = false
	_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_body_label.meta_hover_started.connect(_on_skill_row_hover_started)
	_body_label.meta_clicked.connect(_on_skill_row_meta_clicked)
	stack.add_child(_body_label)

	_scroll_hint = UIChrome.make_label("▼")
	_scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	_scroll_hint.hide()
	_root.add_child(_scroll_hint)

	ObservableBus.domain_event.connect(_on_domain_event)


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
	var completed_quest_lines: Array = Game.sim.completed_quest_summary()
	var skill_groups: Array = Game.sim.skills_journal()
	var seen_statuses: Array = Game.sim.seen_statuses.duplicate()
	# Threaded through both call sites that need it below: the render loop
	# (`_build_body_text` -> `_revealed_skill_line`) and the event-payload
	# loop further down, via the formatter's existing `combatants_catalog`
	# override param.
	var combatants_catalog := _load_combatants_catalog()
	var bounty_pool := _load_json_pool("res://data/bounties.json", "bounties")
	var delivery_pool := _load_json_pool("res://data/deliveries.json", "deliveries")
	var classes_catalog := _load_json_pool("res://data/classes.json", "classes")
	var class_levels := _class_levels_by_heading(classes_catalog)
	var class_aspirations := _class_aspirations_by_heading(classes_catalog)
	var chronicle_facts: Dictionary = {}
	if Game.sim.accomplishment_count("post_game") > 0:
		chronicle_facts = Game.sim.chronicle_facts()
	_open_act = act
	_open_quest_lines = quest_lines
	_open_completed_quest_lines = completed_quest_lines
	_open_skill_groups = skill_groups
	_open_seen_statuses = seen_statuses
	_open_combatants_catalog = combatants_catalog
	_open_bounty_pool = bounty_pool
	_open_delivery_pool = delivery_pool
	_open_class_levels = class_levels
	_open_class_aspirations = class_aspirations
	_open_chronicle_facts = chronicle_facts
	_flat_skill_ids = _flatten_skill_ids(skill_groups)
	_cursor_index = 0 if not _flat_skill_ids.is_empty() else -1
	var built := _build_body_text(act, quest_lines, completed_quest_lines, skill_groups, seen_statuses, combatants_catalog, _cursor_index, bounty_pool, delivery_pool, class_levels, class_aspirations, chronicle_facts)
	_body_label.text = String(built["text"])
	_root.show()
	var vbar := _body_label.get_v_scroll_bar()
	if vbar != null:
		vbar.value = 0.0
	_update_scroll_hint.call_deferred()
	var headings: Array = []
	## Parallel to `headings` (same index order) -- issue #79's per-class
	## identity line, "" for a group with none authored (Innate always, plus
	## most classes -- see `_class_aspirations_by_heading`'s doc comment).
	var class_aspiration_lines: Array = []
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
		var heading := String(group["heading"])
		headings.append(_class_heading_text(heading, class_levels))
		class_aspiration_lines.append(String(class_aspirations.get(heading, "")))
		for raw_skill: Variant in (group["skills"] as Array):
			var skill := raw_skill as Dictionary
			skill_count += 1
			if bool(skill["revealed"]):
				var skill_id := String(skill["id"])
				revealed_skills.append(skill_id)
				revealed_effect_lines.append(WIEffectText.skill_effect_lines(Game.sim.skills.get(skill_id, {}), combatants_catalog))
	var act_beats: Array = act.get("beats", [])
	var act_beats_achieved := 0
	for raw_beat: Variant in act_beats:
		if bool((raw_beat as Dictionary).get("achieved", false)):
			act_beats_achieved += 1
	var posting := _posting_slot_state(bounty_pool, Game.sim.accepted_bounty_id, Game.sim.accepted_bounty_baseline, Callable(self, "_posting_title"), "copy", Game.sim.accepted_bounty())
	var delivery := _posting_slot_state(delivery_pool, Game.sim.accepted_delivery_id, Game.sim.accepted_delivery_baseline, Callable(self, "_delivery_title"), "slip_copy")
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_SHOWN, {
		"quest_lines": quest_lines.size(),
		"completed_quest_lines": completed_quest_lines,
		"skill_groups": headings,
		"class_aspirations": class_aspiration_lines,
		"skill_count": skill_count,
		"skills_note": COMBAT_KIT_NOTE,
		"revealed_skills": revealed_skills,
		"revealed_effect_lines": revealed_effect_lines,
		"act_id": String(act.get("id", "")),
		"act_beats": act_beats.size(),
		"act_beats_achieved": act_beats_achieved,
		"seen_statuses": seen_statuses,
		"posting_title": String(posting.get("title", "")),
		"posting_status": String(posting.get("status", "")),
		"posting_gold": int(posting.get("gold", 0)),
		"posting_detail": String(posting.get("detail", "")),
		"delivery_title": String(delivery.get("title", "")),
		"delivery_status": String(delivery.get("status", "")),
		"delivery_gold": int(delivery.get("gold", 0)),
		"delivery_detail": String(delivery.get("detail", "")),
		"found_notes": _found_note_ids(),
	})
	if not chronicle_facts.is_empty():
		ObservableBus.emit_domain_event(WIEvents.UI_CHRONICLE_RENDERED, {
			"surface": "journal",
			"facts": chronicle_facts,
		})


func _close() -> void:
	open = false
	_root.hide()
	if _scroll_hint != null:
		_scroll_hint.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_HIDDEN, {})


func toggle_open() -> bool:
	if not open and not _can_open():
		return false
	if open:
		_close()
	else:
		_open()
	return true


## Every known skill id, in the SAME order `_build_body_text` renders its
## rows (Innate group first, then one group per held class in catalog
## order) -- see `_flat_skill_ids`' own doc comment.
func _flatten_skill_ids(skill_groups: Array) -> Array[String]:
	var out: Array[String] = []
	for raw_group: Variant in skill_groups:
		for raw_skill: Variant in (raw_group as Dictionary)["skills"]:
			out.append(String((raw_skill as Dictionary)["id"]))
	return out


func _class_heading_text(heading: String, class_levels: Dictionary) -> String:
	if class_levels.has(heading):
		return "%s — Lv %d" % [heading, int(class_levels[heading])]
	return heading


func _class_levels_by_heading(catalog: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw_cls: Variant in catalog:
		var cls := raw_cls as Dictionary
		var id := String(cls.get(WIKeys.ID, ""))
		if id != "" and Game.sim.classes.has(id):
			out[String(cls.get(WIKeys.DISPLAY_NAME, id))] = int(Game.sim.classes[id])
	return out


func _class_aspirations_by_heading(catalog: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw_cls: Variant in catalog:
		var cls := raw_cls as Dictionary
		var id := String(cls.get(WIKeys.ID, ""))
		if id == "" or not Game.sim.classes.has(id) or not cls.has("aspiration"):
			continue
		var text := String((cls["aspiration"] as Dictionary).get("text", ""))
		if text != "":
			out[String(cls.get(WIKeys.DISPLAY_NAME, id))] = text
	return out


func _move_cursor(delta: int) -> void:
	if _flat_skill_ids.is_empty():
		return
	_cursor_index = clampi(_cursor_index + delta, 0, _flat_skill_ids.size() - 1)
	_rebuild_body_follow_cursor()


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


func _on_skill_row_hover_started(meta: Variant) -> void:
	var idx := String(meta).to_int()
	if idx < 0 or idx >= _flat_skill_ids.size() or idx == _cursor_index:
		return
	_cursor_index = idx
	_rebuild_body_no_scroll()


func _on_skill_row_meta_clicked(meta: Variant) -> void:
	var idx := String(meta).to_int()
	if idx < 0 or idx >= _flat_skill_ids.size():
		return
	_cursor_index = idx
	_toggle_cursor_skill()


func click_skill_row(flat_i: int) -> void:
	_on_skill_row_meta_clicked(str(flat_i))


## Same rebuild `_rebuild_body_follow_cursor` performs, minus the
## scroll-to-cursor-line/scroll-hint follow-up -- see
## `_on_skill_row_hover_started`'s doc comment for why hover must NOT scroll.
func _rebuild_body_no_scroll() -> void:
	var built := _build_body_text(_open_act, _open_quest_lines, _open_completed_quest_lines, _open_skill_groups, _open_seen_statuses, _open_combatants_catalog, _cursor_index, _open_bounty_pool, _open_delivery_pool, _open_class_levels, _open_class_aspirations, _open_chronicle_facts)
	_body_label.text = String(built["text"])


func _rebuild_body_follow_cursor() -> void:
	var built := _build_body_text(_open_act, _open_quest_lines, _open_completed_quest_lines, _open_skill_groups, _open_seen_statuses, _open_combatants_catalog, _cursor_index, _open_bounty_pool, _open_delivery_pool, _open_class_levels, _open_class_aspirations, _open_chronicle_facts)
	_body_label.text = String(built["text"])
	var cursor_line := int(built["cursor_line"])
	if cursor_line >= 0:
		_body_label.scroll_to_line.call_deferred(cursor_line)
	_update_scroll_hint.call_deferred()


func _update_scroll_hint() -> void:
	if _scroll_hint == null:
		return
	var vbar := _body_label.get_v_scroll_bar()
	var more_below := vbar != null and vbar.value < (vbar.max_value - vbar.page - 1.0)
	_scroll_hint.visible = open and more_below


## Every skill row leads with a "✓ "/"  " assign marker (reading
## `Game.sim.hotbar_loadout` directly — journal.gd already references
## Game.sim freely, it isn't purity-constrained) and the `cursor_index`'th
## row (in the SAME flattened order `_flatten_skill_ids` produces) is
## wrapped in `[b]...[/b]` with a "▶ " lead glyph. A class group's heading
## additionally gets " — Lv N" appended (`class_levels`, keyed by the SAME
## display-name string the heading already is -- see `_class_levels_by_
## heading`'s doc comment) -- "Innate" never matches an entry there, so it
## stays bare, per the OPAQUE-UNTIL-SLEEP rule (class LEVEL is player-visible,
## unlike raw stats). Returns a Dictionary `{text: String, cursor_line: int}`
## instead of a bare String -- `cursor_line` is the 0-based BBCode line the
## cursor row landed on (-1 if `cursor_index` didn't match any row), so the
## caller can `scroll_to_line` it into view without a second, drift-prone
## line-counting pass.
func _build_body_text(act: Dictionary, quest_lines: Array, completed_quest_lines: Array, skill_groups: Array, seen_statuses: Array, combatants_catalog: Array = [], cursor_index: int = -1, bounty_pool: Array = [], delivery_pool: Array = [], class_levels: Dictionary = {}, class_aspirations: Dictionary = {}, chronicle_facts: Dictionary = {}) -> Dictionary:
	var parts: Array = []
	var cursor_line := -1
	if not act.is_empty():
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(String(act.get("header", ""))))
		for raw_beat: Variant in act.get("beats", []):
			var beat := raw_beat as Dictionary
			var marker := "✓ " if bool(beat.get("achieved", false)) else "· "
			parts.append("%s%s" % [marker, UIChrome.bb_escape(String(beat.get("text", "")))])
		parts.append("")
	parts.append("[b]Quests[/b]")
	if quest_lines.is_empty():
		parts.append("No quests in progress." if not completed_quest_lines.is_empty() else "No quests yet.")
	else:
		for line: Variant in quest_lines:
			parts.append(UIChrome.bb_escape(String(line)))
	parts.append("")
	if not completed_quest_lines.is_empty():
		parts.append("[b]Completed[/b]")
		for line: Variant in completed_quest_lines:
			parts.append(UIChrome.bb_escape(String(line)))
		parts.append("")
	parts.append("[b]Postings[/b]")
	var posting_lines := _build_postings_lines(bounty_pool, delivery_pool)
	for line: String in posting_lines:
		parts.append(line)
	parts.append("")
	parts.append("[b]Skills[/b]")
	parts.append(COMBAT_KIT_NOTE)
	parts.append("Slotted skills appear on your bars.  •  Up/Down to move  •  %s to toggle" % WIInputHints.label("confirm"))
	var flat_i := 0
	# GH#171: the checkmarks were unlabeled -- players could not tell
	# selection = hotbar loadout.
	parts.append("[i]Checked skills ride your hotbar — confirm on a row to swap it.[/i]")
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		var heading := String(group["heading"])
		parts.append("")
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(_class_heading_text(heading, class_levels)))
		if class_aspirations.has(heading):
			parts.append("[i]%s[/i]" % UIChrome.bb_escape(String(class_aspirations[heading])))
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
			line = "[url=%d]%s[/url]" % [flat_i, line]
			parts.append(line)
			flat_i += 1
	if not seen_statuses.is_empty():
		parts.append("")
		parts.append("[b]Effects[/b]")
		for status_id: Variant in seen_statuses:
			parts.append(UIChrome.bb_escape(WIEffectText.status_line(String(status_id), Game.sim.skills.values())))
	var found_notes := _found_note_ids()
	if not found_notes.is_empty():
		parts.append("")
		parts.append("[b]Lore[/b]")
		for note_id: String in found_notes:
			var note_record: Dictionary = Game.sim.item(note_id)
			var note_name := String(note_record.get("name", note_id))
			var note_lore := String(note_record.get("lore", ""))
			if note_lore != "":
				parts.append(UIChrome.bb_escape("%s — %s" % [note_name, note_lore]))
			else:
				parts.append(UIChrome.bb_escape(note_name))
	if not chronicle_facts.is_empty():
		parts.append("")
		parts.append("[b]Chronicle[/b]")
		parts.append(UIChrome.bb_escape("%s — %s" % [String(chronicle_facts.get("name", "Traveler")), String(chronicle_facts.get("race", ""))]))
		var chronicle_classes: Array[String] = []
		for raw_class: Variant in chronicle_facts.get("classes", []):
			var class_facts := raw_class as Dictionary
			chronicle_classes.append("%s Lv%d" % [String(class_facts.get("name", "")), int(class_facts.get("level", 0))])
		parts.append(UIChrome.bb_escape("Classes: %s" % (", ".join(chronicle_classes) if not chronicle_classes.is_empty() else "—")))
		parts.append(UIChrome.bb_escape("Quests completed: %d  •  Victories: %d  •  Sleeps: %d" % [int(chronicle_facts.get("quests_completed", 0)), int(chronicle_facts.get("victories", 0)), int(chronicle_facts.get("sleeps", 0))]))
		parts.append(UIChrome.bb_escape(String(chronicle_facts.get("ending", ""))))
	# GH#170: Recent Messages tail -- APPEND-ONLY position so every
	# contains-style body pin above survives. Newest last (reading order).
	var layer_script := load("res://src/ui/message_layer.gd")
	var recent: Array = layer_script.recent_messages if layer_script != null else []
	if not recent.is_empty():
		parts.append("")
		parts.append("[b]Recent Messages[/b]")
		for msg: Variant in recent:
			parts.append("[i]%s[/i]" % UIChrome.bb_escape(String(msg)))
	return {"text": "\n".join(parts), "cursor_line": cursor_line}


func _build_postings_lines(bounty_pool: Array, delivery_pool: Array) -> Array[String]:
	var lines: Array[String] = []
	var posting := _posting_slot_state(bounty_pool, Game.sim.accepted_bounty_id, Game.sim.accepted_bounty_baseline, Callable(self, "_posting_title"), "copy", Game.sim.accepted_bounty())
	if not posting.is_empty():
		lines.append(UIChrome.bb_escape("%s — %s (%d gold)" % [String(posting["title"]), String(posting["status"]), int(posting["gold"])]))
		var posting_detail := String(posting["detail"])
		if posting_detail != "":
			lines.append("   " + UIChrome.bb_escape(posting_detail))
	var delivery := _posting_slot_state(delivery_pool, Game.sim.accepted_delivery_id, Game.sim.accepted_delivery_baseline, Callable(self, "_delivery_title"), "slip_copy")
	if not delivery.is_empty():
		lines.append(UIChrome.bb_escape("%s — %s (%d gold)" % [String(delivery["title"]), String(delivery["status"]), int(delivery["gold"])]))
		var delivery_detail := String(delivery["detail"])
		if delivery_detail != "":
			lines.append("   " + UIChrome.bb_escape(delivery_detail))
	if lines.is_empty():
		lines.append("No postings in hand. The boards at the Guilds always have more.")
	return lines


## `title_fn` is `_posting_title`'s or `_delivery_title`'s Callable (bounty
## vs. delivery id prefixes need different maps). `detail_key` is the
## record's own flavor-text field ("copy" for a bounty, "slip_copy" for a
## delivery -- issue #79's own posting-slip detail view, see `_build_
## postings_lines`'s doc comment). `status` is the OPAQUE-UNTIL-DONE binary
## line -- see `_condition_met`'s doc comment for how it stays in lockstep
## with the real turn-in gate. Shared by `_build_postings_lines` (the panel
## body) and `_open()`'s event-emission block (the `ui_journal_shown`
## payload) -- each call site computes it independently rather than
## threading one result through both, the SAME duplication shape this file
## already accepts for the skill-groups/headings loop above.
func _posting_slot_state(pool: Array, accepted_id: String, baseline: Dictionary, title_fn: Callable, detail_key: String, resolved_record: Dictionary = {}) -> Dictionary:
	if accepted_id == "":
		return {}
	# Issue #163: a tiered bounty accepted at silver/gold must show its LOCKED
	# tier's copy/gold/condition, not the bronze base -- callers pass the
	# resolved record (Game.sim.accepted_bounty()); deliveries pass none.
	var record := resolved_record if not resolved_record.is_empty() else _pool_record(pool, accepted_id)
	if record.is_empty():
		return {}
	var met := _condition_met(record.get("condition", {}), baseline, String(record.get("condition_mode", "delta")))
	return {
		"title": String(title_fn.call(accepted_id)),
		"status": "Ready to turn in." if met else "In hand.",
		"gold": int(record.get("gold", 0)),
		"detail": String(record.get(detail_key, "")),
	}


## True when the accepted posting/slip's condition clears -- calls the SAME
## pure static (`WIBounties.condition_met`) that `WIGame._bounty_condition_
## met`/`_delivery_condition_met` call. Those two are private-by-convention
## (leading underscore) on wi_game.gd, so this file can't call THEM directly
## -- it duplicates the one-line CALL SITE instead of the condition logic
## itself, which stays in exactly one place (bounties.gd). Any future change
## to those private methods' call shape (a new `condition_mode`, an extra
## param) must be mirrored here or this journal section can drift from the
## real turn-in gate.
func _condition_met(condition: Dictionary, baseline: Dictionary, mode: String) -> bool:
	return WIBounties.condition_met(condition, baseline, Callable(Game.sim, "accomplishment_count"), mode)


func _posting_title(id: String) -> String:
	return String(_POSTING_TITLES.get(id, id.trim_prefix("bounty_").capitalize()))


func _delivery_title(id: String) -> String:
	return String(_DELIVERY_TITLES.get(id, id.trim_prefix("delivery_").capitalize()))


## Every held inventory item id carrying the `note_` prefix -- the found-note
## collectible convention (issue #81), mirroring this file's own `bounty_`/
## `delivery_` id-prefix idiom (`_posting_title`/`_delivery_title`'s fallback
## branch). Reads `Game.sim.inventory` directly (this file already reaches
## into `Game.sim` freely, not purity-constrained) -- no new sim field, no
## catalog needed beyond the existing `Game.sim.item()` accessor the Lore
## section itself calls. In inventory order (insertion order, stable).
func _found_note_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in Game.sim.inventory:
		if id.begins_with("note_"):
			out.append(id)
	return out


func _pool_record(pool: Array, id: String) -> Dictionary:
	for raw: Variant in pool:
		var record := raw as Dictionary
		if String(record.get("id", "")) == id:
			return record
	return {}


func _load_json_pool(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).has(key):
		return (parsed as Dictionary)[key]
	return []


func _revealed_skill_line(id: String, display_name: String, combatants_catalog: Array = []) -> String:
	var record: Dictionary = Game.sim.skills.get(id, {})
	var desc := String(record.get("description", ""))
	var effect_lines := WIEffectText.skill_effect_lines(record, combatants_catalog)
	if effect_lines.is_empty():
		return "%s — %s" % [display_name, desc] if desc != "" else display_name
	if desc == "":
		return "%s — %s" % [display_name, effect_lines[0]]
	return "%s — %s — %s" % [display_name, effect_lines[0], desc]


func _load_combatants_catalog() -> Array:
	const COMBATANTS_PATH := "res://data/combatants.json"
	if not FileAccess.file_exists(COMBATANTS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has("combatants"):
		return (parsed as Dictionary)["combatants"]
	return []
