shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

// The glass of a lamp that is shot out: thin shards that leave along the +Y
// of the burst, turn over as they fall, bounce and lie on the floor for a
// while before they are cleared away. A shard is all but clear, and what
// makes it glass is that it flashes whenever it turns its face to the light.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
instance uniform float floor_y = -1000.0;
instance uniform vec3 tint : source_color = vec3(0.78, 0.88, 0.9);
instance uniform float speed = 3.0;
instance uniform float spread = 0.8;
// Longest side of the largest shard in metres.
instance uniform float size = 0.05;
instance uniform float amount = 1.0;

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
	float air;
	vec3 center = ballistic(MODEL_MATRIX[3].xyz + frame[1] * 0.02, velocity, age, floor_y + scale * 0.1, 0.25, air);

	// A shard turns about its own long axis for as long as it is in the air.
	vec3 axis = NORMAL;
	vec3 side = normalize(cross(axis, vec3(0.31, 0.87, 0.38)));
	float angle = air * (6.0 + 24.0 * UV2.y) + random.x * 6.28;
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
	ALPHA = 0.3 + 0.7 * glint;
}
