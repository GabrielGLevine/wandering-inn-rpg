extends CanvasLayer
## Quest journal — lists started-quest progress via `Game.sim.quest_summary()`,
## the ACCEPTED board posting/delivery slip via the "Postings" section (own
## journal section per user ruling — board work never conflates with story
## quests), and known [Skills] grouped by class via `Game.sim.skills_journal()`
## (UI stays out of sim internals — WIGame builds the strings/structure, this
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

## Issue #60 item 1: the Skills section's one-line disclosure that combat
## kit is class+weapon-DERIVED, not player-assigned (there is no loadout
## editor for combat skills -- only field/hotbar assignment, handled by the
## toggle hint right below this one). Threaded into `ui_journal_shown`'s
## payload too (`skills_note` field) so QA can assert the exact copy without
## reading the rendered RichTextLabel.
const COMBAT_KIT_NOTE := "Combat skills follow your classes and weapon."

## Posting-id -> short board title, DUPLICATED from `WIBounties._posting_title`
## (that helper is a private-by-convention static on bounties.gd — this file
## already keeps a zero-cross-dependency per-file copy for the combatants
## catalog below, same reasoning applies here rather than reaching into
## another file's underscore-prefixed helper). KEEP IN LOCKSTEP: a new id
## added to data/bounties.json (and to `WIBounties._posting_title`'s own map)
## needs the SAME entry added here, or this falls back to the generic
## id-derived title while the picker still shows the authored one.
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
## Issue #79: completed-quest HISTORY lines (Game.sim.completed_quest_
## summary()) -- see quest_summary()'s own doc comment for why completed
## quests no longer appear in `_open_quest_lines` at all.
var _open_completed_quest_lines: Array = []
var _open_skill_groups: Array = []
var _open_seen_statuses: Array = []
var _open_combatants_catalog: Array = []
## The FULL bounty/delivery pools (data/bounties.json's "bounties" /
## data/deliveries.json's "deliveries" arrays), loaded ONCE per `_open()` --
## mirrors `_load_combatants_catalog`'s per-file-copy idiom below. Looked up
## by the FULL POOL, never `Game.sim.board_bounties()`/`delivery_board_
## deliveries()`'s 2-3-wide active SLATE: a held posting/slip can rotate OUT
## of the visible slate while still accepted (9 bounties / 5 deliveries,
## slate window only min(3, pool.size())) -- `WIGame.turn_in_bounty`/
## `turn_in_delivery` themselves resolve the held record via `_bounty_by_id`/
## `_delivery_by_id` over the FULL pool for the exact same reason, so this
## mirrors the real turn-in lookup, not the browse-only slate.
var _open_bounty_pool: Array = []
var _open_delivery_pool: Array = []
## Class DISPLAY NAME -> held level, for every class the PC currently holds
## (built once per `_open()` from data/classes.json's catalog + Game.sim.
## classes -- see `_class_levels_by_heading`'s own doc comment). Keyed by
## display name, not id, because `skills_journal()`'s group dicts only carry
## the rendered heading string, never the class id.
var _open_class_levels: Dictionary = {}
## Class DISPLAY NAME -> its authored `aspiration.text` (data/classes.json),
## for every class carrying one (see `_class_aspirations_by_heading`'s own
## doc comment) -- issue #79's "dead aspiration text" surfaced at last. Keyed
## the SAME way `_open_class_levels` is, same reasoning.
var _open_class_aspirations: Dictionary = {}


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
	# Issue #84: `meta_underlined = false` keeps a skill row's `[url=]` wrapper
	# (added in `_build_body_text` below) purely functional -- no automatic
	# underline decoration layered on top of the EXISTING bold+"▶ " marker
	# selection state (one selection state, not a second highlight system).
	# Mouse wheel scroll needs no new code -- RichTextLabel's own `_gui_input`
	# already scrolls `scroll_active` content on WHEEL_UP/DOWN.
	_body_label.meta_underlined = false
	_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_body_label.meta_hover_started.connect(_on_skill_row_hover_started)
	_body_label.meta_clicked.connect(_on_skill_row_meta_clicked)
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
	# Issue #79 (journal history cluster): completed quests move OUT of the
	# active Quests list (quest_summary() above now excludes them) into
	# their own results-only "Completed" section, one line per finished
	# quest with its own chosen-path HISTORY line when the quest's data
	# resolves one (WIQuests.resolution_path_text via completed_quest_
	# summary()'s own doc comment).
	var completed_quest_lines: Array = Game.sim.completed_quest_summary()
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
	var bounty_pool := _load_json_pool("res://data/bounties.json", "bounties")
	var delivery_pool := _load_json_pool("res://data/deliveries.json", "deliveries")
	# Loaded ONCE, fed to both per-class derivations below (levels and the
	# issue #79 aspiration line) -- avoids a second FileAccess+JSON.parse of
	# the same file (the combatants_catalog doc comment above's own
	# reasoning).
	var classes_catalog := _load_json_pool("res://data/classes.json", "classes")
	var class_levels := _class_levels_by_heading(classes_catalog)
	var class_aspirations := _class_aspirations_by_heading(classes_catalog)
	# Cache this open's inputs so a later cursor move or assign/unassign
	# toggle can rebuild the body without re-querying Game.sim (see these
	# fields' own doc comment -- nothing can change the known-skill set
	# while the journal is open).
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
	_flat_skill_ids = _flatten_skill_ids(skill_groups)
	_cursor_index = 0 if not _flat_skill_ids.is_empty() else -1
	var built := _build_body_text(act, quest_lines, completed_quest_lines, skill_groups, seen_statuses, combatants_catalog, _cursor_index, bounty_pool, delivery_pool, class_levels, class_aspirations)
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
	## Parallel to `headings` (same index order) -- issue #79's per-class
	## identity line, "" for a group with none authored (Innate always, plus
	## most classes -- see `_class_aspirations_by_heading`'s doc comment).
	## Lets QA assert the exact aspiration text landed on the right group
	## without OCR, the same structural-proof shape `revealed_effect_lines`
	## below already established for the skill rows.
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
	# QA can assert the panel actually rendered the grouped-by-class
	# structure and the first-use reveal state, not just that the (opaque,
	# empty) event fired. Also carries the act-line data (current act id +
	# achieved-beat count) so arc_flow/journal QA can gate act progression.
	var act_beats: Array = act.get("beats", [])
	var act_beats_achieved := 0
	for raw_beat: Variant in act_beats:
		if bool((raw_beat as Dictionary).get("achieved", false)):
			act_beats_achieved += 1
	# The Postings section's own confirmation fields, riding this SAME event
	# (the established idiom -- the skills panel confirms through fields on
	# ui_journal_shown too, not a second event; see `revealed_skills`/
	# `act_id` above). Empty string/0 when nothing is accepted -- QA asserts
	# presence via the non-empty title, never a "none" sentinel.
	var posting := _posting_slot_state(bounty_pool, Game.sim.accepted_bounty_id, Game.sim.accepted_bounty_baseline, Callable(self, "_posting_title"), "copy")
	var delivery := _posting_slot_state(delivery_pool, Game.sim.accepted_delivery_id, Game.sim.accepted_delivery_baseline, Callable(self, "_delivery_title"), "slip_copy")
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_SHOWN, {
		"quest_lines": quest_lines.size(),
		# Issue #79: the Completed section's own structural proof -- the FULL
		# lines (not just a count), since each already carries the
		# chosen-path text QA needs to assert without OCR.
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


func _close() -> void:
	open = false
	_root.hide()
	if _scroll_hint != null:
		_scroll_hint.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_JOURNAL_HIDDEN, {})


## Field chip tap (issue #109): the SAME open/close/`_can_open()` gate the
## `journal` action key's own branch runs above -- exposed as a public entry
## point so `field_chips.gd`'s journal chip can invoke it without a parallel
## activation path. No-op (returns false, no state change) if the panel is
## closed and `_can_open()` refuses, mirroring the keyboard branch's own
## early return.
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


## `heading` with " — Lv N" appended when `class_levels` carries an entry for
## it, else `heading` unchanged (the "Innate" group never has an entry --
## see `_class_levels_by_heading`'s doc comment). Single source for the
## suffix so the `ui_journal_shown` event's `skill_groups` field and the
## rendered panel body can never drift from each other.
func _class_heading_text(heading: String, class_levels: Dictionary) -> String:
	if class_levels.has(heading):
		return "%s — Lv %d" % [heading, int(class_levels[heading])]
	return heading


## Class DISPLAY NAME -> held level, for every class id `Game.sim.classes`
## currently holds. `catalog` is data/classes.json's "classes" array (loaded
## via `_load_json_pool`, this file's existing per-file-copy idiom -- same
## reasoning as `_load_combatants_catalog`'s own doc comment: zero cross-
## dependency into wi_game.gd's private catalog fields). Keyed by display
## name rather than id because `skills_journal()`'s group dicts only ever
## carry the RENDERED heading string (`cls.get(WIKeys.DISPLAY_NAME, id)`),
## never the id itself -- display names are unique across the shipped
## catalog today (verified: 13 classes, 13 distinct display_name values), so
## this round-trips cleanly; a future class sharing another's display_name
## would collide here and needs its own disambiguation, not silently reached
## from this function.
func _class_levels_by_heading(catalog: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw_cls: Variant in catalog:
		var cls := raw_cls as Dictionary
		var id := String(cls.get(WIKeys.ID, ""))
		if id != "" and Game.sim.classes.has(id):
			out[String(cls.get(WIKeys.DISPLAY_NAME, id))] = int(Game.sim.classes[id])
	return out


## Class DISPLAY NAME -> its authored `aspiration.text` (data/classes.json),
## for every class id `Game.sim.classes` currently holds AND that carries an
## `aspiration` block. Issue #79 gap-analysis: "authored class 'aspiration'
## text is dead content" -- every class's own far-future-title flavor line
## (e.g. Swordsman's "Far down this road waits the title of [Swordmaster]
## ...") was authored in data/classes.json but never read by ANY code path.
## Not every shipped class carries one (warrior/spearmaster/spellsword/
## helper/barmaid/server/diplomat/rogue/archer have none) -- `.has()`-gated
## the same way `_class_levels_by_heading` skips a class with no entry,
## degrading to no line rather than a "None yet" filler (this file's own
## Effects/Postings-section precedent). Same keying rationale (display name,
## not id) as `_class_levels_by_heading`'s own doc comment.
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


## Issue #84: hover moves `_cursor_index` to the hovered skill row (the SAME
## field the keyboard Up/Down cursor drives, rendered via the bold+"▶ "
## marker `_build_body_text` already composes -- one selection state) without
## scrolling the panel (the hovered row is already on-screen; unlike keyboard
## nav, which scrolls the NEW cursor row into view, a hover shouldn't yank the
## view around under a stationary mouse). `meta` is the `[url=]` value
## `_build_body_text` wrote -- always a plain int string, but read via
## `String(meta).to_int()` defensively rather than assuming RichTextLabel
## hands back an int Variant.
func _on_skill_row_hover_started(meta: Variant) -> void:
	var idx := String(meta).to_int()
	if idx < 0 or idx >= _flat_skill_ids.size() or idx == _cursor_index:
		return
	_cursor_index = idx
	_rebuild_body_no_scroll()


## Issue #84: a click on a skill row moves the cursor there (if it hadn't
## already, e.g. a click with no prior hover motion event) then calls
## `_toggle_cursor_skill()` -- the EXACT function Enter calls on the cursored
## row, so a click is indistinguishable in its effects from arrow-to-row +
## Enter (one-dispatch-path discipline).
func _on_skill_row_meta_clicked(meta: Variant) -> void:
	var idx := String(meta).to_int()
	if idx < 0 or idx >= _flat_skill_ids.size():
		return
	_cursor_index = idx
	_toggle_cursor_skill()


## QA-only entry point (issue #84 QA-teeth, `click_journal_skill` DSL step):
## fires the EXACT SAME dispatch a real click on skill row `flat_i`'s
## rendered glyphs would (`_on_skill_row_meta_clicked` above). RichTextLabel's
## BBCode `[url=]` meta spans expose no public per-region screen rect (unlike
## the per-row Control lists `pause_menu.gd`'s `row_rect`/`dialogue_panel.gd`'s
## `option_rect`/`inventory.gd`'s `item_row_rect` resolve against for their
## own click_* steps), so this targets by the SAME logical flat-index
## `_flat_skill_ids`/`_cursor_index` already use rather than raw pixel
## coordinates -- mirrors `test_driver.gd`'s pre-existing `press_field_skill`
## precedent ("target by logical identity" when an on-screen position isn't
## reliably queryable).
func click_skill_row(flat_i: int) -> void:
	_on_skill_row_meta_clicked(str(flat_i))


## Same rebuild `_rebuild_body_follow_cursor` performs, minus the
## scroll-to-cursor-line/scroll-hint follow-up -- see
## `_on_skill_row_hover_started`'s doc comment for why hover must NOT scroll.
func _rebuild_body_no_scroll() -> void:
	var built := _build_body_text(_open_act, _open_quest_lines, _open_completed_quest_lines, _open_skill_groups, _open_seen_statuses, _open_combatants_catalog, _cursor_index, _open_bounty_pool, _open_delivery_pool, _open_class_levels, _open_class_aspirations)
	_body_label.text = String(built["text"])


## Rebuilds the body from this open session's cached inputs (see
## `_open_act`/etc.'s doc comment) at the CURRENT cursor position, and scrolls
## the cursor's row into view -- used by both cursor movement and the toggle
## (unlike `_open()`, which deliberately resets to the panel's top instead).
func _rebuild_body_follow_cursor() -> void:
	var built := _build_body_text(_open_act, _open_quest_lines, _open_completed_quest_lines, _open_skill_groups, _open_seen_statuses, _open_combatants_catalog, _cursor_index, _open_bounty_pool, _open_delivery_pool, _open_class_levels, _open_class_aspirations)
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


## Builds the BBCode body text: a "Quests" section (ACTIVE quests only as of
## issue #79 -- `quest_summary()`'s own doc comment), then "Completed"
## (issue #79's own new HISTORY section -- one line per finished quest with
## its chosen-path text, `Game.sim.completed_quest_summary()`; OMITTED
## ENTIRELY when empty, the Effects section's own "no filler" precedent, so
## a save with no completed quest yet renders byte-identical to before this
## task), then "Postings" (the accepted board posting/delivery slip -- see
## `_build_postings_lines`'s doc comment; ordered right after Completed
## since it's the same "things I've taken on/finished" reading, but its own
## heading per the DP2 board/quest split ruling: board work never gets a
## journal entry folded into the quest log), then a "Skills" section, one
## sub-heading per `skills_journal()` group ("Innate" first, then held
## classes). A class heading is immediately followed by its issue #79
## aspiration line (`class_aspirations`, the SAME display-name keying as
## `class_levels` -- see `_class_aspirations_by_heading`'s doc comment),
## omitted for a class with none authored. Pre-reveal a
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
func _build_body_text(act: Dictionary, quest_lines: Array, completed_quest_lines: Array, skill_groups: Array, seen_statuses: Array, combatants_catalog: Array = [], cursor_index: int = -1, bounty_pool: Array = [], delivery_pool: Array = [], class_levels: Dictionary = {}, class_aspirations: Dictionary = {}) -> Dictionary:
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
		# "No quests in progress." once history exists (a completed quest
		# means the player HAS had quests -- "No quests yet." would misread
		# as never-started, exactly the cluster's own "history vanishes"
		# complaint) -- else the original fresh-game line, byte-identical.
		parts.append("No quests in progress." if not completed_quest_lines.is_empty() else "No quests yet.")
	else:
		for line: Variant in quest_lines:
			parts.append(UIChrome.bb_escape(String(line)))
	parts.append("")
	# Completed section (issue #79 journal history cluster): one line per
	# finished quest with its own chosen-path HISTORY line (results-only --
	# what already happened, never how-close-to-finishing). OMITTED ENTIRELY
	# when empty, the Effects section's own "no filler" precedent.
	if not completed_quest_lines.is_empty():
		parts.append("[b]Completed[/b]")
		for line: Variant in completed_quest_lines:
			parts.append(UIChrome.bb_escape(String(line)))
		parts.append("")
	# Postings section (own section per user ruling -- board work never
	# conflates with story quests): the accepted board posting + delivery
	# slip, each "<title> — <status> (<gold> gold)". OPAQUE-UNTIL-DONE: status
	# is the binary "In hand."/"Ready to turn in." line, never a progress
	# count. Omitted sub-lines entirely when nothing is held (the Effects
	# section's own "no filler" precedent) -- a single flavor line instead. A
	# failed/returned delivery needs no special case here: `sleep()` already
	# clears `accepted_delivery_id` back to "" on a run failure, so this
	# section falls straight back to empty/absent for it, same as any other
	# cleared slip -- the board's own barks carry that fiction.
	parts.append("[b]Postings[/b]")
	var posting_lines := _build_postings_lines(bounty_pool, delivery_pool)
	for line: String in posting_lines:
		parts.append(line)
	parts.append("")
	parts.append("[b]Skills[/b]")
	parts.append(COMBAT_KIT_NOTE)
	# The assignment surface's one-line disclosure, matching the established
	# hint-copy grammar (char_creation.gd's "Up/Down to choose  •  Enter to
	# confirm  •  Esc to go back"). Composed through WIInputHints (kb-mode
	# byte-identical to the old literal -- no QA pin exists on this line,
	# but the discipline still applies).
	parts.append("Slotted skills appear on your bars.  •  Up/Down to move  •  %s to toggle" % WIInputHints.label("confirm"))
	var flat_i := 0
	for raw_group: Variant in skill_groups:
		var group := raw_group as Dictionary
		var heading := String(group["heading"])
		parts.append("")
		parts.append("[b]%s[/b]" % UIChrome.bb_escape(_class_heading_text(heading, class_levels)))
		# Issue #79: the per-class identity line (the authored, previously-
		# dead `aspiration.text`) -- a class carrying none (most of the
		# roster) renders no extra line, byte-identical to before this task.
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
			# Issue #84: wraps the WHOLE row (marker + bold/▶ when selected)
			# in a `[url=<flat_i>]` meta region -- RichTextLabel's native
			# hover/click detection for BBCode meta spans, so a hover/click
			# needs no manual rect math over this single free-flowing text
			# blob (contrast the per-row Control rects the OTHER four panels
			# use). `flat_i` is the SAME index `_cursor_index`/
			# `_flat_skill_ids` already use -- one index space, no translation.
			line = "[url=%d]%s[/url]" % [flat_i, line]
			parts.append(line)
			flat_i += 1
	if not seen_statuses.is_empty():
		parts.append("")
		parts.append("[b]Effects[/b]")
		for status_id: Variant in seen_statuses:
			parts.append(UIChrome.bb_escape(WIEffectText.status_line(String(status_id), Game.sim.skills.values())))
	# Issue #81 (exploration & optional content): the found-note collectible
	# thread's own section, OMITTED ENTIRELY when nothing is held yet -- the
	# Effects section's own "no filler" precedent, not a "None yet" row. One
	# line per held note, "<name> — <the note's own written text>" (the
	# `lore` field carries the found text itself for this item kind; see
	# items.json's note_* entries).
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
	return {"text": "\n".join(parts), "cursor_line": cursor_line}


## Builds the "Postings" section's rendered lines: one line per accepted
## board posting/delivery slip, "<title> — <status> (<gold> gold)", followed
## by a SECOND, indented line carrying the posting's own authored detail
## text (issue #79: "accepted posting/slip text unrecoverable" -- once a
## posting rotates out of the board's 2-3-wide browsable slate it was
## PREVIOUSLY only ever readable at accept time; the journal now carries it
## for as long as the posting stays accepted). That detail text is the
## SAME `copy`/`slip_copy` string `WIBounties.build_picker_graph`/
## `build_delivery_picker_graph` already render into the board's own
## dialogue-panel body (test_copy_fit.gd's `_check_bounty_delivery_copy`
## already budgets it for that surface) -- reused verbatim, never
## re-authored, so this can't drift from what the board itself said; the
## journal body is its own copy_fit-EXEMPT surface (autowrap + scroll, this
## file's own doc-comment precedent), so no new budget check is needed for
## re-using an already-budgeted string on a MORE permissive panel. Neither
## accepted -> a single flavor line, no sub-items (the Effects section's own
## "omit entirely, no filler" precedent, not a "None yet" row). Never emits a
## progress count -- `_posting_slot_state`'s `status` field is the ONLY
## per-posting status text, and it's always one of exactly two literals.
func _build_postings_lines(bounty_pool: Array, delivery_pool: Array) -> Array[String]:
	var lines: Array[String] = []
	var posting := _posting_slot_state(bounty_pool, Game.sim.accepted_bounty_id, Game.sim.accepted_bounty_baseline, Callable(self, "_posting_title"), "copy")
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


## Returns `{title, status, gold, detail}` for the currently-accepted
## posting/slip in `pool` (found over the FULL pool -- see `_open_bounty_
## pool`'s doc comment), or `{}` when nothing is accepted / the id doesn't
## resolve (defensive; can't happen from real accept/turn-in flow).
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
func _posting_slot_state(pool: Array, accepted_id: String, baseline: Dictionary, title_fn: Callable, detail_key: String) -> Dictionary:
	if accepted_id == "":
		return {}
	var record := _pool_record(pool, accepted_id)
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


## Posting-id -> title via `_POSTING_TITLES` (`WIBounties._posting_title`'s
## duplicated map, see its own doc comment), falling back to the SAME
## id-derived title bounties.gd's original uses for an unmapped id.
func _posting_title(id: String) -> String:
	return String(_POSTING_TITLES.get(id, id.trim_prefix("bounty_").capitalize()))


## `_posting_title`'s exact delivery twin, over `_DELIVERY_TITLES`.
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


## Finds the record with `id` in `pool` (a bounties.json/deliveries.json
## array) -- the FULL-pool lookup `_open_bounty_pool`'s doc comment explains.
## Returns `{}` if not found (defensive; can't happen for a real accepted id).
func _pool_record(pool: Array, id: String) -> Dictionary:
	for raw: Variant in pool:
		var record := raw as Dictionary
		if String(record.get("id", "")) == id:
			return record
	return {}


## Loads a `{"<key>": [...]}`-shaped data file's array straight off disk --
## mirrors `_load_combatants_catalog`'s own FileAccess+JSON.parse idiom
## (kept as its own small helper rather than generalizing that one, to leave
## its existing call site/behavior untouched). A missing/unparseable file
## degrades to `[]`, same as every caller here already treats "no override".
func _load_json_pool(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).has(key):
		return (parsed as Dictionary)[key]
	return []


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
