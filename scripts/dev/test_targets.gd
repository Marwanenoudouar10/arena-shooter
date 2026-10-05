## Self-test: enemies hiding and peeking from cover, dashing, bullet holes, the flick drill,
## pausing and leaving a session, walking, jumping, sprinting, sliding, and sounds.

const E := preload("res://scripts/core/enums.gd")
const AI := preload("res://scripts/enemies/enemy_ai.gd")
const Player := preload("res://scripts/player/player.gd")
const T := preload("res://scripts/dev/test_helpers.gd")


static func run(g: Node3D) -> void:
	_cover_ai(g)
	_hit_marks(g)
	_flicks(g)
	await _session(g)
	await _movement(g)
	await _sprint_and_slide(g)
	_sounds(g)


## Smarter targets: hide spots are out of sight, peek spots show at least the head, Light dashes.
static func _cover_ai(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	var enemy: Node = g.enemy
	var ai: RefCounted = enemy.ai
	g.map_name = "Cover"
	g.apply_map()
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	for z in [-12.5, -14.0, -15.5]:
		enemy.target.position = Vector3(0.0, 0.0, z)
		ai.plan_hide()
		T.check(ai.plan == AI.Plan.HIDE, "no hide spot found at z=%.1f" % z)
		enemy.target.position.x = ai.goal_x
		cam.look_at(enemy.body_center())
		var body_hidden: bool = enemy.aim_hit() == E.Hit.MISS
		cam.look_at(enemy.head_center())
		T.check(body_hidden and enemy.aim_hit() == E.Hit.MISS, "visible at hide spot x=%.2f z=%.1f" % [ai.goal_x, z])
		var hide_x: float = ai.goal_x
		ai.plan_peek()
		enemy.target.position.x = ai.goal_x
		cam.look_at(enemy.head_center())
		T.check(enemy.aim_hit() == E.Hit.HEAD, "head hidden at peek spot x=%.2f z=%.1f" % [ai.goal_x, z])
		print("cover AI z=%.1f: hide x=%.2f, peek x=%.2f" % [z, hide_x, ai.goal_x])
	g.map_name = "Open"
	g.apply_map()
	enemy.kind = "Light"
	enemy.apply_class()
	g.session.start_round(E.Mode.TRACKING, false)
	ai.dash()
	T.check(absf(enemy.vel.x) >= AI.DASH_SPEED, "dash too slow")
	enemy.kind = "Medium"
	enemy.apply_class()


## Hit marks: a shot into a wall leaves a hole on that wall, facing you.
static func _hit_marks(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	g.map_name = "Open"
	g.apply_map()
	g.session.start_round(E.Mode.FLICKS, false)
	g.state = E.State.PLAYING
	cam.rotation = Vector3(0, PI, 0)  # face the wall behind the start (z = 8)
	var mark: Vector3 = g.shooting.mark_world(-cam.global_basis.z)
	var holes: Array[Decal] = g.impacts.holes
	var hole: Decal = holes[(g.impacts.next_hole - 1 + holes.size()) % holes.size()]
	T.check(hole.visible and absf(mark.z - 7.75) < 0.05 and hole.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.99, "bullet hole not on the wall: %s" % mark)
	print("hit marks: hole on the wall at z=%.2f" % mark.z)


## Flicks: one aimed hit, one miss.
static func _flicks(g: Node3D) -> void:
	var cam: Camera3D = g.cam
	g.session.start_round(E.Mode.FLICKS, false)
	g.state = E.State.PLAYING
	cam.look_at(g.flicks.targets[0].position)
	g.flicks.shoot()
	cam.rotation = Vector3(0, PI, 0)  # face the back wall
	g.flicks.shoot()
	T.check(g.session.hits == 1 and g.session.misses == 1, "flick hit/miss wrong")
	print("flicks: ", g.session.summary())


## No timer: a round keeps going; Esc pauses and resumes, the pause menu leads to the lobby.
static func _session(g: Node3D) -> void:
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	g.session.round_clock = 3600.0
	await g.get_tree().process_frame
	T.check(g.state == E.State.PLAYING, "the round ended by itself")
	T.press(KEY_ESCAPE, true)
	T.press(KEY_ESCAPE, false)
	await g.get_tree().process_frame
	T.check(g.state == E.State.PAUSED and g.pause_menu.visible, "Esc did not pause")
	var clock_paused: float = g.session.round_clock
	await g.get_tree().process_frame
	T.check(g.session.round_clock == clock_paused, "game kept running while paused")
	T.press(KEY_ESCAPE, true)
	T.press(KEY_ESCAPE, false)
	await g.get_tree().process_frame
	T.check(g.state == E.State.PLAYING and not g.pause_menu.visible, "Esc did not resume")
	g.session.end()
	T.check(g.state == E.State.MENU and g.lobby.visible, "did not go back to the lobby")
	print("session: no timer, Esc pauses and resumes, back to the lobby")


## Movement: hold W to walk forward, then tap Space to jump.
static func _movement(g: Node3D) -> void:
	var player: Node = g.player
	g.session.start_round(E.Mode.FLICKS, false)
	g.state = E.State.PLAYING
	T.press(KEY_W, true)
	await T.frames(g, 20)
	T.press(KEY_W, false)
	T.check(player.pos.z < -0.05, "W did not move forward")
	T.press(KEY_SPACE, true)
	await T.frames(g, 2)
	T.press(KEY_SPACE, false)
	T.check(player.pos.y > 0.0, "Space did not jump")
	var eye_at: Vector3 = player.pos + Vector3(0, player.eye, 0)
	T.check(g.cam.position.is_equal_approx(eye_at), "camera not following player")
	print("movement: z=%.2f y=%.2f" % [player.pos.z, player.pos.y])


## Sprint with W + Shift, then C at full speed starts a slide that is faster still.
static func _sprint_and_slide(g: Node3D) -> void:
	var player: Node = g.player
	g.session.start_round(E.Mode.FLICKS, false)
	g.state = E.State.PLAYING
	T.press(KEY_W, true)
	T.press(KEY_SHIFT, true)
	await T.frames(g, 60)
	var sprint_speed: float = player.flat_speed()
	T.check(sprint_speed > Player.MOVE_SPEED + 1.0, "sprint not faster than walking")
	T.press(KEY_C, true)
	await T.frames(g, 2)
	var slide_speed: float = player.flat_speed()
	T.check(player.sliding and slide_speed > sprint_speed, "slide did not start")
	await T.frames(g, 40)
	T.check(player.eye < Player.EYE_HEIGHT, "camera did not drop while sliding")
	T.press(KEY_C, false)
	T.press(KEY_SHIFT, false)
	T.press(KEY_W, false)
	await T.frames(g, 2)
	T.check(not player.sliding, "slide did not end on release")
	print("sprint %.1f m/s, slide %.1f m/s, eye %.2f m" % [sprint_speed, slide_speed, player.eye])


## Sounds: every gun has real shots loaded, plus reloads, steps and hit markers.
static func _sounds(g: Node3D) -> void:
	var sfx: Node = g.sfx
	for sound in ["shot_rifle", "shot_pistol", "shot_sniper", "shot_shotgun", "mag_out", "mag_in", "pump", "shell_in", "step", "hit_body", "hit_head", "kill", "casing", "click"]:
		T.check(sfx.has(sound), "sound missing: " + sound)
	var takes := 0
	for shot in ["shot_rifle", "shot_pistol", "shot_sniper", "shot_shotgun"]:
		takes += sfx.clips[shot].size()
	print("sounds: %d shot takes loaded" % takes)
