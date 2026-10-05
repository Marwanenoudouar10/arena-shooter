extends Node
## Flick drill: a few orange balls float in the map's flick zone. Click one and it jumps
## somewhere else you can see; a click that hits nothing counts as a miss.

const Crosshair := preload("res://scripts/ui/crosshair.gd")
const AimMath := preload("res://scripts/weapons/aim_math.gd")

const RADIUS := 0.35
const COUNT := 3
const COLOR := Color(1.0, 0.36, 0.18)

var game: Node3D
var targets: Array[MeshInstance3D] = []


func build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	for i in COUNT:
		var t := MeshInstance3D.new()
		t.mesh = sphere
		t.material_override = mat
		game.add_child(t)
		targets.append(t)


func show_all() -> void:
	for t in targets:
		place(t)
		t.show()


func hide_all() -> void:
	for t in targets:
		t.hide()


func place(target: MeshInstance3D) -> void:
	var area: AABB = game.world.maps.get(game.map_name, {}).get("flick_zone", AABB())
	if area.size == Vector3.ZERO:
		area = AABB(Vector3(-6.0, 0.8, -14.0), Vector3(12.0, 3.4, 3.0))
	var pos := Vector3.ZERO
	for attempt in 60:
		pos = area.position + Vector3(randf(), randf(), randf()) * area.size
		var clear := _visible_from_camera(pos)
		for other in targets:
			if other != target and other.position.distance_to(pos) < 1.6:
				clear = false
				break
		if clear:
			break
	target.position = pos


func shoot() -> void:
	var gun: Dictionary = game.gun.data()
	var cam: Camera3D = game.cam
	game.sfx.play("shot_" + gun["sound"], gun["volume"] - 4.0, gun["pitch"])
	game.viewmodel.fired()
	var forward := -cam.global_basis.z
	for t in targets:
		if AimMath.ray_hits_sphere(cam.global_position, forward, t.position, RADIUS) \
				and not game.world.blocks(cam.global_position, forward, t.position):
			game.session.hits += 1
			game.sfx.play("hit_body", -6.0)
			game.impacts.body(t.position, cam.global_position - t.position)
			game.crosshair.show_marker(Crosshair.Marker.BODY)
			place(t)
			return
	game.session.misses += 1
	game.shooting.mark_world(forward)


func _visible_from_camera(pos: Vector3) -> bool:
	if not game.world.cover_on():
		return true
	for box in game.world.cover_boxes:
		if box.grow(RADIUS).has_point(pos):
			return false
	var origin: Vector3 = game.cam.global_position
	var dist: float = game.world.cover_distance(origin, (pos - origin).normalized())
	return dist > origin.distance_to(pos)
