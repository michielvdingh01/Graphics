shader_type spatial;

// Scanned concrete with puddles: a noise mask decides where water stands, and
// the water flattens the normal, darkens the surface and makes it mirror-like.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.333;
uniform float mask_scale = 0.045;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.34;

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 orm = texture(orm_tex, uv).rgb;
	float mask = texture(wet_mask, UV * mask_scale).r;
	float level = 1.0 - puddle_amount;
	float puddle = smoothstep(level, level + 0.035, mask);
	float damp = smoothstep(level - 0.14, level, mask);
	ALBEDO = texture(albedo_tex, uv).rgb * mix(1.0, 0.6, damp);
	ROUGHNESS = mix(mix(orm.g, orm.g * 0.6, damp), 0.03, puddle);
	METALLIC = orm.b;
	AO = orm.r;
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), puddle);
}
