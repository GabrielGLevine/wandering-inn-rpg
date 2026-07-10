extends SceneTree
## Contract coverage for combat visual wiring that can run in standalone
## --script mode (UI scripts depend on autoload globals and are exercised by QA).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_visuals.gd
##
## combat_screen.gd's god-file was decomposed into board_renderer.gd
## (D2), combat_playback.gd (D3), and targeting_controller.gd/combat_hud.gd
## (D4). This file's checks were reworked to follow the logic to its REAL new
## home rather than keep asserting raw-source substrings against
## combat_screen.gd for code that no longer lives there -- see the D4 task
## report's assertion rework table for the full old -> new mapping.
## `targeting_controller.gd`/`combat_hud.gd` carry ZERO bare autoload
## identifiers (the established D3 idiom), so unlike `board_renderer.gd`
## (which references ObservableBus/TestDriver directly and can only be
## contract-checked via raw-source slicing, same as combat_screen.gd) they
## can be `load()`+`.new()`'d directly here for real behavioral checks.


func _init() -> void:
	WITestWatchdog.arm(self)
	var combatants: Dictionary = _load_json("res://data/combatants.json")
	var pc_cfg := _combatant_config(combatants, "pc")
	assert(String(pc_cfg.get("sprite", "")) == "body_a", "pc combatant declares Body_A sprite")

	var body_frames := WISpriteRegistry.frames_for("body_a")
	for anim_name: String in ["idle_side", "slice_side", "hit_side", "death_side"]:
		assert(body_frames.has_animation(anim_name), "body_a missing combat animation: " + anim_name)

	# combat_screen.gd references the ObservableBus/Game autoloads directly
	# (e.g. `ObservableBus.domain_event.connect(...)` in _ready, `Game.sim.combat`
	# in _combat()). A plain preload() of that file fails to COMPILE under bare
	# --script mode, not just to run: GDScript's whole-class semantic pass
	# resolves every identifier in every method up front, and --script mode
	# never registers autoload singletons in the compiler's global symbol
	# table (this is the same "autoloads don't resolve as bare identifiers in
	# --script mode" gotcha documented in CLAUDE.md — confirmed empirically:
	# even preloading game.gd itself, an autoload, fails the same way here).
	# Work around it by compiling an in-memory patched copy that shadows those
	# two names with inert instance vars so every reference resolves to a
	# harmless Variant instead of an unresolved global; no other line changes,
	# and the real on-disk file is untouched.
	var raw_source := FileAccess.get_file_as_string("res://src/combat/combat_screen.gd")
	assert(raw_source.find("_hp_labels") == -1, "combat HP numerals must not be stored as in-board Label nodes")
	# The hotbar replaces the MENU/SKILL_PICK text lists -- assert the
	# old list-building machinery is actually gone, not just that a new method
	# exists alongside it (a partial migration that left both would still pass
	# a purely-additive check).
	# Checks the actual enum reference, not the bare substring "SKILL_PICK" --
	# this file's own doc comments mention the removed mode by name.
	assert(raw_source.find("Mode.SKILL_PICK") == -1, "Mode.SKILL_PICK must be removed -- hotbar skill slots target directly")
	# Declaration-shaped needles, not bare substrings -- this file's own
	# comments reference both retired names in prose while explaining why
	# they're gone.
	assert(raw_source.find("var _menu_items") == -1, "the old MENU text-list array must be removed")
	assert(raw_source.find("var _skill_ids") == -1, "the old SKILL_PICK id list must be removed")
	# The dedicated Move mode is gone --
	# arrows step the active unit directly from the hotbar resting state.
	# Declaration-shaped needles again (prose in combat_screen.gd's comments
	# says "Move mode"/"Move slot", never the literal enum member).
	assert(raw_source.find("Mode.MOVE") == -1, "Mode.MOVE must be deleted -- arrows move directly (M5 H2)")
	assert(raw_source.find("Mode.MENU") == -1, "Mode.MENU was renamed to Mode.HOTBAR in M5 H2")
	assert(raw_source.find("Mode.HOTBAR") != -1, "Mode.HOTBAR must exist -- the player's resting turn state")
	assert(raw_source.find("func _input_move") == -1, "the dedicated Move-mode input handler must be removed")
	assert(raw_source.find("\"type\": \"move\"") == -1, "the interim unnumbered Move bar slot must be removed")
	var hotbar_input_body := raw_source.get_slice("func _input_hotbar", 1).get_slice("func ", 0)
	assert(hotbar_input_body.find("_move_active_or_bump") != -1, "hotbar-mode arrows must move the active unit directly")
	# Controller support deliberately reopened this: a pad has
	# no number keys, so `slot_prev`/`slot_next` move a cursor into `_bar_index`
	# and `confirm` activates whatever it points at. The movement-first contract this
	# used to assert outright ("no Enter-confirms-highlight branch") still
	# holds for KEYBOARD play -- `_bar_index` stays -1 unless a pad cursor
	# press set it, so Enter alone (no prior slot_prev/next) remains inert,
	# exactly as before. Assert the guard exists instead of banning "confirm"
	# outright.
	assert(hotbar_input_body.find("event.is_action_pressed(\"confirm\") and _bar_index >= 0") != -1, "hotbar mode's confirm branch must stay pad-cursor-gated -- unconditional Enter-confirms-highlight would break M5 H2's number-key-only keyboard contract")
	# M5 arch: emit sites use WIEvents StringName consts (the bus string is
	# unchanged -- WIEvents.UI_HOTBAR_RENDERED is &"ui_hotbar_rendered").
	# ui_hotbar_rendered still fires from combat_screen.gd's own
	# _apply_turn_started (the HUD extraction did not move turn-start lifecycle).
	assert(raw_source.find("WIEvents.UI_HOTBAR_RENDERED") != -1, "combat screen must emit ui_hotbar_rendered for QA")
	# combat_screen.gd is the composition
	# root for keycap hints too now (WIInputHints.label() calls in _refresh()/
	# _apply_combat_finished()) -- stub it alongside the other three autoloads.
	var patched_source := raw_source.replace(
		"extends CanvasLayer",
		"extends CanvasLayer\n\nvar ObservableBus: Variant = null\nvar Game: Variant = null\nvar TestDriver: Variant = null\nvar WIInputHints: Variant = null",
	)
	var patched_script := GDScript.new()
	patched_script.source_code = patched_source
	var compile_err := patched_script.reload()
	assert(compile_err == OK, "combat_screen.gd (autoload-stubbed copy) failed to compile: %d" % compile_err)
	var screen: CanvasLayer = patched_script.new()
	# `_make_combatant_visual`/`_visual_for`/`_world_labels` (D2-era
	# dead-code compat shims) were DELETED from combat_screen.gd -- the real
	# implementations they used to delegate to (`WICombatBoardRenderer.
	# make_combatant_visual`/`visual_for`, and the labels-publish contract)
	# are checked against board_renderer.gd directly below instead, their
	# real home. `_play_combatant_anim`/`_flash_cells` stay real, unmoved
	# functions on combat_screen.gd (still called by `_play_event_visual`),
	# so their has_method checks stay here.
	for method_name: String in [
		"_play_combatant_anim",
		"_flash_cells",
		"_skill_flash_cells",
		"_skill_flash_color",
		"_capture_playback_event",
		"_activate_bar_slot",
		"_numbered_slot_pressed",
		"_input_hotbar",
	]:
		assert(screen.has_method(method_name), "combat_screen missing method: " + method_name)
	assert(screen.AI_BEAT_SECONDS == 0.5, "AI playback beat changed unexpectedly")
	var captured: Dictionary = screen._capture_playback_event("attack_resolved", {
		"attacker": "pc", "target": "goblin", "hit": true, "damage": 1,
	})
	assert((captured["payload"] as Dictionary).has("_ui"), "queued playback event does not carry captured UI data")
	assert(((captured["payload"] as Dictionary)["_ui"] as Dictionary).has("feed_line"), "queued playback event does not capture feed text")
	assert(screen.FROST_FLASH == Color(0.5, 0.8, 1.0), "FROST_FLASH const changed unexpectedly")
	assert(screen.FLAME_FLASH == Color(1.0, 0.45, 0.15), "FLAME_FLASH const changed unexpectedly")
	assert(screen.SHIELD_FLASH == Color(0.4, 0.6, 1.0), "SHIELD_FLASH const changed unexpectedly")
	screen.free()

	# board_renderer.gd (D2) is the REAL new home of the combatant-
	# visual builder + the WorldLabels-publish contract this test used to
	# check against combat_screen.gd's now-deleted dead-code shims. It
	# references ObservableBus/TestDriver directly (same as combat_screen.gd),
	# so it's checked the same way: raw-source slicing, not load()+instantiate.
	var board_renderer_source := FileAccess.get_file_as_string("res://src/combat/board_renderer.gd")
	assert(not board_renderer_source.is_empty(), "board_renderer.gd must exist")
	assert(board_renderer_source.find("func make_combatant_visual") != -1, "board renderer must define make_combatant_visual (moved from combat_screen.gd, M6.5 D2)")
	assert(board_renderer_source.find("func visual_for") != -1, "board renderer must define visual_for (moved from combat_screen.gd, M6.5 D2)")
	# Accurate slice boundary (the combat_screen.gd version of this check used
	# a stale D1-era marker, "func _make_tile_layer", that no longer exists in
	# either file post-D1 -- fixed here rather than perpetuated: `_biome_for_
	# combat` is the function that genuinely follows `make_combatant_visual`
	# in board_renderer.gd today).
	var combatant_visual_body := board_renderer_source.get_slice("func make_combatant_visual", 1).get_slice("func _biome_for_combat", 0)
	assert(combatant_visual_body.find("Label.new()") == -1, "combatant visual builder must not create in-board text labels")
	assert(board_renderer_source.find("_hp_labels") == -1, "combat HP numerals must not be stored as in-board Label nodes")
	assert(board_renderer_source.find("_world_labels()") != -1, "board renderer must publish combat labels through WorldLabels")
	assert(board_renderer_source.find("rebuild_context") != -1, "board renderer must publish labels via WIWorldLabels.rebuild_context")

	# targeting_controller.gd/combat_hud.gd carry ZERO bare autoload
	# identifiers by design (same idiom D3 established for combat_playback.gd)
	# -- unlike combat_screen.gd/board_renderer.gd, they can be load()+
	# instantiated directly here for real behavioral checks, not just
	# raw-source slicing.
	var targeting_script := load("res://src/combat/targeting_controller.gd") as Script
	assert(targeting_script != null and targeting_script.can_instantiate(), "targeting_controller.gd must compile standalone (zero bare autoload identifiers)")
	var targeting: RefCounted = targeting_script.new(null, null)
	assert(not targeting.has_valid_target(), "a fresh targeting controller has no target before enter() is called")
	targeting.cancel()
	var targeting_state: Dictionary = targeting.state()
	assert((targeting_state.get("targets", []) as Array).is_empty(), "targeting state starts with no targets")
	assert(targeting_state.has("line_mode") and targeting_state.has("skill_id"), "targeting state must expose line_mode/skill_id for the HUD readout")

	# test_combat_sim.gd's c57/c58/
	# c59 blocks already prove `WICombat.use_skill("sneak", "pc")` resolves the
	# self-cast directly -- but that calls `use_skill` with a hand-picked
	# target_id, bypassing `WICombatTargeting.enter()` entirely. Nothing
	# proved `enter()` ITSELF ever produces the self-target list through the
	# real UI dispatch path (`enter()` -> `state().targets` -> `confirm()` ->
	# `combat.use_skill(...)`). Proven here with a REAL `WICombat`/
	# `WICombatView` (both plain `class_name` scripts, zero bare autoloads,
	# constructible directly in --script mode -- same idiom test_combat_sim.gd
	# already uses) plus a minimal stub `_screen` (a bare `Node` with only the
	# one method `enter()` calls, `_emit_targeting_shown_event` -- a no-op, so
	# it never touches ObservableBus and needs none of combat_screen.gd's own
	# autoload-stub patching above).
	var stub_screen_script := GDScript.new()
	stub_screen_script.source_code = "extends Node\nfunc _emit_targeting_shown_event(_mode_text: String, _skill_id: String, _target_count: int) -> void:\n\tpass\n"
	var stub_screen_compile_err := stub_screen_script.reload()
	assert(stub_screen_compile_err == OK, "stub targeting screen failed to compile: %d" % stub_screen_compile_err)
	var stub_screen: Node = stub_screen_script.new()

	var tc_combatants: Dictionary = _load_json("res://data/combatants.json")
	var tc_arena: Dictionary = _load_json("res://data/arenas.json")["arenas"][0]
	var tc_skills: Dictionary = _load_json("res://data/skills.json")
	var tc_pc_cfg: Dictionary = (_combatant_config(tc_combatants, "pc") as Dictionary).duplicate(true)
	tc_pc_cfg["skills"] = ["sneak", "quick_movement"]
	var tc_goblin_cfg: Dictionary = (_combatant_config(tc_combatants, "goblin_raider") as Dictionary).duplicate(true)
	var tc_combat := WICombat.new(tc_arena, [tc_pc_cfg, tc_goblin_cfg], tc_skills, func(_t: String, _p: Dictionary) -> void: pass, 9)
	tc_combat.begin()
	tc_combat.active_index = tc_combat.turn_order.find("pc")
	tc_combat._start_turn()
	var tc_view := WICombatView.new(tc_combat)

	# (1) [Stealth] (ap_cost 1 > 0): enter() must take the self-target shortcut.
	var sneak_targeting: RefCounted = targeting_script.new(tc_view, stub_screen)
	sneak_targeting.enter(0, "sneak")
	assert((sneak_targeting.state()["targets"] as Array) == ["pc"], "enter() must yield the self-target list [pc] for sneak's ap_cost>0 move_pool_bonus cast")
	assert(sneak_targeting.has_valid_target(), "the self-target list must read as a valid confirmable target (Tab/Enter gate)")
	var sneak_action: Dictionary = sneak_targeting.confirm()
	assert(sneak_action == {"kind": "skill", "skill_id": "sneak", "target_id": "pc"}, "confirm() must return the self-cast action dict exactly like a real enemy pick")
	var tc_pool_before := int(tc_combat.combatants["pc"]["move_pool"])
	assert(tc_combat.use_skill(String(sneak_action["skill_id"]), String(sneak_action["target_id"])), "the action confirm() returns must actually resolve through the real combat")
	assert(int(tc_combat.combatants["pc"]["move_pool"]) == tc_pool_before + 2, "the targeting-controller-driven cast must grant sneak's +2 move_pool through resolve_active")

	# (2) [Quick Movement] (ap_cost 0): enter() must NOT self-target -- the
	# ap_cost>0 gate (kept in lockstep with skill_effects.gd's resolve_active
	# gate, per both files' cross-referencing doc comments) must leave this
	# PRE-EXISTING 0-cost move_pool_bonus skill falling through to the normal
	# enemy-gated filter, exactly as before K2 -- never the self-buff shortcut.
	var quick_targeting: RefCounted = targeting_script.new(tc_view, stub_screen)
	quick_targeting.enter(0, "quick_movement")
	var quick_targets: Array = quick_targeting.state()["targets"]
	assert(not quick_targets.has("pc"), "enter() must NOT self-target for quick_movement (ap_cost 0) -- a self-target here would silently reopen the free-pool exploit the ap_cost>0 gate exists to close")
	stub_screen.free()

	var hud_script := load("res://src/combat/combat_hud.gd") as Script
	assert(hud_script != null and hud_script.can_instantiate(), "combat_hud.gd must compile standalone (zero bare autoload identifiers)")
	for method_name: String in ["build", "refresh", "rebuild_slots", "render_bar_slots", "feed_push", "feed_line_for_event", "reset_tutor_lines", "match_tutor_line", "render_tutor_line", "show_banner", "clear_feed"]:
		assert(hud_script.new(null, null, null).has_method(method_name), "combat HUD missing method: " + method_name)
	# Real behavioral check of the tutor-line matcher (the counting half)
	# -- moved verbatim from combat_screen.gd, still must fire on its declared
	# event and never re-fire once matched.
	var hud_logic: RefCounted = hud_script.new(null, null, null)
	hud_logic.reset_tutor_lines({"tutor_lines": [{"id": "t1", "on": {"event": "combat_started"}, "line": "Begin!"}]})
	var matched: Dictionary = hud_logic.match_tutor_line("combat_started", {})
	assert(String(matched.get("id", "")) == "t1", "tutor line matching must fire on its declared event")
	assert(hud_logic.match_tutor_line("combat_started", {}).is_empty(), "a fired tutor line must not re-fire")
	# `requires_any_class`/`fallback_line` contract: a gated tutor entry
	# must render its FALLBACK when `_screen._pc_has_any_class()` reads
	# false, and its normal `line` unchanged when true -- proven against
	# real class stub screens, not just the raw-source presence of the keys.
	var class_stub_script := GDScript.new()
	class_stub_script.source_code = "extends Node\nvar has_class: bool = false\nfunc _pc_has_any_class() -> bool:\n\treturn has_class\n"
	assert(class_stub_script.reload() == OK, "class-gate stub screen failed to compile")
	var no_class_screen: Node = class_stub_script.new()
	no_class_screen.has_class = false
	var gated_hud_no_class: RefCounted = hud_script.new(null, null, no_class_screen)
	gated_hud_no_class.reset_tutor_lines({"tutor_lines": [{
		"id": "real_ones", "on": {"event": "combat_started"}, "requires_any_class": true,
		"line": "Relc: you slept.", "fallback_line": "Relc: you haven't slept.",
	}]})
	var no_class_match: Dictionary = gated_hud_no_class.match_tutor_line("combat_started", {})
	assert(String(no_class_match.get("line", "")) == "Relc: you haven't slept.", "requires_any_class gate must render fallback_line when the PC has no class yet")
	var has_class_screen: Node = class_stub_script.new()
	has_class_screen.has_class = true
	var gated_hud_has_class: RefCounted = hud_script.new(null, null, has_class_screen)
	gated_hud_has_class.reset_tutor_lines({"tutor_lines": [{
		"id": "real_ones", "on": {"event": "combat_started"}, "requires_any_class": true,
		"line": "Relc: you slept.", "fallback_line": "Relc: you haven't slept.",
	}]})
	var has_class_match: Dictionary = gated_hud_has_class.match_tutor_line("combat_started", {})
	assert(String(has_class_match.get("line", "")) == "Relc: you slept.", "requires_any_class gate must render the normal line once the PC has a class")
	# Control: an UNGATED entry (every pre-existing tutor_lines entry) must
	# stay byte-identical -- no _pc_has_any_class call, no behavior change.
	assert(String(matched.get("line", "")) == "Begin!", "an ungated tutor entry must render its plain line untouched")
	no_class_screen.free()
	has_class_screen.free()
	# Real behavioral check that build() actually instantiates the hotbar
	# under a real Control root (the direct replacement for the old
	# raw-source "HOTBAR_SCRIPT" substring check against combat_screen.gd --
	# HOTBAR_SCRIPT lives in combat_hud.gd).
	var fake_root := Control.new()
	var hud_visual: RefCounted = hud_script.new(fake_root, null, null)
	hud_visual.build()
	var found_hotbar := false
	for child: Node in fake_root.get_children():
		if child is WIHotbar:
			found_hotbar = true
	assert(found_hotbar, "combat HUD build() must instantiate the hotbar under its root")
	fake_root.free()

	# rebuild_slots' new 3rd `loadout` arg. AUTO (the
	# default `[]`, exactly the pre-K2b 2-arg call every OTHER call site in
	# this repo still uses) must be byte-identical to the old order; a
	# non-empty loadout reorders/filters ONLY the kit-skill run (slots 3+) --
	# Attack/Dash stay hard-pinned at 1/2 regardless.
	var k2b_combatants: Dictionary = _load_json("res://data/combatants.json")
	var k2b_arena: Dictionary = _load_json("res://data/arenas.json")["arenas"][0]
	var k2b_skills: Dictionary = _load_json("res://data/skills.json")
	var k2b_pc_cfg: Dictionary = (_combatant_config(k2b_combatants, "pc") as Dictionary).duplicate(true)
	k2b_pc_cfg["skills"] = ["power_strike", "frost_bolt", "second_wind"]
	var k2b_goblin_cfg: Dictionary = (_combatant_config(k2b_combatants, "goblin_raider") as Dictionary).duplicate(true)
	var k2b_combat := WICombat.new(k2b_arena, [k2b_pc_cfg, k2b_goblin_cfg], k2b_skills, func(_t: String, _p: Dictionary) -> void: pass, 9)
	k2b_combat.begin()
	k2b_combat.active_index = k2b_combat.turn_order.find("pc")
	k2b_combat._start_turn()
	var k2b_view := WICombatView.new(k2b_combat)
	var k2b_hud: RefCounted = hud_script.new(null, null, null)

	var auto_slots: Array = k2b_hud.rebuild_slots(k2b_view, "pc")
	var auto_ids: Array = []
	for s: Dictionary in auto_slots:
		auto_ids.append(String(s.get("id", s["type"])))
	assert(auto_ids == ["attack", "dash", "power_strike", "frost_bolt", "second_wind", "end_turn"], "AUTO (no 3rd arg) rebuild_slots is byte-identical to the pre-K2b order")

	var loaded_slots: Array = k2b_hud.rebuild_slots(k2b_view, "pc", ["second_wind", "power_strike"])
	var loaded_ids: Array = []
	for s: Dictionary in loaded_slots:
		loaded_ids.append(String(s.get("id", s["type"])))
	assert(loaded_ids == ["attack", "dash", "second_wind", "power_strike", "end_turn"], "a non-empty loadout reorders the kit run to LOADOUT order and drops frost_bolt (unslotted) -- Attack/Dash stay pinned at 1/2")
	assert(String(loaded_slots[0]["key_hint"]) == "1" and String(loaded_slots[1]["key_hint"]) == "2", "Attack/Dash key hints stay 1/2 regardless of the loadout")
	assert(String(loaded_slots[2]["key_hint"]) == "3" and String(loaded_slots[3]["key_hint"]) == "4", "kit slots renumber from 3 in the FILTERED order")

	var world_labels_source := FileAccess.get_file_as_string("res://src/ui/world_labels.gd")
	assert(not world_labels_source.is_empty(), "world_labels.gd must exist")
	var world_labels_script := load("res://src/ui/world_labels.gd") as Script
	assert(world_labels_script != null and world_labels_script.can_instantiate(), "world_labels.gd must compile")

	# hotbar.gd is pure rendering (no autoload references), so unlike
	# combat_screen.gd/test_driver.gd above it can be loaded directly without
	# the autoload-stub patching dance.
	var hotbar_source := FileAccess.get_file_as_string("res://src/ui/hotbar.gd")
	assert(not hotbar_source.is_empty(), "hotbar.gd must exist")
	var hotbar_script := load("res://src/ui/hotbar.gd") as Script
	assert(hotbar_script != null and hotbar_script.can_instantiate(), "hotbar.gd must compile")
	var hotbar_instance: Control = hotbar_script.new()
	assert(hotbar_instance.has_method("render"), "hotbar.gd missing render() -- combat_screen's public entry point")
	hotbar_instance.free()

	var world_source := FileAccess.get_file_as_string("res://src/world/world.gd")
	var entity_visual_body := world_source.get_slice("func _make_entity_visual", 1).get_slice("func _count_visual", 0)
	assert(entity_visual_body.find("Label.new()") == -1, "field entity visual builder must not create in-board text labels")
	# Field name tags are RETIRED (spec §8 addendum) -- world.gd
	# must no longer touch WIWorldLabels/publish ui_world_labels_rendered at
	# all (that event retired entirely; combat's HP/MP stat readout still
	# rides WIWorldLabels but ONLY from board_renderer.gd, checked above).
	assert(world_source.find("_world_labels()") == -1, "world.gd must not publish field labels through WorldLabels -- field labels are retired (M-BEAUTY R3)")
	assert(world_source.find("WIWorldLabels") == -1, "world.gd must not reference WIWorldLabels at all -- field labels are retired (M-BEAUTY R3)")
	assert(world_source.find("UI_WORLD_LABELS_RENDERED") == -1, "ui_world_labels_rendered is retired -- world.gd must not emit it")
	# The visual_states seam (spec §8 pt.2) that REPLACES a label's "state
	# changed" affordance for props like dirty_table/inn_chest/unlit_lantern.
	assert(world_source.find("func _resolve_entity_render") != -1, "world.gd must define _resolve_entity_render (visual_states resolution, M-BEAUTY R3)")
	assert(world_source.find("func _refresh_entity_visual") != -1, "world.gd must define _refresh_entity_visual (single-prop re-render, M-BEAUTY R3)")
	assert(world_source.find("WIEvents.ACCOMPLISHMENT_RECORDED") != -1, "world.gd must listen for ACCOMPLISHMENT_RECORDED to drive visual_states re-renders")

	var board_renderer_source_r3 := FileAccess.get_file_as_string("res://src/combat/board_renderer.gd")
	assert(board_renderer_source_r3.find("UI_WORLD_LABELS_RENDERED") == -1, "ui_world_labels_rendered is retired -- board_renderer.gd must not emit it")
	var combat_label_body := board_renderer_source_r3.get_slice("func _rebuild_combat_labels", 1).get_slice("func _label_id", 0)
	assert(combat_label_body.find("\"name\"") == -1, "combat labels must not publish a name field -- combat name tags are retired (M-BEAUTY R3), only the HP/MP stats readout survives")

	# TERRAIN_ADDED/TERRAIN_EXPIRED are BOARD
	# STATE, not transient juice -- combat_playback.gd's `_apply_playback_event`
	# must route them to `_screen._play_event_visual` even on the SKIP-forward
	# path (`with_visuals == false`), the COMBATANT_MOVED idiom, because the
	# renderer's persistent terrain overlays have no post-drain resync to
	# recover a skipped mutation (unlike combatant position/HP/MP). Proven
	# behaviorally: combat_playback.gd carries zero bare autoload identifiers
	# (its own doc-comment contract), so it loads+instantiates directly here
	# with a RECORDING stub screen; the skip path is unreachable under QA
	# (beat_delay()==0 under TestDriver), so this unit check is the only
	# automated coverage the skip branch can ever get.
	var playback_script := load("res://src/combat/combat_playback.gd") as Script
	assert(playback_script != null and playback_script.can_instantiate(), "combat_playback.gd must compile standalone (zero bare autoload identifiers)")
	var recorder_script := GDScript.new()
	recorder_script.source_code = "extends Node\nvar visual_calls: Array = []\nfunc _play_event_visual(type: String, _payload: Dictionary) -> void:\n\tvisual_calls.append(type)\nfunc _push_feed(_payload: Dictionary) -> void:\n\tpass\nfunc _render_tutor_line(_tutor: Dictionary) -> void:\n\tpass\nfunc _refresh() -> void:\n\tpass\n"
	assert(recorder_script.reload() == OK, "recording stub screen failed to compile")
	var recorder: Node = recorder_script.new()
	var playback: RefCounted = playback_script.new(null, recorder)
	var terrain_cells := [[6, 2], [6, 3]]
	# with_visuals == false IS the skip-fast-forward path (drain()'s
	# `_apply_playback_event(rest, false)` loop after request_skip()).
	playback._apply_playback_event({"type": "terrain_expired", "payload": {"kind": "icy_floor", "cells": terrain_cells, "_ui": {}}}, false)
	playback._apply_playback_event({"type": "terrain_added", "payload": {"kind": "icy_floor", "cells": terrain_cells, "rounds": 2, "_ui": {}}}, false)
	assert(recorder.visual_calls == ["terrain_expired", "terrain_added"], "TERRAIN_ADDED/TERRAIN_EXPIRED must reach _play_event_visual even when skip-fast-forwarded (with_visuals=false) -- they mutate persistent renderer state, the COMBATANT_MOVED class, not VFX")
	# Control: a VFX-class event (skill_resolved) must still be visual-gated
	# on the skip path -- the fix must not have widened the gate wholesale.
	playback._apply_playback_event({"type": "skill_resolved", "payload": {"actor": "pc", "skill": "frost_bolt", "target": "goblin_raider", "_ui": {}}}, false)
	assert(recorder.visual_calls == ["terrain_expired", "terrain_added"], "VFX-class events (skill_resolved) stay gated behind with_visuals on the skip path -- the terrain fix is surgical, not a wholesale gate removal")
	recorder.free()

	# Dead-actor re-flash guard: `_highlight_actor` must never re-flash a
	# combatant already marked `death_visible`. TRAP being covered:
	# `_actor_id_for_event` has no dedicated COMBATANT_DOWNED case, so it
	# names the DOWNED unit itself as "actor", and that same unit's own
	# trailing bookkeeping event in the SAME AI-turn batch (its own
	# turn_ended, which still fires when it died mid-turn to a
	# reaction/counter-strike) would otherwise re-trigger the
	# bright-flash-then-white tween on the SAME node the death fade
	# (fade_chip) is already animating, snapping modulate back to opaque.
	# Stub renderer only implements the two methods `_highlight_actor`
	# actually calls (`visual_for`/`death_visible`); a real in-tree screen
	# stub lets `_screen.create_tween()` succeed if the guard is EVER
	# reached (it must not be, for the dead case).
	var hl_renderer_script := GDScript.new()
	hl_renderer_script.source_code = "extends Node\nvar dead: bool = false\nvar visual: Node2D\nfunc visual_for(_id: String) -> Node2D:\n\treturn visual\nfunc death_visible(_id: String) -> bool:\n\treturn dead\n"
	assert(hl_renderer_script.reload() == OK, "stub highlight renderer failed to compile")
	var hl_renderer: Node = hl_renderer_script.new()
	var hl_visual := Node2D.new()
	var post_fade_modulate := Color(1.0, 1.0, 1.0, 0.28)  # fade_chip's own end value
	hl_visual.modulate = post_fade_modulate
	hl_renderer.visual = hl_visual
	hl_renderer.dead = true
	var hl_screen := Node.new()
	root.add_child(hl_screen)
	var hl_playback: RefCounted = playback_script.new(hl_renderer, hl_screen)
	hl_playback._highlight_actor({"payload": {"_ui": {"actor_id": "raskghar_scout"}}})
	assert(hl_visual.modulate.is_equal_approx(post_fade_modulate), "_highlight_actor must NOT touch modulate for an already-dead combatant -- would undo its death fade")
	# Control: a LIVE combatant still gets the highlight bump -- the fix must
	# be surgical (death-visible guard only), not a wholesale disable.
	hl_renderer.dead = false
	hl_playback._highlight_actor({"payload": {"_ui": {"actor_id": "raskghar_scout"}}})
	assert(not hl_visual.modulate.is_equal_approx(post_fade_modulate), "_highlight_actor must still flash a LIVE combatant")
	# Direct free() (not queue_free -- this script's own SceneTree quits
	# synchronously right after this function returns, before a deferred free
	# would ever run, leaking the ObjectDB entry), same idiom this file's
	# other bare-Node stubs already use (driver.free()/recorder.free()/
	# fake_root.free() above).
	root.remove_child(hl_screen)
	hl_screen.free()
	hl_visual.free()
	hl_renderer.free()

	var driver_source := FileAccess.get_file_as_string("res://qa/test_driver.gd").replace(
		"extends Node",
		"extends Node\n\nvar ObservableBus: Variant = null\nvar QAPaths: Variant = null\nvar Game: Variant = null\nvar WICombatAI: Variant = null",
	)
	assert(driver_source.find("SCREENSHOT_SETTLE_SECONDS") != -1, "TestDriver must define screenshot settle wait")
	var driver_script := GDScript.new()
	driver_script.source_code = driver_source
	var driver_compile_err := driver_script.reload()
	assert(driver_compile_err == OK, "test_driver.gd (autoload-stubbed copy) failed to compile: %d" % driver_compile_err)
	var driver: Node = driver_script.new()
	assert(driver.has_method("active"), "TestDriver missing active() helper")
	assert(driver.active() == false, "TestDriver.active() should be false before a QA script is loaded")
	driver.free()

	print("PASS: combat visual contracts are wired")
	quit(0)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _combatant_config(catalog: Dictionary, id: String) -> Dictionary:
	for c: Dictionary in catalog["combatants"]:
		if String(c["id"]) == id:
			return c
	return {}
