shader_type sky;

// The sky over the Alps: a scanned sky, tilted a few degrees towards the sun
// so that its sun stands where the sun of the level does, and below the
// horizon the land as the sky sees it, as over the dunes (dune_sky.gdshader).
//
// The scan has its sun at 7.2 degrees; the level wants it higher. Turning the
// whole sky about the level line across the sun's way lifts the sky on the
// sun's side and lowers it on the other, where the Zugspitze stands in front
// of the lowest of it.
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform vec3 ground : source_color = vec3(0.3, 0.32, 0.22);
uniform float ground_energy = 0.6;
uniform float ground_from = 0.1;
uniform float energy = 1.0;
// How far the scan is turned round, as a share of a whole turn.
uniform float turn = 0.0;
// Where the sun stands, round from north by east, and how many degrees the
// sky is tilted up on that side.
uniform float sun_turn_deg = 230.0;
uniform float tilt_deg = 4.3;

void sky() {
	float a = radians(sun_turn_deg);
	vec3 axis = vec3(cos(a), 0.0, sin(a));
	float t = -radians(tilt_deg);
	vec3 d = EYEDIR;
	// Rodrigues: d turned by t about the axis.
	d = d * cos(t) + cross(axis, d) * sin(t) + axis * dot(axis, d) * (1.0 - cos(t));
	vec2 coords = vec2(atan(d.x, -d.z) / 6.2831853, acos(clamp(d.y, -1.0, 1.0)) / 3.1415927);
	vec2 at = vec2(fract(coords.x - turn), coords.y);
	// The steps from one dot to the next are taken from the coordinates as
	// they run without the turn, which have no seam where the scan wraps.
	vec3 above = textureGrad(panorama, at, dFdx(SKY_COORDS), dFdy(SKY_COORDS)).rgb;
	float below = smoothstep(0.0, -ground_from, EYEDIR.y);
	COLOR = mix(above, ground * ground_energy, below) * energy;
}
