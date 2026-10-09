shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// A fire that keeps burning: balls of flame that rise from a patch around
// the origin of the burst along its +Y, burn out on the way up and start
// again at the bottom, each to a rhythm of its own. Upright on the floor
// that is burning fuel; with no patch to speak of, a long reach and a fast
// rhythm it is the jet from a punctured gas bottle.
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

varying vec3 random;
varying float course;
varying float strength;

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
	float out_of = hash(round) * (1.0 - 0.6 * course);
	float bearing = hash(round + 0.37) * 6.2832;

	mat3 frame = mat3(MODEL_MATRIX);
	vec3 up = normalize(frame[1]);
	vec3 world = MODEL_MATRIX[3].xyz + (frame[0] * cos(bearing) + frame[2] * sin(bearing)) * out_of * radius;
	// Taller in the middle of the patch than at its edge, and drawn together
	// as it rises.
	float reach = size.y * (0.45 + 0.55 * hash(round + 0.71)) * (1.0 - 0.5 * out_of) * strength;
	float ball = size.x * (0.65 + 0.5 * hash(round + 0.13)) * smoothstep(0.0, 0.15, course) * mix(1.0, 0.4, course) * (0.5 + 0.5 * strength);
	// It starts out resting on the patch, not halfway through it.
	world += up * (ball * 0.7 + reach * course);

	vec3 view = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	// One right in front of the lens would wipe out the view.
	ball *= smoothstep(0.1, 0.45, -view.z);
	// The card stands along the way the flame goes, as seen from here, and
	// gets longer the further it has come.
	vec2 along = (VIEW_MATRIX * vec4(up, 0.0)).xy;
	along = length(along) > 0.01 ? normalize(along) : vec2(0.0, 1.0);
	vec2 corner = UV * 2.0 - 1.0;
	view.xy += (vec2(along.y, -along.x) * corner.x + along * corner.y * (1.0 + 1.3 * course)) * ball;
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
	float density = inside * inside * (0.2 + 2.4 * billow * billow);
	// It cools as it rises; the thin parts go out first.
	float left = 1.0 - course;
	float heat = left * (0.3 + 0.7 * inside) * (0.2 + 2.6 * billow * billow) + left * left * left * 0.35;
	ALBEDO = vec3(1.0, 0.16, 0.02) * smoothstep(0.05, 0.4, heat) * 1.3 + vec3(1.0, 0.5, 0.1) * smoothstep(0.35, 0.85, heat) * 1.5 + vec3(1.0, 0.8, 0.5) * smoothstep(0.85, 1.4, heat) * 2.0;
	ALPHA = smoothstep(0.03, 0.3, density) * smoothstep(0.08, 0.35, heat) * smoothstep(0.0, 0.1, course) * 0.95;
}
