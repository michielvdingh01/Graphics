shader_type spatial;

// The peel of a banana. UV.x runs along it from the cut end of the stalk, 0,
// to the tip, 1, and UV.y once round it; the five ridges a banana has lie at
// every fifth of that. Green near the stalk, brown at both ends, a shade
// darker along the ridges, and freckled the riper it is.
uniform vec3 peel : source_color = vec3(0.93, 0.74, 0.1);
uniform vec3 unripe : source_color = vec3(0.42, 0.55, 0.12);
uniform vec3 bruise : source_color = vec3(0.17, 0.09, 0.03);
uniform float ripe : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float mask_scale = 1.0;

void fragment() {
	float along = UV.x;
	vec3 wide = texture(wear_mask, vec2(along * 1.9, UV.y * 0.9) * mask_scale).rgb;
	vec3 fine = texture(wear_mask, vec2(along * 7.0, UV.y * 3.3) * mask_scale + vec2(0.37, 0.11)).rgb;
	vec3 colour = peel * mix(0.9, 1.07, fine.r);
	colour = mix(colour, unripe, smoothstep(0.26, 0.07, along) * 0.8);
	float ridge = pow(0.5 + 0.5 * cos(UV.y * TAU * 5.0), 8.0);
	float body = smoothstep(0.08, 0.25, along) * smoothstep(0.99, 0.85, along);
	colour *= mix(1.0, 0.8, ridge * body);
	float freckles = smoothstep(0.86 - 0.3 * ripe, 0.93 - 0.3 * ripe, wide.b * 0.55 + fine.g * 0.55);
	colour = mix(colour, bruise * 1.6, freckles * 0.85 * body);
	// The stalk is cut off brown, and the tip is what is left of the flower.
	colour = mix(colour, bruise, smoothstep(0.035, 0.0, along));
	colour = mix(colour, bruise, smoothstep(0.93, 0.985, along));
	ALBEDO = colour;
	ROUGHNESS = clamp(roughness + (fine.b - 0.5) * 0.12 + 0.3 * freckles, 0.05, 1.0);
}
