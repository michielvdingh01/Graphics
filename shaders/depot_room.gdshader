shader_type spatial;
render_mode unshaded;

// The wall behind the glass of the main building of the dunes: where a pane
// is out, this is what shows, and it shows the room the glass showed. See
// shaders/depot_room.gdshaderinc.
#include "res://shaders/depot_room.gdshaderinc"

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 out_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 look = normalize((INV_VIEW_MATRIX * vec4(normalize(VERTEX), 0.0)).xyz);
	ALBEDO = room_seen(world, out_normal, look);
}
