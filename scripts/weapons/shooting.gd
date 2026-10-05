extends Node
## What happens when you fire at the enemy: sound, every pellet's ray inside the spread,
## damage with headshots and range falloff, hit markers, bullet holes where shots miss,
## tracers from the muzzle, and the recoil kick.

const E := preload("res://scripts/core/enums.gd")
const Crosshair := preload("res://scripts/ui/crosshair.gd")
const AimMath := preload("res://scripts/weapons/aim_math.gd")

const HEAD_MULT := 1.5

var game: Node3D


func fire() -> void:
	var gun: Dictionary = game.gun.data()
	var cam: Camera3D = game.cam
	var enemy: Node = game.enemy
	var session: Node = game.session
	game.gun.ammo -= 1
	session.shots += 1
	game.sfx.play("shot_" + gun["sound"], gun["volume"], gun["pitch"])
	if gun["mode"] in ["auto", "semi"] and gun["reload_style"] != "revolver":
		game.sfx.play_later("casing", randf_range(0.45, 0.7), -18.0)  # brass hitting the floor
	game.viewmodel.fired()
	# Every pellet is its own ray inside the spread cone (aiming tightens it).
	var forward := -cam.global_basis.z
	var ads: float = game.gun.ads
	var spread := deg_to_rad(gun.get("spread", 0.0)) * lerpf(1.0, 0.7, ads)
	var damage := 0.0
	var hit := E.Hit.MISS
	for i in int(gun.get("pellets", 1)):
		var dir := forward
		if spread > 0.0:
			var turn := randf() * TAU
			var off := sqrt(randf()) * spread
			dir = (forward + (cam.global_basis.x * cos(turn) + cam.global_basis.y * sin(turn)) * tan(off)).normalized()
		var pellet: E.Hit = enemy.aim_hit(dir)
		var landed := Vector3.ZERO
		if pellet != E.Hit.MISS:
			damage += gun["damage"] * (HEAD_MULT if pellet == E.Hit.HEAD else 1.0) * falloff(gun)
			if hit != E.Hit.HEAD:
				hit = pellet
			var origin := cam.global_position
			var aim_at: Vector3 = enemy.head_center() if pellet == E.Hit.HEAD else enemy.body_center()
			landed = origin + dir * (aim_at - origin).dot(dir)
			game.impacts.body(landed, -dir)
		else:
			landed = mark_world(dir)
		if i == 0 and (gun["mode"] != "auto" or session.shots % 2 == 0):
			game.impacts.tracer(game.viewmodel.muzzle_position(), landed)
	if hit != E.Hit.MISS:
		session.shot_hits += 1
		if hit == E.Hit.HEAD:
			session.head_hits += 1
		var hp: float = enemy.hp
		session.damage_done += minf(damage, hp)  # overkill does not count
		if enemy.hurt(damage):
			session.kills += 1
			game.sfx.play("kill", -4.0)
			game.crosshair.show_marker(Crosshair.Marker.KILL)
		else:
			game.sfx.play("hit_head" if hit == E.Hit.HEAD else "hit_body", -3.0 if hit == E.Hit.HEAD else -6.0)
			game.crosshair.show_marker(Crosshair.Marker.HEAD if hit == E.Hit.HEAD else Crosshair.Marker.BODY)
	game.gun.kick()


## Damage share at the enemy's distance (shotguns lose punch with range).
func falloff(gun: Dictionary) -> float:
	if not gun.has("falloff"):
		return 1.0
	var f: Array = gun["falloff"]
	var dist: float = game.cam.global_position.distance_to(game.enemy.body_center())
	return lerpf(1.0, f[2], clampf((dist - f[0]) / (f[1] - f[0]), 0.0, 1.0))


## Where a shot along `dir` lands in the world (walls, floor, crates, cover): leave a
## bullet hole and a dust puff there. Returns the point.
func mark_world(dir: Vector3) -> Vector3:
	var origin: Vector3 = game.cam.global_position
	var best := 200.0
	var normal := Vector3.UP
	for box in game.world.bullet_boxes(game.map_name):
		var at: Variant = box.intersects_ray(origin, dir)
		if at != null and origin.distance_to(at) < best and not box.has_point(origin):
			best = origin.distance_to(at)
			normal = AimMath.box_face(box, at)
	if dir.y < -0.001:  # the ground plane under everything
		var to_floor := -origin.y / dir.y
		if to_floor < best:
			best = to_floor
			normal = Vector3.UP
	var point := origin + dir * best
	if best < 199.0:
		game.impacts.surface(point, normal)
	return point
