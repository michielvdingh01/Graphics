shader_type spatial;

// The glass of a window seen from outside by day: the room behind it is
// dark, so what shows is the sky that lies on it. No two panes of an old
// window lie in quite the same plane, and each gives back its own patch of
// sky. Dust has settled on them, most along their lower bars. Some have
// been painted over, and a few are gone.
//
// The builder gives each pane one colour for all four of its corners: red
// and green are how far it leans to the side and back (a half is not at
// all), blue how dirty it is, and alpha what has become of it: nought for
// glass, a half for painted over, one for gone. UV is its position in metres.
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// What a clean pane gives back of the sky when it is looked at straight on.
uniform vec3 mirror : source_color = vec3(0.34, 0.38, 0.42);
uniform vec3 film : source_color = vec3(0.3, 0.29, 0.25);
uniform vec3 painted : source_color = vec3(0.36, 0.4, 0.36);
uniform float lean = 0.07;
uniform float dirt : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec3 mask = texture(wear_mask, UV * 0.7).rgb;
	float gone = step(0.75, COLOR.a);
	float over = step(0.25, COLOR.a) * (1.0 - gone);
	float dusty = clamp(COLOR.b * dirt * (0.35 + 0.9 * mask.r) + smoothstep(0.62, 0.8, mask.g) * 0.25 * dirt, 0.0, 1.0);

	vec3 albedo = mix(mirror, film, dusty);
	float metal = 1.0 - dusty * 0.85;
	float rough = mix(0.035, 0.55, dusty);
	albedo = mix(albedo, painted * (0.75 + 0.5 * mask.b), over);
	metal = mix(metal, 0.0, over);
	rough = mix(rough, 0.8, over);
	albedo = mix(albedo, vec3(0.012, 0.013, 0.015), gone);
	metal = mix(metal, 0.0, gone);
	rough = mix(rough, 1.0, gone);

	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = mix(0.5, 0.0, gone);
	vec2 tilt = (COLOR.rg - 0.5) * 2.0 * lean * (1.0 - gone);
	NORMAL = normalize(NORMAL + TANGENT * tilt.x + BINORMAL * tilt.y);
}
