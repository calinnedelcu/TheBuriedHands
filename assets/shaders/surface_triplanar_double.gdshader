shader_type spatial;
// The triplanar surface shader drawn from both sides, for one-sided walls that
// are seen from behind (see surface_triplanar.gdshader).
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define DOUBLE_SIDED
#include "res://assets/shaders/surface_triplanar.gdshaderinc"
