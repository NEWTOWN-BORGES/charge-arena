shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint_color : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform float metal_amount : hint_range(0.0, 1.0) = 0.2;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.36;
uniform float light_amount : hint_range(0.0, 3.0) = 0.0;
varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	// Low-contrast brushed enamel. Derivative filtering keeps its grain still when
	// the same model shrinks from a gallery portrait to a few pixels in the arena.
	float footprint = length(fwidth(model_position)) * 140.0;
	float grain = sin(model_position.y * 185.0 + sin(model_position.x * 91.0) * 0.7);
	grain *= 1.0 - smoothstep(0.35, 1.2, footprint);
	ALBEDO = paint_color.rgb * (1.0 + grain * 0.022);
	METALLIC = metal_amount;
	ROUGHNESS = surface_roughness + grain * 0.025;
	SPECULAR = 0.56;
	CLEARCOAT = 0.38;
	CLEARCOAT_ROUGHNESS = 0.28;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = paint_color.rgb * (light_amount + edge * 0.075);
}
