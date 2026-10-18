shader_type spatial;
render_mode skip_vertex_transform;

// The ground of the Alps, the land that is played on and the mountains round
// it alike: meadow on the floor of the basin and on the gentle slopes, the
// spruce wood below the tree line (from afar its crowns, close by the litter
// under them), rock where it is steep, scree below it, and the fresh snow of
// October on the heights. What lies where, how much sun a spot gets and how
// much of the sky it sees the level builder has worked out into two maps:
// one for the land, two metres a dot, and one for everything, 24 metres a dot
// (tools/levels/alps/plan.gd and vista.gd). Close by every layer has its
// scanned texture; far off each fades to the colour it is seen as.
//
// The sun's own shadow reaches a few hundred metres; beyond that the map says
// where the mountains keep the sun off, see light().

uniform float sea = 900.0;

uniform sampler2D far_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D far_b : filter_linear_mipmap, repeat_disable;
uniform vec4 far_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D land_a : filter_linear_mipmap, repeat_disable;
// The roads: how far a spot is from the middle of the nearest one (0 to 1
// for 0 to 16 m), and how wide that one is (0 to 1 for 0 to 8 m).
uniform sampler2D land_b : filter_linear, repeat_disable;
uniform vec4 land_rect = vec4(0.0, 0.0, 0.0, 0.0);
// The land is drawn as flat grids lifted to its heights: a height for every
// cell of it (in metres over the level's nought), and how large a cell is.
// The skirt of a grid is marked red and hangs down.
uniform bool lifted = false;
uniform sampler2D land_height : filter_nearest, repeat_disable;
uniform float land_cell = 2.0;

uniform sampler2D meadow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 gravel_far : source_color = vec3(0.46, 0.43, 0.37);
uniform sampler2D snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D far_rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D far_snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// The colour each layer is seen as from afar.
uniform vec3 meadow_far : source_color = vec3(0.2, 0.28, 0.09);
uniform vec3 autumn : source_color = vec3(0.42, 0.33, 0.15);
uniform vec3 crowns : source_color = vec3(0.04, 0.06, 0.035);
uniform vec3 larch : source_color = vec3(0.5, 0.33, 0.07);
uniform vec3 rock_far : source_color = vec3(0.5, 0.49, 0.47);
uniform vec3 scree_far : source_color = vec3(0.55, 0.54, 0.51);
uniform vec3 snow_far : source_color = vec3(0.9, 0.92, 0.96);
// How far off the near textures are gone, in metres, and between which
// distances the map's shadow takes over from the sun's own.
uniform float near_reach = 280.0;
uniform vec2 shadow_hand_over = vec2(200.0, 280.0);
// How much of the sun gets through a full cloud (scripts/cloud.gd turns the
// sun itself down; this is for the haze of the low sun in a deep valley).
uniform float shade_floor = 0.0;

varying vec3 world;
varying vec3 world_normal;
varying float sun_seen;

// Four octaves of value noise, read from a picture of it that tiles
// (tools/gen_noise.gd), a cell of the first octave a unit of `p` across:
// worked out here it was sixteen sines a call, and there are a dozen calls.
// Its spread is set to that of the noise it stands in for.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float fbm(vec2 p) {
	return 0.468 + (texture(noise_tex, p * (1.0 / 64.0)).r - 0.497) * 0.94;
}

float lift(ivec2 cell, ivec2 size) {
	return texelFetch(land_height, clamp(cell, ivec2(0), size - ivec2(1)), 0).r;
}

void vertex() {
	if (lifted) {
		vec3 spot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		ivec2 size = textureSize(land_height, 0);
		ivec2 cell = ivec2(round((spot.xz - land_rect.xy) / land_cell));
		float h = lift(cell, size);
		float west = lift(cell - ivec2(1, 0), size);
		float east = lift(cell + ivec2(1, 0), size);
		float north = lift(cell - ivec2(0, 1), size);
		float south = lift(cell + ivec2(0, 1), size);
		NORMAL = normalize(vec3(west - east, 2.0 * land_cell, north - south));
		// A skirt hangs as far as the coarsest block beside it can lie over it.
		VERTEX.y = h - COLOR.r * 1.6 * 8.0 * land_cell;
	}
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The textures lie on the ground by x and z, as a map: their right is
	// east and their up is north.
	TANGENT = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
}

// A texture seen from the side as well as from above: two projections, by
// which way the ground faces.
vec3 biplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 a = abs(n);
	vec3 top = texture(tex, p.xz * scale).rgb;
	vec3 side = a.x > a.z ? texture(tex, p.zy * scale).rgb : texture(tex, p.xy * scale).rgb;
	return mix(side, top, smoothstep(0.55, 0.8, a.y));
}

void fragment() {
	float depth = length(world - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(near_reach * 0.6, near_reach, depth);
	vec2 p = world.xz;
	vec2 at_far = (p - far_rect.xy) * far_rect.zw;
	vec4 fa = texture(far_a, at_far);
	vec4 fb = texture(far_b, at_far);
	// Inside the land its own map says more, and more finely; at its edge
	// the far map takes over.
	vec2 at_land = (p - land_rect.xy) * land_rect.zw;
	float inland = land_rect.z > 0.0 ? (1.0 - smoothstep(0.0, 0.01, max(max(-at_land.x, at_land.x - 1.0), max(-at_land.y, at_land.y - 1.0)) + 0.01)) : 0.0;
	vec4 la = texture(land_a, clamp(at_land, vec2(0.0), vec2(1.0)));
	float lit = mix(fa.r, la.r, inland);
	float open = mix(fa.g, la.g, inland);
	float forest = mix(fa.b, la.b, inland);
	float snow = fa.a;
	float rock = mix(fb.b, la.a, inland);
	float scree = fb.a * (1.0 - inland);

	// Which way the ground faces: the map's normal for the mountains, whose
	// squares are coarse, the mesh's own close by.
	vec3 mapped = normalize(vec3((fb.r - 0.5) * 2.0, 0.0, (fb.g - 0.5) * 2.0));
	mapped.y = sqrt(max(0.0, 1.0 - mapped.x * mapped.x - mapped.z * mapped.z));
	vec3 n = normalize(mix(mapped, normalize(world_normal), max(inland, smoothstep(3000.0, 1500.0, depth))));
	float fine = fbm(p * 0.03) - 0.5;
	// Close by, the steepness of the mesh itself says where rock shows.
	rock = max(rock, near * (1.0 - smoothstep(0.62, 0.74, normalize(world_normal).y + fine * 0.1)));
	rock = clamp(rock + fine * 0.3 * rock, 0.0, 1.0);

	// Every layer is only looked at where there is some of it: the most of
	// the land is meadow and nothing else.
	// The meadow: green on the floor, going over to the tawny of October in
	// patches and on the alps higher up. Close by the picture of the grass,
	// its bare earth grown over: where it is dark, the green of the sward.
	vec3 meadow = meadow_far;
	if (near > 0.0) {
		vec3 sward = texture(meadow_tex, p * 0.25).rgb;
		float sward_light = dot(sward, vec3(0.3, 0.6, 0.1));
		sward = mix(sward * vec3(0.8, 1.12, 0.55) * 1.15, meadow_far * (0.55 + sward_light * 2.2), 0.6);
		meadow = mix(sward, meadow_far, 1.0 - near);
	}
	float browned = smoothstep(0.6, 0.9, fbm(p * 0.006 + 7.7)) * 0.25 + smoothstep(1300.0, 1800.0, world.y + sea) * 0.75;
	meadow = mix(meadow, meadow * autumn / meadow_far, clamp(browned, 0.0, 1.0));
	// The floor of the basin is cut in strips from north to south, each mown
	// on a day of its own: one a little lighter than the next, one gone
	// yellow, one still long and dark.
	float on_floor = 1.0 - smoothstep(1000.0, 1040.0, world.y + sea);
	if (on_floor > 0.0) {
		float across_strips = (p.x + (fbm(p * 0.0025) - 0.5) * 70.0) / 31.0;
		float strip = floor(across_strips);
		float edge = smoothstep(0.93, 1.0, fract(across_strips));
		float mown = mix(fract(sin(strip * 12.9898) * 43758.5453), fract(sin((strip + 1.0) * 12.9898) * 43758.5453), edge);
		meadow *= mix(1.0, mix(0.84, 1.12, mown), on_floor);
		meadow = mix(meadow, meadow * vec3(1.12, 1.03, 0.72), smoothstep(0.72, 0.85, mown) * on_floor * 0.7);
	}
	vec3 colour = meadow;
	// Scree below the rock of the mountains.
	if (scree > 0.0) {
		vec3 gravel = scree_far * mix(0.85, 1.1, fbm(p * 0.02));
		if (near > 0.0) {
			gravel = mix(texture(scree_tex, p * 0.2).rgb, gravel, 1.0 - near);
		}
		colour = mix(colour, gravel, scree);
	}
	// The wood: where the map says how much of it there is, crowns stand in
	// clumps that many, with the shade between them; from far off that is
	// one tone. A larch gone gold here and there, more of them lower down;
	// above the tree line the dwarf pine, darker and lower.
	if (forest > 0.0) {
		float clumps = fbm(p * 0.14 + 3.0);
		float blur = smoothstep(700.0, 2600.0, depth);
		float stands = mix(smoothstep(0.42, 0.58, forest + (clumps - 0.5) * 0.9), forest, blur);
		float gaps = mix(smoothstep(0.3, 0.55, clumps), 0.55, blur);
		vec3 canopy = crowns * mix(0.55, 1.3, gaps) * mix(0.85, 1.15, fbm(p * 0.015));
		float larches = smoothstep(0.66, 0.74, fbm(p * 0.08 + 11.0)) * smoothstep(1950.0, 1700.0, world.y + sea) * smoothstep(1050.0, 1250.0, world.y + sea);
		canopy = mix(canopy, larch * mix(0.7, 1.2, gaps), larches * 0.45);
		vec3 wood = canopy;
		if (near > 0.0) {
			wood = mix(texture(forest_tex, p * 0.3).rgb * 0.75, canopy, 1.0 - near);
		}
		forest = stands;
		colour = mix(colour, wood, forest);
	}
	if (rock > 0.0) {
		vec3 stone = vec3(0.0);
		if (near < 1.0) {
			vec3 stone_far = biplanar(far_rock_tex, world, n, 0.0035);
			stone = mix(rock_far, stone_far * 1.15, 0.55) * mix(0.8, 1.15, fbm(p * 0.01 + 5.0));
		}
		if (near > 0.0) {
			stone = mix(biplanar(rock_tex, world, n, 0.11) * vec3(1.05, 1.04, 1.02), stone, 1.0 - near);
		}
		colour = mix(colour, stone, rock);
	}
	// A road: two ruts of gravel, the stones pressed into the earth between
	// them, grass along the middle of a track and at the edges; worn into
	// the meadow, with the earth showing at the verges.
	float road = 0.0;
	if (inland > 0.0) {
		vec4 lb = texture(land_b, clamp(at_land, vec2(0.0), vec2(1.0)));
		float from_middle = lb.r * 16.0;
		float half_wide = lb.g * 8.0 * 0.5;
		if (half_wide > 0.0 && from_middle < half_wide + 2.0) {
			float edge = half_wide + (fbm(p * 0.6) - 0.5) * 0.5;
			road = (1.0 - smoothstep(edge - 0.35, edge + 0.25, from_middle)) * inland;
			vec3 stones = gravel_far;
			if (near > 0.0) {
				stones = mix(texture(gravel_tex, p * 0.5).rgb, gravel_far, 1.0 - near);
			}
			float rut = smoothstep(0.42, 0.12, abs(from_middle - half_wide * 0.5));
			float spine = (1.0 - smoothstep(0.25, 0.55, from_middle)) * step(half_wide, 1.9);
			vec3 earth_road = mix(stones * 0.85, stones * 0.62, rut);
			earth_road = mix(earth_road, meadow * 0.9, spine * 0.85);
			// The verge: trodden earth where the road ends.
			float verge = smoothstep(edge - 0.2, edge + 0.4, from_middle) * (1.0 - smoothstep(edge + 0.4, edge + 1.3, from_middle));
			colour = mix(colour, colour * vec3(0.78, 0.72, 0.6), verge * 0.6 * inland);
			colour = mix(colour, earth_road, road);
		}
	}
	forest *= 1.0 - road;
	// Snow lies on the ledges of a face, and thins where it is steep.
	float lying = 0.0;
	if (snow > 0.0) {
		lying = clamp(snow * mix(1.0, 0.45 + 0.4 * smoothstep(0.35, 0.65, fbm(p * 0.03)), rock), 0.0, 1.0);
		vec3 white = snow_far * mix(0.92, 1.0, texture(far_snow_tex, p * 0.002).r);
		if (near > 0.0) {
			white = mix(texture(snow_tex, p * 0.15).rgb, white, 1.0 - near);
		}
		colour = mix(colour, white, lying);
	}
	ALBEDO = colour;
	ROUGHNESS = mix(mix(0.92, 0.85, rock), 0.6, lying);
	SPECULAR = mix(0.3, 0.5, lying);
	// The sky a spot sees, and under the wood the shade of the crowns.
	AO = open * mix(1.0, 0.7, forest * near);
	AO_LIGHT_AFFECT = 0.0;
	sun_seen = mix(1.0, lit, smoothstep(shadow_hand_over.x, shadow_hand_over.y, depth));
	sun_seen = max(sun_seen, shade_floor);

	// The normal: the map's for the mountains, the relief of the near
	// textures close by.
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	if (near > 0.0) {
		vec3 nm = texture(meadow_nor, p * 0.25).rgb;
		if (forest > 0.0) {
			nm = mix(nm, texture(forest_nor, p * 0.3).rgb, forest);
		}
		if (rock > 0.0) {
			nm = mix(nm, texture(rock_nor, p * 0.11).rgb, rock);
		}
		if (road > 0.0) {
			nm = mix(nm, texture(gravel_nor, p * 0.5).rgb, road);
		}
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, near * (1.0 - lying * 0.7));
	}
}

// The sun as the scanned layers of a ground take it: soft, and kept off by
// the map where the sun's own shadow no longer reaches.
void light() {
	float shade = LIGHT_IS_DIRECTIONAL ? sun_seen : 1.0;
	float wrap = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += wrap * ATTENUATION * shade * LIGHT_COLOR / PI;
	vec3 half_way = normalize(LIGHT + VIEW);
	float shine = pow(max(dot(NORMAL, half_way), 0.0), mix(8.0, 64.0, 1.0 - ROUGHNESS)) * (1.0 - ROUGHNESS) * 0.35;
	SPECULAR_LIGHT += shine * wrap * ATTENUATION * shade * LIGHT_COLOR / PI;
}
