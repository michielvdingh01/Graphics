shader_type spatial;
render_mode cull_disabled, skip_vertex_transform, specular_disabled;

// Chips knocked out of whatever a shot hits: concrete, brick, splinters of
// wood. Small tumbling flakes that fly out along the +Y of the burst, bounce
// and lie on the floor for a while before they are cleared away.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
instance uniform float floor_y = -1000.0;
instance uniform vec3 tint : source_color = vec3(0.62, 0.6, 0.57);
instance uniform float speed = 4.5;
instance uniform float spread = 0.8;
// Longest side of the largest chip in metres, and how many times longer than
// wide a chip is: 1 for a flake of stone, more for a splinter.
instance uniform float size = 0.02;
instance uniform float slender = 1.0;
instance uniform float amount = 1.0;

// Seconds a chip lies about.
const float LINGER = 2.5;

varying float shade;

void vertex() {
	vec3 random = VERTEX * 0.5 + 0.5;
	float age = fx_time - start;
	float span = LINGER * (0.7 + 0.3 * random.x);
	shade = 0.65 + 0.7 * random.z;

	mat3 frame = mat3(MODEL_MATRIX);
	float scale = size * (0.3 + 0.7 * random.z * random.z) * (1.0 - smoothstep(span - 0.4, span, age));
	vec3 velocity = frame * cone(NORMAL, spread) * speed * (0.15 + 0.85 * random.y * random.y);
	float air;
	vec3 center = ballistic(MODEL_MATRIX[3].xyz + frame[1] * 0.02, velocity, age, floor_y + scale * 0.3, 0.3, air);

	// A flake spins about its own long axis for as long as it is in the air.
	vec3 axis = NORMAL;
	vec3 side = normalize(cross(axis, vec3(0.31, 0.87, 0.38)));
	float angle = air * (8.0 + 30.0 * UV2.y) + random.x * 6.28;
	side = side * cos(angle) + cross(axis, side) * sin(angle);
	vec2 corner = UV - 0.5;
	// One corner is pulled in, some of the way or all of it, so that no two
	// chips have the same outline.
	corner *= 1.0 - (0.4 + 0.6 * random.y) * step(0.5, UV.x) * step(0.5, UV.y);
	vec3 world = center + (axis * corner.x + side * corner.y * (0.5 + random.x) / slender) * scale;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * cross(axis, side));
	if (age < 0.0 || age > span || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	ALBEDO = tint * shade;
	ROUGHNESS = 0.9;
}
