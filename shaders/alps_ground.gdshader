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
uniform sampler2D snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D far_rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D far_snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// The colour each layer is seen as from afar.
uniform vec3 meadow_far : source_color = vec3(0.24, 0.29, 0.12);
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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.3);
		amp *= 0.5;
	}
	return sum;
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
	float up = n.y;
	float wobble = fbm(p * 0.004) - 0.5;
	float fine = fbm(p * 0.03) - 0.5;
	// Close by, the steepness of the mesh itself says where rock shows.
	rock = max(rock, near * (1.0 - smoothstep(0.62, 0.74, normalize(world_normal).y + fine * 0.1)));
	rock = clamp(rock + fine * 0.3 * rock, 0.0, 1.0);

	// The meadow: green on the floor, going over to the tawny of October in
	// patches and on the alps higher up.
	vec3 meadow = mix(texture(meadow_tex, p * 0.25).rgb * vec3(0.95, 1.05, 0.8), meadow_far, 1.0 - near);
	float browned = smoothstep(0.55, 0.85, fbm(p * 0.006 + 7.7)) * 0.35 + smoothstep(1250.0, 1750.0, world.y + sea) * 0.75;
	meadow = mix(meadow, meadow * autumn / meadow_far, clamp(browned, 0.0, 1.0));
	// The wood: where the map says how much of it there is, crowns stand in
	// clumps that many, with the shade between them; from far off that is
	// one tone. A larch gone gold here and there, more of them lower down;
	// above the tree line the dwarf pine, darker and lower.
	float clumps = fbm(p * 0.14 + 3.0);
	float blur = smoothstep(700.0, 2600.0, depth);
	float stands = mix(smoothstep(0.42, 0.58, forest + (clumps - 0.5) * 0.9), forest, blur);
	float gaps = mix(smoothstep(0.3, 0.55, clumps), 0.55, blur);
	vec3 canopy = crowns * mix(0.55, 1.3, gaps) * mix(0.85, 1.15, fbm(p * 0.015));
	float larches = smoothstep(0.62, 0.72, fbm(p * 0.035 + 11.0)) * smoothstep(1950.0, 1700.0, world.y + sea) * smoothstep(1050.0, 1250.0, world.y + sea);
	canopy = mix(canopy, larch * mix(0.7, 1.2, gaps), larches * 0.8);
	vec3 litter = texture(forest_tex, p * 0.3).rgb * 0.75;
	vec3 wood = mix(litter, canopy, 1.0 - near);
	forest = stands;
	vec3 stone_near = biplanar(rock_tex, world, n, 0.11) * vec3(1.05, 1.04, 1.02);
	vec3 stone_far = biplanar(far_rock_tex, world, n, 0.0035);
	stone_far = mix(rock_far, stone_far * 1.15, 0.55) * mix(0.8, 1.15, fbm(p * 0.01 + 5.0));
	vec3 stone = mix(stone_near, stone_far, 1.0 - near);
	vec3 gravel = mix(texture(scree_tex, p * 0.2).rgb, scree_far * mix(0.85, 1.1, fbm(p * 0.02)), 1.0 - near);
	vec3 white = mix(texture(snow_tex, p * 0.15).rgb, snow_far * mix(0.92, 1.0, texture(far_snow_tex, p * 0.002).r), 1.0 - near);

	vec3 colour = meadow;
	colour = mix(colour, gravel, scree);
	colour = mix(colour, wood, forest);
	colour = mix(colour, stone, rock);
	// Snow lies on the ledges of a face, and thins where it is steep.
	float lying = snow * mix(1.0, 0.45 + 0.4 * smoothstep(0.35, 0.65, fbm(p * 0.03)), rock);
	colour = mix(colour, white, clamp(lying, 0.0, 1.0));
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
		nm = mix(nm, texture(forest_nor, p * 0.3).rgb, forest);
		nm = mix(nm, texture(rock_nor, p * 0.11).rgb, rock);
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
