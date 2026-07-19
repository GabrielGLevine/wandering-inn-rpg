class_name WIEntityVisualFactory
extends RefCounted

## Issue #194b seam 1: the entity-visual CONSTRUCTION half of world.gd's
## _make_entity_visual + the per-prop construction of
## _build_field_blocked_props, moved VERBATIM. Pure builder: returns
## detached nodes — the caller (world.gd's thin wrappers) owns light
## spawning (_atmosphere/_light_count state), add_child, and attach order.
## The y-sort bias CONTRACT comment + needles live here now;
## test_world_visuals slices THIS file for the construction contract and
## world.gd for the call-site override reads.

var _cell: float
var _sway_material: Material


func _init(cell_px: float, sway_material: Material) -> void:
	_cell = cell_px
	_sway_material = sway_material


func make(
	cell: Vector2i,
	sprite_id: String,
	tint: Variant,
	fallback_color: Color,
	facing: String = "",
	sway: bool = false,
	field_y_sort_bias_override: Variant = null,
) -> Node2D:
	var CELL := _cell
	var holder := Node2D.new()
	holder.position = Vector2(cell) * CELL
	var uses_sprite := false
	if sprite_id != "" and WISpriteRegistry.has_sprite(sprite_id):
		var spr := AnimatedSprite2D.new()
		# GH#169: pixel sprites stay crisp at ANY render_scale (the 0.55 rock
		# crab blurred under the default Linear filter); UI chrome keeps Linear.
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		spr.centered = false
		var facing_anim := "idle_side" if facing in ["left", "right"] else "idle_%s" % facing
		var anim := "idle_down" if spr.sprite_frames.has_animation("idle_down") else "idle"
		if facing != "" and spr.sprite_frames.has_animation(facing_anim):
			anim = facing_anim
			spr.flip_h = facing == "left"
		spr.play(anim)
		if tint is Array and (tint as Array).size() == 3:
			var tint_values := tint as Array
			spr.modulate = Color(float(tint_values[0]), float(tint_values[1]), float(tint_values[2]))
		if sway:
			spr.material = _sway_material
		var catalog_entry: Dictionary = WISpriteRegistry.entry_for(sprite_id)
		if catalog_entry.has("render_scale"):
			var s := float(catalog_entry["render_scale"])
			spr.scale = Vector2(s, s)
		# `field_y_sort_bias_px` (sprites.json, opt-in, SIGNED -- negative pulls
		# the key north, positive pushes it south; inn_roof's +20 is the first
		# positive consumer) lets a
		# catalog entry pull its own `holder`'s Y-SORT KEY north without
		# moving the sprite: `holder.position.y` gets the bias (sorts as if
		# further back), while `spr`/the shadow below get the bias
		# SUBTRACTED BACK OUT of their own (holder-relative) position so the
		# rendered pixels land exactly where the true cell puts them -- net
		# zero visual shift, sort-only effect. (An earlier version of this
		# fix used a raw `z_index`, which is a canvas-layer-GLOBAL sort key,
		# not scoped to y-sort siblings -- it drew the boss BEHIND THE FLOOR
		# TILES too, since those default to z_index 0, making it vanish
		# outright rather than just tuck behind the PC. Bias must stay
		# WITHIN the y-sort comparison, hence the position trick.)
		var y_sort_bias := (
			float(field_y_sort_bias_override)
			if field_y_sort_bias_override is float or field_y_sort_bias_override is int
			else float(catalog_entry.get("field_y_sort_bias_px", 0.0))
		)
		holder.position.y += y_sort_bias
		var frame_tex := spr.sprite_frames.get_frame_texture(anim, 0)
		var frame_size := frame_tex.get_size() if frame_tex != null else Vector2(CELL, CELL)
		var anchor := WISpriteRegistry.anchor_for(sprite_id)
		spr.position = Vector2(
			CELL * 0.5 - anchor.x * frame_size.x * spr.scale.x,
			CELL - anchor.y * frame_size.y * spr.scale.y - y_sort_bias
		)
		if bool(catalog_entry.get("shadow", false)):
			var shadow := Sprite2D.new()
			# GH#169: pixel sprites stay crisp at ANY render_scale (the 0.55 rock
			# crab blurred under the default Linear filter); UI chrome keeps Linear.
			shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			shadow.texture = WISpriteRegistry.shadow_texture()
			shadow.position = Vector2(CELL * 0.5, CELL - 2.0 - y_sort_bias)
			var shadow_w := clampf(frame_size.x * spr.scale.x / 24.0, 0.6, 2.5)
			shadow.scale = Vector2(shadow_w, shadow_w * 0.8)
			holder.add_child(shadow)
		holder.add_child(spr)
		uses_sprite = true
	else:
		var rect := ColorRect.new()
		rect.color = fallback_color
		rect.size = Vector2(CELL - 8, CELL - 8)
		rect.position = Vector2(4, 4)
		holder.add_child(rect)
	holder.set_meta("uses_sprite", uses_sprite)
	return holder


func make_blocked_prop(cell: Vector2i, sprite_id: String) -> Sprite2D:
	var CELL := _cell
	var frames: SpriteFrames = WISpriteRegistry.frames_for(sprite_id)
	var animation := &"idle_down" if frames.has_animation(&"idle_down") else &"idle"
	var frame_texture := frames.get_frame_texture(animation, 0)
	assert(frame_texture != null, "blocked prop %s needs a frame" % sprite_id)
	var spr := Sprite2D.new()
	# GH#169: pixel sprites stay crisp at ANY render_scale (the 0.55 rock
	# crab blurred under the default Linear filter); UI chrome keeps Linear.
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.name = "BlockedProp_%d_%d" % [cell.x, cell.y]
	spr.texture = frame_texture
	spr.centered = false
	spr.position = Vector2(cell) * CELL
	var catalog_entry: Dictionary = WISpriteRegistry.entry_for(sprite_id)
	var scale_value := float(catalog_entry.get("render_scale", 1.0))
	spr.scale = Vector2(scale_value, scale_value)
	var frame_size := frame_texture.get_size()
	var anchor := WISpriteRegistry.anchor_for(sprite_id)
	spr.offset = Vector2(
		CELL * 0.5 / scale_value - anchor.x * frame_size.x,
		CELL / scale_value - anchor.y * frame_size.y
	)
	return spr
