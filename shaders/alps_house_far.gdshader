shader_type spatial;

// The houses of the villages round the land, seen from it (and only from
// it): a few faces each, coloured by their vertices (tools/levels/alps/
// villages.gd). The sun reaches them as it reaches the ground they stand on:
// beyond the reach of its own shadow the maps of the land say where the
// mountains keep it off (as shaders/alps_ground.gdshader reads them), and the
// shadows of the drifting clouds lie on them.

#include "cloud_shadow.gdshaderinc"

uniform sampler2D far_a : filter_linear_mipmap, repeat_disable;
uniform vec4 far_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D mid_b : filter_linear_mipmap, repeat_disable;
uniform vec4 mid_rect = vec4(0.0);
uniform vec2 shadow_hand_over = vec2(200.0, 280.0);

varying float sun_seen;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float depth = distance(world, CAMERA_POSITION_WORLD);
	float lit = textureLod(far_a, (world.xz - far_rect.xy) * far_rect.zw, 0.0).r;
	vec2 at_mid = (world.xz - mid_rect.xy) * mid_rect.zw;
	if (mid_rect.z > 0.0 && all(greaterThan(at_mid, vec2(0.0))) && all(lessThan(at_mid, vec2(1.0)))) {
		lit = textureLod(mid_b, at_mid, 0.0).a;
	}
	sun_seen = mix(1.0, lit, smoothstep(shadow_hand_over.x, shadow_hand_over.y, depth)) * cloud_light(world.xz, depth);
}

void fragment() {
	// The colours were given as they look, in sRGB.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}

void light() {
	float shade = LIGHT_IS_DIRECTIONAL ? sun_seen : 1.0;
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * shade * LIGHT_COLOR / PI;
}
