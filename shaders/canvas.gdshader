shader_type spatial;
render_mode cull_disabled;

// Canvas that has stood in the field: the roof and the walls of a tent, a
// shelter half, the tilt of a lorry. Proofed cotton duck, sewn from lengths
// a yard wide that have each faded by themselves, with the lap of a seam
// between one and the next; paler where the sun has been at it, dark where
// the rain ran off, and the colour of the ground along its hem. Seen from
// inside, with the sun on the other side, it glows.
//
// Whoever builds the cloth gives it its place in metres for UV, the seams
// running along V, and says in the vertex colour what has happened to it:
// red is how much of the ground has got into it, green how far it has faded
// (0.5 for canvas as it came), blue how much light gets into its folds (1
// for cloth that hangs free) and alpha how much of the sun comes through (0
// for cloth that is rolled up or lies on something).
uniform vec3 color : source_color = vec3(0.2, 0.196, 0.14);
uniform vec3 faded : source_color = vec3(0.33, 0.315, 0.245);
uniform vec3 soil : source_color = vec3(0.74, 0.69, 0.58);
uniform sampler2D weave_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D weave_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// How bright the scan of the weave is on average, so that it leaves the
// colour as it is.
uniform float weave_value = 0.55;
uniform float weave_scale = 2.5;
uniform float weave_depth : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// How wide the lengths are that it was sewn from, in metres.
uniform float strip = 0.9;
uniform float through : hint_range(0.0, 4.0) = 1.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.93;
// The way the wind blows (x and z), as the grass has it: the gusts that run
// over the land bend the marram and fill the canvas at the same moment.
uniform vec2 wind = vec2(0.12, 1.0);

void vertex() {
	// Cloth that moves says so in UV2: x is how far this corner of it gives
	// in the wind, in metres, and nought where it is held; y is how light it
	// is, nought for a wall of canvas that fills and sinks back and one for
	// a shirt on a line, which is taken along by the wind and never still.
	if (UV2.x > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 downwind = normalize(wind);
		float run = dot(world.xz, downwind);
		float gust = 0.5 + 0.5 * sin(run * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
		// It fills with a gust and empties after it, a swell runs along it,
		// and what is light flutters.
		float swell = sin(run * 0.9 + world.y * 0.6 - TIME * 1.7);
		float flutter = sin(run * 4.3 + world.y * 2.9 - TIME * 6.1) * 0.6 + sin(dot(world.xz, vec2(-downwind.y, downwind.x)) * 3.1 + world.y * 1.7 - TIME * 4.3) * 0.4;
		float moves = (gust - 0.4) * 0.8 + swell * (0.15 + 0.3 * gust) + flutter * UV2.y * (0.15 + 0.3 * gust);
		// Cloth that is held all round moves in and out, the way it faces;
		// cloth that hangs free goes with the wind.
		mat3 turned = mat3(MODEL_MATRIX);
		vec3 blows = normalize(vec3(downwind.x, 0.3, downwind.y));
		vec3 faces = normalize(turned * NORMAL);
		vec3 goes = mix(faces * (dot(faces, blows) < 0.0 ? -1.0 : 1.0), blows, UV2.y);
		VERTEX += (goes * turned) * moves * UV2.x;
	}
	// The sun shines through one thickness of canvas: the inside of a roof
	// is lit by what falls on its outside. Its own shadow would lie on it
	// there, in the dots of the shadow map. The cloth therefore throws its
	// shadow from a hand's breadth further from the light than it hangs.
	if (IN_SHADOW_PASS) {
		vec4 seen = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		seen.z -= 0.09;
		VERTEX = (inverse(MODELVIEW_MATRIX) * seen).xyz;
	}
}

void fragment() {
	vec3 wide = texture(wear_mask, UV * 0.09).rgb;
	vec3 fine = texture(wear_mask, UV * 0.71 + vec2(0.31, 0.57)).rgb;
	vec3 weave = texture(weave_tex, UV * weave_scale).rgb;
	float thread = mix(1.0, dot(weave, vec3(0.333)) / weave_value, 1.0 - smoothstep(1.0, 3.5, -VERTEX.z));

	// Each length of the cloth is a little lighter or darker than the next.
	float lane = floor(UV.x / strip);
	float bolt = fract(sin(lane * 12.9898) * 43758.5453);
	float fade = clamp((COLOR.g - 0.5) * 2.0 + (wide.b - 0.5) * 0.9 + (bolt - 0.5) * 0.35, -1.0, 1.0);
	vec3 albedo = mix(color, faded, max(fade, 0.0)) * (1.0 + min(fade, 0.0) * 0.4);

	// Where the rain ran off it left streaks: thin lines of the noise, drawn
	// out along the fall.
	float streaks = texture(wear_mask, vec2(UV.x * 1.9, UV.y * 0.11)).g;
	float run = smoothstep(0.62, 0.85, streaks) * smoothstep(0.4, 0.65, wide.r);
	albedo *= 1.0 - 0.12 * run;
	albedo *= mix(0.9, 1.08, fine.b) * thread;

	// The seams: two thicknesses of cloth, a line of stitching either side.
	float off = abs(fract(UV.x / strip + 0.5) - 0.5) * strip;
	float lap = 1.0 - smoothstep(0.014, 0.018, off);
	float stitched = (1.0 - smoothstep(0.0015, 0.004, abs(off - 0.011))) * step(0.45, fract(UV.y * 110.0));
	albedo *= 1.0 - 0.14 * lap;
	albedo = mix(albedo, albedo * 1.5 + 0.02, stitched * 0.6);

	// The ground works its way up from the hem, and dust lies in the weave.
	float soiled = smoothstep(0.3, 0.85, COLOR.r * 1.1 + (fine.g - 0.5) * 0.45 + (wide.r - 0.5) * 0.25);
	albedo = mix(albedo, soil * mix(0.8, 1.05, fine.r) * thread, soiled * 0.8);

	albedo *= mix(0.45, 1.0, COLOR.b);
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(weave_normal, UV * weave_scale).rgb;
	// From further off the threads are finer than a dot of the screen, and
	// what is left of them is a grid that is not there.
	NORMAL_MAP_DEPTH = weave_depth * (1.0 - smoothstep(1.0, 3.5, -VERTEX.z));
	// One thickness lets the sun through, warm; a seam lets less through, and
	// so does dirt.
	BACKLIGHT = vec3(1.0, 0.95, 0.72) * through * COLOR.a * (1.0 - 0.55 * lap) * (1.0 - 0.5 * soiled) * (1.0 - 0.3 * run);
}
