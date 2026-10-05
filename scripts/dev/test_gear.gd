## Self-test: every gun and sight, aiming down sights, hands on the gun, the reload
## animation, the scope picture, single-shot guns, the lobby, and the character kit.

const E := preload("res://scripts/core/enums.gd")
const Guns := preload("res://scripts/data/guns.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")
const Rig := preload("res://scripts/enemies/rig.gd")
const T := preload("res://scripts/dev/test_helpers.gd")


static func run(g: Node3D) -> void:
	_guns(g)
	await _aim(g)
	_hands(g)
	await _reload(g)
	await _scope(g)
	await _single_shot(g)
	_lobby_and_characters(g)


## Guns: each one shows alone, fills its own magazine, and has a sight above its origin.
static func _guns(g: Node3D) -> void:
	var vm: Node3D = g.viewmodel
	for gun_id in Guns.GUN_NAMES:
		g.gun_name = gun_id
		g.apply_gun()
		T.check(g.gun.ammo == Guns.GUNS[gun_id]["mag"] and vm.guns[gun_id]["node"].visible, "gun %s not ready" % gun_id)
		for other in Guns.GUN_NAMES:
			T.check(other == gun_id or not vm.guns[other]["node"].visible, "two guns showing")
		for optic_id in Guns.GUNS[gun_id]["optics"]:
			g.optic_name = optic_id
			g.apply_gun()
			var pose: Vector3 = vm.ads_pose()
			var far_enough := pose.z < (0.05 if optic_id == "Scope" else -0.15)  # a scope sits right at the eye
			T.check(pose.y < -0.02 and far_enough, "sight of %s + %s looks wrong: %s" % [gun_id, optic_id, pose])
	g.gun_name = "Striker"
	g.optic_name = "RedDot"
	g.apply_gun()


## Aim down sights: right click zooms in and brings the sights to the centre, release undoes it.
static func _aim(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	var vm: Node3D = g.viewmodel
	var fov: float = g.fov
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	T.press_mouse(MOUSE_BUTTON_RIGHT, true)
	await T.frames(g, 150)  # also lets the gun finish its raise at round start
	var ads: float = g.gun.ads
	T.check(is_equal_approx(ads, 1.0) and cam.fov < fov * 0.8, "aiming did not zoom: ads=%.2f fov=%.1f" % [ads, cam.fov])
	T.check(vm.position.distance_to(vm.ads_pose()) < 0.02, "sights not centred when aiming")
	T.press_mouse(MOUSE_BUTTON_RIGHT, false)
	await T.frames(g, 40)
	T.check(g.gun.ads == 0.0 and is_equal_approx(cam.fov, fov), "aiming did not end")
	var zoom: float = vm.zoom()
	print("aim: zoom fov %.1f -> %.1f, sights centred" % [fov, fov * zoom])


## Hands: the right hand's knuckles sit on the pistol grip, the left hand on the handguard.
static func _hands(g: Node3D) -> void:
	var vm: Node3D = g.viewmodel
	var body_sk: Skeleton3D = vm.body["skeleton"]
	var ids: Dictionary = vm.body["ids"]
	var knuckles_r: Vector3 = body_sk.global_transform * body_sk.get_bone_global_pose(ids[Rig.knuckle(1, "R")]).origin
	var knuckles_l: Vector3 = body_sk.global_transform * body_sk.get_bone_global_pose(ids[Rig.knuckle(1, "L")]).origin
	var gun_node: Node3D = vm.guns[g.gun_name]["node"]
	var sockets: Dictionary = vm.guns[g.gun_name]["sockets"]
	var grip_at := gun_node.to_global(sockets["grip"].position)
	var hand_at := gun_node.to_global(sockets["hand"].position)
	var right := knuckles_r.distance_to(grip_at)
	var left := knuckles_l.distance_to(hand_at)
	T.check(right < 0.1 and left < 0.1, "hands not on the gun: right %.3f m, left %.3f m" % [right, left])
	print("hands: right %.3f m from the grip, left %.3f m from the handguard" % [right, left])


## Reload: the magazine comes out, the empty one drops, a new one goes in.
static func _reload(g: Node3D) -> void:
	var vm: Node3D = g.viewmodel
	var mag: MeshInstance3D = vm.guns[g.gun_name]["parts"]["magazine"]
	var mag_rest := mag.position
	g.gun.ammo = 5
	g.gun.start_reload()
	var saw_out := false
	var saw_gone := false
	var saw_drop := false
	while g.gun.reload_left > 0.0:
		await g.get_tree().process_frame
		saw_out = saw_out or mag.position.distance_to(mag_rest) > 0.3
		saw_gone = saw_gone or not mag.visible
		saw_drop = saw_drop or not vm.dropped.is_empty()
	await g.get_tree().process_frame
	T.check(saw_out and saw_gone and saw_drop, "magazine did not come out (out=%s gone=%s drop=%s)" % [saw_out, saw_gone, saw_drop])
	T.check(mag.visible and mag.position.is_equal_approx(mag_rest) and g.gun.ammo == g.gun.data()["mag"], "magazine not back in after reload")
	print("reload: magazine out, dropped, new one in")


## Scope: aiming with it shows the scope picture instead of the gun.
static func _scope(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	var scope: Node = g.scope
	g.optic_name = "Scope"
	g.apply_gun()
	T.press_mouse(MOUSE_BUTTON_RIGHT, true)
	await T.frames(g, 40)
	var scope_fov: float = scope.cam.fov
	T.check(scope.overlay.visible and g.viewmodel.visible and scope_fov < cam.fov * 0.3, "scope picture did not show: fov %.1f vs %.1f" % [scope_fov, cam.fov])
	T.press_mouse(MOUSE_BUTTON_RIGHT, false)
	await T.frames(g, 40)
	T.check(not scope.overlay.visible, "scope picture did not go away")
	g.optic_name = "RedDot"
	g.apply_gun()
	print("scope: 4x picture inside the lens on aim, gone on release")


## Single-shot guns: holding the trigger fires once. Pump: a second click during the pump
## does nothing. Shells: an empty shotgun loads one round at a time.
static func _single_shot(g: Node3D) -> void:
	for gun_id in ["Sting", "KS-12"]:
		g.gun_name = gun_id
		g.apply_gun()
		g.session.start_round(E.Mode.TRACKING, false)
		g.state = E.State.PLAYING
		var before: int = g.session.shots
		g.test_fire = true
		await T.frames(g, 60)
		g.test_fire = false
		var fired: int = g.session.shots - before
		T.check(fired == 1, "%s fired %d times on one long press" % [gun_id, fired])
	while g.gun.cycle_left > 0.0:  # let the pump finish first
		await g.get_tree().process_frame
	g.gun.ammo = 0
	g.gun.start_reload()
	var loaded_steps := 0
	var last_ammo: int = g.gun.ammo
	while g.gun.reload_left > 0.0:
		await g.get_tree().process_frame
		if g.gun.ammo != last_ammo:
			loaded_steps += 1
			last_ammo = g.gun.ammo
	var mag: int = Guns.GUNS["KS-12"]["mag"]
	T.check(g.gun.ammo == mag and loaded_steps == mag, "shotgun did not load shell by shell (%d steps)" % loaded_steps)
	print("guns: semi-auto and pump fire once per click, shotgun loads shell by shell")
	g.gun_name = "Striker"
	g.apply_gun()


## Lobby: pick a class (its first weapon comes with it), a weapon, clothes and a map, then
## PLAY. Characters: one blueprint, each class overrides only its own parts, every part is
## bound to the shared skeleton, and clothes you pick change your character only.
static func _lobby_and_characters(g: Node3D) -> void:
	var lobby: Control = g.lobby
	var models: Dictionary = g.enemy.models
	g.session.show_menu()
	lobby.pick_class("Heavy")
	T.check(Guns.GUNS[lobby.choice["gun"]]["class"] == "Heavy", "class change kept another class's gun")
	lobby.pick_gun("KS-12")
	T.check(Kit.worn(models["Light"]["pivot"]) == Kit.BASE, "Light look wrong")
	T.check(Kit.worn(models["Heavy"]["pivot"]) == {"Head": "head_short", "Top": "top_jacket", "Legs": "legs_cargo", "Feet": "feet_shoes"}, "Heavy look wrong")
	for cls_name in Classes.CLASS_NAMES:
		var skel: Skeleton3D = models[cls_name]["skeleton"]
		var parts := skel.find_children("*", "MeshInstance3D", true, false)
		T.check(parts.size() >= 4, "%s has %d meshes, expected one or more per slot" % [cls_name, parts.size()])
		for part in parts:
			var skin: Skin = part.skin
			T.check(part.mesh and skin and part.get_node(part.skeleton) == skel, "%s %s not bound" % [cls_name, part.name])
			for i in skin.get_bind_count():
				var bone: int = skel.find_bone(skin.get_bind_name(i)) if skin.get_bind_name(i) != "" else skin.get_bind_bone(i)
				T.check(bone >= 0 and bone < skel.get_bone_count(), "%s %s bind %d has no bone" % [cls_name, part.name, i])
	lobby.choice["outfits"] = {}  # ignore clothes from saved settings
	lobby.wear("Top", "top_tshirt")
	T.check(g.outfits == {"Heavy": {"Top": "top_tshirt"}}, "outfit not passed to the game")
	T.check(Kit.worn(lobby.characters["Heavy"]["root"])["Top"] == "top_tshirt", "lobby character did not change clothes")
	var my_body: Node3D = g.viewmodel.bodies["Heavy"]["root"]
	T.check(Kit.worn(my_body) == {"Head": "head_short", "Top": "top_tshirt", "Legs": "legs_cargo", "Feet": "feet_shoes"}, "first-person body did not change clothes")
	T.check(not (my_body.find_child("Wear_Head", true, false) as Node3D).visible, "first-person head showed after a clothes change")
	T.check(Kit.worn(models["Heavy"]["pivot"])["Top"] == "top_jacket", "enemies wore your clothes")
	lobby.wear("Top", "top_jacket")
	T.check(g.outfits.is_empty() and Kit.worn(my_body)["Top"] == "top_jacket", "picking the class top did not take the override off")
	T.check(Kit.look_for("Heavy", {"Top": "punk", "Legs": "top_polo"}) == Kit.look_for("Heavy"), "old or wrong saved clothes were not ignored")
	lobby.show_screen("locker")
	var cards: int = lobby.locker_ui.find_children("*", "Button", true, false).size()
	T.check(cards >= Kit.PARTS.size() and lobby.stage.mode == "character", "locker does not show every piece of clothing")
	lobby.show_screen("build")
	T.check(lobby.stage.mode == "gun" and lobby.stage.showcase.visible and lobby.stage.showcase.guns["KS-12"].visible, "picked gun not shown on the stage")
	T.check(lobby.icons.gun(Guns.GUNS["KS-12"]["file"]) != null and lobby.icons.part("top_jacket") != null, "card pictures missing")
	lobby.show_screen("main")
	print("characters: one blueprint, class looks, clothes swap live; locker and gun showcase work")
	while lobby.choice["map"] != "Cover":
		lobby.step_map(1)
	lobby.play.emit("fight")
	T.check(g.state == E.State.COUNTDOWN and not lobby.visible, "PLAY did not start the round")
	T.check(g.map_name == "Cover" and g.gun_name == "KS-12" and g.my_class == "Heavy" and g.gun.ammo == 6, "wrong loadout in game")
	print("lobby: Heavy + KS-12 on Cover started")
	g.map_name = "Open"
	g.gun_name = "Striker"
	g.my_class = "Medium"
	g.apply_map()
	g.apply_gun()
