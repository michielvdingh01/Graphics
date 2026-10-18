shader_type spatial;

// The glass of a lamp that burns by night only: a floodlight on a mast, a
// lamp over a door, a storm lantern. By day it is pale glass with the dark of
// the fitting behind it; by night (the global "night", see Settings.apply())
// it glows. Its light is a lamp in the night layer of the level, see
// night_light() in tools/level_builder.gd; when that is shot out,
// scripts/lamp.gd lays a dark copy over this glass.
uniform vec3 glass : source_color = vec3(0.55, 0.56, 0.52);
uniform vec3 glow : source_color = vec3(1.0, 0.74, 0.44);
uniform float glow_energy = 7.0;
global uniform float night;

void fragment() {
	ALBEDO = glass * (1.0 - night * 0.8);
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
	EMISSION = glow * glow_energy * night;
}
