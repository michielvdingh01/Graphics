extends CanvasLayer

const MARGIN := 28
## How far left of the grenades what is on the second key begins: past the
## pips of the most grenades there can be.
const TACTICALS_LEFT := 92.0
## Seconds a level takes to come up out of black, and the most it waits for
## the navmesh of the level before it does.
const FADE_IN := 0.7
const BAKE_WAIT := 2.0
## Where a hit came from shows as a red arc on a ring around the crosshair:
## the radius of that ring and the thickness of an arc as shares of the height
## of the screen, and the length of an arc in radians. An arc stands for
## ARC_HOLD seconds and fades over ARC_FADE more. There are at most ARC_COUNT
## of them, and a hit from within ARC_SAME radians of an earlier one renews
## that one instead of adding to them.
const ARC_RADIUS := 0.19
const ARC_THICKNESS := 0.015
const ARC_LENGTH := deg_to_rad(40.0)
const ARC_HOLD := 0.3
const ARC_FADE := 0.9
const ARC_COUNT := 4
const ARC_SAME := deg_to_rad(20.0)
## The ring that shows who of the watch is growing sure of the player, as a
## share of the height of the screen.
const WATCH_RADIUS := 0.105
const VEHICLE_HUD := preload("res://scripts/vehicle_hud.gd")
## Under this share of full health the red at the edges of the screen
## breathes: this many times a second, by this much of its strength either way.
const PULSE_BELOW := 0.3
const PULSE_RATE := 1.3
const PULSE_SIZE := 0.08


class Crosshair:
	extends Control
	var gap := 6.0
	var opacity := 1.0

	func _draw() -> void:
		var color := Color(1, 1, 1, 0.9 * opacity)
		draw_rect(Rect2(-1, -1, 2, 2), Color(1, 1, 1, 0.9))
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(direction * gap, direction * (gap + 9.0), color, 2.0)


class Hitmarker:
	extends Control
	var color := Color.WHITE
	var strength := 0.0

	func _draw() -> void:
		if strength <= 0.0:
			return
		var inner := 7.0 + 4.0 * strength
		var tint := Color(color, strength)
		for direction: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(direction * inner, direction * (inner + 9.0), tint, 2.5)


class HitArcs:
	extends Control
	## One for every hit that still shows: on its x the angle it came from, in
	## radians clockwise from straight ahead, which is up on the screen; on its
	## y how strongly it is drawn, from 0 to 1.
	var arcs: Array[Vector2] = []
	var radius := 200.0
	var thickness := 16.0

	## An arc is three bands of red on top of each other, each narrower and
	## stronger than the one under it, and all of them fading out towards both
	## ends: something soft at the edge of sight, not a mark to read.
	func _draw() -> void:
		for arc in arcs:
			for band: Vector2 in [Vector2(1.0, 0.25), Vector2(0.6, 0.4), Vector2(0.25, 0.6)]:
				var points := PackedVector2Array()
				var colors := PackedColorArray()
				for i in 17:
					var along := i / 16.0
					var angle := arc.x + (along - 0.5) * ARC_LENGTH
					points.append(Vector2(sin(angle), -cos(angle)) * radius)
					colors.append(Color(1.0, 0.16, 0.1, arc.y * band.y * sin(PI * along)))
				draw_polyline_colors(points, colors, thickness * band.x, true)


class Watchers:
	extends Control
	## One for every enemy on watch that is growing sure of the player: on its
	## x the angle it stands at, as for the arcs of a hit, on its y how sure it
	## is, from 0 to 1.
	var eyes: Array[Vector2] = []
	var radius := 120.0

	## A short arc towards each, inside the ring the hits show on: it grows
	## from its middle as the enemy grows surer, and goes from white through
	## amber to red. Full, the enemy knows.
	func _draw() -> void:
		for eye in eyes:
			var tint := Color(1, 1, 1).lerp(Color(1, 0.8, 0.4), smoothstep(0.0, 0.5, eye.y)).lerp(Color(1, 0.3, 0.25), smoothstep(0.5, 1.0, eye.y))
			for band: Vector2 in [Vector2(1.0, 0.35), Vector2(0.45, 0.9)]:
				var points := PackedVector2Array()
				for i in 13:
					var angle := eye.x + (i / 12.0 - 0.5) * 0.5 * (0.25 + 0.75 * eye.y)
					points.append(Vector2(sin(angle), -cos(angle)) * radius)
				draw_polyline(points, Color(tint.r, tint.g, tint.b, band.y * (0.35 + 0.65 * eye.y)), 9.0 * band.x, true)


class Grenades:
	extends Control
	var count := 0
	## Stick grenades instead of round ones.
	var sticks := false
	## Tins of smoke instead of either.
	var tins := false

	## One pip for every grenade carried, right to left: a ball with its fuze,
	## the can of a stick grenade on its handle, or a tin with its cap.
	func _draw() -> void:
		for i in count:
			var at := Vector2(-11.0 - i * 24.0, -12.0)
			if tins:
				draw_rect(Rect2(at.x - 6.0, at.y - 9.0, 12.0, 18.0), Color(1, 1, 1, 0.9))
				draw_rect(Rect2(at.x - 4.0, at.y - 13.0, 8.0, 3.0), Color(1, 1, 1, 0.9))
			elif sticks:
				draw_rect(Rect2(at.x - 7.0, at.y - 16.0, 14.0, 12.0), Color(1, 1, 1, 0.9))
				draw_rect(Rect2(at.x - 2.5, at.y - 4.0, 5.0, 14.0), Color(1, 1, 1, 0.9))
			else:
				draw_circle(at, 8.0, Color(1, 1, 1, 0.9))
				draw_rect(Rect2(at.x - 3.0, at.y - 13.0, 6.0, 6.0), Color(1, 1, 1, 0.9))


class Heat:
	extends Control
	## How hot the weapon in hand is, 0 to 1, and whether it has overheated.
	var heat := 0.0
	var over := false

	## A bar that fills from the right as it heats, white, then orange, then
	## red; overheated it blinks.
	func _draw() -> void:
		var width := 150.0
		draw_rect(Rect2(-width, -6.0, width, 6.0), Color(1, 1, 1, 0.18))
		var tint := Color(1, 0.25, 0.15) if over else Color.WHITE.lerp(Color(1, 0.55, 0.15), smoothstep(0.4, 0.9, heat))
		if over and fmod(Time.get_ticks_msec() / 1000.0, 0.4) > 0.25:
			tint.a = 0.35
		draw_rect(Rect2(-width * heat, -6.0, width * heat, 6.0), tint)


var _player: CharacterBody3D
var _root := Control.new()
var _fps_label := Label.new()
var _ammo_label := Label.new()
var _weapon_label := Label.new()
var _grenades := Grenades.new()
## What is on the second key, in the same row, to the left of the most
## grenades there can be.
var _tacticals := Grenades.new()
var _heat := Heat.new()
## Where the name of the weapon sits, offset_top and offset_bottom, when there
## is no heat to show under it.
var _name_at := Vector2.ZERO
var _health_bar := ProgressBar.new()
## A mark on the health bar at what comes back by itself, the health as a
## number, and a line for what was just picked up.
var _regen_mark := ColorRect.new()
var _health_label := Label.new()
var _pickup_label := Label.new()
var _objective_label := Label.new()
var _kills_label := Label.new()
## Who came and who went, in a game with others.
var _news_label := Label.new()
var _banner := Label.new()
var _crosshair := Crosshair.new()
var _hitmarker := Hitmarker.new()
var _hit_arcs := HitArcs.new()
## Who is growing sure of the player, in a level where a watch is kept.
var _watchers := Watchers.new()
var _vehicle_hud: Control = VEHICLE_HUD.new()
## The hits that still show where they came from. For each: `bearing`, the
## direction it came from in the world, level with the floor, which the arc
## keeps pointing at while the player turns; `age` in seconds; and `strength`,
## how strongly it is drawn to begin with.
var _hits: Array[Dictionary] = []
var _vignette := ColorRect.new()
var _vignette_mat := ShaderMaterial.new()
var _scope := ColorRect.new()
var _scope_mat := ShaderMaterial.new()
## Over everything else: black while a level comes in or goes out.
var _curtain := ColorRect.new()
var _hurt := 0.0
var _health_ratio := 1.0
## How far the red at the edges is through a breath, from 0 to 1.
var _pulse := 0.0
var _fading: Tween
var _news: Tween


func _ready() -> void:
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Under everything else: what is seen through a telescopic sight.
	_scope_mat.shader = preload("res://shaders/scope.gdshader")
	_scope.material = _scope_mat
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_place(_scope, Control.PRESET_FULL_RECT, 0)

	_vignette_mat.shader = preload("res://shaders/damage_vignette.gdshader")
	_vignette.material = _vignette_mat
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_vignette, Control.PRESET_FULL_RECT, 0)

	_place(_fps_label, Control.PRESET_TOP_LEFT)
	# What there is to do, where the wave number used to be.
	_objective_label.add_theme_font_size_override("font_size", 26)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_objective_label, Control.PRESET_TOP_RIGHT)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kills_label.modulate.a = 0.75
	_place(_kills_label, Control.PRESET_TOP_RIGHT)
	_kills_label.offset_top += 38
	_kills_label.offset_bottom += 38
	_news_label.modulate.a = 0.0
	_place(_news_label, Control.PRESET_TOP_LEFT)
	_news_label.offset_top += 30
	_news_label.offset_bottom += 30

	_ammo_label.add_theme_font_size_override("font_size", 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_ammo_label, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_weapon_label, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.offset_bottom -= 56
	_weapon_label.offset_top -= 56
	_place(_grenades, Control.PRESET_BOTTOM_RIGHT)
	_place(_heat, Control.PRESET_BOTTOM_RIGHT)
	_heat.offset_bottom -= 60
	_heat.offset_top -= 60
	_heat.visible = false
	_name_at = Vector2(_weapon_label.offset_top, _weapon_label.offset_bottom)
	_grenades.offset_bottom -= 88
	_grenades.offset_top -= 88
	_tacticals.tins = true
	_place(_tacticals, Control.PRESET_BOTTOM_RIGHT)
	_tacticals.offset_bottom = _grenades.offset_bottom
	_tacticals.offset_top = _grenades.offset_top
	_tacticals.offset_left -= TACTICALS_LEFT
	_tacticals.offset_right -= TACTICALS_LEFT

	_health_bar.custom_minimum_size = Vector2(260, 14)
	_health_bar.show_percentage = false
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_place(_health_bar, Control.PRESET_BOTTOM_LEFT)
	_regen_mark.color = Color(1, 1, 1, 0.85)
	_regen_mark.size = Vector2(2, 20)
	_regen_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_child(_regen_mark)
	_health_label.add_theme_font_size_override("font_size", 26)
	_place(_health_label, Control.PRESET_BOTTOM_LEFT)
	_health_label.offset_left += 272
	_health_label.offset_right += 272
	_health_label.offset_top += 8
	_health_label.offset_bottom += 8
	_pickup_label.add_theme_font_size_override("font_size", 24)
	_pickup_label.modulate.a = 0.0
	_place(_pickup_label, Control.PRESET_BOTTOM_LEFT)
	_pickup_label.offset_top -= 30
	_pickup_label.offset_bottom -= 30

	_banner.add_theme_font_size_override("font_size", 56)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_place(_banner, Control.PRESET_CENTER_TOP, 140)

	_place(_crosshair, Control.PRESET_CENTER, 0)
	_place(_hitmarker, Control.PRESET_CENTER, 0)
	_place(_hit_arcs, Control.PRESET_CENTER, 0)
	_place(_watchers, Control.PRESET_CENTER, 0)

	_place(_vehicle_hud, Control.PRESET_FULL_RECT, 0)

	_curtain.color = Color.BLACK
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_curtain, Control.PRESET_FULL_RECT, 0)
	_lift_curtain()
	_bind.call_deferred()


## The level comes up out of black once it has baked its navmesh, which in
## the dunes is a frame of a third of a second: under the curtain, not
## halfway up.
func _lift_curtain() -> void:
	var waited := 0.0
	var game := get_parent()
	while game and game.has_signal(&"baked") and not game.get(&"is_baked") and waited < BAKE_WAIT:
		await get_tree().process_frame
		if not is_inside_tree():
			# The level was left before it was baked.
			return
		waited += get_process_delta_time()
	create_tween().tween_property(_curtain, "modulate:a", 0.0, FADE_IN)


func _place(control: Control, preset: Control.LayoutPreset, margin := MARGIN) -> void:
	_root.add_child(control)
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	# Keep right- and bottom-anchored labels on screen when their text grows.
	if control.anchor_left == 1.0:
		control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif control.anchor_left == 0.5:
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if control.anchor_top == 1.0:
		control.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _bind() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_vehicle_hud.player = _player
	_player.health_changed.connect(_on_health_changed)
	_player.damaged.connect(func(amount: float) -> void: _hurt = minf(_hurt + amount / 25.0, 1.0))
	_player.hit_from.connect(_on_hit_from)
	_player.died.connect(_show_banner.bind("YOU DIED", Color(1, 0.3, 0.25), 10.0))
	_player.revived.connect(_show_banner.bind("", Color.WHITE, 0.0))
	Net.said.connect(_on_news)
	_player.weapons.ammo_changed.connect(_on_ammo_changed)
	_player.weapons.hit_confirmed.connect(_on_hit_confirmed)
	_player.weapons.grenades_changed.connect(_on_grenades_changed)
	_on_grenades_changed(_player.weapons.grenades)
	_player.weapons.tacticals_changed.connect(_on_tacticals_changed)
	_on_tacticals_changed(_player.weapons.tacticals)
	var game := get_tree().get_first_node_in_group("game")
	game.objective_changed.connect(_on_objective_changed)
	game.kills_changed.connect(_on_kills_changed)
	game.checkpoint_reached.connect(func(_title: String) -> void: _show_banner("CHECKPOINT", Color.WHITE, 1.2))
	game.finished.connect(_on_finished.bind(game.EXIT_FADE))
	game.picked_up.connect(_on_picked_up)
	_on_health_changed(_player.health, _player.MAX_HEALTH)
	_on_objective_changed(game.objective, 0)
	_on_kills_changed(game.kills)


## What a player has to know of the enemies that keep watch: who of them is
## growing sure of him. Whether he stands in the shade, where they hardly see
## him, is his to find out. Nothing of it shows in a level without a watch,
## or once every watch near by knows.
func _watch(half_height: float) -> void:
	var view: Basis = _player.global_basis.inverse()
	_watchers.eyes.clear()
	for enemy: Node3D in get_tree().get_nodes_in_group(&"watch"):
		if not enemy.is_watching() or not enemy.can_process():
			continue
		var to := enemy.global_position - _player.global_position
		if enemy.awareness > 0.02:
			var from: Vector3 = view * to
			_watchers.eyes.append(Vector2(atan2(from.x, -from.z), clampf(enemy.awareness, 0.0, 1.0)))
	_watchers.radius = half_height * 2.0 * WATCH_RADIUS
	_watchers.visible = not _player.dead
	_watchers.queue_redraw()


func _process(delta: float) -> void:
	_fps_label.visible = Settings.show_fps
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	# A match counts them itself, see scripts/match_hud.gd.
	_kills_label.visible = not Match.active
	if _player == null:
		return
	var weapons: Node3D = _player.weapons

	# Crosshair gap matches the real spread cone at the current field of view.
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	var spread := tan(deg_to_rad(weapons.current_spread_deg()))
	_crosshair.gap = 3.0 + spread / tan(deg_to_rad(_player.camera.fov * 0.5)) * half_height
	_crosshair.opacity = 1.0 - weapons.ads_blend
	# Whoever drives has no weapon in hand, unless it is a car that lets them
	# fire: the vehicle says what there is.
	var driving: bool = _player.riding != null and _player.seat == 0 and not _player.fires_from_the_wheel()
	_crosshair.visible = not _player.dead and not driving
	_crosshair.queue_redraw()
	for label: Control in [_ammo_label, _weapon_label, _grenades, _tacticals]:
		label.visible = not driving

	# Aiming a scoped weapon, the view goes black and opens again as a circle.
	var scope: float = weapons.scope_blend()
	_scope.visible = scope > 0.0
	if scope > 0.0:
		var view := get_viewport().get_visible_rect().size
		_scope_mat.set_shader_parameter("cover", smoothstep(0.0, 0.5, scope))
		_scope_mat.set_shader_parameter("open", smoothstep(0.5, 1.0, scope))
		_scope_mat.set_shader_parameter("aspect", view.x / view.y)

	if _hitmarker.strength > 0.0:
		_hitmarker.strength = maxf(_hitmarker.strength - delta * 4.0, 0.0)
		_hitmarker.queue_redraw()

	# The arcs go by where a hit came from in the world, so that they slide
	# round the ring as the player turns towards it. Once more after the last
	# has gone, to wipe it.
	if not _hits.is_empty() or not _hit_arcs.arcs.is_empty():
		var view: Basis = _player.global_basis.inverse()
		_hit_arcs.arcs.clear()
		for i in range(_hits.size() - 1, -1, -1):
			var hit := _hits[i]
			hit.age += delta
			if hit.age >= ARC_HOLD + ARC_FADE:
				_hits.remove_at(i)
				continue
			var from: Vector3 = view * hit.bearing
			var faded: float = clampf((hit.age - ARC_HOLD) / ARC_FADE, 0.0, 1.0)
			_hit_arcs.arcs.append(Vector2(atan2(from.x, -from.z), hit.strength * (1.0 - faded)))
		_hit_arcs.radius = half_height * 2.0 * ARC_RADIUS
		_hit_arcs.thickness = half_height * 2.0 * ARC_THICKNESS
		_hit_arcs.queue_redraw()

	_watch(half_height)

	_hurt = maxf(_hurt - delta * 1.5, 0.0)
	var low_health := clampf(1.0 - _health_ratio / 0.5, 0.0, 1.0) * 0.6
	# Close to death the red does not stand still but breathes, more the less
	# health is left: something that stands still is soon no longer seen.
	if _health_ratio < PULSE_BELOW and not _player.dead:
		_pulse = fposmod(_pulse + delta * PULSE_RATE, 1.0)
		low_health += sin(TAU * _pulse) * PULSE_SIZE * minf((PULSE_BELOW - _health_ratio) / 0.1, 1.0)
	else:
		_pulse = 0.0
	_vignette_mat.set_shader_parameter("strength", maxf(_hurt, low_health))

	var reloading: float = weapons.reload_fraction()
	if reloading > 0.0:
		_weapon_label.text = "RELOADING %d%%" % (reloading * 100.0)
	elif weapons.overheated():
		_weapon_label.text = "OVERHEATED"
	else:
		_weapon_label.text = weapons.current().display_name
	# A weapon that can overheat shows how hot it is, under its name.
	_heat.visible = weapons.current().overheat_after > 0.0
	if _heat.visible:
		_heat.heat = weapons.heat()
		_heat.over = weapons.overheated()
		_heat.queue_redraw()
	var lift := 14.0 if _heat.visible else 0.0
	_weapon_label.offset_top = _name_at.x - lift
	_weapon_label.offset_bottom = _name_at.y - lift


func _on_health_changed(health: float, max_health: float) -> void:
	_health_ratio = clampf(health / max_health, 0.0, 1.0)
	_health_bar.value = _health_ratio
	_health_label.text = "%d" % ceili(_health_ratio * max_health)
	# What is under the mark comes back by itself; the rest has to be found.
	var regen_to: float = Settings.rules().regen_to / max_health
	_regen_mark.position = Vector2(_health_bar.custom_minimum_size.x * regen_to - 1.0, -3.0)
	_health_label.modulate = Color(1, 0.45, 0.35) if _health_ratio <= regen_to else Color.WHITE


## The reserve is -1 for a weapon that never runs out.
func _on_ammo_changed(_weapon_name: String, mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %s" % [mag, "∞" if reserve < 0 else str(reserve)]
	_ammo_label.modulate = Color(1, 0.4, 0.3) if mag == 0 else (Color(1, 0.8, 0.4) if reserve == 0 else Color.WHITE)


func _on_picked_up(text: String, tint: Color) -> void:
	_pickup_label.text = text
	_pickup_label.modulate = tint
	var tween := create_tween()
	tween.tween_interval(1.1)
	tween.tween_property(_pickup_label, "modulate:a", 0.0, 0.5)


func _on_grenades_changed(count: int) -> void:
	_grenades.count = count
	_grenades.sticks = _player.weapons.grenade_kind == "stick_grenade"
	_grenades.queue_redraw()


func _on_tacticals_changed(count: int) -> void:
	_tacticals.count = count
	_tacticals.queue_redraw()


## A hit on the player, see Player.hit_from: one that came from a side gets
## an arc on that side, a hard one a stronger arc than a graze. The oldest
## makes way if there are too many.
func _on_hit_from(amount: float, bearing: Vector3) -> void:
	if bearing == Vector3.ZERO:
		return
	var strength := clampf(0.5 + amount / 40.0, 0.5, 1.0)
	for hit in _hits:
		if (hit.bearing as Vector3).angle_to(bearing) < ARC_SAME:
			hit.bearing = bearing
			hit.age = 0.0
			hit.strength = maxf(hit.strength, strength)
			return
	_hits.append({"bearing": bearing, "age": 0.0, "strength": strength})
	if _hits.size() > ARC_COUNT:
		var oldest := 0
		for i in _hits.size():
			if _hits[i].age > _hits[oldest].age:
				oldest = i
		_hits.remove_at(oldest)


func _on_hit_confirmed(headshot: bool, killed: bool) -> void:
	_hitmarker.strength = 1.0
	_hitmarker.color = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	_hitmarker.queue_redraw()


func _on_objective_changed(text: String, hostiles: int) -> void:
	_objective_label.text = text if hostiles == 0 else "%s  ·  %d left" % [text, hostiles]


func _on_kills_changed(kills: int) -> void:
	_kills_label.text = "Kills %d" % kills


## The screen goes dark as the player walks out of the level.
func _on_finished(_next: String, fade: float) -> void:
	create_tween().tween_property(_curtain, "modulate:a", 1.0, fade)


func _on_news(text: String) -> void:
	_news_label.text = text
	_news_label.modulate.a = 1.0
	if _news:
		_news.kill()
	_news = create_tween()
	_news.tween_interval(4.0)
	_news.tween_property(_news_label, "modulate:a", 0.0, 0.6)


func _show_banner(text: String, color: Color, hold: float) -> void:
	_banner.text = text
	_banner.modulate = color
	# One banner at a time: a later one is not faded out by an earlier one.
	if _fading:
		_fading.kill()
	_fading = create_tween()
	_fading.tween_interval(hold)
	_fading.tween_property(_banner, "modulate:a", 0.0, 0.6)
