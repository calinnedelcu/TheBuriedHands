shader_type spatial;
// Hides one surface of a mesh (e.g. the baked flame of a jam sconce whose
// fire is now a live WallLamp that can be put out).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void vertex() {
	// Collapse the surface so nothing is rasterised at all.
	POSITION = vec4(0.0, 0.0, 2.0, 1.0);
}

void fragment() {
	discard;
}
