shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.42, 0.12, 0.2);
uniform vec2 center = vec2(0.5, 0.56);
uniform vec2 radius = vec2(0.34, 0.64);
uniform float softness : hint_range(0.25, 4.0) = 1.8;

void fragment() {
	vec2 d = (UV - center) / radius;
	float core = max(0.0, 1.0 - dot(d, d));
	float alpha = pow(core, softness);
	COLOR = vec4(glow_color.rgb * COLOR.rgb, glow_color.a * alpha * COLOR.a);
}
