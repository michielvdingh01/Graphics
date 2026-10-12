shader_type spatial;
render_mode blend_mix, cull_disabled;

// What stays of a pane of glass along the glazing bars once it is broken:
// teeth of the same glass, with the film of dirt the pane had there (see
// materials/glass.tres). Where it broke it is not clear any more: glass that
// has cracked is white, and the edge it broke along catches the light.
// scripts/window.gd makes the teeth.

// The film of dirt on the panes, and how many times it repeats in a metre.
uniform sampler2D film : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 film_scale = vec2(0.3);
uniform float roughness = 0.06;
uniform float specular = 0.8;

// How wide the edge is that a tooth broke along, in metres, and the colour
// of glass seen edge-on.
const float EDGE = 0.009;
const vec3 BROKEN = vec3(0.8, 0.9, 0.87);
// How much less clear the whole of a tooth is than the pane was.
const float CRAZED = 0.15;

void fragment() {
	vec4 dirt = texture(film, UV * film_scale);
	// UV2 is how far it is to each of the two edges the tooth broke along.
	float edge = 1.0 - smoothstep(EDGE * 0.4, EDGE, min(UV2.x, UV2.y));
	ALBEDO = mix(dirt.rgb, BROKEN, max(edge, CRAZED));
	ALPHA = mix(min(dirt.a + CRAZED, 1.0), 0.8, edge);
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
