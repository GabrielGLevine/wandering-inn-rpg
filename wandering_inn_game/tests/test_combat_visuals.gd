extends SceneTree
## Contract coverage for combat visual wiring that can run in standalone
## --script mode (UI scripts depend on autoload globals and are exercised by QA).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_visuals.gd
##
## M6.5 D4: combat_screen.gd's god-file was decomposed into board_renderer.gd
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
	# M5 H1: the hotbar replaces the MENU/SKILL_PICK text lists -- assert the
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
	# M5 H2 (movement-first, consultant B4): the dedicated Move mode is gone --
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
	assert(hotbar_input_body.find("confirm") == -1, "hotbar mode must not have an Enter-confirms-highlight branch (slots are number-key activated)")
	# M5 arch: emit sites use WIEvents StringName consts (the bus string is
	# unchanged -- WIEvents.UI_HOTBAR_RENDERED is &"ui_hotbar_rendered").
	# ui_hotbar_rendered still fires from combat_screen.gd's own
	# _apply_turn_started (M6.5 D4 did not move turn-start lifecycle).
	assert(raw_source.find("WIEvents.UI_HOTBAR_RENDERED") != -1, "combat screen must emit ui_hotbar_rendered for QA")
	var patched_source := raw_source.replace(
		"extends CanvasLayer",
		"extends CanvasLayer\n\nvar ObservableBus: Variant = null\nvar Game: Variant = null\nvar TestDriver: Variant = null",
	)
	var patched_script := GDScript.new()
	patched_script.source_code = patched_source
	var compile_err := patched_script.reload()
	assert(compile_err == OK, "combat_screen.gd (autoload-stubbed copy) failed to compile: %d" % compile_err)
	var screen: CanvasLayer = patched_script.new()
	# M6.5 D4: `_make_combatant_visual`/`_visual_for`/`_world_labels` (D2-era
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

	# M6.5 D4: board_renderer.gd (D2) is the REAL new home of the combatant-
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

	# M6.5 D4: targeting_controller.gd/combat_hud.gd carry ZERO bare autoload
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

	var hud_script := load("res://src/combat/combat_hud.gd") as Script
	assert(hud_script != null and hud_script.can_instantiate(), "combat_hud.gd must compile standalone (zero bare autoload identifiers)")
	for method_name: String in ["build", "refresh", "rebuild_slots", "render_bar_slots", "feed_push", "feed_line_for_event", "reset_tutor_lines", "match_tutor_line", "render_tutor_line", "show_banner", "clear_feed"]:
		assert(hud_script.new(null, null, null).has_method(method_name), "combat HUD missing method: " + method_name)
	# Real behavioral check of the tutor-line matcher (M-FP F's counting half)
	# -- moved verbatim from combat_screen.gd, still must fire on its declared
	# event and never re-fire once matched.
	var hud_logic: RefCounted = hud_script.new(null, null, null)
	hud_logic.reset_tutor_lines({"tutor_lines": [{"id": "t1", "on": {"event": "combat_started"}, "line": "Begin!"}]})
	var matched: Dictionary = hud_logic.match_tutor_line("combat_started", {})
	assert(String(matched.get("id", "")) == "t1", "tutor line matching must fire on its declared event")
	assert(hud_logic.match_tutor_line("combat_started", {}).is_empty(), "a fired tutor line must not re-fire")
	# Real behavioral check that build() actually instantiates the hotbar
	# under a real Control root (the direct replacement for the old
	# raw-source "HOTBAR_SCRIPT" substring check against combat_screen.gd --
	# HOTBAR_SCRIPT moved to combat_hud.gd in M6.5 D4).
	var fake_root := Control.new()
	var hud_visual: RefCounted = hud_script.new(fake_root, null, null)
	hud_visual.build()
	var found_hotbar := false
	for child: Node in fake_root.get_children():
		if child is WIHotbar:
			found_hotbar = true
	assert(found_hotbar, "combat HUD build() must instantiate the hotbar under its root")
	fake_root.free()

	var world_labels_source := FileAccess.get_file_as_string("res://src/ui/world_labels.gd")
	assert(not world_labels_source.is_empty(), "world_labels.gd must exist")
	var world_labels_script := load("res://src/ui/world_labels.gd") as Script
	assert(world_labels_script != null and world_labels_script.can_instantiate(), "world_labels.gd must compile")

	# M5 H1: hotbar.gd is pure rendering (no autoload references), so unlike
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
	# M-BEAUTY R3 (spec §8 addendum): field name tags are RETIRED -- world.gd
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
