## Screenshot tool: sets up a scene from flags, waits a moment, saves a PNG and quits.
## godot --path . -- --shot=out.png [--menu[=build|settings]] [--flicks] [--map=Cover]
##   [--class=Light] [--gun=Striker] [--optic=Holo] [--near] [--hitboxes] [--ads] [--pause]
##   [--marks] [--close] [--reload=0.4] [--yaw=-30] [--vmside] [--emote=dance] [--clean]

const E := preload("res://scripts/core/enums.gd")
const Guns := preload("res://scripts/data/guns.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Maps := preload("res://scripts/data/maps.gd")
const Player := preload("res://scripts/player/player.gd")
const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")
const HitboxDebug := preload("res://scripts/dev/hitbox_debug.gd")
const T := preload("res://scripts/dev/test_helpers.gd")
const Emotes := preload("res://scripts/data/emotes.gd")


static func take(g: Node3D, path: String, args: PackedStringArray) -> void:
	var cam: Camera3D = g.cam
	for arg in args:
		if arg.begins_with("--class=") and arg.substr(8) in Classes.CLASSES:
			g.enemy.kind = arg.substr(8)
			g.enemy.apply_class()
		if arg.begins_with("--map=") and arg.substr(6) in Maps.MAP_NAMES:
			g.map_name = arg.substr(6)
			g.apply_map()
		if arg.begins_with("--gun=") and arg.substr(6) in Guns.GUNS:
			g.gun_name = arg.substr(6)
			g.apply_gun()
		if arg.begins_with("--optic=") and arg.substr(8) in Viewmodel.OPTICS:
			g.optic_name = arg.substr(8)
			g.apply_gun()
	if "--hitboxes" in args:
		var hitboxes := HitboxDebug.new()
		hitboxes.game = g
		g.add_child(hitboxes)
	var menu_screen := ""
	for arg in args:
		if arg.begins_with("--menu"):
			menu_screen = arg.substr(7) if arg.contains("=") else "home"
	if menu_screen != "":
		g.session.show_menu()
		g.lobby.show_screen("main" if menu_screen == "home" else menu_screen)
	else:
		_set_up_round(g, args)
	for i in 30:
		await g.get_tree().process_frame
	for arg in args:
		if arg.begins_with("--reload="):  # freeze the reload at this share (0..1) for a picture
			g.gun.ammo = 1
			g.gun.start_reload()
			g.gun.reload_left = g.gun.data()["reload"] * (1.0 - float(arg.substr(9)))
			g.set_process(false)
			g.update_viewmodel(0.0)
	if "--vmside" in args:
		_side_view(g, cam)
	if "--clean" in args:  # no fps / sens line, for pictures
		g.hud.info.modulate.a = 0.0
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(path)
	g.get_tree().quit()


static func _set_up_round(g: Node3D, args: PackedStringArray) -> void:
	var cam: Camera3D = g.cam
	g.session.start_round(E.Mode.FLICKS if "--flicks" in args else E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	if g.mode == E.Mode.TRACKING:
		if "--near" in args:  # close-up for checking models and hitboxes
			g.enemy.hold_still(Vector3(0.0, 0.0, -4.0))
			g.enemy.change_in = 100.0
			g.enemy.dash_cooldown = 100.0
		cam.look_at(g.enemy.body_center() + Vector3(0.6, 0, 0))
	if "--ads" in args:
		T.press_mouse(MOUSE_BUTTON_RIGHT, true)
	if "--pause" in args:
		var s: Node = g.session
		s.round_clock = 95.0
		s.kills = 7
		s.shots = 120
		s.shot_hits = 61
		s.head_hits = 14
		s.damage_done = 2900.0
		s.pause()
	for arg in args:
		if arg.begins_with("--yaw="):  # turn the view, degrees (negative = right)
			g.player.yaw = deg_to_rad(float(arg.substr(6)))
			g.player.pitch = 0.0
			g.player.look()
	if "--close" in args:  # stand two metres from the middle wall of the Arena
		g.player.pos = Vector3(0, 0, -13.8)
		cam.position = g.player.pos + Vector3(0, Player.EYE_HEIGHT, 0)
	for arg in args:
		if arg.begins_with("--emote="):  # third person, playing that emote
			for emote in Emotes.LIST:
				if emote["id"] == arg.substr(8):
					g.emote.start(emote)
	if "--marks" in args:  # spray a few holes in front of you for a picture
		for i in 14:
			var dir := (-cam.global_basis.z + cam.global_basis.x * randf_range(-0.08, 0.08) + cam.global_basis.y * randf_range(-0.05, 0.04)).normalized()
			g.shooting.mark_world(dir)


## Look at the first-person gun and arms from the side, with the hand targets marked.
static func _side_view(g: Node3D, cam: Camera3D) -> void:
	var side_cam := Camera3D.new()
	cam.add_child(side_cam)
	side_cam.position = Vector3(1.1, 0.0, -0.25)
	side_cam.rotation_degrees = Vector3(0, 90, 0)
	side_cam.fov = 40
	side_cam.near = 0.01
	side_cam.make_current()
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(0.1, 1.0, 0.3)
	dot_mat.no_depth_test = true
	for side in g.viewmodel.debug_targets:
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.012
		sphere.height = 0.024
		dot.mesh = sphere
		dot.material_override = dot_mat
		cam.add_child(dot)
		dot.position = g.viewmodel.debug_targets[side]
