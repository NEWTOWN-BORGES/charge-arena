shader_type sky;
// Deep space for the press photographs: a dark gradient, two soft nebula clouds and a
// field of stars of different brightness. Only ever drawn once per photograph.
uniform vec3 nebula_a : source_color = vec3(0.42, 0.16, 0.52);
uniform vec3 nebula_b : source_color = vec3(0.08, 0.34, 0.46);
uniform float density = 0.986;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 base = mix(vec3(0.006, 0.01, 0.024), vec3(0.02, 0.035, 0.06), smoothstep(-0.4, 0.6, d.y));
	float cloud_a = sin(d.x * 3.1 + d.y * 2.3 + 0.7) * sin(d.z * 2.7 - d.y * 1.9);
	float cloud_b = sin(d.x * 1.7 - d.z * 2.9 + 1.9) * sin(d.y * 3.3 + d.x * 1.1);
	base += nebula_a * smoothstep(0.25, 1.0, cloud_a) * 0.55;
	base += nebula_b * smoothstep(0.3, 1.0, cloud_b) * 0.45;
	vec3 cell = floor(d * 260.0);
	float s = hash(cell);
	float star = step(density, s) * (0.35 + 0.65 * hash(cell + 3.1));
	float big = step(0.9985, hash(floor(d * 90.0) + 7.7)) * 1.4;
	COLOR = base + vec3(star + big) * vec3(0.95, 0.97, 1.0);
}
