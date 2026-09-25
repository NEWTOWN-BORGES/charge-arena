shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 tint : source_color = vec4(0.67, 0.40, 1.0, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float aa = max(fwidth(radius) * 1.2, 0.008);
	float envelope = smoothstep(0.0, 0.13, age) * (1.0 - smoothstep(0.70, 1.0, age));
	float horizon = 0.49 + sin(age * 5.0) * 0.045;
	float ring = 1.0 - smoothstep(0.014, 0.014 + aa, abs(radius - horizon));
	float spiral = sin(angle * 3.0 + radius * 21.0 - age * 13.0 + seed);
	float stream = pow(max(0.0, spiral), 8.0) * smoothstep(horizon, horizon + 0.1, radius) * (1.0 - smoothstep(0.64, 0.92, radius));
	float dark_core = 1.0 - smoothstep(horizon - 0.07, horizon, radius);
	vec3 rim_color = mix(tint.rgb, vec3(0.88, 0.92, 1.0), ring * 0.72);
	ALBEDO = mix(rim_color, vec3(0.018, 0.012, 0.037), dark_core);
	ALPHA = clamp(dark_core * 0.78 + ring + stream * 0.68, 0.0, 1.0) * envelope * tint.a;
}
