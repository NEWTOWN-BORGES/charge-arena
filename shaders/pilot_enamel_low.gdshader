shader_type spatial;
render_mode unshaded;

// Leve keeps the same paint and energy accents without per-light/PBR work.
uniform vec4 paint_color : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform float light_amount : hint_range(0.0, 3.0) = 0.0;

void fragment() {
	ALBEDO = paint_color.rgb;
	EMISSION = paint_color.rgb * light_amount;
}
