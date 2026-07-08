extends SceneTree
## Validates the presentation sprite catalog can build SpriteFrames resources.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd


func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = _load_json("res://data/sprites.json")
	var expected_counts: Dictionary = _build_expected_counts()
	for required_prop: String in ["dusty_scroll", "dirty_table", "bed", "door"]:
		assert(catalog.has(required_prop), "sprites.json missing field prop sprite: " + required_prop)
	for required_enemy: String in ["goblin_base", "goblin_female", "goblin_sword", "bat"]:
		assert(catalog.has(required_enemy), "sprites.json missing enemy sprite: " + required_enemy)
	for sprite_id: String in catalog:
		assert(WISpriteRegistry.has_sprite(sprite_id), "registry missing sprite: " + sprite_id)
		var frames: SpriteFrames = WISpriteRegistry.frames_for(sprite_id)
		var entry: Dictionary = catalog[sprite_id]
		var directional: bool = bool(entry.get("directional", false))
		for anim_name: String in entry["animations"]:
			var facings: Array[String] = _facings(directional)
			for facing: String in facings:
				var full_name: String = "%s_%s" % [anim_name, facing] if facing != "" else anim_name
				assert(frames.has_animation(full_name), "%s missing animation: %s" % [sprite_id, full_name])
				var expected: int = expected_counts.get("%s/%s" % [sprite_id, anim_name], -1)
				assert(expected >= 0, "no expected frame count for %s/%s" % [sprite_id, anim_name])
				var actual: int = frames.get_frame_count(full_name)
				## Public-checkout (fallback-art) runs: a missing sheet's
				## placeholder can't know the real sheet's frame count (the
				## PNG width carried it) -- relax to >=1 for exactly those
				## sheets; asset-present runs keep the exact pin.
				var anim_rec: Dictionary = entry["animations"][anim_name]
				var sheet_key: String = "sheet_%s" % facing if facing != "" else "sheet"
				if WISpriteRegistry.is_fallback_sheet(String(anim_rec[sheet_key])):
					assert(actual >= 1, "%s animation %s: fallback placeholder needs >= 1 frame" % [sprite_id, full_name])
				else:
					assert(actual == expected, "%s animation %s: expected %d frames, got %d" % [sprite_id, full_name, expected, actual])
				_assert_expected_region(sprite_id, full_name, frames.get_frame_texture(full_name, 0))
	assert(not WISpriteRegistry.has_sprite("missing_sprite"), "registry should reject unknown sprite ids")
	_assert_biome_tiles_build()
	_assert_missing_sheet_fallback()
	print("PASS: sprite registry catalog builds SpriteFrames")
	quit(0)


## Fallback-art contract: a nonexistent sheet path must yield a
## valid frame-sized placeholder (never assert/crash) so a public checkout
## without the private asset bundle still boots. Exercises BOTH the tile path
## (tile_set_for) and the sprite-strip path (_add_strip), including a region
## crop against a missing sheet (must stay in-bounds).
func _assert_missing_sheet_fallback() -> void:
	var bogus_tile := "res://assets/__nonexistent_tile__.png"
	var ts: TileSet = WISpriteRegistry.tile_set_for(bogus_tile, 16)
	assert(ts != null, "missing tile sheet should yield a placeholder TileSet, not crash")
	assert(ts.tile_size == Vector2i(16, 16), "placeholder TileSet tile size mismatch")
	var src := ts.get_source(0) as TileSetAtlasSource
	assert(src != null, "placeholder TileSet should expose atlas source 0")
	assert(src.texture != null, "placeholder TileSet source needs a texture")
	assert(src.has_tile(Vector2i(0, 0)), "placeholder TileSet must have at least tile (0,0)")

	## Sprite-strip path: no region -> a single frame-sized placeholder frame.
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	WISpriteRegistry._add_strip(frames, "walk", "res://assets/__nonexistent_sprite__.png", Vector2i(16, 16), 6.0, [])
	assert(frames.has_animation("walk"), "placeholder strip should register the animation")
	assert(frames.get_frame_count("walk") >= 1, "placeholder strip needs >= 1 frame")
	var tex := frames.get_frame_texture("walk", 0)
	assert(tex != null, "placeholder frame texture must be non-null")
	assert(tex.get_width() >= 16 and tex.get_height() >= 16, "placeholder frame must be at least frame-sized")

	## Region crop against a missing sheet must stay in-bounds and yield the
	## region_w/frame_w frame count (64/16 = 4), never an out-of-range error.
	var frames2 := SpriteFrames.new()
	frames2.remove_animation("default")
	WISpriteRegistry._add_strip(frames2, "idle", "res://assets/__nonexistent_region__.png", Vector2i(16, 16), 6.0, [0, 0, 64, 16])
	assert(frames2.get_frame_count("idle") == 4, "region placeholder should yield 4 frames")


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


## Builds a map of expected frame counts: "sprite_id/anim_name" -> count.
## Counts derived from PNG widths in asset-index.md divided by frame_size.
## body_a (F2 outfit rebuild, 104px frames): idle=4, walk=6, slice=3, hit=6,
## death=7, cast=6; citizen_f: idle=4, walk=6.
func _build_expected_counts() -> Dictionary:
	var counts: Dictionary = {}

	## body_a frame counts (F2: PixelLab v2 clothed-traveler character,
	## 104x104 frame size, per-anim counts from the mannequin templates)
	counts["body_a/idle"] = 4      ## 416 / 104 (breathing-idle)
	counts["body_a/walk"] = 6      ## 624 / 104 (walking)
	counts["body_a/slice"] = 3     ## 312 / 104 (lead-jab)
	counts["body_a/cast"] = 6      ## 624 / 104 (fireball; now real down/side/up sheets)
	counts["body_a/hit"] = 6       ## 624 / 104 (taking-punch)
	counts["body_a/death"] = 7     ## 728 / 104 (falling-back-death)

	## PC creation variants (6 = 3 races x 2 genders, all the SAME F2
	## mannequin-template anim set, so counts match body_a exactly; per-variant
	## frame_size/render_scale/anchor differ, but frame COUNTS are template-fixed).
	## pc_human_m reuses body_a's sheets verbatim (the Human base).
	for variant in ["pc_human_m", "pc_human_f", "pc_drake_m", "pc_drake_f", "pc_gnoll_m", "pc_gnoll_f"]:
		counts["%s/idle" % variant] = 4
		counts["%s/walk" % variant] = 6
		counts["%s/slice" % variant] = 3
		counts["%s/cast" % variant] = 6
		counts["%s/hit" % variant] = 6
		counts["%s/death" % variant] = 7

	## citizen_f frame counts (all 64x64 frame size)
	counts["citizen_f/idle"] = 4   ## 256 / 64
	counts["citizen_f/walk"] = 6   ## 384 / 64

	## static field prop entries (single 64x64 region)
	counts["dusty_scroll/idle"] = 1
	## PixelLab prop batch -- dirty_table (cluttered pre-clean look),
	## cauldron (stew_pot), training_dummy (straw pell) are all single 64x64
	## PixelLab sheets, 1 frame each.
	counts["dirty_table/idle"] = 1
	counts["cauldron/idle"] = 1
	counts["bed/idle"] = 1
	counts["door/idle"] = 1

	## Decor prop entries (single-region static crops, all 1 frame)
	## (controller iteration: table_red/table_blue removed; rug_tan/table_brown added)
	counts["rug_tan/idle"] = 1
	counts["table_brown/idle"] = 1
	counts["chest/idle"] = 1
	## Admurin open-lid chest, single-region static (inn_chest
	## visual_states "opened" swap).
	counts["chest_open/idle"] = 1
	counts["plant_pot/idle"] = 1
	counts["bar_counter/idle"] = 1
	counts["barrel/idle"] = 1
	counts["crate/idle"] = 1
	counts["stool/idle"] = 1
	counts["mushroom/idle"] = 1
	## Sconce: Bonfire_01-Sheet.png strip, 128px / 32px frame = 4 frames
	counts["sconce/idle"] = 4

	## 8 code-drawn field-skill icons (single-frame)
	for icon_id: String in ["icon_basic_cleaning", "icon_light", "icon_basic_cooking", "icon_observe", "icon_soothe_clientele", "icon_unerring_aim", "icon_sweep_the_tables", "icon_servers_prescience"]:
		counts[icon_id + "/idle"] = 1

	## [Diplomat] kit: 2 code-drawn skill icons (single-frame)
	## -- charming_smile (field) + calming_touch (combat).
	for icon_id: String in ["icon_charming_smile", "icon_calming_touch"]:
		counts[icon_id + "/idle"] = 1

	## [Stealth] (`sneak`) code-drawn boot glyph
	## (single-frame), same policy as every icon above.
	counts["icon_sneak/idle"] = 1

	## Library/sewer/dummy statics (1-frame regions);
	## royal_soldier single-facing battler idle 256/64 = 4;
	## a_hunter directional idle 256/64 = 4, walk maps the Run sheets 384/64 = 6.
	counts["library_desk/idle"] = 1
	counts["library_shelf/idle"] = 1
	counts["sewer_grate/idle"] = 1
	counts["training_dummy/idle"] = 1
	counts["royal_soldier/idle"] = 4
	counts["a_hunter/idle"] = 4
	counts["a_hunter/walk"] = 6

	## Relc: DIRECTIONAL + animated
	## (PixelLab v2 create-character-pro -> animate-character; 124x124 frames,
	## down/side/up sheets). idle=breathing-idle(4), walk=walking(6),
	## slice=lead-jab(3) -- the spear thrust reads cleanly.
	counts["relc/idle"] = 4
	counts["relc/walk"] = 6
	counts["relc/slice"] = 3

	## Pisces: DIRECTIONAL + animated
	## (hooded white-robe necromancer; 108x108 frames, down/side/up).
	## idle=breathing-idle(4), walk=walking(6).
	counts["pisces/idle"] = 4
	counts["pisces/walk"] = 6

	## Olesm (sky-blue Drake clerk w/ rolled map)
	## + Zevara (light-blue Drake Watch officer, armor) are now DIRECTIONAL +
	## animated (112x112 frames, down/side/up). idle(4) + walk(6).
	counts["olesm/idle"] = 4
	counts["olesm/walk"] = 6
	counts["zevara/idle"] = 4
	counts["zevara/walk"] = 6

	## The two Raskghar (scout + awakened boss) are DIRECTIONAL +
	## animated via the same F2/upgrade PixelLab v2 mannequin templates (124x124
	## frames, down/side/up). idle=breathing-idle(4), walk=walking(6),
	## slice=lead-jab(3) -- the reaching claw swipe reads.
	for raskghar_id: String in ["raskghar_scout", "raskghar_awakened"]:
		counts["%s/idle" % raskghar_id] = 4
		counts["%s/walk" % raskghar_id] = 6
		counts["%s/slice" % raskghar_id] = 3

	## Dressing sprites (single-region statics; grill is a 4-frame strip)
	for e3_static: String in [
		"hearth", "counter_left", "counter_mid", "counter_right",
		"shelf_bottles", "window_blue", "food_bread", "food_ham",
		"food_basket", "rug_green", "facade_plaster", "bush_green",
		"grass_tuft", "flower_purple", "flower_tiny", "pebble",
		"boulder", "tree_big",
		"mushroom_purple_l", "mushroom_purple_m", "mushroom_purple_s",
		"inn_roof", "tree_round",
	]:
		counts["%s/idle" % e3_static] = 1
	counts["grill/idle"] = 4  ## Grill_01-Sheet 256px / 64px frames
	counts["campfire/idle"] = 4  ## Bonfire strip, 128/32

	## Hotbar icons: single 16x16 crops, 1 frame each.
	for icon_id: String in ["icon_attack", "icon_dash", "icon_power_strike", "icon_flame_bolt", "icon_flame_jet", "icon_frost_bolt"]:
		counts["%s/idle" % icon_id] = 1

	## Class-kit icons (placeholder glyphs, single 16x16 frames).
	for icon_id: String in [
		"icon_second_wind", "icon_piercing_strikes", "icon_quick_slash",
		"icon_flash_cut", "icon_devastating_slash", "icon_triple_thrust",
		"icon_extended_sweep", "icon_spear_flurry", "icon_ice_shard",
		"icon_icy_floor", "icon_flame_scythe", "icon_flare_burst",
		"icon_keener_edge",
	]:
		counts["%s/idle" % icon_id] = 1
	## [Light] prop (Furniture.png lantern crop, single frame).
	counts["unlit_lantern/idle"] = 1
	## Art-wiring task (2026-07-07): inn_sign is now a bespoke PixelLab
	## signpost (text-free plank; the sign's wording lives in toast/observe
	## copy only), single 64x64 sheet, 1 frame. Previously a Furniture.png
	## hanging-plank crop (44x21) -- see VISUAL-LOG, now closed.
	counts["inn_sign/idle"] = 1
	## Art-wiring task (2026-07-07): THE REQUEST BOARD's bespoke corkboard art
	## (guild_board), replacing the inn_sign-crop reuse VISUAL-LOG flagged as
	## reading small/dense. Single 64x64 PixelLab sheet, 1 frame.
	counts["request_board/idle"] = 1
	## Art-wiring task (2026-07-07): bench prop (Runner's Guild resting-runner
	## walk-on), replacing the `stool` stand-in VISUAL-LOG flagged (no bench
	## sprite existed in any in-hand pack). Single 64x64 PixelLab sheet, 1 frame.
	counts["bench/idle"] = 1

	## The ruin pedestal + the
	## shared pantry_door flicker/awakened placeholder, both single-region
	## statics (1 frame each), same convention as chest/sewer_grate/boulder.
	counts["pedestal/idle"] = 1
	counts["pantry_door_glow/idle"] = 1

	## Art-wiring task (2026-07-07): Lyonette's canon-correct bright-red-hair
	## sprite (replacing the citizen_f pink-tint stand-in, VISUAL-LOG closed) +
	## three inn-cast-variety NPC sprites (human_laborer, gnoll_traveler,
	## drake_patron), all PixelLab v2 create-character-pro/animate-character
	## directional sets (down/side/up, side sheet faces right/east, registry
	## mirrors west) -- idle=breathing-idle(4), walk=walking(6), same template
	## family as relc/pisces/olesm/zevara/pc_*/raskghar_*. lyonette/human_laborer
	## 104x104; gnoll_traveler 108x108; drake_patron 124x124.
	counts["lyonette/idle"] = 4
	counts["lyonette/walk"] = 6
	counts["human_laborer/idle"] = 4
	counts["human_laborer/walk"] = 6
	counts["gnoll_traveler/idle"] = 4
	counts["gnoll_traveler/walk"] = 6
	counts["drake_patron/idle"] = 4
	counts["drake_patron/walk"] = 6

	## Enemy sprites.
	## Goblin sheets are 1536x1024, 256x256 frames: 6 columns per facing row.
	for goblin_id: String in ["goblin_base", "goblin_female", "goblin_sword"]:
		counts["%s/idle" % goblin_id] = 6
		counts["%s/walk" % goblin_id] = 6
	## Bat_Fur sheets are 96px-high strips: idle/hit=4, move=8, death=6.
	counts["bat/idle"] = 4
	counts["bat/move"] = 8
	counts["bat/hit"] = 4
	counts["bat/death"] = 6

	## The Garden of Sanctuary. `garden_door_inner` is an
	## owned single-frame PixelLab static (34x48, the door/pantry_door_glow
	## convention); `garden_fountain_basin`/`garden_fountain_statue` are
	## single-region crops of the LICENSED Garden Pixel Crawler pack (both
	## FORBIDDEN/bundle:true/placeholder-fallback -- this test's own
	## `is_fallback_sheet` relax-to-`>=1` branch covers them in this public
	## checkout; the `== expected` pin below only bites once the private
	## bundle lands the real PNGs).
	counts["garden_door_inner/idle"] = 1
	counts["garden_fountain_basin/idle"] = 1
	counts["garden_fountain_statue/idle"] = 1

	## The memorial hill roster -- all 5 owned, single-frame
	## PixelLab statics (stone-ify ramp recolor, never LICENSED/never a
	## fallback-relaxed case).
	counts["memorial_plinth/idle"] = 1
	counts["memorial_statue_human/idle"] = 1
	counts["memorial_statue_gnoll/idle"] = 1
	counts["memorial_statue_drake/idle"] = 1
	counts["memorial_statue_goblin/idle"] = 1

	## 8b R1 (issue #10) -- the owned PixelLab riverfarm village set + the
	## witch's two-form idles, all single-frame statics (never fallback-
	## relaxed, owned art).
	for owned_static: String in ["cottage_thatch_a", "cottage_thatch_b", "riverfarm_longhouse",
			"riverfarm_windmill", "riverfarm_well", "riverfarm_haystack", "riverfarm_scarecrow",
			"riverfarm_earthwork", "riverfarm_fence_ew", "riverfarm_fence_ns", "riverfarm_dock_pier",
			"riverfarm_rowboat", "witch_cottage", "riverfarm_witch_elder", "riverfarm_witch_young"]:
		counts["%s/idle" % owned_static] = 1

	## Licensed picks (Free Pack Farm.png/Vegetation.png, Fairy Forest
	## Props.png/Tree.png) -- single-frame region crops, fallback-relaxed in a
	## public checkout via the SAME is_fallback_sheet branch the garden picks
	## above use.
	for licensed_static: String in ["crop_row_orange", "crop_row_green", "crop_row_dark_green",
			"tree_autumn_orange", "tree_autumn_red", "hollow_glow_stone", "hollow_mushroom_cluster",
			"hollow_canopy_tree", "hollow_small_tree"]:
		counts["%s/idle" % licensed_static] = 1

	## river_wolf_idle -- Admurin Canine_Gray_Idle.png, 192x32 sheet @ 32x32
	## frames = 6 frames (picks.md sec.6).
	counts["river_wolf_idle/idle"] = 6

	return counts


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
		# blocked cells may come from a sheet with a different native grid than
		# the floor (M5: street floor is a whole-image 540px tile, blocked is
		# 16px Wall_Tiles) — validate against blocked_tile_px, not tile_px.
		var blocked_tile_px: int = int(biome.get("blocked_tile_px", tile_px))
		var blocked_tile_set: TileSet = WISpriteRegistry.tile_set_for(blocked_sheet, blocked_tile_px)
		var blocked_source := blocked_tile_set.get_source(0) as TileSetAtlasSource
		assert(blocked_source != null, "biome %s blocked source should be an atlas source" % biome_id)
		var blocked_coord: Array = biome["blocked"]
		var blocked_atlas := Vector2i(int(blocked_coord[0]), int(blocked_coord[1]))
		assert(blocked_source.has_tile(blocked_atlas), "biome %s blocked tile missing at %s" % [biome_id, blocked_atlas])
