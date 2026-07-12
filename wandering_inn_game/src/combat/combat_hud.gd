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
##
## Constructed ONCE by `combat_screen.gd._ready()` (like `_board_renderer`/
## `_ai_playback`), reused across encounters: `_hud = load("res://src/combat/
## combat_hud.gd").new(_root, main_ref, self); _hud.build()`. `build()` is a
## separate explicit call (not run from `_init`) so this file stays
## constructible with a null `root` -- see the next paragraph.
##
## `_root`/`_main_ref`/`_screen` are loosely typed (`Control`/`Node`/`Node`,
## not the screen's own class), and `_init` is a pure store with no side
## effects -- this is REQUIRED, not stylistic: `combat_screen.gd`'s
## `_feed_line_for_event` compat shim (kept because `combat_playback.gd`'s
## `_capture_event_ui` calls it on every captured event, live gameplay and
## `tests/test_combat_visuals.gd`'s direct `_capture_playback_event(...)` call
## alike) lazily constructs `_hud` the same way D3's `_capture_playback_event`
## shim lazily constructs `_ai_playback` -- and that lazy construction must
## succeed even inside the test's hostile `--script`-mode process, where
## `_root`/`main_ref` are null (the patched screen instance never ran
## `_ready()`). `feed_line_for_event()` (the one method that lazy path
## actually calls) never touches `_root`, so a null `_root` is harmless there.
##
## This file carries ZERO bare autoload identifiers (`ObservableBus`/`Game`/
## `TestDriver`/`WIAudio` -- the only 4 real autoloads in this project, per
## project.godot; `UIChrome`/`WIEvents`/`WICombat`/`WIHotbar` etc. are plain
## `class_name` scripts and resolve fine anywhere, same as combat_playback.gd
## already established) -- REQUIRED for the same reason `combat_playback.gd`
## needed it: `load("res://src/combat/combat_hud.gd")` must actually COMPILE
## when the `_feed_line_for_event` shim calls it inside the hostile test
## process (confirmed empirically by D3: a `load()`'d script with ANY
## unresolved bare autoload identifier anywhere in its body -- even inside a
## method never called that run -- returns `can_instantiate() == false`).
## The two spots this file's moved logic used to touch `ObservableBus`
## directly (`ui_slot_info_rendered`, `ui_tutor_line_rendered`) now call back
## through `_screen._emit_slot_info(...)`/`_screen._emit_tutor_rendered(...)`.

## Feed panel interior text box width (panel width 292 minus the 22px
## left+right content margins -- see `build()`). The USABLE text HEIGHT is
## deliberately NOT a const (see `_feed_text_capacity_height`): it tracks
## `_feed_panel_height`, which can grow past the base size for a long tutor
## beat.
const FEED_TEXT_WIDTH := 248.0

## Readout panel interior text box (panel-class fix
## flagged after L4's windowed shot: `.superpowers/sdd/fp-handoff/l4-shots/
## 01_first_encounter_feed.png` showed frost_bolt's full 3-segment slot-info
## line ("[Frost Bolt] — 1 AP, 2 MP — damage 1d6 at range 4. Slows. — A dart
## of biting cold that clings to the legs.") wrap to a 2nd line, pushing the
## readout's total to 4 wrapped lines (head + hint + 2 info lines); the 4th
## rode the parchment's bottom fold, same repo-wide "Control rect > art-safe
## band" class the feed panel was already fixed for (see the Gotchas
## entry "Message panels budget WRAPPED LINES, not entries"). WIDTH mirrors
## the readout MarginContainer's interior (panel width 620 minus its 22px
## left+right margins, see build()). This panel has no separately-measured
## print-safe pixel height the way the feed does; rather than guess one,
## HEIGHT is picked to yield a LINE CAPACITY of exactly 3 (head + hint/target
## + slot-info) at the CombatReadout RichTextLabel's real font pitch --
## confirmed via a headless theme probe: font height 20px, `line_separation`
## 0px for this unstyled variation, so pitch=20 and capacity=3 needs a height
## in [60,79]; 64 leaves a little headroom. 3 lines is the empirically
## observed safe boundary (every OTHER shipped slot-info line, one line long,
## already renders fine inside this panel) -- windowed-reverified after this
## fix (see the L5 report).
const READOUT_TEXT_WIDTH := 576.0
const READOUT_TEXT_HEIGHT := 64.0
const HOTBAR_SCRIPT := preload("res://src/ui/hotbar.gd")
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

## Fold-pin for the feed panel's PARCHMENT_STRIP chrome (Banner_Horizontal.
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
## Danger-zone depth from the panel's own bottom edge once the fold is
## pinned into the unstretched bottom patch -- mirrors message_layer.gd's
## TOAST_FOLD_DANGER_PX (30, same source art, 1px slack over the 29px
## measured fold depth).
const FEED_FOLD_DANGER_PX := 30.0
## The feed label's own top content margin (`_make_panel_label`'s
## `UIChrome.add_margins(margin, 22, 8, 22, 8)` call for this panel) --
## text starts this far below the panel's top edge, so it factors into both
## the base capacity and the tutor-grow formula below.
const FEED_CONTENT_MARGIN_TOP := 8.0
## Extra print-safety margin stacked on top of FEED_FOLD_DANGER_PX when
## GROWING the panel for a long tutor beat (never applied to the base,
## already-measured-safe capacity) -- errs generous since a tutor beat is a
## rare, story-critical line worth a few extra px of headroom, not spammy
## combat-log noise.
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

var _root: Control
var _main_ref: Node
var _screen: Node

var _readout_label: RichTextLabel
var _order_label: Label
var _feed_label: Label
var _banner_label: Label
var _readout_panel: Control
var _banner_panel: Control
var _hotbar: WIHotbar
var _feed: Array = []
## Current feed panel height, grown (never
## shrunk mid-encounter) by `_grow_feed_panel_for_tutor` when a tutor beat
## needs more room than FEED_PANEL_BASE_SIZE.y safely provides. Reset to
## base on every fresh `reset_tutor_lines` call (combat_started).
var _feed_panel_height := FEED_PANEL_BASE_SIZE.y
## Dedup guard so `ui_slot_info_rendered` fires only when the rendered slot
## index or its text actually changes -- see `_render_slot_info_line`.
var _last_slot_info_index := -999
var _last_slot_info_text := ""
## Floodplains P1: reloaded fresh per combat instance by `reset_tutor_lines`
## (called on `combat_started`) -- see `match_tutor_line`.
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
	#   order strip   CENTER_TOP     x[32,1248]  y[10,52]
	#   feed          BOTTOM_LEFT    x[28,320]   y[514,636]  (left column)
	#   readout       CENTER_BOTTOM  x[330,950]  y[530,642]  (grown upward, M6
	#                 slot-info line -- see _readout_text/_slot_info_line;
	#                 nothing else occupies this x-range above y[636])
	#   hotbar        CENTER_BOTTOM  y[658,710]  (see hotbar.gd BOTTOM_MARGIN)
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
	# The strip art seats its parchment slightly high in the panel, so bias the
	# text up (bigger bottom margin) to sit it on the parchment's centre rather
	# than at its lower lip -- measured against a windowed turn-banner read.
	(_order_label.get_parent() as MarginContainer).add_theme_constant_override("margin_bottom", 24)
	# Feed: PARCHMENT_STRIP (landscape banner) -- the portrait scroll squashed
	# to a wide rect read wrong (H3 review minor). "Small" text; capacity is
	# budgeted in WRAPPED lines, not entry count (see FEED_TEXT_WIDTH and
	# feed_push) -- a long tutor line can consume more of the budget and
	# evict older entries sooner.
	_feed_label = _make_panel_label(
		UIChrome.PARCHMENT_STRIP, Control.PRESET_BOTTOM_LEFT,
		Vector2(292.0, 122.0), Vector4(28.0, -206.0, 320.0, -84.0), false, "Small"
	)
	# Pin the fold into the unstretched bottom patch (see
	# FEED_STRIP_FOLD_PATCH_BOTTOM's doc comment) -- `_make_panel_label` ->
	# `_make_panel` -> `UIChrome.make_texture_panel` already built this
	# panel's NinePatchRect as child 0 with the default STRIP_PATCH_MARGIN on
	# all four sides; only the bottom margin needs widening here.
	(_feed_label.get_parent().get_parent().get_child(0) as NinePatchRect).patch_margin_bottom = FEED_STRIP_FOLD_PATCH_BOTTOM
	# Height grown from 62/70px to 104/112px (M6 playtest fix) to fit the new
	# third slot-info line (name + costs + description) without truncation --
	# see _readout_text/_slot_info_line. Grown upward only (top offset), so
	# the hotbar's y[658,710] band directly below stays untouched.
	_readout_panel = _make_panel(UIChrome.PARCHMENT_STRIP, Control.PRESET_CENTER_BOTTOM, Vector2(620.0, 104.0), Vector4(-310.0, -190.0, 310.0, -78.0))
	_readout_label = UIChrome.make_rich_label("CombatReadout")
	var readout_margin := MarginContainer.new()
	UIChrome.full_rect(readout_margin)
	UIChrome.add_margins(readout_margin, 22, 9, 22, 9)
	_readout_panel.add_child(readout_margin)
	readout_margin.add_child(_readout_label)
	_root.add_child(_readout_panel)
	_banner_panel = _make_panel(UIChrome.BLUE_RIBBON, Control.PRESET_CENTER, Vector2(360.0, 76.0), Vector4(-180.0, -38.0, 180.0, 38.0))
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


## Read-only accessor (issue #57): the real `WIHotbar` node, for
## `combat_screen.gd` to connect its `slot_clicked` signal (same dispatch as
## a `hotbar_N` key -- `_activate_bar_slot`) and for `qa/test_driver.gd`'s
## `click_slot` step to read its rendered `slot_rect` geometry.
func hotbar_node() -> WIHotbar:
	return _hotbar


func _make_panel(texture: Texture2D, preset: int, min_size: Vector2, offsets: Vector4) -> Control:
	# make_texture_panel threads texture-appropriate patch margins (ribbon
	# asymmetric, strip narrow, panel default) -- H3 review Important 2.
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
## original `_refresh()`'s split exactly.
func refresh(view: RefCounted, bar_active: bool, in_targeting: bool, is_banner: bool,
		targeting_state: Dictionary, bar_slots: Array, bar_index: int, info_slot_index: int,
		dash_confirm: bool = false, hints: Dictionary = DEFAULT_HINTS) -> void:
	var order_bits: Array = []
	for id: String in view.order():
		var mark := "> " if id == view.active_id() else ""
		if view.alive(id):
			# Issue #75 item 5b: `view.display_name` (not the raw
			# combatant dict) so a duplicate-name roster reads "Footpad A" /
			# "Footpad B" on the strip, matching the feed/readout.
			order_bits.append(mark + view.display_name(id))
	# "Turn:" + a bare space read as glued to the first name at a glance
	# (playtest report: "Turn: Relc | > Traveler" misreads as possessive --
	# "Turn's Relc"). An em dash is an unambiguous label/content break, same
	# grammar as the readout's own "AP ●●●●  Move ○○○○" spaced segments.
	_order_label.text = "Turn — " + "  |  ".join(order_bits)
	_feed_label.text = "\n".join(_feed)
	# Empty feed = no floating empty parchment (E3 merge windowed pass).
	_feed_label.get_parent().get_parent().visible = not _feed.is_empty()
	_banner_panel.visible = is_banner
	# The hotbar + its readout/hint strip share one visibility gate: every
	# mode where the player is actively choosing/aiming an action this turn.
	_readout_panel.visible = bar_active
	_hotbar.visible = bar_active
	if bar_active:
		var rendered_slots := render_bar_slots(view, bar_slots)
		_readout_label.text = _readout_text(view, in_targeting, targeting_state, rendered_slots, info_slot_index, dash_confirm, hints)
		_hotbar.render(rendered_slots, bar_index)


## Builds the ordered slot list for the hotbar -- Attack, Dash, then
## `actor_id`'s combat skills with an AP cost (skills.json order), then End
## Turn. Rebuilt fresh every time a player turn starts (`combat_screen.gd`'s
## `_apply_turn_started`, which stores the result in its own `_bar_slots`).
## Static display data only (icon id, label, key hint) -- affordability and
## live AP-cost numbers are computed fresh every `refresh()` by
## `render_bar_slots`, not baked in here.
## `loadout` (default `[]` -- every pre-K2b call site,
## including this file's own unit test, stays byte-identical) is
## `Game.sim.hotbar_loadout`, threaded in by `combat_screen.gd` (the actual
## screen, which already references `Game.sim` freely -- this file itself
## stays at ZERO bare autoload identifiers, see the file doc comment).
## Attack/Dash stay HARD-PINNED at slots 1/2 regardless of the loadout -- the
## loadout only ever governs the kit-skill run from slot 3 on, filtered
## through `WIGame.apply_loadout` (a plain `class_name`, not an autoload, so
## calling it here is safe under the zero-bare-autoload-identifier contract
## the same way `WICombat`/`WIHotbar` already are). AUTO (loadout empty)
## returns the kit run in its original skills.json-derived order, unchanged.
func rebuild_slots(view: RefCounted, actor_id: String, loadout: Array = []) -> Array:
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
	var number := 3
	for sk_id: String in WIGame.apply_loadout(kit_ids, loadout):
		var sk: Dictionary = view.skill(sk_id)
		slots.append({
			"type": "skill", "id": sk_id, "label": String(sk.get("display_name", sk_id)),
			"icon": String(sk.get("icon", "")), "key_hint": str(number),
			"description": String(sk.get("description", "")),
			# Carried through untouched by render_bar_slots'
			# duplicate() so `_slot_info_line` can hand it to
			# `WIEffectText.skill_effect_lines` -- the generated mechanical
			# line, never hand-composed here.
			"effect": sk.get("effect", {}),
		})
		number += 1
	slots.append({"type": "end_turn", "label": "End\nTurn", "icon": "", "key_hint": "E", "end_turn_gap": true})
	return slots


## Adds the per-render-frame bits `rebuild_slots` deliberately leaves out
## (affordability + live ap/mp cost numbers) to a copy of `bar_slots`, ready
## for `Hotbar.render`. Public (not just `refresh()`'s internal use) so
## `combat_screen.gd`'s dead `_render_bar_slots` compat shim (kept for
## `tests/test_combat_visuals.gd`'s has_method check) can call the one real
## implementation.
func render_bar_slots(view: RefCounted, bar_slots: Array) -> Array:
	var c: Dictionary = view.combatant(view.active_id())
	var out: Array = []
	for raw: Variant in bar_slots:
		var d := (raw as Dictionary).duplicate()
		match String(d["type"]):
			"attack":
				d["affordable"] = bar_action_affordable("Attack", c)
				d["ap_cost"] = WICombat.ATTACK_COST
				# GH#70: carried through so _slot_info_line can branch its text --
				# see that function own comment. weapon_range defaults to 1 for
				# every pre-GH#70 combatant.
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
			"end_turn":
				d["affordable"] = true
		out.append(d)
	return out


## Whether a fixed bar action (Attack/Dash) is currently actionable -- mirrors
## the AP gates the sim would enforce, purely for greying + activate-refusal.
## Public: also called directly by `combat_screen.gd`'s `_activate_bar_slot`
## (the command-issuing gate, which stays screen-side).
func bar_action_affordable(action: String, c: Dictionary) -> bool:
	match action:
		"Attack":
			return int(c["ap"]) >= WICombat.ATTACK_COST
		"Dash":
			return int(c["ap"]) >= WICombat.DASH_COST
		_:
			return true


## Whether `c` (always the active combatant in every real call site) can
## currently afford to cast `skill_id` -- the same AP/MP gate WICombat.
## use_skill checks internally, mirrored here purely for greying unaffordable
## rows. Uses `view.effective_ap_cost` so a quick_cast discount shows up in
## both the cost readout and the affordability check. Public: also called
## directly by `combat_screen.gd`'s `_activate_bar_slot`.
func skill_affordable(c: Dictionary, skill_id: String, view: RefCounted) -> bool:
	var skill: Dictionary = view.skill(skill_id)
	return int(c.get("mp", 0)) >= int(skill.get("mp_cost", 0)) \
			and int(c["ap"]) >= view.effective_ap_cost(view.active_id(), skill_id)


## The readout/hint strip that sits directly above the hotbar. `in_targeting`
## distinguishes the HOTBAR resting-state hint from the ATTACK/SKILL_TARGET
## aiming hint (the original matched on `_mode` directly; see the file doc
## comment on why that enum can't be referenced from here). `dash_confirm`
## is its own third hint state -- Dash has no target list,
## so it is NOT folded into `in_targeting`. `rendered_slots` is this same
## call's already-computed `render_bar_slots()` array.
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
	# Issue #75 item 5b: view.display_name, not the raw dict field -- the
	# active combatant may itself be one of a duplicate-name pair.
	var head := "%s  AP %s  Move %s%s" % [
		UIChrome.bb_escape(view.display_name(view.active_id())), "●".repeat(int(c["ap"])), "○".repeat(int(c["move_pool"])), mp_bit,
	]
	# RAW (un-escaped) -- `_compose_readout` measures/fits this against the
	# panel's true wrap width, then escapes only the FITTED result. The event
	# `_render_slot_info_line` fires (ui_slot_info_rendered) still carries the
	# FULL escaped line regardless of what's rendered here.
	var info_line := _render_slot_info_line(rendered_slots, info_slot_index)
	if dash_confirm:
		# Dedupe: the confirm hint REPLACES the plain
		# slot-info line rather than stacking above it — while the gate is
		# armed, `info_slot_index` always points at the Dash slot, so both
		# lines would start "Dash — 1 AP: ...". `_render_slot_info_line` is
		# still called above so `ui_slot_info_rendered` (QA-asserted) fires.
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
	# Issue #75 item 5b: view.display_name for the target name.
	return _compose_readout(
		head,
		"Target: %s (%d/%d) (%s cycles, %s confirms)" % [UIChrome.bb_escape(view.display_name(target_id)), int(t["hp"]), int(t["max_hp"]), cycle_glyph, confirm_glyph],
		info_line
	)


## Assembles the readout's on-screen text -- head / hint-or-target / slot-info
## -- fitting ONLY the variable-length `info` segment to whatever WRAPPED-LINE
## budget remains in the panel's art-safe capacity after `head` and `hint`
## (design D2-7 #6: cut words, never widen; same discipline `feed_push`
## already applies, generalized to this panel --
## see READOUT_TEXT_WIDTH/HEIGHT's doc comment above for the reproduction and
## the capacity derivation). `head`/`hint` are always render-ready (already
## bb-escaped by their callers above); `info` is the RAW slot-info line --
## escaped here, AFTER fitting, so the fit measures true visible width rather
## than the "[lb]"/"[rb]" escape placeholders' inflated one. `hint` is "" only
## for the dash_confirm caller (whose whole hint lives in `info`'s suffix).
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


## Builds the "what does this button do" line for `info_slot_index` from
## `rendered_slots` (live cost data) and emits `ui_slot_info_rendered` the
## first time this exact (index, text) pair renders (dedup-guard). Returns
## the RAW (un-bb-escaped) line -- `ui_slot_info_rendered` gets the escaped
## form at the emit site (`_readout_text`'s wrap-fit needs
## the true visible width, which the "[lb]"/"[rb]" escape placeholders would
## inflate; QA's exact pin on the ESCAPED text, e.g.
## combat_move_input.json's "[lb]Power Strike[rb] — 3 AP — …", is unchanged
## since the emitted string is still escaped, just later).
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


## Name + costs + one-line canon-voiced description for a single rendered bar
## slot (`d` is one entry of `render_bar_slots()`'s output).
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
## RAW (un-bb-escaped) return value -- escaping belongs to
## each caller (`_render_slot_info_line`'s emit site, `_compose_readout`'s
## post-fit render site) so the wrap-fit measurement below sees the true
## visible width, not the "[lb]"/"[rb]" placeholder-inflated one.
func _slot_info_line(d: Dictionary) -> String:
	match String(d.get("type", "")):
		"attack":
			# GH#70: a bow (weapon_range > 1) reads its live range instead of
			# the melee-only phrasing -- gated strictly on > 1 so every
			# pre-GH#70 combatant (weapon_range defaults to 1) keeps the exact
			# original string, byte-identical.
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
			var record := {
				"ap_cost": d.get("ap_cost", 0),
				"mp_cost": d.get("mp_cost", 0),
				"effect": d.get("effect", {}),
			}
			var effect_lines := WIEffectText.skill_effect_lines(record)
			# Guard the trailing-dash case
			# in BOTH branches (desc empty) -- unreachable today (every
			# shipped active combat skill has a non-empty description) but
			# matching journal.gd's/field_hotbar.gd's identical guard so a
			# future no-description combat skill can't regress this either.
			if desc == "":
				return skill_name if effect_lines.is_empty() else "%s — %s" % [skill_name, effect_lines[0]]
			if effect_lines.is_empty():
				return "%s — %s" % [skill_name, desc]
			return "%s — %s — %s" % [skill_name, effect_lines[0], desc]
		_:
			return ""


## BBCode-escaping (skill display_names like "[Power Strike]") is now
## `UIChrome.bb_escape` (promoted off a per-file copy
## here/journal.gd/targeting_controller.gd -- the M6.5 zero-cross-dependency
## idiom, amended for this one case since this file already references
## UIChrome for its panel chrome, so calling `bb_escape` too adds no new
## dependency). `UIChrome.bb_escape`'s own doc comment covers the
## self-collision bug the placeholder-char technique fixes.


## Issue #75 item 5b: every feed-line name read routes through this instead
## of the raw `combat.combatants[id]["display_name"]` -- `view` (when given;
## see `feed_line_for_event`'s own doc comment) owns the per-encounter A/B/C
## dedup, so a duplicate-name roster reads disambiguated on the feed exactly
## like the turn strip/readout.
func _display_name(combat: WICombat, view: RefCounted, id: String) -> String:
	if view != null:
		return view.display_name(id)
	return String(combat.combatants[id]["display_name"])


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


## Appends `line` to the feed and evicts the OLDEST entries (list-front, per
## design D2-7 #6) until the TOTAL WRAPPED line count fits the panel's real
## capacity -- never raw entry count. A single entry longer than the whole
## panel is truncated with an ellipsis instead of evicting every other entry.
func feed_push(line: String) -> void:
	if line == "":
		return
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


## Verbatim move of `_feed_line_for_event`, taking the raw `combat: WICombat`
## as a parameter (the original derived it internally via
## `_combat_or_null()`) instead of routing through `WICombatView` -- `view`
## has no `.has(id)`-style existence check for a combatant/skill id, and this
## function's every arm defensively guards against a missing id/skill before
## indexing (`combat.combatants.has(...)`/`combat.skills.has(...)`), so it
## reads the raw dictionaries directly, exactly as before. `WICombat` is a
## plain `class_name` (sim-purity rule: no autoload refs), so this static
## type annotation is compile-safe. `view` (issue #75 item 5b, optional --
## every REAL call site passes `combat_screen.gd`'s own `_view`, populated in
## lockstep with `_combat_or_null()`; `null` only matters for API safety) owns
## the per-encounter A/B/C dedup (`WICombatView.display_name`), threaded
## through so a duplicate-name roster reads disambiguated on the feed too,
## matching the turn strip/readout.
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
			if String(payload["skill"]) == "mana_shield":
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
			# The first-encounter surface. TRACED before
			# choosing this surface over a TOAST: combat_hud's own "disjoint
			# opaque bands" doc comment (build(), above) places the readout
			# panel at x[330,950] y[530,642]; message_layer's toast panel is
			# PRESET_BOTTOM_RIGHT with TOAST_OFFSETS_DEFAULT (-472,-130,-24,-34)
			# on a 1280x720 viewport, i.e. x[808,1256] y[590,686] — the two
			# rects genuinely intersect (x[808,950] × y[590,642]), and
			# both parchment panels are opaque, and combat_screen's CanvasLayer
			# is added to the tree AFTER message_layer's (main.gd
			# `_spawn_ui_layers`), so a TOAST fired mid-combat would render
			# behind the readout panel, invisible to the player. The combat
			# feed is the honest surface: WIGame's `_combat_event_relay`
			# enriches this exact event with `first_seen`/`status_text`
			# (generated by L1's `WIEffectText.status_line`, never hand-
			# composed) the moment a status is banked into `seen_statuses`
			# for the first time ever — appended here as a second sentence,
			# once, on top of the terse repeat-application line every future
			# application still gets.
			if bool(payload.get("first_seen", false)):
				line += " " + String(payload.get("status_text", ""))
		WIEvents.STATUS_EXPIRED:
			if combat == null or not combat.combatants.has(String(payload["id"])):
				return ""
			line = "%s shakes it off." % _display_name(combat, view, String(payload["id"]))
		WIEvents.ACTION_REFUSED:
			if combat == null or not combat.combatants.has(String(payload["actor"])):
				return ""
			var refused := _display_name(combat, view, String(payload["actor"]))
			var why := String(payload.get("reason", ""))
			var why_text := "no clear line of sight" if why == "no_los" else ("out of range" if why == "out_of_range" else why.replace("_", " "))
			line = "%s hesitates — %s." % [refused, why_text]
	return line


## Wrapped-line count for `text` at `width` using `label`'s resolved theme
## font/size -- the same TextServer word-wrap layout Label uses under the
## hood (`Font.get_multiline_string_size`), not a guessed character count.
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


## How many wrapped lines `label` actually fits at `height`, from real font
## metrics. Uses the FULL line pitch (font height + the theme's
## `line_spacing` constant) -- see combat_screen.gd's original doc comment
## (moved verbatim) for the windowed-verified regression this fixed.
func _line_capacity(label: Label, height: float) -> int:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	var line_spacing := float(label.get_theme_constant("line_spacing"))
	var pitch := line_height + line_spacing
	return max(int((height + line_spacing) / pitch), 1)


## Cuts whole words (design D2-7 #6: cut words, never widen the UI) and
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


## Resolves the RENDERED line for a tutor entry: `line` unconditionally,
## UNLESS the entry carries the optional `requires_any_class` gate and the
## gate reads false -- then `fallback_line` renders instead, if the entry
## has one. The gate exists for lines whose content presumes progression
## state (e.g. "check your new skill slots") on an arena also reachable
## before that state exists -- the entry's `_comment` in data/arenas.json
## carries the per-line rationale. Entries with no `requires_any_class` key
## always take the plain-`line` branch, unchanged. CONSTRAINTS:
## `_screen._pc_has_any_class()` is a read-only sim query (see that
## wrapper's own doc comment for why this isn't an accomplishment-counter
## gate like `ally_requires`/`door_when` elsewhere in this repo) --
## presentation reads sim state here, never mutates it.
func _tutor_line_text(entry: Dictionary) -> String:
	if bool(entry.get("requires_any_class", false)) and not _screen._pc_has_any_class():
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


## Duplicated from qa/test_driver.gd's `_loosely_equal`.
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


## Renders an already-decided tutor-line match (see `match_tutor_line`):
## pushes `tutor.line` into the feed and emits `ui_tutor_line_rendered
## {beat: id}` via the screen wrapper. `tutor` is `{}` for "no match this
## event" (no-op). Grows the feed panel FIRST (see
## `_grow_feed_panel_for_tutor`) so a long beat never has to fall back to
## feed_push's ordinary cut-with-ellipsis discipline.
func render_tutor_line(tutor: Dictionary) -> void:
	if tutor.is_empty():
		return
	_grow_feed_panel_for_tutor(String(tutor.get("line", "")))
	feed_push(String(tutor.get("line", "")))
	_screen._emit_tutor_rendered(String(tutor.get("id", "")))


## Grows the feed panel (never shrinks -- see `_feed_panel_height`'s doc
## comment) so `text`'s own wrapped-line count clears the parchment fold with
## TUTOR_SAFETY_BUFFER_PX to spare. Fixed-pixel model (needed = text block +
## top content margin + fold danger zone + safety buffer), not the old
## proportional ~70%-of-height fraction -- valid now that FEED_STRIP_FOLD_
## PATCH_BOTTOM pins the fold at a TRUE CONSTANT depth from the panel's own
## bottom edge regardless of how tall the panel grows (see that const's doc
## comment for why the old fraction could still ride the fold on a long
## beat). No-op if `_feed_label` is null (hud built via `hud_script.new(null,
## null,null)` with no `build()` call -- test_combat_visuals.gd's direct
## `reset_tutor_lines`/matcher check exercises exactly that path) or if the
## computed need already fits the panel's current height.
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


## Applies a feed panel height: LEFT/RIGHT/BOTTOM stay fixed (FEED_OFFSET_*),
## TOP is derived so growth always reads upward (same idiom as message_
## layer.gd's toast panel and dialogue_panel.gd's `_fit_panel_height`). No-op
## if `_feed_label` is null (see `_grow_feed_panel_for_tutor`'s doc comment).
func _resize_feed_panel(height: float) -> void:
	if _feed_label == null:
		return
	_feed_panel_height = height
	var panel: Control = _feed_label.get_parent().get_parent()
	panel.custom_minimum_size = Vector2(FEED_PANEL_BASE_SIZE.x, height)
	panel.size = Vector2(FEED_PANEL_BASE_SIZE.x, height)
	UIChrome.set_offsets(panel, FEED_OFFSET_LEFT, FEED_OFFSET_BOTTOM - height, FEED_OFFSET_RIGHT, FEED_OFFSET_BOTTOM)
