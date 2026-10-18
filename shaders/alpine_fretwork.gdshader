shader_type spatial;
render_mode cull_disabled;

// The boards of the balcony of a farmhouse in Tyrol, sawn into balusters:
// side by side, each cut along both edges, so that between one board and the
// next a figure is left open, a vase with a waist and a round head. The wood
// has gone as dark as the rest of the upper floor.
//
// The face has metres for UV: U along the balcony and V down from the top of
// its boards, the boards `board` wide and the figure in the middle `high` of
// them. See _farm_balcony() in tools/kit/alpine.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scan_mean = 0.06;
uniform vec3 grey : source_color = vec3(0.34, 0.28, 0.23);
uniform vec3 burnt : source_color = vec3(0.24, 0.15, 0.09);
uniform vec2 sun_side = vec2(0.15, 0.99);
uniform float board = 0.16;
uniform float high = 0.95;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Where in the height of the boards, 0 at the top of the figure and 1 at
	// its foot, and how far from the joint between two boards.
	float t = (UV.y - 0.12) / (high - 0.24);
	float from_joint = abs(fract(UV.x / board + 0.5) - 0.5) * board;
	if (t > 0.0 && t < 1.0) {
		// The head, the waist, the belly and the foot of the vase.
		float head = 0.034 * sqrt(max(1.0 - pow((t - 0.12) / 0.12, 2.0), 0.0));
		float belly = 0.04 * sqrt(max(1.0 - pow((t - 0.6) / 0.33, 2.0), 0.0));
		float neck = 0.012 * step(0.2, t) * step(t, 0.32);
		if (from_joint < max(max(head, belly), neck)) {
			discard;
		}
	}
	vec3 scan = texture(albedo_tex, UV * vec2(0.6, 0.5)).rgb;
	float lum = dot(scan, vec3(0.299, 0.587, 0.114)) / scan_mean;
	float sunny = smoothstep(-0.2, 0.9, dot(world_normal.xz, sun_side));
	vec3 wood = mix(grey, burnt, sunny) * mix(1.0, lum, 0.8);
	// The joint between two boards.
	wood *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 0.004, from_joint));
	ALBEDO = clamp(wood, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.9;
	NORMAL_MAP = texture(normal_tex, UV * vec2(0.6, 0.5)).rgb;
}
