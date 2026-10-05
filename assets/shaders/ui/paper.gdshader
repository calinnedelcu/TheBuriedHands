shader_type canvas_item;
// Old paper for the epilogue: warm, faintly fibrous and mottled, browner
// toward the edges. Alpha comes from the node (it fades in over the white).

uniform vec3 paper : source_color = vec3(0.925, 0.88, 0.79);
uniform vec3 edge : source_color = vec3(0.7, 0.58, 0.43);
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float aspect = 1.7778;

void fragment() {
	vec2 uv = UV * vec2(aspect, 1.0);
	float broad = texture(noise, uv * 0.55).r;
	float fibres = texture(noise, uv * vec2(10.0, 1.3) + vec2(0.31, 0.72)).r;
	float grain = texture(noise, uv * 9.0 + vec2(0.71, 0.13)).r;
	vec3 c = paper * (0.96 + 0.06 * broad) * (0.98 + 0.035 * fibres) * (0.985 + 0.025 * grain);
	vec2 d = (UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(0.3, 0.8, length(d) + (broad - 0.5) * 0.1);
	c = mix(c, edge, v * 0.55);
	COLOR = vec4(c, COLOR.a);
}
