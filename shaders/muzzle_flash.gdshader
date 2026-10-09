shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// Muzzle flash. The mesh points along -Z from the muzzle: flat cards down
// the length of the flame, which is what is seen from the side, and one card
// across it, which is what the shooter and the target see. Every shot gets a
// seed, so no two flashes are alike, and the flame is gone `life` seconds
// after `start`.
//
// UV2.x says which card a point is on: 0 down the length, 1 across.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
instance uniform float seed = 0.0;
instance uniform float life = 0.045;
instance uniform vec3 tint : source_color = vec3(1.0, 0.62, 0.25);
// Number of tongues the flash hider splits the flame into; 0 leaves it round.
instance uniform float prongs = 4.0;

varying float course;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

// Smooth noise along a line, the same after `period`.
float wave(float x, float period) {
	float cell = floor(x);
	float t = smoothstep(0.0, 1.0, x - cell);
	return mix(hash(mod(cell, period)), hash(mod(cell + 1.0, period)), t);
}

void vertex() {
	course = clamp((fx_time - start) / life, 0.0, 1.0);
	// It is at its largest at once and shrinks back into the muzzle.
	VERTEX *= mix(1.0, 0.45, course * course);
	if (fx_time < start || fx_time > start + life) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float flame;
	if (UV2.x > 0.5) {
		// Across: a small hot ball with tongues of unequal length around it,
		// and thin streaks of burning powder between those.
		vec2 p = UV * 2.0 - 1.0;
		float radius = length(p);
		float turn = atan(p.y, p.x) / TAU + 0.5;
		float ragged = wave(turn * 31.0, 31.0);
		float streaks = pow(wave(turn * 17.0 + 0.3, 17.0), 4.0);
		float reach = 0.18 + 0.1 * ragged + 0.32 * streaks;
		if (prongs > 0.5) {
			float tongue = pow(abs(cos(turn * PI * prongs)), 5.0);
			reach += tongue * (0.2 + 0.5 * wave(turn * prongs + 0.5, prongs)) * (0.75 + 0.25 * ragged);
		} else {
			reach += 0.12 + 0.3 * wave(turn * 5.0, 5.0);
		}
		flame = smoothstep(reach, 0.0, radius);
		flame *= flame;
	} else {
		// Down the length: wide just past the muzzle, tapering to a ragged tip.
		float along = UV.y;
		float width = sin(pow(along, 0.55) * PI) * (0.55 + 0.45 * wave(along * 5.0 + 3.0, 64.0));
		float tip = 0.55 + 0.45 * hash(2.0 + floor(UV2.y * 8.0));
		float side = abs(UV.x - 0.5) * 2.0;
		flame = smoothstep(width, width * 0.2, side) * smoothstep(tip, tip * 0.5, along) * smoothstep(0.0, 0.04, along);
	}
	flame *= 1.0 - course * course;
	// White where it is hottest, the colour of the powder towards the edge.
	ALBEDO = mix(tint, vec3(1.0, 0.95, 0.8), smoothstep(0.3, 0.9, flame)) * mix(4.0, 20.0, flame);
	ALPHA = flame;
}
