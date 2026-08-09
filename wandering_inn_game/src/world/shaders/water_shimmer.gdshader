shader_type canvas_item;
// M-BEAUTY Task B3: uv wobble for the floodplains pond water tiles.
//
// Approach note (per plan B3, documented as required): the pond is painted
// by data/skeleton_scene.json's floodplains `walls.segments` -- five
// cap-only segments on the `free_pack/Water_tiles.png` sheet (see
// tile_board_builder.gd's `build_walls`, off-limits to this task's file
// list). `build_walls` paints those segments into its OWN internal
// TileMapLayer(s) and returns only the covered-cell set, not the layer
// nodes themselves, so there is no node this task can reach in to attach a
// material to the ACTUAL painted water tiles without editing
// tile_board_builder.gd. Chosen: an OVERLAY TileMapLayer -- world.gd's
// `_build_water_shimmer()` re-derives the same water segments (matched by
// `sheet == Water_tiles.png`) via the same public `WIGame.segment_cells`/
// `WITileBoardBuilder.make_tile_layer` calls tile_board_builder.gd already
// exposes, paints the identical cap tile at the identical cells into a NEW
// TileMapLayer added directly above the base one (later sibling of
// `_field_root` => drawn on top, opaque, fully covering the flat tile below
// it), and applies this shader to that overlay layer only. This keeps
// tile_board_builder.gd (a file shared with combat_screen.gd, out of this
// task's scope) untouched while still visually replacing the pond's look
// with the shimmering version -- a per-tile shader on the original layer
// would have required a return-value change there.
//
// WASM-safe: sin/cos + one texture() sample, all core GLES3/Compatibility ops.

uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float amplitude : hint_range(0.0, 0.05) = 0.02;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * 3.0 + TIME * speed) * amplitude;
	uv.y += cos(uv.x * 3.0 + TIME * speed * 0.8) * amplitude;
	// PILOT FIX (B4): multiply by the incoming COLOR — it carries the
	// vertex color/modulate chain (incl. WIAtmosphere's CanvasModulate).
	// The bare texture() assignment made the pond IGNORE the mood grade,
	// caught on the first graded pilot frame.
	COLOR = texture(TEXTURE, uv) * COLOR;
}
