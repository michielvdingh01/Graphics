shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, specular_disabled;

// Dust or smoke: a handful of soft balls that leave along the +Y of the
// burst, slow down in the air, swell, drift and thin out from the edges. It
// is lit like everything else, so it is dark in a dark corner and lights up
// in a beam of sunlight.
#include "puff.gdshaderinc"
