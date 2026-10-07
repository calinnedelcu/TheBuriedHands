shader_type spatial;
// The triplanar surface tinted by the instance colour: the level kit's stone
// blocks, flagstones and boards (multimeshes), each a shade lighter or darker
// than the next, the way dressed stone comes out of the quarry.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#define INSTANCE_TINT
#include "res://assets/shaders/surface_triplanar.gdshaderinc"
