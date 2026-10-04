shader_type spatial;
// World-space triplanar detail for the level's flat-coloured surfaces. The
// original colour stays the base; a scanned surface (stone, earth, wood) adds
// grain, normal detail and roughness variation on top, and a low-frequency
// pass of the same texture breaks up tiling. No UVs needed, so it works on
// the jam meshes as they are.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Repeats per metre.
uniform float tex_scale = 0.25;
// Average luminance of detail_albedo, so the texture modulates around 1.0.
uniform float albedo_mean = 0.45;
uniform float detail_strength : hint_range(0.0, 1.5) = 0.85;
// 0 = only the texture's light/dark pattern, 1 = its full colour.
uniform float detail_saturation : hint_range(0.0, 1.0) = 0.3;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.8;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.9;
uniform float roughness_detail : hint_range(0.0, 1.0) = 0.5;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float macro_scale = 0.045;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.3;
uniform float blend_sharpness = 6.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	return w / max(w.x + w.y + w.z, 1e-4);
}

void fragment() {
	vec3 n = normalize(v_world_nrm);
	vec3 w = tri_weights(n);
	vec3 s = sign(n);
	s = vec3(s.x == 0.0 ? 1.0 : s.x, s.y == 0.0 ? 1.0 : s.y, s.z == 0.0 ? 1.0 : s.z);
	vec3 p = v_world_pos * tex_scale;
	// Image-up is world-up on walls and world +Z on floors, so the green
	// channel of the (OpenGL-style) normal map points the right way.
	vec2 uv_x = vec2(p.z * s.x, -p.y);
	vec2 uv_y = vec2(p.x * s.y, -p.z);
	vec2 uv_z = vec2(-p.x * s.z, -p.y);

	vec3 a = texture(detail_albedo, uv_x).rgb * w.x + texture(detail_albedo, uv_y).rgb * w.y + texture(detail_albedo, uv_z).rgb * w.z;
	float lum = dot(a, vec3(0.299, 0.587, 0.114));
	vec3 d = mix(vec3(lum), a, detail_saturation) / max(albedo_mean, 0.05);

	vec3 pm = v_world_pos * macro_scale;
	float macro = dot(texture(detail_albedo, pm.zy).rgb, vec3(0.333)) * w.x
		+ dot(texture(detail_albedo, pm.xz + vec2(0.37, 0.11)).rgb, vec3(0.333)) * w.y
		+ dot(texture(detail_albedo, pm.xy + vec2(0.71, 0.53)).rgb, vec3(0.333)) * w.z;
	macro /= max(albedo_mean, 0.05);

	vec3 col = base_color.rgb * mix(vec3(1.0), d, detail_strength) * mix(1.0, macro, macro_strength);
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));

	float r = texture(detail_roughness, uv_x).r * w.x + texture(detail_roughness, uv_y).r * w.y + texture(detail_roughness, uv_z).r * w.z;
	ROUGHNESS = clamp(mix(roughness_base, r, roughness_detail), 0.04, 1.0);
	METALLIC = metallic_value;

	// Whiteout-blended triplanar normals, built in world space.
	vec3 tx = texture(detail_normal, uv_x).rgb * 2.0 - 1.0;
	vec3 ty = texture(detail_normal, uv_y).rgb * 2.0 - 1.0;
	vec3 tz = texture(detail_normal, uv_z).rgb * 2.0 - 1.0;
	tx.xy *= normal_strength;
	ty.xy *= normal_strength;
	tz.xy *= normal_strength;
	tx.x *= s.x;
	ty.x *= s.y;
	tz.x *= -s.z;
	vec3 nx = vec3(n.x * abs(tx.z), tx.y + n.y, tx.x + n.z);
	vec3 ny = vec3(ty.x + n.x, n.y * abs(ty.z), ty.y + n.z);
	vec3 nz = vec3(tz.x + n.x, tz.y + n.y, n.z * abs(tz.z));
	vec3 wn = normalize(nx * w.x + ny * w.y + nz * w.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
