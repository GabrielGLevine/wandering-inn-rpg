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
## GH#334 note 2: the always-visible "how do I get out of here" row.
var _close_hint: Label

## The assignment surface. `_flat_skill_ids` is every RENDERED skill id in the
## SAME order `_build_skills_tab` renders its rows (GH#336: the four category
## buckets in `WIGame.SKILL_CATEGORY_ORDER`, deduped, mirroring
## `skills_journal_categories()`'s own grouping -- it was class-primary and
## duplicated before) -- rebuilt once per `_open()` (the group/skill SET can't
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
## Total travel, in px, before an in-flight body gesture stops counting as a tap.
## NO REPO PRECEDENT EXISTED -- this sets one, so the number is argued rather
## than picked: (a) it must exceed the drift a resting finger produces between
## press and release on a touch screen, which is a px or two, or the latch eats
## real taps; (b) it must sit well under the 20px body row pitch, or a pan can
## cross a whole row and still be read as a tap on the row it lands in. 4px is
## the middle of that window and a quarter of a row. Mouse taps drift 0px and are
## unaffected either way. CHOICE-LOG 2026-07-28 carries the call and its revert.
const BODY_PAN_SLOP_PX := 4.0

## True once the in-flight body gesture has travelled past the slop: a pan, not a
## tap. `_body_gesture_drift` is its accumulator. Both reset on every fresh press
## AND on every open/close/tab-switch (see `_reset_body_gesture`), so a latched
## flag can never outlive the gesture that set it and swallow a later tap.
var _body_gesture_panned := false
var _body_gesture_drift := 0.0
var _open_act: Dictionary = {}
var _open_leads: Array = []
var _open_quest_lines: Array = []
## GH#338: parallel to `_open_quest_lines` by index, already gated by the
## "Quest Hints" setting -- "" means "no sub-row drawn for this quest", whether
## because the beat authored none or because the player switched them off.
var _open_quest_hint_lines: Array = []
var _open_completed_quest_lines: Array = []
var _open_skill_groups: Array = []
## GH#336: the CATEGORIZED, deduped groups the Skills-tab body actually renders
## (`WIGame.skills_journal_categories()`). `_open_skill_groups` above is still
## captured, unchanged, because the class-primary grouping is what the
## `skill_groups`/`class_aspirations` payload keys and the Classes strip need.
var _open_skill_categories: Array = []
var _open_seen_statuses: Array = []
var _open_combatants_catalog: Array = []
var _open_bounty_pool: Array = []
var _open_delivery_pool: Array = []
var _open_class_levels: Dictionary = {}
var _open_class_aspirations: Dictionary = {}
var _open_chronicle_facts: Dictionary = {}

## Issue #209: the journal is split into three internal tabs. Only the ACTIVE
## tab's slice renders into `_body_label`; the section-DATA payload emitted on
## `UI_JOURNAL_SHOWN` stays FULL and tab-independent (every existing field is
## present regardless of which tab shows), so the ~20 payload-only QA pins
## survive the split untouched -- see the a8 plan's de-risking finding. Default
## = Quests on every open; the skill cursor is LIVE only on the Skills tab.
enum Tab { QUESTS, SKILLS, HISTORY }
const _TAB_IDS: Array[String] = ["quests", "skills", "history"]
const _TAB_TITLES: Array[String] = ["Quests", "Skills", "History"]
var _active_tab: int = Tab.QUESTS
var _tab_labels: Array[Label] = []
## The full section-DATA payload, cached at open. The section SET/DATA can't
## change while the journal is open (same modal-exclusivity guarantee
## `_flat_skill_ids`' doc comment relies on), so a tab switch re-emits this
## verbatim with only `active_tab` updated -- QA can assert the visible tab
## without any section field drifting.
var _journal_payload: Dictionary = {}


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

	# Issue #209: the three-tab switcher bar (Quests / Skills / History). Each
	# label is tappable via its own STOP mouse_filter + gui_input hook (the
	# SAME shape `_body_label`'s drag hook below uses); the driver's
	# `click_journal_tab` action clicks a label's `tab_rect`. Keyboard
	# `move_left`/`move_right` switch too (see `_unhandled_input`). The active
	# tab is bracket-highlighted by `_refresh_tab_bar`.
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 22)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in _TAB_TITLES.size():
		var tab_label := UIChrome.make_label("", "Small")
		tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_label.mouse_filter = Control.MOUSE_FILTER_STOP
		tab_label.gui_input.connect(_on_tab_label_gui_input.bind(i))
		_tab_labels.append(tab_label)
		tab_bar.add_child(tab_label)
	stack.add_child(tab_bar)

	# JOURNAL/HALF-ROW (P3), v0.15 A4. The body used to be the VBox's own
	# EXPAND_FILL child, so its height was "whatever is left after the ribbon and
	# the tab bar" — a number with no relationship to the text pitch, which is
	# why the last row rendered sliced ("The Missing Crate — Complete." on both
	# climax_seal/02 and spine_reach/02) and read as a clipping bug rather than
	# as "more below". The EXPAND_FILL now lives on a plain Control SLOT and the
	# body is anchored full-rect INSIDE it, so `_clip_body_to_line_boundary` can
	# shorten the body to a whole number of rows from the slot's own height. The
	# dependency runs one way only (slot height -> body height; a Control parent
	# never resizes to its children), so there is no layout feedback loop, and if
	# the clip never runs the body still fills the slot exactly as before.
	var body_slot := Control.new()
	body_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(body_slot)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.scroll_active = true
	_body_label.fit_content = false
	UIChrome.full_rect(_body_label)
	_body_label.meta_underlined = false
	_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_body_label.meta_hover_started.connect(_on_skill_row_hover_started)
	_body_label.meta_clicked.connect(_on_skill_row_meta_clicked)
	# a4 #216 slice 2: the body scrolls on touch/mouse DRAG (wheel-only
	# before — a touch player had no way to read past the fold).
	_body_label.gui_input.connect(_on_body_gui_input)
	body_slot.add_child(_body_label)
	body_slot.resized.connect(_clip_body_to_line_boundary)

	# GH#334 note 2: the close affordance. Deliberately NOT a row in `stack` and
	# NOT a line in a per-tab hint block -- both were tried and both are wrong.
	# A body line scrolls away (and only the Skills tab had a hint block at all);
	# a stack row steals height from `body_slot`, which moves every BBCode line
	# in the panel and quietly re-aims field_skills_loop's own drag/tap
	# coordinates. It is an OVERLAY on `_root` instead, the exact idiom the `▼`
	# more-below cue below already uses: bottom margin band, zero layout effect.
	# Bottom-RIGHT so it never sits under the centered arrow. Device-aware
	# through the same `WIInputHints.label()` table every other on-screen hint
	# composes from, re-composed on INPUT_DEVICE_CHANGED (see `_on_domain_event`)
	# so picking up a pad mid-read swaps Esc/J for B/Y live.
	_close_hint = UIChrome.make_label("", "Small")
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	_root.add_child(_close_hint)
	_refresh_close_hint()

	_scroll_hint = UIChrome.make_label("▼")
	_scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	_scroll_hint.hide()
	_root.add_child(_scroll_hint)

	ObservableBus.domain_event.connect(_on_domain_event)


## Shortens the body viewport to a WHOLE number of text rows, so its bottom
## edge is always a line boundary and the `▼` cue means "more below" instead of
## "this row is cut in half". Measured from the RichTextLabel's own theme font
## (`normal_font`/`normal_font_size`, the keys RichTextLabel actually draws
## with) rather than from the panel constants, so a theme font-size change
## re-quantizes itself. Never grows the body past the slot; a run where the
## metrics are unavailable leaves the pre-existing full-fill behaviour intact.
func _clip_body_to_line_boundary() -> void:
	if _body_label == null:
		return
	var slot := _body_label.get_parent() as Control
	if slot == null or slot.size.y <= 0.0:
		return
	var font := _body_label.get_theme_font("normal_font")
	var font_size := _body_label.get_theme_font_size("normal_font_size")
	if font == null or font_size <= 0:
		return
	var separation := float(_body_label.get_theme_constant("line_separation"))
	var pitch := font.get_height(font_size) + separation
	if pitch <= 0.0:
		return
	var rows := maxi(int((slot.size.y + separation) / pitch), 1)
	var used := float(rows) * pitch - separation
	_body_label.offset_bottom = -maxf(slot.size.y - used, 0.0)
	_update_scroll_hint.call_deferred()


## GH#334 note 2. Both keys are true: `cancel` is the new universal-back close,
## `journal` is the toggle that has always closed it. Naming both is what makes
## the row an answer rather than a second thing to memorize.
func _close_hint_text() -> String:
	return "%s or %s to close" % [WIInputHints.label("cancel"), WIInputHints.label("journal")]


func _refresh_close_hint() -> void:
	if _close_hint != null:
		_close_hint.text = _close_hint_text()


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.INPUT_DEVICE_CHANGED and open:
		_refresh_close_hint()
		_rebuild_body_follow_cursor()


## a4 #216 slice 2: drag-to-scroll the journal body. A held-button mouse
## drag or a touch screen-drag pans the v-scroll bar; a stationary press
## still reaches meta_clicked (skill rows) since we only act on motion.
## a4 #216 slice 2: QA scroll hooks — the drag leg asserts the body
## scroll VALUE moved and reads the body rect to aim the drag.
func body_scroll_value() -> float:
	if not open:
		return -1.0
	var vbar := _body_label.get_v_scroll_bar()
	return vbar.value if vbar != null else -1.0


func body_scrollable() -> bool:
	if not open:
		return false
	var vbar := _body_label.get_v_scroll_bar()
	return vbar != null and vbar.max_value > vbar.page


func body_rect() -> Rect2:
	if not open or _body_label == null or not _body_label.visible:
		return Rect2()
	return Rect2(_body_label.global_position, _body_label.size)


## Clears the in-flight gesture. Called on every fresh press, on the meta
## handler's consume, and on every open/close/tab-switch: a flag latched by a pan
## that ended outside the body (or on a tab the player then left) would otherwise
## sit armed and swallow the NEXT tap -- and a programmatic `meta_clicked` with
## no press behind it, which is how QA and any future scripted click arrive,
## would hit that stale flag with no gesture to blame.
func _reset_body_gesture() -> void:
	_body_gesture_panned = false
	_body_gesture_drift = 0.0


func _on_body_gui_input(event: InputEvent) -> void:
	if not open:
		return
	# A gesture that PANNED must not also count as a tap on whatever row it
	# happens to let go over. RichTextLabel fires `meta_clicked` on button
	# RELEASE over a meta region regardless of intervening motion, so before
	# this latch a drag-to-scroll that ended on a skill row silently toggled that
	# skill in and out of the field loadout -- the exact failure `field_skills_loop`
	# hit the moment `_clip_body_to_line_boundary` moved the release point by a
	# few px. The clip only EXPOSED it; any scroll position, panel size or font
	# change could land the same accidental toggle on a player.
	#
	# ACCUMULATED, with slop -- see BODY_PAN_SLOP_PX. Latching on the first
	# motion event of ANY magnitude would have been worse than the bug on touch,
	# where a finger never holds still: a 1px drift between press and release
	# would have eaten a legitimate tap, and the player would have got nothing at
	# all instead of the wrong thing.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_reset_body_gesture()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_reset_body_gesture()
	var dy := 0.0
	if event is InputEventScreenDrag:
		dy = (event as InputEventScreenDrag).relative.y
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		dy = (event as InputEventMouseMotion).relative.y
	else:
		return
	# Total travel, not per-event travel: a slow pan arrives as many small deltas
	# and must still latch, while a jittery tap's deltas cancel out in position
	# but NOT in magnitude -- so this sums absolute values and never resets
	# mid-gesture. Scrolling itself stays unconditional below: a sub-slop wobble
	# pans by those same few px, which is invisible, and still counts as a tap.
	_body_gesture_drift += absf(dy)
	if _body_gesture_drift > BODY_PAN_SLOP_PX:
		_body_gesture_panned = true
	var vbar := _body_label.get_v_scroll_bar()
	if vbar != null and vbar.max_value > vbar.page:
		vbar.value = clampf(vbar.value - dy, vbar.min_value, vbar.max_value - vbar.page)
		_update_scroll_hint()
		get_viewport().set_input_as_handled()


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
	if not open:
		return
	# GH#334 note 2: `cancel` closes the journal. The inventory has always done
	# this; the journal never handled `cancel` at all, so Esc/B was swallowed
	# with no feedback (pause_menu refuses to open while the journal is open,
	# `pause_menu.gd`'s own `_can_open`) -- the one panel in the game where the
	# universal back key did literally nothing. Routed through `_close()` so
	# UI_JOURNAL_HIDDEN still emits exactly as the `journal` toggle's close does,
	# and CONSUMED here (`set_input_as_handled`) so it can never fall through to
	# the pause menu in some future ordering where that refusal is relaxed.
	# Placed FIRST among the open-only branches: no other branch claims `cancel`.
	if event.is_action_pressed("cancel"):
		_close()
		get_viewport().set_input_as_handled()
		return
	# Issue #209: left/right switch tabs (world.gd gates its own move_left/
	# move_right out while any modal is open -- `_movement_gated` -- so
	# consuming them here is purely additive, never a lost player move).
	if event.is_action_pressed("move_left"):
		_switch_tab_relative(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_switch_tab_relative(1)
		get_viewport().set_input_as_handled()
	elif _active_tab == Tab.SKILLS and event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif _active_tab == Tab.SKILLS and event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif _active_tab == Tab.SKILLS and event.is_action_pressed("confirm"):
		_toggle_cursor_skill()
		get_viewport().set_input_as_handled()


## GH#170(b): the combat blow-by-blow feeds Recent Messages; this count in
## the UI_JOURNAL_SHOWN payload lets QA prove the history is non-empty
## after a fight without pinning volatile line text.
func _recent_message_count() -> int:
	var layer_script := load("res://src/ui/message_layer.gd")
	return (layer_script.recent_messages as Array).size() if layer_script != null else 0


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
	_reset_body_gesture()
	var act: Dictionary = Game.sim.act_summary()
	var leads: Array = Game.sim.active_leads()
	var quest_lines: Array = Game.sim.quest_summary()
	var quest_hints: Array = Game.sim.quest_hint_lines()
	var completed_quest_lines: Array = Game.sim.completed_quest_summary()
	var skill_groups: Array = Game.sim.skills_journal()
	var skill_categories: Array = Game.sim.skills_journal_categories()
	var seen_statuses: Array = Game.sim.seen_statuses.duplicate()
	# Threaded through both call sites that need it below: the render loop
	# (`_build_skills_tab` -> `_revealed_skill_line`) and the event-payload
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
	_open_leads = leads
	_open_quest_lines = quest_lines
	# GH#338: captured PRE-gated (the sim always tells the truth about what the
	# beats authored); the settings toggle is applied once, here, so the render
	# and the payload can never disagree about what the player saw.
	_open_quest_hint_lines = _gated_quest_hints(quest_hints)
	_open_completed_quest_lines = completed_quest_lines
	_open_skill_groups = skill_groups
	_open_skill_categories = skill_categories
	_open_seen_statuses = seen_statuses
	_open_combatants_catalog = combatants_catalog
	_open_bounty_pool = bounty_pool
	_open_delivery_pool = delivery_pool
	_open_class_levels = class_levels
	_open_class_aspirations = class_aspirations
	_open_chronicle_facts = chronicle_facts
	_flat_skill_ids = _flatten_skill_ids(skill_categories)
	_cursor_index = 0 if not _flat_skill_ids.is_empty() else -1
	# Issue #209: every open lands on the Quests tab; the skill cursor is armed
	# but inert until the player switches to the Skills tab.
	_active_tab = Tab.QUESTS
	_render_active_tab(false)
	_refresh_tab_bar()
	_refresh_close_hint()
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
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		var heading := String(group["heading"])
		headings.append(_class_heading_text(heading, class_levels))
		class_aspiration_lines.append(String(class_aspirations.get(heading, "")))
	## GH#336: `skill_count`/`revealed_skills`/`revealed_effect_lines` now count
	## RENDERED ROWS, which after the dedupe is one per DISTINCT Skill -- the
	## number the panel actually draws. On every save that pins them today the
	## PC holds at most one class, so no Skill had a duplicate and the pinned
	## values are byte-unchanged; a multi-class save is where the old count was
	## lying (46 rows for 28 Skills).
	var skill_count := 0
	## Category headings in render order (spec trap R4: category headings ride a
	## NEW payload key -- `skill_groups` keeps carrying the CLASS headings).
	var skill_categories_rendered: Array = []
	## Every rendered row's skill id, in the exact flattened cursor order
	## `_flatten_skill_ids` produces -- so a QA re-pin of a cursor index is
	## derivable from the payload instead of by counting rows in a screenshot.
	var skill_row_ids: Array = []
	for raw_group: Variant in skill_categories:
		var category_group := raw_group as Dictionary
		skill_categories_rendered.append(String(category_group["heading"]))
		for raw_skill: Variant in (category_group["skills"] as Array):
			var skill := raw_skill as Dictionary
			skill_count += 1
			var skill_id := String(skill["id"])
			skill_row_ids.append(skill_id)
			if bool(skill["revealed"]):
				revealed_skills.append(skill_id)
				revealed_effect_lines.append(WIEffectText.skill_effect_lines(Game.sim.skills.get(skill_id, {}), combatants_catalog))
	var act_beats: Array = act.get("beats", [])
	var act_beats_achieved := 0
	for raw_beat: Variant in act_beats:
		if bool((raw_beat as Dictionary).get("achieved", false)):
			act_beats_achieved += 1
	var posting := _posting_slot_state(bounty_pool, Game.sim.accepted_bounty_id, Game.sim.accepted_bounty_baseline, Callable(self, "_posting_title"), "copy", Game.sim.accepted_bounty())
	var delivery := _posting_slot_state(delivery_pool, Game.sim.accepted_delivery_id, Game.sim.accepted_delivery_baseline, Callable(self, "_delivery_title"), "slip_copy")
	# Issue #209: the payload is cached FULL (every section's data, independent
	# of the visible tab) and re-emitted verbatim on each tab switch with only
	# `active_tab` updated -- see `_journal_payload`'s doc comment and
	# `_emit_journal_shown`.
	_journal_payload = {
		"quest_lines": quest_lines.size(),
		# GH#338 ruling 5: the count-only gap closes. `quest_line_texts` is the
		# exact rendered quest rows, `quest_hint_lines` their sub-rows (parallel
		# by index, "" where none drew) -- so QA can pin the strings the panel
		# actually wrote instead of asserting on a number.
		"quest_line_texts": quest_lines.duplicate(),
		"quest_hint_lines": _open_quest_hint_lines.duplicate(),
		"completed_quest_lines": completed_quest_lines,
		"skill_groups": headings,
		"class_aspirations": class_aspiration_lines,
		"skill_categories": skill_categories_rendered,
		"skill_row_ids": skill_row_ids,
		"skill_count": skill_count,
		"skills_note": COMBAT_KIT_NOTE,
		# GH#334 note 2: the rendered close-affordance row, carried as a real
		# rendered fact so QA pins the string the player actually reads.
		"close_hint": _close_hint_text(),
		"revealed_skills": revealed_skills,
		"revealed_effect_lines": revealed_effect_lines,
		"act_id": String(act.get("id", "")),
		"act_beats": act_beats.size(),
		"act_beats_achieved": act_beats_achieved,
		"act_beat_lines": _act_beat_lines(),
		"lead_lines": _lead_lines(),
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
		# Newest-first, matching the render order -- QA asserts lore CAPTURE
		# structurally instead of reading a screenshot for it.
		"lore_notes": _lore_note_lines(),
		"recent_count": _recent_message_count(),
	}
	_emit_journal_shown()
	if not chronicle_facts.is_empty():
		ObservableBus.emit_domain_event(WIEvents.UI_CHRONICLE_RENDERED, {
			"surface": "journal",
			"facts": chronicle_facts,
		})


func _close() -> void:
	open = false
	_reset_body_gesture()
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


## Issue #209: re-emit the cached full payload with the current tab id. Both
## `_open()` (first show, Quests) and `_switch_tab()` route through here, so QA
## reads one event type (`ui_journal_shown`) whose `active_tab` names the
## visible tab while every section field stays present and unchanged.
func _emit_journal_shown() -> void:
	_journal_payload["active_tab"] = _TAB_IDS[_active_tab]
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_SHOWN, _journal_payload)


## Bracket-highlight the active tab label (plain Labels, no bbcode -- brackets
## are the visible active marker, matching the panel's terse chrome).
func _refresh_tab_bar() -> void:
	for i in _tab_labels.size():
		_tab_labels[i].text = ("[ %s ]" % _TAB_TITLES[i]) if i == _active_tab else _TAB_TITLES[i]


func _switch_tab_relative(delta: int) -> void:
	var n := _TAB_IDS.size()
	_switch_tab((_active_tab + delta + n) % n)


func _switch_tab(new_tab: int) -> void:
	if not open or new_tab == _active_tab:
		return
	_reset_body_gesture()
	_active_tab = new_tab
	# Entering Skills re-arms the cursor at row 0 (or -1 when the PC knows zero
	# skills); leaving it makes the cursor inert (guarded in `_unhandled_input`
	# and the row handlers) -- the "cursor LIVE only on Skills" contract.
	if _active_tab == Tab.SKILLS:
		_cursor_index = 0 if not _flat_skill_ids.is_empty() else -1
	_refresh_tab_bar()
	_render_active_tab(_active_tab == Tab.SKILLS)
	var vbar := _body_label.get_v_scroll_bar()
	if vbar != null:
		vbar.value = 0.0
	_update_scroll_hint.call_deferred()
	_emit_journal_shown()


func _on_tab_label_gui_input(event: InputEvent, tab_index: int) -> void:
	if not open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_switch_tab(tab_index)
		get_viewport().set_input_as_handled()


## Issue #209 QA hook: the tab label's on-screen rect (empty when closed or the
## id is unknown), mirroring `body_rect`/`playtest_page_rect` so the driver's
## `click_journal_tab` can tap it. `tab_id` is one of `_TAB_IDS`.
func tab_rect(tab_id: String) -> Rect2:
	if not open:
		return Rect2()
	var idx := _TAB_IDS.find(tab_id)
	if idx < 0 or idx >= _tab_labels.size():
		return Rect2()
	var lbl := _tab_labels[idx]
	if lbl == null or not lbl.visible:
		return Rect2()
	return Rect2(lbl.global_position, lbl.size)


## Issue #209 QA hook: the active tab's id (one of `_TAB_IDS`).
func active_tab_id() -> String:
	return _TAB_IDS[_active_tab] if open else ""


## Render ONLY the active tab's body into `_body_label`. `follow_cursor` scrolls
## the cursor row into view (Skills tab only); a plain re-render leaves scroll
## where it is (Godot resets RichTextLabel scroll to top on `text` assignment,
## which is the intended reset for a fresh open / tab switch).
func _render_active_tab(follow_cursor: bool) -> void:
	var built: Dictionary
	match _active_tab:
		Tab.SKILLS:
			built = _build_skills_tab(_cursor_index)
		Tab.HISTORY:
			built = _build_history_tab()
		_:
			built = _build_quests_tab()
	_body_label.text = String(built["text"])
	if _active_tab == Tab.SKILLS and follow_cursor:
		var cursor_line := int(built.get("cursor_line", -1))
		if cursor_line >= 0:
			_scroll_skill_cursor_into_view.call_deferred(cursor_line)
	_update_scroll_hint.call_deferred()


## FIX WAVE — two defects in what used to be one `scroll_to_line` call.
##
## (a) INDEX SPACE. `cursor_line` counts entries in `parts`, i.e. PARAGRAPHS,
##     while `scroll_to_line` takes a WRAPPED VISUAL line. The redesign renders
##     full descriptions on passive rows, and those wrap to two or three visual
##     lines each, so the old call undershot progressively worse the further
##     down the list the cursor moved. `scroll_to_paragraph` is the
##     index-matched twin — same counting as the renderer, no drift.
##
## (b) UNCONDITIONAL FOLLOW. Scrolling on EVERY render parks the cursor row at
##     the top of the panel, which scrolled the tab's own header off the moment
##     it opened — the kit note, the controls line, and the one sentence that
##     explains the `·` glyph and why confirm refuses on those rows. (Windowed
##     proof of the old behaviour: `qa_output/journal_categories/
##     00_skills_tab_categories.png` opened on "Combat — Active" with all four
##     header lines above the fold and the panel's hint pointing DOWN.) So:
##     scroll only when the cursor row is not already visible. Measured against
##     the live scrollbar rather than guessed from a line count —
##     `get_paragraph_offset` is in the same pixel space as `value`/`page`.
func _scroll_skill_cursor_into_view(paragraph: int) -> void:
	if _body_label == null or paragraph < 0:
		return
	var bar := _body_label.get_v_scroll_bar()
	var top := float(_body_label.get_paragraph_offset(paragraph))
	# Belt: a label that has not laid out yet answers 0 for every offset. Fall
	# back to the unconditional scroll there — a wrong scroll is recoverable,
	# a silent no-op would strand the cursor off-screen on a long list.
	if bar == null or bar.page <= 0.0 or (paragraph > 0 and top <= 0.0):
		_body_label.scroll_to_paragraph(paragraph)
		return
	if top >= bar.value and top + _paragraph_height(paragraph) <= bar.value + bar.page:
		return
	_body_label.scroll_to_paragraph(paragraph)


## Height of one rendered paragraph: the next paragraph's offset minus this
## one's, which counts its wrapped lines exactly. The font size is the floor for
## the last paragraph, which has no successor to measure against.
func _paragraph_height(paragraph: int) -> float:
	var top := float(_body_label.get_paragraph_offset(paragraph))
	if paragraph + 1 < _body_label.get_paragraph_count():
		var next := float(_body_label.get_paragraph_offset(paragraph + 1))
		if next > top:
			return next - top
	return float(_body_label.get_theme_font_size("normal_font_size"))


## Every rendered skill id, in the SAME order `_build_skills_tab` draws its rows
## -- GH#336 moved that from class groups to the four CATEGORY buckets
## (`WIGame.SKILL_CATEGORY_ORDER`), deduped, so this walks `category_groups`
## now. It stays in lockstep with the renderer by construction: both iterate the
## same captured array in the same order, and neither re-sorts.
func _flatten_skill_ids(category_groups: Array) -> Array[String]:
	var out: Array[String] = []
	for raw_group: Variant in category_groups:
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


## GH#336 ruling 4, the other half of the honest checkbox: a row that draws no
## checkbox must not ACT like one either. A passive reaches no bar, so confirm/
## tap on its row refuses instead of quietly parking it on `hotbar_loadout` —
## which is exactly how 41 of 119 catalog entries came to ride a loadout they
## could never appear in. The row stays focusable (one flat cursor, ruling 6);
## only the toggle refuses. `slottable` rides the confirmation event both ways
## so QA can pin the refusal as a rendered fact, not as an absence.
##
## FIX WAVE — the refusal is ONE-WAY. Before GH#336 the checkbox was drawn on
## all 119 catalog entries and ticking a passive parked it on `hotbar_loadout`;
## every v0.16.2 save can therefore be carrying one. A symmetric refusal would
## make that entry PERMANENT — `loadout_toggle` has exactly two UI callers
## (here and inventory.gd's `item:` tokens), so nothing else could clear it,
## and a save whose loadout is a single passive would render BOTH bars empty
## forever (a non-empty loadout is CUSTOM to `WIGame.apply_loadout`). Removing
## a stale entry is never the defect this gate exists to stop, so the gate only
## covers ADDING. Deliberately not "filter hotbar_loadout on load": the spec's
## own trap says never to do that, and this needs no migration pass.
func _toggle_cursor_skill() -> void:
	if _cursor_index < 0 or _cursor_index >= _flat_skill_ids.size():
		return
	var skill_id := _flat_skill_ids[_cursor_index]
	var slottable := _row_slottable(skill_id)
	var stale_entry := not slottable and Game.sim.hotbar_loadout.has(skill_id)
	if slottable or stale_entry:
		Game.sim.loadout_toggle(skill_id)
		_rebuild_body_follow_cursor()
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_LOADOUT_RENDERED, {
		"skill": skill_id,
		"assigned": Game.sim.hotbar_loadout.has(skill_id),
		"cursor_index": _cursor_index,
		"slottable": slottable,
	})


## Read the derived flag off the captured rows -- never re-derived here, so the
## renderer's checkbox and this gate can never disagree.
func _row_slottable(skill_id: String) -> bool:
	for raw_group: Variant in _open_skill_categories:
		for raw_skill: Variant in ((raw_group as Dictionary)["skills"] as Array):
			var skill := raw_skill as Dictionary
			if String(skill["id"]) == skill_id:
				return bool(skill["slottable"])
	return false


func _on_skill_row_hover_started(meta: Variant) -> void:
	# Skill rows exist only on the Skills tab; a stray hover/click elsewhere
	# (the driver can call `click_skill_row` directly) is a no-op (issue #209).
	if _active_tab != Tab.SKILLS:
		return
	var idx := String(meta).to_int()
	if idx < 0 or idx >= _flat_skill_ids.size() or idx == _cursor_index:
		return
	_cursor_index = idx
	_rebuild_body_no_scroll()


func _on_skill_row_meta_clicked(meta: Variant) -> void:
	if _active_tab != Tab.SKILLS:
		return
	# See `_on_body_gui_input`: a release that ended a PAN is not a tap. Consumed
	# here (not just read) so the next genuine stationary press still toggles.
	if _body_gesture_panned:
		_reset_body_gesture()
		return
	var idx := String(meta).to_int()
	if idx < 0 or idx >= _flat_skill_ids.size():
		return
	_cursor_index = idx
	_toggle_cursor_skill()


func click_skill_row(flat_i: int) -> void:
	_on_skill_row_meta_clicked(str(flat_i))


## Re-render the active tab WITHOUT following the cursor -- see
## `_on_skill_row_hover_started`'s doc comment for why hover must NOT scroll.
## (Issue #209: both rebuild wrappers now route through `_render_active_tab`,
## which no-ops the cursor-follow off the Skills tab.)
func _rebuild_body_no_scroll() -> void:
	_render_active_tab(false)


func _rebuild_body_follow_cursor() -> void:
	_render_active_tab(true)


func _update_scroll_hint() -> void:
	if _scroll_hint == null:
		return
	var vbar := _body_label.get_v_scroll_bar()
	var more_below := vbar != null and vbar.value < (vbar.max_value - vbar.page - 1.0)
	_scroll_hint.visible = open and more_below


## The act-beat rows exactly as the player reads them: "✓ " banked / "· "
## pending, over WIActs.render_beats' copy policy (pending beat shows its
## authored `opening`, never its outcome `text`; an opening-less pending beat
## is dropped). ONE source for both the rendered tab and `act_beat_lines` in
## the shown payload -- QA pins the strings the panel actually drew.
func _act_beat_lines() -> Array:
	var lines: Array = []
	for raw_row: Variant in WIActs.render_beats(_open_act):
		var row := raw_row as Dictionary
		lines.append("%s%s" % ["✓ " if bool(row["achieved"]) else "· ", String(row["line"])])
	return lines


## GH#338 — apply the "Quest Hints" setting ONCE, at capture. Default ON: the
## owner asked for clarity by default with an immersion off switch, which is a
## deliberate partial supersession of the thread-legibility spec (CHOICE-LOG).
## Scope is the journal sub-row ONLY -- the "Quest updated:" toast and the Leads
## strip are untouched, because the sim cannot read WISettings and gating the
## toast would mean suppressing it in message_layer for no real gain (ruling 3).
func _gated_quest_hints(hints: Array) -> Array:
	if not WISettings.show_quest_hints():
		var blanked: Array = []
		blanked.resize(hints.size())
		blanked.fill("")
		return blanked
	return hints.duplicate()


## v0.15 A2 — the Leads rows as the player reads them: "· <lead_text> (<place>)"
## over `WIGame.active_leads()`. Same ONE-source rule as `_act_beat_lines`: the
## rendered strip and the `lead_lines` payload key are this list.
func _lead_lines() -> Array:
	var lines: Array = []
	for raw_lead: Variant in _open_leads:
		var lead := raw_lead as Dictionary
		lines.append("· %s (%s)" % [String(lead["lead_text"]), String(lead["place"])])
	return lines


## Issue #209 — TAB 1 (Quests, the default): Act header/beats + Quests +
## Completed + Postings. "What am I doing now." Reads the `_open_*` snapshot
## fields (captured at `_open()`, immutable while the panel is open). Returns
## `{text: String}`.
func _build_quests_tab() -> Dictionary:
	var parts: Array = []
	if not _open_act.is_empty():
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(String(_open_act.get("header", ""))))
		for line: String in _act_beat_lines():
			parts.append(UIChrome.bb_escape(line))
		parts.append("")
	# v0.15 A2: above Quests, and only when non-empty -- the three mainline
	# seams used to land the player on "No quests in progress." with no pointer.
	var lead_lines := _lead_lines()
	if not lead_lines.is_empty():
		parts.append("[b]Leads[/b]")
		for line: String in lead_lines:
			parts.append(UIChrome.bb_escape(line))
		parts.append("")
	parts.append("[b]Quests[/b]")
	if _open_quest_lines.is_empty():
		parts.append("No quests in progress." if not _open_completed_quest_lines.is_empty() else "No quests yet.")
	else:
		for i in _open_quest_lines.size():
			parts.append(UIChrome.bb_escape(String(_open_quest_lines[i])))
			# GH#338: the hint rides as an INDENTED sub-row under its own quest
			# line -- the Postings detail indent, same three spaces, so the two
			# secondary rows in this tab read as one convention.
			var hint := String(_open_quest_hint_lines[i]) if i < _open_quest_hint_lines.size() else ""
			if hint != "":
				parts.append("   [i]%s[/i]" % UIChrome.bb_escape(hint))
	parts.append("")
	if not _open_completed_quest_lines.is_empty():
		parts.append("[b]Completed[/b]")
		for line: Variant in _open_completed_quest_lines:
			parts.append(UIChrome.bb_escape(String(line)))
		parts.append("")
	parts.append("[b]Postings[/b]")
	for line: String in _build_postings_lines(_open_bounty_pool, _open_delivery_pool):
		parts.append(line)
	return {"text": "\n".join(parts)}


## Issue #209 — TAB 2 (Skills, the ONLY interactive tab). GH#336 rebuilt the
## BODY (not the panel): a Classes strip (level + issue #79's aspiration line,
## non-focusable), then the four CATEGORY sections in
## `WIGame.SKILL_CATEGORY_ORDER`, then the Effects glossary. Every Skill appears
## exactly ONCE — the class it came from is a per-row provenance suffix now, so
## the spellsword inherits-closure can no longer draw [Dangersense] three times
## and have one tick flip all three.
##
## Row markers read `Game.sim.hotbar_loadout` directly (journal.gd references
## Game.sim freely, it isn't purity-constrained): "✓ "/"  " on a SLOTTABLE row,
## the category glyph on a passive, all two chars wide. The `cursor_index`'th
## row (in the SAME flattened order `_flatten_skill_ids` produces) is wrapped in
## `[b]...[/b]` with a "▶ " lead glyph. A class row gets " — Lv N" appended
## (`_open_class_levels`, keyed by the SAME display-name string the heading
## already is) — "Innate" never matches, so it stays bare, per the
## OPAQUE-UNTIL-SLEEP rule (class LEVEL is player-visible, unlike raw stats).
## Returns `{text: String, cursor_line: int}` — `cursor_line` is the 0-based
## BBCode line the cursor row landed on (-1 if `cursor_index` matched no row),
## so `_render_active_tab` can `scroll_to_line` it without a drift-prone
## second line-counting pass.
## The honest passive marker. Two chars wide, exactly like "✓ " and "  ", so
## `_clip_body_to_line_boundary`'s single-pitch assumption is untouched and a
## passive row can never be mistaken for an unchecked slottable one.
const PASSIVE_ROW_GLYPH := "· "

## GH#336 ruling 7: the glossary keeps its place at the tab bottom and stops
## calling itself a bare "Effects" list -- it is the reference for statuses this
## run has actually met, one line each.
const EFFECTS_GLOSSARY_TITLE := "Effects you've seen"
const EFFECTS_GLOSSARY_NOTE := "One line each, as they behaved in the fight you met them in."


func _build_skills_tab(cursor_index: int) -> Dictionary:
	var parts: Array = []
	var cursor_line := -1
	parts.append("[b]Skills[/b]")
	parts.append(COMBAT_KIT_NOTE)
	parts.append("Slotted skills appear on your bars.  •  Up/Down to move  •  %s to toggle" % WIInputHints.label("confirm"))
	# GH#171: the checkmarks were unlabeled -- players could not tell
	# selection = hotbar loadout. GH#336 amends it: only ACTIVE rows carry a
	# checkbox at all now, so the sentence has to say which rows those are.
	parts.append("[i]Active skills can ride a bar — confirm on a checkbox row to swap it. Passive skills (%s) are always on.[/i]" % PASSIVE_ROW_GLYPH.strip_edges())
	var flat_i := 0
	for raw_group: Variant in _open_skill_categories:
		var group := raw_group as Dictionary
		parts.append("")
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(String(group["heading"])))
		for raw_skill: Variant in (group["skills"] as Array):
			var skill := raw_skill as Dictionary
			var skill_id := String(skill["id"])
			var row_text: String
			if bool(skill["revealed"]):
				row_text = _revealed_skill_line(skill_id, String(skill["display_name"]), _open_combatants_catalog)
			else:
				# Spec ruling 5: a PRE-REVEAL row still shows name + category +
				# provenance. Category is not progression information, so
				# carrying it costs the reveal convention nothing.
				row_text = String(skill["text"])
			row_text += _row_suffix(skill)
			# Spec ruling 4: the checkbox appears ONLY where it is true. A
			# passive reaches no bar, so it gets the category glyph instead of a
			# box that does nothing when ticked.
			var marker := PASSIVE_ROW_GLYPH
			if bool(skill["slottable"]):
				marker = "✓ " if Game.sim.hotbar_loadout.has(skill_id) else "  "
			var line := marker + UIChrome.bb_escape(row_text)
			if flat_i == cursor_index:
				cursor_line = parts.size()
				line = "[b]▶ %s[/b]" % line
			line = "[url=%d]%s[/url]" % [flat_i, line]
			parts.append(line)
			flat_i += 1
	# GH#336: class provenance demoted from the outer axis to a per-row suffix,
	# but the CLASS facts the tab carried (level, issue #79's aspiration line)
	# are real and keep a home of their own -- BELOW the interactive rows, with
	# the glossary, as non-focusable reference text. Above them it would be
	# strictly worse than the old layout: entering the tab scrolls the cursor
	# row into view, so a tall block over row 0 is a block the player is
	# auto-scrolled PAST and would have to scroll UP to find, against the
	# panel's own "more below" hint.
	if not _open_skill_groups.is_empty():
		parts.append("")
		parts.append("[b]Classes[/b]")
		for raw_group: Variant in _open_skill_groups:
			var class_heading := String((raw_group as Dictionary)["heading"])
			parts.append(UIChrome.bb_escape(_class_heading_text(class_heading, _open_class_levels)))
			if _open_class_aspirations.has(class_heading):
				parts.append("[i]%s[/i]" % UIChrome.bb_escape(String(_open_class_aspirations[class_heading])))
	if not _open_seen_statuses.is_empty():
		parts.append("")
		parts.append("[b]%s[/b]" % EFFECTS_GLOSSARY_TITLE)
		parts.append("[i]%s[/i]" % UIChrome.bb_escape(EFFECTS_GLOSSARY_NOTE))
		for status_id: Variant in _open_seen_statuses:
			parts.append(UIChrome.bb_escape(WIEffectText.status_line(String(status_id), Game.sim.skills.values())))
	return {"text": "\n".join(parts), "cursor_line": cursor_line}


## The per-row tail: where the Skill came from, plus the "both" badge for a
## Skill that is genuinely activatable in BOTH contexts (it renders once, in its
## primary bucket, so the badge is the only place that fact can live).
func _row_suffix(skill: Dictionary) -> String:
	var suffix := ""
	var provenance := String(skill.get("provenance", ""))
	if provenance != "":
		suffix += " — %s" % provenance
	if String(skill.get("bar", "")) == "both":
		suffix += " · both"
	return suffix


## Issue #209 — TAB 3 (History): Lore (found notes) + Chronicle facts + Recent
## Messages. "What happened / what you found." An empty-state line keeps the
## tab from rendering blank on an early run. Returns `{text: String}`.
func _build_history_tab() -> Dictionary:
	var parts: Array = []
	var found_notes := _found_note_ids()
	var lore_notes := _lore_note_lines()
	if not lore_notes.is_empty() or not found_notes.is_empty():
		parts.append("[b]Lore[/b]")
	# v0.15 A3 (GH#304): what the WORLD told you, newest first -- the durable
	# half of a toast that may never have finished rendering. Item lore (the
	# notes actually in the pack) follows below, unchanged.
	for line: String in lore_notes:
		parts.append(UIChrome.bb_escape(line))
	if not found_notes.is_empty():
		if not lore_notes.is_empty():
			parts.append("")
		for note_id: String in found_notes:
			var note_record: Dictionary = Game.sim.item(note_id)
			var note_name := String(note_record.get("name", note_id))
			var note_lore := String(note_record.get("lore", ""))
			if note_lore != "":
				parts.append(UIChrome.bb_escape("%s — %s" % [note_name, note_lore]))
			else:
				parts.append(UIChrome.bb_escape(note_name))
	if parts.size() > 0:
		parts.append("")
	if not _open_chronicle_facts.is_empty():
		parts.append("[b]Chronicle[/b]")
		parts.append(UIChrome.bb_escape("%s — %s" % [String(_open_chronicle_facts.get("name", "Traveler")), String(_open_chronicle_facts.get("race", ""))]))
		var chronicle_classes: Array[String] = []
		for raw_class: Variant in _open_chronicle_facts.get("classes", []):
			var class_facts := raw_class as Dictionary
			chronicle_classes.append("%s Lv%d" % [String(class_facts.get("name", "")), int(class_facts.get("level", 0))])
		parts.append(UIChrome.bb_escape("Classes: %s" % (", ".join(chronicle_classes) if not chronicle_classes.is_empty() else "—")))
		parts.append(UIChrome.bb_escape("Quests completed: %d  •  Victories: %d  •  Sleeps: %d" % [int(_open_chronicle_facts.get("quests_completed", 0)), int(_open_chronicle_facts.get("victories", 0)), int(_open_chronicle_facts.get("sleeps", 0))]))
		parts.append(UIChrome.bb_escape(String(_open_chronicle_facts.get("ending", ""))))
		parts.append("")
	# GH#170: Recent Messages tail. Newest last (reading order).
	var layer_script := load("res://src/ui/message_layer.gd")
	var recent: Array = layer_script.recent_messages if layer_script != null else []
	if not recent.is_empty():
		parts.append("[b]Recent Messages[/b]")
		for msg: Variant in recent:
			parts.append("[i]%s[/i]" % UIChrome.bb_escape(String(msg)))
	if parts.is_empty():
		parts.append("Nothing recorded here yet. Your deeds and the day's news will gather here.")
	return {"text": "\n".join(parts)}


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


## `Game.sim.lore_notes` reversed: capture order in the sim, NEWEST-FIRST for
## reading (the record's whole job is answering "what did that toast say").
func _lore_note_lines() -> Array[String]:
	var out: Array[String] = []
	var notes: Array = Game.sim.lore_notes
	for i: int in range(notes.size() - 1, -1, -1):
		out.append(String(notes[i]))
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
