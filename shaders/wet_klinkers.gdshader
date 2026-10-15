shader_type spatial;

// Clinker bricks or cobbles after rain, as the quays and streets of the
// canals are by night. The bricks are dark with the wet and have a sheen;
// water stands in the joints, brimming where the street sags, and lies in
// puddles where it sags further. Flattened by the water, the joints and the
// puddles mirror the lanterns: the long streaks of light down a wet street.
// The top of a street has its position in metres for UV.
//
// `wetness` goes from dry to just after a shower. The weather is to turn it
// into one number that every wet surface reads; until then it is set here.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.8;
uniform float mask_scale = 0.05;
uniform float wetness : hint_range(0.0, 1.0) = 1.0;
// How much of the street the puddles cover when it is soaked.
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.22;
// Where the scan has its joints: its ambient occlusion goes from the one to
// the other between these two.
uniform vec2 joint_shade = vec2(0.55, 0.85);
// How rough a wet brick still is, as a share of how rough it is dry, and
// what the film of water leaves of it at the least.
uniform float wet_rough = 0.25;
uniform float film_rough = 0.06;

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 albedo = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	float joint = 1.0 - smoothstep(joint_shade.x, joint_shade.y, orm.r);

	// The same noise at two scales, so that the shores are ragged.
	float sag = texture(wet_mask, UV * mask_scale).r + (texture(wet_mask, UV * mask_scale * 4.3 + vec2(0.37, 0.61)).r - 0.5) * 0.12;
	float level = 1.0 - puddle_amount * wetness;
	float puddle = smoothstep(level, level + 0.03, sag);
	float brim = smoothstep(level - 0.2, level, sag);
	float filled = max(puddle, joint * mix(0.5, 1.0, brim)) * wetness;

	// Wet brick darkens by half, the sand between by more.
	ALBEDO = albedo * mix(1.0, mix(0.52, 0.4, joint), wetness) * mix(1.0, 0.8, puddle);
	float rough = mix(orm.g, orm.g * wet_rough + film_rough, wetness);
	ROUGHNESS = mix(rough, 0.02, filled);
	METALLIC = 0.0;
	AO = orm.r;
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), max(puddle * wetness, filled * 0.85));
}
