shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.5, 0.9, 0.8, 1.0);
uniform float unlocked = 0.0;
void fragment() {
	vec3 color = mix(tint.rgb, vec3(0.76, 0.92, 0.53), unlocked);
	float phase = UV.y * 65.0 - TIME * 1.4;
	float scan = pow(0.5 + 0.5 * sin(phase), 4.0) * (1.0 - smoothstep(0.6, 3.0, fwidth(phase)));
	float edge = pow(abs(UV.x - 0.5) * 2.0, 10.0);
	ALBEDO = color;
	ALPHA = (0.05 + scan * 0.1 + edge * 0.34) * (1.0 - unlocked * 0.4);
}
