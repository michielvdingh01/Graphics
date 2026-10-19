shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

// The grass of the meadows of the Alps, drawn round the eye (scripts/meadow.gd):
// every tuft is one of a MultiMesh whose transforms say nothing. The rings
// round the eye are cut into tiles, each a square of `columns` by `columns`
// squares of `spacing` metres, and a tile stands where its first square is
// (MODEL_MATRIX): a tuft in every square of it, shaken in the square by its
// own dice. The rest the shader works out from where the tuft stands.
//
// What grows there it reads from the maps of the land: meadow, not under
// the wood and not on rock or a road (land_a, land_b), and which of three
// grasses (land_c): the mown meadow, short and green; the long grass nobody
// cut, knee high, gone to seed and straw, along ditches, fences, barns, the
// edge of the wood and on the steep; and the wet grass of the Moos, sedge,
// rush and moor grass gone gold. Where two kinds meet, a tuft is one or the
// other by its own dice.
//
// Where two rings meet the tufts of one give way to those of the other over
// a stretch, as many going as coming; the last ring shrinks into the ground
// instead. The pictures are those of tools/gen_plants.py (alps_meadow): four
// of each kind for up close, and a band of each for afar.

// Where the tile is and what the ring is like.
uniform float spacing = 0.5;
uniform int columns = 14;
uniform float hole = 0.0;
uniform float reach = 16.0;
// The last ring has nothing beyond it to hand over to: it sinks into the
// ground over its outer fifth.
uniform bool last_ring = false;
// A card that turns to whoever looks, for afar; otherwise the cards of a tuft
// stand at their own angle.
uniform bool facing_eye = false;
// Which pictures: those for up close, or the bands for afar.
uniform bool far_cells = false;
// How much wider and higher than its picture a tuft of this ring is.
uniform vec2 grown = vec2(1.0, 1.0);
// How many of the tufts of each kind this ring keeps: long grass and rushes
// are larger and fewer.
uniform vec3 keep = vec3(1.0, 0.5, 0.6);

uniform sampler2D land_height : filter_nearest, repeat_disable;
uniform sampler2D land_a : filter_linear, repeat_disable;
uniform sampler2D land_b : filter_linear, repeat_disable;
// What grows where on the meadow, each 0 to 1: red long grass, green wet,
// blue trampled or path, alpha the edge of the wood.
uniform sampler2D land_c : filter_linear, repeat_disable;
uniform vec4 land_rect = vec4(0.0);
uniform float land_cell = 2.0;
// The noise the ground's strips are drawn with (shaders/alps_ground.gdshader).
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform sampler2D blades_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D blades_normal : hint_normal, filter_linear_mipmap, repeat_disable;
// Where on the sheet every picture is (left, top, right, bottom) and how many
// metres it shows: mown 0 to 3, mown from above 4 to 7, long 8 to 11, wet 12
// to 15, the bands 16 to 19 (mown, long, wet, trampled). meadow.gd reads them
// from alps_meadow.json.
uniform vec4 cells[20];
uniform vec2 cell_size[20];
// The colour of each kind is that of its picture times this.
uniform vec3 mown_tint : source_color = vec3(0.86, 0.9, 0.86);
uniform vec3 long_tint : source_color = vec3(1.0);
uniform vec3 wet_tint : source_color = vec3(1.0);
uniform vec3 straw_tint : source_color = vec3(0.86, 0.72, 0.42);
uniform float cut_near : hint_range(0.0, 1.0) = 0.42;
uniform float cut_far : hint_range(0.0, 1.0) = 0.2;
uniform vec2 wind = vec2(0.6, 0.8);
uniform float sway = 0.1;
uniform float through : hint_range(0.0, 1.0) = 0.14;

varying flat int kind;
// How high up its card a dot is, 0 at the foot and 1 at the top.
varying float up_card;
varying float straw;
varying float sky;
varying float shade;
// The strip of the floor it grows on, as the ground has it: how lately it
// was mown.
varying float mown;
varying float on_floor;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fbm(vec2 p) {
	return 0.468 + (textureLod(noise_tex, p * (1.0 / 64.0), 0.0).r - 0.497) * 0.94;
}

void vertex() {
	vec3 eye = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	vec2 square = round(MODEL_MATRIX[3].xz / spacing) + vec2(float(INSTANCE_ID % columns), float(INSTANCE_ID / columns));
	float d1 = hash(square);
	float d2 = hash(square + 17.31);
	float d3 = hash(square + 41.17);
	float d4 = hash(square + 73.9);
	float d5 = hash(square + 5.3);
	vec2 at = (square + vec2(d1, d2)) * spacing;
	vec2 off = at - eye.xz;
	float ring = max(abs(off.x), abs(off.y));
	// Where two rings meet, a tuft goes or comes by its own dice.
	float coming = hole > 0.0 ? smoothstep(hole * 0.8, hole, ring) : 1.0;
	float going = last_ring ? 0.0 : smoothstep(reach * 0.8, reach, ring);
	vec2 on_land = (at - land_rect.xy) * land_rect.zw;
	bool out_of_land = on_land.x < 0.0 || on_land.y < 0.0 || on_land.x > 1.0 || on_land.y > 1.0;
	// Not this ring's, or no grass: nothing to draw.
	vec3 corner = VERTEX;
	VERTEX = vec3(0.0, 0.0, 10.0);
	if (d3 < coming && d3 >= going && ring <= reach && !out_of_land) {
		vec4 map = textureLod(land_a, on_land, 0.0);
		float meadow = (1.0 - smoothstep(0.15, 0.5, map.b)) * (1.0 - smoothstep(0.2, 0.5, map.a));
		// None on a road, but along the middle of a track.
		vec4 ways = textureLod(land_b, on_land, 0.0);
		float from_middle = ways.r * 16.0;
		float half_wide = ways.g * 4.0;
		float on_road = 1.0 - smoothstep(half_wide - 0.3, half_wide + 0.3, from_middle);
		on_road *= 1.0 - (1.0 - smoothstep(0.2, 0.45, from_middle)) * step(half_wide, 1.9);
		meadow *= 1.0 - on_road;
		vec4 lie = textureLod(land_c, on_land, 0.0);

		// How high the ground is, and how steep: the two triangles of each square,
		// as the collider has them.
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

		// Which grass: wet where the map says so, long where it says so, at the
		// edge of the wood and on the steep, mown elsewhere. Where one gives
		// way to another it does so in patches of a few metres, ragged at
		// their rim.
		float wet = lie.g;
		float long_grass = max(max(lie.r, lie.a * 0.85), smoothstep(0.45, 0.8, steep));
		float trodden = lie.b;
		float wet_here = wet + (fbm(at * 0.22 + 31.0) - 0.47) * 0.75 + (hash(square + 91.7) - 0.5) * 0.25;
		float long_here = long_grass + (fbm(at * 0.27 + 77.0) - 0.47) * 0.75 + (hash(square + 13.9) - 0.5) * 0.25;
		kind = wet_here > 0.5 ? 2 : (long_here > 0.5 ? 1 : 0);
		// Long grass thins out where the meadow ends: a tuft is a smaller share
		// of a full one there.
		float kept_share = kind == 0 ? keep.x : (kind == 1 ? keep.y : keep.z);
		if (d4 * 0.9 + 0.05 <= meadow && hash(square + 33.3) <= kept_share * (1.0 - 0.75 * trodden)) {
			// The cards of a tuft each show another of the four pictures of its
			// kind; from afar one card shows the band of it. The card that lies
			// in the grass shows the mown meadow from above, and is only there.
			bool lying = UV2.y > 0.5;
			int variant = (int(d5 * 4.0) + int(UV2.x)) % 4;
			// The mown meadow's third picture is a patch gone yellow: only a
			// tuft here and there shows it.
			if (kind == 0) {
				variant = (int(d5 * 3.0) + int(UV2.x)) % 3;
				variant = variant == 2 ? 3 : variant;
				if (hash(square + 7.7) > 0.94 && int(UV2.x) == 0) {
					variant = 2;
				}
			}
			int cell = far_cells ? 16 + kind : (kind == 0 ? 0 : kind * 4 + 4) + variant;
			if (far_cells && trodden > 0.5 && kind == 0) {
				cell = 19;
			}
			if (lying) {
				cell = 4 + variant;
			}
			vec4 rect = cells[cell];
			vec2 metres = cell_size[cell];
			float size = mix(0.75, 1.2, d4) * mix(1.0, 0.55, trodden);
			// Where the meadow peters out the grass is lower.
			size *= mix(0.6, 1.0, smoothstep(0.2, 0.7, meadow));
			if (last_ring) {
				size *= 1.0 - smoothstep(reach * 0.72, reach * 0.97, ring);
			}
			vec2 scale = metres * grown * size;
			// A tuft of the mown meadow is narrower than its picture: wider
			// than high, it would look like a plank from above.
			if (kind == 0 && !far_cells) {
				scale.x *= 0.65;
			}
			if (lying) {
				// As wide as its picture, and as high in the grass as the
				// pictures of the mown meadow are tall.
				scale.y = cell_size[0].y * grown.y * size * (kind == 0 ? 1.0 : 0.0);
				scale.x *= kind == 0 ? 1.0 : 0.0;
			}
			straw = smoothstep(0.85, 1.0, hash(square + 7.7)) * 0.35 + smoothstep(0.5, 0.0, meadow) * 0.3;
			sky = map.g;
			shade = mix(0.88, 1.1, hash(square + 61.1));
			on_floor = 1.0 - smoothstep(100.0, 140.0, ground);
			float across_strips = (at.x + (fbm(at * 0.0025) - 0.5) * 70.0) / 31.0;
			float strip = floor(across_strips);
			mown = mix(fract(sin(strip * 12.9898) * 43758.5453), fract(sin((strip + 1.0) * 12.9898) * 43758.5453), smoothstep(0.93, 1.0, fract(across_strips)));

			// A tuft stands at an angle of its own, or turns to the eye.
			float turn = facing_eye ? atan(off.x, off.y) : d1 * 6.2831853;
			mat3 spin = mat3(vec3(cos(turn), 0.0, -sin(turn)), vec3(0.0, 1.0, 0.0), vec3(sin(turn), 0.0, cos(turn)));
			// A card seen on its edge, or from straight above, shows its blades
			// squashed into streaks: it narrows as it turns away, and the one
			// that lies in the grass narrows as the eye comes down to it.
			vec3 toward = normalize(vec3(at.x, ground + scale.y * 0.4, at.y) - eye);
			vec3 card_faces = spin * vec3(-TANGENT.z, 0.0, TANGENT.x);
			float down = abs(toward.y);
			float across = abs(dot(normalize(toward.xz + vec2(1e-4, 0.0)), card_faces.xz));
			float narrow = lying ? smoothstep(0.2, 0.5, down) : (facing_eye ? 1.0 : smoothstep(0.2, 0.5, across) * (1.0 - smoothstep(0.55, 0.8, down)));
			// What stands right at the eye bows away, or a blade would fill the
			// picture.
			float close = smoothstep(0.35, 1.1, length(off));
			vec3 local = spin * (corner * vec3(scale.x * narrow, scale.y * close, scale.x * narrow) * close);
			// Its cards lean with the slope where they meet it, so that on a
			// hillside no card stands on air or sinks into the ground.
			vec3 world = vec3(at.x, ground - 0.03 * scale.y, at.y) + local;
			world.y += dot(slope, local.xz);
			// Gusts run over the meadow with the wind, and every tuft shivers in
			// them at its own time; long grass bends further than short.
			vec2 downwind = normalize(wind);
			float gust = 0.5 + 0.5 * sin(dot(world.xz, downwind) * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
			vec2 shiver = vec2(sin(TIME * 3.1 + d2 * 6.283), cos(TIME * 2.3 + d2 * 10.7)) * 0.3;
			vec2 push = (downwind * (0.25 + 0.75 * gust) + shiver * (0.4 + 0.6 * gust)) * sway * COLOR.r * scale.y;
			world += vec3(push.x, -0.35 * length(push), push.y);
			up_card = 1.0 - UV.y;
			UV = mix(rect.xy, rect.zw, UV);
			VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
			// Lit as the ground is, tipped a little the way the card faces: from
			// afar it is then the colour of the ground under it. Which way the
			// picture's right and up are, for which way its blades face.
			vec3 normal = facing_eye ? vec3(0.0, 1.0, 0.0) : spin * NORMAL;
			NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
			TANGENT = normalize((VIEW_MATRIX * vec4(spin * TANGENT, 0.0)).xyz);
			BINORMAL = normalize((VIEW_MATRIX * vec4(spin * (lying ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0)), 0.0)).xyz);
		}
	}
}

void fragment() {
	vec4 blade = texture(blades_tex, UV);
	float depth = -VERTEX.z;
	vec3 colour = blade.rgb * (kind == 0 ? mown_tint : (kind == 1 ? long_tint : wet_tint));
	if (kind == 0) {
		colour = mix(colour, vec3(dot(blade.rgb, vec3(0.3, 0.6, 0.1))) * 2.0 * straw_tint, straw);
		colour *= mix(1.0, mix(0.84, 1.12, mown), on_floor);
		colour = mix(colour, colour * vec3(1.12, 1.03, 0.72), smoothstep(0.72, 0.85, mown) * on_floor * 0.7);
	}
	colour *= COLOR.b * shade;
	// A band for afar is dense, and was rendered dark at its foot; from afar
	// its foot is as light as the ground it stands in.
	if (far_cells) {
		colour *= mix(1.0, 1.7, smoothstep(0.45, 0.0, up_card));
	}
	ALBEDO = colour;
	ALPHA = blade.a;
	ALPHA_SCISSOR_THRESHOLD = mix(cut_near, cut_far, smoothstep(5.0, 40.0, depth));
	// Blades are dull: against the low sun a shine on them would turn the
	// meadow white.
	ROUGHNESS = 0.9;
	SPECULAR = 0.08;
	BACKLIGHT = colour * through * 2.0;
	AO = sky;
	AO_LIGHT_AFFECT = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float near = 1.0 - smoothstep(10.0, 16.0, depth);
	vec3 tilt = vec3(0.5, 0.5, 1.0);
	if (near > 0.0) {
		tilt = textureGrad(blades_normal, UV, dFdx(UV), dFdy(UV)).rgb;
	}
	NORMAL_MAP = tilt;
	NORMAL_MAP_DEPTH = near;
}
