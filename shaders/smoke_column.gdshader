shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// The smoke of a small fire, seen from far off: a thread that rises
// straight for a few metres, then leans with the wind, widens and thins
// out. It is drawn on cards that stand on the fire and turn about their
// height to face whoever looks. A corner of a card says in UV which side of
// the column it is (x) and how far up it (y), and in UV2.x how many metres
// high the column is; where the corner really stands is worked out here.
// By night (the global "night", see Settings.apply()) it is grey only as far
// as the moon makes it, and the fire under it lights its foot.
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 smoke_color : source_color = vec3(0.62, 0.62, 0.64);
uniform float density : hint_range(0.0, 1.0) = 0.36;
// How wide the column is at its foot and at its top, in metres.
uniform float foot = 0.14;
uniform float crown = 3.6;
// Which way the wind takes it, and how far by the time it is at its top.
uniform vec2 wind = vec2(0.1, 0.86);
uniform float drift = 9.0;
uniform float rise = 0.045;
// What is left of its colour by night, and the light of the fire on it.
uniform float moonlit = 0.07;
uniform vec3 firelight : source_color = vec3(1.0, 0.42, 0.14);
global uniform float night;

varying float up;
varying float turn;

void vertex() {
	up = UV.y;
	turn = COLOR.r;
	float high = UV2.x;
	vec3 base = (MODEL_MATRIX * vec4(VERTEX.x, VERTEX.y - up * high, VERTEX.z, 1.0)).xyz;
	// It leans more the higher it gets, and sways a little as it goes.
	vec2 lean = wind * drift * up * up + vec2(sin(TIME * 0.31 + up * 5.0), cos(TIME * 0.23 + up * 4.0)) * 0.5 * up;
	vec3 middle = base + vec3(lean.x, up * high, lean.y);
	vec3 to_eye = CAMERA_POSITION_WORLD - middle;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye));
	float wide = mix(foot, crown, pow(up, 0.75));
	vec3 at = middle + side * (UV.x * 2.0 - 1.0) * wide * (1.0 + turn * 0.6);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(at, 1.0)).xyz;
}

void fragment() {
	// Puffs that climb the card: two layers at different speeds.
	vec2 at = vec2(UV.x * 1.6 + turn * 0.37, up * 7.0 - TIME * rise * 4.0);
	float puffs = texture(noise_tex, at).r * 0.6 + texture(noise_tex, at * 2.3 + vec2(0.2, -TIME * rise * 5.0)).b * 0.4;
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float body = pow(smoothstep(0.0, 0.8, across), 1.5) * smoothstep(0.38, 0.75, puffs + across * 0.3);
	// Thin at the fire, where it is hot and clear, and gone at the top.
	float life = smoothstep(0.0, 0.1, up) * (1.0 - smoothstep(0.4, 1.0, up));
	vec3 day = smoke_color * mix(0.75, 1.1, puffs);
	ALBEDO = mix(day, day * moonlit + firelight * 0.5 * exp(-up * 9.0), night);
	ALPHA = body * life * density * (1.0 - 0.3 * turn);
}
