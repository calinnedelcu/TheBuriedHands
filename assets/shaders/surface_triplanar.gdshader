shader_type spatial;
// World-space triplanar detail for the level's flat-coloured surfaces. The
// original colour stays the base; a scanned surface (stone, earth, wood) adds
// grain, normal detail and roughness variation on top, and a low-frequency
// pass of the same texture breaks up tiling. No UVs needed, so it works on
// the jam meshes as they are.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/surface_triplanar.gdshaderinc"
