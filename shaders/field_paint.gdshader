shader_type spatial;

// Painted steel that has been driven through sand for a week: the matt
// green of a field car, the rubber of its tyres, the links of a track. It
// wears as painted steel does anywhere (see worn_paint.gdshader, which this
// follows: chipped along its edges, rusted through here and there, streaked
// below the rust), and the ground has got onto it: thrown up by the wheels
// over its lower half, and settled as dust on whatever faces the sky.
//
// A vehicle stands on the ground at the origin of its model, so how high a
// spot lies over the ground is the Y it was built at. The builder writes
// into the vertex colour where a point lies between the edges of its face;
// see _edge() in tools/level_builder.gd.
uniform vec3 paint : source_color = vec3(0.16, 0.175, 0.105);
uniform float repaint : hint_range(0.0, 1.0) = 1.0;
uniform float scan_value = 0.066;
uniform sampler2D paint_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paint_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform float paint_roughness : hint_range(0.0, 1.0) = 0.68;
uniform float rust : hint_range(0.0, 1.0) = 0.08;
uniform float chipping : hint_range(0.0, 1.0) = 0.5;
// The ground it stands on, as dust.
uniform vec3 sand : source_color = vec3(0.74, 0.69, 0.58);
// How much of it has settled on what faces up.
uniform float dust : hint_range(0.0, 1.0) = 0.6;
// How thick it lies on the lower half, and how high the wheels throw it.
uniform float splash : hint_range(0.0, 1.0) = 0.8;
uniform float splash_to = 1.15;

varying vec3 world_normal;
varying float height;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// A vehicle's model says how high over the ground each point of it was
	// built, as its wheels and its turret are parts that each have their own
	// origin (see _tri() in tools/models/vehicles.gd); anything else stands
	// on the ground at its origin.
	height = CUSTOM0.x > 500.0 ? CUSTOM0.x - 1000.0 : VERTEX.y;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(paint_tex, uv).rgb;
	float value = dot(scan, vec3(0.2126, 0.7152, 0.0722)) / scan_value;
	vec3 albedo = mix(scan, paint * clamp(value, 0.5, 1.7), repaint);

	vec3 wide = texture(wear_mask, UV * 0.11).rgb;
	vec3 fine = texture(wear_mask, UV * 0.83 + vec2(0.31, 0.57)).rgb;
	float patchy = wide.r * 0.7 + fine.r * 0.3;
	// Matt paint fades and chalks unevenly.
	albedo *= mix(0.8, 1.14, wide.b);
	albedo = mix(albedo, vec3(dot(albedo, vec3(0.333))) * 1.15, 0.22 * wide.g);
	float rough = paint_roughness + 0.16 * wide.b;
	float metal = 0.0;

	float level = mix(0.92, 0.42, rust);
	float rusted = smoothstep(level, level + 0.035, patchy + (fine.g - 0.5) * 0.06);
	float stained = smoothstep(level - 0.13, level + 0.02, patchy) * 0.6;
	float above = texture(wear_mask, (UV - vec2(0.0, 0.4)) * 0.11).r * 0.7 + fine.r * 0.3;
	float lines = texture(wear_mask, vec2(UV.x * 2.7, UV.y * 0.13)).b;
	stained = max(stained, smoothstep(level - 0.05, level + 0.04, above) * smoothstep(0.5, 0.72, lines) * 0.85);

	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	vec2 away = min(COLOR.rg, 1.0 - COLOR.rg) * span;
	float edge = min(away.x, away.y);
	float near = 1.0 - smoothstep(0.0, 0.01 + 0.05 * chipping, edge);
	float chipped = smoothstep(0.75, 0.82, fine.g * 0.6 + wide.g * 0.4 + near * near * (0.15 + 0.3 * chipping)) * step(0.001, chipping);
	float bright = chipped * (1.0 - smoothstep(0.0015, 0.006, edge)) * smoothstep(0.35, 0.6, fine.b);
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

	// Sand: thrown up from below, thick at the sills and thinning out to
	// where the wheels no longer reach, ragged at its upper edge; and dust
	// that has settled on every ledge.
	float low = 1.0 - smoothstep(0.1, splash_to, height + (wide.g - 0.5) * 0.45 + (fine.r - 0.5) * 0.25);
	float thrown = clamp(low * low * splash * 1.5 * mix(0.5, 1.0, fine.g), 0.0, 1.0);
	float settled = smoothstep(0.45, 0.92, world_normal.y) * dust * mix(0.35, 1.0, wide.g);
	float sanded = max(thrown, settled);
	albedo = mix(albedo, sand * mix(0.82, 1.06, fine.b), sanded);
	rough = mix(rough, 0.96, sanded);
	metal *= 1.0 - sanded;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL_MAP = mix(texture(paint_normal, uv).rgb, texture(rust_normal, uv * 2.0).rgb, max(rusted, chipped * 0.4));
	NORMAL_MAP_DEPTH = 1.0 - 0.6 * sanded;
}
