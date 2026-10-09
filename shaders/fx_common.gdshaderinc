// Shared by the effect shaders. A burst is one mesh of quads, one per
// particle, and where each particle is follows from its age alone: nothing
// is simulated from frame to frame, so a burst costs no script time while it
// plays. scripts/fx.gd builds the meshes and keeps fx_time running.
//
// Every particle carries its own random numbers: three in VERTEX (-1 to 1), a
// random direction in NORMAL, two more in UV2 (0 to 1). UV is the corner of
// its quad.

global uniform float fx_time;

const float GRAVITY = 9.8;

// Where something thrown from `p` at velocity `v` is `t` seconds later. It
// bounces twice off a floor at height `floor_y`; the third time down it stays
// down. `v` comes back as its velocity at that moment and `air` as the time
// it has spent in flight so far.
vec3 ballistic(vec3 p, inout vec3 v, float t, float floor_y, float bounce, out float air) {
	air = 0.0;
	// Something that starts below the floor has no floor to land on.
	if (p.y >= floor_y) {
		for (int i = 0; i < 3; i++) {
			float land = (v.y + sqrt(v.y * v.y + 2.0 * GRAVITY * (p.y - floor_y))) / GRAVITY;
			if (t < land) {
				break;
			}
			p += v * land;
			p.y = floor_y;
			air += land;
			t -= land;
			if (i == 2) {
				v = vec3(0.0);
				return p;
			}
			v = vec3(v.x * 0.55, (GRAVITY * land - v.y) * bounce, v.z * 0.55);
		}
	}
	air += t;
	p += v * t - vec3(0.0, 0.5 * GRAVITY * t * t, 0.0);
	v.y -= GRAVITY * t;
	return p;
}

// A direction within a cone around +Y: `spread` 0 is straight along it, 1 is
// anywhere in the half space.
vec3 cone(vec3 random_direction, float spread) {
	return normalize(mix(vec3(0.0, 1.0, 0.0), vec3(random_direction.x, abs(random_direction.y), random_direction.z), spread));
}

vec2 turned(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}
