shader_type canvas_item;

// The lens pass of the Ultra preset as it was: as post.gdshader, plus
// chromatic aberration towards the edges. That needs a copy of the frame to
// read from, which on a full screen of 3456 x 2160 took 0.7 to 0.9 ms more
// than post.gdshader. scripts/lens_fringe.gd now does the aberration on the
// frame before it is enlarged; this is for a renderer that has no place for
// that, and for a benchmark that asks for it (--undo=fringe).
//
// Its grain is added, where post.gdshader can only multiply: the same frame
// comes out 3% lighter here, with as much grain in the dark as in the light.
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float aberration = 0.004;
uniform float vignette = 0.32;
uniform float grain = 0.03;

void fragment() {
	vec2 from_center = SCREEN_UV - 0.5;
	float r2 = dot(from_center, from_center);
	vec2 shift = from_center * r2 * aberration;
	vec3 color = vec3(
		texture(screen, SCREEN_UV + shift).r,
		texture(screen, SCREEN_UV).g,
		texture(screen, SCREEN_UV - shift).b
	);
	color *= 1.0 - vignette * smoothstep(0.1, 0.6, r2);
	float noise = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * vec2(113.0, 71.0), vec2(12.9898, 78.233))) * 43758.5453);
	color += (noise - 0.5) * grain;
	COLOR = vec4(color, 1.0);
}
