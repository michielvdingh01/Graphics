shader_type sky;

// The sky over a parking lot at the end of the afternoon: a scanned sky, tilted
// so that its sun stands where the sun of the level does (see alps_sky.gdshader),
// and the sun itself drawn over it: in this scan it stands behind thin cloud and
// is hardly brighter than the cloud round it. Whoever looks towards it has to
// be blinded a little, which takes a sky that is as bright as a sun.
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
// How bright the disc of the sun is and the glow round it, and how tight each
// is: the higher, the smaller.
uniform float disc = 90.0;
uniform float glow = 7.0;
uniform float disc_tight = 9000.0;
uniform float glow_tight = 90.0;

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
	// Not in the light the sky gives off: only in what is seen of it.
	if (!AT_CUBEMAP_PASS) {
		float toward = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
		COLOR += LIGHT0_COLOR * (disc * pow(toward, disc_tight) + glow * pow(toward, glow_tight)) * (1.0 - below);
	}
}
