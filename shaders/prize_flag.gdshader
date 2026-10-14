shader_type spatial;
render_mode cull_disabled;

// The cloth of a flag: the colour of a team with a pale chevron on it, moved
// by a wind that is in no level. The mesh lies flat in its own x and y: x
// runs from the mast, where UV.x is 0, to the fly end, where it is 1, and y
// is up, with UV.y 0 along the top. It is drawn from both sides.
//
// Whoever shows it says whose it is with `team` and `teamed`, as for
// team.gdshader, how hard it blows with `wind`, and gives every flag a
// `phase` of its own so that two of them do not move in step.
uniform vec3 plain : source_color = vec3(0.6, 0.58, 0.53);
uniform vec3 mark : source_color = vec3(0.9, 0.88, 0.82);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform sampler2D grain : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_scale = 30.0;
uniform float grain_depth : hint_range(0.0, 2.0) = 0.6;
// Metres from the mast to the fly end.
uniform float fly = 0.9;
instance uniform vec3 team : source_color = vec3(0.5, 0.5, 0.5);
instance uniform float teamed = 0.0;
// 0 hangs down along the mast, 1 stands straight out.
instance uniform float wind = 0.75;
instance uniform float phase = 0.0;

// How far the cloth stands off its own plane `along` of the way to the fly
// end, in metres: waves that run to the fly end and grow on the way.
float billow(float along, float down, float time) {
	float waves = sin(along * 8.0 - time * 4.2 + down * 1.9) * 0.5
		+ sin(along * 15.0 - time * 6.9 - down * 3.1 + 1.3) * 0.22
		+ sin(along * 3.6 - time * 2.4 + 0.6) * 0.4;
	return waves * along * (0.3 + 0.7 * along) * fly * (0.05 + 0.07 * wind);
}

void vertex() {
	float time = TIME * (1.3 + 1.5 * wind) + phase;
	float along = UV.x;
	float further = 0.02;
	float here = billow(along, UV.y, time);
	float ahead = billow(along + further, UV.y, time);
	// With little wind the fly end comes down and in towards the mast.
	float limp = 1.0 - wind;
	VERTEX.z += here;
	VERTEX.y -= along * along * fly * (0.1 + 0.7 * limp);
	VERTEX.x -= along * along * fly * 0.42 * limp;
	NORMAL = normalize(vec3(-(ahead - here) / (further * fly), 0.0, 1.0));
}

void fragment() {
	vec3 cloth = mix(plain, team, teamed);
	// The chevron: its point towards the mast, its arms to the corners of the fly.
	float beside = (UV.x - 0.26) - abs(UV.y - 0.5) * 0.85;
	float chevron = smoothstep(0.0, 0.012, beside) * (1.0 - smoothstep(0.17, 0.182, beside));
	vec3 colour = mix(cloth, mark, chevron);
	// A hem all round, where the cloth is double.
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	colour *= mix(0.78, 1.0, smoothstep(0.012, 0.03, edge));
	ALBEDO = colour;
	ROUGHNESS = roughness;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL_MAP = texture(grain, UV * grain_scale * vec2(fly, fly * 0.67)).rgb;
	NORMAL_MAP_DEPTH = grain_depth;
	// Light comes through it.
	BACKLIGHT = colour * 0.3;
}
