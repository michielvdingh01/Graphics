shader_type spatial;

// Woven cloth or the synthetic leather of a glove, seen from close by: one
// colour that fades in patches, a weave that catches the light, and a rim
// that goes pale where the fibres are seen edge on.
uniform vec3 color : source_color = vec3(0.2, 0.22, 0.16);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float fuzz : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float mask_scale = 3.0;
uniform sampler2D grain : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_scale = 50.0;
uniform float grain_depth : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	vec3 wide = texture(wear_mask, UV * mask_scale).rgb;
	vec3 fine = texture(wear_mask, UV * mask_scale * 5.3 + vec2(0.17, 0.43)).rgb;
	vec3 albedo = color * mix(0.8, 1.15, wide.b) * mix(0.9, 1.08, fine.r);
	// Dirt has worked its way into the cloth here and there.
	albedo = mix(albedo, albedo * vec3(0.55, 0.5, 0.45), smoothstep(0.55, 0.8, wide.g) * 0.5);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(albedo, albedo * 1.8 + 0.02, rim * fuzz);
	// A smooth cloth also has a sheen along that rim, which is what gives a
	// dark glove its shape against a dark hall; a fuzzy one has none.
	RIM = max(0.0, 0.3 - 0.6 * fuzz);
	RIM_TINT = 0.5;
	// Where it is handled the cloth has worn smoother.
	ROUGHNESS = roughness * mix(0.86, 1.0, wide.r);
	NORMAL_MAP = texture(grain, UV * grain_scale).rgb;
	NORMAL_MAP_DEPTH = grain_depth;
}
