shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

// Glass that breaks: thin shards that leave along the +Y of the burst, turn
// over as they fall, bounce and lie on the floor for a while before they are
// cleared away. A shard is all but clear, and what makes it glass is that it
// flashes whenever it turns its face to the light.
//
// The glass of a lamp bursts from one point. A pane of a window comes apart
// as the sheet it was: its shards start out all over it, lying in it.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
instance uniform float floor_y = -1000.0;
instance uniform vec3 tint : source_color = vec3(0.78, 0.88, 0.9);
instance uniform float speed = 3.0;
instance uniform float spread = 0.8;
// Longest side of the largest shard in metres.
instance uniform float size = 0.05;
instance uniform float amount = 1.0;
// The sides of the pane the shards start out in, in metres along the X and
// the Z of the burst; nothing for glass that bursts from one point.
instance uniform vec2 area = vec2(0.0);
// How many shards the mesh of the burst has: what a pane needs to know to
// spread them evenly.
uniform float pieces = 24.0;

// Seconds a shard is there, most of which a lamp under a high roof needs to
// reach the floor.
const float LINGER = 4.0;
// How many times longer than wide a shard is.
const float SLENDER = 1.6;
// Where the light comes from that a shard flashes in: the roof, more or less.
const vec3 SHINE = vec3(0.26, 0.93, 0.26);

varying float glint;

void vertex() {
	vec3 random = VERTEX * 0.5 + 0.5;
	float age = fx_time - start;
	float span = LINGER * (0.7 + 0.3 * random.x);

	mat3 frame = mat3(MODEL_MATRIX);
	float scale = size * (0.3 + 0.7 * random.z * random.z) * (1.0 - smoothstep(span - 0.4, span, age));
	vec3 velocity = frame * cone(NORMAL, spread) * speed * (0.15 + 0.85 * random.y * random.y);
	// Where in the pane a shard starts: each one a step on from the one
	// before, in a row that never comes back to where it has been, so that
	// the first few of them are spread over the pane as evenly as all.
	vec2 spot = fract(UV2.x * pieces * vec2(0.7548776662, 0.5698402910)) - 0.5;
	vec3 from = MODEL_MATRIX[3].xyz + frame[1] * 0.02 + frame[0] * spot.x * area.x + frame[2] * spot.y * area.y;
	float air;
	vec3 center = ballistic(from, velocity, age, floor_y + scale * 0.1, 0.25, air);

	// A shard turns about its own long axis for as long as it is in the air.
	vec3 axis = NORMAL;
	vec3 side = normalize(cross(axis, vec3(0.31, 0.87, 0.38)));
	float angle = air * (6.0 + 24.0 * UV2.y) + random.x * 6.28;
	if (area.x + area.y > 0.0) {
		// A piece of a pane is larger and turns more slowly, and it starts
		// out flat in the pane.
		vec3 through = normalize(cross(frame[2], frame[0]));
		axis = normalize(frame[0] * NORMAL.x + frame[2] * (NORMAL.z + 0.001));
		side = cross(through, axis);
		angle = air * (2.0 + 9.0 * UV2.y);
		// One that passes right in front of the lens would wipe out the view.
		scale *= smoothstep(0.1, 0.6, -(VIEW_MATRIX * vec4(center, 1.0)).z);
	}
	side = side * cos(angle) + cross(axis, side) * sin(angle);
	vec2 corner = UV - 0.5;
	// One corner is pulled in, which leaves a splinter with three corners or
	// a blunt one with four.
	corner *= 1.0 - (0.5 + 0.5 * random.y) * step(0.5, UV.x) * step(0.5, UV.y);
	vec3 face = cross(axis, side);
	vec3 world = center + (axis * corner.x + side * corner.y / SLENDER) * scale;
	glint = pow(abs(dot(face, SHINE)), 10.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * face);
	if (age < 0.0 || age > span || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.08;
	EMISSION = tint * glint * 0.8;
	// A piece of a pane has the dirt of years on it.
	float clear = area.x + area.y > 0.0 ? 0.5 : 0.3;
	ALPHA = clear + (1.0 - clear) * glint;
}
