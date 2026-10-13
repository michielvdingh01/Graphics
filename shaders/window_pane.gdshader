shader_type spatial;

// The glass of a window seen from outside by day: what shows is the sky
// that lies on it, and through that the room behind it, which is dimmer.
// No two panes of an old window lie in quite the same plane, and each gives
// back its own patch of sky. Dust has settled on them, most along their
// lower bars. Some have been painted over, and a few are gone.
//
// The builder gives each pane one colour for all four of its corners: red
// and green are how far it leans to the side and back (a half is not at
// all), blue how dirty it is, and alpha what has become of it: nought for
// glass, a half for painted over, one for gone. UV is its position in metres.
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
// How much of the sky a clean pane gives back when it is looked at straight
// on: glass, not a mirror. The rest of what it shows is the room behind it.
uniform float mirror : hint_range(0.0, 1.0) = 0.09;
uniform vec3 film : source_color = vec3(0.3, 0.29, 0.25);
uniform vec3 painted : source_color = vec3(0.36, 0.4, 0.36);
uniform float lean = 0.07;
uniform float dirt : hint_range(0.0, 1.0) = 0.6;

#include "res://shaders/depot_room.gdshaderinc"

void fragment() {
	vec3 mask = texture(wear_mask, UV * 0.7).rgb;
	float gone = step(0.75, COLOR.a);
	float over = step(0.25, COLOR.a) * (1.0 - gone);
	float dusty = clamp(COLOR.b * dirt * (0.35 + 0.9 * mask.r) + smoothstep(0.62, 0.8, mask.g) * 0.25 * dirt, 0.0, 1.0);

	// Clean glass has no colour of its own: it gives back a little of the
	// sky, more the flatter it is looked along, and lets the room through.
	// Dust on it is lit as dust is, and hides both.
	vec3 albedo = film * dusty;
	float rough = mix(0.03, 0.6, dusty);
	albedo = mix(albedo, painted * (0.75 + 0.5 * mask.b), over);
	rough = mix(rough, 0.8, over);

	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 out_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 look = normalize((INV_VIEW_MATRIX * vec4(normalize(VERTEX), 0.0)).xyz);
	float facing = clamp(dot(-normalize(VERTEX), NORMAL), 0.0, 1.0);
	float given_back = mirror + (1.0 - mirror) * pow(1.0 - facing, 5.0);
	vec3 room = room_seen(world, out_normal, look) * (1.0 - given_back) * (1.0 - dusty * 0.85) * (1.0 - over);

	ALBEDO = albedo;
	METALLIC = 0.0;
	ROUGHNESS = rough;
	// Godot's specular of 0.5 is glass that gives back four parts in a
	// hundred; a window is two faces of it.
	SPECULAR = mix(sqrt(mirror / 0.16), 0.3, max(over, dusty * 0.7));
	EMISSION = room;
	vec2 tilt = (COLOR.rg - 0.5) * 2.0 * lean * (1.0 - gone);
	NORMAL = normalize(NORMAL + TANGENT * tilt.x + BINORMAL * tilt.y);
}
