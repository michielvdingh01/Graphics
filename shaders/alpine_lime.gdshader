shader_type spatial;

// Rubble stone under a coat of lime, whitewashed now and then, as the lower
// floor of a farmhouse and a chapel in Tyrol are: white, but never quite
// flat, since the coat follows the stones under it. At the foot the rain has
// splashed it grey and green, and here and there the coat has come away and
// shows the stones.
//
// A face has its position in metres for UV, and the builder writes into UV2.y
// how high the ground lies that it stands on, and into UV2.x 4 or more for
// a face inside a building, where the light of the sky hardly comes: see
// tools/kit/alpine.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.33;
uniform float scan_mean = 0.05;
uniform vec3 lime : source_color = vec3(0.86, 0.85, 0.81);
uniform vec2 sun_side = vec2(0.15, 0.99);
// How high the splashes reach, and how much of the coat has come away there.
uniform float splash_high = 0.7;
uniform float spalled : hint_range(0.0, 1.0) = 0.5;
uniform float sheltered : hint_range(0.0, 1.0) = 0.2;

varying vec3 world_normal;
varying float height;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - UV2.y;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 scan = texture(albedo_tex, uv).rgb;
	float lum = dot(scan, vec3(0.299, 0.587, 0.114)) / scan_mean;
	vec3 wide = texture(wear_mask, UV * 0.06).rgb;
	vec3 fine = texture(wear_mask, UV * 0.5 + vec2(0.71, 0.29)).rgb;

	// The coat: white, its lumps a shade darker, one coat of wash yellower
	// than the next.
	vec3 albedo = lime * mix(1.0, clamp(lum, 0.6, 1.25), 0.45) * mix(0.93, 1.03, wide.r);
	albedo *= mix(vec3(1.0), vec3(1.02, 1.0, 0.94), wide.g);
	float shady = clamp(0.5 - dot(world_normal.xz, sun_side) * 0.7, 0.0, 1.0);

	// The foot: grey from the splashes, and green where the sun does not
	// come.
	float wet = (1.0 - smoothstep(0.0, splash_high * (0.6 + 0.8 * wide.b), height)) * step(-1.0, height);
	albedo *= 1.0 - 0.35 * wet * (0.6 + 0.4 * fine.r);
	float algae = wet * shady * smoothstep(0.45, 0.7, fine.g * 0.6 + wide.b * 0.5);
	albedo = mix(albedo, vec3(0.32, 0.36, 0.24), algae * 0.6);
	// And where the coat has gone, the stones.
	float gone = wet * spalled * smoothstep(0.62, 0.68, wide.r * 0.7 + fine.b * 0.45);
	vec3 stone = texture(stone_tex, UV * 0.5).rgb;
	stone = mix(vec3(dot(stone, vec3(0.333))), stone, 0.4) * 1.1;
	albedo = mix(albedo, stone, gone);

	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.93;
	AO = mix(1.0, sheltered, step(3.5, UV2.x));
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, texture(stone_normal, UV * 0.5).rgb, gone);
	NORMAL_MAP_DEPTH = 0.8;
}
