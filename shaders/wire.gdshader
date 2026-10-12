shader_type spatial;
render_mode cull_disabled;

// Barbed wire: a picture of it with nothing between the strands (see
// _concertina() in tools/gen_foliage.gd), on a coil or on a ribbon. A strand
// is thinner than a dot of the screen from a few metres off: what counts as
// wire is therefore less and less of the picture the further away it is, so
// that a belt of it still stands as a thin grey lattice from across the
// ground it bars, and is gone where nobody could make it out.
uniform sampler2D wire_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cut_near : hint_range(0.0, 1.0) = 0.45;
uniform float cut_far : hint_range(0.0, 1.0) = 0.07;
uniform float roughness : hint_range(0.0, 1.0) = 0.46;

void fragment() {
	vec4 wire = texture(wire_tex, UV);
	ALBEDO = wire.rgb;
	ALPHA = wire.a;
	ALPHA_SCISSOR_THRESHOLD = mix(cut_near, cut_far, smoothstep(2.5, 28.0, -VERTEX.z));
	METALLIC = 0.8;
	ROUGHNESS = roughness;
}
