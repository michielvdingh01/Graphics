// The shadows of clouds that drift over the land, as scripts/cloud.gd moves
// them: a field of noise, and under a cloud cloud_shade of the sun kept off.
// Close by the sun itself is turned down while a cloud is over the eye
// (cloud_here), for everything it lights; further off a shader that includes
// this shows the shadow that lies there, and takes back what the sun was
// turned down by. Where cloud_shade is nought (every level but one with
// drifting clouds) none of it does anything.
global uniform vec2 cloud_drift;
global uniform float cloud_shade;
global uniform float cloud_here;
global uniform sampler2D cloud_field : filter_linear_mipmap, repeat_enable;

// How much of a full cloud is over the ground at `at`: the same reading as
// over() in scripts/cloud.gd. A cloud is some 800 m across, and about a
// quarter of the land lies under one.
float cloud_over(vec2 at) {
	vec2 q = (at - cloud_drift) / (800.0 * 64.0);
	float n = 0.468 + (textureLod(cloud_field, q, 0.0).r - 0.497) * 0.94;
	return smoothstep(0.5, 0.6, n);
}

// What the sun at `at`, `depth` metres from the eye, is to be taken times.
float cloud_light(vec2 at, float depth) {
	if (cloud_shade <= 0.0) {
		return 1.0;
	}
	float far = smoothstep(120.0, 260.0, depth);
	float here = 1.0 - cloud_shade * cloud_here;
	float there = 1.0 - cloud_shade * cloud_over(at);
	return mix(1.0, there / max(here, 0.05), far);
}
