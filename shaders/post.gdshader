shader_type canvas_item;
render_mode blend_mul;

// Final lens pass over the tonemapped frame: vignette and animated film
// grain, multiplied onto the frame so that nothing has to be read back from
// it. Keep it subtle. The Ultra preset swaps in post_aberration.gdshader.
uniform float vignette = 0.32;
uniform float grain = 0.03;

void fragment() {
	vec2 from_center = SCREEN_UV - 0.5;
	float r2 = dot(from_center, from_center);
	float noise = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * vec2(113.0, 71.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3((1.0 - vignette * smoothstep(0.1, 0.6, r2)) * (1.0 - noise * grain * 2.0)), 1.0);
}
