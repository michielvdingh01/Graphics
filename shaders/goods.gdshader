shader_type spatial;
// What stands on the shelves of a shop, see scripts/goods.gd: tens of
// thousands of things in a few meshes, each wearing its own cell of one sheet
// of labels. INSTANCE_CUSTOM says which cell (x, in cells), how much light
// reaches it where it stands (y, 0 to 1) and how shiny it is (z, 0 to 1).
// `COLOR` is a tint that sets one apple apart from the next.

uniform sampler2D labels : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Cells on a side of the sheet.
uniform float across = 16.0;

varying vec2 cell_uv;
varying float reached;
varying float shine;

void vertex() {
	float cell = floor(INSTANCE_CUSTOM.x + 0.5);
	vec2 at = vec2(mod(cell, across), floor(cell / across));
	cell_uv = (at + UV) / across;
	reached = INSTANCE_CUSTOM.y;
	shine = INSTANCE_CUSTOM.z;
}

void fragment() {
	ALBEDO = texture(labels, cell_uv).rgb * COLOR.rgb * reached;
	ROUGHNESS = mix(0.95, 0.18, shine);
	SPECULAR = 0.5;
}
