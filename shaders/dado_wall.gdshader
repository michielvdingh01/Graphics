shader_type spatial;

// Plastered wall of a corridor or an office in a factory: gloss paint up to
// hip height, where it can be wiped down, a painted line above that and a
// dark skirting at the floor. The paint has flaked where trolleys and boots
// knock into it, and dirt has crept up from the floor. A wall has its
// position in metres for UV, as the level builder writes it.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.333;
// Colour of the plaster above the dado, of the dado itself and of the line.
uniform vec3 wall_tint : source_color = vec3(0.85, 0.88, 0.82);
uniform vec3 dado : source_color = vec3(0.2, 0.33, 0.27);
uniform vec3 line : source_color = vec3(0.09, 0.15, 0.12);
// Heights above the floor in metres.
uniform float dado_height = 1.3;
uniform float line_width = 0.03;
uniform float skirting = 0.1;
uniform float flaking : hint_range(0.0, 1.0) = 0.5;

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 plaster = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	// Soft blotches in red and blue, finer cells in green; one repeat spans
	// three metres of wall.
	vec3 mask = texture(wear_mask, UV * 0.31).rgb;

	float below = 1.0 - smoothstep(dado_height - 0.002, dado_height + 0.002, height);
	float on_line = (1.0 - below) * (1.0 - smoothstep(dado_height + line_width - 0.002, dado_height + line_width + 0.002, height));
	// It flakes most at the height a trolley rubs along and just above the skirting.
	float rubbed = exp(-pow((height - 0.82) / 0.1, 2.0)) + 0.7 * exp(-pow((height - 0.2) / 0.12, 2.0));
	float level = mix(0.9, 0.66, flaking);
	float flaked = smoothstep(level, level + 0.025, mask.g * 0.55 + mask.b * 0.45 + rubbed * 0.14);
	float painted = below * (1.0 - flaked);

	vec3 wall = plaster * wall_tint;
	// Gloss paint keeps the unevenness of the plaster under it, not its colour.
	float relief = dot(plaster, vec3(0.333)) / 0.6;
	vec3 albedo = mix(wall, dado * mix(0.8, 1.15, relief) * mix(0.85, 1.1, mask.r), painted);
	albedo = mix(albedo, line * mix(0.8, 1.2, relief), on_line * (1.0 - flaked * 0.5));
	float rough = mix(orm.g, 0.32 + 0.2 * mask.r, max(painted, on_line));

	// Dirt from mopping and boots, darkest at the floor.
	float dirt = exp(-max(height - skirting, 0.0) / 0.22) * (0.35 + 0.5 * mask.b);
	// And the grey that settles on a wall nobody washes above arm's reach.
	dirt += smoothstep(2.0, 3.4, height) * 0.25 * mask.r;
	albedo = mix(albedo, vec3(0.06, 0.055, 0.05), clamp(dirt, 0.0, 0.8));
	rough = mix(rough, 0.85, clamp(dirt, 0.0, 1.0));

	float base = 1.0 - smoothstep(skirting - 0.002, skirting + 0.002, height);
	albedo = mix(albedo, vec3(0.025, 0.025, 0.027) * mix(0.7, 1.6, mask.g), base);
	rough = mix(rough, 0.45, base);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	AO = orm.r;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	// Paint fills the pores of the plaster.
	NORMAL_MAP_DEPTH = mix(1.0, 0.45, max(painted, base));
}
