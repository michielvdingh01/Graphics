shader_type spatial;
render_mode cull_disabled;

// Paint on concrete, out of doors: a line on a road, a band on a kerb, a
// number stencilled on a wall. The colour of the paint comes with each
// point from the builder, and with it, as its alpha, how much of the wear
// of paint on a road it has had. The paint has worn off in patches, and what is
// left of it has gone dull. With `stencil`, the paint is only where that
// texture is, and the builder gives the place in it as UV2.
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D stencil : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float worn : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 wide = texture(wear_mask, UV * 0.19).rgb;
	vec3 fine = texture(wear_mask, UV * 1.7 + vec2(0.13, 0.71)).rgb;
	// How much of that wear this paint has had comes with its colour.
	float wear = worn * COLOR.a;
	float left = smoothstep(wear - 0.08, wear + 0.08, wide.r * 0.5 + fine.g * 0.3 + fine.b * 0.35);
	// The stencil comes worn; what is left of a letter is taken for all of it.
	float ink = smoothstep(0.06, 0.3, texture(stencil, UV2).a);
	ALBEDO = COLOR.rgb * mix(0.72, 1.0, wide.b) * mix(0.85, 1.0, fine.r);
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
	ALPHA = ink * mix(0.25, 1.0, left);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
