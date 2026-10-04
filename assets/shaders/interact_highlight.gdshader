shader_type spatial;
// Overlay pass for the usable the player is looking at: a soft warm rim
// that breathes slowly, so it reads as "lamplight catching the edge".
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 rim_color : source_color = vec3(1.0, 0.72, 0.38);
uniform float rim_power = 2.6;
uniform float strength = 0.55;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.4);
	ALBEDO = rim_color * rim * strength * pulse;
}
