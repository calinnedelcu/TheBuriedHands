shader_type canvas_item;
// Oil phial: shows the oil texture only below the current level, with a
// gently sloshing surface line.
uniform float level : hint_range(0.0, 1.0) = 1.0;
uniform float slosh = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float top_margin = 0.18;
uniform float bottom_margin = 0.08;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * tint;
	float usable = 1.0 - top_margin - bottom_margin;
	float surface = 1.0 - bottom_margin - level * usable;
	surface += sin(UV.x * 9.0 + TIME * 2.2) * 0.006 * (0.4 + slosh);
	float mask = smoothstep(surface - 0.004, surface + 0.004, UV.y);
	COLOR = vec4(c.rgb, c.a * mask);
}
