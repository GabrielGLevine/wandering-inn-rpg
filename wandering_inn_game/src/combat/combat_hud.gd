class_name WICombatHud
extends RefCounted
## The combat HUD region, extracted from combat_screen.gd --
## the order/readout/feed/banner panels + hotbar built once in the old
## `_ready()`, the hotbar slot list + live affordability/cost rendering, the
## "what does this button do" info line, the prose feed (wrapped-line
## budgeting contract), and the tutor-line matcher/renderer. Owns the
## Control nodes it builds; `_mode`/`_bar_slots`/`_bar_index`/
## `_info_slot_index` all STAY on combat_screen.gd (mode-FSM + bar-data
## ownership, per the plan) -- this file only ever RENDERS from state handed
## to it each call, never reaches back into the screen for sim state.

const FEED_TEXT_WIDTH := 248.0

const READOUT_TEXT_WIDTH := 576.0
const READOUT_TEXT_HEIGHT := 64.0
const HOTBAR_SCRIPT := preload("res://src/ui/hotbar.gd")
## Issue #106: the tap-confirm chip's fixed rect (TOP_RIGHT anchor,
## `UIChrome.set_offsets` order left/top/right/bottom relative to that
## corner) -- x spans [1100,1260] at native 1280 width, comfortably clear of
## the arena board's own worst-case footprint (12x8 grid * 16px CELL * 4x
## WORLD_SCALE = 768px wide, camera-centered in the 1280-wide viewport ->
## board x in [256,1024]) so the chip can NEVER shadow a board cell the
## player might otherwise tap, at any camera framing. Deliberately NOT placed
## near the readout/hotbar bands (both BOTTOM_* and both click-transparent,
## `MOUSE_FILTER_IGNORE`, over the board's own lower rows -- see
## `combat_screen.gd`'s `handle_board_click` doc comment) -- this widget MUST
## be the one thing that reliably intercepts a tap regardless of board
## framing, so it lives in dead space instead. One measured exception: the
## chip's y[56,96] overlaps the order strip PANEL's y[10,66] band by ~10px --
## accepted, the overlap lands on the strip's empty lower-right parchment
## corner (its text is biased UP via the margin_bottom override in build()),
## the chip is added after the strip so it draws on top, no text covered.
const CONFIRM_CHIP_SIZE := Vector2(160.0, 40.0)
const CONFIRM_CHIP_OFFSETS := Vector4(-180.0, 56.0, -20.0, 96.0)
## Default keycap glyphs for the readout
## hint strip, byte-identical to the old hardcoded literals. This file
## carries ZERO bare autoload identifiers by contract (`tests/
## test_combat_visuals.gd` asserts it compiles standalone) -- the REAL
## device-correct glyphs come from `WIInputHints.label()` at the composition
## root (combat_screen.gd), which passes them into `refresh()`'s `hints`
## param. These defaults are the fallback when a caller doesn't pass one
## (keeps this file callable/testable with zero autoload wiring).
const DEFAULT_HINTS := {
	"confirm": "Enter", "cancel": "Esc", "cycle": "Tab", "move": "Arrows",
	"hotbar": "number keys", "end_turn": "E",
}
## Every `on.event` a `tutor_lines`
## entry is allowed to target, because a render call site actually exists for
## it. `reset_tutor_lines` cross-checks fresh data against this list and
## `push_warning`s loudly for anything outside it (zero-warning rule: bad
## tutor data must be loud, not a silent swallow).
const TUTOR_SUPPORTED_EVENTS := [
	WIEvents.COMBAT_STARTED, WIEvents.TURN_STARTED, WIEvents.TURN_ENDED,
	WIEvents.COMBAT_FINISHED, WIEvents.COMBATANT_MOVED, WIEvents.AP_CHANGED,
	WIEvents.COMBATANT_DOWNED, WIEvents.ATTACK_RESOLVED, WIEvents.SKILL_RESOLVED,
	WIEvents.REACTION_TRIGGERED, WIEvents.DASHED, WIEvents.STATUS_APPLIED,
	WIEvents.STATUS_EXPIRED, WIEvents.ACTION_REFUSED, WIEvents.UI_TARGETING_SHOWN,
]

## png, shared with message_layer.gd's toast/dialogue-bark panels). TRAP:
## at the default STRIP_PATCH_MARGIN (20), only 9 of the fold art's 29
## source px sit in the 9-patch's UNSTRETCHED bottom band -- the rest live
## in the STRETCHED center band, so on a panel that grows
## (`_grow_feed_panel_for_tutor`/`_resize_feed_panel`) the fold stretches
## and moves WITH the height (message_layer.gd's STRIP_FOLD_PATCH_BOTTOM
## doc comment has the full measurement/mechanism), and any proportional
## fold-position estimate chases that moving target -- a long beat's last
## line can still ride the fold. `build()` pins this panel's NinePatchRect
## `patch_margin_bottom` to this value (same as message_layer.gd's
## STRIP_FOLD_PATCH_BOTTOM: same texture, same measured 29px source fold
## depth, 32 covers it with slack) so the fold lives ENTIRELY in the
## unstretched bottom patch and its position is a TRUE PIXEL CONSTANT
## (FEED_FOLD_DANGER_PX) at any panel height. Both the base capacity
## (`_feed_text_capacity_height`) and the tutor-grow formula
## (`_grow_feed_panel_for_tutor`) derive from this fixed-pixel model -- the
## toast panel's `_toast_panel_height_for` idiom, with a SINGLE deficit
## (this label is TOP-aligned, not centered like the toast's, so only the
## bottom needs budgeting, not doubled).
const FEED_STRIP_FOLD_PATCH_BOTTOM := 32
const FEED_FOLD_DANGER_PX := 30.0
const FEED_CONTENT_MARGIN_TOP := 8.0
const TUTOR_SAFETY_BUFFER_PX := 12.0
const FEED_PANEL_BASE_SIZE := Vector2(292.0, 122.0)
const FEED_OFFSET_LEFT := 28.0
const FEED_OFFSET_RIGHT := 320.0
const FEED_OFFSET_BOTTOM := -84.0
## Hard cap so a pathological future tutor-lines edit can't grow the panel
## into the order strip/board above -- board headroom is generous (see
## build()'s band comment), but a bound keeps this fix from ever becoming
## unbounded. Comfortably fits the longest wrapped-line count seen in
## data/arenas.json today (4 lines) with room to spare for a 5th.
const FEED_PANEL_MAX_HEIGHT := 220.0

signal confirm_tapped

var _root: Control
var _main_ref: Node
var _screen: Node

var _readout_label: RichTextLabel
var _order_label: Label
var _feed_label: Label
## a3 #215: the banner is a centered Control that CONSUMES clicks — a board
## tap under it never reaches main's router, so the tap-dismiss rides the
## banner itself (the natural mobile gesture: tap the Victory ribbon).
signal banner_tapped

var _banner_label: Label
var _readout_panel: Control
var _banner_panel: Control
var _hotbar: WIHotbar
## GH#337: the live fight, handed in by `combat_screen.gd`'s `set_combat` so the
## bar can read THE cooldown predicate rather than keep a second copy of the
## rule. Null outside a fight and under bare-`new()` unit construction.
var _combat: WICombat
var _confirm_chip: Control
var _confirm_armed := false
var _feed: Array = []
var _feed_panel_height := FEED_PANEL_BASE_SIZE.y
var _last_slot_info_index := -999
var _last_slot_info_text := ""
var _tutor_lines: Array = []
var _tutor_fired: Dictionary = {}
var _tutor_match_counts: Dictionary = {}


func _init(root: Control, main_ref: Node, screen: Node) -> void:
	_root = root
	_main_ref = main_ref
	_screen = screen


## Builds the persistent HUD panels (order strip / feed / readout / banner /
## hotbar) under `_root`, in the EXACT original add_child order (order, feed,
## readout, banner, hotbar) to preserve paint order -- verbatim move of the
## UI-build block from combat_screen.gd's old `_ready()`.
func build() -> void:
	# Combat HUD bands (keep these DISJOINT; both
	# parchment panels are opaque, so any overlap hides one under the other):
	#   order strip   CENTER_TOP     x[32,1248]  y[10,66]
	#   feed          BOTTOM_LEFT    x[28,320]   y[514,636]  (left column)
	#   readout       CENTER_BOTTOM  x[330,950]  y[530,642]  (grown upward, M6
	#                 slot-info line -- see _readout_text/_slot_info_line;
	#                 nothing else occupies this x-range above y[636])
	#   hotbar        CENTER_BOTTOM  y[658,710]  (see hotbar.gd BOTTOM_MARGIN)
	#   confirm chip  TOP_RIGHT      x[1100,1260] y[56,96] -- the ONE sanctioned
	#                 band overlap (~10px into the strip's empty lower-right
	#                 parchment corner; chip added last, draws on top, no text
	#                 covered -- see CONFIRM_CHIP_OFFSETS' doc comment)
	# PF VISUAL-LOG drain (turn-banner top graze): the old 42px height was too
	# short for PARCHMENT_STRIP's 20px-margin 9-slice -- the strip art filled
	# only a ~18px band in the panel's upper portion (the transparent-margin
	# trap, CLAUDE.md UIChrome notes), so the turn text's lower half hung below
	# the visible parchment onto the dark board and its top grazed the window
	# edge. Grown to 56px (the proven dialogue/readout fill height) so the strip
	# renders full-height, plus vertical-centering below -- the text now sits
	# inside the parchment's art-safe band. Still the top-most band; the disjoint
	# combat HUD bands below (all BOTTOM_*) are untouched.
	_order_label = _make_panel_label(
		UIChrome.PARCHMENT_STRIP, Control.PRESET_CENTER_TOP,
		Vector2(1216.0, 56.0), Vector4(-608.0, 10.0, 608.0, 66.0), true
	)
	_order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(_order_label.get_parent() as MarginContainer).add_theme_constant_override("margin_bottom", 24)
	_feed_label = _make_panel_label(
		UIChrome.PARCHMENT_STRIP, Control.PRESET_BOTTOM_LEFT,
		Vector2(292.0, 122.0), Vector4(28.0, -206.0, 320.0, -84.0), false, "Small"
	)
	# COMBAT/FEED-FOLD (P2), v0.15 A4 — THE FIX. The budget model in
	# `_feed_text_capacity_height` was always right; the LABEL silently
	# disagreed with it. That doc comment asserts this label is TOP-aligned ("a
	# single measured deficit, unlike the vertically-centered toast label which
	# budgets it twice") -- but the label was CENTRED in its MarginContainer, so
	# the deficit was doubled and the block grew into the fold from the middle
	# instead of down from the top. TWO defaults conspired: `UIChrome.make_label`
	# leaves `vertical_alignment` at CENTER, and the label's `size_flags_vertical`
	# is SHRINK_CENTER, which is the one that actually bit -- the label rect was
	# its CONTENT height (77px for four rows), parked in the middle of the 106px
	# inner area, so text alignment had nothing to align inside.
	#
	# Measured headless at the 122px base panel (17px rows, 3px line_spacing,
	# 20px pitch, fold band measured on-screen at y=607..636 of the 514..636
	# panel): centred put the four-row block at y=536..613, five px INTO the
	# fold; on `riverfarm_fight/02` that sliced "for 13!" exactly as the ledger
	# recorded. FILL + TOP puts the same block at y=522..599, clear by 8px. Three
	# rows always fit either way, which is why the repro read as "three full rows
	# and a sliced fourth" and why wrapping was irrelevant to it.
	_feed_label.size_flags_vertical = Control.SIZE_FILL
	_feed_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	(_feed_label.get_parent().get_parent().get_child(0) as NinePatchRect).patch_margin_bottom = FEED_STRIP_FOLD_PATCH_BOTTOM
	_readout_panel = _make_panel(UIChrome.PARCHMENT_STRIP, Control.PRESET_CENTER_BOTTOM, Vector2(620.0, 104.0), Vector4(-310.0, -190.0, 310.0, -78.0))
	_readout_label = UIChrome.make_rich_label("CombatReadout")
	var readout_margin := MarginContainer.new()
	UIChrome.full_rect(readout_margin)
	UIChrome.add_margins(readout_margin, 22, 9, 22, 9)
	_readout_panel.add_child(readout_margin)
	readout_margin.add_child(_readout_label)
	_root.add_child(_readout_panel)
	_banner_panel = _make_panel(UIChrome.BLUE_RIBBON, Control.PRESET_CENTER, Vector2(360.0, 76.0), Vector4(-180.0, -38.0, 180.0, 38.0))
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner_panel.gui_input.connect(_on_banner_gui_input)
	_banner_label = UIChrome.make_label("", "Header")
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var banner_margin := MarginContainer.new()
	UIChrome.full_rect(banner_margin)
	UIChrome.add_margins(banner_margin, 34, 14, 34, 14)
	_banner_panel.add_child(banner_margin)
	banner_margin.add_child(_banner_label)
	_root.add_child(_banner_panel)
	_hotbar = HOTBAR_SCRIPT.new()
	_hotbar.name = "Hotbar"
	_root.add_child(_hotbar)
	# Issue #106: the tap-confirm chip. `make_texture_panel` defaults every
	# panel to `MOUSE_FILTER_IGNORE` (click-transparent, the readout/feed/
	# banner/order convention) -- this ONE panel is deliberately flipped to
	# STOP right after construction, since catching the tap IS its whole job
	# (see CONFIRM_CHIP_OFFSETS' doc comment for why it lives in dead space
	# rather than reusing the readout panel's own real estate). Hidden by
	# default; `refresh()` toggles visibility with `_confirm_armed`.
	_confirm_chip = UIChrome.make_texture_panel(UIChrome.BLUE_BUTTON)
	_confirm_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_confirm_chip.custom_minimum_size = CONFIRM_CHIP_SIZE
	_confirm_chip.size = CONFIRM_CHIP_SIZE
	UIChrome.set_offsets(_confirm_chip, CONFIRM_CHIP_OFFSETS.x, CONFIRM_CHIP_OFFSETS.y, CONFIRM_CHIP_OFFSETS.z, CONFIRM_CHIP_OFFSETS.w)
	_confirm_chip.gui_input.connect(_on_confirm_chip_gui_input)
	_confirm_chip.hide()
	var chip_label := UIChrome.make_label("Confirm", "Small")
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_chip.add_child(chip_label)
	_root.add_child(_confirm_chip)


func hotbar_node() -> WIHotbar:
	return _hotbar


func _on_confirm_chip_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if not _confirm_armed:
		return
	confirm_tapped.emit()


## Read-only accessor (issue #106, the `hotbar_node`/`card_rect` idiom): the
## chip's real on-screen rect for `qa/test_driver.gd`'s `click_confirm_chip`
## step -- empty `Rect2` while not armed/visible (`_inject_mouse_click` on an
## empty rect's center would land at the viewport origin and hit nothing,
## same fail-loud-via-`_fail` contract every other `click_*` step already
## follows when its target rect is empty).
func confirm_chip_rect() -> Rect2:
	if _confirm_chip == null or not _confirm_chip.visible:
		return Rect2()
	return Rect2(_confirm_chip.global_position, _confirm_chip.size)


func _make_panel(texture: Texture2D, preset: int, min_size: Vector2, offsets: Vector4) -> Control:
	var panel := UIChrome.make_texture_panel(texture)
	panel.set_anchors_preset(preset)
	panel.custom_minimum_size = min_size
	panel.size = min_size
	UIChrome.set_offsets(panel, offsets.x, offsets.y, offsets.z, offsets.w)
	return panel


func _make_panel_label(
		texture: Texture2D, preset: int, min_size: Vector2, offsets: Vector4,
		centered: bool, type_variation: String = ""
) -> Label:
	var panel := _make_panel(texture, preset, min_size, offsets)
	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 22, 8, 22, 8)
	panel.add_child(margin)
	var label := UIChrome.make_label("", type_variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)
	_root.add_child(panel)
	return label


## Renders every HUD panel from state handed in this call -- `view` for live
## sim reads, `bar_active` (HOTBAR/ATTACK/SKILL_TARGET) gates the
## readout+hotbar block, `in_targeting` (ATTACK/SKILL_TARGET only)
## distinguishes the aiming-hint text from the HOTBAR resting-state hint,
## `is_banner` gates the victory/defeat panel, `targeting_state` is
## `WICombatTargeting.state()` (plus a `line_text` key the screen stashes on
## top when `line_mode` is true), `bar_slots`/`bar_index`/`info_slot_index`
## are the screen-owned hotbar data. Order-strip/feed/banner update
## unconditionally; readout+hotbar only while `bar_active` -- matches the
## original `_refresh()`'s split exactly. `ai_skip_hint` (issue #87) is its
## own third readout state, alongside `bar_active`/`dash_confirm` -- see
## `_ai_skip_hint_text`'s own doc comment.
func refresh(view: RefCounted, bar_active: bool, in_targeting: bool, is_banner: bool,
		targeting_state: Dictionary, bar_slots: Array, bar_index: int, info_slot_index: int,
		dash_confirm: bool = false, hints: Dictionary = DEFAULT_HINTS, ai_skip_hint: bool = false) -> void:
	var order_bits: Array = []
	for id: String in view.order():
		var mark := "> " if id == view.active_id() else ""
		if view.alive(id):
			order_bits.append(mark + view.display_name(id))
	_order_label.text = "Turn — " + "  |  ".join(order_bits)
	_feed_label.text = "\n".join(_feed)
	_feed_label.get_parent().get_parent().visible = not _feed.is_empty()
	_banner_panel.visible = is_banner
	_readout_panel.visible = bar_active or ai_skip_hint
	_hotbar.visible = bar_active
	if bar_active:
		var rendered_slots := render_bar_slots(view, bar_slots)
		_readout_label.text = _readout_text(view, in_targeting, targeting_state, rendered_slots, info_slot_index, dash_confirm, hints)
		_hotbar.render(rendered_slots, bar_index)
	elif ai_skip_hint:
		_readout_label.text = _ai_skip_hint_text(hints)
	_confirm_armed = dash_confirm or (in_targeting and (bool(targeting_state.get("line_mode", false)) or not (targeting_state.get("targets", []) as Array).is_empty()))
	_confirm_chip.visible = bar_active and _confirm_armed


## Builds the ordered slot list for the hotbar -- Attack, Dash, then
## `actor_id`'s combat skills with an AP cost (skills.json order), then End
## Turn. Rebuilt fresh every time a player turn starts (`combat_screen.gd`'s
## `_apply_turn_started`, which stores the result in its own `_bar_slots`).
func rebuild_slots(view: RefCounted, actor_id: String, loadout: Array = [], usable_items: Array = []) -> Array:
	var c: Dictionary = view.combatant(actor_id)
	var slots: Array = [
		{"type": "attack", "label": "Attack", "icon": "icon_attack", "key_hint": "1"},
		{"type": "dash", "label": "Dash", "icon": "icon_dash", "key_hint": "2"},
	]
	var kit_ids: Array = []
	for sk_id: String in c["skills"]:
		var sk: Dictionary = view.skill(sk_id)
		if (sk.get("contexts", []) as Array).has("combat") and int(sk.get("ap_cost", 0)) > 0:
			kit_ids.append(sk_id)
	var skill_loadout: Array = []
	for raw: Variant in loadout:
		if not String(raw).begins_with("item:"):
			skill_loadout.append(raw)
	var number := 3
	for sk_id: String in WIGame.apply_loadout(kit_ids, skill_loadout):
		var sk: Dictionary = view.skill(sk_id)
		slots.append({
			"type": "skill", "id": sk_id, "label": String(sk.get("display_name", sk_id)),
			"icon": String(sk.get("icon", "")), "key_hint": str(number),
			"description": String(sk.get("description", "")),
			"effect": sk.get("effect", {}),
			# GH#334 ruling 14: the slot record was NARROWER than the formatter
			# it feeds. `WIEffectText.skill_effect_lines` generates the "Once per
			# fight." clause from this key, and it was simply never carried here
			# -- so the one restriction a player most needs before spending a
			# turn on the skill was the one clause the tooltip could not say.
			"once_per_fight": bool(sk.get("once_per_fight", false)),
			# GH#337: the STATIC rule ("Once every 2 rounds."), the exact same
			# widen-the-record-with-the-formatter discipline the comment above
			# describes. Its LIVE sibling `cooldown_remaining` is stamped on in
			# `render_bar_slots` instead, because it changes every round while
			# this list is rebuilt only at turn start.
			WICombat.COOLDOWN_ROUNDS: int(sk.get(WICombat.COOLDOWN_ROUNDS, 0)),
		})
		number += 1
	var usable_by_id: Dictionary = {}
	for rec: Dictionary in usable_items:
		usable_by_id[String(rec.get("id", ""))] = rec
	for raw: Variant in loadout:
		var token := String(raw)
		if not token.begins_with("item:"):
			continue
		var item_id := token.substr(5)
		if not usable_by_id.has(item_id):
			continue
		var rec: Dictionary = usable_by_id[item_id]
		slots.append({
			"type": "item", "id": item_id, "label": String(rec.get("name", item_id)),
			"icon": String(rec.get("icon", "")), "key_hint": str(number),
			"description": String(rec.get("description", "")),
			"use_effect": rec.get("use_effect", {}),
		})
		number += 1
	slots.append({"type": "end_turn", "label": "End\nTurn", "icon": "", "key_hint": "E", "end_turn_gap": true})
	return slots


func render_bar_slots(view: RefCounted, bar_slots: Array) -> Array:
	var c: Dictionary = view.combatant(view.active_id())
	var out: Array = []
	for raw: Variant in bar_slots:
		var d := (raw as Dictionary).duplicate()
		match String(d["type"]):
			"attack":
				d["affordable"] = bar_action_affordable("Attack", c)
				d["ap_cost"] = WICombat.ATTACK_COST
				d["weapon_range"] = int(c.get("weapon_range", 1))
			"dash":
				d["affordable"] = bar_action_affordable("Dash", c)
				d["ap_cost"] = WICombat.DASH_COST
			"skill":
				var skill_id := String(d["id"])
				var sk: Dictionary = view.skill(skill_id)
				d["affordable"] = skill_affordable(c, skill_id, view)
				d["ap_cost"] = view.effective_ap_cost(view.active_id(), skill_id)
				d["mp_cost"] = int(sk.get("mp_cost", 0))
				# GH#337, the MP-diamond precedent two lines up: the LIVE
				# cooldown counter joins the rendered slot record, read from
				# THE sim predicate (never a second copy of the rule) so the
				# bar and `use_skill` can never disagree. `_slot_info_line`
				# speaks it; the dim comes from `affordable` above, the same
				# affordance a spent once-per-fight skill already gets.
				d["cooldown_remaining"] = _cooldown_remaining(view, skill_id)
			"item":
				d["affordable"] = int(c["ap"]) >= WIItems.FLAT_AP_COST
				d["ap_cost"] = WIItems.FLAT_AP_COST
			"end_turn":
				d["affordable"] = true
		out.append(d)
	return out


func bar_action_affordable(action: String, c: Dictionary) -> bool:
	match action:
		"Attack":
			return int(c["ap"]) >= WICombat.ATTACK_COST
		"Dash":
			return int(c["ap"]) >= WICombat.DASH_COST
		_:
			return true


## GH#334 ruling 14: "affordable" has to mean "the sim will accept this press".
## It tested only MP and AP, so a once-per-fight skill already spent this fight
## drew at full brightness and then did nothing when pressed -- from the player's
## seat, identical to a dropped input. The spent term is read through the view's
## passthrough to `WICombat.skill_spent`, the same function `use_skill` refuses
## on, so the bar and the sim can never disagree about it.
##
## GH#337 extends the same rule to cooldowns, for the same reason: a cooling
## slot the sim will refuse must not draw bright and swallow the press.
func skill_affordable(c: Dictionary, skill_id: String, view: RefCounted) -> bool:
	var skill: Dictionary = view.skill(skill_id)
	return int(c.get("mp", 0)) >= int(skill.get("mp_cost", 0)) \
			and int(c["ap"]) >= view.effective_ap_cost(view.active_id(), skill_id) \
			and not bool(view.skill_spent(view.active_id(), skill_id)) \
			and _cooldown_remaining(view, skill_id) <= 0


## GH#337. `WICombatView` (owned by the presentation-decomposition plan, not by
## this milestone) exposes no cooldown getter, so the ONE sim reader is reached
## through the combat reference the composition root hands over at fight start
## -- never through a second copy of the rule, and never by reaching back into
## `_screen` for sim state (this file's own contract). Null before `set_combat`
## has been called (bare-`new()` unit construction, `test_combat_visuals`), and
## a null combat means nothing can be cooling: every pre-GH#337 call site keeps
## its exact previous answer.
func _cooldown_remaining(view: RefCounted, skill_id: String) -> int:
	if _combat == null:
		return 0
	return _combat.cooldown_remaining(String(view.active_id()), skill_id)


## GH#337. Handed the live `WICombat` by `combat_screen.gd` when a fight is
## built (and cleared at teardown), the same "state handed in, never fetched"
## shape every other render input on this class already uses.
func set_combat(combat: WICombat) -> void:
	_combat = combat


## Issue #87 (skip affordance): the EXISTING per-turn AI-playback skip
## (`combat_screen.gd`'s confirm/cancel-consumes-`request_skip()` gate, armed
## whenever `_mode == WAIT_AI and _ai_playback.is_playing()`) had ZERO
## on-screen affordance -- nothing told the player confirm/cancel does
## anything while an AI turn is animating. Surfaced on the SAME readout/hint
## strip the player's own turn already uses (this file's own doc comment
## below calls it "the hint strip"), composed from the SAME confirm/cancel
## glyphs every other readout hint already threads through `hints`
## (`WIInputHints.label()`, resolved once at the composition root --
## `combat_screen.gd._refresh()` -- never referenced as a bare autoload here,
## same contract as `_readout_text` below). No new input action, no new
## mechanism -- this only advertises the one that already exists.
func _ai_skip_hint_text(hints: Dictionary = DEFAULT_HINTS) -> String:
	var confirm_glyph := String(hints.get("confirm", DEFAULT_HINTS["confirm"]))
	var cancel_glyph := String(hints.get("cancel", DEFAULT_HINTS["cancel"]))
	return "%s / %s — skip" % [confirm_glyph, cancel_glyph]


func _readout_text(view: RefCounted, in_targeting: bool, targeting_state: Dictionary,
		rendered_slots: Array, info_slot_index: int, dash_confirm: bool = false,
		hints: Dictionary = DEFAULT_HINTS) -> String:
	var confirm_glyph := String(hints.get("confirm", DEFAULT_HINTS["confirm"]))
	var cancel_glyph := String(hints.get("cancel", DEFAULT_HINTS["cancel"]))
	var cycle_glyph := String(hints.get("cycle", DEFAULT_HINTS["cycle"]))
	var move_glyph := String(hints.get("move", DEFAULT_HINTS["move"]))
	var hotbar_glyph := String(hints.get("hotbar", DEFAULT_HINTS["hotbar"]))
	var end_turn_glyph := String(hints.get("end_turn", DEFAULT_HINTS["end_turn"]))
	var c: Dictionary = view.combatant(view.active_id())
	var mp_bit := ""
	if int(c.get("max_mp", 0)) > 0:
		mp_bit = "  MP %d/%d" % [int(c["mp"]), int(c["max_mp"])]
	var head := "%s  AP %s  Move %s%s" % [
		UIChrome.bb_escape(view.display_name(view.active_id())), "●".repeat(int(c["ap"])), "○".repeat(int(c["move_pool"])), mp_bit,
	]
	var info_line := _render_slot_info_line(rendered_slots, info_slot_index)
	if dash_confirm:
		return _compose_readout(head, "", info_line + " (%s confirms, %s cancels)" % [confirm_glyph, cancel_glyph])
	if not in_targeting:
		if int(c["move_pool"]) <= 0 and bar_action_affordable("Dash", c):
			return _compose_readout(head, "Out of steps — Dash (2) spends 1 AP for +3", info_line)
		if int(c["move_pool"]) <= 0:
			return _compose_readout(head, "Out of steps — end turn or choose another action", info_line)
		return _compose_readout(head, "%s move, %s act, %s ends turn" % [move_glyph, hotbar_glyph, end_turn_glyph], info_line)
	if bool(targeting_state.get("line_mode", false)):
		return _compose_readout(head, String(targeting_state.get("line_text", "")), info_line)
	var targets: Array = targeting_state.get("targets", [])
	if targets.is_empty():
		var note := ""
		if bool(targeting_state.get("los_blocked", false)):
			note = "  (no line of sight)"
		elif bool(targeting_state.get("out_of_range", false)):
			note = "  (out of range)"
		return _compose_readout(head, "No target in reach (%s)" % cancel_glyph + note, info_line)
	var target_id := String(targets[int(targeting_state.get("index", 0))])
	var t: Dictionary = view.combatant(target_id)
	return _compose_readout(
		head,
		"Target: %s (%d/%d) (%s cycles, %s confirms)" % [UIChrome.bb_escape(view.display_name(target_id)), int(t["hp"]), int(t["max_hp"]), cycle_glyph, confirm_glyph],
		info_line
	)


func _compose_readout(head: String, hint: String, info: String) -> String:
	var used := _rtl_wrapped_line_count(_readout_label, head, READOUT_TEXT_WIDTH)
	if hint != "":
		used += _rtl_wrapped_line_count(_readout_label, hint, READOUT_TEXT_WIDTH)
	var budget := maxi(_rtl_line_capacity(_readout_label, READOUT_TEXT_HEIGHT) - used, 1)
	var fitted := UIChrome.bb_escape(_rtl_fit_to_lines(_readout_label, info, READOUT_TEXT_WIDTH, budget))
	var lines: Array[String] = [head]
	if hint != "":
		lines.append(hint)
	lines.append(fitted)
	return "\n".join(lines)


func _render_slot_info_line(rendered_slots: Array, info_slot_index: int) -> String:
	var index := info_slot_index
	if index < 0 or index >= rendered_slots.size():
		index = 0
	var line := "" if rendered_slots.is_empty() else _slot_info_line(rendered_slots[index] as Dictionary)
	if index != _last_slot_info_index or line != _last_slot_info_text:
		_last_slot_info_index = index
		_last_slot_info_text = line
		_screen._emit_slot_info(index, UIChrome.bb_escape(line))
	return line


## The skill arm's cost/effect segment is GENERATED by
## `WIEffectText.skill_effect_lines` from `d`'s own `ap_cost`/`mp_cost`/
## `effect` fields (`ap_cost` is the LIVE effective cost, quick_cast discount
## already applied by `render_bar_slots`) -- never hand-composed here. This
## guards the exact defect a hand-composed line invites: a bare "%d AP"
## cost line that never surfaces the skill's actual mechanical effect
## (e.g. Power Strike's ×2 damage multiplier invisible). Every shipped
## active combat skill (ap_cost>0, contexts:combat -- the only skills this
## bar ever lists) has a mapped `_effect_phrase` case, so `effect_lines` is
## never empty in practice; the empty-array branch (name + description only,
## no dangling dash) mirrors the item-card degrade for a Skill the formatter
## can't yet phrase -- report that gap, don't hand-compose around it.
func _slot_info_line(d: Dictionary) -> String:
	match String(d.get("type", "")):
		"attack":
			var attack_range := int(d.get("weapon_range", 1))
			if attack_range > 1:
				return "Attack — strike a target within range %d" % attack_range
			return "Attack — strike an adjacent enemy"
		"dash":
			return "Dash — %d AP: refill your move pool" % int(d.get("ap_cost", WICombat.DASH_COST))
		"end_turn":
			return "End Turn"
		"skill":
			var skill_name := String(d.get("label", ""))
			var desc := String(d.get("description", ""))
			# GH#334 ruling 14: `once_per_fight` joins the record. Every key the
			# formatter reads must be present here or the clause it generates is
			# silently dropped -- widen BOTH this dict and `rebuild_slots`' slot
			# record together when a new one lands.
			var record := {
				"ap_cost": d.get("ap_cost", 0),
				"mp_cost": d.get("mp_cost", 0),
				"effect": d.get("effect", {}),
				"once_per_fight": d.get("once_per_fight", false),
				WICombat.COOLDOWN_ROUNDS: d.get(WICombat.COOLDOWN_ROUNDS, 0),
			}
			var effect_lines := WIEffectText.skill_effect_lines(record)
			# GH#337: the LIVE clause, appended LAST so it reads as the current
			# state of this slot rather than part of the Skill's standing rule
			# (which `skill_effect_lines` already speaks as "Once every N
			# rounds."). Without it a dimmed slot is a dead button with no stated
			# reason -- the same hole ruling 14 closed for a spent
			# once-per-fight Skill.
			var recovering := WIEffectText.cooldown_recovering_line(int(d.get("cooldown_remaining", 0)))
			var tail := "" if recovering == "" else " — " + recovering
			if desc == "":
				return (skill_name if effect_lines.is_empty() else "%s — %s" % [skill_name, effect_lines[0]]) + tail
			if effect_lines.is_empty():
				return "%s — %s%s" % [skill_name, desc, tail]
			return "%s — %s — %s%s" % [skill_name, effect_lines[0], desc, tail]
		"item":
			var item_name := String(d.get("label", ""))
			var item_desc := String(d.get("description", ""))
			var use_effect: Dictionary = d.get("use_effect", {})
			var item_lines: Array[String] = []
			if use_effect.has("heal"):
				item_lines = WIEffectText.skill_effect_lines({
					"ap_cost": d.get("ap_cost", WIItems.FLAT_AP_COST), "mp_cost": 0,
					"effect": {"type": "heal", "amount": int(use_effect["heal"])},
				})
			if item_desc == "":
				return item_name if item_lines.is_empty() else "%s — %s" % [item_name, item_lines[0]]
			if item_lines.is_empty():
				return "%s — %s" % [item_name, item_desc]
			return "%s — %s — %s" % [item_name, item_lines[0], item_desc]
		_:
			return ""




func _display_name(combat: WICombat, view: RefCounted, id: String) -> String:
	if view != null:
		return view.display_name(id)
	return String(combat.combatants[id]["display_name"])


func _on_banner_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		banner_tapped.emit()


func show_banner(text: String) -> void:
	_banner_label.text = text


func clear_feed() -> void:
	_feed.clear()


## The usable text-content height for the feed label RIGHT NOW, derived from
## `_feed_panel_height` (base size, or grown -- see `_resize_feed_panel`) and
## the fixed fold-danger pixel budget (FEED_STRIP_FOLD_PATCH_BOTTOM/
## FEED_FOLD_DANGER_PX -- see that const block's doc comment). The label is
## TOP-aligned (a single measured deficit, unlike the vertically-centered
## toast label which budgets it twice), so: usable = panel_height -
## top_content_margin - danger_zone. CONSTRAINT: must stay a function of the
## LIVE `_feed_panel_height`, never a flat const -- a capacity computed
## against the base size while the panel is grown under-fills it, and one
## computed against the grown size while at base overflows the fold.
func _feed_text_capacity_height() -> float:
	return maxf(_feed_panel_height - FEED_CONTENT_MARGIN_TOP - FEED_FOLD_DANGER_PX, 0.0)


func feed_push(line: String) -> void:
	if line == "":
		return
	# GH#170(b): every on-screen feed line also lands in the shared Recent
	# Messages history -- the journal answers "what just happened" after a
	# fight from the SAME composed copy the player saw scroll past.
	var layer_script := load("res://src/ui/message_layer.gd")
	if layer_script != null:
		layer_script.record_message(line)
	var capacity := _line_capacity(_feed_label, _feed_text_capacity_height())
	_feed.append(_fit_to_lines(_feed_label, line, FEED_TEXT_WIDTH, capacity))
	while _feed.size() > 1 and _feed_wrapped_total() > capacity:
		_feed.pop_front()


func _feed_wrapped_total() -> int:
	var total := 0
	for line: String in _feed:
		total += _wrapped_line_count(_feed_label, line, FEED_TEXT_WIDTH)
	return total


## `payload` must already carry `_ui.feed_line` (captured at enqueue by
## combat_playback.gd's `_capture_event_ui`, which calls `feed_line_for_event`
## below) -- every caller passes a captured event's payload.
func push_feed(payload: Dictionary) -> void:
	feed_push(String((payload.get("_ui", {}) as Dictionary).get("feed_line", "")))


func feed_line_for_event(type: String, payload: Dictionary, combat: WICombat, view: RefCounted = null) -> String:
	var line := ""
	match type:
		WIEvents.ATTACK_RESOLVED:
			if combat == null or not combat.combatants.has(String(payload["attacker"])) or not combat.combatants.has(String(payload["target"])):
				return ""
			var attacker := _display_name(combat, view, String(payload["attacker"]))
			var target := _display_name(combat, view, String(payload["target"]))
			line = ("%s strikes %s for %d!" % [attacker, target, int(payload["damage"])]) if bool(payload["hit"]) else "%s misses %s." % [attacker, target]
		WIEvents.REACTION_TRIGGERED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			var reactor_name := _display_name(combat, view, String(payload["id"]))
			# GH#334 ruling 12: the reaction FAMILY, not the base id -- an Ice Mage's
			# absorb credits [Ice Wall] and must still read as a shield drinking the
			# blow, not fall through to the generic "answers with" reaction line.
			if String(payload.get("family", payload.get("skill", ""))) == "mana_shield":
				line = "%s's shield drinks the blow (%d)." % [reactor_name, int(payload["absorbed"])]
			else:
				if not combat.skills.has(String(payload["skill"])):
					return ""
				line = "%s answers with %s!" % [reactor_name, String(combat.skills[payload["skill"]]["display_name"])]
		WIEvents.SKILL_RESOLVED:
			if combat == null or not combat.combatants.has(String(payload["actor"])) or not combat.skills.has(String(payload["skill"])):
				return ""
			var actor_name := _display_name(combat, view, String(payload["actor"]))
			var used_skill: Dictionary = combat.skills[payload["skill"]]
			var is_line := String((used_skill.get("effect", {}) as Dictionary).get("type", "")) == "line_damage"
			line = ("%s's %s roars down the line!" % [actor_name, String(used_skill["display_name"])]) if is_line \
					else "%s uses %s!" % [actor_name, String(used_skill["display_name"])]
		WIEvents.COMBATANT_DOWNED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			line = "%s falls!" % _display_name(combat, view, String(payload["id"]))
		WIEvents.DASHED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			line = "%s surges forward!" % _display_name(combat, view, String(payload["id"]))
		WIEvents.STATUS_APPLIED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			line = "%s is %s!" % [_display_name(combat, view, String(payload["id"])), String(payload["status"])]
			if bool(payload.get("first_seen", false)):
				line += " " + String(payload.get("status_text", ""))
		WIEvents.STATUS_EXPIRED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			var expired_name := _display_name(combat, view, String(payload["id"]))
			if String(payload.get("status", "")) == "slowed" and String(payload.get("source_kind", "")) == "icy_floor":
				line = "%s is still gripped by the ice." % expired_name
			else:
				line = "%s shakes it off." % expired_name
		WIEvents.STATUS_TICKED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			var ticked_damage := int(payload.get("damage", 0))
			if ticked_damage <= 0:
				return ""
			var ticked_name := _display_name(combat, view, String(payload["id"]))
			if String(payload.get("status", "")) == "burning":
				line = "%s burns for %d." % [ticked_name, ticked_damage]
			else:
				line = "%s takes %d from %s." % [ticked_name, ticked_damage, String(payload.get("status", "")).replace("_", " ")]
		WIEvents.WINDUP_DECLARED:
			if combat == null or not combat.combatants.has(String(payload["id"])) or not combat.skills.has(String(payload["skill"])):
				return ""
			var windup_caster := _display_name(combat, view, String(payload["id"]))
			line = "%s gathers itself for %s..." % [windup_caster, String(combat.skills[payload["skill"]]["display_name"])]
		WIEvents.ACTION_REFUSED:
			if combat == null or not combat.combatants.has(String(payload["actor"])):
				return ""
			var refused := _display_name(combat, view, String(payload["actor"]))
			var why := String(payload.get("reason", ""))
			# GH#337: "cooldown" would otherwise fall through the generic
			# underscore-swap arm and read "hesitates -- cooldown." -- a data key
			# spoken at the player. The Skill is recovering; say that.
			var why_text := "no clear line of sight" if why == "no_los" \
					else ("out of range" if why == "out_of_range" \
					else ("that Skill is still recovering" if why == "cooldown" \
					else why.replace("_", " ")))
			line = "%s hesitates — %s." % [refused, why_text]
	return line


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


func _line_capacity(label: Label, height: float) -> int:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	var line_spacing := float(label.get_theme_constant("line_spacing"))
	var pitch := line_height + line_spacing
	return max(int((height + line_spacing) / pitch), 1)


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


## RichTextLabel counterparts of `_wrapped_line_count`/`_line_capacity`/
## `_fit_to_lines` above, for `_readout_label`. Distinct
## functions, not a shared Label/RichTextLabel-typed one: RichTextLabel's
## real theme properties are "normal_font"/"normal_font_size"/
## "line_separation", not Label's "font"/"font_size"/"line_spacing" --
## reusing the Label helpers on a RichTextLabel would silently read those
## WRONG names (this theme happens to fall back to the same engine default
## either way today, since CombatReadout overrides none of them -- confirmed
## via a headless probe -- but that is a coincidence of this theme file, not
## a contract worth relying on).
func _rtl_wrapped_line_count(label: RichTextLabel, text: String, width: float) -> int:
	if text == "":
		return 0
	var font := label.get_theme_font("normal_font")
	var font_size := label.get_theme_font_size("normal_font_size")
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	return max(int(round(size.y / line_height)), 1)


func _rtl_line_capacity(label: RichTextLabel, height: float) -> int:
	var font := label.get_theme_font("normal_font")
	var font_size := label.get_theme_font_size("normal_font_size")
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	var line_sep := float(label.get_theme_constant("line_separation"))
	var pitch := line_height + line_sep
	return max(int((height + line_sep) / pitch), 1)


func _rtl_fit_to_lines(label: RichTextLabel, text: String, width: float, max_lines: int) -> String:
	if _rtl_wrapped_line_count(label, text, width) <= max_lines:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var candidate := " ".join(words) + "…"
		if _rtl_wrapped_line_count(label, candidate, width) <= max_lines:
			return candidate
	return (words[0] + "…") if words.size() > 0 else text


## Floodplains P1: reloads `arena_config["tutor_lines"]` for a fresh combat
## instance and clears the fired/count state. Called from
## `combat_screen.gd._on_domain_event` on `combat_started`, BEFORE that same
## event is matched against the new list. Takes `arena_config` directly
## (the screen passes `combat.arena_config` or `{}` if no live combat) rather
## than a `WICombatView` -- `_view` doesn't exist yet at COMBAT_STARTED time
## (it's constructed by `_show_combat()`, called by the SAME event a moment
## later), so this must read off the raw combat the screen already has.
func reset_tutor_lines(arena_config: Dictionary) -> void:
	_tutor_lines = (arena_config.get("tutor_lines", []) as Array).duplicate(true)
	_tutor_fired = {}
	_tutor_match_counts = {}
	for entry: Dictionary in _tutor_lines:
		var on: Dictionary = entry.get("on", {})
		var event_type := String(on.get("event", ""))
		if not TUTOR_SUPPORTED_EVENTS.has(event_type):
			push_warning("tutor_lines entry '%s' targets unsupported event '%s' -- combat HUD has no render call site for it and the line will never reach the feed" % [String(entry.get("id", "")), event_type])
	# A fresh combat starts every panel back at its
	# base size -- a prior encounter's grown-for-a-long-beat feed panel must
	# not carry over.
	_resize_feed_panel(FEED_PANEL_BASE_SIZE.y)


## Counting and rendering are
## SEPARATE concerns -- verbatim move, see combat_screen.gd's original doc
## comment for the full starvation-fix rationale. MUST be called exactly once
## per real domain event, at capture time.
func match_tutor_line(type: String, payload: Dictionary) -> Dictionary:
	var ready: Array[Dictionary] = []
	for entry: Dictionary in _tutor_lines:
		var id := String(entry.get("id", ""))
		if id == "" or bool(_tutor_fired.get(id, false)):
			continue
		var on: Dictionary = entry.get("on", {})
		if String(on.get("event", "")) != type:
			continue
		if not _tutor_payload_contains(payload, (on.get("payload_contains", {}) as Dictionary)):
			continue
		var nth := int(on.get("nth", 1))
		var count: int = int(_tutor_match_counts.get(id, 0)) + 1
		_tutor_match_counts[id] = count
		if count >= nth:
			ready.append({"id": id, "line": _tutor_line_text(entry)})
	if ready.is_empty():
		return {}
	var chosen: Dictionary = ready[0]
	_tutor_fired[String(chosen["id"])] = true
	return chosen


## Issue #88 (gap-2): a SECOND-LEVEL split inside the fallback branch --
## `requires_ally` (a combatant id) + `solo_fallback_line` are BOTH optional,
## checked only once `requires_any_class` has already failed. A line voiced
## as that ally speaking (`fallback_line`, e.g. goblin_ambush_tutorial's
## "real_ones") must not render when the ally is structurally absent from
## THIS fight (`ally_requires` unmet) -- `solo_fallback_line` renders
## instead. An entry with no `requires_ally`/`solo_fallback_line` keys
## (every pre-#88 entry) always falls through to the plain `fallback_line`
## branch, byte-identical to before.
func _tutor_line_text(entry: Dictionary) -> String:
	if bool(entry.get("requires_any_class", false)) and not _screen._pc_has_any_class():
		var required_ally := String(entry.get("requires_ally", ""))
		if required_ally != "" and entry.has("solo_fallback_line") and not _screen._pc_has_ally(required_ally):
			return String(entry["solo_fallback_line"])
		return String(entry.get("fallback_line", entry.get("line", "")))
	return String(entry.get("line", ""))


## Subset match: every key in `subset` must exist in `payload` with a loosely
## equal value. Duplicated from qa/test_driver.gd's `_event_matches` by
## design (see `match_tutor_line`'s doc comment).
func _tutor_payload_contains(payload: Dictionary, subset: Dictionary) -> bool:
	for key: String in subset:
		if not payload.has(key) or not _tutor_loosely_equal(payload[key], subset[key]):
			return false
	return true


func _tutor_loosely_equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _tutor_loosely_equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.keys().size() != b.keys().size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _tutor_loosely_equal(a[key], b[key]):
				return false
		return true
	return a == b


func render_tutor_line(tutor: Dictionary) -> void:
	if tutor.is_empty():
		return
	_grow_feed_panel_for_tutor(String(tutor.get("line", "")))
	feed_push(String(tutor.get("line", "")))
	_screen._emit_tutor_rendered(String(tutor.get("id", "")))


func _grow_feed_panel_for_tutor(text: String) -> void:
	if _feed_label == null:
		return
	var lines := _wrapped_line_count(_feed_label, text, FEED_TEXT_WIDTH)
	var font := _feed_label.get_theme_font("font")
	var font_size := _feed_label.get_theme_font_size("font_size")
	var line_spacing := float(_feed_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	var text_block := float(lines) * pitch - line_spacing
	var needed := text_block + FEED_CONTENT_MARGIN_TOP + FEED_FOLD_DANGER_PX + TUTOR_SAFETY_BUFFER_PX
	needed = minf(needed, FEED_PANEL_MAX_HEIGHT)
	if needed > _feed_panel_height:
		_resize_feed_panel(needed)


func _resize_feed_panel(height: float) -> void:
	if _feed_label == null:
		return
	_feed_panel_height = height
	var panel: Control = _feed_label.get_parent().get_parent()
	panel.custom_minimum_size = Vector2(FEED_PANEL_BASE_SIZE.x, height)
	panel.size = Vector2(FEED_PANEL_BASE_SIZE.x, height)
	UIChrome.set_offsets(panel, FEED_OFFSET_LEFT, FEED_OFFSET_BOTTOM - height, FEED_OFFSET_RIGHT, FEED_OFFSET_BOTTOM)
