shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_disabled;

// A gull wheeling over the dunes, seen from far below: two wings and a body
// of a few triangles. It flies its circle here, in the vertex shader, so
// nothing moves it frame by frame: where it is follows from the time. Its
// place in the flock is the middle of its circle; the custom data of its
// instance has the radius of the circle in metres, where on it the bird
// began, how fast it goes round in radians a second (the sign is the way
// round) and where in its wingbeat it is.
//
// UV.x is how far out along the wing a corner lies, 0 at the body and 1 at
// the tip.
uniform vec3 plumage : source_color = vec3(0.86, 0.86, 0.84);
uniform vec3 tips : source_color = vec3(0.1, 0.1, 0.11);

varying float out_on_wing;

void vertex() {
	float round = TIME * INSTANCE_CUSTOM.b + INSTANCE_CUSTOM.g;
	float radius = INSTANCE_CUSTOM.r;
	float way = sign(INSTANCE_CUSTOM.b);
	// It rides the air up and down as it goes round, and leans into its turn.
	vec3 at = vec3(cos(round), 0.07 * sin(round * 0.6 + INSTANCE_CUSTOM.a), sin(round)) * radius;
	vec3 ahead = vec3(-sin(round), 0.0, cos(round)) * way;
	vec3 inward = -vec3(cos(round), 0.0, sin(round));
	vec3 aside = cross(vec3(0.0, 1.0, 0.0), ahead);
	float lean = 0.42 * way * dot(aside, inward);
	vec3 right = aside * cos(lean) + vec3(0.0, 1.0, 0.0) * sin(lean);
	vec3 over = cross(ahead, right);
	// A gull glides, and beats its wings now and then for a few strokes.
	float beating = smoothstep(0.35, 0.8, sin(TIME * 0.31 + INSTANCE_CUSTOM.a * 2.0));
	float stroke = sin(TIME * 7.5 + INSTANCE_CUSTOM.a) * beating;
	float lift = (0.16 + 0.34 * stroke) * pow(UV.x, 1.4);
	out_on_wing = UV.x;
	VERTEX = at + right * VERTEX.x + over * (VERTEX.y + lift) + ahead * VERTEX.z;
	NORMAL = over;
}

void fragment() {
	ALBEDO = mix(plumage, tips, smoothstep(0.8, 0.9, out_on_wing));
	ROUGHNESS = 0.9;
	// Seen from below it is its underside that shows, which the sun does not
	// reach: a gull overhead is grey against the sky, not white.
	if (dot(NORMAL, VIEW) < 0.0) {
		NORMAL = -NORMAL;
	}
}
