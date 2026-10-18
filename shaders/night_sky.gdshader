shader_type sky;

// The sky over open land by night, worked out rather than scanned: the moon
// where the light of the level comes from, the glow of the air round it,
// stars, a faint band of the galaxy, and the last of the light low over the
// land. Below the horizon, as in shaders/dune_sky.gdshader, the land as the
// sky would see it.
//
// Nothing in it moves, so the light it gives a level is worked out once: a
// sky that reads TIME is redrawn into the light of the level every frame.
// The stars and the face of the moon are left out of that light, which they
// would only speckle.

// The dark overhead and the lighter dark along the horizon.
uniform vec3 zenith : source_color = vec3(0.006, 0.009, 0.02);
uniform vec3 horizon : source_color = vec3(0.03, 0.04, 0.062);
// A glow low in the sky on the side the moon is not: a town beyond the
// dunes. Its turn from north over east in degrees, and how bright.
uniform vec3 town : source_color = vec3(0.12, 0.075, 0.04);
uniform float town_turn = 20.0;
uniform float town_glow = 0.35;
// The moon: how many degrees across it looks, how bright its face is, and
// the glow of the air round it, how bright and how wide.
uniform float moon_size = 1.6;
uniform vec3 moon_face : source_color = vec3(1.0, 0.97, 0.9);
uniform float moon_bright = 6.0;
uniform float halo = 0.18;
uniform float halo_wide = 5.0;
// How finely the sky is cut into cells for stars, the share of cells that
// has one, and how bright the brightest is; how bright the galaxy is.
uniform float star_cells = 220.0;
uniform float star_share = 0.07;
uniform float star_bright = 3.0;
uniform float galaxy = 0.06;
// What the land sends up: its colour, and how bright it lies under this moon.
uniform vec3 ground : source_color = vec3(0.3, 0.33, 0.4);
uniform float ground_energy = 0.12;
uniform float ground_from = 0.1;
uniform float energy = 1.0;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += noise(p) * weight;
		p = p * 2.03 + 7.1;
		weight *= 0.5;
	}
	return sum;
}

// The stars round `dir`: the sky is cut into cells on the faces of a cube,
// and a cell has a star in it or not, somewhere in it, of some brightness.
// `pixel` is how wide a dot of the screen is, in the units of a face; a
// star is never drawn smaller than that, so that it does not crawl.
vec3 stars(vec3 dir, float pixel) {
	vec3 a = abs(dir);
	vec2 face;
	float side;
	if (a.x > a.y && a.x > a.z) {
		face = dir.yz / a.x;
		side = sign(dir.x);
	} else if (a.y > a.z) {
		face = dir.xz / a.y;
		side = 2.0 + sign(dir.y);
	} else {
		face = dir.xy / a.z;
		side = 4.0 + sign(dir.z);
	}
	vec2 at = face * star_cells;
	vec2 cell = floor(at);
	vec3 seed = vec3(cell, side * 17.0);
	float there = hash(seed);
	if (there > star_share) {
		return vec3(0.0);
	}
	vec2 spot = cell + 0.2 + 0.6 * vec2(hash(seed + 3.1), hash(seed + 5.7));
	float size = max(pixel * star_cells, 0.06);
	float away = length(at - spot) / size;
	float shape = exp(-away * away * 2.2);
	// Few are bright and most are faint.
	float bright = pow(hash(seed + 9.3), 7.0) * star_bright + 0.05;
	// Hot stars are blue, cool ones orange; most are white.
	float heat = hash(seed + 13.7);
	vec3 tint = heat < 0.15 ? vec3(1.0, 0.8, 0.62) : (heat > 0.85 ? vec3(0.75, 0.85, 1.0) : vec3(1.0));
	// The dimmer stars are drawn as large as the screen needs, and so dimmer.
	return tint * bright * shape * min(1.0, 0.06 / size);
}

void sky() {
	vec3 dir = EYEDIR;
	float up = max(dir.y, 0.0);
	vec3 moon = normalize(LIGHT0_DIRECTION);
	float to_moon = dot(dir, moon);
	// The dark, lighter towards the horizon.
	vec3 colour = mix(horizon, zenith, pow(up, 0.45));
	// The town, a low glow on one side.
	vec3 towards_town = vec3(sin(radians(town_turn)), 0.0, -cos(radians(town_turn)));
	float town_side = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), towards_town), 0.0);
	colour += town * town_glow * pow(town_side, 3.0) * exp(-up * 9.0);
	// The air round the moon, lit by it.
	float from_moon = degrees(acos(clamp(to_moon, -1.0, 1.0)));
	colour += moon_face * halo * (exp(-from_moon / halo_wide) + 0.25 * exp(-from_moon / (halo_wide * 5.0)));
	if (!AT_CUBEMAP_PASS) {
		// The band of the galaxy, across the sky from the south east to the
		// north west and nearly overhead.
		vec3 band_pole = normalize(vec3(0.55, 0.35, 0.75));
		float band = exp(-pow(dot(dir, band_pole) / 0.2, 2.0));
		float clouds = fbm(dir * 6.0) * fbm(dir * 17.0 + 3.0);
		float glare = smoothstep(4.0, 30.0, from_moon);
		float seen = smoothstep(0.0, 0.25, up) * glare;
		colour += vec3(0.85, 0.88, 1.0) * galaxy * band * clouds * 2.5 * seen;
		float pixel = length(fwidth(dir));
		colour += stars(dir, pixel) * seen * mix(0.4, 1.0, smoothstep(0.0, 0.5, up));
		// The face of the moon, with its seas.
		float radius = moon_size * 0.5;
		if (from_moon < radius * 1.5) {
			vec3 across = normalize(cross(moon, vec3(0.0, 1.0, 0.0)));
			vec3 over = cross(across, moon);
			vec2 on_face = vec2(dot(dir, across), dot(dir, over)) / sin(radians(radius));
			float r = length(on_face);
			float edge = fwidth(r);
			float disc = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, r);
			float limb = sqrt(max(1.0 - r * r, 0.0));
			float seas = smoothstep(0.45, 0.65, fbm(vec3(on_face * 2.2, 1.3)));
			vec3 face_colour = moon_face * moon_bright * mix(1.0, 0.62, seas) * mix(0.55, 1.0, limb);
			colour = mix(colour, face_colour, disc);
		}
	}
	float below = smoothstep(0.0, -ground_from, dir.y);
	COLOR = mix(colour, ground * ground_energy, below) * energy;
}
