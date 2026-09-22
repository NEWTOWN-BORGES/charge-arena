shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_pos;
uniform vec4 sector_tint : source_color = vec4(0.15, 0.27, 0.30, 1.0);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ring_line(float radius, float target, float width) {
	float aa = max(fwidth(radius), 0.008);
	return 1.0 - smoothstep(max(0.0, width - aa), width + aa, abs(radius - target));
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 jade = vec3(0.21, 0.57, 0.51);
	vec3 coral = vec3(0.66, 0.34, 0.29);
	vec3 color = mix(vec3(0.095, 0.18, 0.205), sector_tint.rgb, 1.0 - smoothstep(0.0, 11.0, length(p)));
	vec2 cells = abs(fract(p / 1.8 + 0.5) - 0.5);
	float cell_edge = max(cells.x, cells.y);
	float seams = smoothstep(0.492 - fwidth(cell_edge), 0.5, cell_edge);
	color *= 1.0 - seams * 0.14;
	// Broad satin grain stays below pixel frequency instead of sparkling in motion.
	float grain = sin(p.x * 9.0) * sin(p.y * 11.0);
	color += grain * 0.002;
	color += vec3(0.022, 0.028, 0.026) * exp(-0.10 * dot(p - vec2(-2.0, -2.0), p - vec2(-2.0, -2.0)));
	float r = length(p);
	float rings = ring_line(r, 2.12, 0.026) + ring_line(r, 2.26, 0.011);
	color = mix(color, vec3(0.49, 0.64, 0.61), min(rings, 1.0) * 0.6);
	vec3 team = p.y > 0.0 ? jade : coral;
	color += team * pow(smoothstep(3.2, 6.93, abs(p.y)), 2.0) * 0.21;
	// Inlaid court markings, antialiased analytically. No texture or extra draw call.
	float midline = 1.0 - smoothstep(0.012, 0.012 + fwidth(p.y), abs(p.y));
	float dash = step(0.5, fract(p.x * 1.5));
	color = mix(color, vec3(0.60, 0.67, 0.65), midline * dash * 0.18);
	float medallion = ring_line(r, 1.86, 0.007);
	color = mix(color, vec3(0.80, 0.65, 0.43), medallion * 0.40);
	ALBEDO = color;
}
