shader_type spatial;
render_mode cull_disabled;

// What is strewn on open land from a scan: a fern, a weed, a dead bough, a
// cone, a root. Each is a mesh of its own, with leaves that are leaves and
// not holes in a card; the pieces of a block of ground are merged into one
// mesh, see _strew() in tools/kit/land.gd.
//
// The vertex colour says of every corner how far it bends in the wind (red:
// none at the foot of a plant, none anywhere on wood), where in its sway
// the piece is next to its neighbours (green), and how high over its own
// foot the corner stands, in units of two metres (blue). By the last a
// piece sinks into the ground as it gets too far off to be worth drawing,
// instead of being there one step and gone the next.
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
// The way the wind blows (x and z), and how far it bends a tip, in metres.
uniform vec2 wind = vec2(0.12, 1.0);
uniform float sway = 0.03;
// How much of the sun comes through a leaf from behind.
uniform float through : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
// Between these distances the piece sinks away.
uniform float fade_from = 46.0;
uniform float fade_to = 58.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 downwind = normalize(wind);
	float gust = 0.5 + 0.5 * sin(dot(world.xz, downwind) * 0.19 - TIME * 1.3 + sin(world.x * 0.07 + TIME * 0.21) * 2.0);
	float phase = COLOR.g * 6.283;
	vec2 shiver = vec2(sin(TIME * 3.7 + phase), cos(TIME * 2.9 + phase * 1.7)) * 0.4;
	vec2 push = (downwind * (0.2 + 0.8 * gust) + shiver * (0.3 + 0.7 * gust)) * sway * COLOR.r;
	float sunk = smoothstep(fade_from, fade_to, distance(world, CAMERA_POSITION_WORLD));
	VERTEX += vec3(push.x, -0.3 * length(push) - COLOR.b * 2.0 * sunk, push.y) * mat3(MODEL_MATRIX);
}

void fragment() {
	vec3 leaf = texture(leaf_tex, UV).rgb * tint;
	// The foot of a plant stands in its own shade.
	leaf *= mix(0.55, 1.0, smoothstep(0.0, 0.12, COLOR.b));
	ALBEDO = leaf;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	BACKLIGHT = leaf * through;
	NORMAL_MAP = texture(leaf_normal, UV).rgb;
}
