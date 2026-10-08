shader_type canvas_item;

// Red screen-edge vignette shown when the player is hurt.
uniform float strength = 0.0;

void fragment() {
	float edge = smoothstep(0.25, 0.8, distance(UV, vec2(0.5)));
	COLOR = vec4(0.75, 0.0, 0.0, edge * strength);
}
