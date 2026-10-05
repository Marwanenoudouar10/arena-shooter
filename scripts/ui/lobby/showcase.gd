extends Node3D
## The picked gun shown big on the stage while you choose weapons, floating over the
## turntable. Drag to spin it; a flick keeps it turning for a moment.

const LENGTH := 1.35  # metres from stock to muzzle on the stage

var spinner: Node3D  # turns; the guns sit on it, the lights stay put
var guns := {}  # gun id -> Node3D (each centred on the spinner)
var spin_speed := 0.0


## One model per gun, scaled to the same length and centred, all hidden.
func build(gun_items: Array, load_glb: Callable) -> void:
	spinner = Node3D.new()
	add_child(spinner)
	_light(Vector3(0.4, 0.8, 1.6), Color(1.0, 0.95, 0.88), 9.0)  # soft key from the front
	_light(Vector3(-1.4, 0.5, -1.0), Color(1.0, 0.5, 0.25), 7.0)  # warm rim from behind
	for item in gun_items:
		var holder := Node3D.new()
		spinner.add_child(holder)
		var model: Node3D = load_glb.call(item["file"])
		holder.add_child(model)
		for node in model.find_children("scope", "", true, false):
			(node as Node3D).hide()  # the sniper's own scope; the game fits optics separately
		var bounds := _bounds(model)
		var scale_by := LENGTH / maxf(bounds.size.x, 0.001)
		model.scale = Vector3.ONE * scale_by
		model.position = -bounds.get_center() * scale_by
		holder.hide()
		guns[item["id"]] = holder
	spinner.rotation.y = deg_to_rad(-25)


func show_gun(id: String) -> void:
	for gun_id in guns:
		guns[gun_id].visible = gun_id == id


func turn(amount: float) -> void:
	spinner.rotation.y += amount


func coast(dt: float, dragging: bool) -> void:
	if not dragging:
		spinner.rotation.y += spin_speed * dt
		spin_speed = lerpf(spin_speed, 0.0, minf(1.0, dt * 3.0))


func _light(at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 5.0
	add_child(light)


func _bounds(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible:
			continue
		var box := model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
