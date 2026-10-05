extends RefCounted
## Loads the guns and optics for the first-person view (viewmodel.gd uses it once, in setup).
##
## Guns come from assets/guns/<gun>_rig.glb (made in Blender by make_gun_rigs.py and
## make_more_rigs.py): a "body" mesh, moving parts as their own meshes (magazine, pump,
## bolt, slide, cylinder) and socket_* empties that say where the hands, optic, muzzle and
## ejection port are. Positions inside a gun are model units.
## Every optic with a model is put on each gun's mount; the viewmodel shows the one in use.

const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")

var _wear: NoiseTexture2D
var _grain: NoiseTexture2D


## Loads one gun rig under parent and finds its parts: {node, parts, rests, sockets, stock_x}.
func load_gun(file: String, load_glb: Callable, parent: Node3D) -> Dictionary:
	var root: Node3D = load_glb.call(file)
	root.rotation_degrees = Vector3(0, 90, 0)  # model barrel points +X, camera looks -Z
	root.scale = Vector3.ONE * Viewmodel.GUN_SCALE
	parent.add_child(root)
	var sockets := {}
	var parts := {}
	var rests := {}
	var stock_x := 0.0
	for node in root.find_children("*", "", true, false):
		if String(node.name).begins_with("socket_"):
			sockets[String(node.name).trim_prefix("socket_")] = node
		elif node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_make_real(mesh)
			if mesh.name in ["magazine", "pump", "bolt", "slide", "cylinder", "scope"]:
				parts[String(mesh.name)] = mesh
				rests[String(mesh.name)] = mesh.transform
			else:
				stock_x = minf(stock_x, mesh.get_aabb().position.x)
	if parts.has("scope"):
		parts["scope"].hide()  # the sniper's own scope; ours goes on the mount instead
	return {"node": root, "parts": parts, "rests": rests, "sockets": sockets, "stock_x": stock_x}


## Every optic that has a model, put on the gun's mount: optic id -> {node, sight, lens, eye}.
func load_optics(mount: Node3D, load_glb: Callable) -> Dictionary:
	var sights := {}
	for optic_id in Viewmodel.OPTIC_IDS:
		if Viewmodel.OPTICS[optic_id].has("file"):
			var sight_root: Node3D = load_glb.call(Viewmodel.OPTICS[optic_id]["file"])
			sight_root.scale = Vector3.ONE * Viewmodel.OPTIC_SCALE / Viewmodel.GUN_SCALE  # metres in a model-unit space
			mount.add_child(sight_root)
			var sight_point: Node3D = sight_root.find_child("sight_point", true, false)
			for node in sight_root.find_children("*", "MeshInstance3D", true, false):
				(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var lens: MeshInstance3D = sight_root.find_child("lens_rear", true, false)
			var eye: Node3D = sight_root.find_child("eye_point", true, false)
			sights[optic_id] = {"node": sight_root, "sight": sight_point, "lens": lens, "eye": eye}
	return sights


## Turn the flat-coloured model materials into metal and wood that catch the light.
func _make_real(mesh: MeshInstance3D) -> void:
	for i in mesh.get_surface_override_material_count():
		var source := mesh.get_active_material(i) as StandardMaterial3D
		if source == null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var mat := source.duplicate() as StandardMaterial3D
		var c := mat.albedo_color
		var wood := c.r > c.b * 1.3 and c.r > 0.2
		mat.metallic = 0.0 if wood else 0.75
		mat.roughness = 0.62 if wood else 0.4
		mat.roughness_texture = _wear_texture()
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 3.0
		mat.normal_enabled = true
		mat.normal_texture = _grain_texture()
		mat.normal_scale = 0.25 if wood else 0.1
		mesh.set_surface_override_material(i, mat)


func _wear_texture() -> NoiseTexture2D:
	if _wear == null:
		_wear = NoiseTexture2D.new()
		_wear.seamless = true
		_wear.noise = FastNoiseLite.new()
		_wear.noise.frequency = 0.04
		_wear.color_ramp = Gradient.new()
		_wear.color_ramp.set_color(0, Color(0.32, 0.32, 0.32))  # polished, worn spots
		_wear.color_ramp.set_color(1, Color(0.7, 0.7, 0.7))
	return _wear


func _grain_texture() -> NoiseTexture2D:
	if _grain == null:
		_grain = NoiseTexture2D.new()
		_grain.seamless = true
		_grain.as_normal_map = true
		_grain.bump_strength = 3.0
		_grain.noise = FastNoiseLite.new()
		_grain.noise.frequency = 0.12
	return _grain
