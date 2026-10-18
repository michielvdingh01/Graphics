shader_type spatial;

// The face of a stack of firewood: the ends of logs a hand or two across,
// round ones and ones split in half, packed together with the dark between
// them. The fresh ones are pale, the older ones grey; each has its rings,
// and its bark round the rim.
//
// The face has metres for UV.
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float log_size = 0.16;
uniform vec3 fresh : source_color = vec3(0.7, 0.57, 0.4);
uniform vec3 old : source_color = vec3(0.5, 0.46, 0.41);
uniform vec3 bark : source_color = vec3(0.2, 0.16, 0.12);
uniform vec3 deep : source_color = vec3(0.04, 0.035, 0.03);

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	// The logs lie in rows, each row shifted, each log a little bigger or
	// smaller than the next and not quite where the row would have it.
	vec2 at = UV / log_size;
	float row = floor(at.y);
	float best = 1e5;
	vec2 to_heart = vec2(0.0);
	vec2 own = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		float its_row = row + float(y);
		float shift = fract(its_row * 0.5) + hash2(vec2(its_row, 7.0)).x * 0.3;
		float along = at.x + shift;
		for (int x = -1; x <= 1; x++) {
			vec2 c = vec2(floor(along) + float(x), its_row);
			vec2 middle = c + vec2(0.5) + (hash2(c) - 0.5) * 0.25;
			float r = mix(0.4, 0.56, hash2(c + 3.1).x);
			// How far inside its own rim a point is, in log sizes.
			vec2 off = vec2(along, at.y) - middle;
			float d = length(off) - r;
			if (d < best) {
				best = d;
				to_heart = off;
				own = hash2(c + 11.7);
			}
		}
	}
	// A log split in half has a straight face across it.
	float split = step(0.55, own.x);
	float angle = own.y * 6.2832;
	float across = dot(to_heart, vec2(cos(angle), sin(angle)));
	float inside = -best;
	if (split > 0.5) {
		inside = min(inside, across + 0.05);
	}
	float r = length(to_heart) * log_size;
	float rings = 0.5 + 0.5 * sin(r * 230.0 + own.x * 6.0);
	vec3 wood = mix(fresh, old, smoothstep(0.3, 0.9, own.y)) * mix(0.82, 1.0, rings);
	vec3 fine = texture(wear_mask, UV * 2.0).rgb;
	wood *= mix(0.85, 1.08, fine.r);
	float rim = 1.0 - smoothstep(0.02, 0.07, inside);
	vec3 albedo = mix(wood, bark, rim * (1.0 - split * step(abs(across + 0.05), 0.06)));
	float gap = 1.0 - smoothstep(-0.01, 0.015, inside);
	albedo = mix(albedo, deep, gap);
	ALBEDO = albedo;
	ROUGHNESS = 0.92;
	AO = 1.0 - 0.8 * gap;
	vec2 slope = normalize(to_heart + 0.0001) * rim * 0.5;
	NORMAL_MAP = vec3(0.5 + slope.x * 0.5, 0.5 - slope.y * 0.5, 1.0);
}
