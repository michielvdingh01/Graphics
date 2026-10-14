shader_type spatial;

// Something painted, dyed or made in the colour of a team: the band round the
// foot of a flag, the dark panels of a football, a ribbon. Whoever shows it
// says which colour that is, with the instance uniforms `team` and `teamed`;
// until then it has `plain`, the colour it has when it is nobody's.
uniform vec3 plain : source_color = vec3(0.05, 0.05, 0.055);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
// How much the rim goes pale where the surface is seen edge on, as cloth does.
uniform float fuzz : hint_range(0.0, 1.0) = 0.0;
uniform float wear : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// Repeats of the mask per metre.
uniform float mask_scale = 3.0;
instance uniform vec3 team : source_color = vec3(0.5, 0.5, 0.5);
instance uniform float teamed = 0.0;

void fragment() {
	vec3 wide = texture(wear_mask, UV * mask_scale).rgb;
	vec3 colour = mix(plain, team, teamed);
	// Handled and knocked about: darker in patches, a shade lighter in others.
	colour *= mix(1.0, 0.7, smoothstep(0.45, 0.8, wide.g) * wear) * mix(0.94, 1.06, wide.b);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(colour, colour * 1.7 + 0.02, rim * fuzz);
	ROUGHNESS = clamp(roughness + (wide.r - 0.5) * 0.25 * wear, 0.05, 1.0);
}
