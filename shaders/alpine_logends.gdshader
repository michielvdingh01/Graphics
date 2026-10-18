shader_type spatial;

// The face of a stack of firewood: the ends of split logs a hand or two
// across, round ones and halves and quarters, packed together with dark gaps
// between them. The fresh ones are pale, the older ones grey; each has its
// rings, and the split ones their bark on the round side.
//
// The face has metres for UV.
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float log_size = 0.15;
uniform vec3 fresh : source_color = vec3(0.68, 0.55, 0.38);
uniform vec3 old : source_color = vec3(0.45, 0.42, 0.38);
uniform vec3 bark : source_color = vec3(0.22, 0.17, 0.13);

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	vec2 at = UV / log_size;
	vec2 cell = floor(at);
	float nearest = 8.0;
	float second = 8.0;
	vec2 heart = vec2(0.0);
	vec2 which = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 site = c + 0.15 + 0.7 * hash2(c);
			float d = length(at - site);
			if (d < nearest) {
				second = nearest;
				nearest = d;
				heart = site;
				which = c;
			} else if (d < second) {
				second = d;
			}
		}
	}
	vec2 own = hash2(which + 31.0);
	// How far into its log a point is: nought at the gap.
	float inside = second - nearest;
	// A log that was split has its heart at its round side, where the bark is.
	vec2 to_heart = at - heart;
	float r = length(to_heart) * log_size;
	float rings = 0.5 + 0.5 * sin(r * 220.0 + own.x * 6.0);
	vec3 wood = mix(fresh, old, own.y) * mix(0.8, 1.0, rings);
	vec3 fine = texture(wear_mask, UV * 2.0).rgb;
	wood *= mix(0.85, 1.08, fine.r);
	float rim = 1.0 - smoothstep(0.04, 0.1, inside);
	vec3 albedo = mix(wood, bark, rim * step(0.35, own.x));
	float gap = 1.0 - smoothstep(0.0, 0.035, inside);
	albedo *= 1.0 - 0.92 * gap;
	ALBEDO = albedo;
	ROUGHNESS = 0.92;
	AO = 1.0 - 0.7 * gap;
	// Each end bulges a little from its gap.
	vec2 slope = normalize(to_heart + 0.0001) * gap * 0.6;
	NORMAL_MAP = vec3(0.5 + slope.x * 0.5, 0.5 - slope.y * 0.5, 1.0);
}
