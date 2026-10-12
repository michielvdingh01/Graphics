shader_type spatial;
render_mode cull_disabled;

// A card of leaves: the crown of a pine, a bush, a tuft of grass. The
// texture has the holes; what is left of it is lit from both sides, and
// lets some of the sun through. The cards of a tree are few and large, so
// their normals are not their own: whoever builds the tree hands every
// corner the normal of the crown it belongs to, and the crown is shaded as
// one mass.
//
// The vertex colour says how a corner moves in the wind and how much light
// gets to it: red is how far it sways, green where in its sway it is next to
// the others, blue how deep in the crown it sits (0) or how far out (1), and
// alpha is 1 for a card that lies on a bough: its back is then its underside,
// which the sun does not see.
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
// What counts as a hole from close by, and from far off: seen small, thin
// leaves blur into less than half a dot each, and a crown would thin out.
uniform float cut_near : hint_range(0.0, 1.0) = 0.45;
uniform float cut_far : hint_range(0.0, 1.0) = 0.12;
// How far a corner that sways fully moves, in metres.
uniform float sway = 0.07;
// How much of the sun comes through a card from behind.
uniform float through : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = COLOR.g * 6.283 + world.x * 0.21 + world.z * 0.17;
	vec3 push = vec3(sin(TIME * 1.3 + phase), 0.35 * sin(TIME * 2.9 + phase * 1.7), cos(TIME * 1.1 + phase * 0.8)) * sway * COLOR.r;
	VERTEX += push * mat3(MODEL_MATRIX);
}

void fragment() {
	vec4 leaf = texture(leaf_tex, UV);
	float under = FRONT_FACING ? 0.0 : COLOR.a;
	ALBEDO = leaf.rgb * tint * mix(0.45, 1.0, COLOR.b) * mix(1.0, 0.5, under);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = mix(cut_near, cut_far, smoothstep(8.0, 60.0, -VERTEX.z));
	ROUGHNESS = roughness;
	SPECULAR = 0.1;
	BACKLIGHT = leaf.rgb * tint * through * 2.0 * (1.0 - under * 0.6);
	// The normal of the crown, whichever side of the card is looked at.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
