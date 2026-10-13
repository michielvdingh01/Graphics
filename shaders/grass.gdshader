shader_type spatial;
render_mode cull_disabled;

// Grass on a card: a tussock of marram, or a tuft of the fine grass that
// grows low. The texture is a picture of real blades with the gaps between
// them (see tools/render_grass.py), four plants to a picture, and comes
// with one of which way each blade faces. A clump is a few such cards that
// stand through each other, see _clump() and _tuft() in tools/kit/land.gd:
// its corners are handed normals that point up and out of the clump, so
// that it is lit as one mass, like the ground it stands on, and the blades
// only add their own tilt to that.
//
// The vertex colour says what the card cannot: red is how far a corner
// bends in the wind (none at the foot), green where in its sway the clump
// is next to its neighbours, blue how much light gets to the corner (the
// heart of a clump is dark), and alpha how much of the clump is last
// year's straw.
uniform sampler2D blades_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D blades_normal : hint_normal, filter_linear_mipmap, repeat_disable;
// The colour of what is green, and of a clump that is all straw.
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 straw_tint : source_color = vec3(0.8, 0.7, 0.45);
// What counts as a gap from close by, and from far off: seen small, a
// blade blurs into less than half a dot, and a clump would thin out.
uniform float cut_near : hint_range(0.0, 1.0) = 0.42;
uniform float cut_far : hint_range(0.0, 1.0) = 0.14;
// Between these distances the blades thin out to nothing: beyond them the
// clump is not drawn, and the ground shows the grass instead.
uniform float fade_from = 62.0;
uniform float fade_to = 84.0;
// The way the wind blows (x and z), and how far it bends a tip, in metres.
uniform vec2 wind = vec2(0.12, 1.0);
uniform float sway = 0.1;
// How much of the sun comes through a blade from behind.
uniform float through : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 downwind = normalize(wind);
	// Gusts run over the land with the wind, and every clump shivers in
	// them at its own time.
	float gust = 0.5 + 0.5 * sin(dot(world.xz, downwind) * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
	float phase = COLOR.g * 6.283;
	vec2 shiver = vec2(sin(TIME * 3.1 + phase), cos(TIME * 2.3 + phase * 1.7)) * 0.3;
	vec2 push = (downwind * (0.25 + 0.75 * gust) + shiver * (0.4 + 0.6 * gust)) * sway * COLOR.r;
	// A blade that is pushed over comes down a little as well.
	VERTEX += vec3(push.x, -0.35 * length(push), push.y) * mat3(MODEL_MATRIX);
}

void fragment() {
	vec4 blade = texture(blades_tex, UV);
	float depth = -VERTEX.z;
	vec3 colour = blade.rgb * tint;
	colour = mix(colour, vec3(dot(blade.rgb, vec3(0.3, 0.6, 0.1))) * 2.0 * straw_tint, COLOR.a);
	colour *= COLOR.b;
	ALBEDO = colour;
	ALPHA = blade.a;
	ALPHA_SCISSOR_THRESHOLD = mix(mix(cut_near, cut_far, smoothstep(5.0, 40.0, depth)), 1.01, smoothstep(fade_from, fade_to, depth));
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	BACKLIGHT = colour * through * 2.0;
	// The normal of the clump, whichever side of the card is looked at, and
	// from close by the tilt of each blade on it.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float near = 1.0 - smoothstep(10.0, 16.0, depth);
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec3 tilt = vec3(0.5, 0.5, 1.0);
	if (near > 0.0) {
		tilt = textureGrad(blades_normal, UV, dx, dy).rgb;
	}
	NORMAL_MAP = tilt;
	NORMAL_MAP_DEPTH = near;
}
