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

	print("PASS: world.gd presentation wiring contracts hold")
	quit(0)
