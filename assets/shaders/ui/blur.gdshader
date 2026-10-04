shader_type canvas_item;
// Pause backdrop: blurred, darkened and slightly warmed copy of the game view.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 col = textureLod(screen_tex, SCREEN_UV, amount * 3.0).rgb;
	col = mix(col, col * vec3(0.55, 0.45, 0.38), amount * 0.75);
	float edge = smoothstep(0.3, 0.95, length((SCREEN_UV - 0.5) * vec2(1.5, 1.0)));
	col *= 1.0 - edge * 0.6 * amount;
	COLOR = vec4(col, 1.0);
}
