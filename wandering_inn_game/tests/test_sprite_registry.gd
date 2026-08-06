extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = _load_json("res://data/sprites.json")
	var expected_counts: Dictionary = _build_expected_counts()
	for required_prop: String in ["dusty_scroll", "inn_room_ledger", "cellar_wardwork", "pantry_door_runes", "dirty_table", "bed", "door"]:
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
				var anim_rec: Dictionary = entry["animations"][anim_name]
				var sheet_key: String = "sheet_%s" % facing if facing != "" else "sheet"
				if WISpriteRegistry.is_fallback_sheet(String(anim_rec[sheet_key])):
					assert(actual >= 1, "%s animation %s: fallback placeholder needs >= 1 frame" % [sprite_id, full_name])
				else:
					assert(actual == expected, "%s animation %s: expected %d frames, got %d" % [sprite_id, full_name, expected, actual])
				_assert_expected_region(sprite_id, full_name, frames.get_frame_texture(full_name, 0))
	_assert_visual_log_assets_are_real(catalog)
	_assert_no_pc_sprites_in_scene()
	assert(not WISpriteRegistry.has_sprite("missing_sprite"), "registry should reject unknown sprite ids")
	_assert_biome_tiles_build()
	_assert_ice_tile_is_bespoke_and_opaque()
	_assert_missing_sheet_fallback()
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


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _build_expected_counts() -> Dictionary:
	var counts: Dictionary = {}

	counts["body_a/idle"] = 4      ## 416 / 104 (breathing-idle)
	counts["body_a/walk"] = 6      ## 624 / 104 (walking)
	counts["body_a/slice"] = 3     ## 312 / 104 (lead-jab)
	counts["body_a/cast"] = 6      ## 624 / 104 (fireball; now real down/side/up sheets)
	counts["body_a/hit"] = 6       ## 624 / 104 (taking-punch)
	counts["body_a/death"] = 7     ## 728 / 104 (falling-back-death)

	for variant in ["pc_human_m", "pc_human_f", "pc_drake_m", "pc_drake_f", "pc_gnoll_m", "pc_gnoll_f"]:
		counts["%s/idle" % variant] = 4
		counts["%s/walk" % variant] = 6
		counts["%s/slice" % variant] = 3
		counts["%s/cast" % variant] = 6
		counts["%s/hit" % variant] = 6
		counts["%s/death" % variant] = 7

	counts["citizen_f/idle"] = 4   ## 256 / 64
	counts["citizen_f/walk"] = 6   ## 384 / 64

	counts["dusty_scroll/idle"] = 1
	## #198 dusty_scroll split: the three inn props' own PixelLab sprites
	counts["inn_room_ledger/idle"] = 1
	counts["cellar_wardwork/idle"] = 1
	counts["pantry_door_runes/idle"] = 1
	counts["note_pinned/idle"] = 1
	## #222/#224 batch: stalls, alchemy stations, dormant-guardian marker
	counts["market_stall_pallass_b/idle"] = 1
	counts["market_stall_pallass_c/idle"] = 1
	counts["market_stall_wood/idle"] = 1
	counts["market_stall_silverfang/idle"] = 1
	counts["alchemy_bench/idle"] = 1
	counts["alchemy_still/idle"] = 1
	counts["alchemy_bench_dark/idle"] = 1
	counts["alchemy_bench_true/idle"] = 1
	counts["dormant_guardian_statue/idle"] = 1
	## #210/#223 character rigs
	counts["erin/idle"] = 4
	counts["erin/walk"] = 6
	counts["rags/idle"] = 4
	counts["rags/walk"] = 6
	counts["ruin_warden/idle"] = 4
	counts["ruin_warden/walk"] = 6
	counts["ruin_warden/slice"] = 3
	counts["ruin_warden/hit"] = 6
	counts["ruin_warden/death"] = 7
	## #224 batch B: transitions + sewers dressing + the warded-seam tell
	counts["shaft_ladder/idle"] = 1
	counts["phosphor_moss/idle"] = 1
	counts["spider_web/idle"] = 1
	counts["warded_seam/idle"] = 1
	counts["dirty_table/idle"] = 1
	counts["cauldron/idle"] = 1
	counts["short_order_range/idle"] = 1
	counts["witch_kettle_hook/idle"] = 1
	counts["corusdeer_carcass/idle"] = 1
	counts["bed/idle"] = 1
	counts["door/idle"] = 1

	counts["rug_woven_cream/idle"] = 1
	counts["table_brown/idle"] = 1
	counts["chest/idle"] = 1
	counts["chest_open/idle"] = 1
	counts["plant_pot/idle"] = 1
	counts["bar_counter/idle"] = 1
	counts["barrel/idle"] = 1
	counts["crate/idle"] = 1
	counts["stool/idle"] = 1
	counts["mushroom/idle"] = 1
	counts["sconce/idle"] = 4

	for icon_id: String in ["icon_basic_cleaning", "icon_light", "icon_basic_cooking", "icon_observe", "icon_soothe_clientele", "icon_unerring_aim", "icon_sweep_the_tables", "icon_servers_prescience"]:
		counts[icon_id + "/idle"] = 1

	for icon_id: String in ["icon_charming_smile", "icon_calming_touch"]:
		counts[icon_id + "/idle"] = 1

	counts["icon_sneak/idle"] = 1
	counts["icon_invisibility/idle"] = 1

	# Playtest fix wave (finding 3): the martial slate's icons. data_lint's
	# check_skill_icons is the gate that keeps a field skill from shipping
	# icon-less again.
	for icon_id: String in ["icon_even_footing", "icon_greater_strength", "icon_broader_shoulders", "icon_bar_fighting", "icon_rope_work", "icon_basic_repair"]:
		counts[icon_id + "/idle"] = 1

	for icon_id: String in ["icon_power_shot", "icon_keen_eye", "icon_quick_nock", "icon_piercing_shot", "icon_spellbound_strike", "icon_sudden_strike"]:
		counts[icon_id + "/idle"] = 1

	for icon_id: String in [
		"icon_hedge_remedy", "icon_evil_eye", "icon_bone_dart",
		"icon_deathbolt", "icon_detect_magic", "icon_advanced_cooking",
		"icon_signature_dish", "icon_eagle_eyes", "icon_marked_quarry",
	]:
		counts[icon_id + "/idle"] = 1

	for icon_id: String in ["icon_double_step", "icon_flash_step", "icon_animate_dead", "icon_hearthward_charm", "icon_greater_hearthward"]:
		counts[icon_id + "/idle"] = 1
	## Wave D-1 (#155) alchemist kit -- placeholder 16x16 icons (PixelLab drain).
	for icon_id: String in ["icon_low_grade_synthesis", "icon_cleansing_heat", "icon_magic_water_solvent", "icon_mineral_distillation", "icon_true_synthesis"]:
		counts[icon_id + "/idle"] = 1
	## Wave D-2 (#156) tamer/druid kit -- placeholder 16x16 icons (PixelLab drain).
	for icon_id: String in ["icon_healthy_rearing", "icon_animals_basic_command", "icon_lesser_bond", "icon_beasts_mending", "icon_wild_affinity", "icon_pack_bond", "icon_peace_of_the_wild", "icon_thorn_hand"]:
		counts[icon_id + "/idle"] = 1
	counts["skeleton_ally/idle"] = 4
	## Second Wind wave (#165) L14 grant kit -- placeholder 16x16 icons (PixelLab drain).
	for icon_id: String in ["icon_crescent_cut", "icon_pierce_thrust", "icon_ice_wall", "icon_flashfire_spellcraft", "icon_blinding_arrow", "icon_shadowstep", "icon_phantom_barrage", "icon_trusted_voice", "icon_barmaids_prescience", "icon_swift_service", "icon_evaluation_of_wealth", "icon_couriers_double_step", "icon_tea_omens", "icon_flarepepper_supplies", "icon_perfect_reduction", "icon_sworn_fang_ride_together"]:
		counts[icon_id + "/idle"] = 1

	## GH#145 bespoke rigs (PixelLab drain): ratici sheets are 416/104 idle,
	## 624/104 walk; hat_stand is a single-frame prop.
	counts["ratici/idle"] = 4
	counts["ratici/walk"] = 6
	counts["hat_stand/idle"] = 1

	for icon_id: String in [
		"icon_appraise_goods", "icon_called_shot", "icon_directed_strike",
		"icon_disarm_trap", "icon_find_trap", "icon_flame_dart",
		"icon_flame_pillar", "icon_measured_words", "icon_open_doors",
		"icon_perfect_hospitality", "icon_piercing_volley", "icon_soothing_presence",
	]:
		counts[icon_id + "/idle"] = 1

	for visual_log_prop: String in [
		"dart_slit_tell", "illusory_floor_tell", "delivery_board",
		"guild_notice_wall", "deep_fissure", "cold_hearth", "gnaw_pile",
		"warren_mouth", "nest_ledge",
	]:
		counts[visual_log_prop + "/idle"] = 1

	counts["shield_spider/idle"] = 4
	counts["shield_spider/slice"] = 3
	counts["shield_spider/hit"] = 6
	counts["shield_spider/death"] = 7

	counts["library_desk/idle"] = 1
	counts["library_shelf/idle"] = 1
	counts["sewer_grate/idle"] = 1
	counts["training_dummy/idle"] = 1
	counts["royal_soldier/idle"] = 4
	counts["a_hunter/idle"] = 4
	counts["a_hunter/walk"] = 6

	## #390: wilovan is a BESPOKE rig, and his COMBAT SET landed 2026-08-05 --
	## slice/hit/death are real sheets now, pinned at the frame counts v3 actually
	## produced (reference pose + N generated: 4+1, 4+1, 6+1), which is why slice
	## and hit no longer carry the borrowed pc_gnoll_m numbers (3 and 6). walk and
	## cast stay INERT pins -- absent animations are never checked (the loop walks
	## the ENTRY's animations) -- because nothing in world.gd or board_renderer
	## plays `walk` for a non-player rig, and his kit carries no spell, so
	## combat_screen's ranged-cast branch can never pick `cast` for him.
	for anim_name in [["idle", 4], ["walk", 6], ["slice", 5], ["cast", 6], ["hit", 5], ["death", 7]]:
		counts["wilovan/%s" % anim_name[0]] = int(anim_name[1])

	## #390 bespoke rigs (OWNED PixelLab v3, 8-dir generated, 3 facings kept +
	## side mirrored). IDLE ONLY by design: all four are field-only NPCs, so
	## board_renderer.play_anim's documented fallback (missing anim -> idle_side)
	## is never reached for them. Wilovan is the exception and keeps his full set
	## because combatants.json fields him.
	for bespoke_rig in ["selys", "krshia", "octavia", "ilvo", "gnoll_ranger"]:
		counts["%s/idle" % bespoke_rig] = 4

	# Playtest fix wave (findings 2, 4, 15): the corusdeer state sprites (a
	# tint is not a state) and the legible scree dressing.
	counts["corusdeer_wounded/idle"] = 1
	counts["scree_spill/idle"] = 1

	## #390 Tier-2/3 art drain: single-frame owned props. `lamb`/`lamb_lying`
	## ship SPRITE-ONLY (the riverfarm rows that place them are #396's branch),
	## `corusdeer_stag` replaces the doe rig inside wounded_corusdeer's
	## visual_states, and `hearth`/`worn_grass_bed`/`rug_woven_cream` moved off
	## pack regions onto owned sheets -- all still 1 frame, so the pin values
	## below are unchanged for the three repoints and new for the three adds.
	for owned_prop in ["lamb", "lamb_lying", "corusdeer_stag", "hearth", "worn_grass_bed", "rug_woven_cream"]:
		counts["%s/idle" % owned_prop] = 1

	counts["relc/idle"] = 4
	counts["relc/walk"] = 6
	counts["relc/slice"] = 3

	counts["pisces/idle"] = 4
	counts["pisces/walk"] = 6

	counts["olesm/idle"] = 4
	counts["olesm/walk"] = 6
	counts["zevara/idle"] = 4
	counts["zevara/walk"] = 6

	counts["klbkch/idle"] = 4
	counts["klbkch/walk"] = 6
	counts["klbkch/slice"] = 3

	counts["ceria/idle"] = 4
	counts["ceria/walk"] = 6
	counts["ceria/cast"] = 6
	counts["yvlon/idle"] = 4
	counts["yvlon/walk"] = 6
	counts["yvlon/slice"] = 3
	counts["ksmvr/idle"] = 4
	counts["ksmvr/walk"] = 6
	counts["ksmvr/slice"] = 3

	counts["eloise/idle"] = 4
	counts["eloise/walk"] = 6

	counts["grimalkin/idle"] = 4
	counts["grimalkin/walk"] = 6
	counts["tier_clerk/idle"] = 4
	counts["tier_clerk/walk"] = 6

	counts["vault_construct/idle"] = 4
	counts["vault_construct/walk"] = 6
	counts["vault_construct/slice"] = 3

	counts["antinium_worker/idle"] = 4

	for raskghar_id: String in ["raskghar_scout", "raskghar_awakened"]:
		counts["%s/idle" % raskghar_id] = 4
		counts["%s/walk" % raskghar_id] = 6
		counts["%s/slice" % raskghar_id] = 3

	for e3_static: String in [
		"hearth", "counter_left", "counter_mid", "counter_right",
		"shelf_bottles", "window_blue", "food_bread", "food_ham",
		"food_basket", "rug_woven_red", "facade_plaster", "bush_green",
		"grass_tuft", "flower_purple", "flower_tiny", "pebble",
		"boulder", "tree_big",
		"mushroom_purple_l", "mushroom_purple_m", "mushroom_purple_s",
		"inn_roof", "tree_round",
	]:
		counts["%s/idle" % e3_static] = 1
	counts["grill/idle"] = 4  ## Grill_01-Sheet 256px / 64px frames
	counts["campfire/idle"] = 4  ## Bonfire strip, 128/32

	for icon_id: String in ["icon_attack", "icon_dash", "icon_power_strike", "icon_flame_bolt", "icon_flame_jet", "icon_frost_bolt"]:
		counts["%s/idle" % icon_id] = 1

	for icon_id: String in [
		"icon_second_wind", "icon_piercing_strikes", "icon_quick_slash",
		"icon_flash_cut", "icon_devastating_slash", "icon_triple_thrust",
		"icon_extended_sweep", "icon_spear_flurry", "icon_ice_shard",
		"icon_icy_floor", "icon_flame_scythe", "icon_flare_burst",
		"icon_keener_edge",
	]:
		counts["%s/idle" % icon_id] = 1
	counts["unlit_lantern/idle"] = 1
	counts["inn_sign/idle"] = 1
	counts["wandering_inn_facade/idle"] = 1
	counts["request_board/idle"] = 1
	counts["bench/idle"] = 1

	counts["pedestal/idle"] = 1
	counts["anchor_waystone/idle"] = 1
	counts["trail_gap/idle"] = 1
	counts["stairs_up/idle"] = 1

	counts["lyonette/idle"] = 4
	counts["lyonette/walk"] = 6
	counts["human_laborer/idle"] = 4
	counts["human_laborer/walk"] = 6
	counts["gnoll_traveler/idle"] = 4
	counts["gnoll_traveler/walk"] = 6
	counts["drake_patron/idle"] = 4
	counts["drake_patron/walk"] = 6

	for goblin_id: String in ["goblin_base", "goblin_female", "goblin_sword"]:
		counts["%s/idle" % goblin_id] = 6
		counts["%s/walk" % goblin_id] = 6
	# (b1 #199 interim rows removed 2026-07-19: the c3 bespoke rig landed --
	# rags counts now live with the other #223 rig rows above.)
	counts["bat/idle"] = 4
	counts["bat/move"] = 8
	counts["bat/hit"] = 4
	counts["bat/death"] = 6

	counts["garden_door_inner/idle"] = 1
	counts["garden_fountain_basin/idle"] = 1
	counts["garden_fountain_statue/idle"] = 1

	counts["memorial_plinth/idle"] = 1
	counts["memorial_statue_human/idle"] = 1
	counts["memorial_statue_gnoll/idle"] = 1
	counts["memorial_statue_drake/idle"] = 1
	counts["memorial_statue_goblin/idle"] = 1

	for owned_static: String in ["cottage_thatch_a", "cottage_thatch_b", "riverfarm_longhouse",
			"riverfarm_windmill", "riverfarm_well", "riverfarm_haystack", "riverfarm_scarecrow",
			"riverfarm_earthwork", "riverfarm_fence_ew", "riverfarm_fence_ns", "riverfarm_dock_pier",
			"riverfarm_rowboat", "witch_cottage", "riverfarm_witch_elder", "riverfarm_witch_young"]:
		counts["%s/idle" % owned_static] = 1

	for licensed_static: String in ["crop_row_orange", "crop_row_green", "crop_row_dark_green",
			"tree_autumn_orange", "tree_autumn_red", "hollow_glow_stone", "hollow_mushroom_cluster",
			"hollow_canopy_tree", "hollow_small_tree", "hollow_bent_tree"]:
		counts["%s/idle" % licensed_static] = 1

	counts["river_wolf_idle/idle"] = 4

	counts["rock_crab/idle"] = 4

	counts["briar_collector/idle"] = 1
	counts["briar_collector_deep/idle"] = 1
	counts["river_wolf/idle"] = 1

	counts["corusdeer/idle"] = 1
	## #330 R3: the healed doe's four-frame breathing idle (owned PixelLab rig).
	counts["corusdeer_doe/idle"] = 4
	## #330 R3: the deer's bedded hollow (Vegetation atlas region at prop scale).
	counts["worn_grass_bed/idle"] = 1
	## #308: the camp hollow's own props (owned PixelLab, one frame each).
	counts["hide_rack/idle"] = 1
	counts["drying_rack/idle"] = 1
	counts["drying_rack_hung/idle"] = 1
	counts["turf_cut_mouth/idle"] = 1
	## GH#334: Codex gpt-image concept -> PixelLab image-to-pixelart-pro
	## hero-art wave (owned, one frame each).
	counts["codex_hut/idle"] = 1
	counts["ruin_gate/idle"] = 1
	counts["rune_door/idle"] = 1
	counts["wardstone_anchor/idle"] = 1
	counts["witch_cauldron/idle"] = 1
	## <!-- v017-L4 BEGIN --> CROSS-OWNERSHIP, DISCLOSED. The v0.17 art lane
	## owns assets/, data/sprites.json and map sprite fields, and explicitly
	## NOT .gd files -- but this table is the mechanical mirror of
	## sprites.json's ids (_build_expected_counts has no default: .get(..., -1)
	## then assert(expected >= 0), and a failed assert HANGS the headless run),
	## so a new sprite row cannot ship without its key here. PR #344 set the
	## same precedent one wave earlier. Appended, never reordered.
	##
	## DROPPING THIS BLOCK: it is only safe to remove together with the data
	## rows it mirrors, or the suite goes red. The complete, mechanically
	## derived recipe -- three sprite rows, three map sprite fields, three
	## keys, and nothing else in data/ references these ids:
	##   data/sprites.json                              drop "temper_bench"
	##   data/maps/pallass/pallass_forge_hall.json:179  -> "forge_station"
	##   data/sprites.json                              drop "wax_seal_tray"
	##   data/maps/invrisil/stationer.json:309          -> "crate"
	##   data/sprites.json                              drop "shop_oil_lamp"
	##   data/maps/pallass/pallass_den_shop.json:150    -> "crystal_lamp"
	##   the three counts lines below
	## Both states were RUN in the v0.17 fix wave and both print
	## "PASS: sprite registry catalog builds SpriteFrames". Reverting this
	## .gd hunk on its own is the one combination that is red.
	counts["temper_bench/idle"] = 1
	counts["wax_seal_tray/idle"] = 1
	counts["shop_oil_lamp/idle"] = 1
	## <!-- v017-L4 END -->
	counts["razorbeak/idle"] = 1
	## GH#156 follower-visual aliases of the same owned single-frame sheets.
	counts["wolf_companion/idle"] = 1
	counts["razorbeak_companion/idle"] = 1
	counts["mothbear/idle"] = 1
	counts["kingslayer_spider/idle"] = 1
	counts["forge_golem/idle"] = 1
	counts["watchgolem/idle"] = 1

	counts["hired_blade/idle"] = 4
	counts["hired_blade/walk"] = 6

	## v0.16.1 art wave: idle-only PixelLab v3 rigs, one frame per facing.
	for idle_only_rig: String in ["invrisil_lady_client", "master_coyle", "hedault",
			"city_scribe", "city_runner"]:
		counts["%s/idle" % idle_only_rig] = 1
	counts["coyle_shop_sign/idle"] = 1

	for invrisil_owned_static: String in ["plaza_fountain", "street_lamp", "coin_shop_sign", "guild_banner"]:
		counts["%s/idle" % invrisil_owned_static] = 1

	counts["dungeon_statue/idle"] = 1
	counts["dungeon_rubble/idle"] = 1
	counts["pressure_plate/idle"] = 1
	counts["snare_coil/idle"] = 1
	counts["illusory_floor_tell/idle"] = 1

	for pallass_static: String in ["great_lift", "crystal_lamp", "steam_vent",
			"price_board", "forge_station", "market_stall_pallass", "tier_wall",
			"anchor_waystone_slate"]:
		counts["%s/idle" % pallass_static] = 1

	# GH#184 city gate set (PixelLab statics)
	counts["city_gatehouse/idle"] = 1
	counts["city_gate_arch/idle"] = 1

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
		var blocked_tile_px: int = int(biome.get("blocked_tile_px", tile_px))
		var blocked_tile_set: TileSet = WISpriteRegistry.tile_set_for(blocked_sheet, blocked_tile_px)
		var blocked_source := blocked_tile_set.get_source(0) as TileSetAtlasSource
		assert(blocked_source != null, "biome %s blocked source should be an atlas source" % biome_id)
		var blocked_coord: Array = biome["blocked"]
		var blocked_atlas := Vector2i(int(blocked_coord[0]), int(blocked_coord[1]))
		assert(blocked_source.has_tile(blocked_atlas), "biome %s blocked tile missing at %s" % [biome_id, blocked_atlas])
