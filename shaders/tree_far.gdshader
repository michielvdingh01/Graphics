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
// Whether the alpha of the facing sheet says how much light the needles of
// that tree let through, as a share of `through`, rather than only that
// they are needles: 0 for wood, and from one half up for needles, a half for
// none and one for all of `through`. The trees of the Alps are pictured so,
// for a larch lets the sun through where a spruce does not.
uniform bool graded = false;
// How much of the sky the crown sees, as shaders/crown.gdshader has it.
uniform float sky_seen : hint_range(0.0, 1.0) = 1.0;
// Where the mountains keep the sun off, for a tree beyond the sun's own
// shadow: a map of the level's (its red is how much of the sun gets to the
// ground there), where it lies, as (west, north, 1 / width, 1 / depth), and
// over which distances it takes over from the sun's shadow, as the ground
// takes it over (shaders/alps_ground.gdshader). Without a map every tree far
// off is in the sun.
uniform sampler2D sun_map : hint_default_white, filter_linear, repeat_disable;
uniform vec4 sun_rect = vec4(0.0);
uniform vec2 shadow_hand_over = vec2(200.0, 280.0);

#include "tree_lod.gdshaderinc"

varying vec3 own;
varying float lets;
varying float sun_seen;

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
	vec3 foot = MODEL_MATRIX[3].xyz;
	vec3 eye_at = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	// Where the far cards go, each tree goes at a distance of its own.
	float own_end = fract(sin(dot(stands, vec2(93.989, 67.345))) * 23421.631);
	if (given_way_by(foot, eye_at, 0.5, own_end)) {
		VERTEX = vec3(0.0);
	}
	sun_seen = 1.0;
	if (sun_rect.z > 0.0) {
		float lit = textureLod(sun_map, (foot.xz - sun_rect.xy) * sun_rect.zw, 0.0).r;
		sun_seen = mix(1.0, lit, smoothstep(shadow_hand_over.x, shadow_hand_over.y, distance(foot, eye_at)));
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
	float needles = graded ? smoothstep(0.2, 0.45, faces.a) : faces.a;
	ALBEDO = seen.rgb * mix(vec3(dot(own, vec3(0.333))), own, needles);
	ROUGHNESS = roughness;
	SPECULAR = 0.1;
	AO = sky_seen;
	lets = through * (graded ? clamp(faces.a * 2.0 - 1.0, 0.0, 1.0) : faces.a);
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = clamp((facing + wrap) / (1.0 + wrap), 0.0, 1.0) + clamp(-facing, 0.0, 1.0) * lets;
	float reaches = LIGHT_IS_DIRECTIONAL ? mix(scatter, 1.0, ATTENUATION * sun_seen) : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * reaches / PI;
}
