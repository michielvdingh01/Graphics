shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;

// The pressure wave of an explosion: a shell of air that runs out from the
// centre and bends what is seen through it. The mesh is a unit sphere, which
// the shader blows up to `reach` metres over `life` seconds. Only its rim
// bends the view, so what is seen is a ring that widens and fades.
//
// It reads the picture back, which costs a copy of the screen for as long as
// one is in view: a third of a second for each explosion.
#include "fx_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;

instance uniform float start = -100.0;
instance uniform float reach = 6.0;
instance uniform float life = 0.32;

varying float course;

void vertex() {
	float age = fx_time - start;
	course = clamp(age / life, 0.0, 1.0);
	// Fast at first, slowing as it thins.
	VERTEX *= reach * (1.0 - (1.0 - course) * (1.0 - course));
	if (age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	// Most just inside the outline, and nothing on the outline itself, which
	// would otherwise show as a line.
	float bend = pow(rim, 3.0) * (1.0 - smoothstep(0.7, 1.0, rim)) * (1.0 - course) * (1.0 - course);
	vec2 outwards = normalize(NORMAL.xy + vec2(0.00001, 0.0));
	// Further off it covers less of the picture, so it bends it less far.
	vec2 shift = outwards * bend * 0.35 / max(-VERTEX.z, 1.0);
	ALBEDO = texture(screen, SCREEN_UV - shift).rgb;
	ALPHA = smoothstep(0.0, 0.02, bend);
}
