## Loads a .glb file at runtime (assets/ and maps/ are never imported by the editor).


static func scene(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var gltf := GLTFState.new()
	if doc.append_from_file(path, gltf) != OK:
		push_error("Could not load " + path)
		return Node3D.new()
	return doc.generate_scene(gltf)
