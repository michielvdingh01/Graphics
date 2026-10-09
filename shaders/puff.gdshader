shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, specular_disabled;

// Dust or smoke: a handful of soft balls that leave along the +Y of the
// burst, slow down in the air, swell, drift and thin out from the edges. It
// is lit like everything else, so it is dark in a dark corner and lights up
// in a beam of sunlight.
#include "fx_common.gdshaderinc"

// Three channels of tiling noise; the wear mask of the painted steel will do.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

instance uniform float start = -100.0;
// Colour, and how opaque the thickest part is.
instance uniform vec4 tint : source_color = vec4(0.5, 0.48, 0.45, 0.5);
// Speed it leaves at in m/s and how far from the normal it fans out.
instance uniform float speed = 1.5;
instance uniform float spread = 0.6;
// Radius of a ball when it appears and when it is gone, in metres.
instance uniform vec2 size = vec2(0.05, 0.35);
instance uniform float life = 1.2;
// Metres per second it drifts upwards; dust that settles has this negative.
instance uniform float rise = 0.1;
instance uniform float amount = 1.0;
// Light it gives off itself while it is young: a ball of fire, not of dust.
instance uniform float glow = 0.0;

// How quickly the air stops it, per second.
const float DRAG = 5.0;

varying vec3 random;
varying float course;

void vertex() {
	random = VERTEX * 0.5 + 0.5;
	// They do not all leave at the same moment.
	float age = fx_time - start - random.z * 0.12 * life;
	float span = life * (0.6 + 0.4 * random.x);
	course = clamp(age / span, 0.0, 1.0);

	mat3 frame = mat3(MODEL_MATRIX);
	float carried = (1.0 - exp(-DRAG * age)) / DRAG;
	vec3 world = MODEL_MATRIX[3].xyz + frame * cone(NORMAL, spread) * speed * (0.25 + 0.75 * random.y) * carried;
	world.y += rise * age * (0.6 + 0.8 * random.x);
	float radius = mix(size.x, size.y, 1.0 - exp(-3.5 * course)) * (0.7 + 0.6 * random.z);

	vec3 view = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	// One that hangs right in front of the lens would wipe out the view.
	radius *= smoothstep(0.15, 0.6, -view.z);
	view.xy += turned(UV * 2.0 - 1.0, random.x * 6.28 + age * (random.y - 0.5) * 1.2) * radius;
	VERTEX = view;
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (age < 0.0 || age > span || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float inside = max(1.0 - dot(p, p), 0.0);
	// Thick in the middle and thinning to nothing at the rim, in billows.
	float billow = texture(noise, UV * 0.33 + random.xy * 7.0).r * 0.6 + texture(noise, UV * 0.8 + random.yz * 5.0 + course * 0.1).b * 0.4;
	float density = inside * inside * (0.2 + 2.4 * billow * billow);
	// It is gone first where it is thinnest.
	float gone = mix(0.0, 0.5, course * course);
	ALPHA = smoothstep(gone, gone + 0.8, density) * tint.a * smoothstep(0.0, 0.08, course) * (1.0 - smoothstep(0.5, 1.0, course));
	ALBEDO = tint.rgb * (0.75 + 0.5 * billow);
	ROUGHNESS = 1.0;
	EMISSION = tint.rgb * glow * (1.0 - course);
	// Shade it as the ball it stands for instead of the flat card it is.
	NORMAL = normalize(vec3(p * 0.7, sqrt(inside) + 0.35));
}

void light() {
	// Smoke scatters light every way, a little more towards where it came from.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (0.3 + 0.3 * max(dot(NORMAL, LIGHT), 0.0)) / PI;
}
