## Self-test: killing the enemy, headshot damage, recoil and reload, cover blocking shots,
## walking into crates, climbing the Arena stairs, and climbing onto ledges.

const E := preload("res://scripts/core/enums.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Shooting := preload("res://scripts/weapons/shooting.gd")
const T := preload("res://scripts/dev/test_helpers.gd")


static func run(g: Node3D) -> void:
	await _tracking(g)
	await _rifle(g)
	await _cover(g)
	await _arena(g)
	await _climbing(g)


## Tracking, every class: aim at the target, hold fire, force a quick kill.
static func _tracking(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	for cls_name in Classes.CLASS_NAMES:
		g.test_fire = false
		g.enemy.kind = cls_name
		g.enemy.apply_class()
		g.session.start_round(E.Mode.TRACKING, false)
		g.state = E.State.PLAYING
		await T.frames(g, 2)  # first frames after loading are long; let them pass
		g.enemy.hold_still(Vector3(0.0, 0.0, -12.0))
		g.test_fire = true
		g.enemy.hp = 0.01
		cam.look_at(g.enemy.body_center())
		await T.frames(g, 2)
		T.check(g.session.kills == 1, "tracking kill not registered for " + cls_name)
		T.check(g.enemy.dead_left > 0.0 and g.enemy.aim_hit() == E.Hit.MISS, "dead target still hittable for " + cls_name)
		print("tracking %s: %s" % [cls_name, g.session.summary()])
	g.test_fire = false
	g.enemy.kind = "Medium"
	g.enemy.apply_class()


## Rifle: a headshot does 1.5x, a body shot 1x, recoil lifts the aim, an empty mag reloads.
static func _rifle(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	var s: Node = g.session
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	var hp_before: float = g.enemy.hp
	cam.look_at(g.enemy.head_center())
	g.shooting.fire()
	var dmg: float = g.gun.data()["damage"]
	T.check(s.head_hits == 1 and is_equal_approx(hp_before - g.enemy.hp, dmg * Shooting.HEAD_MULT), "headshot damage wrong")
	cam.look_at(g.enemy.body_center())
	g.shooting.fire()
	T.check(s.shot_hits == 2 and s.head_hits == 1, "body shot not counted as body")
	T.check(is_equal_approx(hp_before - g.enemy.hp, dmg * (1.0 + Shooting.HEAD_MULT)), "body damage wrong")
	g.player.yaw = PI  # face the back wall so the rest are misses
	g.player.pitch = 0.0
	g.gun.recoil_pending = Vector2.ZERO
	g.player.look()
	g.gun.ammo = 6
	g.test_fire = true
	for i in 300:
		await g.get_tree().process_frame
		if g.gun.reload_left > 0.0:
			break
	g.test_fire = false
	T.check(g.gun.ammo == 0 and g.gun.reload_left > 0.0, "empty magazine did not start a reload")
	await T.frames(g, 30)
	var pitch: float = g.player.pitch
	T.check(pitch > deg_to_rad(g.gun.data()["recoil"] * 4.0), "recoil did not lift the aim")
	print("rifle: %d shots, %d hits, %d head, pitch +%.2f deg after burst" % [s.shots, s.shot_hits, s.head_hits, rad_to_deg(pitch)])
	g.gun.reload_left = 0.01
	await T.frames(g, 2)
	T.check(g.gun.ammo == g.gun.data()["mag"], "reload did not refill the magazine")


## Cover map: walls block shots, low walls leave the head open, crates stop you.
static func _cover(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	var player: Node = g.player
	g.map_name = "Cover"
	g.apply_map()
	var boxes: int = g.world.cover_boxes.size()
	T.check(boxes >= 7, "expected at least the 7 starter boxes, got %d" % boxes)
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	g.enemy.target.position = Vector3(0.0, 0.0, -13.0)  # behind the tall middle wall
	cam.look_at(g.enemy.body_center())
	T.check(g.enemy.aim_hit() == E.Hit.MISS, "shot went through the tall wall")
	g.enemy.target.position = Vector3(3.0, 0.0, -13.0)  # behind the low right wall
	cam.look_at(g.enemy.target.position + Vector3(0.0, 0.4, 0.0))  # hips, well below the 1 m top
	T.check(g.enemy.aim_hit() == E.Hit.MISS, "shot went through the low wall")
	cam.look_at(g.enemy.head_center())
	T.check(g.enemy.aim_hit() == E.Hit.HEAD, "head above the low wall not hittable")
	g.reset_view()
	player.pos = Vector3(-4.0, 0.0, 0.5)  # just in front of crate_left (z -1.6..-0.4)
	T.press(KEY_W, true)
	await T.frames(g, 60)
	T.press(KEY_W, false)
	T.check(player.pos.z > -0.15 and player.pos.y == 0.0, "walked into the crate: z=%.2f" % player.pos.z)
	var blocked_z: float = player.pos.z
	player.pos = Vector3(-4.0, 1.0, -1.0)  # drop onto the crate (top at 1.2 m)
	player.vel = Vector3.ZERO
	await T.frames(g, 30)
	T.check(is_equal_approx(player.pos.y, 1.2) and player.grounded, "did not land on the crate: y=%.2f" % player.pos.y)
	print("cover: walls block, head over low wall hittable, crate stops you at z=%.2f, stand on crate y=%.2f" % [blocked_z, player.pos.y])
	g.map_name = "Open"
	g.apply_map()


## Arena: start at the spawn, climb the stairs onto the 3 m deck, enemies stand on their zone.
static func _arena(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	var player: Node = g.player
	var world: Node3D = g.world
	g.map_name = "Arena"
	g.apply_map()
	T.check(world.cover_boxes.size() > 40 and world.maps["Arena"]["zones"].size() >= 4, "arena did not load")
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	var spawn: Vector3 = world.spawn_pos
	T.check(player.pos.is_equal_approx(spawn) and spawn.z < -1.0, "not placed at the arena spawn")
	T.check(not world.room_nodes[0].visible, "small room still showing in the arena")
	await T.frames(g, 2)
	g.reset_view()
	player.pos = Vector3(12.75, 0.0, -11.0)  # foot of the deck stairs
	T.press(KEY_W, true)
	var biggest_jump := 0.0
	var last_eye := cam.position.y
	for i in 600:
		await g.get_tree().process_frame
		biggest_jump = maxf(biggest_jump, absf(cam.position.y - last_eye))
		last_eye = cam.position.y
		if player.pos.z < -19.5:
			break
	T.press(KEY_W, false)
	T.check(maxf(biggest_jump, 0.0) < 0.06, "stairs still jerky: view jumped %.2f m in one frame" % biggest_jump)
	T.check(world.cover_ramps.size() >= 2, "staircases not found: %d" % world.cover_ramps.size())
	T.check(is_equal_approx(player.pos.y, 3.0), "did not climb onto the deck: y=%.2f z=%.2f" % [player.pos.y, player.pos.z])
	var climbed: Vector3 = player.pos
	for raised in world.maps["Arena"]["zones"]:
		if raised.position.y > 2.0:
			g.enemy.zone = raised
	var zone: AABB = g.enemy.zone
	g.enemy.hold_still(zone.get_center() + Vector3.UP * 0.5)  # drop it in, it must land on the deck, not the floor
	await T.frames(g, 60)
	var stands_at: float = g.enemy.target.position.y
	T.check(is_equal_approx(stands_at, zone.position.y), "target not standing on its raised zone: y=%.2f" % stands_at)
	print("arena: %d boxes, %d staircases, climbed smoothly to y=%.1f (biggest view step %.3f m), target stands at y=%.1f" % [world.cover_boxes.size(), world.cover_ramps.size(), climbed.y, biggest_jump, stands_at])
	g.map_name = "Open"
	g.apply_map()


## Climbing: hold W + Space into a crate and you end up on top; same from the side of the stairs.
static func _climbing(g: Node3D) -> void:
	var player: Node = g.player
	g.map_name = "Cover"
	g.apply_map()
	g.session.start_round(E.Mode.FLICKS, false)
	g.state = E.State.PLAYING
	await T.frames(g, 2)
	g.reset_view()
	player.pos = Vector3(-4.0, 0.0, 0.25)  # facing crate_left (1.2 m tall, z -1.6..-0.4)
	T.press(KEY_W, true)
	T.press(KEY_SPACE, true)
	var climbed_crate := false
	for i in 200:
		await g.get_tree().process_frame
		if not g.mantle.climbing() and is_equal_approx(player.pos.y, 1.2):
			climbed_crate = true
			break
	T.press(KEY_SPACE, false)
	T.press(KEY_W, false)
	T.check(climbed_crate, "could not climb the crate: y=%.2f" % player.pos.y)
	g.map_name = "Arena"
	g.apply_map()
	g.reset_view()
	player.pos = Vector3(11.3, 0.0, -15.5)  # beside the deck stairs, steps here are ~1.1 m up
	player.yaw = -PI / 2.0  # face +X, into the side of the stairs
	T.press(KEY_W, true)
	T.press(KEY_SPACE, true)
	var on_stairs := false
	var climbing_seen := false
	for i in 300:
		await g.get_tree().process_frame
		climbing_seen = climbing_seen or g.mantle.climbing()
		if climbing_seen and not g.mantle.climbing() and player.grounded:
			on_stairs = player.pos.y > 1.0
			break
	T.press(KEY_SPACE, false)
	T.press(KEY_W, false)
	T.check(on_stairs, "could not climb onto the stairs from the side: y=%.2f" % player.pos.y)
	print("climb: crate y=1.2, stairs from the side y=%.2f" % player.pos.y)
	g.map_name = "Open"
	g.apply_map()
