extends SceneTree
## Dev utility, not a pass/fail suite (no assert, never run by
## ci_sweep.sh/CLAUDE.md's unit-suite list): prints the
## RandomNumberGenerator .state that results from a proper .seed = N
## init, for each N passed as a user arg. Mirrors the #38/#45
## re-derivation method (WISave stores/restores .state directly, never
## .seed -- a hand-typed small-int .state collapses the first randi()
## draw to the same degenerate output regardless of which small int is
## picked; deriving FROM a real .seed init avoids that). Usage:
## `godot --headless --path wandering_inn_game --script
## res://tests/_derive_rng_state.gd -- 1 2 3` then patch the printed
## state into the target fixture's rng_state and re-run its canonical.
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var n := int(arg)
		var rng := RandomNumberGenerator.new()
		rng.seed = n
		print("seed=%d -> state=%d" % [n, rng.state])
	quit()
