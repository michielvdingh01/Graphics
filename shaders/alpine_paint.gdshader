shader_type spatial;

// Painted wood out of doors: the shutters of a farmhouse, the frames of its
// windows, the door of a chapel, a figure on a cross. The paint has gone
// chalky, and along the edges and in patches it has flaked off the grey
// wood under it, whose grain shows through what is left.
//
// Which paint a piece has is the builder's: UV2.x is the number of a colour
// of `paints` over ten, and UV2.y how high the ground lies. A face has metres
// for UV with the grain down V, and the vertex colour says where a point lies
// between the edges of its face: see tools/kit/alpine.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform float scan_mean = 0.06;
uniform vec3 bare : source_color = vec3(0.5, 0.48, 0.45);
// White, the green of shutters, the red-brown of a door, the pale of a
// carved figure, the blue of a shrine, gold, black, the green of a field.
const vec3 PAINTS[8] = vec3[8](
	vec3(0.82, 0.81, 0.77), vec3(0.16, 0.3, 0.17), vec3(0.36, 0.13, 0.08), vec3(0.78, 0.67, 0.55),
	vec3(0.1, 0.17, 0.36), vec3(0.72, 0.55, 0.18), vec3(0.06, 0.06, 0.06), vec3(0.3, 0.42, 0.2)
);
// How much paint has come off, on the whole.
uniform float flaked : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	int which = clamp(int(UV2.x * 10.0 + 0.5), 0, 7);
	vec3 paint = PAINTS[which];
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(albedo_tex, uv).rgb;
	float lum = dot(scan, vec3(0.299, 0.587, 0.114)) / scan_mean;
	vec3 fine = texture(wear_mask, UV * 1.3 + vec2(0.23, 0.81)).rgb;
	vec3 wide = texture(wear_mask, UV * 0.2).rgb;
	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	vec2 in_face = COLOR.rg * span;
	vec2 to_edge = min(in_face, span - in_face);
	float edge = 1.0 - smoothstep(0.003, 0.03, min(to_edge.x, to_edge.y));
	float off = smoothstep(0.62, 0.7, fine.r * 0.6 + wide.g * 0.5 + edge * 0.5 - (1.0 - flaked) * 0.4);
	vec3 painted = paint * mix(1.0, clamp(lum, 0.5, 1.4), 0.25) * mix(0.92, 1.05, wide.b);
	vec3 albedo = mix(painted, bare * mix(1.0, lum, 0.8), off);
	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.6, 0.9, off);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(0.4, 1.0, off);
}
