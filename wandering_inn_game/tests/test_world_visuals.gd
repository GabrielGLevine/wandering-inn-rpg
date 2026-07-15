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
	return true


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
	var journal_source := FileAccess.get_file_as_string("res://src/ui/journal.gd")
	var title_source := FileAccess.get_file_as_string("res://src/ui/title_screen.gd")
	assert(events_source.find("const UI_CHRONICLE_RENDERED := &\"ui_chronicle_rendered\"") != -1,
		"Chronicle needs its dedicated stable render-confirmation event")
	assert(_chronicle_capture_contract_holds(main_source),
		"main must capture a completed run on post_game and before title teardown, while guarding initial boot")
	assert(_journal_chronicle_contract_holds(journal_source),
		"journal must append current-run Chronicle facts as its final section and emit the full journal payload")
	assert(_title_chronicle_contract_holds(title_source),
		"title must preserve ROWS and show a read-only 420x150 bottom-left Chronicle card after the gesture gate")

	print("PASS: world.gd presentation wiring contracts hold")
	quit(0)
