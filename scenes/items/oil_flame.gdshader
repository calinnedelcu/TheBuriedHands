shader_type spatial;

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 outer_color : source_color = vec4(1.0, 0.28, 0.045, 0.72);
uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.28, 0.92);
uniform vec4 tip_color : source_color = vec4(1.0, 0.54, 0.08, 0.52);
uniform float emission_strength : hint_range(0.5, 8.0) = 3.4;
uniform float alpha_scale : hint_range(0.1, 1.0) = 0.78;

void fragment() {
	float y = clamp(UV.y, 0.0, 1.0);
	float center = 1.0 - abs(UV.x - 0.5) * 2.0;
	center = smoothstep(0.0, 0.82, center);

	vec3 flame_col = mix(outer_color.rgb, tip_color.rgb, smoothstep(0.45, 1.0, y));
	flame_col = mix(flame_col, core_color.rgb, pow(center, 2.15) * (1.0 - smoothstep(0.62, 1.0, y) * 0.55));

	float base_fade = smoothstep(0.0, 0.12, y);
	float tip_fade = 1.0 - smoothstep(0.88, 1.0, y) * 0.42;
	float alpha = alpha_scale * (0.34 + center * 0.66) * base_fade * tip_fade;

	ALBEDO = flame_col;
	EMISSION = flame_col * emission_strength;
	ALPHA = alpha;
}
