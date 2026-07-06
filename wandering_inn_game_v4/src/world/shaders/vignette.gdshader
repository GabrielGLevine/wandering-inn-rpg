shader_type canvas_item;
// M-BEAUTY Task B3: fullrect vignette. world.gd creates ONE ColorRect (named
// "Vignette") as a child of the field Camera2D (not the World node directly)
// so its rect always tracks the camera's centered/clamped view regardless of
// map size (see world.gd's `_ready()` -- position is -VIEW_SIZE/2, size is
// VIEW_SIZE, both in the camera's local space, which is exactly the visible
// window since `_update_camera`/`enter_combat_camera` always center the
// Camera2D on the current view). `z_index` is set high on the ColorRect
// itself so it draws above world content (floor/decor/entities/ambience)
// regardless of sibling-order timing quirks (e.g. combat_board_root being
// added lazily, sometimes after the camera). atmosphere.gd owns setting the
// `strength` uniform from moods.json's per-map `vignette` field (0.0 today
// on every map = fully invisible, ship-neutral-first).
//
// COLOR is fully overridden in fragment() (the ColorRect's own `color`
// property is irrelevant) -- alpha ramps from 0 at the center out to
// `strength` at the corners; strength 0 means alpha is 0 everywhere, i.e.
// truly invisible, not just barely-visible.
//
// WASM-safe: length()/smoothstep(), both core GLES3/Compatibility ops.

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 1.4142135; // 0 at center, ~1.0 at the corners
	float vig = smoothstep(0.35, 0.9, dist) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, vig);
}
