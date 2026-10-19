shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

// What grows between the grass of the Alps and on the floor of the wood,
// drawn round the eye as the grass is (scripts/meadow.gd, and see
// shaders/alps_grass.gdshader for the rings, the tiles and the cards). A
// plant stands in a square of the grid by its own dice, or none does; which
// plant, the shader works out from the maps of the land:
//
//   layer 0, the meadow (alps_herbs): autumn crocus in drifts over the mown
//            meadow, pale lilac and without a leaf; dandelion rosettes and
//            the odd clock; knapweed and yarrow in the long grass; nettles
//            in clumps where the ground is trodden, by barns and gates.
//   layer 1, the wood (alps_floor): bilberry gone red and orange in carpets
//            where some light comes through, ferns gone gold and brown,
//            cushions of moss and wood sorrel in the shade, and the odd
//            spruce seedling.
//   layer 2, the edge of the wood (alps_shrubs): hazel gone yellow, rowan
//            with its red berries, juniper on the sunny steep; each card of
//            a shrub shows it from another side.
//
// Nothing of it throws a shadow; every plant sways and is a shade of its own.

uniform int layer = 0;
uniform float spacing = 0.5;
uniform int columns = 14;
uniform float hole = 0.0;
uniform float reach = 12.0;
uniform bool last_ring = false;
uniform bool facing_eye = false;
// How much larger than its picture a plant of this ring is, and by how much
// more likely a square of it holds one: further out there are fewer squares.
uniform vec2 grown = vec2(1.0, 1.0);
uniform float more = 1.0;

uniform sampler2D land_height : filter_nearest, repeat_disable;
uniform sampler2D land_a : filter_linear, repeat_disable;
uniform sampler2D land_b : filter_linear, repeat_disable;
uniform sampler2D land_c : filter_linear, repeat_disable;
uniform vec4 land_rect = vec4(0.0);
uniform float land_cell = 2.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform sampler2D plants_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D plants_normal : hint_normal, filter_linear_mipmap, repeat_disable;
// Where on the sheet every picture is and how many metres it shows, as
// meadow.gd reads them from the sheet's json, in the order of its CELLS.
uniform vec4 cells[24];
uniform vec2 cell_size[24];
uniform float cut_near : hint_range(0.0, 1.0) = 0.4;
uniform float cut_far : hint_range(0.0, 1.0) = 0.25;
uniform vec2 wind = vec2(0.6, 0.8);
uniform float sway = 0.06;
uniform float through : hint_range(0.0, 1.0) = 0.3;

varying float sky;
varying float shade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fbm(vec2 p) {
	return 0.468 + (textureLod(noise_tex, p * (1.0 / 64.0), 0.0).r - 0.497) * 0.94;
}

// Which picture grows in this square, or -1; and of the four cards of a tuft
// whether the one that lies flat is used (only by what has a picture from
// above). `top` is the cell seen from above, or -1. `card` is which card of
// the tuft it is.
void pick(vec2 at, vec2 square, vec4 map, vec4 lie, float meadow, float steep, float verge, int card, out int cell, out int top) {
	cell = -1;
	top = -1;
	float r = hash(square + 51.3);
	float v = hash(square + 23.9);
	if (layer == 0) {
		if (meadow < 0.5) {
			return;
		}
		// Which grass grows here, as the grass works it out.
		float wet_here = lie.g + (fbm(at * 0.22 + 31.0) - 0.47) * 0.75;
		float long_here = max(max(lie.r, lie.a * 0.85), smoothstep(0.45, 0.8, steep)) + (fbm(at * 0.27 + 77.0) - 0.47) * 0.75;
		bool wet = wet_here > 0.5;
		bool tall = !wet && long_here > 0.5;
		float drift = smoothstep(0.52, 0.62, fbm(at * 0.045 + 5.0));
		float clump = smoothstep(0.5, 0.6, fbm(at * 0.2 + 13.0));
		// Nettles by the barns and in the camps, not on the verge of a road.
		float nettles = max(smoothstep(0.35, 0.7, lie.b) * (1.0 - verge), lie.a * 0.4) * clump;
		// The chances add up: each kind takes the next stretch of the dice.
		float p1 = nettles * 0.7 * more;
		// Bare earth, as the ground has it: only nettles stand at its rim.
		float bare = smoothstep(0.25, 0.75, lie.b + (fbm(at * 0.9) - 0.5) * 0.6);
		if (r < p1) {
			cell = 12 + int(v * 4.0);
		} else if (wet || bare > 0.3) {
			return;
		} else if (tall) {
			float p2 = p1 + 0.1 * more;
			float p3 = p2 + 0.07 * more;
			if (r < p2) {
				cell = 8 + int(v * 2.0);
			} else if (r < p3) {
				cell = 10 + int(v * 2.0);
			}
		} else {
			float p2 = p1 + drift * 0.18 * more;
			float p3 = p2 + 0.035 * more;
			float p4 = p3 + 0.01 * more;
			float p5 = p4 + 0.006 * more;
			if (r < p2) {
				cell = int(v * 4.0);
			} else if (r < p3) {
				cell = 16 + int(v * 4.0);
			} else if (r < p4) {
				cell = 4 + int(v * 4.0);
			} else if (r < p5) {
				cell = 10 + int(v * 2.0);
			}
		}
	} else if (layer == 2) {
		// Shrubs on the meadow side of the edge of the wood, and the odd one
		// on its own: hazel, rowan, and juniper where it is sunny and steep.
		float fringe = smoothstep(0.1, 0.4, map.b) * (1.0 - smoothstep(0.55, 0.85, map.b));
		float edge = max(lie.a, fringe) * (1.0 - smoothstep(0.2, 0.5, map.a));
		if (r >= (edge * 0.7 + 0.003) * more) {
			return;
		}
		float dry = smoothstep(0.3, 0.6, steep) * smoothstep(0.4, 0.8, map.r);
		int kind = v < dry * 0.6 ? 2 : (v < 0.55 + dry * 0.2 ? 0 : 1);
		int variant = int(hash(square + 7.1) * 2.0);
		cell = kind * 6 + variant * 3 + card % 3;
	} else {
		float wood = smoothstep(0.45, 0.75, map.b) * (1.0 - smoothstep(0.2, 0.5, map.a));
		if (wood < 0.5 || hash(square + 3.3) > wood) {
			return;
		}
		// How much sky the floor sees: bilberry and seedlings where some
		// light comes in, moss and sorrel where it is dark.
		float light = smoothstep(0.25, 0.6, map.g);
		float berries = smoothstep(0.45, 0.55, fbm(at * 0.07) + light * 0.12);
		float ferns = smoothstep(0.55, 0.62, fbm(at * 0.05 + 40.0));
		float moss = smoothstep(0.48, 0.56, fbm(at * 0.11 + 80.0) + (1.0 - light) * 0.1);
		float p1 = berries * 0.85 * more;
		float p2 = p1 + ferns * 0.55 * more;
		float p3 = p2 + moss * 0.5 * more;
		float p4 = p3 + (1.0 - light) * 0.12 * more;
		float p5 = p4 + (0.02 + light * 0.05) * more;
		if (r < p1) {
			cell = int(v * 4.0);
		} else if (r < p2) {
			cell = 4 + int(v * 4.0);
		} else if (r < p3) {
			cell = 12 + int(v * 2.0);
			top = 16 + int(v * 2.0);
		} else if (r < p4) {
			cell = 14 + int(v * 2.0);
			top = 18 + int(v * 2.0);
		} else if (r < p5) {
			cell = 8 + int(v * 4.0);
		}
	}
}

void vertex() {
	vec3 eye = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	vec2 square = round(MODEL_MATRIX[3].xz / spacing) + vec2(float(INSTANCE_ID % columns), float(INSTANCE_ID / columns));
	float d1 = hash(square);
	float d2 = hash(square + 17.31);
	float d3 = hash(square + 41.17);
	float d4 = hash(square + 73.9);
	vec2 at = (square + vec2(d1, d2)) * spacing;
	vec2 off = at - eye.xz;
	float ring = max(abs(off.x), abs(off.y));
	float coming = hole > 0.0 ? smoothstep(hole * 0.8, hole, ring) : 1.0;
	float going = last_ring ? 0.0 : smoothstep(reach * 0.8, reach, ring);
	vec2 on_land = (at - land_rect.xy) * land_rect.zw;
	bool out_of_land = on_land.x < 0.0 || on_land.y < 0.0 || on_land.x > 1.0 || on_land.y > 1.0;
	vec3 corner = VERTEX;
	VERTEX = vec3(0.0, 0.0, 10.0);
	if (d3 < coming && d3 >= going && ring <= reach && !out_of_land) {
		vec4 map = textureLod(land_a, on_land, 0.0);
		float meadow = (1.0 - smoothstep(0.15, 0.5, map.b)) * (1.0 - smoothstep(0.2, 0.5, map.a));
		vec4 ways = textureLod(land_b, on_land, 0.0);
		float from_middle = ways.r * 16.0;
		float half_wide = ways.g * 4.0;
		float on_road = 1.0 - smoothstep(half_wide - 0.3, half_wide + 0.6, from_middle);
		meadow *= 1.0 - on_road;
		vec4 lie = textureLod(land_c, on_land, 0.0);
		ivec2 dims = textureSize(land_height, 0);
		vec2 f = (at - land_rect.xy) / land_cell;
		ivec2 c = clamp(ivec2(floor(f)), ivec2(0), dims - ivec2(2));
		vec2 t = clamp(f - vec2(c), vec2(0.0), vec2(1.0));
		float nw = texelFetch(land_height, c, 0).r;
		float ne = texelFetch(land_height, c + ivec2(1, 0), 0).r;
		float sw = texelFetch(land_height, c + ivec2(0, 1), 0).r;
		float se = texelFetch(land_height, c + ivec2(1, 1), 0).r;
		float ground = t.x >= t.y ? nw + (ne - nw) * t.x + (se - ne) * t.y : nw + (sw - nw) * t.y + (se - sw) * t.x;
		vec2 slope = vec2(ne - nw + se - sw, sw - nw + se - ne) * 0.5 / land_cell;
		float steep = length(slope);
		int cell;
		int top;
		float verge = half_wide > 0.0 ? 1.0 - smoothstep(half_wide + 2.5, half_wide + 5.0, from_middle) : 0.0;
		pick(at, square, map, lie, meadow * (1.0 - on_road), steep, verge, int(UV2.x), cell, top);
		bool lying = UV2.y > 0.5;
		if (lying) {
			cell = top;
		}
		if (cell >= 0) {
			vec4 rect = cells[cell];
			vec2 metres = cell_size[cell];
			float size = mix(0.8, 1.2, d4);
			if (last_ring) {
				size *= 1.0 - smoothstep(reach * 0.75, reach, ring);
			}
			vec2 scale = metres * grown * size;
			sky = map.g;
			shade = mix(0.85, 1.12, hash(square + 61.1));
			float turn = facing_eye ? atan(off.x, off.y) : d1 * 6.2831853;
			mat3 spin = mat3(vec3(cos(turn), 0.0, -sin(turn)), vec3(0.0, 1.0, 0.0), vec3(sin(turn), 0.0, cos(turn)));
			vec3 toward = normalize(vec3(at.x, ground + scale.y * 0.4, at.y) - eye);
			vec3 card_faces = spin * vec3(-TANGENT.z, 0.0, TANGENT.x);
			float down = abs(toward.y);
			float across = abs(dot(normalize(toward.xz + vec2(1e-4, 0.0)), card_faces.xz));
			float narrow = lying ? smoothstep(0.15, 0.4, down) : (facing_eye ? 1.0 : smoothstep(0.2, 0.5, across) * (1.0 - smoothstep(0.6, 0.85, down)));
			float close = smoothstep(0.3, 0.9, length(off));
			vec3 local = spin * (corner * vec3(scale.x * narrow, lying ? 0.2 * scale.x : scale.y * close, scale.x * narrow) * close);
			vec3 world = vec3(at.x, ground - 0.03 * scale.y, at.y) + local;
			world.y += dot(slope, local.xz);
			vec2 downwind = normalize(wind);
			float gust = 0.5 + 0.5 * sin(dot(world.xz, downwind) * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
			vec2 shiver = vec2(sin(TIME * 2.7 + d2 * 6.283), cos(TIME * 2.1 + d2 * 10.7)) * 0.3;
			vec2 push = (downwind * (0.25 + 0.75 * gust) + shiver * (0.4 + 0.6 * gust)) * sway * COLOR.r * scale.y;
			world += vec3(push.x, -0.35 * length(push), push.y);
			UV = mix(rect.xy, rect.zw, UV);
			VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
			vec3 normal = facing_eye ? vec3(0.0, 1.0, 0.0) : spin * NORMAL;
			NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
			TANGENT = normalize((VIEW_MATRIX * vec4(spin * TANGENT, 0.0)).xyz);
			BINORMAL = normalize((VIEW_MATRIX * vec4(spin * (lying ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0)), 0.0)).xyz);
		}
	}
}

void fragment() {
	vec4 leaf = texture(plants_tex, UV);
	float depth = -VERTEX.z;
	vec3 colour = leaf.rgb * COLOR.b * shade;
	ALBEDO = colour;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = mix(cut_near, cut_far, smoothstep(5.0, 30.0, depth));
	ROUGHNESS = 0.8;
	SPECULAR = 0.12;
	BACKLIGHT = colour * through * 2.0;
	AO = sky;
	AO_LIGHT_AFFECT = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float near = 1.0 - smoothstep(8.0, 14.0, depth);
	vec3 tilt = vec3(0.5, 0.5, 1.0);
	if (near > 0.0) {
		tilt = textureGrad(plants_normal, UV, dFdx(UV), dFdy(UV)).rgb;
	}
	NORMAL_MAP = tilt;
	NORMAL_MAP_DEPTH = near;
}
