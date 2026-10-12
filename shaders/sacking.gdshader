shader_type spatial;

// Hessian that has been out in the rain: a sandbag, a rope. The scan gives
// the weave and its colour; the bag has gone darker in patches where it
// stays damp, sand lies on whatever of it faces the sky, and along one side
// runs the seam it was sewn up with.
//
// Whoever builds the bag gives it the way round it in metres for U, nought
// on its seam, and the way along it for V. The vertex colour is its shade,
// and in alpha how much light gets to that spot: little underneath, and
// where one bag lies against the next.
uniform vec3 color : source_color = vec3(0.9, 0.82, 0.66);
uniform vec3 sand : source_color = vec3(0.74, 0.66, 0.5);
uniform sampler2D weave_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D weave_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float weave_scale = 1.7;
uniform float weave_depth : hint_range(0.0, 3.0) = 1.6;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// A bag's own shade moves its stains: no two are marked alike.
	vec2 own = vec2(COLOR.r * 7.3, COLOR.b * 5.1);
	vec3 wide = texture(wear_mask, UV * 0.37 + own).rgb;
	vec3 fine = texture(wear_mask, UV * 1.9 + own.yx).rgb;
	vec3 albedo = texture(weave_tex, UV * weave_scale).rgb * color * COLOR.rgb;
	// Damp, and the dirt that damp holds.
	float damp = smoothstep(0.52, 0.74, wide.r * 0.75 + fine.g * 0.25);
	albedo *= mix(1.0, 0.62, damp) * mix(0.9, 1.08, fine.b);
	// The seam: a ridge of doubled cloth, stitched.
	float off = abs(UV.x);
	float seam = 1.0 - smoothstep(0.006, 0.011, off);
	float stitched = (1.0 - smoothstep(0.012, 0.016, off)) * step(0.5, fract(UV.y * 55.0)) * (1.0 - seam);
	albedo *= 1.0 - 0.3 * seam - 0.25 * stitched;
	// Sand on top of it.
	float settled = smoothstep(0.55, 0.95, world_normal.y) * smoothstep(0.3, 0.7, wide.g + fine.r * 0.3);
	albedo = mix(albedo, sand * mix(0.85, 1.05, fine.r), settled * 0.6);
	albedo *= mix(0.3, 1.0, COLOR.a);
	ALBEDO = albedo;
	ROUGHNESS = 0.94;
	SPECULAR = 0.2;
	AO = mix(0.5, 1.0, COLOR.a);
	NORMAL_MAP = texture(weave_normal, UV * weave_scale).rgb;
	NORMAL_MAP_DEPTH = weave_depth;
}
