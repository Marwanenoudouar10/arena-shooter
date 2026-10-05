extends Node3D
## The place you play in: sky, sun, the small concrete room, and the Blender maps. Knows
## which boxes are solid on the map in play, the staircases, your spawn point and how far
## you can walk.

const Maps := preload("res://scripts/data/maps.gd")
const Materials := preload("res://scripts/world/materials.gd")
const MapLoader := preload("res://scripts/world/map_loader.gd")

var env: Environment
var sun: DirectionalLight3D
var maps := {}  # name -> {root, boxes, zones, flick_zone, spawn, floor, ramps}
var cover_boxes: Array[AABB] = []  # solid boxes of the map in play
var cover_ramps: Array[Dictionary] = []  # staircases of the map in play, see MapLoader.find_ramps()
var room_nodes: Array[Node3D] = []  # the small room, hidden on the Arena
var room_boxes: Array[AABB] = []  # its floor and walls, for where bullets land
var spawn_pos := Vector3.ZERO
var play_area := Maps.ROOM_AREA
var marker: MeshInstance3D  # the tall green line the 360 test turns from
var mat_floor: Material
var mat_wall: Material
var mat_concrete: Material
var mat_container: Material


func build() -> void:
	# Open-air arena: sky light, sun with shadows, soft contact shadows (SSAO), light haze.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.68, 0.76, 0.86)
	sky_mat.ground_horizon_color = Color(0.68, 0.76, 0.86)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.22)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.68, 0.76, 0.86)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	# Room from x -20..20, z -26..8: concrete floor with 2 m tiles (handy for judging
	# distance), painted wall panels, and a glowing orange band like arena lighting.
	# Photo textures (Poly Haven, CC0); generated surfaces if a file is missing.
	mat_floor = Materials.photo("concrete_floor_worn_001", 3.0, Color.WHITE, Vector3.ONE,
			func() -> Material: return Materials.painted(Color(0.44, 0.44, 0.45), Color(0.3, 0.3, 0.31), 2.0, 0.12, 0.85, 11))
	# Both of these photos are green; grey them out (and calm the paint blotches) then tint.
	mat_wall = Materials.photo("painted_concrete", 3.0, Color(0.62, 0.7, 0.84), Vector3(1.05, 0.55, 0.0),
			func() -> Material: return Materials.painted(Color(0.26, 0.31, 0.4), Color(0.18, 0.21, 0.27), 3.0, 0.06, 0.6, 12))
	mat_concrete = Materials.photo("concrete_wall_008", 2.0, Color.WHITE, Vector3.ONE,
			func() -> Material: return Materials.painted(Color(0.62, 0.6, 0.55), Color(0.45, 0.43, 0.4), 1.0, 0.1, 0.9, 13))
	mat_container = Materials.photo("container_side", 2.5, Color(1.0, 0.58, 0.2), Vector3(1.4, 1.0, 0.0),
			func() -> Material: return Materials.painted(Color(0.86, 0.52, 0.14), Color(0.45, 0.27, 0.08), 0.6, 0.08, 0.5, 14))
	room_nodes.append(add_box(Vector3(0, -0.1, -9), Vector3(40, 0.2, 34), mat_floor))
	room_nodes.append(add_box(Vector3(0, 6, -26), Vector3(40, 12, 0.5), mat_wall))
	room_nodes.append(add_box(Vector3(0, 6, 8), Vector3(40, 12, 0.5), mat_wall))
	room_nodes.append(add_box(Vector3(-20, 6, -9), Vector3(0.5, 12, 34), mat_wall))
	room_nodes.append(add_box(Vector3(20, 6, -9), Vector3(0.5, 12, 34), mat_wall))
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(1.0, 0.45, 0.1)
	band.emission_enabled = true
	band.emission = Color(1.0, 0.45, 0.1)
	band.emission_energy_multiplier = 2.0
	room_nodes.append(add_box(Vector3(0, 3.0, -25.7), Vector3(40, 0.25, 0.1), band))
	room_nodes.append(add_box(Vector3(0, 3.0, 7.7), Vector3(40, 0.25, 0.1), band))
	room_nodes.append(add_box(Vector3(-19.7, 3.0, -9), Vector3(0.1, 0.25, 34), band))
	room_nodes.append(add_box(Vector3(19.7, 3.0, -9), Vector3(0.1, 0.25, 34), band))
	for i in 5:  # floor and the four walls
		var wall := room_nodes[i] as MeshInstance3D
		room_boxes.append(wall.global_transform * wall.get_aabb())

	var marker_mat := StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Color(0.3, 1.0, 0.6)
	marker = add_box(Vector3(0, 3, -12), Vector3(0.08, 6, 0.08), marker_mat)

	for name_ in Maps.MAP_FILES:
		maps[name_] = MapLoader.read(Maps.MAP_FILES[name_], self, _map_material)


func add_box(pos: Vector3, box_size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


## Shows one map and makes its boxes the solid ones. Returns the map actually shown
## (the Open room when that map failed to load).
func show_map(map_name: String) -> String:
	if map_name != "Open" and maps.get(map_name, {}).is_empty():
		map_name = "Open"
	for other in maps:
		if not maps[other].is_empty():
			maps[other]["root"].visible = other == map_name
	var info: Dictionary = maps.get(map_name, {})
	cover_boxes.assign(info.get("boxes", []))
	cover_ramps.assign(info.get("ramps", []))
	for node in room_nodes:
		node.visible = map_name != "Arena"
	spawn_pos = info.get("spawn", Vector3.ZERO)
	play_area = Maps.ROOM_AREA
	var floor_box: AABB = info.get("floor", AABB())
	if floor_box.size != Vector3.ZERO:
		play_area = Rect2(floor_box.position.x + 0.5, floor_box.position.z + 0.5, floor_box.size.x - 1.0, floor_box.size.z - 1.0)
	marker.position = spawn_pos + Vector3(0, 3, -12)
	return map_name


func apply_quality(quality: String) -> void:
	var q: Dictionary = Maps.QUALITY[quality]
	var view := get_viewport()
	view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q["scale"] < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	view.scaling_3d_scale = q["scale"]
	view.msaa_3d = q["msaa"]
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q["msaa"] == Viewport.MSAA_DISABLED else Viewport.SCREEN_SPACE_AA_DISABLED
	env.ssao_enabled = q["ssao"]
	env.glow_enabled = q["glow"]
	env.fog_enabled = q["fog"]
	sun.directional_shadow_max_distance = q["shadow"]


func cover_on() -> bool:
	return not cover_boxes.is_empty()


## Where bullets can land: the map's boxes, plus the room's floor and walls when it shows.
func bullet_boxes(map_name: String) -> Array[AABB]:
	var boxes: Array[AABB] = cover_boxes.duplicate()
	if map_name != "Arena":
		boxes.append_array(room_boxes)
	return boxes


## Distance along the ray to the nearest cover box, INF if none.
func cover_distance(origin: Vector3, dir: Vector3) -> float:
	var nearest := INF
	for box in cover_boxes:
		var point: Variant = box.intersects_ray(origin, dir)
		if point != null:
			nearest = minf(nearest, origin.distance_to(point))
	return nearest


func _map_material(mesh_name: String) -> Material:
	if mesh_name.begins_with("floor"):
		return mat_floor
	if mesh_name.begins_with("crate") or mesh_name.begins_with("container"):
		return mat_container
	if mesh_name.begins_with("outer") or mesh_name.begins_with("warehouse") or mesh_name == "deck" or mesh_name.begins_with("deck_pillar"):
		return mat_wall
	return mat_concrete


## True when a wall is between `origin` and `point`, along the ray `dir`.
func blocks(origin: Vector3, dir: Vector3, point: Vector3) -> bool:
	return cover_on() and cover_distance(origin, dir) < (point - origin).dot(dir)
