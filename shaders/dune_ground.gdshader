shader_type spatial;

// The ground of open land: scanned sand, with a litter of needles, moss and
// packed earth mixed in where the level builder painted them on its map of
// the land (cover() in tools/kit/land.gd), red, green and blue. The ground
// has its place in metres for UV.
//
// The alpha of that map holds where the sun does not come. Near the camera
// the sun draws that shadow itself; where its shadow maps end, the ground
// darkens by the map instead, so that a wood far off still stands on shade.
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D needles_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D needles_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cover : hint_default_transparent, filter_linear_mipmap, repeat_disable;
// Where the map lies: x and z of its first corner, then one over its width
// and its depth.
uniform vec4 cover_rect = vec4(0.0);
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// How many times a scan fits into a metre.
uniform float sand_scale = 0.55;
uniform float needles_scale = 0.5;
uniform float moss_scale = 0.5;
uniform float earth_scale = 0.5;
uniform vec3 sand_tint : source_color = vec3(1.0);
uniform vec3 needles_tint : source_color = vec3(1.0);
uniform vec3 moss_tint : source_color = vec3(1.0);
uniform vec3 earth_tint : source_color = vec3(1.0);
// Between these distances the shadow of the sun gives way to the map, and
// this is how much of its light the shade of the map takes off.
uniform float shadow_from = 80.0;
uniform float shadow_to = 105.0;
uniform float shade_depth : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 at = (UV - cover_rect.xy) * cover_rect.zw;
	// Beyond the map there is sand and nothing else.
	float inside = float(at == clamp(at, 0.0, 1.0));
	vec4 lies = texture(cover, at) * inside;
	vec3 patchy = texture(wear_mask, UV * 0.017).rgb;
	vec3 ragged = texture(wear_mask, UV * 0.23).rgb;

	// From afar a scan repeats: there it gives way to itself seen from five
	// times as far, and to paler and darker patches a dune across.
	float depth = -VERTEX.z;
	vec3 sand = texture(sand_tex, UV * sand_scale).rgb;
	sand = mix(sand, texture(sand_tex, UV * sand_scale * 0.19).rgb, smoothstep(10.0, 40.0, depth) * 0.75);
	sand *= sand_tint * mix(0.86, 1.1, patchy.r);
	vec3 normal = texture(sand_normal, UV * sand_scale).rgb;
	float rough = 0.96;

	// Each cover comes in raggedly, not as the soft disc it was painted as.
	float moss = smoothstep(0.2, 0.8, lies.g + (ragged.g - 0.5) * 0.9);
	vec3 moss_rgb = texture(moss_tex, UV * moss_scale).rgb * moss_tint * mix(0.85, 1.12, patchy.b);
	sand = mix(sand, moss_rgb, moss);
	normal = mix(normal, texture(moss_normal, UV * moss_scale).rgb, moss);

	float needles = smoothstep(0.2, 0.8, lies.r + (ragged.r - 0.5) * 0.9);
	// The scan is of red earth: what lies under a pine is duller.
	vec3 needles_rgb = texture(needles_tex, UV * needles_scale).rgb;
	needles_rgb = mix(vec3(dot(needles_rgb, vec3(0.333))), needles_rgb, 0.45) * needles_tint * mix(0.88, 1.1, patchy.g);
	sand = mix(sand, needles_rgb, needles);
	normal = mix(normal, texture(needles_normal, UV * needles_scale).rgb, needles);
	rough = mix(rough, 0.88, max(moss, needles));

	// Earth is what is left where wheels and boots have been: it lies on top.
	float earth = smoothstep(0.35, 0.65, lies.b + (ragged.b - 0.5) * 0.45);
	vec3 earth_rgb = texture(earth_tex, UV * earth_scale).rgb * earth_tint * mix(0.9, 1.08, patchy.r);
	sand = mix(sand, earth_rgb, earth * 0.92);
	normal = mix(normal, texture(earth_normal, UV * earth_scale).rgb, earth);

	float shade = lies.a;
	float mapped = smoothstep(shadow_from, shadow_to, depth);
	// Under a crown the sky is hidden as well as the sun: a little darker
	// from close by too.
	ALBEDO = sand * mix(1.0, 1.0 - shade_depth, shade * mapped) * mix(1.0, 0.88, shade);
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	NORMAL_MAP = normal;
}
