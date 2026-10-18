shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

// The grass of the meadows of the Alps, drawn round the eye (scripts/meadow.gd):
// every tuft is one of a MultiMesh whose transforms say nothing. Where a
// tuft stands the shader works out from its number: the grid of `spacing`
// metres round the eye, `columns` wide, a tuft in every square of it, shaken
// in the square by its own dice. Where the ring has a hole, the next ring in
// draws the grass, and where two rings meet the tufts of one give way to
// those of the other over a stretch, as many going as coming. A tuft stands
// on the ground as the land has it (land_height), and grows only where the
// land's map says it is meadow: not under the wood, not on rock.
//
// The cards and their picture are those of the fine grass of the dunes (see
// shaders/grass.gdshader and tools/render_grass.py), tinted to a meadow in
// October.

uniform float spacing = 0.5;
uniform int columns = 64;
uniform float hole = 0.0;
uniform float reach = 16.0;
uniform sampler2D land_height : filter_nearest, repeat_disable;
uniform sampler2D land_a : filter_linear, repeat_disable;
uniform sampler2D land_b : filter_linear, repeat_disable;
uniform vec4 land_rect = vec4(0.0);
uniform float land_cell = 2.0;

uniform sampler2D blades_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D blades_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.42, 0.72, 0.2);
uniform vec3 straw_tint : source_color = vec3(0.86, 0.72, 0.42);
uniform float cut_near : hint_range(0.0, 1.0) = 0.42;
uniform float cut_far : hint_range(0.0, 1.0) = 0.16;
uniform vec2 wind = vec2(0.6, 0.8);
uniform float sway = 0.08;
uniform float through : hint_range(0.0, 1.0) = 0.12;
// How large a tuft of the nearest ring is, in metres, the least and the most.
uniform vec2 size = vec2(0.32, 0.55);

varying float straw;
varying float sky;
// The strip of the floor it grows on, as the ground has it
// (shaders/alps_ground.gdshader): how lately it was mown.
varying float mown;
varying float on_floor;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The noise of the ground's strips, as shaders/alps_ground.gdshader has it.
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

float height_at(vec2 at) {
	ivec2 dims = textureSize(land_height, 0);
	vec2 f = (at - land_rect.xy) / land_cell;
	ivec2 c = clamp(ivec2(floor(f)), ivec2(0), dims - ivec2(2));
	vec2 t = clamp(f - vec2(c), vec2(0.0), vec2(1.0));
	float nw = texelFetch(land_height, c, 0).r;
	float ne = texelFetch(land_height, c + ivec2(1, 0), 0).r;
	float sw = texelFetch(land_height, c + ivec2(0, 1), 0).r;
	float se = texelFetch(land_height, c + ivec2(1, 1), 0).r;
	// The two triangles of each square, as the collider has them.
	if (t.x >= t.y) {
		return nw + (ne - nw) * t.x + (se - ne) * t.y;
	}
	return nw + (sw - nw) * t.y + (se - sw) * t.x;
}

void vertex() {
	vec3 eye = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	vec2 first = floor(eye.xz / spacing) - float(columns / 2);
	vec2 square = first + vec2(float(INSTANCE_ID % columns), float(INSTANCE_ID / columns));
	float d1 = hash(square);
	float d2 = hash(square + 17.31);
	float d3 = hash(square + 41.17);
	float d4 = hash(square + 73.9);
	vec2 at = (square + vec2(d1, d2)) * spacing;
	vec2 off = at - eye.xz;
	float ring = max(abs(off.x), abs(off.y));
	// Where two rings meet, a tuft goes or comes by its own dice.
	float coming = hole > 0.0 ? smoothstep(hole * 0.8, hole, ring) : 1.0;
	float going = smoothstep(reach * 0.8, reach, ring);
	float kept = (d3 < coming && d3 >= going) ? 1.0 : 0.0;
	vec2 on_land = (at - land_rect.xy) * land_rect.zw;
	vec4 map = textureLod(land_a, on_land, 0.0);
	float meadow = (1.0 - smoothstep(0.15, 0.5, map.b)) * (1.0 - smoothstep(0.2, 0.5, map.a));
	// None on a road, but along the middle of a track.
	vec4 ways = textureLod(land_b, on_land, 0.0);
	float from_middle = ways.r * 16.0;
	float half_wide = ways.g * 4.0;
	float on_road = 1.0 - smoothstep(half_wide - 0.3, half_wide + 0.3, from_middle);
	on_road *= 1.0 - (1.0 - smoothstep(0.2, 0.45, from_middle)) * step(half_wide, 1.9);
	meadow *= 1.0 - on_road;
	if (on_land.x < 0.0 || on_land.y < 0.0 || on_land.x > 1.0 || on_land.y > 1.0) {
		meadow = 0.0;
	}
	kept *= step(d4 * 0.9 + 0.05, meadow);
	float grown = mix(size.x, size.y, d4) * spacing / 0.26 * kept;
	straw = smoothstep(0.7, 1.0, hash(square + 5.3)) * 0.6 + smoothstep(0.5, 0.0, meadow) * 0.3;
	sky = map.g;
	on_floor = 1.0 - smoothstep(100.0, 140.0, height_at(at));
	float across_strips = (at.x + (fbm(at * 0.0025) - 0.5) * 70.0) / 31.0;
	float strip = floor(across_strips);
	mown = mix(fract(sin(strip * 12.9898) * 43758.5453), fract(sin((strip + 1.0) * 12.9898) * 43758.5453), smoothstep(0.93, 1.0, fract(across_strips)));
	float turn = d1 * 6.2831853;
	mat3 spin = mat3(vec3(cos(turn), 0.0, -sin(turn)), vec3(0.0, 1.0, 0.0), vec3(sin(turn), 0.0, cos(turn)));
	vec3 local = spin * (VERTEX * vec3(1.15, 0.7, 1.15)) * grown;
	vec3 world = vec3(at.x, height_at(at) - 0.03 * grown, at.y) + local;
	// Gusts run over the meadow with the wind, and every tuft shivers in
	// them at its own time.
	vec2 downwind = normalize(wind);
	float gust = 0.5 + 0.5 * sin(dot(world.xz, downwind) * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
	vec2 shiver = vec2(sin(TIME * 3.1 + d2 * 6.283), cos(TIME * 2.3 + d2 * 10.7)) * 0.3;
	vec2 push = (downwind * (0.25 + 0.75 * gust) + shiver * (0.4 + 0.6 * gust)) * sway * COLOR.r * grown;
	world += vec3(push.x, -0.35 * length(push), push.y);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(spin * NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 blade = texture(blades_tex, UV);
	float depth = -VERTEX.z;
	vec3 colour = blade.rgb * tint;
	colour = mix(colour, vec3(dot(blade.rgb, vec3(0.3, 0.6, 0.1))) * 2.0 * straw_tint, straw);
	colour *= COLOR.b;
	colour *= mix(1.0, mix(0.84, 1.12, mown), on_floor);
	colour = mix(colour, colour * vec3(1.12, 1.03, 0.72), smoothstep(0.72, 0.85, mown) * on_floor * 0.7);
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
