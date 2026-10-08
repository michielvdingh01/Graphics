shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

// Window of a reflex sight. The dot is not painted on the glass: it is drawn
// wherever the line of sight through the glass runs parallel to the barrel,
// as a collimated reticle does. So it stays on the target when the weapon
// sways, and slides off the glass when the eye is not behind it.
uniform vec3 tint : source_color = vec3(0.25, 0.4, 0.45);
uniform float glass : hint_range(0.0, 1.0) = 0.12;
uniform vec3 dot_color : source_color = vec3(1.0, 0.08, 0.04);
uniform float dot_energy = 9.0;
// Radius of the dot and of the ring around it, as a slope (0.001 is 1 mil).
uniform float dot_size = 0.0012;
uniform float ring_size = 0.0;

varying vec3 ray;

void vertex() {
	// From the eye to this point, in the coordinates of the sight: it looks along -Z.
	vec3 eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	ray = VERTEX - eye;
}

void fragment() {
	float off = length(ray.xy / -ray.z);
	float lit = 1.0 - smoothstep(dot_size * 0.6, dot_size, off);
	float width = dot_size * 0.5;
	lit = max(lit, step(0.0001, ring_size) * (1.0 - smoothstep(width * 0.5, width, abs(off - ring_size))));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint;
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	EMISSION = dot_color * dot_energy * lit;
	// More of a mirror the more the glass is seen at a slant.
	ALPHA = max(lit, mix(0.4, glass, facing * facing));
}
