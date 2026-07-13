extends SceneTree
## World-presentation WIRING contracts for world.gd -- test_combat_visuals.gd's
## raw-source slicing idiom (world.gd needs autoloads, so it can never be
## load()+instantiated under --script; assert the wiring, not the behavior).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_world_visuals.gd


func _init() -> void:
	WITestWatchdog.arm(self)
	var source := FileAccess.get_file_as_string("res://src/world/world.gd")
	assert(not source.is_empty(), "world.gd must exist")

	# GH#104 reconciler light discipline (review item): the FREE arm must
	# mirror _refresh_entity_visual's unregister loop -- detach every
	# PointLight2D child from _atmosphere AND decrement _light_count BEFORE
	# queue_free. Skipping it leaks one stale registry entry per phase-flip
	# cycle and ratchets _light_count toward the LIGHT_BUDGET assert (a
	# failed assert HANGS headless). LATENT today: no shipped present_when
	# entity carries a light, and a live probe cannot observe the leak in
	# one waking (atmosphere.gd's is_instance_valid guards + budget
	# headroom hide it) -- a lifecycle probe with a temporary light-carrier
	# entity verified flip-clean at fix time (2026-07-13); THIS wiring
	# tripwire is the permanent tooth.
	var body := source.get_slice("func _reconcile_entity_presence", 1).get_slice("\nfunc ", 0)
	assert(not body.is_empty(), "world.gd must define _reconcile_entity_presence (the GH#104 PHASE_CHANGED presence reconciler)")
	assert(body.find("unregister_light") != -1,
		"_reconcile_entity_presence's free arm must unregister PointLight2D children from _atmosphere before queue_free (the _refresh_entity_visual discipline)")
	assert(body.find("_light_count -= 1") != -1,
		"_reconcile_entity_presence's free arm must decrement _light_count (mirrors _spawn_light's increment)")
	assert(body.find("LIGHT_BUDGET") != -1,
		"_reconcile_entity_presence must re-check the LIGHT_BUDGET assert after a reconcile (the _refresh_entity_visual discipline)")
	# Build-arm guard: a hide_sprite entity never gets a visual from
	# _build_entities, so the reconciler must skip it too or a phase flip
	# builds a phantom twin.
	assert(body.find("hide_sprite") != -1,
		"_reconcile_entity_presence must skip hide_sprite entities (matches _build_entities' guard)")

	print("PASS: world.gd presentation wiring contracts hold")
	quit(0)
