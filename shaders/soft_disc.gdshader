shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform float falloff = 1.8;
void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = tint.rgb;
	ALPHA = pow(max(0.0, 1.0 - d), falloff) * tint.a;
}
