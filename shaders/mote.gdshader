shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled;

// A speck in the air of open land: pollen, a midge, dust. Like the mote of
// dust in a room (shaders/dust.gdshader) it shows only where light falls on
// it. Out of doors that is nearly everywhere, and a speck against the sky
// is a white dot nobody ever saw: so it shows only near the camera and
// about level with it or below, where what lies behind it is wood, shade
// or ground.
uniform float brightness = 0.2;
// Beyond this many metres a speck is gone.
uniform float reach = 9.0;

varying float shown;

void vertex() {
	// Face the camera, keeping the size the particle was given.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec3 to_it = MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD;
	float far = length(to_it);
	// One that drifts right past the lens would be a blob across the screen.
	shown = smoothstep(0.4, 1.6, far) * smoothstep(reach, reach * 0.6, far);
	shown *= 1.0 - smoothstep(0.04, 0.22, to_it.y / max(far, 0.001));
}

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = (1.0 - smoothstep(0.15, 1.0, length(UV - 0.5) * 2.0)) * COLOR.a * shown;
}

void light() {
	// A speck scatters whatever reaches it, from whichever side.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * brightness;
}
