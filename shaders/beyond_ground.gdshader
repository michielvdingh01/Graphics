shader_type spatial;

// The ground beyond the land, where nobody comes: see
// tools/levels/dunes/vista.gd. What lies there is said by the colour of each
// corner, sand, grey dune, the floor of a wood, and the grain of sand is laid
// over it for as far as a grain can be told. No more than that: it is seen
// from a hundred metres off at the nearest, through the haze.
uniform sampler2D grain_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// How many times to the metre the grain repeats, and how light it is on
// average, so that laying it on leaves the colour what it was.
uniform float grain_scale = 0.3;
uniform vec3 grain_mean : source_color = vec3(0.58, 0.5, 0.39);
// From how far off the grain is still seen, and where it is gone.
uniform float grain_from = 60.0;
uniform float grain_to = 260.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;

varying vec3 lies;

void vertex() {
	lies = COLOR.rgb;
}

void fragment() {
	vec3 grain = texture(grain_tex, UV * grain_scale).rgb / grain_mean;
	float near = 1.0 - smoothstep(grain_from, grain_to, -VERTEX.z);
	ALBEDO = lies * mix(vec3(1.0), grain, near);
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
}
