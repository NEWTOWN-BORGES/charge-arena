shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// A single two-triangle card: the shock front is drawn analytically, never a
// stack of transparent spheres. Narrow feathered edges hold up on phone screens.
uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float motif = 0.0;
uniform float seed = 0.0;

float band(float value, float center, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(value - center));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float aa = max(fwidth(radius) * 1.2, 0.008);
	float travel = 1.0 - pow(1.0 - age, 2.4);
	float front = mix(0.13, 0.91, travel);
	float fade = smoothstep(0.0, 0.06, age + 0.025) * pow(1.0 - age, 1.35);
	float edge = band(radius, front, mix(0.022, 0.008, age), aa);
	float tail = exp(-abs(radius - front + 0.05) * 24.0) * 0.19;
	float core = pow(max(0.0, 1.0 - radius * 2.0), 3.0) * pow(1.0 - age, 7.0);
	float detail = 0.0;
	if (motif > 0.5 && motif < 1.5) {
		// Molten starburst: a broken hot crown followed by receding embers.
		float lobes = sin(angle * 11.0 + seed) * sin(angle * 7.0 - seed);
		edge = band(radius, front + lobes * 0.055 * (1.0 - age), 0.022, aa);
		float rays = pow(max(0.0, sin(angle * 17.0 + seed)), 14.0);
		detail = rays * smoothstep(front * 0.32, front * 0.58, radius) * (1.0 - smoothstep(front * 0.82, front + 0.04, radius)) * 0.65;
		core *= 1.5;
	} else if (motif > 1.5 && motif < 2.5) {
		// Electrical spokes fracture into an angular ionisation ring.
		float jagged = abs(fract(angle * 3.82 + seed * 0.1) - 0.5);
		edge = band(radius, front + jagged * 0.085, 0.012, aa);
		float branch = pow(max(0.0, cos(angle * 15.0 + sin(radius * 31.0 + seed) * 0.6)), 26.0);
		detail = branch * (1.0 - smoothstep(front * 0.65, front, radius)) * smoothstep(0.11, 0.26, radius) * 0.72;
		fade *= 0.78 + 0.22 * sin(age * 46.0);
	} else if (motif > 2.5 && motif < 3.5) {
		// Six overlapping petals read as growth rather than a blast.
		float petals = 0.66 + 0.23 * cos(angle * 6.0 + seed + age * 0.7);
		detail = band(radius, front * petals, 0.019, aa) * 0.72;
		edge *= 0.44;
		core *= 0.3;
	} else if (motif > 4.5 && motif < 5.5) {
		// Beam ribbon: soft coloured sheath and a narrow white-hot core.
		float crossline = abs(p.x);
		float along = 1.0 - smoothstep(0.81, 1.0, abs(p.y));
		edge = exp(-crossline * 24.0) * along;
		tail = exp(-crossline * 6.0) * along * 0.28;
		float pulses = pow(max(0.0, cos(p.y * 33.0 - age * 24.0)), 8.0);
		detail = band(crossline, 0.32, 0.018, aa) * pulses * along * 0.5;
		core = 0.0;
	} else if (motif > 5.5) {
		// A lens-shaped glint, reserved for the very brief impact core.
		edge = exp(-abs(p.x) * 20.0 - abs(p.y) * 2.8) + exp(-abs(p.y) * 24.0 - abs(p.x) * 3.2);
		tail = exp(-radius * 6.0) * 0.2;
		detail = 0.0;
		core *= 0.55;
		fade = pow(1.0 - age, 2.8);
	}
	float mask = 1.0 - smoothstep(0.95, 1.0, radius);
	if (motif > 4.5 && motif < 5.5) mask = 1.0;
	float light = clamp(edge + tail + core + detail, 0.0, 1.0);
	ALBEDO = mix(tint.rgb, hot.rgb, clamp(edge * 0.68 + core, 0.0, 0.92));
	ALPHA = light * fade * mask * tint.a;
}
