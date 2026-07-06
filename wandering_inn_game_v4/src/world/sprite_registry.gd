class_name WISpriteRegistry
extends RefCounted
## Builds and caches SpriteFrames from the data/sprites.json catalog.
## Presentation-side only (uses ResourceLoader) -- never referenced from src/core.

static var _catalog: Dictionary = {}
static var _cache: Dictionary = {}
static var _tile_sources: Dictionary = {}

## M-RELEASE R2 fallback-art contract. A PUBLIC checkout is missing the
## protected asset packs (see wandering_inn_game_v4/assets_manifest.json), so
## ResourceLoader.load() returns null for those sheets. Rather than
## assert/crash (the pre-R2 behavior), we synthesize a legible frame-sized
## placeholder texture -- a flat muted colour derived deterministically from
## the sheet path plus a 1px border -- so all downstream region/frame_size
## math still resolves and the game boots + passes QA with placeholder art.
## ZERO behavior change when assets are present (the null branch is unreached).
## A missing sprites.json ENTRY is still an assert (malformed catalog data,
## not a missing file) -- same convention as _load_catalog / the B2 note.
static var _placeholder_cache: Dictionary = {}
static var _missing_sheet_logged: Dictionary = {}


static func _load_catalog() -> void:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
		assert(parsed is Dictionary, "invalid sprites.json")
		_catalog = parsed


static func has_sprite(sprite_id: String) -> bool:
	_load_catalog()
	return _catalog.has(sprite_id)


## Returns the raw catalog entry for a sprite id (e.g. to read optional
## top-level fields like "render_scale"), or an empty Dictionary if unknown.
static func entry_for(sprite_id: String) -> Dictionary:
	_load_catalog()
	return _catalog.get(sprite_id, {})


## Fractional anchor point within a sprite's frame that should align to a
## cell's bottom-center (M5 R3 16px recalibration). Optional per-entry
## "anchor": [x, y] in data/sprites.json; defaults to [0.5, 1.0] (feet/base
## centered at the cell's bottom edge) -- the correct convention for both
## character sprites (which overhang the cell above, by design, at 16px) and
## floor-standing props. Consumed by the field (world.gd) and combat
## (combat_screen.gd) visual builders.
static func anchor_for(sprite_id: String) -> Vector2:
	var entry := entry_for(sprite_id)
	var raw: Variant = entry.get("anchor", [0.5, 1.0])
	if raw is Array and (raw as Array).size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2(0.5, 1.0)


## Deterministic position-seeded index into a variants array (M5 R4
## floor_layers schema, docs/superpowers/specs/2026-07-02-environment-ui-
## immersion-design.md sec.1) -- a pure function of the cell coordinate, no
## RNG stream touched, so the same cell always renders the same variant
## across saves/replays/QA runs. Shared by world.gd (field) and
## combat_screen.gd (arena board) so both pick variants the same way.
static func cell_variant_index(cell: Vector2i, count: int) -> int:
	if count <= 0:
		return 0
	var h := int(cell.x) * 374761393 + int(cell.y) * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return int(abs(h)) % count


## Shared contact-shadow texture (M5 E3, scene-assembly-guide P5): one cached
## soft black ellipse rendered under any sprite whose catalog entry sets
## "shadow": true. Generated, not an asset -- pack Shadows.png sheets can
## replace it per-prop later if the ellipse reads poorly.
static func shadow_texture() -> Texture2D:
	if _cache.has("__shadow__"):
		return _cache["__shadow__"]
	var w := 24
	var h := 10
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := (w - 1) * 0.5
	var cy := (h - 1) * 0.5
	for y in h:
		for x in w:
			var dx := (x - cx) / (w * 0.5)
			var dy := (y - cy) / (h * 0.5)
			var d := dx * dx + dy * dy
			if d < 1.0:
				# soft edge: fade alpha toward the rim
				img.set_pixel(x, y, Color(0, 0, 0, 0.35 * clampf(1.0 - d, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_cache["__shadow__"] = tex
	return tex


static func frames_for(sprite_id: String) -> SpriteFrames:
	_load_catalog()
	assert(_catalog.has(sprite_id), "unknown sprite id: " + sprite_id)
	if _cache.has(sprite_id):
		return _cache[sprite_id]
	var entry: Dictionary = _catalog[sprite_id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var directional := bool(entry.get("directional", false))
	for anim_name: String in entry["animations"]:
		var anim: Dictionary = entry["animations"][anim_name]
		var facings: Array[String] = _facings(directional)
		for facing: String in facings:
			var sheet_key := "sheet_%s" % facing if facing != "" else "sheet"
			var region_key := "region_%s" % facing if facing != "" else "region"
			var full_name := "%s_%s" % [anim_name, facing] if facing != "" else anim_name
			_add_strip(
				frames,
				full_name,
				String(anim[sheet_key]),
				Vector2i(int(anim["frame_size"][0]), int(anim["frame_size"][1])),
				float(anim.get("fps", 6)),
				anim.get(region_key, anim.get("region", []))
			)
	_cache[sprite_id] = frames
	return frames


## Cached TileSetAtlasSource for a sheet, gridded at tile_px. Each distinct
## sheet gets one TileSet the callers share via source id 0.
static func tile_set_for(sheet_path: String, tile_px: int) -> TileSet:
	var key := "%s@%d" % [sheet_path, tile_px]
	if _tile_sources.has(key):
		return _tile_sources[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(sheet_path):
		tex = ResourceLoader.load(sheet_path)
	if tex == null:
		tex = _placeholder_tile_texture(sheet_path, tile_px)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_px, tile_px)
	var grid := Vector2i(tex.get_width() / tile_px, tex.get_height() / tile_px)
	for x in grid.x:
		for y in grid.y:
			src.create_tile(Vector2i(x, y))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_px, tile_px)
	ts.add_source(src, 0)
	_tile_sources[key] = ts
	return ts


static func _facings(directional: bool) -> Array[String]:
	var out: Array[String] = []
	if directional:
		out.append("down")
		out.append("side")
		out.append("up")
	else:
		out.append("")
	return out


static func _add_strip(frames: SpriteFrames, anim_name: String, sheet_path: String, frame_size: Vector2i, fps: float, region_data: Variant = []) -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(sheet_path):
		tex = ResourceLoader.load(sheet_path)
	if tex == null:
		tex = _placeholder_strip_texture(sheet_path, frame_size, region_data)
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, not (anim_name.begins_with("death") or anim_name.begins_with("hit") or anim_name.begins_with("slice")))
	var origin := Vector2i.ZERO
	var strip_size := Vector2i(tex.get_width(), frame_size.y)
	if region_data is Array and (region_data as Array).size() == 4:
		var region := region_data as Array
		origin = Vector2i(int(region[0]), int(region[1]))
		strip_size = Vector2i(int(region[2]), int(region[3]))
	assert(strip_size.x >= frame_size.x and strip_size.y >= frame_size.y, "sprite region smaller than frame: " + sheet_path)
	var count := int(strip_size.x / frame_size.x)
	assert(count > 0, "sprite sheet has no frames: " + sheet_path)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(origin.x + i * frame_size.x, origin.y, frame_size.x, frame_size.y)
		frames.add_frame(anim_name, at)


## --- R2 fallback-art placeholder synthesis -----------------------------------

## Placeholder for a missing sprite SHEET. Sized to contain the requested
## region (so region_data crops stay in-bounds) or a single frame when no
## region is given -- either way >= one frame, so `_add_strip`'s frame math
## yields count >= 1.
static func _placeholder_strip_texture(sheet_path: String, frame_size: Vector2i, region_data: Variant) -> Texture2D:
	var w := frame_size.x
	var h := frame_size.y
	if region_data is Array and (region_data as Array).size() == 4:
		var r := region_data as Array
		w = maxi(w, int(r[0]) + int(r[2]))
		h = maxi(h, int(r[1]) + int(r[3]))
	return _placeholder_texture(sheet_path, maxi(w, 1), maxi(h, 1))


## Placeholder for a missing TILE sheet. Extent is inversely proportional to
## tile_px and capped at 32 tiles/axis, so a fine 16px sheet gets a generous
## grid (covers every atlas coord the maps reference, max ~[14,21]) while a
## whole-image 540px "tile" stays a cheap 1x1.
static func _placeholder_tile_texture(sheet_path: String, tile_px: int) -> Texture2D:
	var span: int = clampi(int(round(512.0 / float(maxi(tile_px, 1)))), 1, 32)
	var px := span * maxi(tile_px, 1)
	return _placeholder_texture(sheet_path, px, px)


## Deterministic flat muted colour (from the path hash) with a 1px darker
## border. Cached per path+size so repeated builds reuse one ImageTexture.
static func _placeholder_texture(seed_path: String, w: int, h: int) -> Texture2D:
	_log_missing_sheet(seed_path)
	var key := "%s@%dx%d" % [seed_path, w, h]
	if _placeholder_cache.has(key):
		return _placeholder_cache[key]
	var fill := _placeholder_color(seed_path)
	var border := Color(fill.r * 0.45, fill.g * 0.45, fill.b * 0.45, 1.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for x in w:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, h - 1, border)
	for y in h:
		img.set_pixel(0, y, border)
		img.set_pixel(w - 1, y, border)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[key] = tex
	return tex


static func _placeholder_color(seed_path: String) -> Color:
	var hv: int = abs(hash(seed_path))
	# Muted mid-tones (0.32..0.66) so a chip reads as a distinct solid block
	# without glaring; each pack/sheet gets its own stable hue.
	var r := 0.32 + float(hv & 0xFF) / 255.0 * 0.34
	var g := 0.32 + float((hv >> 8) & 0xFF) / 255.0 * 0.34
	var b := 0.32 + float((hv >> 16) & 0xFF) / 255.0 * 0.34
	return Color(r, g, b, 1.0)


## One `[fallback_art]` line per unique missing sheet per run. A plain print
## (NOT push_warning) so the grep discipline (SCRIPT ERROR|Parse Error|WARNING)
## is not tripped -- check_fallback_boot.sh additionally expects these lines.
static func _log_missing_sheet(path: String) -> void:
	if _missing_sheet_logged.has(path):
		return
	_missing_sheet_logged[path] = true
	print("[fallback_art] missing sheet: %s" % path)
