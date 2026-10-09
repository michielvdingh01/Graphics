shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// The streak a bullet draws on its way from `from` to `to`: a short glowing
// line that travels at `speed` and is gone when it arrives. The mesh is one
// quad; the node only has to stay in the tree for as long as the flight takes.
#include "fx_common.gdshaderinc"

instance uniform float start = -100.0;
instance uniform vec3 from;
instance uniform vec3 to;
instance uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.35);
instance uniform float speed = 260.0;

// Length of the streak and its width, in metres.
const float LENGTH = 7.0;
const float WIDTH = 0.02;
// Narrowest it gets, as a slope: about two pixels at 1080p.
const float MIN_WIDTH = 0.003;
// It appears this far ahead of the muzzle, clear of the weapon itself.
const float LEAD = 1.2;

varying float along_streak;

void vertex() {
	float reach = distance(from, to);
	vec3 direction = (to - from) / max(reach, 0.001);
	float front = LEAD + (fx_time - start) * speed;
	float head = min(front, reach);
	float tail = clamp(front - LENGTH, min(LEAD, reach), reach);
	vec3 a = (VIEW_MATRIX * vec4(from + direction * tail, 1.0)).xyz;
	vec3 b = (VIEW_MATRIX * vec4(from + direction * head, 1.0)).xyz;
	vec3 at = mix(a, b, UV.y);
	vec3 across = normalize(cross(b - a, at) + vec3(0.00001, 0.0, 0.0));
	VERTEX = at + across * (UV.x - 0.5) * max(WIDTH, -at.z * MIN_WIDTH);
	NORMAL = vec3(0.0, 0.0, 1.0);
	along_streak = UV.y;
	if (fx_time < start || head - tail < 0.01) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float core = smoothstep(0.45, 1.0, across);
	float halo = across * across;
	float taper = smoothstep(0.0, 0.8, along_streak);
	ALBEDO = mix(tint, vec3(1.0, 0.95, 0.85), core * 0.6) * (2.0 + 14.0 * core);
	ALPHA = (0.35 * halo + core) * taper;
}
