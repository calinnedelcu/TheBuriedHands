shader_type spatial;
// First-person hands/items: drawn with their depth pulled toward the near
// plane so they never clip into walls, while still sorting against
// themselves and receiving the scene's lights.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = true;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float depth_squash : hint_range(0.0, 0.99) = 0.9;
// Held things never go fully black: a touch of self-light keeps them readable.
uniform float fill_light : hint_range(0.0, 0.5) = 0.07;
uniform float max_metallic : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// Reversed-Z: w is the near plane, so lerping toward it brings the mesh forward.
	POSITION.z = mix(POSITION.z, POSITION.w, depth_squash);
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	ALBEDO = base.rgb;
	ROUGHNESS = max(roughness, 0.35);
	METALLIC = min(metallic, max_metallic);
	EMISSION = base.rgb * fill_light;
}
