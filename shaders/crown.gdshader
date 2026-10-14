shader_type spatial;
render_mode cull_disabled;

// The cards a crown is made of: the needles of a pine, the leaves of a
// bush. The texture has the holes; what is left of it is lit from both
// sides and lets some of the sun through. A card is flat and a crown is
// not, so its normals are not its own: whoever builds the tree hands every
// corner the normal of the tuft and of the crown it belongs to, and those
// are what is shaded.
//
// A hole is cut hard, dot by dot, and not softened where the picture has
// several samples to the dot. Softened, a crown is drawn with what is
// see-through: every card of it lit in full, with the sun's shadow looked
// up for each, before the cards in front cover it. In a wood that was half
// of what a frame cost. Cut hard, the crowns are sorted out by depth first
// and only what shows is lit.
//
// The vertex colour says how a corner moves in the wind and how much light
// gets to it: red is how far it sways, green where in its sway it is next to
// the others, blue how deep in the crown it sits (0) or how far out (1), and
// alpha is 1 for a card that lies on a bough: its back is then its underside,
// which the sun does not see. Alpha one half is wood that is drawn along
// with the needles, the trunk of a tree far off: it takes the colour of the
// texture as it is and lets no light through.
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
// What counts as a hole from close by, and from far off: seen small, thin
// needles blur into less than half a dot each, and a crown would thin out.
uniform float cut : hint_range(0.0, 1.0) = 0.4;
uniform float cut_far : hint_range(0.0, 1.0) = 0.25;
// What counts as a hole to the sun, whose shadow has the holes of the
// texture too: the light that falls through a crown.
uniform float cut_shadow : hint_range(0.0, 1.0) = 0.3;
// How far a corner that sways fully moves, in metres.
uniform float sway = 0.07;
// How much of the sun comes through a card from behind.
uniform float through : hint_range(0.0, 1.0) = 0.3;
// How much of the sun still gets to what stands in the shadow of other
// needles: a crown is not a wall, and what comes through it and is thrown
// about in it keeps its shade green where a wall's would be black.
uniform float scatter : hint_range(0.0, 1.0) = 0.22;
// How far round a tuft the sun reaches: at nought only what faces it is lit.
uniform float wrap : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// How dark what sits deep in a crown is, next to what is on its outside.
uniform float deep : hint_range(0.0, 1.0) = 0.45;
// How much one tree differs from the next in colour, by where it stands:
// no two trees of a wood are the same green.
uniform float vary : hint_range(0.0, 0.5) = 0.0;
// How far out along its normal a dot looks for the sun, in metres. A card
// is handed the normal of its tuft, and the cards of a tuft stand in each
// other's shadow dot by dot, which shows as stripes: from a little way out
// of the tuft the sun is either there or it is not.
uniform float lift = 0.0;
// How square to the look a card has to stand to be drawn whole: a card seen
// along its own plane is a bright line where nothing is, and leaves it to
// the cards that stand through it to show what is there.
uniform float edge = 0.0;
// How many steps sharper than the distance asks the texture is read: thin
// needles then stay needles for longer, and a sprig does not close up into
// the shape of its card.
uniform float sharp = 0.0;
// How wide the rim of a hole is, as a share of the cut, and how many steps
// blurrier than the distance asks the hole is read for it: see fragment().
uniform float soft : hint_range(0.0, 1.0) = 0.6;
uniform float blur : hint_range(0.0, 3.0) = 1.0;

varying vec3 own;
// How much light a dot lets through from behind: none, for wood.
varying float lets;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = COLOR.g * 6.283 + world.x * 0.21 + world.z * 0.17;
	vec3 push = vec3(sin(TIME * 1.3 + phase), 0.35 * sin(TIME * 2.9 + phase * 1.7), cos(TIME * 1.1 + phase * 0.8)) * sway * COLOR.r;
	VERTEX += push * mat3(MODEL_MATRIX);
	// Yellower or bluer, and lighter or darker, from where the tree stands.
	vec2 stands = MODEL_MATRIX[3].xz;
	float warm = fract(sin(dot(stands, vec2(12.9898, 78.233))) * 43758.5453) * 2.0 - 1.0;
	float light = fract(sin(dot(stands, vec2(39.346, 11.135))) * 24634.6345) * 2.0 - 1.0;
	own = vec3(1.0 + vary * warm, 1.0 + vary * 0.35 * warm, 1.0 - vary * 0.8 * warm) * (1.0 + vary * light);
}

void fragment() {
	vec4 leaf = texture(leaf_tex, UV, -sharp);
	ALPHA = leaf.a;
	if (IN_SHADOW_PASS) {
		ALPHA_SCISSOR_THRESHOLD = cut_shadow;
	} else {
		// The rim of a hole is not a line. Seen small, a brush of needles has
		// no outline: it thins out into its tips. So where the texture is seen
		// smaller than it was made, the hole is read from a blurred copy of it,
		// which widens its rim, and over that rim one dot is there and the
		// next is not, in a pattern without a direction. Each dot is still
		// there or not: the crown stays in the depth pass, and only what shows
		// is lit.
		vec2 dots = fwidth(UV) * vec2(textureSize(leaf_tex, 0));
		float small = smoothstep(1.0, 3.0, max(dots.x, dots.y));
		float grain = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		float at = mix(cut, cut_far, smoothstep(8.0, 60.0, -VERTEX.z));
		ALPHA = mix(leaf.a, texture(leaf_tex, UV, blur).a, small * 0.75);
		ALPHA_SCISSOR_THRESHOLD = clamp(at * (1.0 + soft * small * (grain * 2.0 - 1.0)), 0.02, 0.98);
		float wood = 1.0 - abs(COLOR.a - 0.5) * 2.0;
		float lies = max(COLOR.a * 2.0 - 1.0, 0.0);
		// The normal it was handed, whichever side of the card is looked at.
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		// The side of the card that is looked at, as it really faces.
		vec3 faces = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		vec3 look = normalize(VERTEX);
		faces *= -sign(dot(faces, look));
		float squarely = -dot(faces, look);
		ALPHA *= clamp(squarely / max(edge, 0.0001), 0.0, 1.0);
		// A card that lies is a plate of needles. Looked at squarely, its
		// top looks at the sky and its underside at the ground, whatever
		// its tuft does; looked at along its plane it is what the tuft is.
		vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		float skyward = clamp(dot(faces, up) * 4.0, -1.0, 1.0);
		float plate = lies * smoothstep(0.3, 0.85, squarely);
		NORMAL = normalize(mix(NORMAL, (NORMAL - up * dot(NORMAL, up)) * 0.6 + up * skyward, plate));
		float under = plate * clamp(-skyward, 0.0, 1.0);
		vec3 colour = leaf.rgb * mix(tint * own, vec3(1.0), wood);
		ALBEDO = colour * mix(deep, 1.0, COLOR.b) * mix(1.0, 0.8, under);
		ROUGHNESS = roughness;
		SPECULAR = 0.1;
		// What sits deep in a crown sees little of the sky either.
		AO = mix(0.7, 1.0, COLOR.b);
		lets = through * (1.0 - wood);
		LIGHT_VERTEX = VERTEX + NORMAL * lift;
	}
}

// The sun on needles: on what faces it and some way round, through a card
// from behind, and a share of it on what other needles shade. No gloss: a
// crown has none from where anybody stands.
void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = clamp((facing + wrap) / (1.0 + wrap), 0.0, 1.0) + clamp(-facing, 0.0, 1.0) * lets;
	float reaches = LIGHT_IS_DIRECTIONAL ? mix(scatter, 1.0, ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * reaches / PI;
}
