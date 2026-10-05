## Reads a map made in Blender (maps/*.glb) and turns its meshes into boxes for walking
## and shooting, enemy zones, the flick zone, your spawn point and staircases.


## Reads a Blender export at runtime (no editor import needed) and sorts its meshes
## into solid boxes, enemy zones, the flick zone and your spawn point.
static func read(path: String, parent: Node, material_for: Callable) -> Dictionary:
	var doc := GLTFDocument.new()
	var gltf := GLTFState.new()
	if doc.append_from_file(path, gltf) != OK:
		push_warning("Map not found at " + path)
		return {}
	var root := doc.generate_scene(gltf)
	parent.add_child(root)
	root.hide()
	var boxes: Array[AABB] = []
	var zones: Array[AABB] = []
	var step_ids: Array[int] = []
	var info := {"root": root, "boxes": boxes, "zones": zones, "flick_zone": AABB(), "spawn": Vector3.ZERO, "floor": AABB()}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var mesh_name := String(mesh.name)
		var box := mesh.global_transform * mesh.get_aabb()
		if mesh_name.begins_with("ref_"):
			mesh.queue_free()
		elif mesh_name.begins_with("zone_flicks"):
			info["flick_zone"] = box
			mesh.queue_free()
		elif mesh_name.begins_with("zone_"):
			zones.append(box)
			mesh.queue_free()
		elif mesh_name.begins_with("spawn_player"):
			info["spawn"] = Vector3(box.get_center().x, box.position.y, box.get_center().z)
			mesh.queue_free()
		else:
			if mesh_name.begins_with("floor"):
				info["floor"] = box
			mesh.material_override = material_for.call(mesh_name)
			if mesh_name.contains("step"):
				step_ids.append(boxes.size())
			boxes.append(box)
	info["ramps"] = find_ramps(boxes, step_ids)
	return info


## Groups touching step boxes into staircases. Each becomes a ramp over the stairs'
## footprint, rising toward the tallest step: {box, axis (0 = x, 2 = z), rising (+1/-1), steps}.
static func find_ramps(boxes: Array[AABB], step_ids: Array[int]) -> Array[Dictionary]:
	var ramps: Array[Dictionary] = []
	var left := step_ids.duplicate()
	while not left.is_empty():
		var group: Array[int] = [left.pop_back()]
		var grew := true
		while grew:
			grew = false
			for id in left.duplicate():
				for member in group:
					if boxes[id].grow(0.02).intersects(boxes[member]):
						group.append(id)
						left.erase(id)
						grew = true
						break
		if group.size() < 2:
			continue
		var area: AABB = boxes[group[0]]
		var lowest: AABB = area
		var highest: AABB = area
		for id in group:
			area = area.merge(boxes[id])
			if boxes[id].end.y < lowest.end.y:
				lowest = boxes[id]
			if boxes[id].end.y > highest.end.y:
				highest = boxes[id]
		var rise := highest.get_center() - lowest.get_center()
		var axis := 0 if absf(rise.x) > absf(rise.z) else 2
		ramps.append({"box": area, "axis": axis, "rising": signf(rise[axis]), "steps": group})
	return ramps


## Height of a ramp's surface at (x, z), from its floor at the low end to the top step.
static func ramp_height(ramp: Dictionary, pos: Vector3) -> float:
	var area: AABB = ramp["box"]
	var axis: int = ramp["axis"]
	var along := pos[axis] - area.position[axis] if ramp["rising"] > 0.0 else area.end[axis] - pos[axis]
	return area.position.y + area.size.y * clampf(along / area.size[axis], 0.0, 1.0)
