## Renders each map from a good spot into assets/ui/map_<name>.png for the lobby's map
## picker (flag --thumbs).

const Maps := preload("res://scripts/data/maps.gd")

const VIEWS := {  # map -> [camera position, look at]
	"Open": [Vector3(0, 2.2, 3), Vector3(0, 1.0, -16)],
	"Cover": [Vector3(-3, 2.6, 3), Vector3(1, 1.0, -12)],
	"Arena": [Vector3(-16, 15, 8), Vector3(2, 0, -26)],
}


static func make(g: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	g.ui.hide()
	g.viewmodel.hide()
	g.enemy.target.hide()
	g.world.marker.hide()
	var cam: Camera3D = g.cam
	for map_id in Maps.MAP_NAMES:
		g.map_name = map_id
		g.apply_map()
		cam.position = VIEWS[map_id][0]
		cam.look_at(VIEWS[map_id][1])
		cam.fov = 80
		for i in 20:
			await g.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := g.get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://assets/ui/map_%s.png" % map_id.to_lower()))
	g.get_tree().quit()
