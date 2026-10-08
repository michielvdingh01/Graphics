shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled;

// A mote of dust: a soft dot that shows only where light falls on it, so the
// air glitters in the sunbeams and under the lamps and nowhere else.
uniform float brightness = 0.35;

varying float nearby;

void vertex() {
	// Face the camera, keeping the size the particle was given.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// One that drifts right past the lens would be a blob across the screen.
	nearby = smoothstep(0.4, 1.6, length(MODELVIEW_MATRIX[3].xyz));
}

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = (1.0 - smoothstep(0.15, 1.0, length(UV - 0.5) * 2.0)) * COLOR.a * nearby;
}

void light() {
	// A mote scatters whatever reaches it, from whichever side.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * brightness;
}
