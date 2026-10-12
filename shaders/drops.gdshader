shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, specular_disabled;

// The drops a shot throws up out of a puddle: a crown that leaves the water
// along the +Y of the burst, up and out, and falls back. A drop is drawn as
// the streak it leaves in the time the eye holds it, so one on its way up or
// down is a short line and one at the top of its flight a bead. It is gone
// the moment it lands. Drops are lit like everything else: they shine in the
// light and are dark in a dark corner.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
// Height of the water they fall back into.
instance uniform float floor_y = -1000.0;
instance uniform vec3 tint : source_color = vec3(0.82, 0.87, 0.92);
// Speed of the fastest drop in m/s and how far from straight up they fan out.
instance uniform float speed = 4.5;
instance uniform float spread = 0.5;
// Width of the largest drop in metres, and the seconds of flight it is drawn
// out over: a moment for a drop, more for a jet that leaves in one piece.
instance uniform float size = 0.024;
instance uniform float trail = 0.013;
// Fraction of the drops in the mesh that fly.
instance uniform float amount = 1.0;

// Narrowest a drop gets, as a slope: about a pixel and a half at 1080p.
const float MIN_WIDTH = 0.0022;
// Seconds over which the drops leave the water, the fast ones first.
const float STAGGER = 0.04;
// Longest a drop is there, for one that finds no floor to land on.
const float LONGEST = 1.6;

varying float clear;

// Where something thrown from `from` at `velocity` is `t` seconds later.
vec3 flight(vec3 from, vec3 velocity, float t) {
	return from + velocity * t - vec3(0.0, 0.5 * GRAVITY * t * t, 0.0);
}

void vertex() {
	vec3 random = VERTEX * 0.5 + 0.5;
	float age = fx_time - start - (1.0 - random.y) * STAGGER;

	mat3 frame = mat3(MODEL_MATRIX);
	vec3 from = MODEL_MATRIX[3].xyz + frame[1] * 0.01;
	vec3 thrown = frame * cone(NORMAL, spread) * speed * (0.3 + 0.7 * random.y);
	// The moment it is back in the water.
	float landing = min((thrown.y + sqrt(thrown.y * thrown.y + 2.0 * GRAVITY * max(from.y - floor_y, 0.0))) / GRAVITY, LONGEST);
	vec3 head = (VIEW_MATRIX * vec4(flight(from, thrown, age), 1.0)).xyz;
	vec3 tail = (VIEW_MATRIX * vec4(flight(from, thrown, max(age - trail, 0.0)), 1.0)).xyz;
	// It thins out into the air over the last of its flight.
	clear = 1.0 - 0.6 * smoothstep(0.5, 1.0, age / landing);

	// The quad lies along the streak and is turned to face the eye.
	vec3 along = head - tail;
	float streak = length(along);
	along = streak > 0.0001 ? along / streak : vec3(0.0, 1.0, 0.0);
	vec3 across = normalize(cross(along, head) + vec3(0.00001, 0.0, 0.0));
	float width = max(size * (0.3 + 0.7 * random.z * random.z), -head.z * MIN_WIDTH);
	vec2 corner = UV - 0.5;
	VERTEX = mix(tail, head, UV.y) + (across * corner.x + along * corner.y) * width;
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (age < 0.0 || age > landing || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	// Round at the head, thinning out towards the tail.
	float shape = smoothstep(0.0, 0.75, across) * smoothstep(0.0, 0.6, UV.y) * smoothstep(1.0, 0.8, UV.y);
	ALBEDO = tint;
	ROUGHNESS = 1.0;
	ALPHA = shape * clear;
}

void light() {
	// A drop passes on the light that falls on it every way, whichever side
	// it comes from.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION / PI;
}
