shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

// The rings a shot leaves on a puddle: a few of them run out from where it
// landed, each lower than the one before, and die away within a second or
// so. They are drawn on one card that lies flat just above the floor, as
// water that is tilted a little: it mirrors what the puddle mirrors a little
// to one side, catches the light on its crests and is dark in its troughs.
// The card reads the mask of the floor as shaders/wet_floor.gdshader does,
// so the rings are only there where water stands and stop at its shore.
#include "fx_common.gdshaderinc"

// The mask of the floor the puddle lies on, its `mask_scale`, and the least
// the mask has to be for water to stand: one less its `puddle_amount`.
uniform sampler2D wet_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float mask_scale = 0.045;
uniform float level = 0.58;

instance uniform float start = -100.0;
// UV of the floor where the shot landed, and what a metre along the X and a
// metre along the Z of the world add to it.
instance uniform vec2 floor_uv = vec2(0.0);
instance uniform vec4 floor_uv_step = vec4(1.0, 0.0, 0.0, 1.0);
// How far the first ring gets in metres, and how long it takes to.
instance uniform float reach = 0.9;
instance uniform float life = 1.4;
// How steep the rings are: 1 for those of a bullet.
instance uniform float steep = 1.0;
// A burst of rings is one card; rehearse() leaves it out with less than none.
instance uniform float amount = 1.0;

// Metres from one ring to the next, and how far above the floor the card lies.
const float SPACING = 0.11;
const float LIFT = 0.003;
// The steepest a ring is, as a slope.
const float STEEPEST = 0.4;
// What wet_floor.gdshader adds to its mask for a ragged shore, and how wide
// it makes the shore.
const float PATCHY = 0.37;
const float RAGGED = 0.09;
const float SHORE = 0.035;

varying vec2 place;
varying vec2 mask_uv;
varying vec3 right;
varying vec3 forward;
varying vec3 up;
varying float front;
varying float calm;

void vertex() {
	float age = fx_time - start;
	float course = clamp(age / life, 0.0, 1.0);
	// The first ring leaves fast and slows down as it runs out, and all of
	// them flatten as they go.
	front = reach * 0.95 * (1.0 - (1.0 - course) * (1.0 - course));
	calm = smoothstep(0.0, 0.05, course) * (1.0 - smoothstep(0.3, 1.0, course));

	mat3 frame = mat3(MODEL_MATRIX);
	// Metres from where the shot landed, along the card, which is no larger
	// than the rings have got.
	place = (UV * 2.0 - 1.0) * (front + 0.02);
	vec3 offset = frame[0] * place.x + frame[2] * place.y;
	mask_uv = floor_uv + floor_uv_step.xy * offset.x + floor_uv_step.zw * offset.z;
	right = mat3(VIEW_MATRIX) * frame[0];
	forward = mat3(VIEW_MATRIX) * frame[2];
	up = mat3(VIEW_MATRIX) * frame[1];
	VERTEX = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz + offset + frame[1] * LIFT, 1.0)).xyz;
	NORMAL = up;
	if (age < 0.0 || age > life || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	float mask = texture(wet_mask, mask_uv * mask_scale).r + (texture(wet_mask, mask_uv * PATCHY).r - 0.5) * RAGGED;
	float puddle = smoothstep(level, level + SHORE, mask);

	float radius = length(place);
	// How many rings a point lies behind the first. There is nothing ahead
	// of it, and every ring behind it is lower than the one before.
	float behind = (front - radius) / SPACING;
	float train = smoothstep(0.0, 0.5, behind) * exp(-behind * 0.5);
	float wave = train * calm * steep;
	float height = sin(behind * TAU) * wave;
	float slope = cos(behind * TAU) * wave * STEEPEST;

	vec2 out_of = place / max(radius, 0.001);
	NORMAL = normalize(up - (right * out_of.x + forward * out_of.y) * slope);
	// A crest is pale with the light it catches, a trough is the dark of the
	// water.
	float crest = smoothstep(0.1, 1.0, height);
	ALBEDO = mix(vec3(0.02, 0.022, 0.025), vec3(0.5, 0.55, 0.6), crest);
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	ALPHA = puddle * clamp(abs(slope) / STEEPEST * 1.8 + crest * 0.7, 0.0, 0.9);
	if (ALPHA < 0.004) {
		discard;
	}
}
