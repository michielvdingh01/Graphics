shader_type spatial;

// A roof of split larch shingles, laid in courses from the eaves up, each
// course lapping over the one below so that only a hand's breadth of every
// shingle shows. They have weathered silver-grey, one a shade off the next,
// a few darker where they were put in later, with lichen on them and moss
// along the lower courses where the sun does not come. The butt of every
// shingle throws a thin shadow on the course below it, and the cracks
// between them are dark.
//
// The face has metres for UV, U along the eaves and V down the slope from the
// ridge: see _alp_roof() in tools/kit/alpine.gd. A turned roof, the cap of a
// tower, has U round it and V down it. Into UV2.y the builder writes how
// high the ground lies, which the shader does not need.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float scan_mean = 0.06;
// What shows of each course, and how wide a shingle is on average.
uniform float course = 0.12;
uniform float shingle = 0.1;
uniform vec3 grey : source_color = vec3(0.4, 0.39, 0.37);
uniform vec3 newer : source_color = vec3(0.45, 0.33, 0.22);
uniform vec2 sun_side = vec2(0.15, 0.99);
uniform float lichen : hint_range(0.0, 1.0) = 0.6;
uniform float moss : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float row = floor(UV.y / course);
	float down = fract(UV.y / course);
	float x = UV.x / shingle + hash(vec2(row, 3.1)) * 7.0;
	// The joints between shingles wander: each lies up to a third of a width
	// off where it would be in a regular row.
	float c = floor(x);
	float left = c + (hash(vec2(c, row)) - 0.5) * 0.6;
	if (x < left) {
		c -= 1.0;
		left = c + (hash(vec2(c, row)) - 0.5) * 0.6;
	}
	float right = c + 1.0 + (hash(vec2(c + 1.0, row)) - 0.5) * 0.6;
	if (x > right) {
		c += 1.0;
		left = right;
		right = c + 1.0 + (hash(vec2(c + 1.0, row)) - 0.5) * 0.6;
	}
	float across = (x - left) / max(right - left, 0.1);
	float own = hash(vec2(c, row + 17.0));

	// The grain of each shingle, a strip of the scan of its own.
	vec2 uv = vec2(own * 9.0 + across * (right - left) * shingle * 0.4, UV.y * 0.5 + own * 3.0);
	vec3 scan = texture(albedo_tex, uv).rgb;
	float lum = dot(scan, vec3(0.299, 0.587, 0.114)) / scan_mean;
	vec3 wide = texture(wear_mask, UV * 0.09).rgb;
	vec3 fine = texture(wear_mask, UV * 0.8 + vec2(0.17, 0.63)).rgb;

	vec3 wood = grey * mix(0.72, 1.12, own) * mix(0.9, 1.08, wide.r);
	wood = mix(wood, newer, step(0.93, hash(vec2(c * 0.37, row * 1.3))) * 0.8);
	vec3 albedo = wood * mix(1.0, lum, 0.7);
	// The shadow of the butts above, the crack either side, and the worn
	// butt of its own.
	float shade = 1.0 - smoothstep(0.0, 0.22, down);
	float crack = 1.0 - smoothstep(0.0, 0.05, min(across, 1.0 - across));
	albedo *= (1.0 - 0.55 * shade) * (1.0 - 0.6 * crack);
	albedo = mix(albedo, grey * 1.2, smoothstep(0.9, 1.0, down) * 0.35);

	// Lichen in rosettes, and moss in the low courses away from the sun.
	float spot = smoothstep(0.66, 0.74, fine.g * 0.65 + wide.b * 0.5) * lichen;
	albedo = mix(albedo, mix(vec3(0.55, 0.52, 0.36), vec3(0.6, 0.38, 0.16), step(0.7, fine.r)), spot * 0.55);
	float shady = clamp(0.6 - dot(world_normal.xz, sun_side), 0.0, 1.0);
	float mossy = moss * shady * smoothstep(0.45, 0.7, wide.g * 0.8 + fine.b * 0.3) * (1.0 - shade * 0.5);
	albedo = mix(albedo, vec3(0.13, 0.16, 0.06) * (0.8 + 0.5 * fine.r), mossy * 0.75);

	// From afar a roof of a thousand shingles is one grey: the pattern gives
	// way to its average before it shimmers.
	float far = smoothstep(18.0, 70.0, -VERTEX.z);
	albedo = mix(albedo, grey * 0.78 * mix(1.0, 0.85, mossy), far * 0.7);

	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.9;
	// Each shingle lies at a slant on the course below it: thicker at its butt.
	vec3 relief = texture(normal_tex, uv).rgb;
	vec2 slant = vec2((0.5 - across) * 0.25 * crack, -0.35 + 0.5 * shade) * (1.0 - far);
	NORMAL_MAP = normalize(vec3(relief.xy * 2.0 - 1.0 + slant, 1.0)) * 0.5 + 0.5;
}
