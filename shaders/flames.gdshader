shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// A fire that keeps burning: balls of flame that rise from a patch around
// the origin of the burst along its +Y, burn out on the way up and start
// again at the bottom, each to a rhythm of its own. Upright on the floor
// that is burning fuel; with no patch to speak of, a long reach and a fast
// rhythm it is the jet from a punctured gas bottle.
//
// Given a box instead of a patch it is the fire on something that burns: a
// crate, a tower of them, a pile of pallets. A ball then starts somewhere on
// a side of the box or on its top, just outside the wood, licks up along the
// side and is drawn in over the top once it is past it.
//
// A ball is drawn the way the fire of an explosion is (see puff.gdshader):
// hottest where it is thickest, and gone first where it is thin. As it rises
// it is drawn out into a tongue that points the way it is going. It covers
// what is behind it instead of adding to it, so that it is as much a fire in
// a patch of sunlight as in a dark corner.
#include "fx_common.gdshaderinc"

// Three channels of tiling noise; the wear mask of the painted steel will do.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

instance uniform float start = -100.0;
// Seconds it burns. It flares up at once and dies down over the last of them.
instance uniform float life = 5.0;
// Radius of the patch it stands on, in metres.
instance uniform float radius = 0.5;
// Radius of a ball of flame at its largest, and how high the flames reach.
instance uniform vec2 size = vec2(0.3, 1.2);
// How many times a second a ball rises: 1.6 for a fire, more for a jet.
instance uniform float rush = 1.6;
instance uniform float amount = 1.0;
// The box that burns, in metres, standing on the origin of the burst: how
// wide, how high and how deep. Without a height the fire stands on the patch.
instance uniform vec3 box = vec3(0.0);
// How much of the fire stands on top of the box: none of it when something
// stands there that does not burn.
instance uniform float crown = 1.0;

varying vec3 random;
varying float course;
varying float strength;
// 1 for a flame on a box, 0 for one over a patch.
varying float licking;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	random = VERTEX * 0.5 + 0.5;
	float age = fx_time - start;
	float dying = min(1.5, life * 0.4);
	strength = smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(life - dying, life, age));

	// Every time round it starts from another spot on the patch.
	float turn = age * rush * (0.7 + 0.6 * random.y) + random.z;
	course = fract(turn);
	float round = floor(turn) + random.x * 31.0;

	mat3 frame = mat3(MODEL_MATRIX);
	vec3 up = normalize(frame[1]);
	float ball = size.x * (0.65 + 0.5 * hash(round + 0.13)) * smoothstep(0.0, 0.15, course) * mix(1.0, 0.4, course) * (0.5 + 0.5 * strength);
	float reach = size.y * (0.45 + 0.55 * hash(round + 0.71)) * strength;
	vec3 world = MODEL_MATRIX[3].xyz;
	licking = float(box.y > 0.0);
	if (box.y > 0.0) {
		vec3 across = normalize(frame[0]);
		vec3 along_it = normalize(frame[2]);
		vec2 half_box = box.xz * 0.5;
		// Where on the box it starts: `spot` on its plan and `foot` above its
		// underside, and `out_of` the way that side faces.
		vec2 spot = (vec2(hash(round), hash(round + 0.37)) - 0.5) * box.xz * 0.9;
		vec2 out_of = vec2(0.0);
		float foot = box.y;
		// The top gets its share of them by its area, and as much again and
		// more: that is where a fire stands highest.
		float sides = 2.0 * (box.x + box.z) * box.y;
		if (hash(round + 0.53) * (sides + box.x * box.z * 2.5 * crown) < sides) {
			// Once round the four sides.
			float around = hash(round) * 2.0 * (box.x + box.z);
			if (around < box.x) {
				spot = vec2(around - half_box.x, half_box.y);
				out_of = vec2(0.0, 1.0);
			} else if (around < box.x + box.z) {
				spot = vec2(half_box.x, around - box.x - half_box.y);
				out_of = vec2(1.0, 0.0);
			} else if (around < 2.0 * box.x + box.z) {
				spot = vec2(around - box.x - box.z - half_box.x, -half_box.y);
				out_of = vec2(0.0, -1.0);
			} else {
				spot = vec2(-half_box.x, around - 2.0 * box.x - box.z - half_box.y);
				out_of = vec2(-1.0, 0.0);
			}
			// Anywhere up the side, and most of them low down: a fire burns
			// from the bottom up.
			foot = box.y * hash(round + 0.37) * hash(round + 0.91);
		}
		float height = foot + ball * 0.5 + reach * course;
		// Half out of the wood while it is on a side; past the top it is
		// drawn in over the box, to where the others are.
		float past = max(height - box.y, 0.0);
		spot += out_of * (ball * 0.45 - min(past * 0.5, dot(abs(out_of), half_box) * 0.7));
		world += across * spot.x + along_it * spot.y + up * height;
	} else {
		float out_from = hash(round) * (1.0 - 0.6 * course);
		float bearing = hash(round + 0.37) * 6.2832;
		world += (frame[0] * cos(bearing) + frame[2] * sin(bearing)) * out_from * radius;
		// Taller in the middle of the patch than at its edge, and drawn
		// together as it rises.
		reach *= 1.0 - 0.5 * out_from;
		// It starts out resting on the patch, not halfway through it.
		world += up * (ball * 0.7 + reach * course);
	}

	vec3 view = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	// One right in front of the lens would wipe out the view.
	ball *= smoothstep(0.1, 0.45, -view.z);
	// The card stands along the way the flame goes, as seen from here, and
	// gets longer the further it has come.
	vec2 along = (VIEW_MATRIX * vec4(up, 0.0)).xy;
	along = length(along) > 0.01 ? normalize(along) : vec2(0.0, 1.0);
	vec2 corner = UV * 2.0 - 1.0;
	// Up the side of something it is drawn out further than over a patch.
	float drawn = 1.0 + 0.3 * licking;
	view.xy += (vec2(along.y, -along.x) * corner.x + along * corner.y * (1.0 + 1.3 * course) * drawn) * ball;
	VERTEX = view;
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (age < 0.0 || age > life || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Round at the bottom and drawn to a point at the top, more so the
	// further it has risen.
	p.x *= 1.0 + (0.4 + 1.6 * course) * (p.y * 0.5 + 0.5);
	float inside = max(1.0 - dot(p, p), 0.0);
	// The fire streams up through it.
	vec2 flow = vec2(0.0, fx_time * rush * 0.35);
	float billow = texture(noise, UV * vec2(0.4, 0.3) + random.xy * 7.0 - flow).r * 0.6 + texture(noise, UV * vec2(0.9, 0.6) + random.yz * 5.0 - flow * 1.7).b * 0.4;
	// A flame that licks along wood is more ragged than one over fuel: it is
	// only there where the fire is thick.
	float density = inside * inside * mix(0.2 + 2.4 * billow * billow, 3.6 * billow * billow, licking);
	// It cools as it rises; the thin parts go out first.
	float left = 1.0 - course;
	float heat = left * (0.3 + 0.7 * inside) * (0.2 + 2.6 * billow * billow) + left * left * left * 0.35;
	ALBEDO = vec3(1.0, 0.16, 0.02) * smoothstep(0.05, 0.4, heat) * 1.3 + vec3(1.0, 0.5, 0.1) * smoothstep(0.35, 0.85, heat) * 1.5 + vec3(1.0, 0.8, 0.5) * smoothstep(0.85, 1.4, heat) * 2.0;
	ALPHA = smoothstep(0.03, 0.3, density) * smoothstep(0.08, 0.35, heat) * smoothstep(0.0, 0.1, course) * 0.95;
}
