shader_type sky;

// The sky over open land: a scanned sky above the horizon, and below it the
// land as the sky would see it. A scanned "pure sky" has the sky mirrored
// under its horizon, as over water: everything that faces down, the
// underside of a crown, a wall in the shade, a man's chin, was lit blue from
// below. Sand in the sun throws warm light back up, and that is most of
// what lights the shade of a dune.
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
// What the land sends up: its colour, and how bright it lies under this sun.
uniform vec3 ground : source_color = vec3(0.62, 0.52, 0.38);
uniform float ground_energy = 0.8;
// How far under the horizon the land has taken over from the sky, as the
// height of the look (the sine of its angle).
uniform float ground_from = 0.1;
uniform float energy = 1.0;
// How far the scan is turned round, as a share of a whole turn: so that the
// sun in it stands where the sun of the level does.
uniform float turn = 0.0;

void sky() {
	// Turned, the place where the scan wraps round lies somewhere else in the
	// sky; the steps from one dot to the next are taken from the scan as it
	// lies, which has no seam there.
	vec2 at = vec2(fract(SKY_COORDS.x - turn), SKY_COORDS.y);
	vec3 above = textureGrad(panorama, at, dFdx(SKY_COORDS), dFdy(SKY_COORDS)).rgb;
	float below = smoothstep(0.0, -ground_from, EYEDIR.y);
	COLOR = mix(above, ground * ground_energy, below) * energy;
}
