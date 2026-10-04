shader_type spatial;
// Liquid mercury: a heavy mirror with slow, viscous ripples. Most of its look
// comes from reflecting the lamps around it (SSR + reflection probes), so it
// is nearly black where nothing is lit and blinding silver where a flame is.
render_mode cull_back, depth_draw_opaque;

uniform vec3 tint : source_color = vec3(0.78, 0.8, 0.84);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.06;
uniform float ripple_scale = 0.35;
uniform float ripple_speed = 0.25;
uniform float ripple_strength = 0.35;
uniform float flow_speed = 0.05;
uniform vec2 flow_dir = vec2(1.0, 0.3);
// What a mirror shows in a hazy hall: a cold sheen toward grazing angles, and
// small glints drifting with the flow, so the rivers read as metal even
// where no flame is reflected.
uniform vec3 sheen_color : source_color = vec3(0.55, 0.62, 0.68);
uniform float sheen_strength = 0.5;
uniform float glint_strength = 1.4;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float height(vec2 p) {
	float t = TIME * ripple_speed;
	vec2 q = p + normalize(flow_dir) * TIME * flow_speed;
	return noise(q * 1.0 + t) * 0.6 + noise(q * 2.3 - t * 1.3) * 0.3 + noise(q * 5.1 + t * 0.7) * 0.1;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz * ripple_scale;
	float e = 0.02;
	float h = height(p);
	float hx = height(p + vec2(e, 0.0)) - h;
	float hz = height(p + vec2(0.0, e)) - h;
	vec3 n_world = normalize(vec3(-hx * ripple_strength / e * 0.05, 1.0, -hz * ripple_strength / e * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ALBEDO = tint;
	METALLIC = 1.0;
	ROUGHNESS = roughness_base + h * 0.04;
	SPECULAR = 0.8;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec2 g = world.xz * 7.0 + normalize(flow_dir) * TIME * flow_speed * 14.0;
	float glint = smoothstep(0.93, 0.995, noise(g) * noise(g * 2.3 + 3.1) * 1.7);
	EMISSION = sheen_color * (0.03 + fresnel * sheen_strength) + vec3(0.9, 0.95, 1.0) * glint * glint_strength * (0.3 + fresnel);
}
