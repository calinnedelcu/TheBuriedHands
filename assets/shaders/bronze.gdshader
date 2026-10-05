shader_type spatial;
// Ancient bronze: warm metal where hands kept it bright, dark oxide and
// green verdigris elsewhere, in world-space patches so props need no UVs.
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 metal_color : source_color = vec3(0.56, 0.39, 0.19);
uniform vec3 oxide_color : source_color = vec3(0.17, 0.12, 0.08);
uniform vec3 verdigris : source_color = vec3(0.25, 0.37, 0.31);
uniform float patina : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float scale = 1.6;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 1e-4);
	return texture(noise, p.zy).r * w.x + texture(noise, p.xz).r * w.y + texture(noise, p.xy).r * w.z;
}

void fragment() {
	vec3 n = normalize(wn);
	float big = tri(wp * scale * 0.35, n);
	float fine = tri(wp * scale * 2.7 + 0.37, n);
	// Verdigris in patches, gathering on what faces up.
	float g = smoothstep(0.58 - patina * 0.25, 0.9 - patina * 0.25, big * 0.6 + fine * 0.4);
	g = clamp(g + max(n.y, 0.0) * 0.22 * patina, 0.0, 1.0);
	float ox = smoothstep(0.3, 0.7, fine);
	vec3 metal = mix(metal_color, oxide_color, ox * 0.55);
	ALBEDO = mix(metal, verdigris, g);
	METALLIC = mix(0.85, 0.0, g);
	ROUGHNESS = mix(0.36 + ox * 0.25, 0.85, g);
}
