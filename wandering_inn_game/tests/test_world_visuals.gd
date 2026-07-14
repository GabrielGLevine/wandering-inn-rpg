extends SceneTree


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

	var make_body := source.get_slice("func _make_entity_visual", 1).get_slice("\nfunc ", 0)
	assert(make_body.find("field_y_sort_bias_override") != -1,
		"_make_entity_visual must accept a per-entity field Y-sort bias override")
	assert(make_body.find("field_y_sort_bias_override is float or field_y_sort_bias_override is int") != -1,
		"entity sort override must accept only numeric values and otherwise fall back to the sprite catalog")
	for function_name: String in ["_build_entities", "_refresh_entity_visual", "_reconcile_entity_presence"]:
		var function_body := source.get_slice("func %s" % function_name, 1).get_slice("\nfunc ", 0)
		assert(function_body.find("ent.get(\"field_y_sort_bias_px\", null)") != -1,
			"%s must pass the per-entity field Y-sort bias override" % function_name)
	var accomplishment_branch := source.get_slice("elif type == WIEvents.ACCOMPLISHMENT_RECORDED:", 1).get_slice("\nelif ", 0)
	assert(accomplishment_branch.find("_reconcile_entity_presence()") != -1,
		"accomplishment changes must reconcile same-map present_when entities")

	print("PASS: world.gd presentation wiring contracts hold")
	quit(0)
