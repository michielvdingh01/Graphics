shader_type spatial;

// Finish on something that is handled and knocked about: a weapon, a robot.
// A coat (bluing, anodising, paint, or the plastic itself) lies over a core
// that shows wherever the coat has worn through: along the edges first, then
// in scuffs and scratches on the flats. Grease dulls and darkens it in patches.
//
// The builder writes into the vertex colour where a point lies between the
// edges of its face; see _edge() in tools/level_builder.gd.
uniform vec3 coat : source_color = vec3(0.04, 0.04, 0.045);
uniform float coat_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float coat_metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec3 core : source_color = vec3(0.55, 0.55, 0.57);
uniform float core_roughness : hint_range(0.0, 1.0) = 0.3;
uniform float core_metallic : hint_range(0.0, 1.0) = 1.0;
uniform float edge_wear : hint_range(0.0, 1.0) = 0.5;
uniform float scuffs : hint_range(0.0, 1.0) = 0.3;
uniform float grime : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// Repeats of the mask per metre: one repeat should span about the whole object.
uniform float mask_scale = 3.0;
// Fine surface texture, in repeats per metre.
uniform sampler2D grain : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_scale = 20.0;
uniform float grain_depth : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec3 wide = texture(wear_mask, UV * mask_scale).rgb;
	vec3 fine = texture(wear_mask, UV * mask_scale * 6.7 + vec2(0.31, 0.57)).rgb;

	// The coat is gone on the edge itself and thins out over a few millimetres,
	// further where the noise says the thing has been rubbed.
	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	vec2 away = min(COLOR.rg, 1.0 - COLOR.rg) * span;
	float edge = min(away.x, away.y);
	float near = 1.0 - smoothstep(0.0, 0.0004 + 0.0025 * edge_wear, edge);
	float rubbed = (fine.g - 0.5) * 0.6 + (wide.r - 0.5) * 0.5;
	float worn = smoothstep(0.5, 0.58, near * (0.2 + 0.5 * edge_wear) + rubbed);

	// Scratches are the noise drawn out into hairlines, in two directions;
	// scuffs are where it peaks.
	float hairs = max(
		texture(wear_mask, vec2(UV.x * 2.1, UV.y * 61.0) * mask_scale).b,
		texture(wear_mask, vec2(UV.x * 53.0 + 0.4, UV.y * 2.7) * mask_scale).b);
	float scratched = smoothstep(0.86 - 0.2 * scuffs, 0.9 - 0.2 * scuffs, hairs) * smoothstep(0.4, 0.65, wide.g);
	float scuffed = smoothstep(0.98 - 0.3 * scuffs, 1.02 - 0.3 * scuffs, wide.b * 0.6 + fine.r * 0.5);
	worn = max(worn, max(scratched * 0.6, scuffed * 0.8));

	// Grease and dust: darker and duller in soft patches, shinier where a
	// hand has polished it.
	float dirty = smoothstep(0.35, 0.75, wide.g * 0.6 + fine.b * 0.4) * grime;
	float handled = smoothstep(0.55, 0.85, wide.r) * grime;
	vec3 albedo = coat * mix(1.0, 0.72, dirty) * mix(0.92, 1.1, fine.r);
	float rough = clamp(coat_roughness + 0.22 * dirty - 0.16 * handled + (fine.b - 0.5) * 0.08, 0.04, 1.0);

	ALBEDO = mix(albedo, core, worn);
	ROUGHNESS = mix(rough, core_roughness + (fine.r - 0.5) * 0.15, worn);
	METALLIC = mix(coat_metallic, core_metallic, worn);
	NORMAL_MAP = texture(grain, UV * grain_scale).rgb;
	NORMAL_MAP_DEPTH = grain_depth * (1.0 - 0.6 * worn);
}
