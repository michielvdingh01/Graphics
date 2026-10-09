shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

// The fire and smoke of an explosion: the same balls as in puff.gdshader, but
// not lit, and able to burn. A cloud that fills half the picture costs too
// much when every pixel of every ball has to look up its lights and shadows:
// an explosion a second took a third off the frame rate that way. Whoever
// sets one off says how much light falls on it instead, see `shade`.
#define UNLIT
#include "puff.gdshaderinc"
