shader_type spatial;

// Slabs of concrete laid out of doors as a road or a yard, thirty years
// ago. Every face the builder made is a slab: one a little paler than the
// next, dark along its joints, a few of them cracked. Wheels have left
// their rubber along the way the slabs lie, oil has dripped where lorries
// stood, and sand has blown over all of it and stays in the lee of things.
//
// A slab has its position in metres for UV, and the builder writes into the
// vertex colour where a point lies between its edges: see _edge() in
// tools/level_builder.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.3;
// The scan is of a floor indoors and dark: this is how much lighter the
// concrete of a road is.
uniform vec3 tint : source_color = vec3(1.0);
uniform float gain = 3.0;
uniform float marks : hint_range(0.0, 1.0) = 0.6;
uniform float oil : hint_range(0.0, 1.0) = 0.5;
uniform float cracks : hint_range(0.0, 1.0) = 0.5;
uniform float sand : hint_range(0.0, 1.0) = 0.6;
uniform vec3 sand_tint : source_color = vec3(0.6, 0.555, 0.49);

void fragment() {
	vec2 uv = UV * uv_scale;
	float depth = -VERTEX.z;
	vec3 scan = texture(albedo_tex, uv).rgb;
	scan = mix(scan, texture(albedo_tex, uv * 0.23 + vec2(0.37, 0.11)).rgb, smoothstep(12.0, 50.0, depth) * 0.6);
	vec3 wide = texture(wear_mask, UV * 0.027).rgb;
	vec3 fine = texture(wear_mask, UV * 0.43 + vec2(0.31, 0.57)).rgb;

	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	float edged = step(span.x, 200.0) * step(span.y, 200.0);
	vec2 sides = min(COLOR.rg, 1.0 - COLOR.rg) * span;
	float away = mix(100.0, min(sides.x, sides.y), edged);
	// As dark as where the slab begins says: see shaders/weathered_wall.gdshader.
	vec2 corner = (UV - COLOR.rg * span) * edged;
	float pour = 0.5 + 0.5 * sin(dot(corner, vec2(0.93, 1.71))) * sin(dot(corner, vec2(2.37, 0.61)) + 1.3);

	vec3 albedo = min(scan * gain, vec3(1.0)) * tint * mix(0.8, 1.08, pour) * mix(0.88, 1.08, wide.r);
	float rough = 0.86;

	// Wheels have gone the way the slabs lie.
	vec2 lane = span.x >= span.y ? UV : UV.yx;
	float streak = texture(wear_mask, vec2(lane.y * 0.61, lane.x * 0.017)).r;
	float rubber = smoothstep(0.52, 0.74, streak + (fine.b - 0.5) * 0.2) * marks;
	albedo *= 1.0 - 0.38 * rubber;

	// Oil, where something stood and dripped.
	float oily = smoothstep(0.66, 0.78, wide.b * 0.62 + fine.r * 0.42) * oil;
	albedo *= 1.0 - 0.6 * oily;
	rough = mix(rough, 0.45, oily);

	// A slab that has broken shows it as a line that wanders across it.
	float broken = step(1.0 - 0.45 * cracks, fract(pour * 7.31 + corner.x * 0.137));
	float wander = texture(wear_mask, UV * 0.071 + corner * 0.19).r;
	float crack = (1.0 - smoothstep(0.004, 0.011, abs(wander - 0.5))) * broken * smoothstep(0.25, 0.5, fine.g + 0.3);
	albedo = mix(albedo, vec3(0.05, 0.045, 0.04), crack * 0.85);

	// Dirt lies in the joints and creeps out of them.
	float joint = 1.0 - smoothstep(0.0, 0.02 + 0.05 * fine.g, away);
	albedo *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.6, away)) * fine.b;
	albedo = mix(albedo, vec3(0.07, 0.06, 0.05), joint * 0.7);

	// Sand, in drifts and along the joints.
	float drift = smoothstep(0.6, 0.8, wide.g * 0.7 + fine.b * 0.4 + (1.0 - smoothstep(0.0, 0.18, away)) * 0.12) * sand;
	albedo = mix(albedo, sand_tint * (0.86 + 0.28 * fine.r), drift);
	rough = mix(rough, 0.96, drift);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.4, drift);
}
