// What is behind the windows of the main building of the dunes: rooms that
// are not there. A window is looked through along a line, and that line is
// followed to the first ceiling, floor, partition or back wall of a room
// that is only arithmetic: a bay wide between two columns, a storey high,
// and as deep as `room_deep`. What is hit there is given a colour: paint
// and concrete, lit by the day through the window it is seen through, less
// the further in. Each room is a little lighter or darker than the next,
// and one in a while has its lamps on.
//
// The glass has it behind its reflection (shaders/window_pane.gdshader) and
// the wall behind a pane that is gone has it by itself
// (shaders/depot_room.gdshader), so that a window that is shot out shows
// what it showed.

// Where the building stands: the corner its bays are counted from (x and
// z), how wide a bay is along its long faces and along its ends, and the
// height of the ground it stands on.
uniform vec2 room_corner = vec2(300.0, 27.0);
uniform vec2 room_bay = vec2(8.2667, 7.2);
uniform float room_ground = 6.4;
uniform float room_deep = 7.0;
// How bright a room is just inside its window, next to the day outside.
uniform float room_light : hint_range(0.0, 2.0) = 0.2;
uniform sampler2D room_grain : hint_default_white, filter_linear_mipmap, repeat_enable;

float room_dice(vec2 cell, float salt) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233)) + salt * 37.719) * 43758.5453);
}

// The light that comes out of the room at `world`, a point of a face that
// looks along `out_normal` (level, in the world), towards an eye that looks
// at it along `look` (in the world).
vec3 room_seen(vec3 world, vec3 out_normal, vec3 look) {
	// Along the face, up, and into the building.
	bool end_face = abs(out_normal.x) > abs(out_normal.z);
	vec3 into = -normalize(vec3(out_normal.x, 0.0, out_normal.z));
	vec3 along = vec3(-into.z, 0.0, into.x);
	float bay = end_face ? room_bay.y : room_bay.x;
	float run = (end_face ? world.z - room_corner.y : world.x - room_corner.x) * (end_face ? along.z : along.x);
	float high = world.y - room_ground;
	// The storey: its floor and its ceiling.
	vec2 storey = high < 4.9 ? vec2(0.0, 4.6) : (high < 8.1 ? vec2(5.2, 7.8) : vec2(8.4, 12.2));
	vec3 at = vec3(run / bay, (high - storey.x) / (storey.y - storey.x), 0.0);
	vec3 way = vec3(dot(look, along) / bay, look.y / (storey.y - storey.x), dot(look, into) / room_deep);
	way.z = max(way.z, 1e-4);
	vec2 cell = vec2(floor(at.x), storey.x);
	vec3 from = vec3(fract(at.x), clamp(at.y, 0.001, 0.999), 0.0);
	// How far along the line to the side of the room, to its floor or
	// ceiling, and to its back.
	vec3 walls = mix(vec3(0.0), vec3(1.0), step(vec3(0.0), way));
	vec3 reach = (walls - from) / way;
	reach = mix(reach, vec3(1e6), lessThan(abs(way), vec3(1e-5)));
	float far = min(reach.x, min(reach.y, reach.z));
	vec3 hit = from + way * far;
	float lamps_on = step(0.9, room_dice(cell, 3.0));
	float mood = mix(0.55, 1.0, room_dice(cell, 1.0));
	vec3 paint;
	float lit;
	if (far == reach.y) {
		if (way.y > 0.0) {
			// The ceiling: concrete between its beams, a row of fittings.
			float beam = smoothstep(0.42, 0.5, abs(fract(hit.x * 4.0) - 0.5));
			paint = mix(vec3(0.5, 0.49, 0.45), vec3(0.36, 0.35, 0.33), beam);
			float fitting = step(abs(fract(hit.x * 2.0) - 0.5), 0.07) * step(abs(fract(hit.z * 3.0) - 0.5), 0.3);
			paint = mix(paint, vec3(0.8), fitting);
			lit = 0.85 + lamps_on * fitting * 2.5;
		} else {
			paint = vec3(0.2, 0.19, 0.17);
			lit = 1.2;
		}
	} else if (far == reach.x) {
		// A partition: a dado of darker paint.
		paint = mix(vec3(0.3, 0.33, 0.29), vec3(0.52, 0.5, 0.43), step(0.36, hit.y));
		lit = 0.8;
	} else {
		// The back of the room: the same dado, and a door in it.
		paint = mix(vec3(0.3, 0.33, 0.29), vec3(0.52, 0.5, 0.43), step(0.36, hit.y));
		float door = step(abs(hit.x - 0.3 - 0.4 * room_dice(cell, 2.0)), 0.07) * step(hit.y, 0.78);
		paint = mix(paint, vec3(0.16, 0.13, 0.1), door);
		lit = 0.7;
	}
	// The day comes in at the window and is lost on the way to the back.
	float inward = hit.z;
	float daylight = mix(1.0, 0.16, smoothstep(0.0, 1.0, inward));
	float grain = texture(room_grain, vec2(hit.x + hit.z * 0.7 + cell.x * 0.37, hit.y + hit.z * 0.31)).r;
	vec3 lamp_glow = vec3(1.0, 0.86, 0.6) * lamps_on * 0.07;
	return paint * (daylight * lit * mood * room_light * mix(0.8, 1.1, grain) + lamp_glow);
}
