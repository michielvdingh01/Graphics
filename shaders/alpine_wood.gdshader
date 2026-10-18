shader_type spatial;

// Larch and spruce that have stood out of doors for a lifetime, as a hay
// barn or the upper floor of a farmhouse in Tyrol has: grey where the rain
// beats on it, burnt brown where the sun stands all day, darker at the foot
// where the rain splashes up, worn pale along every edge, with grey lichen on
// what faces the sky. Every timber is a little lighter or darker than the
// next, and the end of a log shows its rings.
//
// A face has its position in metres for UV; along a timber the grain runs
// down V, and across it the builder squeezes U, so that a log shows one
// board of the scan and not three. The builder writes into UV2 what it knows
// of the timber: in x a tone of its own between 0 and 1, plus 2 for the end
// of it and 4 for a face inside a building, where the light of the sky
// hardly comes, and in y how high the ground lies it stands on. Into the vertex
// colour it writes where a point lies between the edges of its face: see
// _edge() in tools/level_builder.gd and _alp_timber() in tools/kit/alpine.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
// The luminance of the scan on average, in linear light: what it is divided
// by to keep its grain and lose its colour.
uniform float scan_mean = 0.06;
// How much of the grain of the scan is kept.
uniform float grain : hint_range(0.0, 2.0) = 0.9;
// The grey wood weathers to where the rain beats on it and the sun does not
// stand long, and the brown it burns to where the sun stands all day.
uniform vec3 grey : source_color = vec3(0.38, 0.365, 0.34);
uniform vec3 burnt : source_color = vec3(0.28, 0.215, 0.16);
// The way the sun stands at noon over the ground, x and z: south.
uniform vec2 sun_side = vec2(0.15, 0.99);
// How much one timber differs from the next.
uniform float tones : hint_range(0.0, 1.0) = 0.5;
// What is left of the light of the sky inside a building.
uniform float sheltered : hint_range(0.0, 1.0) = 0.18;
// How dark the foot is from the rain that splashes up, and how high.
uniform float splash : hint_range(0.0, 1.0) = 0.45;
uniform float splash_high = 0.6;
// Lichen on what faces up, and moss at the foot where the sun does not come.
uniform float lichen : hint_range(0.0, 1.0) = 0.5;
uniform float moss : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_normal;
varying float height;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - UV2.y;
}

void fragment() {
	float inside = step(3.5, UV2.x);
	float rest = UV2.x - 4.0 * inside;
	float end_grain = step(1.5, rest);
	float tone = fract(rest);
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	vec3 relief = texture(normal_tex, uv).rgb;
	vec3 wide = texture(wear_mask, UV * 0.11 + vec2(tone * 7.3, tone * 3.1)).rgb;
	vec3 fine = texture(wear_mask, UV * 0.9 + vec2(0.31, 0.57)).rgb;

	// The colour of the wood: grey or burnt as its face turns to the sun, and
	// one timber a shade off the next.
	float sunny = smoothstep(-0.2, 0.9, dot(world_normal.xz, sun_side));
	// Some timbers have gone greyer than the rest, some have kept more brown.
	float browner = fract(tone * 7.31) - 0.5;
	vec3 wood = mix(grey, burnt, clamp(sunny * (0.45 + 0.4 * wide.g) + browner * 0.7, 0.0, 1.0));
	wood *= mix(1.0 - tones * 0.5, 1.0 + tones * 0.35, tone);
	wood = mix(wood, wood * vec3(1.06, 0.98, 0.9), tones * fract(tone * 5.7));
	// The scan's light and dark, around its mean: the grain, the cracks
	// between boards, the knots and the nails.
	float lum = dot(scan, vec3(0.299, 0.587, 0.114)) / scan_mean;
	vec3 albedo = wood * mix(1.0, lum, grain);

	// The end of a timber: rings round its heart, darker, with checks that
	// run out from the middle.
	float rings = 0.0;
	if (end_grain > 0.5) {
		float r = length(UV);
		float a = atan(UV.y, UV.x);
		rings = 0.5 + 0.5 * sin(r * 160.0 + fine.r * 6.0);
		float check = smoothstep(0.93, 0.99, sin(a * 3.0 + tone * 20.0)) * smoothstep(0.02, 0.06, r);
		albedo = wood * mix(0.62, 0.82, rings) * (1.0 - 0.6 * check) * mix(0.85, 1.05, fine.g);
	}

	// Where in its face this point lies: a worn edge is paler.
	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	vec2 in_face = COLOR.rg * span;
	vec2 to_edge = min(in_face, span - in_face);
	float edge = 1.0 - smoothstep(0.004, 0.025, min(to_edge.x, to_edge.y));
	albedo = mix(albedo, grey * 1.25, edge * 0.45 * (1.0 - end_grain));

	// Whatever faces the sky greys and grows lichen; whatever faces the
	// ground stays dark.
	float faces_up = smoothstep(0.5, 0.95, world_normal.y);
	float faces_down = smoothstep(0.3, 0.9, -world_normal.y);
	albedo = mix(albedo, grey * mix(0.85, 1.15, fine.b), faces_up * 0.45);
	float spots = faces_up * lichen * smoothstep(0.62, 0.72, fine.g * 0.7 + wide.r * 0.45);
	albedo = mix(albedo, vec3(0.42, 0.43, 0.33), spots * 0.6);
	albedo *= 1.0 - faces_down * 0.35;

	// The foot: dark where the rain splashes up, green where it never dries.
	float wet = (1.0 - smoothstep(0.0, splash_high * (0.6 + 0.8 * wide.b), height)) * step(-1.0, height);
	albedo *= 1.0 - splash * wet;
	float green = wet * moss * (1.0 - sunny) * smoothstep(0.4, 0.7, fine.g * 0.6 + wide.b * 0.5);
	albedo = mix(albedo, vec3(0.1, 0.13, 0.05), green * 0.7);

	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.82, 0.95, orm.g);
	METALLIC = 0.0;
	AO = mix(1.0, orm.r, 0.8) * mix(1.0, sheltered, inside);
	NORMAL_MAP = relief;
	NORMAL_MAP_DEPTH = mix(1.1, 0.5, end_grain);
}
