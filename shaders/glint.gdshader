shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// The glint on the weapon of somebody who is about to fire: a small star that
// always faces the viewer and never gets smaller on screen than it is at
// `near` metres, so that it can be read from across a hall.
#include "fx_common.gdshaderinc"

instance uniform vec3 tint : source_color = vec3(1.0, 0.15, 0.1);
// 0 when there is nothing to see, 1 just before the shot.
instance uniform float power = 0.0;

// Metres across at arm's length, and the distance from which it stops shrinking.
const float SIZE = 0.24;
const float NEAR = 5.0;

void vertex() {
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float across = SIZE * max(length(center) / NEAR, 1.0) * (0.35 + 0.65 * power) * step(0.01, power);
	VERTEX = center + vec3(VERTEX.xy * across, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 at = (UV - 0.5) * 2.0;
	float away = length(at);
	// A hot core, a soft halo and four thin rays.
	float core = exp(-away * away * 45.0);
	float halo = exp(-away * 5.0) * 0.3;
	float rays = (exp(-abs(at.y) * 60.0) + exp(-abs(at.x) * 60.0)) * exp(-away * 3.0) * 0.8;
	float shimmer = 0.85 + 0.15 * sin(fx_time * 40.0);
	float edge = 1.0 - smoothstep(0.8, 1.0, away);
	ALBEDO = mix(tint, vec3(1.0), core * 0.7) * (core * 2.0 + halo + rays) * power * shimmer * edge * 9.0;
}
