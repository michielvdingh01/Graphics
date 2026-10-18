shader_type spatial;

// The grey limestone of the Wetterstein that the valley builds with, laid dry
// as a plinth or lying as it was found under the corner of a barn: a scan of
// stones turned from its own warm brown to the grey of the mountains, darker
// and green at the foot, with moss and lichen on whatever faces up.
//
// A face has its position in metres for UV, and the builder writes into UV2.y
// how high the ground lies that it stands on: see tools/kit/alpine.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
// How much of the scan's own colour is kept, and the grey it is turned to.
uniform float own_colour : hint_range(0.0, 1.0) = 0.3;
uniform vec3 grey : source_color = vec3(0.62, 0.61, 0.58);
uniform float scan_mean = 0.15;
uniform vec2 sun_side = vec2(0.15, 0.99);
uniform float moss : hint_range(0.0, 1.0) = 0.6;

varying vec3 world_normal;
varying float height;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - UV2.y;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	vec3 wide = texture(wear_mask, UV * 0.15).rgb;
	vec3 fine = texture(wear_mask, UV * 1.1 + vec2(0.53, 0.77)).rgb;
	float lum = dot(scan, vec3(0.299, 0.587, 0.114)) / scan_mean;
	vec3 albedo = mix(grey * lum, scan * (grey.g / scan_mean) * 0.9, own_colour);

	float faces_up = smoothstep(0.4, 0.9, world_normal.y);
	float shady = clamp(0.6 - dot(world_normal.xz, sun_side) * 0.7, 0.0, 1.0);
	float wet = (1.0 - smoothstep(0.0, 0.35 + 0.4 * wide.b, height)) * step(-1.0, height);
	albedo *= 1.0 - 0.35 * wet;
	float green = moss * smoothstep(0.5, 0.72, fine.g * 0.6 + wide.r * 0.5) * max(faces_up, wet * shady);
	albedo = mix(albedo, vec3(0.14, 0.18, 0.06) * (0.8 + 0.5 * fine.b), green * 0.8);
	float spots = smoothstep(0.7, 0.76, fine.r * 0.7 + wide.g * 0.4) * (1.0 - wet);
	albedo = mix(albedo, vec3(0.7, 0.68, 0.6), spots * 0.5);

	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(orm.g, 0.95, green);
	AO = orm.r;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
}
