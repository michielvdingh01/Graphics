shader_type spatial;
render_mode cull_disabled;

// A flag at its staff. The builder hangs it out flat, straight downwind of
// its hoist, and says of every corner where on the flag it is: UV runs from
// the hoist to the fly (x) and from the head to the foot (y), and UV2 is
// how long and how high the flag is, in metres. Where the corner is at this
// moment is worked out here: the fly droops when the wind drops and lifts in
// a gust, and waves run down the cloth from the hoist, wider as they go.
//
// It is bunting, thinner than canvas: the sun shines through it. A plain
// field with the star the vehicles carry, bleached and frayed at the fly.
uniform vec3 field : source_color = vec3(0.24, 0.27, 0.13);
uniform vec3 device : source_color = vec3(0.74, 0.73, 0.66);
uniform sampler2D weave_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D weave_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float weave_value = 0.437;
uniform float weave_scale = 5.0;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float through : hint_range(0.0, 4.0) = 1.6;
// The way the wind blows (x and z), as the grass has it.
uniform vec2 wind = vec2(0.12, 1.0);
// How far under the level the fly hangs in a lull and in a gust, in turns
// of a circle.
uniform float droop_lull = 0.17;
uniform float droop_gust = 0.045;

varying vec2 on_flag;

// Where the corner at `at` of the flag (0 to 1 each way) is, from the head
// of the hoist, in metres: downwind, up, and across the wind.
vec3 flies(vec2 at, vec2 size, float gust, float clock) {
	float far = at.x * size.x;
	float droop = mix(droop_lull, droop_gust, gust) * 6.2832;
	// The foot of the flag is slacker than its head and hangs a little more.
	droop *= 1.0 + 0.25 * at.y;
	float wave = sin(far * 3.4 - clock * 6.5 + at.y * 1.3) * (0.03 + 0.11 * at.x)
		+ sin(far * 7.9 - clock * 11.0 - at.y * 2.1) * 0.035 * at.x
		+ sin(far * 1.3 - clock * 2.3) * 0.12 * at.x;
	wave *= 0.45 + 0.75 * gust;
	// What goes into the waves is taken out of its length.
	float taken = 1.0 - 0.07 * at.x * (0.45 + 0.75 * gust);
	return vec3(far * cos(droop) * taken, -far * sin(droop) - at.y * size.y, wave);
}

void vertex() {
	on_flag = UV;
	vec2 size = UV2;
	vec2 downwind = normalize(wind);
	mat3 turned = mat3(MODEL_MATRIX);
	vec3 along = vec3(downwind.x, 0.0, downwind.y) * turned;
	vec3 up = vec3(0.0, 1.0, 0.0) * turned;
	vec3 across = cross(up, along);
	// The head of the hoist, which stays where it is.
	vec3 hoist = VERTEX - along * UV.x * size.x + up * UV.y * size.y;
	vec3 world = (MODEL_MATRIX * vec4(hoist, 1.0)).xyz;
	float run = dot(world.xz, downwind);
	float gust = 0.5 + 0.5 * sin(run * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
	vec3 here = flies(UV, size, gust, TIME);
	vec3 further = flies(UV + vec2(0.02, 0.0), size, gust, TIME) - here;
	vec3 lower = flies(UV + vec2(0.0, 0.02), size, gust, TIME) - here;
	VERTEX = hoist + along * here.x + up * here.y + across * here.z;
	vec3 lies = further.x * along + further.y * up + further.z * across;
	vec3 hangs = lower.x * along + lower.y * up + lower.z * across;
	NORMAL = normalize(cross(lies, hangs));
	TANGENT = normalize(lies);
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}

// How far inside a star of five points `at` lies, the star a unit across
// its points: positive inside.
float star(vec2 at) {
	float turn = atan(at.x, at.y);
	float slice = 6.2832 / 5.0;
	float within = abs(mod(turn + slice * 0.5, slice) - slice * 0.5);
	float far = length(at);
	// The edge of a point runs from its tip (1 out) to the notch (0.382 out)
	// half a slice on.
	vec2 spot = far * vec2(cos(within), sin(within));
	vec2 tip = vec2(1.0, 0.0);
	vec2 notch = 0.382 * vec2(cos(slice * 0.5), sin(slice * 0.5));
	vec2 edge = notch - tip;
	return (edge.x * (spot.y - tip.y) - edge.y * (spot.x - tip.x)) / length(edge);
}

void fragment() {
	vec2 size = UV2;
	vec2 metres = on_flag * size;
	vec3 mask = texture(wear_mask, metres * 0.4).rgb;
	vec3 weave = texture(weave_tex, metres * weave_scale).rgb;
	float thread = dot(weave, vec3(0.333)) / weave_value;
	// The star stands in the middle of the hoist half, two fifths of the
	// height across.
	vec2 from_star = (metres - vec2(size.x * 0.5, size.y * 0.5)) / (size.y * 0.3);
	float in_star = smoothstep(-0.02, 0.02, star(vec2(from_star.x, -from_star.y)));
	vec3 albedo = mix(field, device, in_star);
	// Bleached towards the fly, where it has been in the wind longest, and
	// along its seams darker.
	albedo *= mix(0.92, 1.3, on_flag.x * on_flag.x) * mix(0.9, 1.08, mask.b) * thread;
	float hem = 1.0 - smoothstep(0.02, 0.028, min(min(metres.y, size.y - metres.y), metres.x));
	albedo *= 1.0 - 0.2 * hem;
	// The fly is frayed: threads of it are gone.
	float frayed = smoothstep(size.x - 0.09 - 0.07 * mask.r, size.x - 0.01, metres.x) * step(0.45, fract(metres.y * 37.0 + mask.g * 3.0));
	if (frayed > 0.5) {
		discard;
	}
	ALBEDO = albedo;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	NORMAL_MAP = texture(weave_normal, metres * weave_scale).rgb;
	NORMAL_MAP_DEPTH = 0.5 * (1.0 - smoothstep(1.5, 5.0, -VERTEX.z));
	BACKLIGHT = albedo * 2.0 * through * (1.0 - 0.5 * hem) + vec3(0.02);
}
