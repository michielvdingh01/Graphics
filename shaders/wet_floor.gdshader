shader_type spatial;

// Scanned concrete with puddles and floor paint. A noise mask decides where
// water stands; the water flattens the normal, darkens the surface and makes
// it mirror-like. Lines and hatching come from a texture that the level
// builder draws per level (floor_line() and the like in
// tools/level_builder.gd); traffic has worn them down to the pores of the
// concrete. The top of a floor has its position in metres for UV.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D markings : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
// Where the markings lie: x and z of their first corner, then one over
// their width and their depth.
uniform vec4 markings_rect = vec4(0.0);
// Average brightness of the scan.
uniform float scan_value = 0.092;
uniform float uv_scale = 0.333;
uniform float mask_scale = 0.045;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.34;

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 albedo = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	float rough = orm.g;

	// Paint lasts where nobody walks, and in the pores of the concrete: those
	// are the dark specks of the scan.
	vec4 mark = texture(markings, (UV - markings_rect.xy) * markings_rect.zw);
	float pores = 1.0 - dot(albedo, vec3(0.333)) / scan_value;
	float kept = smoothstep(0.3, 0.6, texture(wet_mask, UV * 0.37).r + pores * 0.6);
	float painted = mark.a * mix(0.22, 0.95, kept);
	albedo = mix(albedo, mark.rgb * mix(0.75, 1.05, kept), painted);
	rough = mix(rough, 0.55, painted * 0.6);

	float mask = texture(wet_mask, UV * mask_scale).r;
	float level = 1.0 - puddle_amount;
	float puddle = smoothstep(level, level + 0.035, mask);
	float damp = smoothstep(level - 0.14, level, mask);
	ALBEDO = albedo * mix(1.0, 0.6, damp);
	ROUGHNESS = mix(mix(rough, rough * 0.6, damp), 0.03, puddle);
	METALLIC = orm.b;
	AO = orm.r;
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), puddle);
}
