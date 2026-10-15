shader_type spatial;
render_mode cull_disabled;

// A tree from afar: one card that turns to whoever looks, with the picture
// on it that was taken from nearest to where he stands. tools/gen_tree_cards.sh
// takes the pictures, eight to a tree, side by side on a sheet: the colour of
// every dot without light, and on a second sheet which way it faces, seen
// from where the picture was taken, and in its alpha whether it lets light
// through (needles) or not (wood). The sun is put on it here as
// shaders/crown.gdshader puts it on the tree itself.
//
// A corner of the card says in UV2 how far to the side of the stem it is, in
// metres, and the vertex colour says in its red how the tree is turned, as a
// share of a full turn, for a tree that is part of a larger mesh, in its
// green how much of the light gets to it, and in its blue what tells such a
// tree from the next.
uniform sampler2D far_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D far_facing : filter_linear_mipmap, repeat_disable;
// How many pictures there are of a tree, side by side.
uniform float sides = 8.0;
// What counts as a hole.
uniform float cut : hint_range(0.0, 1.0) = 0.35;
// As in shaders/crown.gdshader: how much of the sun comes through needles
// from behind, how much gets to what other needles shade, and how far round
// the sun reaches.
uniform float through : hint_range(0.0, 1.0) = 0.2;
uniform float scatter : hint_range(0.0, 1.0) = 0.22;
uniform float wrap : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
// How much one tree differs from the next in colour, by where it stands.
uniform float vary : hint_range(0.0, 0.5) = 0.12;

#include "tree_lod.gdshaderinc"

varying vec3 own;
varying float lets;

void vertex() {
	float turned = COLOR.r * 6.2831853;
	// Where the stem is at the height of this corner.
	vec3 stem = VERTEX - vec3(cos(turned), 0.0, -sin(turned)) * UV2.x;
	vec3 eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec2 to = normalize(eye.xz - stem.xz + vec2(0.0, 0.0001));
	vec3 toward = vec3(to.x, 0.0, to.y);
	vec3 right = vec3(to.y, 0.0, -to.x);
	VERTEX = stem + right * UV2.x;
	NORMAL = toward;
	TANGENT = right;
	BINORMAL = vec3(0.0, 1.0, 0.0);
	// The picture taken from nearest to there.
	float side = floor(mod((atan(to.x, to.y) - turned) / 6.2831853 * sides + 0.5, sides));
	UV.x += side / sides;
	// Yellower or bluer, and lighter or darker, from where the tree stands,
	// as its crown is from closer by; a tree that is part of a larger mesh
	// has dice of its own in the blue of its corners.
	vec2 stands = MODEL_MATRIX[3].xz + vec2(977.0, 131.0) * COLOR.b;
	float warm = fract(sin(dot(stands, vec2(12.9898, 78.233))) * 43758.5453) * 2.0 - 1.0;
	float light = fract(sin(dot(stands, vec2(39.346, 11.135))) * 24634.6345) * 2.0 - 1.0;
	own = vec3(1.0 + vary * warm, 1.0 + vary * 0.35 * warm, 1.0 - vary * 0.8 * warm) * (1.0 + vary * light) * COLOR.g;
	if (given_way(NODE_POSITION_WORLD, MAIN_CAM_INV_VIEW_MATRIX[3].xyz, 0.5)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec4 seen = texture(far_tex, UV);
	ALPHA = seen.a;
	ALPHA_SCISSOR_THRESHOLD = cut;
	vec4 faces = texture(far_facing, UV);
	vec3 way = faces.rgb * 2.0 - 1.0;
	NORMAL = normalize(TANGENT * way.x + BINORMAL * way.y + NORMAL * way.z);
	// Only needles differ from tree to tree: bark is bark.
	ALBEDO = seen.rgb * mix(vec3(dot(own, vec3(0.333))), own, faces.a);
	ROUGHNESS = roughness;
	SPECULAR = 0.1;
	lets = through * faces.a;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = clamp((facing + wrap) / (1.0 + wrap), 0.0, 1.0) + clamp(-facing, 0.0, 1.0) * lets;
	float reaches = LIGHT_IS_DIRECTIONAL ? mix(scatter, 1.0, ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * reaches / PI;
}
