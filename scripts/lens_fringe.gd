extends CompositorEffect
## The chromatic aberration of the Ultra preset: red and blue pulled apart
## towards the edges of the picture, as shaders/post_aberration.gdshader does.
##
## That shader runs over the finished frame, which on a full screen is far
## larger than what the 3D scene was drawn at: 7.5 million pixels on a 16 inch
## MacBook Pro, each of which first has to be copied to be read back. This
## does the same to the 3D scene before it is enlarged, on a quarter of those
## pixels at a render scale of 50%. scripts/settings.gd hangs it on the
## environment of a level; vignette and grain stay with shaders/post.gdshader,
## which reads nothing back.
##
## It works on the picture before it is tone mapped, so a fringe along a lamp
## is as bright as the lamp and glows with it. And the grain of Ultra is now
## that of the other presets, multiplied on instead of added: the picture is
## 3% darker than it was with the old lens pass, and its grain fades with the
## light. Adding grain takes reading the frame back, which was the cost.

const CONTEXT := &"lens"
const COPY := &"fringe"
const SOURCE := """#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D target;
layout(set = 0, binding = 1) uniform sampler2D source;

layout(push_constant, std430) uniform Params {
	vec2 size;
	float amount;
	float unused;
} params;

void main() {
	ivec2 at = ivec2(gl_GlobalInvocationID.xy);
	if (at.x >= int(params.size.x) || at.y >= int(params.size.y)) {
		return;
	}
	vec2 uv = (vec2(at) + 0.5) / params.size;
	vec2 from_center = uv - 0.5;
	vec2 shift = from_center * dot(from_center, from_center) * params.amount;
	vec4 color = textureLod(source, uv, 0.0);
	color.r = textureLod(source, uv + shift, 0.0).r;
	color.b = textureLod(source, uv - shift, 0.0).b;
	imageStore(target, at, color);
}
"""

## How far red and blue are pulled apart in a corner, as a share of the
## picture: the `aberration` of shaders/post_aberration.gdshader.
var amount := 0.004

var _device: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	_device = RenderingServer.get_rendering_device()
	if _device:
		RenderingServer.call_on_render_thread(_build)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# The pipeline goes with its shader.
		if _shader.is_valid():
			RenderingServer.free_rid(_shader)
		if _sampler.is_valid():
			RenderingServer.free_rid(_sampler)


func _build() -> void:
	var source := RDShaderSource.new()
	source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	source.source_compute = SOURCE
	var compiled := _device.shader_compile_spirv_from_source(source)
	if compiled.compile_error_compute != "":
		push_error("lens_fringe: %s" % compiled.compile_error_compute)
		return
	_shader = _device.shader_create_from_spirv(compiled)
	_pipeline = _device.compute_pipeline_create(_shader)
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _device.sampler_create(state)


func _render_callback(_type: int, render_data: RenderData) -> void:
	if not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	if buffers.has_texture(CONTEXT, COPY):
		var format := buffers.get_texture_format(CONTEXT, COPY)
		if format.width != size.x or format.height != size.y:
			buffers.clear_context(CONTEXT)
	if not buffers.has_texture(CONTEXT, COPY):
		buffers.create_texture(
			CONTEXT, COPY, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT,
			RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false
		)
	var copy := buffers.get_texture(CONTEXT, COPY)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		# Pulled apart into the copy, and the copy back as it is: the picture
		# cannot be read and written in one go, and the renderer does not
		# let it be copied any cheaper than this.
		_draw(color, copy, size, amount)
		_draw(copy, color, size, 0.0)


func _draw(from: RID, to: RID, size: Vector2i, by: float) -> void:
	var target := RDUniform.new()
	target.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	target.binding = 0
	target.add_id(to)
	var source := RDUniform.new()
	source.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	source.binding = 1
	source.add_id(_sampler)
	source.add_id(from)
	var uniforms := UniformSetCacheRD.get_cache(_shader, 0, [target, source])
	var constants := PackedFloat32Array([size.x, size.y, by, 0.0]).to_byte_array()
	var list := _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(list, _pipeline)
	_device.compute_list_bind_uniform_set(list, uniforms, 0)
	_device.compute_list_set_push_constant(list, constants, constants.size())
	_device.compute_list_dispatch(list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	_device.compute_list_end()
