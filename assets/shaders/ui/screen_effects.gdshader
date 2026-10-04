shader_type canvas_item;
// Full-screen status overlay: damage flash, low-health pulse, mercury
// poisoning (cold tint + edge warping) and the dimming of held breath.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float damage = 0.0;      // 0..1 flash
uniform float low_health = 0.0;  // 0..1
uniform float toxicity = 0.0;    // 0..1
uniform float breath_hold = 0.0; // 0..1
uniform float time_scale = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float dist = length(centered * vec2(1.6, 1.0));

	// Mercury: the edges of the world swim.
	float warp = toxicity * toxicity * 0.012;
	uv += vec2(sin(uv.y * 18.0 + TIME * 1.7), cos(uv.x * 14.0 + TIME * 1.3)) * warp * smoothstep(0.2, 0.9, dist);
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (toxicity > 0.3) {
		float split = (toxicity - 0.3) * 0.006;
		col.r = textureLod(screen_tex, uv + vec2(split, 0.0), 0.0).r;
		col.b = textureLod(screen_tex, uv - vec2(split, 0.0), 0.0).b;
	}

	float edge = smoothstep(0.35, 1.05, dist);
	// Cold silver-green bleed from the edges as poison builds.
	vec3 tox_col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(0.75, 0.9, 0.85), toxicity * 0.55);
	col = mix(col, tox_col, clamp(toxicity * (0.4 + edge), 0.0, 1.0));
	// Blood at the edges.
	float pulse = 0.75 + 0.25 * sin(TIME * 5.5);
	float red = clamp(damage * (0.35 + edge) + low_health * edge * pulse * 0.6, 0.0, 1.0);
	col = mix(col, col * vec3(0.55, 0.08, 0.06) + vec3(0.22, 0.0, 0.0), red * 0.8);
	// Held breath narrows the world.
	col *= 1.0 - breath_hold * edge * 0.55;
	COLOR = vec4(col, 1.0);
}
