shader_type spatial;
// The morning outside the drain's mouth, painted on a box around the exit.
// Everything is a function of the view direction only, so the box reads as
// an endless sky: a low sun, thin clouds catching it, and three ranges of
// hills fading into the valley mist below Mount Li.
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled, shadows_disabled;

uniform vec3 sun_dir = vec3(0.1685, 0.2419, 0.9556);
uniform vec3 zenith_color : source_color = vec3(0.27, 0.44, 0.75);
uniform vec3 horizon_color : source_color = vec3(0.98, 0.82, 0.6);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 far_hills : source_color = vec3(0.36, 0.42, 0.56);
uniform vec3 mid_hills : source_color = vec3(0.19, 0.25, 0.32);
uniform vec3 near_hills : source_color = vec3(0.08, 0.11, 0.09);
uniform vec3 mist_color : source_color = vec3(0.95, 0.86, 0.72);
uniform float brightness = 1.6;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Smooth 1D fractal noise read along a row of the noise texture.
float fbm1(float x, float row, int octaves) {
	float h = 0.0;
	float amp = 0.5;
	float total = 0.0;
	for (int i = 0; i < octaves; i++) {
		h += amp * texture(noise, vec2(x, row + float(i) * 0.137)).r;
		total += amp;
		x *= 2.03;
		amp *= 0.45;
	}
	return h / total;
}

float fbm2(vec2 p) {
	float h = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		h += amp * texture(noise, p).r;
		p = p * 2.07 + vec2(0.31, 0.17);
		amp *= 0.5;
	}
	return h / 0.94;
}

// Lays one range of hills over `col`: darker crest, mist pooling below it.
vec3 hills(vec3 col, float elev, float top, vec3 tint, float mist, float haze) {
	float edge = fwidth(elev) * 1.5 + 0.0004;
	float inside = smoothstep(top + edge, top - edge, elev);
	float depth = clamp((top - elev) / 0.16, 0.0, 1.0);
	vec3 c = mix(tint, horizon_color, haze);
	c = mix(c, mist_color, depth * depth * mist);
	return mix(col, c, inside);
}

void fragment() {
	vec3 dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 sd = normalize(sun_dir);
	float elev = asin(clamp(dir.y, -1.0, 1.0));
	float az = atan(dir.x, dir.z);
	float sun = max(dot(dir, sd), 0.0);

	// Sky: warm haze at the horizon, clear blue overhead, the sun's glow.
	float t = clamp(elev / 0.75, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(t, 0.6));
	col += sun_color * (pow(sun, 6.0) * 0.55 + pow(sun, 48.0) * 1.2 + pow(sun, 600.0) * 4.0);

	// Clouds on a far plane, thin and drifting, lit from the sun's side.
	if (dir.y > 0.0) {
		vec2 cp = dir.xz / (dir.y + 0.06) * 0.045 + vec2(TIME * 0.0015, 0.0);
		float c = fbm2(cp);
		c = smoothstep(0.52, 0.78, c) * smoothstep(0.0, 0.1, dir.y);
		vec3 lit = mix(vec3(0.98, 0.9, 0.82), sun_color * 1.5, pow(sun, 3.0));
		col = mix(col, lit, c * 0.6);
	}

	// Three ranges of misty mountains (as in the landscape scrolls of the
	// time), the farthest palest; haze thickest toward the sun.
	float glare = pow(sun, 4.0);
	float far_top = 0.0 + pow(smoothstep(0.28, 0.72, fbm1(az * 0.5 + 0.3, 0.11, 3)), 1.3) * 0.16;
	float mid_top = -0.012 + pow(smoothstep(0.28, 0.72, fbm1(az * 0.85 + 2.7, 0.43, 3)), 1.3) * 0.11;
	float near_top = -0.05 + pow(smoothstep(0.28, 0.72, fbm1(az * 1.3 + 5.1, 0.71, 3)), 1.2) * 0.085;
	float low_top = -0.105 + pow(smoothstep(0.28, 0.72, fbm1(az * 2.0 + 8.3, 0.29, 3)), 1.1) * 0.06;
	// Forest along the lower crests.
	near_top += (texture(noise, vec2(az * 26.0, 0.93)).r - 0.5) * 0.004;
	low_top += (texture(noise, vec2(az * 34.0, 0.81)).r - 0.5) * 0.005;
	col = hills(col, elev, far_top, far_hills, 0.7, 0.22 + glare * 0.35);
	col = hills(col, elev, mid_top, mid_hills, 0.8, 0.12 + glare * 0.4);
	col = hills(col, elev, near_top, near_hills, 0.8, 0.05 + glare * 0.3);
	col = hills(col, elev, low_top, near_hills * 0.8, 0.7, 0.02 + glare * 0.25);
	// The valley floor far below is lost in bright mist, lying in banks.
	float banks = 0.86 + 0.14 * fbm1(az * 2.5 + elev * 14.0, 0.57, 3);
	col = mix(col, mist_color * 0.82 * banks, smoothstep(-0.12, -0.24, elev) * 0.8);

	ALBEDO = col * brightness;
}
