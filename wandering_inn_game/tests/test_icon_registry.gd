extends SceneTree

const OWNED_ICONS := [
	"icon_flash_cut",
	"icon_bone_dart",
	"icon_power_strike",
	"icon_quick_slash",
	"icon_devastating_slash",
	"icon_crescent_cut",
	"icon_piercing_strikes",
	"icon_triple_thrust",
	"icon_extended_sweep",
	"icon_spear_flurry",
	"icon_pierce_thrust",
	"icon_keener_edge",
	"icon_keener_point",
	"icon_flame_bolt",
	"icon_flame_jet",
	"icon_frost_bolt",
	"icon_ice_shard",
	"icon_icy_floor",
	"icon_flame_scythe",
	"icon_flare_burst",
	"icon_spellbound_strike",
	"icon_spellbound_thrust",
	"icon_attack",
	"icon_dash",
	"icon_basic_swordwork",
]


func _init() -> void:
	WITestWatchdog.arm(self)
	for id: String in OWNED_ICONS:
		assert(WISpriteRegistry.has_sprite(id), "curated icon must be wired: " + id)
		var entry := WISpriteRegistry.entry_for(id)
		var path := String(entry.animations.idle.sheet)
		assert(path.begins_with("res://assets/icons/harvest/"), "owned glyphs must resolve through the shared sprite registry")
		var frames := WISpriteRegistry.frames_for(id)
		assert(frames.get_frame_count("idle") == 1, "each action owns exactly one glyph")
		var texture := frames.get_frame_texture("idle", 0)
		var image := texture.get_image()
		assert(not image.get_used_rect().size == Vector2i.ZERO, "owned icon must contain visible pixels")
		assert(image.get_width() in [16, 32] and image.get_height() in [16, 32], "native icon geometry must remain 16/32px")
	var basic := WISpriteRegistry.frames_for("icon_basic_swordwork").get_frame_texture("idle", 0).get_image()
	var power := WISpriteRegistry.frames_for("icon_power_strike").get_frame_texture("idle", 0).get_image()
	assert(basic.get_data() != power.get_data(), "Basic Swordwork must not reuse the impact-bearing Power Strike image")
	print("PASS: curated co-visible icons resolve through shared registry with native geometry and distinct sword skills")
	quit(0)
