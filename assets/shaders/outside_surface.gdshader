shader_type spatial;
// Ground and rocks outside the drain's mouth. World-space triplanar detail
// like the tomb's surfaces, grass growing over whatever faces the sky, and
// the valley's bright haze instead of the tomb's dark fog.
render_mode diffuse_burley, specular_schlick_ggx, fog_disabled;

uniform vec3 base_color : source_color = vec3(0.42, 0.38, 0.33);
uniform vec3 grass_color : source_color = vec3(0.16, 0.2, 0.07);
// How much of the upward-facing surface is grown over.
uniform float grass_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float tex_scale = 0.3;
uniform float albedo_mean = 0.45;
uniform vec3 haze_color : source_color = vec3(0.95, 0.87, 0.74);
uniform float haze_distance = 90.0;

varying vec3 wp;
varying vec3 wn;
varying float haze;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	haze = clamp(length(wp - CAMERA_POSITION_WORLD) / haze_distance, 0.0, 1.0);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 1e-4);
	vec3 p = wp * tex_scale;
	vec3 a = texture(detail_albedo, p.zy).rgb * w.x + texture(detail_albedo, p.xz).rgb * w.y + texture(detail_albedo, p.xy).rgb * w.z;
	float lum = dot(a, vec3(0.299, 0.587, 0.114)) / albedo_mean;
	float patches = texture(noise, wp.xz * 0.06).r;
	float g = grass_amount * smoothstep(0.5, 0.85, n.y) * smoothstep(0.3, 0.6, patches + grass_amount * 0.35);
	vec3 c = mix(base_color, grass_color, g) * mix(1.0, lum, 0.8);
	ALBEDO = mix(c, haze_color, haze * haze * 0.6);
	NORMAL_MAP = texture(detail_normal, p.zy).rgb * w.x + texture(detail_normal, p.xz).rgb * w.y + texture(detail_normal, p.xy).rgb * w.z;
	ROUGHNESS = 0.93;
}
