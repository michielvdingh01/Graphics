shader_type spatial;

// The ground beyond the land, where nobody comes: see
// tools/levels/dunes/vista.gd. What lies there, sand, grey dune, the floor of
// a wood or its crowns, is on two maps that are laid over it by where a spot
// lies: one of what is near the land and a coarser one of all of it. The
// grain of sand is laid over that for as far as a grain can be told. No more
// than that: it is seen from a hundred metres off at the nearest, through
// the haze.
uniform sampler2D look_near : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D look_far : source_color, filter_linear_mipmap, repeat_disable;
// Where each map lies: x and z of its corner, and one over its size.
uniform vec4 near_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 far_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform sampler2D grain_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// How many times to the metre the grain repeats, and how light it is on
// average, so that laying it on leaves the colour what it was.
uniform float grain_scale = 0.3;
uniform vec3 grain_mean : source_color = vec3(0.58, 0.5, 0.39);
// From how far off the grain is still seen, and where it is gone.
uniform float grain_from = 60.0;
uniform float grain_to = 260.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;

void fragment() {
	// UV is where the spot lies, x and z in metres.
	vec2 near_at = (UV - near_rect.xy) * near_rect.zw;
	vec2 far_at = (UV - far_rect.xy) * far_rect.zw;
	vec2 in_near = smoothstep(vec2(0.0), vec2(0.04), near_at) * smoothstep(vec2(0.0), vec2(0.04), 1.0 - near_at);
	vec3 look = mix(texture(look_far, far_at).rgb, texture(look_near, near_at).rgb, in_near.x * in_near.y);
	vec3 grain = texture(grain_tex, UV * grain_scale).rgb / grain_mean;
	float close = 1.0 - smoothstep(grain_from, grain_to, -VERTEX.z);
	ALBEDO = look * mix(vec3(1.0), grain, close);
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
}
