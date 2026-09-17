shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = UV;
	vec3 color = mix(vec3(0.025, 0.045, 0.075), vec3(0.07, 0.145, 0.16), 1.0 - p.y);
	color += vec3(0.04, 0.07, 0.075) * exp(-6.0 * length((p - vec2(0.53, 0.48)) * vec2(1.0, 0.7)));
	color += vec3(0.07, 0.025, 0.016) * exp(-5.0 * length(p - vec2(0.8, 0.1)));
	float vignette = smoothstep(0.25, 0.83, length((p - 0.5) * vec2(1.0, 1.1)));
	color *= 1.0 - vignette * 0.48;
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	color += (grain - 0.5) * 0.008;
	COLOR = vec4(color, 1.0);
}
