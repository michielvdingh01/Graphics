shader_type spatial;

// The bark of a pine, as an ORMMaterial3D draws it: a picture of bark tinted
// by the colours of the corners, its occlusion, roughness and metal in one
// texture and its relief in another. It is a shader of its own for one thing
// only: the drawings of a tree give way to one another, see
// tree_lod.gdshaderinc, and the bark of one to that of the next.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float specular : hint_range(0.0, 1.0) = 0.5;

#include "tree_lod.gdshaderinc"

void vertex() {
	UV *= uv_scale;
	if (given_way(NODE_POSITION_WORLD, MAIN_CAM_INV_VIEW_MATRIX[3].xyz, 0.5)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb * COLOR.rgb;
	vec4 orm = texture(orm_tex, UV);
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	SPECULAR = specular;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
}
