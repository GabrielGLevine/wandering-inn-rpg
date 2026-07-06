shader_type canvas_item;
// M-BEAUTY Task B3: subtle vertex wobble applied to decor/scatter sprites
// tagged `sway: true` in data/skeleton_scene.json (trees/bushes/grass/
// flowers). world.gd assigns ONE SHARED ShaderMaterial instance (created
// once, not per-sprite) to every swaying sprite -- per-instance phase
// variance comes from MODEL_MATRIX (each sprite's own world position, a
// canvas_item vertex-shader built-in) rather than a per-instance uniform, so
// a single material can drive many independently-phased sprites with zero
// extra CPU bookkeeping. UV.y scales the wobble to 0 at the sprite's bottom
// (UV.y == 1, the anchored "root") and full amplitude at the top (UV.y == 0,
// the "tip") -- classic grass/foliage sway, not a rigid side-to-side shift.
// WASM-safe: sin() + a 4x4 matrix read, both core GLES3/Compatibility ops.

uniform float amplitude : hint_range(0.0, 4.0) = 0.6; // SUBTLE default per plan B3
uniform float speed : hint_range(0.0, 5.0) = 1.2;

void vertex() {
	float phase_offset = MODEL_MATRIX[3].x * 0.3 + MODEL_MATRIX[3].y * 0.17;
	float phase = TIME * speed + phase_offset;
	VERTEX.x += sin(phase) * amplitude * (1.0 - UV.y);
}
