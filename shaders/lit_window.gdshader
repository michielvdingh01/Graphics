shader_type spatial;

// A window that somebody is at home behind, by night: the room glows warm,
// brighter towards the lamp under its ceiling, and curtains are drawn some
// way across from either side. The glass still mirrors the street.
//
// The level builder gives every window a UV of its own: its x runs from a
// whole number to the next across the glass, and that number tells one
// window from the other; its y runs from 0 at the sill to 1 at the head.
uniform vec3 room : source_color = vec3(1.0, 0.68, 0.4);
uniform float energy = 1.6;

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

void fragment() {
	vec2 uv = vec2(fract(UV.x), UV.y);
	float id = floor(UV.x);
	float r = hash(id);
	// The lamp hangs under the ceiling, somewhere over the middle.
	vec2 lamp = vec2(mix(0.3, 0.7, hash(id + 1.0)), 1.15);
	float glow = mix(0.32, 1.0, exp(-2.2 * distance(uv, lamp)));
	// Curtains: how far they are drawn, their folds, and their colour.
	float drawn = mix(0.08, 0.36, r);
	float gap = smoothstep(drawn - 0.03, drawn, uv.x) * smoothstep(drawn - 0.03, drawn, 1.0 - uv.x);
	float folds = 0.8 + 0.2 * sin(uv.x * 70.0 + r * 9.0);
	vec3 cloth = mix(vec3(0.9, 0.42, 0.22), vec3(0.95, 0.85, 0.6), hash(id + 2.0)) * folds * 0.4;
	vec3 seen = mix(cloth, vec3(1.0), gap) * glow;
	ALBEDO = vec3(0.02);
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	EMISSION = room * seen * energy * mix(0.6, 1.25, hash(id + 3.0));
}
