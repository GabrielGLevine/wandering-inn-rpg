shader_type canvas_item;

uniform vec4 ground_base : source_color = vec4(0.37, 0.26, 0.17, 1.0);
uniform float ground_detail : hint_range(0.0, 1.0) = 1.0;
varying vec4 layer_tint;

void vertex() {
	layer_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(ground_base.rgb, tex.rgb, ground_detail), tex.a) * layer_tint;
}
