extends Node
## Quality presets for the 3D pipeline. The scene's WorldEnvironment holds the "balanced" look;
## presets only override the expensive switches, so every preset can be A/B tested with the
## benchmark: tools/benchmark.sh --quality=ultra. F2 cycles presets in game.

const PRESETS := ["low", "balanced", "ultra"]

var preset_name := "balanced"

var _env: Environment


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			preset_name = arg.trim_prefix("--quality=")
	# The main scene is not ready yet when autoloads are, so apply on the next frame.
	apply.call_deferred(preset_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quality_cycle"):
		apply(PRESETS[(PRESETS.find(preset_name) + 1) % PRESETS.size()])


func apply(preset: String) -> void:
	if not preset in PRESETS:
		push_warning("Unknown quality preset '%s', using balanced" % preset)
		preset = "balanced"
	preset_name = preset
	var world_env := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if not world_env or not world_env.environment:
		return
	_env = world_env.environment
	var viewport := get_viewport()
	match preset:
		"low":
			_apply_flags(false, false, false, false, false)
			_env.sdfgi_enabled = false
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.use_taa = false
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		"balanced":
			_apply_flags(true, false, false, true, true)
			_env.sdfgi_enabled = true
			_env.sdfgi_cascades = 4
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.use_taa = false
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		"ultra":
			_apply_flags(true, true, true, true, true)
			_env.sdfgi_enabled = true
			_env.sdfgi_cascades = 6
			viewport.msaa_3d = Viewport.MSAA_2X
			# TAA smooths SSAO, SSIL and the volumetric fog, which are all sampled sparsely.
			viewport.use_taa = true
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


func _apply_flags(ssao: bool, ssil: bool, ssr: bool, fog: bool, glow: bool) -> void:
	_env.ssao_enabled = ssao
	_env.ssil_enabled = ssil
	_env.ssr_enabled = ssr
	_env.volumetric_fog_enabled = fog
	_env.glow_enabled = glow
