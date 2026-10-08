shader_type spatial;

// Painted steel after years of use. One coat of paint covers the surface. It
// has chipped along the edges, rusted through in patches that leave streaks
// below them, and dust has settled on whatever faces up.
//
// The level builder writes into the vertex colour where a point lies between
// the edges of its face; see _edge() in tools/level_builder.gd.
uniform vec3 paint : source_color = vec3(0.4, 0.09, 0.06);
// How far `paint` replaces the colour of the scan; its light and dark stay.
uniform float repaint : hint_range(0.0, 1.0) = 1.0;
// Average brightness of the scan, so that repainting comes out as `paint`.
uniform float scan_value = 0.066;
uniform sampler2D paint_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paint_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform float paint_roughness : hint_range(0.0, 1.0) = 0.42;
uniform float rust : hint_range(0.0, 1.0) = 0.3;
uniform float chipping : hint_range(0.0, 1.0) = 0.5;
uniform float dust : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(paint_tex, uv).rgb;
	float value = dot(scan, vec3(0.2126, 0.7152, 0.0722)) / scan_value;
	vec3 albedo = mix(scan, paint * clamp(value, 0.5, 1.7), repaint);

	// The same noise at two unrelated scales, so that neither is seen to repeat.
	vec3 wide = texture(wear_mask, UV * 0.11).rgb;
	vec3 fine = texture(wear_mask, UV * 0.83 + vec2(0.31, 0.57)).rgb;
	float patchy = wide.r * 0.7 + fine.r * 0.3;
	// Paint fades and dulls unevenly.
	albedo *= mix(0.78, 1.12, wide.b);
	float rough = paint_roughness + 0.2 * wide.b;
	float metal = 0.0;

	// Rust breaks through where the noise peaks and stains the paint around it.
	float level = mix(0.92, 0.42, rust);
	float rusted = smoothstep(level, level + 0.035, patchy + (fine.g - 0.5) * 0.06);
	float stained = smoothstep(level - 0.13, level + 0.02, patchy) * 0.6;
	// What rusts higher up runs down in streaks: thin lines of noise, switched
	// on by the rust that lies above this point.
	float above = texture(wear_mask, (UV - vec2(0.0, 0.4)) * 0.11).r * 0.7 + fine.r * 0.3;
	float lines = texture(wear_mask, vec2(UV.x * 2.7, UV.y * 0.13)).b;
	stained = max(stained, smoothstep(level - 0.05, level + 0.04, above) * smoothstep(0.5, 0.72, lines) * 0.85);

	// Paint chips off within a few centimetres of an edge, the noise deciding
	// where; the edge itself is rubbed bright.
	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	vec2 away = min(COLOR.rg, 1.0 - COLOR.rg) * span;
	float edge = min(away.x, away.y);
	float near = 1.0 - smoothstep(0.0, 0.01 + 0.05 * chipping, edge);
	float chipped = smoothstep(0.75, 0.82, fine.g * 0.6 + wide.g * 0.4 + near * near * (0.15 + 0.3 * chipping));
	float bright = chipped * (1.0 - smoothstep(0.0015, 0.006, edge)) * smoothstep(0.35, 0.6, fine.b);
	// A chip that has been there for long has rusted over.
	rusted = max(rusted, chipped * smoothstep(0.4, 0.65, patchy + rust * 0.3));

	vec3 rust_color = texture(rust_tex, uv * 2.0).rgb;
	albedo = mix(albedo, mix(albedo, rust_color * 0.8, 0.55), stained);
	albedo = mix(albedo, vec3(0.1, 0.085, 0.075), chipped);
	rough = mix(rough, 0.6, chipped);
	metal = mix(metal, 0.5, chipped);
	albedo = mix(albedo, rust_color * 0.7, rusted);
	rough = mix(rough, 0.92, rusted);
	metal = mix(metal, 0.0, rusted);
	albedo = mix(albedo, vec3(0.56, 0.56, 0.57), bright);
	rough = mix(rough, 0.36, bright);
	metal = mix(metal, 1.0, bright);

	float settled = smoothstep(0.5, 0.92, world_normal.y) * dust * mix(0.5, 1.0, wide.g);
	albedo = mix(albedo, vec3(0.27, 0.24, 0.2), settled);
	rough = mix(rough, 0.96, settled);
	metal *= 1.0 - settled;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL_MAP = mix(texture(paint_normal, uv).rgb, texture(rust_normal, uv * 2.0).rgb, max(rusted, chipped * 0.4));
}
