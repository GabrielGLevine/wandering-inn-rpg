extends SceneTree
## Issue #411 (dual-grid pass): the shoreline vertex mapping and its sheet.
##
## Three tiers:
##   1. Pure mapping: every 4-bit water-corner combo maps to a coord, total.
##   2. Behavior on real shapes: island ring, 1-wide channel (the sewers
##      case that killed the per-cell approach), cross-segment union.
##   3. SHEET PIN (review I7): the generated sheet itself proves polarity --
##      for every mapping entry, the tile's water corners are majority
##      opaque and its land corners majority transparent. A wrong-way-round
##      table or a regenerated-and-flipped sheet fails HERE, not on screen.

var _failed := false


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + label)


func _init() -> void:
	_mapping_total()
	_island_ring()
	_one_wide_channel()
	_cross_segment_union()
	_sheet_pin()
	if _failed:
		push_error("ERROR: FAIL water shoreline")
	else:
		print("PASS: water shoreline dual-grid mapping + sheet pin")
	quit(1 if _failed else 0)


func _mapping_total() -> void:
	# Every paintable combo (1..14) present; 15 present for optional interior.
	for bits in range(1, 16):
		_check(WITileBoardBuilder.SHORELINE_WANG_COORDS.has(bits),
			"mapping missing bits=%d" % bits)
	# Corruption guard: spot-pin four single-corner combos to their coords.
	# (Derived from the PixelLab Wang metadata; see sheet pin for the proof
	# that these orientations are REAL, not copied wrong twice.)
	_check(WITileBoardBuilder.SHORELINE_WANG_COORDS[1] == Vector2i(3, 3), "bits=1 (water NW only)")
	_check(WITileBoardBuilder.SHORELINE_WANG_COORDS[2] == Vector2i(0, 2), "bits=2 (water NE only)")
	_check(WITileBoardBuilder.SHORELINE_WANG_COORDS[4] == Vector2i(0, 0), "bits=4 (water SW only)")
	_check(WITileBoardBuilder.SHORELINE_WANG_COORDS[8] == Vector2i(1, 3), "bits=8 (water SE only)")


func _island_ring() -> void:
	# 1-cell island of LAND inside water: the 4 vertices around the land cell
	# carry exactly-one-land combos -- every one must paint (no fallback).
	var water := {}
	for x in range(0, 3):
		for y in range(0, 3):
			if not (x == 1 and y == 1):
				water[Vector2i(x, y)] = true
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		var bits := WITileBoardBuilder.vertex_water_bits(corner, water)
		_check(bits != 0 and bits != 15, "island vertex %s paints (bits=%d)" % [corner, bits])
		_check(WITileBoardBuilder.SHORELINE_WANG_COORDS.has(bits), "island vertex %s mapped" % corner)


func _one_wide_channel() -> void:
	# The sewers shape: a 1-tall horizontal run. Its vertex rows above and
	# below must BOTH paint bank tiles -- the per-cell picker rendered this
	# as a complete no-op (review I1).
	var water := {}
	for x in range(0, 5):
		water[Vector2i(x, 0)] = true
	var top := WITileBoardBuilder.vertex_water_bits(Vector2i(2, 0), water)   # cells above are land
	var bottom := WITileBoardBuilder.vertex_water_bits(Vector2i(2, 1), water)
	_check(top == (4 | 8), "channel top vertex sees water below only (got %d)" % top)
	_check(bottom == (1 | 2), "channel bottom vertex sees water above only (got %d)" % bottom)
	_check(WITileBoardBuilder.SHORELINE_WANG_COORDS[top] == Vector2i(3, 0), "channel top tile")
	_check(WITileBoardBuilder.SHORELINE_WANG_COORDS[bottom] == Vector2i(1, 2), "channel bottom tile")


func _cross_segment_union() -> void:
	# Two abutting segments are ONE body of water: the shared boundary's
	# vertices must read all-water (15) and therefore not paint.
	var segments := [
		{"water": true, "from": [0, 0], "to": [2, 0], "cap": [1, 5]},
		{"water": true, "from": [0, 1], "to": [2, 1], "cap": [1, 5]},
	]
	var water := WITileBoardBuilder.water_segment_cell_set(segments)
	var mid := WITileBoardBuilder.vertex_water_bits(Vector2i(1, 1), water)
	_check(mid == 15, "abutting segments union at the seam (got %d)" % mid)


func _sheet_pin() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(WITileBoardBuilder.SHORELINE_SHEET))
	_check(img != null, "shoreline sheet loads")
	if img == null:
		return
	_check(img.get_width() == 64 and img.get_height() == 64, "sheet is 64x64 (4x4 Wang-16)")
	for bits: int in WITileBoardBuilder.SHORELINE_WANG_COORDS:
		if bits == 15:
			continue  # interior tile: all-water, no polarity to prove
		var coord: Vector2i = WITileBoardBuilder.SHORELINE_WANG_COORDS[bits]
		# Sample each corner's OUTERMOST 4x4 block: the Wang transition curve
		# (size 0.25) legitimately wanders past quadrant midlines, but it never
		# reaches the tile's far corners -- so water far-corners must be near
		# fully opaque and land far-corners near fully transparent. This is
		# the boundary-shape-agnostic polarity proof.
		for corner_idx in range(4):
			var corner_bit: int = [1, 2, 4, 8][corner_idx]
			var qx: int = [0, 12, 0, 12][corner_idx]
			var qy: int = [0, 0, 12, 12][corner_idx]
			var opaque := 0
			for py in range(4):
				for px in range(4):
					if img.get_pixel(coord.x * 16 + qx + px, coord.y * 16 + qy + py).a > 0.1:
						opaque += 1
			if bits & corner_bit:
				_check(opaque >= 13, "bits=%d %s water far-corner %d painted (%d/16)" % [bits, coord, corner_bit, opaque])
			else:
				_check(opaque <= 3, "bits=%d %s land far-corner %d transparent (%d/16)" % [bits, coord, corner_bit, opaque])
