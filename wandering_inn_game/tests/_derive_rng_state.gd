extends SceneTree
## Derive fixture rng_state from RNG.seed; never hand-type a small state value.
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var n := int(arg)
		var rng := RandomNumberGenerator.new()
		rng.seed = n
		print("seed=%d -> state=%d" % [n, rng.state])
	quit()
