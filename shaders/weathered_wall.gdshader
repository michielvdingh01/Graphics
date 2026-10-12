shader_type spatial;

// A wall that has stood out of doors for thirty years: poured concrete, or
// brick. Every face the builder made is a pour of its own, a little paler or
// darker than the next. Rain has run down from its top in streaks, damp
// stands at its foot, with green on it where the sun does not come, sand has
// blown against it, lichen has taken on whatever faces up, and where the
// face is a bay of a wall with weep holes, rust runs down from them.
//
// A face has its position in metres for UV, and the builder writes into the
// vertex colour where a point lies between the edges of its face: see
// _edge() in tools/level_builder.gd.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.333;
uniform vec3 tint : source_color = vec3(1.0);
// How high the ground lies that the wall stands on.
uniform float foot_y = 6.4;
// The way to the sun along the ground, x and z: a face that looks away from
// it stays damp.
uniform vec2 sunward = vec2(-0.56, 0.83);
// How much one pour differs from the next.
uniform float pours : hint_range(0.0, 1.0) = 0.5;
uniform float streaks : hint_range(0.0, 1.0) = 0.6;
uniform float damp : hint_range(0.0, 1.0) = 0.6;
uniform float green : hint_range(0.0, 1.0) = 0.5;
// Sand blown against the foot, and its colour.
uniform float sand : hint_range(0.0, 1.0) = 0.6;
uniform vec3 sand_tint : source_color = vec3(0.6, 0.555, 0.49);
// How high over the foot a bay of a wall has its two weep holes, or nought
// for none. A bay is a face between two and a half and a good four metres
// wide: that is how wide the wall of the complex is between its piers.
uniform float weep_height = 0.0;

varying vec3 world_normal;
varying float height;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - foot_y;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	// From afar a scan repeats: there it gives way to itself seen from four
	// times as far.
	float depth = -VERTEX.z;
	vec3 scan = texture(albedo_tex, uv).rgb;
	scan = mix(scan, texture(albedo_tex, uv * 0.27 + vec2(0.37, 0.11)).rgb, smoothstep(14.0, 55.0, depth) * 0.6);
	vec3 orm = texture(orm_tex, uv).rgb;
	// Blotches a few metres across, and ragged cells a hand wide.
	vec3 wide = texture(wear_mask, UV * 0.043).rgb;
	vec3 fine = texture(wear_mask, UV * 0.41 + vec2(0.31, 0.57)).rgb;

	// Where in its face this point lies, in metres from its left and its
	// lower edge. A side of a face that has no edges is 256 m long.
	vec2 span = exp2(COLOR.ba * 16.0 - 8.0);
	vec2 in_face = COLOR.rg * span;
	float edged = step(span.x, 200.0) * step(span.y, 200.0);
	float upright = 1.0 - smoothstep(0.35, 0.7, abs(world_normal.y));
	float faces_up = smoothstep(0.6, 0.95, world_normal.y);
	float shady = clamp(0.55 - dot(world_normal.xz, sunward) * 0.75, 0.0, 1.0);

	// A pour is as dark as where its face begins says. That place is not
	// known to the centimetre, so it is no dice that are thrown with it but
	// a wave that is read off.
	vec2 corner = (UV - in_face) * edged;
	float pour = 0.5 + 0.5 * sin(dot(corner, vec2(0.93, 1.71))) * sin(dot(corner, vec2(2.37, 0.61)) + 1.3);
	vec3 albedo = scan * tint * mix(1.0 - 0.3 * pours, 1.0 + 0.14 * pours, pour) * mix(0.88, 1.08, wide.r);
	// One load of cement was greyer than the next, and one of sand yellower.
	albedo *= mix(vec3(1.0), mix(vec3(0.94, 0.98, 1.04), vec3(1.05, 1.0, 0.92), fract(pour * 3.7)), pours * 0.7);
	float rough = orm.g;

	// Rain runs down from the top edge of an upright face, in streaks that
	// reach further here than there. Right under a coping the wall stays dry.
	float from_top = mix(1000.0, (1.0 - COLOR.g) * span.y, step(span.y, 200.0));
	float reach = 0.4 + 3.4 * wide.g * wide.g + 1.2 * pour;
	vec3 lines = texture(wear_mask, vec2(UV.x * 0.83, UV.y * 0.04)).rgb;
	float run = (1.0 - smoothstep(reach * 0.2, reach, from_top)) * smoothstep(0.03, 0.1, from_top) * upright * streaks;
	float dirty = run * smoothstep(0.34, 0.66, lines.b + (fine.r - 0.5) * 0.25);
	albedo = mix(albedo, albedo * vec3(0.42, 0.4, 0.36), dirty * 0.85);
	// And here and there it has brought lime out of the concrete with it.
	float limed = run * smoothstep(0.66, 0.8, lines.r) * smoothstep(0.45, 0.7, wide.b);
	albedo = mix(albedo, vec3(0.62, 0.61, 0.57), limed * 0.6);

	// Damp stands at the foot, up to a line that wanders, and where the sun
	// does not come it has gone green.
	float tide = 0.25 + 1.1 * wide.b * (0.5 + 0.9 * fine.b);
	float wet = (1.0 - smoothstep(tide * 0.3, tide, height)) * damp * mix(0.55, 1.0, shady) * step(-0.5, height);
	albedo *= 1.0 - 0.5 * wet;
	rough = mix(rough, 0.62, wet * 0.6);
	float algae = wet * green * shady * smoothstep(0.3, 0.62, fine.g * 0.7 + wide.r * 0.5);
	// Higher up the same green keeps to the joints and the shade under a
	// coping: a thin film where the wall never dries.
	algae = max(algae, green * shady * shady * 0.5 * smoothstep(0.55, 0.8, wide.b * 0.6 + fine.g * 0.5) * upright);
	albedo = mix(albedo, vec3(0.13, 0.17, 0.07) * (0.7 + 0.6 * fine.r), algae * 0.8);

	// Rust under the weep holes of a bay: one a quarter of the way along it
	// and one at three quarters.
	float bay = edged * upright * step(2.5, span.x) * step(span.x, 4.3) * step(0.001, weep_height);
	float off = abs(fract(COLOR.r * 2.0) - 0.5) * span.x * 0.5;
	float below = weep_height - height;
	float rust = (1.0 - smoothstep(0.0, 0.035 + below * 0.14, off)) * step(0.0, below) * exp(-max(below, 0.0) / 0.5) * bay;
	rust *= 0.55 + 0.45 * fine.r;
	albedo = mix(albedo, vec3(0.3, 0.14, 0.05) * (0.7 + 0.5 * fine.b), rust * 0.85);
	// And the hole itself, the end of a pipe a fist wide.
	float hole = (1.0 - smoothstep(0.028, 0.036, length(vec2(off, below)))) * bay;
	albedo = mix(albedo, vec3(0.012), hole);

	// Whatever faces up has lichen on it, and dirt in it.
	float lichen = faces_up * smoothstep(0.52, 0.6, fine.g * 0.65 + wide.g * 0.45);
	albedo = mix(albedo * mix(1.0, 0.72, faces_up), vec3(0.42, 0.4, 0.22), lichen * 0.6 * green);

	// Sand has blown against the foot and lies on every ledge near it.
	float blown = exp(-max(height, 0.0) / (0.07 + 0.12 * wide.r)) * sand * (0.55 + 0.45 * fine.b);
	blown = max(blown, faces_up * sand * (1.0 - smoothstep(0.3, 1.4, height)) * 0.8);
	albedo = mix(albedo, sand_tint * (0.85 + 0.3 * fine.r), clamp(blown, 0.0, 0.9));
	rough = mix(rough, 0.95, clamp(blown, 0.0, 1.0));

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	AO = orm.r;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.5, clamp(blown + algae, 0.0, 1.0));
}
