shader_type canvas_item;

// The picture through a telescopic sight: black all round, a clear circle
// with a darkened rim, and a fine cross with dots to hold off by. On the way
// in the whole view first goes black (`cover`), then the circle opens (`open`).
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform float open : hint_range(0.0, 1.0) = 0.0;
// Width of the view over its height.
uniform float aspect = 1.7778;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float radius = 0.47;
	float inside = 1.0 - smoothstep(radius - 0.006, radius, r);
	float rim = smoothstep(radius * 0.6, radius, r) * 0.6;

	// Hairlines that thicken into posts away from the centre, except upwards.
	vec2 a = abs(p);
	float fine = 0.0007;
	float hair = max(1.0 - smoothstep(fine, fine * 2.0, a.x), 1.0 - smoothstep(fine, fine * 2.0, a.y));
	float post = max(
		(1.0 - smoothstep(0.003, 0.0036, a.y)) * step(0.17, a.x),
		(1.0 - smoothstep(0.003, 0.0036, a.x)) * step(0.17, -p.y) * 0.0 + (1.0 - smoothstep(0.003, 0.0036, a.x)) * step(0.17, p.y));
	float dots = 0.0;
	for (int i = 1; i <= 4; i++) {
		float at = float(i) * 0.034;
		dots = max(dots, 1.0 - smoothstep(0.0022, 0.003, length(vec2(a.x - at, p.y))));
		dots = max(dots, 1.0 - smoothstep(0.0022, 0.003, length(vec2(p.x, a.y - at))));
	}
	float reticle = max(hair * 0.85, max(post, dots)) * inside;

	float dark = max(1.0 - inside, max(rim, reticle));
	COLOR = vec4(0.0, 0.0, 0.0, mix(cover, dark, open));
}
