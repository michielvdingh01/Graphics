shader_type spatial;
render_mode cull_disabled;

// A camouflage net: knotted cord with strips of scrim threaded through it,
// see _net() in tools/gen_foliage.gd. More than a third of it is hole. The
// scrim is thin: with the sun behind it a strip is lit through, so that from
// its shadow side a net is a pattern of lit strips and sky and not a dark
// mass. Every strip is rounded and lies over or under the next, in a normal
// map drawn with the same dice.
//
// UV is its place in metres. It moves in the wind as canvas does, and says
// in UV2 how: see shaders/canvas.gdshader.
uniform sampler2D net_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D net_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// How many times the picture, two metres of net, goes into a metre.
uniform float scale = 0.5;
uniform float cut : hint_range(0.0, 1.0) = 0.5;
uniform float relief : hint_range(0.0, 2.0) = 1.0;
// What a strip lets through of the sun, and its colour by then.
uniform vec3 lit_through : source_color = vec3(0.6, 0.58, 0.36);
uniform float through : hint_range(0.0, 4.0) = 0.9;
uniform vec2 wind = vec2(0.12, 1.0);

void vertex() {
	if (UV2.x > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 downwind = normalize(wind);
		float run = dot(world.xz, downwind);
		float gust = 0.5 + 0.5 * sin(run * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
		float swell = sin(run * 0.9 + world.y * 0.6 - TIME * 1.7);
		float flutter = sin(run * 4.3 + world.y * 2.9 - TIME * 6.1) * 0.6 + sin(dot(world.xz, vec2(-downwind.y, downwind.x)) * 3.1 + world.y * 1.7 - TIME * 4.3) * 0.4;
		float moves = (gust - 0.4) * 0.8 + swell * (0.15 + 0.3 * gust) + flutter * UV2.y * (0.15 + 0.3 * gust);
		mat3 turned = mat3(MODEL_MATRIX);
		vec3 blows = normalize(vec3(downwind.x, 0.3, downwind.y));
		vec3 faces = normalize(turned * NORMAL);
		vec3 goes = mix(faces * (dot(faces, blows) < 0.0 ? -1.0 : 1.0), blows, UV2.y);
		VERTEX += (goes * turned) * moves * UV2.x;
	}
}

void fragment() {
	vec4 net = texture(net_tex, UV * scale);
	float far = smoothstep(8.0, 60.0, -VERTEX.z);
	ALBEDO = net.rgb;
	ALPHA = net.a;
	// From far off the holes are smaller than a dot of the screen: the net
	// keeps as much hole as it has, and does not close up.
	ALPHA_SCISSOR_THRESHOLD = mix(cut, 0.62, far);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	NORMAL_MAP = texture(net_normal, UV * scale).rgb;
	NORMAL_MAP_DEPTH = relief * (1.0 - far);
	BACKLIGHT = lit_through * through;
}
