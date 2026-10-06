class_name PlaceholderViewmodels
extends RefCounted
## Procedural stand-in weapons until generated or authored models replace them. Every model has
## the same contract: barrel along -Z, a "Muzzle" Marker3D, and an optional "Pump" node.
## The sight line sits at the model origin height so `WeaponData.ads_offset.y` centres it.

static var _flash_texture: ImageTexture
static var _materials: Dictionary[String, StandardMaterial3D] = {}


static func build(style: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Viewmodel_" + style
	match style:
		"pistol":
			_build_pistol(root)
		"shotgun":
			_build_shotgun(root)
		_:
			_build_rifle(root)
	return root


static func _build_rifle(root: Node3D) -> void:
	var metal := _mat("gunmetal", Color(0.46, 0.47, 0.5), 0.55, 0.4)
	var polymer := _mat("polymer", Color(0.16, 0.17, 0.18), 0.0, 0.5)
	var accent := _mat("accent", Color(0.55, 0.5, 0.4), 0.7, 0.45)
	_box(root, Vector3(0.052, 0.075, 0.3), Vector3(0, 0.045, -0.07), metal)
	_box(root, Vector3(0.047, 0.05, 0.26), Vector3(0, 0.038, -0.36), polymer)
	_box(root, Vector3(0.056, 0.012, 0.2), Vector3(0, 0.07, -0.36), accent)
	_cyl(root, 0.0105, 0.2, Vector3(0, 0.042, -0.59), metal)
	_cyl(root, 0.0155, 0.055, Vector3(0, 0.042, -0.7), metal)
	_box(root, Vector3(0.032, 0.125, 0.058), Vector3(0, -0.055, -0.08), polymer, Vector3(-9, 0, 0))
	_box(root, Vector3(0.036, 0.105, 0.046), Vector3(0, -0.03, 0.06), polymer, Vector3(20, 0, 0))
	# Reflex sight: an open frame so the dot is visible when aiming down it.
	_box(root, Vector3(0.036, 0.012, 0.07), Vector3(0, 0.09, -0.02), metal)
	_box(root, Vector3(0.004, 0.036, 0.07), Vector3(-0.016, 0.1, -0.02), metal)
	_box(root, Vector3(0.004, 0.036, 0.07), Vector3(0.016, 0.1, -0.02), metal)
	_box(root, Vector3(0.036, 0.006, 0.07), Vector3(0, 0.12, -0.02), metal)
	var dot := MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.0022
	dot_mesh.height = 0.0044
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(4.0, 0.15, 0.1)
	dot_mesh.material = dot_mat
	dot.mesh = dot_mesh
	dot.position = Vector3(0, 0.1, -0.04)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dot)
	_add_muzzle(root, Vector3(0, 0.042, -0.74), 0.2)


static func _build_pistol(root: Node3D) -> void:
	var metal := _mat("gunmetal", Color(0.46, 0.47, 0.5), 0.55, 0.4)
	var polymer := _mat("polymer", Color(0.16, 0.17, 0.18), 0.0, 0.5)
	_box(root, Vector3(0.03, 0.036, 0.2), Vector3(0, 0.075, -0.03), metal)
	_box(root, Vector3(0.03, 0.024, 0.16), Vector3(0, 0.046, -0.01), polymer)
	_box(root, Vector3(0.032, 0.105, 0.042), Vector3(0, -0.01, 0.07), polymer, Vector3(15, 0, 0))
	_cyl(root, 0.0085, 0.03, Vector3(0, 0.075, -0.14), metal)
	_box(root, Vector3(0.004, 0.012, 0.008), Vector3(0, 0.099, -0.118), metal)
	_box(root, Vector3(0.007, 0.01, 0.01), Vector3(-0.0075, 0.098, 0.058), metal)
	_box(root, Vector3(0.007, 0.01, 0.01), Vector3(0.0075, 0.098, 0.058), metal)
	_add_muzzle(root, Vector3(0, 0.075, -0.16), 0.12)


static func _build_shotgun(root: Node3D) -> void:
	var metal := _mat("gunmetal", Color(0.46, 0.47, 0.5), 0.55, 0.4)
	var wood := _mat("wood", Color(0.36, 0.19, 0.09), 0.0, 0.5)
	_box(root, Vector3(0.05, 0.07, 0.21), Vector3(0, 0.07, 0.0), metal)
	_cyl(root, 0.02, 0.56, Vector3(0, 0.095, -0.3), metal)
	_cyl(root, 0.016, 0.5, Vector3(0, 0.058, -0.27), metal)
	_box(root, Vector3(0.04, 0.085, 0.18), Vector3(0, 0.02, 0.19), wood, Vector3(-6, 0, 0))
	var pump := Node3D.new()
	pump.name = "Pump"
	pump.position = Vector3(0, 0.055, -0.28)
	root.add_child(pump)
	_box(pump, Vector3(0.052, 0.046, 0.17), Vector3.ZERO, wood)
	var bead := MeshInstance3D.new()
	var bead_mesh := SphereMesh.new()
	bead_mesh.radius = 0.0045
	bead_mesh.height = 0.009
	bead_mesh.radial_segments = 8
	bead_mesh.rings = 4
	bead_mesh.material = metal
	bead.mesh = bead_mesh
	bead.position = Vector3(0, 0.118, -0.57)
	bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bead)
	_add_muzzle(root, Vector3(0, 0.095, -0.6), 0.28)


static func _add_muzzle(root: Node3D, position: Vector3, flash_size: float) -> void:
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = position
	root.add_child(muzzle)

	var quad := QuadMesh.new()
	quad.size = Vector2(flash_size, flash_size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = _get_flash_texture()
	mat.albedo_color = Color(4.0, 2.6, 1.1)
	mat.no_depth_test = false
	quad.material = mat
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = quad
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.add_child(flash)

	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.0
	light.omni_range = 9.0
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.position = Vector3(0, 0, -0.15)
	muzzle.add_child(light)


static func _box(
	parent: Node3D, size: Vector3, position: Vector3, material: Material, rotation_deg := Vector3.ZERO
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return _instance(parent, mesh, position, rotation_deg)


## Cylinder lying along the Z axis.
static func _cyl(
	parent: Node3D, radius: float, length: float, position: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = material
	return _instance(parent, mesh, position, Vector3(90, 0, 0))


static func _instance(parent: Node3D, mesh: Mesh, position: Vector3, rotation_deg: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _mat(key: String, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.metallic_specular = 0.6
	m.roughness = roughness
	_materials[key] = m
	return m


static func _get_flash_texture() -> ImageTexture:
	if _flash_texture:
		return _flash_texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x, y) / (size - 1) * 2.0 - Vector2.ONE
			var r := p.length()
			var angle := atan2(p.y, p.x)
			# Soft core plus a 6-point star, so the flash reads as a burst and not a blob.
			var core := exp(-r * r * 9.0)
			var star := pow(absf(cos(angle * 3.0)), 6.0) * exp(-r * 3.2)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(core + star * 0.9, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, r))))
	_flash_texture = ImageTexture.create_from_image(img)
	return _flash_texture
