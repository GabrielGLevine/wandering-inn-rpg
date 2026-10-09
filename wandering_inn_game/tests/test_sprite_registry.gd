extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = _load_json("res://data/sprites.json")
	## C7: frame-count pins live in data (tools/wire_asset.py appends them).
	## A sprite animation without a key here is a hard failure below.
	var fixture: Dictionary = _load_json("res://qa/fixtures/sprite_frame_counts.json")
	assert(fixture.get("counts") is Dictionary, "sprite_frame_counts.json needs a top-level counts dict")
	var expected_counts: Dictionary = fixture["counts"]
	for required_prop: String in ["dusty_scroll", "inn_room_ledger", "cellar_wardwork", "pantry_door_runes", "dirty_table", "bed", "door"]:
		assert(catalog.has(required_prop), "sprites.json missing field prop sprite: " + required_prop)
	for required_enemy: String in ["goblin_base", "goblin_female", "goblin_sword", "bat"]:
		assert(catalog.has(required_enemy), "sprites.json missing enemy sprite: " + required_enemy)
	for sprite_id: String in catalog:
		assert(WISpriteRegistry.has_sprite(sprite_id), "registry missing sprite: " + sprite_id)
		var frames: SpriteFrames = WISpriteRegistry.frames_for(sprite_id)
		var resolved: String = WISpriteRegistry.resolved_id(sprite_id)
		var entry: Dictionary = catalog[resolved]
		var directional: bool = bool(entry.get("directional", false))
		for anim_name: String in entry["animations"]:
			var facings: Array[String] = _facings(directional)
			for facing: String in facings:
				var full_name: String = "%s_%s" % [anim_name, facing] if facing != "" else anim_name
				assert(frames.has_animation(full_name), "%s missing animation: %s" % [sprite_id, full_name])
				var expected: int = int(expected_counts.get("%s/%s" % [resolved, anim_name], -1))
				assert(expected >= 0, "no expected frame count for %s/%s" % [resolved, anim_name])
				var actual: int = frames.get_frame_count(full_name)
				var anim_rec: Dictionary = entry["animations"][anim_name]
				var sheet_key: String = "sheet_%s" % facing if facing != "" else "sheet"
				if WISpriteRegistry.is_fallback_sheet(String(anim_rec[sheet_key])):
					assert(actual >= 1, "%s animation %s: fallback placeholder needs >= 1 frame" % [sprite_id, full_name])
				else:
					assert(actual == expected, "%s animation %s: expected %d frames, got %d" % [sprite_id, full_name, expected, actual])
				_assert_expected_region(resolved, full_name, frames.get_frame_texture(full_name, 0))
	_assert_visual_log_assets_are_real(catalog)
	_assert_no_pc_sprites_in_scene()
	assert(not WISpriteRegistry.has_sprite("missing_sprite"), "registry should reject unknown sprite ids")
	_assert_biome_tiles_build()
	_assert_ice_tile_is_bespoke_and_opaque()
	_assert_missing_sheet_fallback()
	_assert_fallback_sprite_resolution()
	_assert_fallback_target_completeness()
	print("PASS: sprite registry catalog builds SpriteFrames")
	quit(0)


## The frozen-cell overlay tile. CONTRACT: exactly one 16x16 tile at (0,0),
## fully OPAQUE (a frozen cell must hide the water beneath it, not tint it),
## and never the placeholder. TRAP: this sheet is authored/owned art, NOT a
## bundle path -- a public checkout must render real ice, so a fallback here
## is a red, not a degrade.
func _assert_ice_tile_is_bespoke_and_opaque() -> void:
	var path := "res://assets/tiles/ice/ice_floor_tiles.png"
	assert(FileAccess.file_exists(path), "ice overlay sheet missing: " + path)
	assert(not WISpriteRegistry.is_fallback_sheet(path), "ice overlay fell back to placeholder: " + path)
	var ts: TileSet = WISpriteRegistry.tile_set_for(path, 16)
	assert(ts != null, "ice overlay TileSet failed to build")
	assert(ts.tile_size == Vector2i(16, 16), "ice overlay tile size must be 16x16")
	var src := ts.get_source(0) as TileSetAtlasSource
	assert(src != null, "ice overlay TileSet needs atlas source 0")
	assert(src.has_tile(Vector2i(0, 0)), "ice overlay needs tile (0,0) -- world.gd paints that coord")
	var tex: Texture2D = src.texture
	assert(tex != null, "ice overlay atlas needs a texture")
	assert(tex.get_width() == 16 and tex.get_height() == 16, "ice overlay must be a single 16x16 tile, got %dx%d" % [tex.get_width(), tex.get_height()])
	var img: Image = tex.get_image()
	var transparent := 0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			if img.get_pixel(x, y).a < 1.0:
				transparent += 1
	assert(transparent == 0, "ice overlay must be fully opaque, %d translucent px" % transparent)


func _assert_visual_log_assets_are_real(catalog: Dictionary) -> void:
	var required_ids := [
		"icon_appraise_goods", "icon_called_shot", "icon_directed_strike",
		"icon_disarm_trap", "icon_find_trap", "icon_flame_dart",
		"icon_flame_pillar", "icon_measured_words", "icon_open_doors",
		"icon_perfect_hospitality", "icon_piercing_volley", "icon_soothing_presence",
		"rock_crab", "dart_slit_tell", "illusory_floor_tell", "delivery_board",
		"guild_notice_wall", "deep_fissure", "cold_hearth", "gnaw_pile",
		"warren_mouth", "nest_ledge", "shield_spider",
	]
	for sprite_id: String in required_ids:
		assert(catalog.has(sprite_id), "VISUAL-LOG asset missing catalog id: " + sprite_id)
		var entry: Dictionary = catalog[sprite_id]
		for anim: Dictionary in entry["animations"].values():
			for key: String in anim:
				if not key.begins_with("sheet"):
					continue
				var path := String(anim[key])
				assert(path.begins_with("res://assets/"), "%s uses non-asset sheet: %s" % [sprite_id, path])
				assert(FileAccess.file_exists(path), "%s sheet does not exist: %s" % [sprite_id, path])
				assert(not WISpriteRegistry.is_fallback_sheet(path), "%s still uses fallback sheet: %s" % [sprite_id, path])


## pc_* ids are the PLAYER's own skin (WIGame.pc_sprite_variant); any map row
## wearing one puts a copy of the player on screen as an NPC or a prop.
func _assert_no_pc_sprites_in_scene() -> void:
	var maps: Dictionary = WISceneCatalog.compose()["maps"]
	for map_id: String in maps:
		var map: Dictionary = maps[map_id]
		for row_key: String in ["entities", "decor"]:
			for row: Variant in map.get(row_key, []):
				var rec: Dictionary = row
				_assert_row_sprite_not_pc(map_id, rec)
				for state: Variant in rec.get("visual_states", []):
					_assert_row_sprite_not_pc(map_id, state)


func _assert_row_sprite_not_pc(map_id: String, rec: Dictionary) -> void:
	var sprite := String(rec.get("sprite", ""))
	assert(not sprite.begins_with("pc_"), "%s/%s wears PC-only sprite '%s' -- give it an NPC rig" % [map_id, String(rec.get("id", "?")), sprite])


func _assert_missing_sheet_fallback() -> void:
	var bogus_tile := "res://assets/__nonexistent_tile__.png"
	var ts: TileSet = WISpriteRegistry.tile_set_for(bogus_tile, 16)
	assert(ts != null, "missing tile sheet should yield a placeholder TileSet, not crash")
	assert(ts.tile_size == Vector2i(16, 16), "placeholder TileSet tile size mismatch")
	var src := ts.get_source(0) as TileSetAtlasSource
	assert(src != null, "placeholder TileSet should expose atlas source 0")
	assert(src.texture != null, "placeholder TileSet source needs a texture")
	assert(src.has_tile(Vector2i(0, 0)), "placeholder TileSet must have at least tile (0,0)")

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	WISpriteRegistry._add_strip(frames, "walk", "res://assets/__nonexistent_sprite__.png", Vector2i(16, 16), 6.0, [])
	assert(frames.has_animation("walk"), "placeholder strip should register the animation")
	assert(frames.get_frame_count("walk") >= 1, "placeholder strip needs >= 1 frame")
	var tex := frames.get_frame_texture("walk", 0)
	assert(tex != null, "placeholder frame texture must be non-null")
	assert(tex.get_width() >= 16 and tex.get_height() >= 16, "placeholder frame must be at least frame-sized")

	var frames2 := SpriteFrames.new()
	frames2.remove_animation("default")
	WISpriteRegistry._add_strip(frames2, "idle", "res://assets/__nonexistent_region__.png", Vector2i(16, 16), 6.0, [0, 0, 64, 16])
	assert(frames2.get_frame_count("idle") == 4, "region placeholder should yield 4 frames")


func _assert_fallback_sprite_resolution() -> void:
	# Synthetic sheets keep this contract independent of the private overlay.
	var real_sheet := "res://assets/sprites/door_locked_heavy/Idle-Sheet.png"
	var missing_sheet := "res://assets/__nonexistent_pack__.png"
	assert(ResourceLoader.exists(real_sheet), "fixture sheet moved: " + real_sheet)
	WISpriteRegistry.reset()
	WISpriteRegistry._load_catalog()
	var cat: Dictionary = WISpriteRegistry._catalog
	var owned := {"render_scale": 0.4, "anchor": [0.25, 0.75], "shadow": true,
		"animations": {"idle": {"sheet": real_sheet, "frame_size": [16, 32],
			"region": [16, 0, 32, 32], "fps": 2}}}
	var primary := {"render_scale": 1.0, "anchor": [0.5, 1.0],
		"fallback_sprite": "__t_owned", "directional": true,
		"animations": {"idle": {"sheet_down": real_sheet, "sheet_side": real_sheet,
			"sheet_up": missing_sheet, "frame_size": [64, 64], "fps": 1}}}
	cat["__t_owned"] = owned
	cat["__t_missing"] = primary
	cat["__t_present"] = {"fallback_sprite": "__t_owned",
		"animations": {"idle": {"sheet": real_sheet, "frame_size": [64, 64], "fps": 1}}}
	cat["__t_missing_anim"] = cat["__t_present"].duplicate(true)
	cat["__t_missing_anim"]["animations"]["walk"] = {"sheet": missing_sheet, "frame_size": [64, 64]}
	assert(WISpriteRegistry.resolved_id("__t_missing") == "__t_owned", "one missing facing must swap the whole entry")
	assert(WISpriteRegistry.resolved_id("__t_missing_anim") == "__t_owned", "a missing later animation must swap the whole entry")
	assert(WISpriteRegistry.resolved_id("__t_present") == "__t_present", "present primary must stay primary")
	assert(WISpriteRegistry.has_sprite("__t_missing"), "existence uses the requested id")
	assert(not WISpriteRegistry.has_sprite("__t_unknown"), "resolution must not create catalog ids")
	assert(WISpriteRegistry.resolved_id("__t_unknown") == "__t_unknown", "unknown id stays unknown")
	assert(WISpriteRegistry.entry_for("__t_unknown").is_empty(), "unknown entry stays empty")
	assert(WISpriteRegistry.entry_for("__t_missing") == owned, "all presentation fields must follow the fallback")
	assert(WISpriteRegistry.anchor_for("__t_missing") == Vector2(0.25, 0.75), "anchor must follow fallback art")
	assert(is_equal_approx(float(WISpriteRegistry.entry_for("__t_missing")["render_scale"]), 0.4), "scale must follow fallback art")
	var frames := WISpriteRegistry.frames_for("__t_missing")
	assert(frames == WISpriteRegistry.frames_for("__t_missing"), "requested id must cache frames")
	assert(frames.has_animation("idle") and not frames.has_animation("idle_down"), "directionality must follow fallback art")
	assert(frames.get_frame_count("idle") == 2, "frame count must follow fallback region")
	assert(is_equal_approx(frames.get_animation_speed("idle"), 2.0), "timing must follow fallback art")
	var tex := frames.get_frame_texture("idle", 0) as AtlasTexture
	assert(tex.region == Rect2(16, 0, 16, 32), "fallback crop and frame geometry must replace the primary")
	assert(not WISpriteRegistry.is_fallback_sheet(real_sheet), "owned fallback must load real art")
	for invalid: Variant in ["__t_nope", "__t_invalid", "__t_chain", "__t_unavailable", "pc_test", 7, "", null]:
		var id := "__t_bad_%s" % str(invalid)
		cat[id] = {"fallback_sprite": invalid,
			"animations": {"idle": {"sheet": missing_sheet, "frame_size": [16, 23], "fps": 1}}}
		cat["__t_invalid"] = "not an entry"
		cat["__t_chain"] = {"fallback_sprite": "__t_owned", "animations": owned["animations"]}
		cat["__t_unavailable"] = {"animations": cat[id]["animations"]}
		cat["pc_test"] = owned
		assert(WISpriteRegistry.resolved_id(id) == id, "invalid fallback must retain placeholder path: " + id)
		var bad_frames := WISpriteRegistry.frames_for(id)
		assert(bad_frames.get_frame_texture("idle", 0).get_size() == Vector2(16, 23), "invalid fallback must retain primary placeholder geometry")
	cat["__t_self"] = {"fallback_sprite": "__t_self", "animations": cat["__t_unavailable"]["animations"]}
	assert(WISpriteRegistry.resolved_id("__t_self") == "__t_self", "self-target must not resolve")
	primary["animations"]["idle"]["sheet_up"] = real_sheet
	assert(WISpriteRegistry.resolved_id("__t_missing") == "__t_owned", "resolution must stay consistent with cached frames until reset")
	WISpriteRegistry.reset()
	assert(WISpriteRegistry._catalog.is_empty() and WISpriteRegistry._cache.is_empty(), "reset must clear catalog and frames")
	assert(WISpriteRegistry._resolved_ids.is_empty(), "reset must clear resolved ids")
	assert(WISpriteRegistry._placeholder_cache.is_empty() and WISpriteRegistry._missing_sheet_logged.is_empty(), "reset must clear placeholder state")
	WISpriteRegistry._load_catalog()
	assert(not WISpriteRegistry._catalog.has("__t_missing"), "reset must reload disk without synthetic entries")
	WISpriteRegistry._catalog["__t_owned"] = owned
	WISpriteRegistry._catalog["__t_missing"] = primary
	assert(WISpriteRegistry.resolved_id("__t_missing") == "__t_missing", "reset must reevaluate sheet availability")
	var fresh := WISpriteRegistry.frames_for("__t_missing")
	assert(fresh != frames and fresh.has_animation("idle_up"), "reset must rebuild primary frames")
	WISpriteRegistry.reset()


func _assert_fallback_target_completeness() -> void:
	var real_sheet := "res://assets/sprites/door_locked_heavy/Idle-Sheet.png"
	var primary := {"fallback_sprite": "__t_target", "animations": {"idle": {
		"sheet": "res://assets/__nonexistent_pack__.png", "frame_size": [16, 23]}}}
	var complete := {"directional": true, "animations": {"idle": {
		"sheet_down": real_sheet, "sheet_side": real_sheet, "sheet_up": real_sheet,
		"frame_size": [64, 64]}}}
	for missing_key: String in ["sheet_down", "sheet_side", "sheet_up", "sheet"]:
		WISpriteRegistry.reset()
		WISpriteRegistry._load_catalog()
		var target: Dictionary = complete.duplicate(true) if missing_key != "sheet" else {
			"animations": {"idle": {"sheet_side": real_sheet, "frame_size": [64, 64]}}}
		target["animations"]["idle"].erase(missing_key)
		WISpriteRegistry._catalog["__t_target"] = target
		WISpriteRegistry._catalog["__t_primary"] = primary
		assert(WISpriteRegistry.resolved_id("__t_primary") == "__t_primary", "target needs required sheet key: " + missing_key)
		assert(WISpriteRegistry.frames_for("__t_primary").get_frame_texture("idle", 0).get_size() == Vector2(16, 23), "incomplete target must keep safe primary placeholder")
		# The same absent key on a primary must select a complete target.
		WISpriteRegistry.reset()
		WISpriteRegistry._load_catalog()
		target["fallback_sprite"] = "__t_target"
		WISpriteRegistry._catalog["__t_primary"] = target
		WISpriteRegistry._catalog["__t_target"] = complete
		assert(WISpriteRegistry.resolved_id("__t_primary") == "__t_target", "primary missing required sheet key must resolve: " + missing_key)
		assert(WISpriteRegistry.frames_for("__t_primary").has_animation("idle_up"), "complete directional target must build every facing")
	var invalid_targets: Array = [{}, {"animations": null}, {"animations": []},
		{"animations": {}}, {"animations": {"idle": null}},
		{"animations": {"idle": {}}}]
	for bad_size: Variant in [null, [], [16], [16, 0], ["64", 64], [64, 64, 64]]:
		invalid_targets.append({"animations": {"idle": {"sheet": real_sheet, "frame_size": bad_size}}})
	invalid_targets.append({"animations": {"idle": {"sheet": real_sheet}}})
	for target: Dictionary in invalid_targets:
		WISpriteRegistry.reset()
		WISpriteRegistry._load_catalog()
		WISpriteRegistry._catalog["__t_primary"] = primary
		WISpriteRegistry._catalog["__t_target"] = target
		assert(WISpriteRegistry.resolved_id("__t_primary") == "__t_primary", "invalid animation target must not resolve: " + str(target))
		assert(WISpriteRegistry.frames_for("__t_primary").get_frame_count("idle") == 1, "invalid target must keep safe primary placeholder")
	WISpriteRegistry.reset()


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _facings(directional: bool) -> Array[String]:
	var out: Array[String] = []
	if directional:
		out.append("down")
		out.append("side")
		out.append("up")
	else:
		out.append("")
	return out


func _assert_expected_region(sprite_id: String, full_name: String, tex: Texture2D) -> void:
	if not sprite_id.begins_with("goblin_"):
		return
	var atlas := tex as AtlasTexture
	assert(atlas != null, "%s %s should use an atlas texture" % [sprite_id, full_name])
	var expected_y := -1
	if full_name.ends_with("_down"):
		expected_y = 0
	elif full_name.ends_with("_up"):
		expected_y = 256
	elif full_name.ends_with("_side"):
		expected_y = 768
	if expected_y >= 0:
		assert(int(atlas.region.position.y) == expected_y, "%s %s expected first frame y=%d, got %d" % [sprite_id, full_name, expected_y, int(atlas.region.position.y)])


func _assert_biome_tiles_build() -> void:
	var biomes: Dictionary = _load_json("res://data/biomes.json")
	for biome_id: String in ["inn", "street", "cave"]:
		assert(biomes.has(biome_id), "biomes.json missing biome: " + biome_id)
		var biome: Dictionary = biomes[biome_id]
		for key: String in ["sheet", "tile_px", "floor", "blocked"]:
			assert(biome.has(key), "biome %s missing %s" % [biome_id, key])
		var tile_px: int = int(biome["tile_px"])
		assert(tile_px > 0, "biome %s invalid tile_px" % biome_id)
		var tile_set: TileSet = WISpriteRegistry.tile_set_for(String(biome["sheet"]), tile_px)
		var cached: TileSet = WISpriteRegistry.tile_set_for(String(biome["sheet"]), tile_px)
		assert(tile_set == cached, "biome %s TileSet should be cached" % biome_id)
		assert(tile_set.tile_size == Vector2i(tile_px, tile_px), "biome %s TileSet tile size mismatch" % biome_id)
		assert(tile_set.has_source(0), "biome %s TileSet missing atlas source 0" % biome_id)
		var source := tile_set.get_source(0) as TileSetAtlasSource
		assert(source != null, "biome %s source 0 should be an atlas source" % biome_id)
		var floor_coord: Array = biome["floor"]
		var floor_atlas := Vector2i(int(floor_coord[0]), int(floor_coord[1]))
		assert(source.has_tile(floor_atlas), "biome %s floor tile missing at %s" % [biome_id, floor_atlas])
		var blocked_sheet := String(biome.get("blocked_sheet", biome["sheet"]))
		var blocked_tile_px: int = int(biome.get("blocked_tile_px", tile_px))
		var blocked_tile_set: TileSet = WISpriteRegistry.tile_set_for(blocked_sheet, blocked_tile_px)
		var blocked_source := blocked_tile_set.get_source(0) as TileSetAtlasSource
		assert(blocked_source != null, "biome %s blocked source should be an atlas source" % biome_id)
		var blocked_coord: Array = biome["blocked"]
		var blocked_atlas := Vector2i(int(blocked_coord[0]), int(blocked_coord[1]))
		assert(blocked_source.has_tile(blocked_atlas), "biome %s blocked tile missing at %s" % [biome_id, blocked_atlas])
