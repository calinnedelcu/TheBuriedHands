shader_type spatial;
// Grass blades (and hanging roots) outside the drain: a tapered strip per
// instance, bent by a slow wind, darker at the root, lit through from behind
// by the low sun. UV.y runs from 0 at the root to 1 at the tip.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled, fog_disabled;

uniform vec3 root_color : source_color = vec3(0.07, 0.09, 0.03);
uniform vec3 tip_color : source_color = vec3(0.42, 0.47, 0.19);
uniform float wind_strength = 0.35;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform vec3 translucency : source_color = vec3(0.42, 0.46, 0.15);
// Aerial haze, done here since the level's fog is the tomb's, not the valley's.
uniform vec3 haze_color : source_color = vec3(0.95, 0.87, 0.74);
uniform float haze_distance = 90.0;

varying float tip;
varying vec3 tint;
varying float haze;

void vertex() {
	tip = UV.y;
	tint = COLOR.rgb;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float gust = sin(TIME * 0.6 + root.x * 0.15 + root.z * 0.1) * 0.5 + 0.5;
	float sway = sin(TIME * 1.9 + root.x * 0.7 + root.z * 0.45) * 0.6 + sin(TIME * 3.3 + root.z * 1.3) * 0.25;
	vec3 bend = vec3(wind_dir.x, 0.0, wind_dir.y) * (sway + gust * 0.8) * wind_strength * tip * tip;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	VERTEX += to_local * bend;
	// Light the blades like the ground they grow from.
	NORMAL = normalize(to_local * vec3(0.0, 1.0, 0.0));
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	haze = clamp(length(wp - CAMERA_POSITION_WORLD) / haze_distance, 0.0, 1.0);
}

void fragment() {
	vec3 c = mix(root_color, tip_color, smoothstep(0.0, 1.0, tip)) * tint * 1.25;
	ALBEDO = mix(c, haze_color, haze * haze * 0.6);
	ROUGHNESS = 0.8;
	BACKLIGHT = translucency * tip;
}
