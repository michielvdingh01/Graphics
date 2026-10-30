shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front;

// The cloud of a smoke grenade: 8 m of smoke that stands for a quarter of a
// minute, and that whoever throws it can stand in. Cards as in smoke.gdshader
// would have to fill the picture many times over to hide what is behind
// them, so this is one ball that the eye looks into: every pixel walks its own
// line through the smoke, from the front of the ball to the back of it or to
// whatever of the level is in the way, and stops as soon as it can see no
// further. That is one layer on the screen, inside the cloud or outside it,
// and it comes up to the floor and to the people in it without an edge.
//
// Like the rest of the effects it follows from its age alone. scripts/smoke.gd
// asks the same questions of the same numbers to know what can be seen.
#include "fx_common.gdshaderinc"

// Tiling noise: billows in red, fine grain in green. tools/gen_smoke_noise.gd.
uniform sampler3D noise : filter_linear, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

instance uniform float start = -100.0;
// Seconds it lasts, of which the last `thins` it takes to go.
instance uniform float life = 20.0;
instance uniform float thins = 6.0;
// How far out it comes at its fullest in metres, how high that is as a share
// of that, and how quickly it gets there per second.
instance uniform float radius = 4.0;
instance uniform float high = 0.8;
instance uniform float grows = 1.1;
// Less than none leaves it out, see Fx.rehearse().
instance uniform float amount = 1.0;
// Colour of the smoke, and the light it hangs in as Fx.smoke_light() says.
instance uniform vec3 tint : source_color = vec3(0.56);
instance uniform vec3 key = vec3(0.0, 1.0, 0.0);
instance uniform vec3 key_light = vec3(2.0);
instance uniform vec3 fill = vec3(0.5);

// How large it is when it starts, as a share of its fullest.
const float SEED = 0.1;
// Metres per second the whole cloud rises as it goes.
const float RISE = 0.06;
// How many stops a pixel makes at most on its way to the smoke, how many it
// then takes to find where the smoke begins, and how many it makes in it, the
// first this many metres in and each further on by this share. So that a
// pixel lands on the same spot of a billow from frame to frame: stops that
// fall anywhere show as grain.
const int STOPS = 18;
const int FINDS = 3;
const int INSIDE = 7;
const float FIRST = 0.14;
const float FURTHER = 1.45;
// How thick the smoke is per metre.
const float THICK = 3.5;
// A pixel stops once it sees no more than this of what is behind.
const float ENOUGH = 0.985;
// Metres in front of the eye that are left clear: what is held in the hands
// stays in view, in the middle of a cloud too.
const float CLEAR = 0.75;
// How far out of its round the smoke can come, as a share of its radius.
const float BOUND = 1.3;
// It lies wider along the floor: by this share, up to about this many metres.
const float SKIRT = 0.18;
const float SKIRT_HIGH = 1.0;
// How far the billows and the grain push the edge in and out, and how wide
// the edge is, all in terms of the round shape: 1 in the middle, 0 at the rim.
const float LUMPS = 1.5;
const float FRAYED = 0.8;
const float EDGE = 0.3;
// Past this it is deep inside, and there is nothing to read.
const float DEEP = 1.1;
// How many times the noise goes round per metre.
const float BILLOWS = 0.11;
const float GRAIN = 0.31;
// Metres per second the billows and the grain roll upwards through the cloud.
const float ROLL = 0.28;
const float CHURN = 0.5;
// The light on the side away from the key light, and how much of the light
// from all around is left underneath.
const float KEY_THROUGH = 0.55;
const float FILL_UNDER = 0.6;
// How far up and towards the key light a spot looks to know which way it
// faces, in metres, and how much that counts.
const float RELIEF_REACH = 0.6;
const float RELIEF = 2.4;

varying flat vec3 centre;
varying flat float reach;
varying flat float bound;
varying flat float left;
varying flat float roll;

// Where `p`, in metres from the middle, lies in the smoke: over nought it is
// in it, and the further over the deeper.
float depth_in(vec3 p, float out_to, float height, float eaten, float rolled) {
	vec3 q = p / vec3(out_to, out_to * height, out_to);
	q.xz /= 1.0 + SKIRT * exp(-max(p.y, 0.0) / SKIRT_HIGH);
	float body = 1.0 - dot(q, q) - eaten;
	if (body > -LUMPS * 0.5 && body < DEEP) {
		body += (texture(noise, p * BILLOWS + vec3(0.0, -rolled, 0.0)).r - 0.45) * LUMPS;
		if (abs(body) < FRAYED) {
			body += (texture(noise, p * GRAIN + vec3(0.0, -rolled * CHURN, 0.0)).g - 0.5) * FRAYED;
		}
	}
	return body;
}

void vertex() {
	float since = max(fx_time - start, 0.0);
	float grown = SEED + (1.0 - SEED) * (1.0 - exp(-grows * since));
	reach = radius * grown;
	// What the smoke loses as it goes: first the edges, then the rest.
	left = 1.0 - smoothstep(life - thins, life, since);
	bound = reach * BOUND;
	centre = MODEL_MATRIX[3].xyz + vec3(0.0, RISE * since, 0.0);
	roll = ROLL * BILLOWS * since;
	VERTEX = VERTEX * bound + vec3(0.0, RISE * since, 0.0);
	if (amount < 0.0 || since > life) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec3 ray = normalize(mat3(INV_VIEW_MATRIX) * VERTEX);
	vec3 eye = INV_VIEW_MATRIX[3].xyz - centre;
	float along = dot(eye, ray);
	float root = sqrt(max(along * along - dot(eye, eye) + bound * bound, 0.0));
	float near = max(-along - root, CLEAR);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_texture, SCREEN_UV).r, 1.0);
	float far = min(-along + root, length(scene.xyz / scene.w));
	if (far <= near) {
		discard;
	}
	float eaten = (1.0 - left) * 1.6;
	float thick = THICK * left * left;
	// Up to the smoke, a little further along for each pixel so that what is
	// thin does not come out in bands.
	float stride = (far - near) / float(STOPS);
	float at = near + stride * 0.5 * fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float before = near;
	float body = depth_in(eye + ray * at, reach, high, eaten, roll);
	for (int i = 1; i < STOPS && body <= 0.0 && at < far; i++) {
		before = at;
		at += stride;
		body = depth_in(eye + ray * at, reach, high, eaten, roll);
	}
	if (body <= 0.0) {
		discard;
	}
	// Then back to where it begins, unless the eye is in it.
	if (at > near) {
		for (int i = 0; i < FINDS; i++) {
			float middle = 0.5 * (before + at);
			if (depth_in(eye + ray * middle, reach, high, eaten, roll) > 0.0) {
				at = middle;
			} else {
				before = middle;
			}
		}
	}
	// Which way the smoke faces there, for the whole of this pixel: where it is
	// thinner up and towards the key light, the light gets to it.
	vec3 p = eye + ray * at;
	float lean = RELIEF * (depth_in(p, reach, high, eaten, roll) - depth_in(p + normalize(key + vec3(0.0, 1.0, 0.0)) * RELIEF_REACH, reach, high, eaten, roll));
	float towards = dot(p, key) / reach;
	float up = clamp(p.y / (reach * high), 0.0, 1.0);
	vec3 light = key_light * mix(KEY_THROUGH, 1.0, smoothstep(-0.9, 0.7, towards + lean))
			+ fill * mix(FILL_UNDER, 1.0, clamp(up + lean * 0.5, 0.0, 1.0));
	// And in, for as far as it takes to see nothing more.
	float seen = 0.0;
	float pace = FIRST;
	for (int i = 0; i < INSIDE && seen < ENOUGH && at < far; i++) {
		float next = min(at + pace, far);
		float density = smoothstep(0.0, EDGE, depth_in(eye + ray * next, reach, high, eaten, roll));
		seen += (1.0 - seen) * (1.0 - exp(-density * thick * (next - at)));
		at = next;
		pace *= FURTHER;
	}
	ALBEDO = tint * light;
	ALPHA = seen;
}
