shader_type spatial;

// The ground of open land. Bare sand is what lies underneath everything:
// pale where the wind keeps it moving, with ripples a hand apart on the
// slopes that face the wind and none on the faces it slides down, darker
// and firmer where it lies low and damp. Over it comes what the level
// builder painted on its map of the land (cover() in tools/kit/land.gd): a
// litter of needles, moss on top of that, and packed earth, red, green and
// blue. The ground has its place in metres for UV.
//
// What the builder knows of every spot of the land and no texture says, it
// hands over with the corners of the mesh, see _dress_ground() there:
//
//   COLOR.r  how high the spot lies among what is around it: 0.5 for level
//            with it, more for a crest, less for a hollow
//   COLOR.g  how loose the sand is: 0 where it was levelled or is driven on
//   COLOR.b  how much of a crust of moss and lichen it has: grey dune
//   COLOR.a  how much grass stands on it, for when that is too far to draw
//   UV2      where the spot lies by the nearest track: metres to the right
//            of its middle, and metres along it. Twelve metres and more
//            to the right is no track but the mound of sand under a clump
//            of grass: twelve for its foot, one more or less for its rim
//
// The alpha of the map holds where the sun does not come. Near the camera
// the sun draws that shadow itself; where its shadow maps end, the ground
// darkens by the map instead, so that a wood far off still stands on shade.
//
// A scan is only looked up where it shows: six look-ups on bare sand, nine
// under the pines where moss grows on the litter, twelve where sand, litter
// and moss meet; fewer by one for each scan within six metres.
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D needles_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D needles_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cover : hint_default_transparent, filter_linear_mipmap, repeat_disable;
// Where the map lies: x and z of its first corner, then one over its width
// and its depth.
uniform vec4 cover_rect = vec4(0.0);
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// How many times a scan fits into a metre.
uniform float sand_scale = 0.55;
uniform float needles_scale = 0.5;
uniform float moss_scale = 0.5;
uniform float earth_scale = 0.5;
// The colour of each: of dry sand and of sand that lies low and damp; of
// needles lately fallen and long fallen; of moss under the pines and of the
// crust of the grey dune; of earth, and of sand that wheels have packed.
uniform vec3 sand_tint : source_color = vec3(1.0);
uniform vec3 damp_tint : source_color = vec3(0.7);
// The scan of sand is of a river bank: how much of its colour is bleached
// out of it, how much lighter it is made, and how much lighter again on a
// crest.
uniform float sand_bleach : hint_range(0.0, 1.0) = 0.2;
uniform float sand_light = 1.17;
uniform float crest_light = 1.1;
uniform vec3 needles_tint : source_color = vec3(1.0);
uniform vec3 litter_tint : source_color = vec3(0.6);
uniform vec3 moss_tint : source_color = vec3(1.0);
uniform vec3 crust_tint : source_color = vec3(0.8);
uniform vec3 earth_tint : source_color = vec3(1.0);
uniform vec3 packed_tint : source_color = vec3(0.75);
// What grass far off makes of the sand it stands on.
uniform vec3 grass_tint : source_color = vec3(0.6, 0.62, 0.4);
// What the straw a clump has dropped makes of the sand at its foot, and how
// much of the light the clump keeps off it.
uniform vec3 straw_tint : source_color = vec3(0.85, 0.78, 0.6);
uniform float foot_depth : hint_range(0.0, 1.0) = 0.38;
// The way the wind blows over the land (x and z), how far apart its ripples
// lie in metres, and how steep they are.
uniform vec2 wind = vec2(0.12, 1.0);
uniform float ripple_length = 0.13;
uniform float ripple_steep : hint_range(0.0, 1.0) = 0.2;
// Half the gauge of what drives on a track, half the width of a rut and how
// deep it is, in metres; and how far apart the lugs of a tyre are.
uniform float rut_gauge = 0.93;
uniform float rut_width = 0.36;
uniform float rut_depth = 0.04;
uniform float lug_pitch = 0.17;
// Between these distances the shadow of the sun gives way to the map, and
// this is how much of its light the shade of the map takes off.
uniform float shadow_from = 80.0;
uniform float shadow_to = 105.0;
uniform float shade_depth : hint_range(0.0, 1.0) = 0.6;
// Beyond this the grass is not drawn, and the ground shows it instead.
uniform float grass_from = 55.0;
uniform float grass_to = 85.0;

// Each scan lies turned its own way, so that no two repeat along the same
// lines, and none along the rows the land is laid in.
const mat2 TURN_SAND = mat2(vec2(0.9553, 0.2955), vec2(-0.2955, 0.9553));
const mat2 TURN_FAR = mat2(vec2(0.5403, -0.8415), vec2(0.8415, 0.5403));
const mat2 TURN_NEEDLES = mat2(vec2(0.8253, -0.5646), vec2(0.5646, 0.8253));
const mat2 TURN_MOSS = mat2(vec2(0.3624, 0.932), vec2(-0.932, 0.3624));
const mat2 TURN_EARTH = mat2(vec2(0.7648, 0.6442), vec2(-0.6442, 0.7648));

// Which way the ground faces in the world, and which way the right and the
// top of a scan lie on it: east and north, on ground laid by its place.
varying vec3 lie;
varying vec3 east;
varying vec3 north;

void vertex() {
	lie = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	east = normalize(MODEL_NORMAL_MATRIX * TANGENT);
	north = normalize(MODEL_NORMAL_MATRIX * BINORMAL);
}

// A scan from close by and, turned and five times as large, from afar: far
// off it gives way to the second, which does not repeat where it can be
// seen to. `far` is how much of it.
vec3 scan(sampler2D tex, mat2 turn, float scale, vec2 at, vec2 dx, vec2 dy, float far) {
	mat2 near = turn * scale;
	vec3 rgb = textureGrad(tex, near * at, near * dx, near * dy).rgb;
	if (far > 0.0) {
		mat2 wide = TURN_FAR * near * 0.21;
		rgb = mix(rgb, textureGrad(tex, wide * at, wide * dx, wide * dy).rgb, far);
	}
	return rgb;
}

// The slant a normal map gives the ground, for a scan that lies turned.
vec2 slant(sampler2D tex, mat2 turn, float scale, vec2 at, vec2 dx, vec2 dy) {
	mat2 near = turn * scale;
	return turn * (textureGrad(tex, near * at, near * dx, near * dy).xy * 2.0 - 1.0);
}

void fragment() {
	vec2 at = (UV - cover_rect.xy) * cover_rect.zw;
	// Beyond the map there is sand and nothing else.
	float inside = float(at == clamp(at, 0.0, 1.0));
	vec4 lies = texture(cover, at) * inside;
	vec4 spot = mix(vec4(0.5, 0.0, 0.0, 0.0), COLOR, inside);
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	float depth = -VERTEX.z;
	float far = smoothstep(6.0, 40.0, depth) * 0.8;

	// Along the wind and across it, in metres.
	vec2 downwind = normalize(wind);
	vec2 crosswind = vec2(downwind.y, -downwind.x);
	// Patches a dune across, drawn out the way the wind blows, and rags a
	// stride across.
	vec3 patchy = texture(wear_mask, vec2(dot(UV, crosswind), dot(UV, downwind)) * vec2(0.021, 0.0075)).rgb;
	vec3 ragged = texture(wear_mask, UV * 0.23).rgb;

	// --- The track ---------------------------------------------------------
	// Two ruts, which weave a little along the way, a strip between them
	// that nothing drives on, and what the wheels threw to either side.
	float across = UV2.x;
	float along = UV2.y;
	float along_wide = fwidth(along);
	vec2 across_wide = vec2(dFdx(across), dFdy(across));
	// Beyond its end a track is measured from nought downwards: there it
	// runs out.
	float driven = (1.0 - smoothstep(2.1, 2.9, abs(across) + (ragged.b - 0.5) * 0.8)) * (1.0 - smoothstep(0.0, 7.0, -along)) * inside;
	float rut = 0.0;
	float worn = 0.0;
	float print = 0.0;
	// What ripples, ruts and the like tilt the ground by: how fast it
	// rises to the east and to the south.
	vec2 rises = vec2(0.0);
	if (driven > 0.0) {
		// Which way the track runs here, from how its measure changes over
		// the ground.
		float turn = dx.x * dy.y - dx.y * dy.x;
		vec2 aside = vec2(across_wide.x * dy.y - across_wide.y * dx.y, across_wide.y * dx.x - across_wide.x * dy.x) / turn;
		aside = normalize(aside + vec2(1e-5, 0.0));
		vec2 ahead = vec2(-aside.y, aside.x);
		float weave = 0.17 * sin(along * 0.071) + 0.09 * sin(along * 0.19 + 1.7);
		float off = across + weave;
		float into = (abs(off) - rut_gauge) / rut_width;
		if (abs(into) < 1.0) {
			// A rut has a flat bed and short sides.
			rut = (1.0 - smoothstep(0.55, 1.0, abs(into))) * (1.0 - smoothstep(0.0, 7.0, -along));
			float side = smoothstep(0.55, 0.78, abs(into)) * (1.0 - smoothstep(0.78, 1.0, abs(into)));
			rises += aside * sign(off) * sign(into) * side * rut_depth * 4.0 / rut_width;
			// The print of the tread, chevrons that point the way it was
			// driven, where no later wheel has smeared it.
			float lugs = (along + abs(into) * rut_width * 0.9) / lug_pitch;
			float sharp = 1.0 - smoothstep(0.15, 0.45, along_wide / lug_pitch);
			float fresh = smoothstep(0.25, 0.5, ragged.g) * sharp * rut;
			print = smoothstep(-0.3, 0.3, sin(lugs * 6.2832)) * fresh;
			rises += ahead * cos(lugs * 6.2832) * fresh * 0.3;
		}
		// The lip of loose sand outside each rut.
		float lip = (abs(off) - rut_gauge - rut_width - 0.35) / 0.5;
		if (abs(lip) < 1.0) {
			rises += aside * sign(off) * 0.03 * 1.5708 * sin(lip * 3.1416) / 0.5 * driven;
		}
		// Older wheels have left their lines all over it.
		float lines = sin(off * 21.0 + sin(along * 0.31) * 2.0) * sin(off * 8.3 + along * 0.05);
		rises += aside * lines * 0.05 * driven;
		// Litter, moss and crust are worn off it: wholly in the ruts, a
		// good deal beside them, least between the wheels.
		worn = max(rut, driven * (0.25 + 0.3 * smoothstep(0.5, 1.3, abs(off)) + 0.25 * (ragged.r - 0.5)));
	}

	// The foot of a clump of grass: as dark as its blades leave it, less so
	// where no sun comes anyway, with the straw it has dropped.
	float foot = 0.0;
	if (across > 10.5) {
		foot = 1.0 - smoothstep(0.0, 0.84, length(UV2 - vec2(12.0, 0.0)));
	}

	// --- What lies where -----------------------------------------------------
	// Each cover comes in raggedly, not as the soft disc it was painted as,
	// and at its edge by what its own scan shows: a needle, a tuft of moss.
	vec3 fallen = vec3(0.0);
	vec2 fallen_tilt = vec2(0.0);
	float needles = lies.r * (1.0 - worn * 0.92) + (ragged.r - 0.5) * 0.8;
	if (needles > 0.15) {
		fallen = scan(needles_tex, TURN_NEEDLES, needles_scale, UV, dx, dy, far);
		fallen_tilt = slant(needles_normal, TURN_NEEDLES, needles_scale, UV, dx, dy) * 1.3;
		needles = smoothstep(0.38, 0.62, needles + (dot(fallen, vec3(1.2)) - 0.86) * 0.5);
		// Rust where they fell lately, grey where they have lain long.
		fallen = mix(fallen, vec3(dot(fallen, vec3(0.3, 0.6, 0.1))), 0.3);
		fallen *= mix(litter_tint, needles_tint, smoothstep(0.3, 0.7, patchy.g + (ragged.b - 0.5) * 0.5));
	} else {
		needles = 0.0;
	}
	// One scan of moss serves twice: bleached, with the sand showing
	// through, it is the lichen and dead moss of the grey dune; as it is, it
	// is the cushions that grow on the litter under the pines.
	vec3 mossy = vec3(0.0);
	vec2 mossy_tilt = vec2(0.0);
	float moss = (lies.g * 0.45 + lies.r * 0.14) * (1.0 - worn) + (ragged.g - 0.5) * 0.9 + (patchy.g - 0.5) * 0.5;
	float crust = spot.b * (1.0 - worn) * (1.0 - needles) + (ragged.g - 0.5) * 0.7 + (patchy.b - 0.5) * 0.4;
	if (moss > 0.3 || crust > 0.25) {
		mossy = scan(moss_tex, TURN_MOSS, moss_scale, UV, dx, dy, far);
		mossy_tilt = slant(moss_normal, TURN_MOSS, moss_scale, UV, dx, dy);
		// How green the scan is here: its grass stands for a cushion.
		float lush = (mossy.g - mossy.r * 0.85) * 6.0;
		moss = smoothstep(0.46, 0.6, moss + lush * 0.3);
		crust = smoothstep(0.4, 0.62, crust + lush * 0.25);
	} else {
		moss = 0.0;
		crust = 0.0;
	}
	// Earth is what is left where wheels and boots have been: it lies on top.
	// It lies in patches, with sand blown over it in between.
	float earth = smoothstep(0.35, 0.65, lies.b + (ragged.b - 0.5) * 0.45 + (patchy.r - 0.55) * 0.55);

	// --- Sand --------------------------------------------------------------
	float bare = (1.0 - needles) * (1.0 - moss) * (1.0 - crust) * (1.0 - earth * 0.92);
	vec3 ground = vec3(0.0);
	vec2 tilt = vec2(0.0);
	float rough = 0.96;
	float loose = spot.g * (1.0 - driven);
	if (bare > 0.004) {
		vec3 sand = scan(sand_tex, TURN_SAND, sand_scale, UV, dx, dy, far);
		sand = mix(sand, vec3(dot(sand, vec3(0.3, 0.6, 0.1))), sand_bleach) * sand_tint * sand_light;
		// Low and damp, or high and dry; and streaks the wind has sorted.
		float high = spot.r + (patchy.r - 0.5) * 0.3 + (ragged.r - 0.5) * 0.08;
		float dry = smoothstep(0.16, 0.46, high);
		sand *= mix(damp_tint, vec3(1.0), dry);
		sand *= mix(1.0, crest_light, smoothstep(0.56, 0.85, high));
		sand *= mix(0.9, 1.08, patchy.b);
		// The scan is of sand that has set: loose sand is smoother.
		tilt = slant(sand_normal, TURN_SAND, sand_scale, UV, dx, dy) * mix(1.0, 0.4, loose);
		rough = mix(0.86, 0.96, dry);

		// Where the sand is loose and bare the wind shapes it: none of it
		// on a face steep enough to slide, less in the lee and where it
		// is wet.
		float windward = -dot(lie.xz, downwind);
		float shaped = loose * bare * smoothstep(0.8, 0.9, lie.y) * mix(0.6, 1.0, smoothstep(-0.25, 0.1, windward)) * smoothstep(0.1, 0.34, high);
		if (shaped > 0.01) {
			// Ripples lie across the wind, bent a little to either side by
			// the slope: two sets of them, and by the side the slope
			// falls to and by chance it is the one or the other.
			vec2 one = normalize(downwind + crosswind * 0.36);
			vec2 other = normalize(downwind - crosswind * 0.42);
			float pick = smoothstep(0.35, 0.65, ragged.g + (lie.x * downwind.y - lie.z * downwind.x) * 1.5);
			float bend = (ragged.r - 0.5) * 9.0 + (patchy.g - 0.5) * 40.0;
			float wave = 6.2832 / ripple_length;
			// They come in three sizes, a hand, a stride and a body
			// apart. Each shows as far as one of it can be told from the
			// next, and where a finer one shows, the coarser lies low.
			vec2 falls = vec2(0.0);
			float trough = 0.0;
			float hidden = 0.0;
			// How far a dot of the picture reaches over the ground, along
			// the one set and along the other.
			float dot_wide = mix(abs(dot(dx, one)) + abs(dot(dy, one)), (abs(dot(dx, other)) + abs(dot(dy, other))) * 1.13, pick);
			for (int size = 0; size < 3; size++) {
				float first = dot(UV, one) * wave + bend;
				float second = dot(UV, other) * wave * 1.13 - bend * 0.7;
				float seen = 1.0 - smoothstep(0.6, 1.9, dot_wide * wave);
				float much = seen * mix(1.0, 0.28, hidden);
				// A ripple has a long back and a short face.
				float a = first + 0.4 * sin(first);
				float b = second + 0.4 * sin(second);
				falls += mix(one * cos(a) * (1.0 + 0.4 * cos(first)), other * cos(b) * (1.0 + 0.4 * cos(second)), pick) * much;
				trough += (0.5 - 0.5 * mix(sin(a), sin(b), pick)) * much;
				hidden = max(hidden, seen);
				wave *= 0.31;
				bend = bend * 0.45 + 1.7;
			}
			float rippled = shaped * mix(0.6, 1.0, smoothstep(0.3, 0.6, patchy.g));
			rises += falls * ripple_steep * rippled;
			// Coarse dark grains gather in the troughs.
			sand *= 1.0 - 0.05 * rippled * trough;
		}
		// What wheels have packed is darker, and what they churn up is not
		// as clean as what the wind has sifted.
		sand *= mix(vec3(1.0), packed_tint, max(rut, driven * 0.3));
		sand *= 1.0 - print * 0.14;
		rough = mix(rough, 0.84, rut);
		ground = sand;
	}

	// --- What lies on it ---------------------------------------------------
	if (crust > 0.0) {
		vec3 grey = mix(mossy, vec3(dot(mossy, vec3(0.3, 0.6, 0.1))), 0.65) * crust_tint * mix(0.8, 1.15, patchy.r);
		ground = mix(ground, grey, crust);
		tilt = mix(tilt, mossy_tilt, crust);
		rough = mix(rough, 0.94, crust);
	}
	ground = mix(ground, fallen, needles);
	tilt = mix(tilt, fallen_tilt, needles);
	rough = mix(rough, 0.9, needles);
	if (moss > 0.0) {
		ground = mix(ground, mossy * moss_tint * mix(0.75, 1.15, patchy.b), moss);
		tilt = mix(tilt, mossy_tilt * 1.4, moss);
		rough = mix(rough, 0.95, moss);
	}
	if (earth > 0.004) {
		vec3 packed = scan(earth_tex, TURN_EARTH, earth_scale, UV, dx, dy, far) * earth_tint * mix(0.8, 1.15, patchy.g) * mix(0.82, 1.1, ragged.r);
		packed *= 1.0 - (rut * 0.25 + print * 0.14);
		ground = mix(ground, packed, earth * 0.92);
		tilt = mix(tilt, slant(earth_normal, TURN_EARTH, earth_scale, UV, dx, dy), earth);
		rough = mix(rough, 0.9, earth);
	}

	// Grass too far off to be drawn: the sand between it darkens to it.
	float grassy = spot.a * smoothstep(grass_from, grass_to, depth) * (0.6 + 0.4 * ragged.g);
	ground = mix(ground, ground * grass_tint, grassy);

	float shade = lies.a;
	ground *= mix(vec3(1.0), straw_tint, foot * 0.6) * (1.0 - foot * foot_depth * (1.0 - 0.6 * shade));
	float mapped = smoothstep(shadow_from, shadow_to, depth);
	// Under a crown the sky is hidden as well as the sun: a little darker
	// from close by too.
	ALBEDO = ground * mix(1.0, 1.0 - shade_depth, shade * mapped) * mix(1.0, 0.88, shade);
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	// The tilt of ripples and ruts, turned from the world into the lie of
	// the mesh, on top of what the scans say.
	tilt -= vec2(dot(rises, east.xz), dot(rises, north.xz)) * inversesqrt(1.0 + dot(rises, rises));
	NORMAL_MAP = vec3(clamp(tilt, vec2(-0.95), vec2(0.95)) * 0.5 + 0.5, 1.0);
}
