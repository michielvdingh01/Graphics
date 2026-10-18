shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The beam of a searchlight in the night air: a cone along the beam that
// adds light to whatever is behind it. Most where the eye looks through the
// thick of it, which is down its middle, and near the lamp, and gone before
// its end: it is shorter than the beam itself, and thins out before it
// reaches the ground, so that it shows no edge there without reading the
// depth of the picture (which cost more than the beams). It is the light the
// night air throws back, at a fraction of the cost of fog that does so for
// real. See light_beam() in tools/kit/field.gd. By day there is no beam to
// see (the global "night").
uniform vec3 colour : source_color = vec3(0.9, 0.94, 1.0);
uniform float strength = 0.05;
uniform float beam_length = 60.0;
global uniform float night;

varying float along;

void vertex() {
	// The cylinder of a CylinderMesh runs from its top (the lamp) at +Y to
	// its bottom at -Y, `beam_length` long.
	along = clamp(0.5 - VERTEX.y / beam_length, 0.0, 1.0);
}

void fragment() {
	// Down the middle of the cone the eye looks through more of it.
	float through = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	// Thinner as it spreads, and gone at its end.
	float spread = pow(1.0 - along, 2.2);
	// And closer than a few metres to the eye it fades, so that nobody
	// standing in it sees a wall of light.
	float near = smoothstep(1.0, 6.0, -VERTEX.z);
	ALBEDO = colour * strength * through * spread * near * night;
}
