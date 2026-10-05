extends RefCounted
## Shot and reload effects of the first-person gun: the muzzle flash and its light, brass
## casings thrown out of the ejection port, and empty magazines falling away. Casings and
## magazines live in the world (not under the camera), so they fall on their own path.

const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")

var vm: Viewmodel
var muzzle_light: OmniLight3D
var muzzle_flash: MeshInstance3D
var flash_left := 0.0
var casings: Array[Dictionary] = []  # {node, vel, spin, life}


func _init(viewmodel: Viewmodel) -> void:
	vm = viewmodel


## Makes the muzzle light and flash and puts them under the viewmodel.
func build() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.8, 0.45)
	muzzle_light.omni_range = 4.0
	muzzle_light.light_energy = 0.0
	vm.add_child(muzzle_light)
	# Star-shaped flash drawn into a small texture once.
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x, y) / (size - 1) * 2.0 - Vector2.ONE
			var spikes := pow(absf(cos(atan2(p.y, p.x) * 3.0)), 6.0)
			var a := clampf(1.0 - p.length() / (0.35 + 0.65 * spikes), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.85, 0.5, a * a * 0.75))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = ImageTexture.create_from_image(img)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)  # model units: about 14 cm
	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.mesh = quad
	muzzle_flash.material_override = mat
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	vm.add_child(muzzle_flash)


## A shot: flash for a moment, turned and sized a bit differently each time, and a casing.
func fired() -> void:
	flash_left = 0.03
	muzzle_flash.rotation.z = randf() * TAU
	muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.2)
	_spawn_casing()


## Each frame: the light follows the muzzle while the flash lasts, debris falls.
func update(dt: float, ads: float) -> void:
	flash_left -= dt
	muzzle_light.global_position = vm.muzzle_position()
	# Aiming puts the muzzle right on your line of sight: no flash picture then, and a
	# much softer light, so you can still see what you are shooting at.
	muzzle_light.light_energy = (1.6 * (1.0 - ads * 0.8)) if flash_left > 0.0 else 0.0
	muzzle_flash.visible = flash_left > 0.0 and ads < 0.3
	_update_debris(dt)


## The empty magazine falls out into the world and disappears after a moment.
func drop_magazine(mag: MeshInstance3D) -> void:
	var copy := MeshInstance3D.new()
	copy.mesh = mag.mesh
	copy.material_override = mag.material_override
	vm.world.add_child(copy)
	copy.global_transform = mag.global_transform
	var down := -vm.global_basis.y
	vm.dropped.append({"node": copy, "vel": down * 1.2 + vm.global_basis.x * 0.3, "spin": Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(3, 6)), "life": 1.6})


func _spawn_casing() -> void:
	var eject: Node3D = vm.guns[vm.gun_id]["sockets"]["eject"]
	var casing: MeshInstance3D
	if casings.size() < 24:
		var shell := CylinderMesh.new()
		shell.top_radius = 0.0045
		shell.bottom_radius = 0.0045
		shell.height = 0.022
		shell.radial_segments = 8
		casing = MeshInstance3D.new()
		casing.mesh = shell
		casing.material_override = _mat(Color(0.85, 0.65, 0.25), 0.3)
		(casing.material_override as StandardMaterial3D).metallic = 0.9
		vm.world.add_child(casing)
	else:
		var oldest: Dictionary = casings.pop_front()
		casing = oldest["node"]
	casing.global_position = eject.global_position
	casing.rotation = Vector3(0, 0, PI / 2)
	casing.show()
	var axes := vm.global_basis
	var vel := axes.x * randf_range(1.6, 2.4) + axes.y * randf_range(1.0, 1.6) + axes.z * randf_range(0.2, 0.6)
	casings.append({"node": casing, "vel": vel, "spin": Vector3(randf_range(-20, 20), randf_range(-20, 20), 0), "life": 0.9})


func _update_debris(dt: float) -> void:
	for item in casings:
		if item["life"] > 0.0:
			item["life"] -= dt
			item["vel"] += Vector3(0, -9.8, 0) * dt
			var node: MeshInstance3D = item["node"]
			node.global_position += item["vel"] * dt
			node.rotation += item["spin"] * dt
			node.visible = item["life"] > 0.0
	for item in vm.dropped.duplicate():
		item["life"] -= dt
		item["vel"] += Vector3(0, -9.8, 0) * dt
		var node: MeshInstance3D = item["node"]
		node.global_position += item["vel"] * dt
		node.rotation += item["spin"] * dt
		if item["life"] <= 0.0:
			node.queue_free()
			vm.dropped.erase(item)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # open tubes show their inside
	return mat
