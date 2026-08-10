extends SceneTree


func _occurrence_count(source: String, needle: String) -> int:
	return source.split(needle).size() - 1


func _y_sort_contract_holds(source: String, factory_source: String) -> bool:
	# #194b seam 1: construction body lives in WIEntityVisualFactory.make();
	# the override-read call sites stay in world.gd.
	var make_body := factory_source.get_slice("func make(", 1).get_slice("\nfunc ", 0)
	if make_body.find("field_y_sort_bias_override is float or field_y_sort_bias_override is int") == -1:
		return false
	if make_body.find("else float(catalog_entry.get(\"field_y_sort_bias_px\", 0.0))") == -1:
		return false
	if make_body.find("holder.position.y += y_sort_bias") == -1:
		return false
	if make_body.find("CELL - anchor.y * frame_size.y * spr.scale.y - y_sort_bias") == -1:
		return false
	if make_body.find("shadow.position = Vector2(CELL * 0.5, CELL - 2.0 - y_sort_bias)") == -1:
		return false
	var override_read := "ent.get(\"field_y_sort_bias_px\", null)"
	if _occurrence_count(source, override_read) != 3:
		return false
	# Trailing "(" so a name can never prefix-match a LONGER one
	# (_reconcile_entity_presence vs _reconcile_entity_presence_or_defer, added
	# by v0.15 T4.3 round 2's dialogue defer).
	for function_name: String in ["_build_entities", "_refresh_entity_visual", "_reconcile_entity_presence"]:
		var function_body := source.get_slice("func %s(" % function_name, 1).get_slice("\nfunc ", 0)
		if function_body.find(override_read) == -1:
			return false
	var rebuild_body := source.get_slice("func _rebuild_field(", 1).get_slice("\nfunc ", 0)
	return rebuild_body.find(override_read) == -1


## Trailing "(" is load-bearing: without it a short name prefix-matches a longer
## sibling and silently slices the wrong body (_rebuild_field vs
## _rebuild_field_after_transition; _reconcile_entity_presence vs its _or_defer).
func _function_body(source: String, function_name: String) -> String:
	return source.get_slice("func %s(" % function_name, 1).get_slice("\nfunc ", 0)


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start == -1:
		return ""
	var finish := source.find("\nfunc ", start + 5)
	return source.substr(start) if finish == -1 else source.substr(start, finish - start)


func _cleared_terrain_visual_contract_holds(source: String) -> bool:
	var handler := _function_body(source, "_on_domain_event")
	var terrain_arm := handler.get_slice("elif type == WIEvents.TERRAIN_CHANGED:", 1).get_slice("\n\telif type", 0)
	return terrain_arm.find('"scorched":\n\t\t\t\t\t_spawn_burn_poof(tc_cell)') != -1 \
		and terrain_arm.find('"cleared":\n\t\t\t\t\t_spawn_burn_poof(tc_cell)') != -1


func _blocked_prop_pool_contract_holds() -> bool:
	var biomes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	var sprites: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	if not (biomes is Dictionary) or not (sprites is Dictionary):
		return false
	for biome_id: String in ["inn", "street", "cave", "floodplains"]:
		var biome: Dictionary = biomes.get(biome_id, {})
		var pool: Array = biome.get("blocked_props", [])
		if pool.size() < 2:
			return false
		for sprite_id: Variant in pool:
			if not (sprites as Dictionary).has(String(sprite_id)):
				return false
	return true


func _map_blocked_sets(map_cfg: Dictionary) -> Dictionary:
	var blocked := {}
	var segment_covered := {}
	for raw_cell: Variant in map_cfg.get("blocked", []):
		var cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		blocked[cell] = true
	for raw_segment: Variant in map_cfg.get("walls", {}).get("segments", []):
		for cell: Vector2i in WIGame.segment_cells(raw_segment as Dictionary):
			blocked[cell] = true
			segment_covered[cell] = true
	for raw_cell: Variant in map_cfg.get("freezable", []):
		blocked[Vector2i(int(raw_cell[0]), int(raw_cell[1]))] = true
	return {"blocked": blocked, "segment_covered": segment_covered}


func _authored_cover_cells(map_cfg: Dictionary) -> Dictionary:
	return WITileBoardBuilder.field_authored_cover_cells(map_cfg)


func _blocked_prop_planning_contract_holds() -> bool:
	var blocked := {
		Vector2i(1, 1): true,
		Vector2i(2, 2): true,
		Vector2i(3, 3): true,
		Vector2i(4, 4): true,
	}
	var segment_covered := {Vector2i(3, 3): true}
	var cover_skip := {Vector2i(4, 4): true}
	var authored_covered := {Vector2i(2, 2): true}
	var pool := ["crate", "barrel"]
	var plan := WITileBoardBuilder.field_blocked_render_plan(
		"inn", blocked, segment_covered, cover_skip, authored_covered, pool
	)
	if plan.get("fallback", []).size() != 0 or plan.get("props", {}).size() != 1:
		return false
	for cell: Vector2i in (plan.get("props", {}) as Dictionary):
		if not blocked.has(cell) or segment_covered.has(cell) or cover_skip.has(cell) or authored_covered.has(cell):
			return false
	var fallback := WITileBoardBuilder.field_blocked_render_plan(
		"unknown_map", blocked, segment_covered, cover_skip, authored_covered, []
	)
	if fallback.get("props", {}).size() != 0 or fallback.get("fallback", []).size() != 1:
		return false
	var inn_sequence: Array[int] = []
	var street_sequence: Array[int] = []
	for x in 16:
		var cell := Vector2i(x, x % 5)
		var first := WITileBoardBuilder.field_blocked_prop_index("inn", cell, 2)
		if first != WITileBoardBuilder.field_blocked_prop_index("inn", cell, 2):
			return false
		inn_sequence.append(first)
		street_sequence.append(WITileBoardBuilder.field_blocked_prop_index("street", cell, 2))
	if inn_sequence == street_sequence:
		return false
	if not WITileBoardBuilder.cover_skip_errors(blocked, segment_covered, cover_skip, authored_covered, plan["props"]).is_empty():
		return false
	if WITileBoardBuilder.cover_skip_errors(
		blocked, segment_covered, {Vector2i(9, 9): true}, authored_covered, {}
	).is_empty():
		return false
	if WITileBoardBuilder.cover_skip_errors(
		blocked, segment_covered, cover_skip, authored_covered, {Vector2i(4, 4): "crate"}
	).is_empty():
		return false
	if WITileBoardBuilder.cover_skip_errors(
		blocked, segment_covered, cover_skip, authored_covered, {Vector2i(2, 2): "crate"}
	).is_empty():
		return false
	return true


func _shipped_blocked_prop_contract_holds() -> bool:
	var biomes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	for map_id: String in WISceneCatalog.compose()["maps"]:
		var map_cfg: Dictionary = WISceneCatalog.compose()["maps"][map_id]
		var sets := _map_blocked_sets(map_cfg)
		var authored_covered := _authored_cover_cells(map_cfg)
		var cover_skip := {}
		for raw_cell: Variant in map_cfg.get("cover_skip", []):
			cover_skip[Vector2i(int(raw_cell[0]), int(raw_cell[1]))] = true
		var pool: Array = biomes.get(String(map_cfg.get("biome", "")), {}).get("blocked_props", [])
		var plan := WITileBoardBuilder.field_blocked_render_plan(
			map_id, sets["blocked"], sets["segment_covered"], cover_skip, authored_covered, pool
		)
		if not WITileBoardBuilder.cover_skip_errors(
			sets["blocked"], sets["segment_covered"], cover_skip, authored_covered, plan.get("props", {})
		).is_empty():
			return false
		for cell: Vector2i in (plan.get("props", {}) as Dictionary):
			if authored_covered.has(cell):
				return false
		var expected := (sets["blocked"] as Dictionary).size()
		for cell: Vector2i in (sets["segment_covered"] as Dictionary):
			if (sets["blocked"] as Dictionary).has(cell):
				expected -= 1
		for cell: Vector2i in cover_skip:
			if not (sets["segment_covered"] as Dictionary).has(cell):
				expected -= 1
		for cell: Vector2i in authored_covered:
			if (sets["blocked"] as Dictionary).has(cell) \
				and not (sets["segment_covered"] as Dictionary).has(cell) \
				and not cover_skip.has(cell):
				expected -= 1
		if plan.get("props", {}).size() + plan.get("fallback", []).size() != expected:
			return false
		if not pool.is_empty() and (not plan.get("fallback", []).is_empty() or plan.get("props", {}).size() > 200):
			return false
	return true


func _field_blocked_render_wiring_holds(source: String, factory_source: String) -> bool:
	if source.find("const FIELD_BLOCKED_PROP_BUDGET := 200") == -1:
		return false
	var floor_body := _function_body(source, "_build_floor")
	for clause: String in [
		"biome.get(\"blocked_props\", [])",
		"WITileBoardBuilder.field_blocked_render_plan",
		"WITileBoardBuilder.field_authored_cover_cells",
		"WITileBoardBuilder.cover_skip_errors",
		"FIELD_BLOCKED_PROP_BUDGET",
	]:
		if floor_body.find(clause) == -1:
			return false
	var prop_body := factory_source.get_slice("func make_blocked_prop(", 1).get_slice("\nfunc ", 0)
	for clause: String in [
		"Sprite2D.new()",
		"get_frame_texture",
		"spr.position = Vector2(cell) * CELL",
		"WISpriteRegistry.anchor_for(sprite_id)",
		"spr.offset = Vector2(",
	]:
		if prop_body.find(clause) == -1:
			return false
	if prop_body.find("AnimatedSprite2D.new()") != -1:
		return false
	var render_body := _function_body(source, "_build_field_blocked_props")
	if render_body.find("make_blocked_prop") == -1 or render_body.find("_entities_root.add_child") == -1:
		return false
	if render_body.find("AnimatedSprite2D.new()") != -1:
		return false
	var rebuild_body := _function_body(source, "_rebuild_field")
	var root_created := rebuild_body.find("_entities_root = Node2D.new()")
	var props_built := rebuild_body.find("_build_field_blocked_props()")
	var decor_built := rebuild_body.find("_build_decor(")
	return root_created != -1 and props_built > root_created and decor_built > props_built


func _chronicle_capture_contract_holds(source: String) -> bool:
	var capture := _function_body(source, "_record_current_chronicle")
	if capture.is_empty():
		return false
	for clause: String in [
		"Game.sim != null",
		"Game.sim.accomplishment_count(\"post_game\")",
		"WISettings.record_chronicle(Game.sim.chronicle_facts())",
	]:
		if capture.find(clause) == -1:
			return false
	var title_swap := _function_body(source, "swap_to_title")
	if title_swap.find("_record_current_chronicle()") == -1:
		return false
	if title_swap.find("_record_current_chronicle()") > title_swap.find("_clear_world_viewport()"):
		return false
	var event_handler := _function_body(source, "_on_domain_event")
	for clause: String in ["WIEvents.ACCOMPLISHMENT_RECORDED", "\"post_game\"", "_record_current_chronicle()"]:
		if event_handler.find(clause) == -1:
			return false
	return true


func _journal_chronicle_contract_holds(source: String) -> bool:
	var open_body := _function_body(source, "_open")
	for clause: String in [
		"Game.sim.accomplishment_count(\"post_game\")",
		"Game.sim.chronicle_facts()",
		"WIEvents.UI_CHRONICLE_RENDERED",
		"\"surface\": \"journal\"",
		"\"facts\": chronicle_facts",
	]:
		if open_body.find(clause) == -1:
			return false
	# Issue #209: the journal body split into three tabs; Chronicle facts now
	# render in the History tab builder (still after Lore) and the FULL payload
	# is emitted via `_emit_journal_shown()` from `_open`.
	if open_body.find("_emit_journal_shown()") == -1:
		return false
	var builder := _function_body(source, "_build_history_tab")
	var chronicle_heading := builder.find("[b]Chronicle[/b]")
	return builder.find("_open_chronicle_facts.is_empty()") != -1 \
		and chronicle_heading > builder.find("[b]Lore[/b]") \
		and builder.find("quests_completed") != -1 \
		and builder.find("victories") != -1 \
		and builder.find("sleeps") != -1 \
		and builder.find("ending") != -1


func _title_chronicle_contract_holds(source: String) -> bool:
	var rows_line := "const ROWS: Array[String] = [\"New Game\", \"Continue\", \"Playtest States\", \"Quit\", \"Settings\"]"
	if source.find(rows_line) == -1 or _occurrence_count(source, rows_line) != 1:
		return false
	var menu_body := _function_body(source, "_enter_menu")
	if menu_body.find("_show_chronicle_card()") == -1:
		return false
	var card := _function_body(source, "_show_chronicle_card")
	for clause: String in [
		"WISettings.latest_chronicle()",
		"facts.is_empty()",
		"Control.PRESET_BOTTOM_LEFT",
		"Vector2(420.0, 150.0)",
		"Control.MOUSE_FILTER_IGNORE",
		"MarginContainer.new()",
		"VBoxContainer.new()",
		"WIEvents.UI_CHRONICLE_RENDERED",
		"\"surface\": \"title\"",
		"\"facts\": facts",
	]:
		if card.find(clause) == -1:
			return false
	for compact_clause: String in [
		"UIChrome.add_margins(margin, 18, 10, 18, 10)",
		"stack.add_theme_constant_override(\"separation\", 0)",
		"UIChrome.make_label(_chronicle_identity_line(facts), \"Small\")",
		"UIChrome.make_label(String(facts.get(\"ending\", \"\")), \"Small\")",
		"%d quests  •  %d victories  •  %d sleeps",
	]:
		if card.find(compact_clause) == -1:
			return false
	if card.find("var result_line") != -1:
		return false
	return true


func _title_continue_caption_contract_holds(source: String) -> bool:
	var caption := _function_body(source, "_refresh_continue_caption")
	var build := _function_body(source, "_build_ui")
	for menu_clause: String in [
		"UIChrome.set_offsets(menu_anchor, -160.0, 34.0, 160.0, 204.0)",
		"_menu_root.add_theme_constant_override(\"separation\", 8)",
		"row_panel.custom_minimum_size = Vector2(300.0, 44.0)",
	]:
		if build.find(menu_clause) == -1:
			return false
	for clause: String in [
		"_continue_caption_label.set_anchors_preset(Control.PRESET_CENTER)",
		"UIChrome.set_offsets(_continue_caption_label, -160.0, 294.0, 160.0, 328.0)",
		"_continue_caption_label.add_theme_color_override(\"font_color\", GESTURE_COLOR)",
		"_root.add_child(_continue_caption_label)",
	]:
		if caption.find(clause) == -1:
			return false
	var menu_top_offset := 34.0
	var row_height := 44.0
	var row_separation := 8.0
	var menu_bottom_offset := menu_top_offset + 5.0 * row_height + 4.0 * row_separation
	var caption_top_offset := 294.0
	var chronicle_right := 444.0
	var caption_left := 640.0 - 160.0
	return caption.find("_menu_root.get_parent()") == -1 \
		and caption_top_offset > menu_bottom_offset \
		and caption_left > chronicle_right


func _main_map_transition_contract_holds(source: String) -> bool:
	if source.find("const MAP_TRANSITION_HALF_SECONDS := 0.125") == -1:
		return false
	if source.find("const MAP_TRANSITION_VISUAL_HOLD_SECONDS := 0.25") == -1:
		return false
	var ready := _function_body(source, "_ready")
	if ready.find("_ensure_map_transition_overlay()") == -1 \
			or ready.find("_ensure_map_transition_overlay()") > ready.find("swap_to_title()"):
		return false
	var ensure := _function_body(source, "_ensure_map_transition_overlay")
	for clause: String in [
		"CanvasLayer.new()",
		"_map_transition_layer.layer = 100",
		"ColorRect.new()",
		"_map_transition_overlay.color = Color.BLACK",
		"Control.PRESET_FULL_RECT",
		"Control.MOUSE_FILTER_STOP",
		"_map_transition_overlay.visible = false",
	]:
		if ensure.find(clause) == -1:
			return false
	var clear := _function_body(source, "_clear_ui_layers")
	if clear.find("child != _map_transition_layer") == -1:
		return false
	var transition := _function_body(source, "transition_map")
	for clause: String in [
		"rebuild: Callable",
		"if _map_transition_active",
		"_map_transition_active = true",
		"_map_transition_overlay.visible = true",
		"_transition_delay(MAP_TRANSITION_HALF_SECONDS)",
		"await _fade_map_transition(1.0, half_seconds)",
		"rebuild.call()",
		"if half_seconds > 0.0:",
		"await RenderingServer.frame_post_draw",
		"await _hold_map_transition_midpoint()",
		"await _fade_map_transition(0.0, half_seconds)",
		"_map_transition_overlay.visible = false",
		"_map_transition_active = false",
	]:
		if transition.find(clause) == -1:
			return false
	var covered := transition.find("await _fade_map_transition(1.0, half_seconds)")
	var rebuilt := transition.find("rebuild.call()")
	var settled := transition.find("await RenderingServer.frame_post_draw")
	var held := transition.find("await _hold_map_transition_midpoint()")
	var revealed := transition.find("await _fade_map_transition(0.0, half_seconds)")
	if not (covered < rebuilt and rebuilt < settled and settled < held and held < revealed):
		return false
	if transition.find("ObservableBus.emit_domain_event") != -1:
		return false
	var fade := _function_body(source, "_fade_map_transition")
	for clause: String in [
		"create_tween()",
		"tween_property(_map_transition_overlay, \"modulate:a\", target_alpha, seconds)",
		"await _map_transition_tween.finished",
	]:
		if fade.find(clause) == -1:
			return false
	var delay := _function_body(source, "_transition_delay")
	for clause: String in [
		"DisplayServer.get_name() == \"headless\"",
		"TestDriver != null and TestDriver.active()",
		"_map_transition_visual_requested()",
	]:
		if delay.find(clause) == -1:
			return false
	var visual_opt_in := _function_body(source, "_map_transition_visual_requested")
	if visual_opt_in.find("QAPaths.user_args().get(\"map-transition-visual\", \"\") == \"1\"") == -1:
		return false
	var visual_hold := _function_body(source, "_hold_map_transition_midpoint")
	for clause: String in [
		"if not _map_transition_visual_requested()",
		"_map_transition_overlay.modulate.a = 0.5",
		"create_timer(MAP_TRANSITION_VISUAL_HOLD_SECONDS)",
	]:
		if visual_hold.find(clause) == -1:
			return false
	var input := _function_body(source, "_input")
	if input.find("_map_transition_active") == -1 \
			or input.find("get_viewport().set_input_as_handled()") == -1:
		return false
	var gui_input := _function_body(source, "_gui_input")
	return gui_input.find("if _map_transition_active") != -1 \
		and gui_input.find("if _map_transition_active") < gui_input.find("InputEventMouseButton")


func _world_map_transition_contract_holds(source: String) -> bool:
	var ready := _function_body(source, "_ready")
	if ready.find("_rebuild_field()") == -1 or ready.find("transition_map") != -1:
		return false
	var event_handler := _function_body(source, "_on_domain_event")
	var map_branch := event_handler.get_slice("elif type == WIEvents.MAP_CHANGED:", 1).get_slice("\nelif ", 0)
	if map_branch.find("_main.transition_map(_rebuild_field_after_transition)") == -1 \
			or map_branch.find("\n\t\t_rebuild_field()") != -1:
		return false
	var covered_rebuild := _function_body(source, "_rebuild_field_after_transition")
	var mood_apply := covered_rebuild.find("_atmosphere.apply_map(Game.sim.current_map, _atmosphere.phase_now())")
	var rebuild := covered_rebuild.find("_rebuild_field()")
	if mood_apply == -1 or rebuild == -1 or mood_apply > rebuild:
		return false
	var accomplishment_branch := event_handler.get_slice("elif type == WIEvents.ACCOMPLISHMENT_RECORDED:", 1).get_slice("\nelif ", 0)
	# #119: the guard narrowed from whole-transition to the stale-cover window
	# (pre-rebuild only) — post-rebuild events must reconcile, not drop.
	var transition_guard := accomplishment_branch.find("_map_transition_stale_cover()")
	var reconcile := accomplishment_branch.find("_reconcile_entity_presence()")
	if transition_guard == -1 or reconcile == -1 or transition_guard > reconcile:
		return false
	var gate := _function_body(source, "_movement_gated")
	if gate.find("_main.map_transition_active()") == -1:
		return false
	var held_or_click := _function_body(source, "_on_move_tween_finished")
	return held_or_click.find("if _movement_gated()") != -1 \
		and held_or_click.find("if _movement_gated()") < held_or_click.find("_advance_click_path()")


func _atmosphere_map_transition_contract_holds(source: String) -> bool:
	var event_handler := _function_body(source, "_on_domain_event")
	return event_handler.find("WIEvents.MAP_CHANGED") == -1


## v0.15 T5.3 MAP-LIGHTS/DAY. The opt-out is latched off the MAP grade inside
## `apply()`, BEFORE the refresh that consumes it, and `apply_arena()` must
## never rewrite it — the lights on screen belong to the map underneath the
## arena, so an arena id (which is not a map id) would silently clear it.
func _atmosphere_lights_by_day_contract_holds(source: String) -> bool:
	var apply_body := _function_body(source, "apply")
	var latch := apply_body.find("_map_lights_by_day = map_lights_by_day(map_id)")
	var refresh := apply_body.find("_refresh_lights()")
	if latch == -1 or refresh == -1 or latch > refresh:
		return false
	if _function_body(source, "apply_arena").find("_map_lights_by_day") != -1:
		return false
	return _function_body(source, "light_multiplier").find("phase_light_energy(phase, _map_lights_by_day)") != -1


func _wave_b_field_visual_contract_holds(source: String) -> bool:
	var handler := _function_body(source, "_on_domain_event")
	for clause: String in [
		"WIEvents.PLAYER_TELEPORTED",
		"_render_blink_afterimage",
		"WIEvents.WARD_PLACED",
		"_reconcile_ward_visuals",
		"WIEvents.COMPANION_CHANGED",
		"_reconcile_companion_visual",
	]:
		if handler.find(clause) == -1:
			return false
	var blink := _function_body(source, "_render_blink_afterimage")
	for clause: String in ["WISettings.reduce_motion()", "Line2D.new()", "UI_TELEPORT_RENDERED", '"blink-visual"', "streak.position =", "Vector2.ZERO"]:
		if blink.find(clause) == -1:
			return false
	var qa_hold := blink.get_slice("if qa_visual_hold:", 1).get_slice("if reduced", 0)
	if qa_hold.find("return") == -1 or qa_hold.find("create_timer") != -1:
		return false
	var ward := _function_body(source, "_reconcile_ward_visuals")
	for clause: String in [
		"_make_entity_visual(",
		'"icon_hearthward_charm"',
		"Line2D.new()",
		"ring.closed = true",
		"point_index: int in 12",
	]:
		if ward.find(clause) == -1:
			return false
	var rebuild := _function_body(source, "_rebuild_field")
	return rebuild.find("_reconcile_ward_visuals()") != -1 \
		and rebuild.find("_reconcile_companion_visual()") != -1 \
		and source.find("WIEvents.UI_WARD_RENDERED") != -1 \
		and source.find("WIEvents.UI_COMPANION_RENDERED") != -1



## v0.15 T4.3 round 2: the dialogue defer's source contract. world.gd cannot be
## instantiated under a bare `--script` SceneTree (it reads the Game/ObservableBus
## autoloads, which do not exist there), so the BEHAVIOUR is pinned live in
## horns_dig_flow -- no rebuild between the invitation's bank and DIALOGUE_ENDED,
## then exactly one. This arm pins the wiring that behaviour rests on, and every
## clause is proven load-bearing by the deletion battery in _init.
func _dialogue_defer_contract_holds(source: String) -> bool:
	if source.find("var _presence_reconcile_deferred := false") == -1:
		return false
	# The ACCOMPLISHMENT_RECORDED arm must route through the defer, never call
	# the reconciler straight -- that call site IS the photographed defect.
	var acc_arm := source.get_slice("elif type == WIEvents.ACCOMPLISHMENT_RECORDED:", 1).get_slice("\n\telif type ==", 0)
	if acc_arm.find("_reconcile_entity_presence_or_defer()") == -1:
		return false
	if acc_arm.find("\t_reconcile_entity_presence()") != -1:
		return false
	# The latch is read off the sim, never mirrored locally.
	var open_body := _function_body(source, "_dialogue_is_open")
	if open_body.find("Game.sim.dialogue != null") == -1:
		return false
	# A finished-but-not-nulled walker must not latch the defer forever.
	if open_body.find("not Game.sim.dialogue.finished") == -1:
		return false
	# Queue-not-run, and the queue is a latch (assignment, never an increment).
	var defer_body := _function_body(source, "_reconcile_entity_presence_or_defer")
	if defer_body.find("_dialogue_is_open()") == -1 or defer_body.find("_presence_reconcile_deferred = true") == -1:
		return false
	if defer_body.find("return") == -1:
		return false
	# Flush exactly once: clear BEFORE reconciling, and no-op when nothing queued.
	var flush_body := _function_body(source, "_flush_deferred_presence_reconcile")
	if flush_body.find("if not _presence_reconcile_deferred:") == -1:
		return false
	# #119: never reconcile against geometry the transition cover is replacing.
	if flush_body.find("_map_transition_stale_cover()") == -1:
		return false
	if flush_body.find("_presence_reconcile_deferred = false") == -1 or flush_body.find("_reconcile_entity_presence()") == -1:
		return false
	if flush_body.find("_presence_reconcile_deferred = false") > flush_body.find("_reconcile_entity_presence()"):
		return false
	# DIALOGUE_ENDED is the flush point.
	if source.find("elif type == WIEvents.DIALOGUE_ENDED:") == -1:
		return false
	var ended_arm := source.get_slice("elif type == WIEvents.DIALOGUE_ENDED:", 1).get_slice("\n\telif type ==", 0)
	if ended_arm.find("_flush_deferred_presence_reconcile()") == -1:
		return false
	# A full rebuild supersedes a queued reconcile.
	return _function_body(source, "_rebuild_field").find("_presence_reconcile_deferred = false") != -1


func _night_layer_attenuation_wiring_holds(source: String) -> bool:
	var make_body := _function_body(source, "_make_entity_visual")
	var legibility_body := _function_body(source, "_apply_field_legibility")
	var decor_body := _function_body(source, "_build_decor")
	var scatter_body := _function_body(source, "_build_scatter")
	var validity_guard := legibility_body.find("if not is_instance_valid(raw_holder):")
	var holder_cast := legibility_body.find("raw_holder as Node2D")
	return source.find('const MOOD_LAYERS: Array[String] = ["entities", "decor", "scatter"]') != -1 \
		and make_body.find("_track_mood_layer_visual") != -1 \
		and make_body.find("mood_layer") != -1 \
		and make_body.find("_atmosphere.apply_current_layer_modulate(holder, mood_layer)") != -1 \
		and legibility_body.find("layer_night_modulate") != -1 \
		and validity_guard != -1 and holder_cast > validity_guard \
		and legibility_body.find("_mood_layer_visuals[layer] = live_holders") != -1 \
		and decor_body.find('"decor"') != -1 \
		and scatter_body.find('"scatter"') != -1


func _dialogue_separation_contract_holds(source: String) -> bool:
	var begin_body := _function_body(source, "_begin_dialogue_separation")
	var restore_body := _function_body(source, "_restore_dialogue_separation")
	var handler := _function_body(source, "_on_domain_event")
	var started_arm := handler.get_slice("elif type == WIEvents.DIALOGUE_STARTED:", 1).get_slice("\n\telif type", 0)
	var ended_arm := handler.get_slice("elif type == WIEvents.DIALOGUE_ENDED:", 1).get_slice("\n\telif type", 0)
	var affordance_body := _function_body(source, "_reconcile_faced_affordance")
	return source.find("const DIALOGUE_SEPARATION_PX := 10.0") != -1 \
		and begin_body.find('payload.get("entity"') != -1 \
		and begin_body.find("_is_cardinal_adjacent") != -1 \
		and begin_body.find("Game.sim.player_facing") == -1 \
		and begin_body.find("_facing_vector") == -1 \
		and begin_body.find("_player_visual.position -= nudge") != -1 \
		and begin_body.find("speaker_visual.position += nudge") != -1 \
		and restore_body.find("player_position") != -1 \
		and restore_body.find("speaker_position") != -1 \
		and started_arm.find("_begin_dialogue_separation(payload)") != -1 \
		and ended_arm.find("_restore_dialogue_separation()") != -1 \
		and ended_arm.find("_restore_dialogue_separation()") < ended_arm.find("_flush_deferred_presence_reconcile()") \
		and source.find("WIEvents.DIALOGUE_STARTED,\n\tWIEvents.DIALOGUE_ENDED") != -1 \
		and affordance_body.find("if trigger == WIEvents.DIALOGUE_STARTED:") != -1 \
		and affordance_body.find("dialogue_open = true") != -1


func _dangersense_world_contract_holds(source: String, overlay_source: String, sim_source: String) -> bool:
	var build := _function_body(source, "_build_dangersense_overlay")
	var gate := _function_body(source, "_field_mode_active")
	var live := _function_body(source, "_live_dangersense_encounters")
	var reconcile := _function_body(source, "_reconcile_dangersense_overlay")
	var compensate := _function_body(source, "_apply_dangersense_night_compensation")
	var rebuild := _function_body(source, "_rebuild_field")
	var overlay_rebuild := _function_body(overlay_source, "rebuild")
	var sim_radius := _function_body(sim_source, "effective_trigger_radius")
	var sim_trigger := _function_body(sim_source, "_check_trigger_radius")
	return overlay_rebuild.find("radius_read.call(encounter)") != -1 \
		and overlay_rebuild.find('encounter["trigger_radius"]') == -1 \
		and overlay_rebuild.find('encounter.has("encounter_when")') != -1 \
		and overlay_rebuild.find("holder_has_skill and field_mode") != -1 \
		and build.find("WIDangersenseOverlay.new") != -1 \
		and gate.find("Game.sim.combat == null") != -1 \
		and gate.find("_field_root.visible") != -1 \
		and live.find("Game.sim.entity_present(encounter)") != -1 \
		and live.find("Game.sim.dormant_encounters") != -1 \
		and live.find("Game.sim.warded_encounters") != -1 \
		and live.find("Game.sim.encounter_gate_met(encounter)") != -1 \
		and source.find("func _dangersense_encounter_gate_met") == -1 \
		and reconcile.find('Game.sim.known_skills().has("dangersense")') != -1 \
		and reconcile.find("Game.sim.effective_trigger_radius") != -1 \
		and reconcile.find("WIEvents.UI_DANGERSENSE_RENDERED") != -1 \
		and compensate.find("WIAtmosphere.night_attenuation_modulate") != -1 \
		and _function_body(source, "_on_domain_event").find("_apply_dangersense_night_compensation()") != -1 \
		and sim_radius.find("_wild_affinity_reduction(ent)") != -1 \
		and sim_trigger.find("effective_trigger_radius(ent)") != -1 \
		and rebuild.find("_build_dangersense_overlay()") < rebuild.find("_entities_root = Node2D.new()")


func _init() -> void:
	WITestWatchdog.arm(self)
	var source := FileAccess.get_file_as_string("res://src/world/world.gd")
	var builder_source := FileAccess.get_file_as_string("res://src/world/tile_board_builder.gd")
	var factory_source := FileAccess.get_file_as_string("res://src/world/entity_visual_factory.gd")
	var dangersense_source := FileAccess.get_file_as_string("res://src/world/dangersense_overlay.gd")
	var sim_source := FileAccess.get_file_as_string("res://src/core/wi_game.gd")
	assert(not source.is_empty(), "world.gd must exist")
	assert(not factory_source.is_empty(), "entity_visual_factory.gd must exist (#194b seam 1)")
	assert(not dangersense_source.is_empty(), "dangersense_overlay.gd must exist")
	assert(not sim_source.is_empty(), "wi_game.gd must exist")
	var danger_overlay := WIDangersenseOverlay.new(16.0)
	root.add_child(danger_overlay)
	var authored_radius := func(encounter: Dictionary) -> int: return int(encounter["trigger_radius"])
	var danger_rows: Array = [
		{"id": "z_danger", "kind": "encounter", "cell": [10, 21], "trigger_radius": 1, "encounter_when": {"phase": ["night"]}},
		{"id": "a_danger", "kind": "encounter", "cell": [4, 5], "trigger_radius": 2, "encounter_when": {"requires": {"armed": 1}}},
		{"id": "plain_encounter", "kind": "encounter", "cell": [1, 1], "trigger_radius": 4},
	]
	assert(danger_overlay.rebuild(danger_rows, false, true, authored_radius).is_empty() and not danger_overlay.visible,
		"a non-holder gets no warning regions")
	assert(danger_overlay.rebuild(danger_rows, true, false, authored_radius).is_empty() and not danger_overlay.visible,
		"a holder outside field mode gets no warning regions")
	var warning_regions := danger_overlay.rebuild(danger_rows, true, true, authored_radius)
	assert((warning_regions as Array).size() == 2 and String(warning_regions[0]["encounter"]) == "a_danger",
		"a field-mode holder gets only encounter_when proximity regions, deterministically sorted")
	assert(danger_overlay.region_rect(warning_regions[1]) == Rect2(144, 320, 48, 48),
		"radius 1 draws the exact 3x3 Chebyshev trigger square from the encounter cell")
	var affinity_game := WIGame.new(
		WISceneCatalog.compose(),
		JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json")),
		func(_type: String, _payload: Dictionary) -> void: pass,
		1,
	)
	affinity_game.player_skills.append("wild_affinity")
	var affinity_regions := danger_overlay.rebuild([{
		"id": "affinity_beast",
		"kind": "encounter",
		"beast": true,
		"cell": [7, 8],
		"trigger_radius": 2,
		"encounter_when": {"phase": ["night"]},
	}], true, true, affinity_game.effective_trigger_radius)
	assert(affinity_regions[0]["radius"] == 1
		and danger_overlay.region_rect(affinity_regions[0]).size == Vector2(48, 48),
		"[Wild Affinity] must render the shared reduced radius-1 square, never authored radius 2")
	var floodplains_night := Color(0.25, 0.3, 0.8)
	var floodplains_compensation := Color(4.0, 10.0 / 3.0, 1.25)
	danger_overlay.apply_night_grade(floodplains_compensation, "night")
	assert((WIDangersenseOverlay.EDGE_COLOR * danger_overlay.modulate * floodplains_night).is_equal_approx(WIDangersenseOverlay.EDGE_COLOR),
		"night compensation must deliver the authored warning edge through CanvasModulate")
	danger_overlay.apply_night_grade(floodplains_night, "day")
	assert(danger_overlay.modulate == Color.WHITE, "day must keep the warning overlay byte-identical")
	assert(_dangersense_world_contract_holds(source, dangersense_source, sim_source),
		"[Dangersense] must use shared sim radius/gate reads, night compensation, and held+field-mode gating")
	assert(not _dangersense_world_contract_holds(
		source,
		dangersense_source.replace("radius_read.call(encounter)", 'encounter["trigger_radius"]'),
		sim_source,
	), "[Dangersense] wiring contract must reject a raw authored-radius read")
	danger_overlay.queue_free()
	assert(_cleared_terrain_visual_contract_holds(source),
		"terrain=cleared must reuse the shipped removal poof used by scorched")
	assert(not _cleared_terrain_visual_contract_holds(source.replace(
		'\t\t\t\t"cleared":\n\t\t\t\t\t_spawn_burn_poof(tc_cell)\n', "")),
		"cleared terrain visual contract must fail when its match arm is deleted")
	assert(_blocked_prop_pool_contract_holds(),
		"inn, street, cave, and floodplains need sprite-registry-backed blocked_props pools")
	for helper: String in ["field_blocked_prop_index", "field_blocked_render_plan", "cover_skip_errors"]:
		assert(builder_source.find("static func %s" % helper) != -1,
			"tile board builder must expose the %s field-cover contract" % helper)
	assert(_blocked_prop_planning_contract_holds(),
		"field blocked cover must select deterministically, fall back, and reject stale/conflicting cover_skip")
	assert(_shipped_blocked_prop_contract_holds(),
		"every shipped blocked cell needs exactly one honest render path within the 200-prop budget")
	assert(_field_blocked_render_wiring_holds(source, factory_source),
		"world must render budgeted static blocked props in the Y-sorted field layer")

	# EXACT signature, not the bare name: v0.15 T4.3 round 2 added
	# `_reconcile_entity_presence_or_defer`, which a prefix slice matches FIRST
	# and which carries none of the light bookkeeping asserted below.
	var body := source.get_slice("func _reconcile_entity_presence() -> void:", 1).get_slice("\nfunc ", 0)
	assert(not body.is_empty(), "world.gd must define _reconcile_entity_presence (the GH#104 PHASE_CHANGED presence reconciler)")
	assert(body.find("unregister_light") != -1,
		"_reconcile_entity_presence's free arm must unregister PointLight2D children from _atmosphere before queue_free (the _refresh_entity_visual discipline)")
	assert(body.find("_light_count -= 1") != -1,
		"_reconcile_entity_presence's free arm must decrement _light_count (mirrors _spawn_light's increment)")
	assert(body.find("LIGHT_BUDGET") != -1,
		"_reconcile_entity_presence must re-check the LIGHT_BUDGET assert after a reconcile (the _refresh_entity_visual discipline)")
	assert(body.find("hide_sprite") != -1,
		"_reconcile_entity_presence must skip hide_sprite entities (matches _build_entities' guard)")

	assert(_dialogue_defer_contract_holds(source),
		"world.gd must defer presence reconciles while a dialogue is open and flush exactly once at DIALOGUE_ENDED (v0.15 T4.3 round 2)")
	for deleted_defer_clause: String in [
		"var _presence_reconcile_deferred := false",
		"_reconcile_entity_presence_or_defer()",
		"Game.sim.dialogue != null",
		"if not _presence_reconcile_deferred:",
		"elif type == WIEvents.DIALOGUE_ENDED:",
		"_flush_deferred_presence_reconcile()",
		"not Game.sim.dialogue.finished",
		"_map_transition_stale_cover()",
	]:
		assert(not _dialogue_defer_contract_holds(source.replace(deleted_defer_clause, "")),
			"dialogue-defer contract must reject deletion of: %s" % deleted_defer_clause)
	assert(not _dialogue_defer_contract_holds(source.replace("_reconcile_entity_presence_or_defer()", "_reconcile_entity_presence()")),
		"dialogue-defer contract must reject the ACCOMPLISHMENT_RECORDED arm calling the reconciler directly (the photographed defect)")
	assert(_night_layer_attenuation_wiring_holds(source),
		"moods.json night attenuation must reach entity, decor, and scatter holders through World")
	assert(not _night_layer_attenuation_wiring_holds(source.replace("layer_night_modulate", "disconnected_layer_modulate")),
		"night layer attenuation contract must fail when the atmosphere lookup is disconnected")
	assert(_dialogue_separation_contract_holds(source),
		"adjacent face-to-face dialogue must separate both holders and restore before the presence flush")
	assert(not _dialogue_separation_contract_holds(source.replace("_restore_dialogue_separation()", "_missing_dialogue_restore()")),
		"dialogue separation contract must fail when restoration is disconnected")

	assert(_y_sort_contract_holds(source, factory_source),
		"entity Y-sort overrides need numeric catalog fallback, holder bias, zero-shift sprite/shadow cancellation, and entity-only plumbing")
	for deleted_clause: String in [
		"else float(catalog_entry.get(\"field_y_sort_bias_px\", 0.0))",
		"holder.position.y += y_sort_bias",
		"CELL - anchor.y * frame_size.y * spr.scale.y - y_sort_bias",
		"shadow.position = Vector2(CELL * 0.5, CELL - 2.0 - y_sort_bias)",
	]:
		assert(not _y_sort_contract_holds(source, factory_source.replace(deleted_clause, "")),
			"Y-sort contract must reject factory deletion of: %s" % deleted_clause)
	assert(not _y_sort_contract_holds(source.replace("ent.get(\"field_y_sort_bias_px\", null)", ""), factory_source),
		"Y-sort contract must reject deletion of the call-site override reads")
	var broadened_scope := source.replace(
		"\t\tPLAYER_COLOR\n\t)",
		"\t\tPLAYER_COLOR,\n\t\tent.get(\"field_y_sort_bias_px\", null)\n\t)"
	)
	assert(broadened_scope != source and not _y_sort_contract_holds(broadened_scope, factory_source),
		"entity-scoped sort overrides must not leak into the player visual build")
	var accomplishment_branch := source.get_slice("elif type == WIEvents.ACCOMPLISHMENT_RECORDED:", 1).get_slice("\nelif ", 0)
	assert(accomplishment_branch.find("_reconcile_entity_presence()") != -1,
		"accomplishment changes must reconcile same-map present_when entities")

	var events_source := FileAccess.get_file_as_string("res://src/core/wi_events.gd")
	var main_source := FileAccess.get_file_as_string("res://src/world/main.gd")
	var atmosphere_source := FileAccess.get_file_as_string("res://src/world/atmosphere.gd")
	var journal_source := FileAccess.get_file_as_string("res://src/ui/journal.gd")
	var title_source := FileAccess.get_file_as_string("res://src/ui/title_screen.gd")
	var driver_source := FileAccess.get_file_as_string("res://qa/test_driver.gd")
	assert(events_source.find("const UI_CHRONICLE_RENDERED := &\"ui_chronicle_rendered\"") != -1,
		"Chronicle needs its dedicated stable render-confirmation event")
	assert(_chronicle_capture_contract_holds(main_source),
		"main must capture a completed run on post_game and before title teardown, while guarding initial boot")
	assert(_journal_chronicle_contract_holds(journal_source),
		"journal must append current-run Chronicle facts as its final section and emit the full journal payload")
	assert(_title_chronicle_contract_holds(title_source),
		"title must preserve ROWS and show a read-only 420x150 bottom-left Chronicle card after the gesture gate")
	assert(_title_continue_caption_contract_holds(title_source),
		"Continue caption must be rooted below the menu, not laid across its selectable rows")
	assert(_main_map_transition_contract_holds(main_source),
		"Main must own the persistent two-half map-transition veil, collapse ordinary QA, and consume transition input")
	assert(not _main_map_transition_contract_holds(main_source.replace(
		"tween_property(_map_transition_overlay, \"modulate:a\", target_alpha, seconds)", "")),
		"map-transition contract must fail if the real alpha tween is removed")
	assert(_world_map_transition_contract_holds(source),
		"World must defer destination mood/entity presentation until the covered MAP_CHANGED rebuild")
	assert(_atmosphere_map_transition_contract_holds(atmosphere_source),
		"Atmosphere must not apply destination mood to still-visible source geometry")
	# v0.15 T5.3 MAP-LIGHTS/DAY -- REAL calls, not source text. Referencing the
	# `WIAtmosphere` class_name directly would pull in the ObservableBus/Game
	# autoloads a `--script` run does not have, so this reuses the same
	# stub-and-recompile trick the TestDriver block below already uses. The two
	# functions under test are pure (moods.json in, float/bool out).
	var atmo_script := GDScript.new()
	atmo_script.source_code = atmosphere_source.replace(
		"class_name WIAtmosphere\n", "",
	).replace(
		"extends CanvasModulate",
		"extends CanvasModulate\n\nvar ObservableBus: Variant = null\nvar Game: Variant = null",
	)
	assert(atmo_script.reload() == OK, "atmosphere.gd (autoload-stubbed copy) failed to compile")
	var atmo: Node = atmo_script.new()
	assert(atmo.phase_light_energy("day", false) == 0.0,
		"a map with a sky still zeroes its lights by day (the shipped default is untouched)")
	assert(atmo.phase_light_energy("day", true) == 1.0,
		"an opted-out map keeps full light energy by day -- the whole point of the key")
	assert(atmo.phase_light_energy("night", false) == 1.0
		and atmo.phase_light_energy("night", true) == 1.0,
		"dusk/night are unchanged either way -- the opt-out is a FLOOR, never an override")
	var street_grade := Color(0.2, 0.26, 0.54)
	var street_layer: Color = atmo.layer_night_modulate("street", "night", "entities")
	var street_effective := street_grade * street_layer
	assert(street_layer != Color.WHITE and street_effective.is_equal_approx(Color(0.376, 0.4228, 0.6412)),
		"street's authored entity attenuation must retain 78% of its night grade")
	assert(atmo.layer_night_modulate("street", "day", "entities") == Color.WHITE,
		"layer attenuation is night-only; day remains byte-identical")
	assert(atmo.layer_night_modulate("street", "night", "no_such_layer") == Color.WHITE,
		"an unauthored layer falls back to identity")
	var moods: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/moods.json"))
	assert((moods["moods"]["mercantile_alleys"]["night"] as Array) == [0.2, 0.26, 0.54],
		"mercantile alleys must open the same real dusk-to-night gap as street")
	# Fresh-build behavior, not a source needle: compile World's real construction
	# choke point and run it twice through the real visual factory, as the player
	# and later companion builds do. The whole-field pass cannot rescue either.
	atmo.call("_set_layer_context", "street", "night")
	var build_script := GDScript.new()
	build_script.source_code = """extends Node
const PROP_COLOR := Color(0.55, 0.55, 0.58)
const MOOD_LAYERS: Array[String] = [\"entities\", \"decor\", \"scatter\"]
var _visual_factory: WIEntityVisualFactory
var _entities_root := Node2D.new()
var _atmosphere: Variant
var _mood_layer_visuals := {\"entities\": [], \"decor\": [], \"scatter\": []}
func _init(atmosphere: Variant) -> void:
	_atmosphere = atmosphere
	_visual_factory = WIEntityVisualFactory.new(16.0, null)
	add_child(_entities_root)
func _spawn_light(_holder: Node2D, _light: Dictionary) -> void:
	pass
%s
%s
""" % [_function_source(source, "_make_entity_visual"), _function_source(source, "_track_mood_layer_visual")]
	assert(build_script.reload() == OK, "World construction behavior harness failed to compile")
	var builder: Node = build_script.new(atmo)
	root.add_child(builder)
	var player_holder: Node2D = builder.call("_make_entity_visual", Vector2i(1, 1), "", [], Color.WHITE)
	var companion_holder: Node2D = builder.call("_make_entity_visual", Vector2i(1, 2), "", [], Color.WHITE)
	assert(player_holder.modulate.is_equal_approx(street_layer),
		"a freshly constructed night-map player holder must receive the current entity-layer attenuation")
	assert(companion_holder.modulate.is_equal_approx(street_layer),
		"a companion constructed later in the same night-map pass must receive the same attenuation immediately")
	builder.queue_free()
	assert(atmo.map_lights_by_day("seal_vault"),
		"seal_vault is sealed -- no sky, so its ward light is the room's only source at any hour")
	assert(not atmo.map_lights_by_day("inn") and not atmo.map_lights_by_day("street"),
		"skied maps must NOT opt in (a lantern adds nothing at noon)")
	assert(not atmo.map_lights_by_day("no_such_map"),
		"an unknown map id falls back to the shipped phase behaviour, never to lit")
	atmo.free()
	assert(_atmosphere_lights_by_day_contract_holds(atmosphere_source),
		"Atmosphere must latch the map opt-out in apply() before the refresh, and never from an arena")
	# a5 #205: the field legibility boost must exist AND be re-applied when
	# the mood lands, or dark-map interactables silently regress to invisible.
	assert(atmosphere_source.find("func field_entity_boost() -> float:") != -1
		and atmosphere_source.find("FIELD_LEGIBILITY_TARGET") != -1,
		"Atmosphere must expose field_entity_boost() with a field-tuned target")
	assert(source.find("func _apply_field_legibility() -> void:") != -1
		and source.find("WIEvents.UI_MOOD_APPLIED:") != -1,
		"World must apply the field legibility boost and re-apply it on UI_MOOD_APPLIED (a5 #205)")
	# a5 #205 review: the boost MUST be holder.modulate (inherits to the
	# drawing children) — holder.self_modulate tints only the bare holder,
	# which draws nothing, so the feature would be silently INERT. Lock it.
	assert(source.find("holder.modulate = m") != -1 and source.find("holder.self_modulate = m") == -1,
		"field legibility must use holder.modulate (inherits to children), never self_modulate (holder draws nothing)")
	assert(_wave_b_field_visual_contract_holds(source),
		"Wave-B blink, ward, and companion state need event-driven field visuals and reduced-motion parity")
	assert(driver_source.find("step.get(\"when_user_args\", {})") != -1 \
		and driver_source.find("QAPaths.user_args().get(arg_name, \"\")") != -1,
		"paced visual canonicals need an opt-in live-input assertion without changing headless streams")

	print("PASS: world.gd presentation wiring contracts hold")
	quit(0)
