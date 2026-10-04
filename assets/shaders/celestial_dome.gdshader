shader_type spatial;
// The dome over the Mercury Hall. Sima Qian: "above, the heavens; below, the
// land". Dark lacquer set with pearls for stars: a dense field of faint ones,
// a few bright ones that catch the light, all twinkling slowly. Stars are
// placed in 3D cells around `centre`, so there is no stretching at the top.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 centre = vec3(0.0);
uniform vec4 lacquer : source_color = vec4(0.018, 0.02, 0.04, 1.0);
uniform vec4 lacquer_band : source_color = vec4(0.05, 0.03, 0.02, 1.0);
uniform vec4 pearl : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float density = 46.0;
uniform float star_size = 0.032;
uniform float bright_fraction = 0.06;
uniform float emission_energy = 3.2;
uniform float twinkle_speed = 0.6;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float star_layer(vec3 dir, float dens, float size, out float bright) {
	vec3 p = dir * dens;
	vec3 cell = floor(p);
	float best = 0.0;
	bright = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 h = hash3(c);
				vec3 star = c + h;
				// Keep stars on the shell: project the cell point onto the sphere of radius dens.
				star = normalize(star) * dens;
				float d = length(p - star);
				float is_bright = step(1.0 - bright_fraction, fract(h.x * 13.7 + h.z * 7.1));
				float s = size * mix(0.55, 1.9, is_bright) * mix(0.7, 1.2, h.y);
				float v = 1.0 - smoothstep(0.0, s, d);
				float tw = 0.65 + 0.35 * sin(TIME * twinkle_speed * (0.5 + h.z * 2.0) + h.x * 40.0);
				v *= tw * mix(0.35, 1.0, is_bright);
				if (v > best) {
					best = v;
					bright = is_bright;
				}
			}
		}
	}
	return best;
}

void fragment() {
	vec3 dir = normalize(v_world - centre);
	float bright;
	float stars = star_layer(dir, density, star_size, bright);
	// Faint lacquer bands around the rim, like painted cloud scrolls.
	float elev = dir.y;
	float band = smoothstep(0.08, 0.0, abs(elev - 0.18)) + smoothstep(0.05, 0.0, abs(elev - 0.42)) * 0.6;
	vec3 base = mix(lacquer.rgb, lacquer_band.rgb, clamp(band, 0.0, 1.0));
	ALBEDO = mix(base, pearl.rgb, stars);
	ROUGHNESS = mix(0.35, 0.15, stars);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = pearl.rgb * stars * emission_energy * mix(0.6, 1.6, bright);
}
