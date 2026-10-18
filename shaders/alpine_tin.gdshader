shader_type spatial;

// Corrugated iron on a barn roof, put up galvanised forty years ago and left:
// the zinc has gone dull, and rust has come through in blotches, along the
// laps where one sheet lies over the next, down from every row of nails and
// most of all along the eaves, where the wet stands longest.
//
// The face has metres for UV, U along the eaves and V down the slope, so the
// corrugations of the scan run down the roof: see _alp_roof() in
// tools/kit/alpine.gd. The vertex colour says where a point lies between the
// edges of its face, see _edge() in tools/level_builder.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform vec3 zinc : source_color = vec3(0.6, 0.62, 0.62);
// How rusty the roof is on the whole, 0 to 1.
uniform float rusty : hint_range(0.0, 1.0) = 0.7;
// How wide a sheet is, and how long: where the laps are.
uniform vec2 sheet = vec2(0.92, 2.2);
// How far apart the rows of nails are, down the slope.
uniform float nails = 0.9;

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(albedo_tex, uv).rgb;
	vec3 rust_scan = texture(rust_tex, UV * 0.35).rgb;
	vec3 wide = texture(wear_mask, UV * 0.07).rgb;
	vec3 fine = texture(wear_mask, UV * 0.6 + vec2(0.41, 0.13)).rgb;
	vec3 streak = texture(wear_mask, vec2(UV.x * 1.7, UV.y * 0.05)).rgb;

	// Where it lies: by a lap, under a row of nails, how far from the eaves.
	vec2 in_sheet = fract(UV / sheet);
	float lap = 1.0 - smoothstep(0.0, 0.06, min(min(in_sheet.x, 1.0 - in_sheet.x) * sheet.x, (1.0 - in_sheet.y) * sheet.y * 0.6));
	float below_nails = fract(UV.y / nails);
	float from_nails = smoothstep(0.0, 0.03, below_nails) * (1.0 - smoothstep(0.03, 0.35 + 0.4 * streak.g, below_nails));
	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	float to_eave = COLOR.g * span.y;
	float eave = 1.0 - smoothstep(0.1, 0.9 + 0.8 * wide.b, mix(9.0, to_eave, step(span.y, 200.0)));

	float rust = rusty * (0.25 + 0.9 * wide.r) + lap * 0.5 + from_nails * streak.b * 0.6 + eave * 0.7;
	rust = smoothstep(0.55, 0.85, rust + (fine.g - 0.5) * 0.35);
	vec3 albedo = mix(scan / 0.44 * zinc * mix(0.8, 1.05, wide.g), rust_scan * mix(0.8, 1.25, fine.r), rust);
	// Streaks of the rust that ran down over the zinc.
	albedo = mix(albedo, albedo * vec3(0.75, 0.6, 0.5), from_nails * streak.r * rusty * (1.0 - rust) * 0.6);

	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	METALLIC = mix(0.55, 0.0, rust);
	ROUGHNESS = mix(0.55, 0.9, rust);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
}
