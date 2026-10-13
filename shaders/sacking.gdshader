shader_type spatial;

// Hessian that has stood in the field: a sandbag, a rope. Grey-buff, not
// the tan of new jute: bleached where it faces the sky, darker where it
// stays damp, with sand lying on it and in the folds between one bag and
// the next, and along one side the seam it was sewn up with. The scan gives
// the weave, a little larger than life so that it shows from across a post.
//
// Whoever builds the bag gives it the way round it in metres for U, nought
// on its seam, and the way along it for V. The vertex colour is its shade,
// and in alpha how much light gets to that spot: little underneath, and
// where one bag lies against the next. Its stains come from where it lies
// in the world, so that no two bags are marked alike.
uniform vec3 color : source_color = vec3(0.5, 0.46, 0.38);
uniform vec3 bleached : source_color = vec3(0.68, 0.65, 0.56);
uniform vec3 sand : source_color = vec3(0.76, 0.71, 0.6);
uniform sampler2D weave_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D weave_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// How bright the scan is on average, so that it leaves the colour alone.
uniform float weave_value = 0.29;
uniform float weave_scale = 1.1;
uniform float weave_depth : hint_range(0.0, 3.0) = 2.0;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;

varying vec3 world_normal;
varying vec3 world_at;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 weave = texture(weave_tex, UV * weave_scale).rgb;
	float thread = dot(weave, vec3(0.333)) / weave_value;
	// From a few metres off the weave is finer than a dot of the screen and
	// would only shimmer.
	float near = 1.0 - smoothstep(4.0, 14.0, -VERTEX.z);
	thread = mix(1.0, thread, 1.7 * near + 0.3);
	vec3 wide = texture(wear_mask, world_at.xz * 0.17 + world_at.y * vec2(0.29, 0.41)).rgb;
	vec3 fine = texture(wear_mask, UV * 1.3 + world_at.zx * 0.11).rgb;
	float up = smoothstep(-0.3, 0.9, world_normal.y);
	vec3 albedo = mix(color, bleached, up * 0.85) * COLOR.rgb * thread;
	// Damp, and the dirt that damp holds: soft-edged, and mostly below.
	float damp = smoothstep(0.3, 0.85, wide.r * 0.7 + fine.g * 0.3) * (1.0 - 0.7 * up);
	albedo *= mix(1.0, 0.6, damp) * mix(0.9, 1.07, fine.b);
	// The seam: a ridge of doubled cloth, stitched.
	float off = abs(UV.x);
	float seam = 1.0 - smoothstep(0.006, 0.011, off);
	float stitched = (1.0 - smoothstep(0.012, 0.016, off)) * step(0.5, fract(UV.y * 55.0)) * (1.0 - seam);
	albedo *= 1.0 - (0.28 * seam + 0.2 * stitched) * near;
	// Sand: on top of it, and in every fold that faces up.
	float fold = smoothstep(0.12, 0.32, 1.0 - COLOR.a) * smoothstep(0.15, 0.7, world_normal.y) * 0.65;
	float settled = smoothstep(0.6, 0.96, world_normal.y) * smoothstep(0.35, 0.7, wide.g + fine.r * 0.3) * 0.45;
	float sanded = max(settled, fold);
	albedo *= mix(0.36, 1.0, COLOR.a);
	albedo = mix(albedo, sand * mix(0.85, 1.03, fine.r), sanded);
	ALBEDO = albedo;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	AO = mix(0.55, 1.0, COLOR.a);
	NORMAL_MAP = texture(weave_normal, UV * weave_scale).rgb;
	NORMAL_MAP_DEPTH = weave_depth * near + 0.2;
}
