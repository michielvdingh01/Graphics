shader_type spatial;

// Hay: dried grass, pale gold where it was dried well and grey-green where it
// got rain, stalks lying every way. It is the scan of a sparse meadow seen
// close, whose stalks are pale on dark earth, turned to straw on straw: the
// dark between the stalks becomes the shadow deeper in the hay. Two layers
// of it lie crosswise.
//
// A face has metres for UV, whichever way it lies. UV2.x is 4 or more for
// hay inside a building, where the light of the sky hardly comes.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.7;
uniform float scan_mean = 0.052;
uniform vec3 straw : source_color = vec3(0.72, 0.62, 0.38);
uniform vec3 deep : source_color = vec3(0.24, 0.19, 0.1);
uniform vec3 rained : source_color = vec3(0.5, 0.5, 0.36);
uniform float sheltered : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 uv = UV * uv_scale;
	float a = dot(texture(albedo_tex, uv).rgb, vec3(0.299, 0.587, 0.114)) / scan_mean;
	float b = dot(texture(albedo_tex, uv.yx * 1.31 + vec2(0.37, 0.11)).rgb, vec3(0.299, 0.587, 0.114)) / scan_mean;
	vec3 wide = texture(wear_mask, UV * 0.2).rgb;
	float stalks = smoothstep(0.7, 1.8, max(a, b * 0.9));
	vec3 hay = mix(straw, rained, smoothstep(0.45, 0.75, wide.g) * 0.7) * mix(0.85, 1.1, wide.r);
	vec3 albedo = mix(deep * mix(0.8, 1.2, wide.b), hay, stalks);
	ALBEDO = albedo;
	ROUGHNESS = 0.95;
	AO = mix(0.55, 1.0, stalks) * mix(1.0, sheltered, step(3.5, UV2.x));
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 1.6;
	// Light comes through a thin layer of stalks.
	BACKLIGHT = hay * 0.15;
}
