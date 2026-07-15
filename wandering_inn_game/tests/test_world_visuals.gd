extends SceneTree


func _occurrence_count(source: String, needle: String) -> int:
	return source.split(needle).size() - 1


func _y_sort_contract_holds(source: String) -> bool:
	var make_body := source.get_slice("func _make_entity_visual", 1).get_slice("\nfunc ", 0)
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
	for function_name: String in ["_build_entities", "_refresh_entity_visual", "_reconcile_entity_presence"]:
		var function_body := source.get_slice("func %s" % function_name, 1).get_slice("\nfunc ", 0)
		if function_body.find(override_read) == -1:
			return false
	var rebuild_body := source.get_slice("func _rebuild_field", 1).get_slice("\nfunc ", 0)
	return rebuild_body.find(override_read) == -1


func _function_body(source: String, function_name: String) -> String:
	return source.get_slice("func %s" % function_name, 1).get_slice("\nfunc ", 0)


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
	var builder := _function_body(source, "_build_body_text")
	var chronicle_heading := builder.find("[b]Chronicle[/b]")
	return builder.find("chronicle_facts: Dictionary") != -1 \
		and builder.find("chronicle_facts.is_empty()") != -1 \
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


func _init() -> void:
	WITestWatchdog.arm(self)
	var source := FileAccess.get_file_as_string("res://src/world/world.gd")
	assert(not source.is_empty(), "world.gd must exist")

	var body := source.get_slice("func _reconcile_entity_presence", 1).get_slice("\nfunc ", 0)
	assert(not body.is_empty(), "world.gd must define _reconcile_entity_presence (the GH#104 PHASE_CHANGED presence reconciler)")
	assert(body.find("unregister_light") != -1,
		"_reconcile_entity_presence's free arm must unregister PointLight2D children from _atmosphere before queue_free (the _refresh_entity_visual discipline)")
	assert(body.find("_light_count -= 1") != -1,
		"_reconcile_entity_presence's free arm must decrement _light_count (mirrors _spawn_light's increment)")
	assert(body.find("LIGHT_BUDGET") != -1,
		"_reconcile_entity_presence must re-check the LIGHT_BUDGET assert after a reconcile (the _refresh_entity_visual discipline)")
	assert(body.find("hide_sprite") != -1,
		"_reconcile_entity_presence must skip hide_sprite entities (matches _build_entities' guard)")

	assert(_y_sort_contract_holds(source),
		"entity Y-sort overrides need numeric catalog fallback, holder bias, zero-shift sprite/shadow cancellation, and entity-only plumbing")
	for deleted_clause: String in [
		"else float(catalog_entry.get(\"field_y_sort_bias_px\", 0.0))",
		"holder.position.y += y_sort_bias",
		"CELL - anchor.y * frame_size.y * spr.scale.y - y_sort_bias",
		"shadow.position = Vector2(CELL * 0.5, CELL - 2.0 - y_sort_bias)",
		"ent.get(\"field_y_sort_bias_px\", null)",
	]:
		assert(not _y_sort_contract_holds(source.replace(deleted_clause, "")),
			"Y-sort contract must reject deletion of: %s" % deleted_clause)
	var broadened_scope := source.replace(
		"\t\tPLAYER_COLOR\n\t)",
		"\t\tPLAYER_COLOR,\n\t\tent.get(\"field_y_sort_bias_px\", null)\n\t)"
	)
	assert(broadened_scope != source and not _y_sort_contract_holds(broadened_scope),
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
	assert(driver_source.find("step.get(\"when_user_args\", {})") != -1 \
		and driver_source.find("QAPaths.user_args().get(arg_name, \"\")") != -1,
		"paced visual canonicals need an opt-in live-input assertion without changing headless streams")

	print("PASS: world.gd presentation wiring contracts hold")
	quit(0)
