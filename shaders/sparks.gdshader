shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// Sparks struck off steel: glowing specks that fly out from the surface along
// its +Y, fall, bounce off the floor and cool from white through orange to a
// dull red. Each is drawn as the streak it leaves in the time the eye holds
// it, so a fast one is a line and one that has come to rest is a dot.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
instance uniform float floor_y = -1000.0;
instance uniform vec3 tint : source_color = vec3(1.0, 0.5, 0.15);
// Speed of the fastest spark in m/s, how far from the normal they fan out
// and how long the longest-lived one glows.
instance uniform float speed = 7.0;
instance uniform float spread = 0.7;
instance uniform float life = 0.6;
// Fraction of the sparks in the mesh that fly.
instance uniform float amount = 1.0;

// Seconds of flight a streak covers, and its width in metres.
const float TRAIL = 0.03;
const float WIDTH = 0.007;
// Narrowest a streak gets, as a slope: about a pixel and a half at 1080p.
const float MIN_WIDTH = 0.0022;

varying float heat;

void vertex() {
	vec3 random = VERTEX * 0.5 + 0.5;
	float age = fx_time - start;
	float span = life * (0.25 + 0.75 * random.x * random.x);
	heat = 1.0 - age / span;

	mat3 frame = mat3(MODEL_MATRIX);
	vec3 from = MODEL_MATRIX[3].xyz + frame[1] * 0.01;
	vec3 thrown = frame * cone(NORMAL, spread) * speed * (0.2 + 0.8 * random.y);
	float air;
	vec3 velocity = thrown;
	vec3 head = (VIEW_MATRIX * vec4(ballistic(from, velocity, age, floor_y, 0.4, air), 1.0)).xyz;
	velocity = thrown;
	vec3 tail = (VIEW_MATRIX * vec4(ballistic(from, velocity, max(age - TRAIL, 0.0), floor_y, 0.4, air), 1.0)).xyz;

	// The quad lies along the streak and is turned to face the eye.
	vec3 along = head - tail;
	float streak = length(along);
	along = streak > 0.0001 ? along / streak : vec3(0.0, 1.0, 0.0);
	vec3 across = normalize(cross(along, head) + vec3(0.00001, 0.0, 0.0));
	float width = max(WIDTH, -head.z * MIN_WIDTH);
	vec2 corner = UV - 0.5;
	VERTEX = mix(tail, head, UV.y) + (across * corner.x + along * corner.y) * width;
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (age < 0.0 || age > span || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	// Brightest at the head, thinning out to nothing at the tail.
	float shape = smoothstep(0.0, 0.7, across) * smoothstep(0.0, 0.9, UV.y) * smoothstep(1.0, 0.92, UV.y);
	vec3 glow = mix(tint * vec3(0.9, 0.35, 0.2), mix(tint, vec3(1.0, 0.92, 0.75), heat * heat), smoothstep(0.0, 0.5, heat));
	ALBEDO = glow * mix(1.5, 26.0, heat * heat);
	ALPHA = shape * smoothstep(0.0, 0.15, heat);
}
