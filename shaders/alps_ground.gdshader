shader_type spatial;
render_mode skip_vertex_transform;

// The ground of the Alps, the land that is played on and the mountains round
// it alike: meadow on the floor of the basin and on the gentle slopes, the
// spruce wood below the tree line (from afar its crowns, close by the moss
// and the litter under them), rock where it is steep, scree below it, and the
// fresh snow of October on the heights. What lies where, how much sun a spot
// gets and how much of the sky it sees the level builder has worked out into
// maps: three for the land, a dot for every metre, and two for everything,
// 24 metres a dot (tools/levels/alps/plan.gd and vista.gd). Close by every
// layer has its scanned textures; further off each fades to their mean
// colour, worked out from the textures themselves, so that the two meet.
//
// The sun's own shadow reaches a few hundred metres; beyond that the map says
// where the mountains keep the sun off, see light().

uniform float sea = 900.0;

uniform sampler2D far_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D far_b : filter_linear_mipmap, repeat_disable;
uniform vec4 far_rect = vec4(0.0, 0.0, 1.0, 1.0);
// The middle map, ten kilometres round the land at five metres a dot (see
// _mid_map() in vista.gd): which way the ground faces, wood, rock; scree,
// snow, the light and shade of the aerial photograph, sun.
uniform sampler2D mid_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D mid_b : filter_linear_mipmap, repeat_disable;
uniform vec4 mid_rect = vec4(0.0);
uniform sampler2D land_a : filter_linear_mipmap, repeat_disable;
// The roads: how far a spot is from the middle of the nearest one (0 to 1
// for 0 to 16 m), and how wide that one is (0 to 1 for 0 to 8 m).
uniform sampler2D land_b : filter_linear, repeat_disable;
// The grass: long, wet, trodden, the edge of the wood (_grass_map() in
// plan.gd).
uniform sampler2D land_c : filter_linear_mipmap, repeat_disable;
uniform vec4 land_rect = vec4(0.0, 0.0, 0.0, 0.0);
// The land is drawn as flat grids lifted to its heights: a height for every
// cell of it (in metres over the level's nought), and how large a cell is.
// The skirt of a grid is marked red and hangs down.
uniform bool lifted = false;
uniform sampler2D land_height : filter_nearest, repeat_disable;
uniform float land_cell = 2.0;

// The sward: green grass on earth, and the grass of October gone to straw.
uniform sampler2D meadow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D straw_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D straw_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D straw_arm : filter_linear_mipmap_anisotropic, repeat_enable;
// Bare earth: the verges and the camps.
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The floor of the wood: litter and moss.
uniform sampler2D forest_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The grey limestone gravel of the roads of the basin, which the scan of a
// road is brought to on the mean, as the meadow is.
uniform vec3 gravel_far : source_color = vec3(0.55, 0.53, 0.47);
uniform sampler2D snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D far_rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D far_snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// The colour each layer is seen as from afar, where no texture says so.
uniform vec3 meadow_far : source_color = vec3(0.2, 0.28, 0.09);
uniform vec3 autumn : source_color = vec3(0.42, 0.33, 0.15);
uniform vec3 crowns : source_color = vec3(0.04, 0.06, 0.035);
uniform vec3 larch : source_color = vec3(0.5, 0.33, 0.07);
uniform vec3 rock_far : source_color = vec3(0.5, 0.49, 0.47);
uniform vec3 scree_far : source_color = vec3(0.55, 0.54, 0.51);
uniform vec3 snow_far : source_color = vec3(0.9, 0.92, 0.96);
// The colours the meadow is seen as: the green of a mown meadow in October
// and the straw of what was left standing. The scans keep their detail but
// are brought to these on the mean, so that near and far are one colour.
uniform vec3 green_seen : source_color = vec3(0.35, 0.42, 0.19);
uniform vec3 straw_seen : source_color = vec3(0.62, 0.54, 0.32);
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

// The mean colour of a texture: its last mip, one dot.
vec3 mean_of(sampler2D tex) {
	return textureLod(tex, vec2(0.5), 14.0).rgb;
}

// Two layers blended by which of them stands higher at a spot (its
// brightness, for these scans), so that straw lies over the green between its
// blades and not as a haze over all of it.
float over(float under_height, float over_height, float share) {
	float a = under_height + (1.0 - share);
	float b = over_height + share;
	float top = max(a, b) - 0.18;
	float wa = max(a - top, 0.0);
	float wb = max(b - top, 0.0);
	return wb / (wa + wb + 1e-4);
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
		VERTEX.y = h - COLOR.r * 1.6 * 16.0 * land_cell;
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

// Turns a spot of the ground, for a second reading of a texture that does not
// line up with the first.
vec2 turned(vec2 p, float by) {
	float c = cos(by);
	float s = sin(by);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	float depth = length(world - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(near_reach * 0.6, near_reach, depth);
	vec2 p = world.xz;
	vec2 at_far = (p - far_rect.xy) * far_rect.zw;
	vec4 fa = texture(far_a, at_far);
	vec4 fb = texture(far_b, at_far);
	// Inside the land its own maps say more, and more finely; at its edge
	// the far map takes over.
	vec2 at_land = (p - land_rect.xy) * land_rect.zw;
	float inland = land_rect.z > 0.0 ? (1.0 - smoothstep(0.0, 0.01, max(max(-at_land.x, at_land.x - 1.0), max(-at_land.y, at_land.y - 1.0)) + 0.01)) : 0.0;
	vec2 on_land = clamp(at_land, vec2(0.0), vec2(1.0));
	vec4 la = texture(land_a, on_land);
	vec4 lc = texture(land_c, on_land) * inland;
	// Between the land and the far map, the middle one, fading out over its
	// last kilometre.
	vec2 at_mid = (p - mid_rect.xy) * mid_rect.zw;
	float to_mid_edge = min(min(at_mid.x, 1.0 - at_mid.x), min(at_mid.y, 1.0 - at_mid.y)) / max(mid_rect.z, 1e-6);
	float middle = mid_rect.z > 0.0 ? smoothstep(0.0, 1000.0, to_mid_edge) * (1.0 - inland) : 0.0;
	vec4 ma = vec4(0.5, 0.5, 0.0, 0.0);
	vec4 mb = vec4(0.0, 0.0, 0.5, 1.0);
	if (middle > 0.0) {
		ma = texture(mid_a, at_mid);
		mb = texture(mid_b, at_mid);
	}
	float lit = mix(mix(fa.r, mb.a, middle), la.r, inland);
	float open = mix(fa.g, la.g, inland);
	float forest = mix(mix(fa.b, ma.b, middle), la.b, inland);
	float snow = mix(fa.a, mb.g, middle);
	float rock = mix(mix(fb.b, ma.a, middle), la.a, inland);
	float scree = mix(fb.a, mb.r, middle) * (1.0 - inland);
	// The light and shade of the photograph: the ledges of a face, the
	// gullies, the rocks in the scree, the clumps of a wood.
	float relief = mix(1.0, mb.b * 2.0, middle * 0.6);
	float long_grass = lc.r;
	float wet = lc.g;
	float trodden = lc.b;

	// Which way the ground faces: the map's normal for the mountains, whose
	// squares are coarse, the mesh's own close by.
	vec2 facing = mix(fb.rg, ma.rg, middle);
	vec3 mapped = normalize(vec3((facing.x - 0.5) * 2.0, 0.0, (facing.y - 0.5) * 2.0));
	mapped.y = sqrt(max(0.0, 1.0 - mapped.x * mapped.x - mapped.z * mapped.z));
	vec3 n = normalize(mix(mapped, normalize(world_normal), max(inland, smoothstep(3000.0, 1500.0, depth) * (1.0 - middle))));
	float fine = fbm(p * 0.03) - 0.5;
	// Close by, the steepness of the mesh itself says where rock shows: a
	// face steeper than about fifty degrees.
	rock = max(rock, near * (1.0 - smoothstep(0.56, 0.68, normalize(world_normal).y + fine * 0.1)));
	rock = clamp(rock + fine * 0.3 * rock, 0.0, 1.0);

	// The meadow. How dry it is: patches gone to straw, more of it high up
	// and where nobody mows; the floor of the basin is cut in strips from
	// north to south, each mown on a day of its own, one a little lighter
	// than the next, one gone yellow, one still long and dark.
	float dry = smoothstep(0.6, 0.85, fbm(p * 0.006 + 7.7)) * 0.3 + smoothstep(1250.0, 1700.0, world.y + sea) * 0.5;
	dry += long_grass * 0.25;
	float shade_of_strip = 1.0;
	float on_floor = 1.0 - smoothstep(1000.0, 1040.0, world.y + sea);
	if (on_floor > 0.0) {
		float across_strips = (p.x * 0.94 + p.y * 0.34 + (fbm(p * 0.0025) - 0.5) * 60.0) / 27.0;
		float strip = floor(across_strips);
		float edge = smoothstep(0.93, 1.0, fract(across_strips));
		float mown = mix(fract(sin(strip * 12.9898) * 43758.5453), fract(sin((strip + 1.0) * 12.9898) * 43758.5453), edge);
		shade_of_strip = mix(1.0, mix(0.92, 1.06, mown), on_floor);
		dry += smoothstep(0.78, 0.95, mown) * on_floor * 0.35;
	}
	dry = clamp(dry + (fbm(p * 0.05 + 1.3) - 0.5) * 0.25, 0.0, 1.0);
	vec3 to_green = green_seen / max(mean_of(meadow_tex), vec3(0.005));
	vec3 to_straw = straw_seen / max(mean_of(straw_tex), vec3(0.005));
	vec3 meadow = mix(green_seen, straw_seen, dry);
	vec3 meadow_n = vec3(0.5, 0.5, 1.0);
	float meadow_ao = 1.0;
	float meadow_rough = 0.95;
	if (near > 0.0) {
		vec3 green = texture(meadow_tex, p * 0.31).rgb;
		// A second reading, turned and coarser, breaks up the tiles.
		vec2 q = turned(p, 0.7) * 0.113 + 0.31;
		green = mix(green, texture(meadow_tex, q).rgb, 0.3) * to_green;
		vec3 straw = texture(straw_tex, turned(p, -0.4) * 0.27 + 0.57).rgb * to_straw;
		float k = over(dot(green, vec3(0.333)) * 1.6, dot(straw, vec3(0.333)) * 1.6, dry);
		vec3 sward = mix(green, straw, k);
		vec4 arm_g = texture(meadow_arm, p * 0.31);
		vec4 arm_s = texture(straw_arm, turned(p, -0.4) * 0.27 + 0.57);
		meadow_ao = mix(mix(arm_g.r, arm_s.r, k), 1.0, 1.0 - near);
		meadow_rough = mix(mix(arm_g.g, arm_s.g, k), 0.95, 1.0 - near);
		meadow_n = mix(texture(meadow_nor, p * 0.31).rgb, texture(straw_nor, turned(p, -0.4) * 0.27 + 0.57).rgb, k);
		meadow = mix(sward, meadow, 1.0 - near);
	}
	meadow *= shade_of_strip * mix(0.9, 1.08, fbm(p * 0.02 + 4.0));
	// The pastures of the mountains round the land: grazed short and gone
	// olive, and seen through kilometres of air.
	meadow *= mix(vec3(1.0), vec3(0.78, 0.8, 0.82), 1.0 - inland);
	// Wet: the ditches, darker and greener, the earth showing.
	meadow = mix(meadow, meadow * vec3(0.62, 0.7, 0.55), wet * 0.8);
	// Trodden: bare earth through the grass at the verges and in the camps.
	vec3 colour = meadow;
	if (trodden > 0.0) {
		vec3 earth = mean_of(soil_tex);
		if (near > 0.0) {
			earth = mix(texture(soil_tex, p * 0.4).rgb, earth, 1.0 - near);
			meadow_n = mix(meadow_n, texture(soil_nor, p * 0.4).rgb, trodden);
		}
		float bare = smoothstep(0.25, 0.75, trodden + (fbm(p * 0.9) - 0.5) * 0.6);
		colour = mix(colour, earth * vec3(0.95, 0.9, 0.85), bare);
	}
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
	// above the tree line the dwarf pine, darker and lower. Close by, under
	// the trees that are drawn, the floor: needles, and moss in hollows.
	vec3 floor_n = vec3(0.5, 0.5, 1.0);
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
			vec3 litter = texture(forest_tex, p * 0.35).rgb;
			vec3 moss = texture(moss_tex, turned(p, 1.1) * 0.21).rgb;
			float mossy = smoothstep(0.45, 0.65, fbm(p * 0.09 + 2.0) + (1.0 - open) * 0.3);
			vec3 ground_floor = mix(litter, moss * vec3(0.85, 0.95, 0.8), mossy);
			wood = mix(ground_floor * 0.8, canopy, 1.0 - near);
			floor_n = texture(forest_nor, p * 0.35).rgb;
		}
		forest = stands;
		// The edge of the wood is long grass gone to straw, with litter in it.
		colour = mix(colour, wood, forest);
	}
	if (rock > 0.0) {
		vec3 stone = vec3(0.0);
		if (near < 1.0) {
			vec3 stone_far = biplanar(far_rock_tex, world, n, 0.0035);
			stone = mix(rock_far, stone_far * 1.15, 0.55) * mix(0.8, 1.15, fbm(p * 0.01 + 5.0));
		}
		if (near > 0.0) {
			stone = mix(biplanar(rock_tex, world, n, 0.13), stone, 1.0 - near);
		}
		colour = mix(colour, stone, rock);
	}
	// A road: two ruts of gravel, the stones pressed into the earth between
	// them, grass along the middle of a track and at the edges; worn into
	// the meadow, with the earth showing at the verges.
	float road = 0.0;
	if (inland > 0.0) {
		vec4 lb = texture(land_b, on_land);
		float from_middle = lb.r * 16.0;
		float half_wide = lb.g * 8.0 * 0.5;
		if (half_wide > 0.0 && from_middle < half_wide + 2.0) {
			float edge = half_wide + (fbm(p * 0.6) - 0.5) * 0.5;
			road = (1.0 - smoothstep(edge - 0.35, edge + 0.25, from_middle)) * inland;
			vec3 stones = gravel_far;
			if (near > 0.0) {
				vec3 laid = texture(gravel_tex, p * 0.45).rgb * gravel_far / max(mean_of(gravel_tex), vec3(0.005));
				// A path is earth, a road gravel.
				laid = mix(texture(soil_tex, p * 0.4).rgb * 0.9, laid, smoothstep(1.4, 2.0, half_wide));
				stones = mix(laid, gravel_far, 1.0 - near);
			}
			float rut = smoothstep(0.42, 0.12, abs(from_middle - half_wide * 0.5));
			float spine = (1.0 - smoothstep(0.25, 0.55, from_middle)) * step(half_wide, 1.9);
			vec3 earth_road = mix(stones * 0.9, stones * 0.7, rut);
			earth_road = mix(earth_road, meadow * 0.9, spine * 0.85);
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
	ALBEDO = colour * mix(relief, 1.0, lying * 0.6);
	float grassy = (1.0 - forest) * (1.0 - rock) * (1.0 - road);
	ROUGHNESS = mix(mix(mix(0.92, 0.85, rock), meadow_rough, grassy) - wet * 0.25, 0.6, lying);
	SPECULAR = mix(0.3, 0.5, lying);
	// The sky a spot sees, and under the wood the shade of the crowns; close
	// by, the hollows between the blades.
	AO = open * mix(1.0, 0.7, forest * near) * mix(1.0, meadow_ao, grassy);
	AO_LIGHT_AFFECT = 0.0;
	sun_seen = mix(1.0, lit, smoothstep(shadow_hand_over.x, shadow_hand_over.y, depth));
	sun_seen = max(sun_seen, shade_floor);

	// The normal: the map's for the mountains, the relief of the near
	// textures close by.
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	if (near > 0.0) {
		vec3 nm = meadow_n;
		if (forest > 0.0) {
			nm = mix(nm, floor_n, forest);
		}
		if (rock > 0.0) {
			nm = mix(nm, texture(rock_nor, p * 0.13).rgb, rock);
		}
		if (road > 0.0) {
			nm = mix(nm, texture(gravel_nor, p * 0.45).rgb, road);
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
