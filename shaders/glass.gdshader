shader_type spatial;
// Thin glass: nearly clear where it faces the camera, bright along its silhouette,
// so a dome stays readable from any angle and over any background.
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 tint : source_color = vec4(0.82, 0.96, 0.92, 1.0);
uniform float body_alpha = 0.12;
uniform float rim_alpha = 0.9;
uniform float rim_power = 2.4;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = tint.rgb * rim * 0.6;
	ALPHA = mix(body_alpha, rim_alpha, rim);
}
