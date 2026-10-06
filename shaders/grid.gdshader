shader_type spatial;

// Procedural stand-in PBR surface for the greybox, until scanned materials arrive (phase 2).
// World-space projection keeps texel density constant on every surface: a 1 m grid for scale,
// two octaves of noise for albedo and roughness variation, and a bump derived from the same
// noise (no tangents needed, so it works on CSG meshes).
uniform vec3 base_color : source_color = vec3(0.5);
uniform vec3 line_color : source_color = vec3(0.35);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_variation : hint_range(0.0, 1.0) = 0.25;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;
uniform float bump_strength : hint_range(0.0, 4.0) = 1.0;
uniform float grime : hint_range(0.0, 1.0) = 0.35;
uniform float line_strength : hint_range(0.0, 1.0) = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Perlin noise clusters around 0.5, so stretch it to use the full range.
float stretch(float v) {
	return clamp((v - 0.5) * 2.4 + 0.5, 0.0, 1.0);
}

float height_at(vec2 uv) {
	float coarse = stretch(texture(noise_tex, uv * 0.23).r);
	float fine = stretch(texture(noise_tex, uv * 1.7).r);
	return coarse * 0.6 + fine * 0.4;
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > 0.5 ? world_pos.xz : (n.x > 0.5 ? world_pos.zy : world_pos.xy);

	float h = height_at(uv);
	float broad = stretch(texture(noise_tex, uv * 0.06).r);

	// Albedo: broad staining plus a little fine speckle, darker in the "valleys".
	float tone = mix(stretch(texture(noise_tex, uv * 0.23).r), h, 0.35);
	vec3 albedo = base_color * mix(1.0 - grime * 0.4, 1.0 + grime * 0.1, tone);
	albedo *= mix(1.0 - grime * 0.3, 1.0, broad);

	// Panel grid, anti-aliased by the screen-space derivative.
	vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	albedo = mix(albedo, line_color, line * line_strength);

	// Screen-space bump from the height field (Mikkelsen's tangent-free perturbation).
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	// Fade the bump with distance so it does not shimmer.
	float bump_fade = 1.0 - smoothstep(12.0, 40.0, length(VERTEX));
	NORMAL = normalize(abs(det) * NORMAL - bump_strength * 0.022 * bump_fade * grad);

	// Seams read as slightly recessed and rougher.
	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness_base + (h - 0.5) * roughness_variation * 2.0 + line * 0.1, 0.04, 1.0);
	METALLIC = metallic_amount * (1.0 - line * 0.5);
	SPECULAR = 0.5;
}
