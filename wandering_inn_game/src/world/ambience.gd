class_name WIAmbience

const DOT_TEXTURE := preload("res://assets/fx/particle_dot.png")
const LEAF_TEXTURE := preload("res://assets/fx/particle_leaf.png")

const PRESETS := ["fireflies", "dust_motes", "leaves", "pond_glints", "embers", "hit_sparks"]


static func make(preset: String, rect: Rect2) -> GPUParticles2D:
	assert(preset in PRESETS, "unknown ambience preset: " + preset)
	match preset:
		"fireflies":
			return _fireflies(rect)
		"dust_motes":
			return _dust_motes(rect)
		"leaves":
			return _leaves(rect)
		"pond_glints":
			return _pond_glints(rect)
		"embers":
			return _embers(rect)
		"hit_sparks":
			return _hit_sparks(rect)
	return null # unreachable -- assert above covers every non-PRESETS value


static func _base(rect: Rect2, texture: Texture2D, amount: int, lifetime: float) -> Dictionary:
	var node := GPUParticles2D.new()
	node.texture = texture
	node.amount = amount
	node.lifetime = lifetime
	node.preprocess = lifetime
	node.position = rect.get_center()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(rect.size.x * 0.5, rect.size.y * 0.5, 0.0)
	node.process_material = mat
	return {"node": node, "mat": mat}


static func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


static func _additive(node: GPUParticles2D) -> void:
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = cm


static func _fireflies(rect: Rect2) -> GPUParticles2D:
	var b := _base(rect, DOT_TEXTURE, 16, 4.0)
	var node: GPUParticles2D = b["node"]
	var mat: ParticleProcessMaterial = b["mat"]
	mat.direction = Vector3.ZERO
	mat.spread = 180.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3.ZERO
	mat.orbit_velocity_min = 0.05
	mat.orbit_velocity_max = 0.15
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(0.85, 1.0, 0.4, 1.0)
	mat.color_ramp = _fade_ramp()
	_additive(node)
	return node


static func _dust_motes(rect: Rect2) -> GPUParticles2D:
	var b := _base(rect, DOT_TEXTURE, 14, 6.0)
	var node: GPUParticles2D = b["node"]
	var mat: ParticleProcessMaterial = b["mat"]
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -0.3, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(1.0, 0.95, 0.85, 0.35)
	mat.color_ramp = _fade_ramp()
	_additive(node)
	return node


static func _leaves(rect: Rect2) -> GPUParticles2D:
	var b := _base(rect, LEAF_TEXTURE, 10, 5.0)
	var node: GPUParticles2D = b["node"]
	var mat: ParticleProcessMaterial = b["mat"]
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, 4.0, 0)
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0
	mat.scale_min = 0.8
	mat.scale_max = 1.3
	mat.color = Color(0.75, 0.55, 0.25, 1.0)
	mat.color_ramp = _fade_ramp()
	return node


static func _pond_glints(rect: Rect2) -> GPUParticles2D:
	var b := _base(rect, DOT_TEXTURE, 10, 2.5)
	var node: GPUParticles2D = b["node"]
	var mat: ParticleProcessMaterial = b["mat"]
	mat.direction = Vector3.ZERO
	mat.spread = 180.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.3
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.15
	mat.scale_max = 0.35
	mat.color = Color(0.85, 0.95, 1.0, 1.0)
	mat.color_ramp = _fade_ramp()
	_additive(node)
	return node


static func _embers(rect: Rect2) -> GPUParticles2D:
	var b := _base(rect, DOT_TEXTURE, 12, 3.0)
	var node: GPUParticles2D = b["node"]
	var mat: ParticleProcessMaterial = b["mat"]
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(1.0, 0.45, 0.15, 1.0)
	mat.color_ramp = _fade_ramp()
	_additive(node)
	return node


## One-shot combat impact spark burst (<=8 particles) fired at a
## struck combatant's cell. Unlike the always-on ambience presets above, the
## CALLER sets `one_shot`/`emitting` and frees it after `lifetime` (see
## board_renderer.gd's `spawn_hit_sparks`) -- so `preprocess` is forced back to
## 0 here (a one-shot burst must start EMPTY and pop, not read as already
## mid-life the way `_base`'s steady-state ambience emitters do). Warm-white
## radial sparks, short life, additive -- reads as a bright hit flare, wasm-safe
## constructs only (BOX emission + velocity/gravity/scale/color_ramp), same
## constraint list as every preset above.
static func _hit_sparks(rect: Rect2) -> GPUParticles2D:
	var b := _base(rect, DOT_TEXTURE, 8, 0.4)
	var node: GPUParticles2D = b["node"]
	var mat: ParticleProcessMaterial = b["mat"]
	node.preprocess = 0.0
	node.one_shot = true
	node.explosiveness = 1.0
	mat.direction = Vector3.ZERO
	mat.spread = 180.0
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 42.0
	mat.gravity = Vector3(0, 30.0, 0)
	mat.scale_min = 0.25
	mat.scale_max = 0.5
	mat.color = Color(1.0, 0.95, 0.6, 1.0)
	mat.color_ramp = _fade_ramp()
	_additive(node)
	return node
