extends Node
## You: where you stand, how you move (walk, sprint, crouch, slide, jump), where you look,
## walking into boxes, up stairs and onto low ledges, and your footsteps.

const MapLoader := preload("res://scripts/world/map_loader.gd")
const Classes := preload("res://scripts/data/classes.gd")

const EYE_HEIGHT := 1.6
const MOVE_SPEED := 5.0
const SPRINT_SPEED := 8.5  # Shift, forward only, cancelled by firing
const CROUCH_SPEED := 3.0
const SLIDE_SPEED := 11.0  # C while running: burst that bleeds off
const SLIDE_FRICTION := 6.0  # m/s lost per second while sliding
const SLIDE_MIN_SPEED := 4.5  # need at least this much speed to start a slide
const SLIDE_COOLDOWN := 0.5
const CROUCH_EYE := 0.95
const GROUND_ACCEL := 60.0
const AIR_ACCEL := 15.0
const JUMP_VEL := 5.5
const GRAVITY := 16.0
const ADS_MOVE := 0.6  # move speed multiplier when aiming
const PLAYER_RADIUS := 0.3
const STEP_UP := 0.35  # land on a box if your feet are this close to its top (a small mantle)
# Staircases (touching boxes with "step" in the name) are walked as smooth ramps.
const RAMP_SNAP_UP := 0.3  # stick to a ramp from this far above its surface (walking down)
const RAMP_SNAP_DOWN := 0.8  # ...and from this far below it (walking up)
const CAM_SETTLE := 14.0  # how fast the view catches up after a small step up

var game: Node3D
var pos := Vector3.ZERO  # feet
var vel := Vector3.ZERO
var grounded := true
var eye := EYE_HEIGHT
var sliding := false
var slide_cooldown := 0.0
var crouch_was_held := false
var move_label := ""  # SPRINT / SLIDE / CROUCH / CLIMB, shown at the bottom
var yaw := 0.0
var pitch := 0.0
var cam_step := 0.0  # camera lag after stepping up, eases back to 0
var on_ramp := -1
var step_left := 0.0  # metres until the next footstep
var was_grounded := true
var fall_speed := 0.0


## Back to the spawn point, standing still, looking straight ahead.
func reset(spawn: Vector3) -> void:
	yaw = 0.0
	pitch = 0.0
	pos = spawn
	vel = Vector3.ZERO
	grounded = true
	cam_step = 0.0
	eye = EYE_HEIGHT
	sliding = false
	slide_cooldown = 0.0
	crouch_was_held = false
	move_label = ""
	game.cam.rotation = Vector3.ZERO
	game.cam.position = spawn + Vector3(0, EYE_HEIGHT, 0)


func look() -> void:
	game.cam.rotation = Vector3(pitch, yaw, 0.0)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func flat_speed() -> float:
	return Vector2(vel.x, vel.z).length()


## WASD (ZQSD on AZERTY, same keys physically) relative to where you look.
## Space jump, Shift sprint, C crouch, or slide when pressed at speed.
func move(dt: float, firing: bool, ads: float) -> void:
	if game.mantle.climbing():
		game.mantle.climb(dt)
		return
	var input := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var crouch_held := Input.is_physical_key_pressed(KEY_C)
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and input.z < 0.0 and not firing and not crouch_held and ads < 0.5
	var class_speed: float = Classes.PLAYER_CLASSES[game.my_class]["speed"]
	var speed_mult := class_speed * lerpf(1.0, ADS_MOVE, ads)
	var on_ground := grounded
	var flat := Vector3(vel.x, 0.0, vel.z)
	slide_cooldown -= dt

	if crouch_held and not crouch_was_held and on_ground and flat.length() >= SLIDE_MIN_SPEED and slide_cooldown <= 0.0:
		sliding = true
		slide_cooldown = SLIDE_COOLDOWN
		flat = flat.normalized() * maxf(flat.length(), SLIDE_SPEED * class_speed)
	crouch_was_held = crouch_held

	if sliding:
		# Momentum only, no steering; ends on release, when slow, or on leaving the ground.
		flat = flat.move_toward(Vector3.ZERO, SLIDE_FRICTION * dt)
		if not crouch_held or not on_ground or flat.length() <= CROUCH_SPEED:
			sliding = false
	if not sliding:
		var speed := (CROUCH_SPEED if crouch_held else (SPRINT_SPEED if sprinting else MOVE_SPEED)) * speed_mult
		var wish := input.rotated(Vector3.UP, yaw).limit_length(1.0) * speed
		flat = flat.move_toward(wish, (GROUND_ACCEL if on_ground else AIR_ACCEL) * dt)
	vel.x = flat.x
	vel.z = flat.z

	if Input.is_physical_key_pressed(KEY_SPACE) and input.z < 0.0 and game.mantle.try_start():
		return
	if on_ground and Input.is_physical_key_pressed(KEY_SPACE):
		vel.y = JUMP_VEL
		sliding = false  # slide-jump keeps the momentum
	vel.y -= GRAVITY * dt

	eye = move_toward(eye, CROUCH_EYE if sliding or crouch_held else EYE_HEIGHT, 6.0 * dt)
	if sliding:
		move_label = "SLIDE"
	elif crouch_held:
		move_label = "CROUCH"
	elif sprinting:
		move_label = "SPRINT"
	else:
		move_label = ""
	pos += vel * dt
	grounded = false
	if pos.y <= 0.0:
		pos.y = 0.0
		vel.y = 0.0
		grounded = true
	if game.world.cover_on():
		_collide_with_cover()
	# Invisible walls stop you instead of letting speed build up against them.
	var area: Rect2 = game.world.play_area
	if pos.x < area.position.x or pos.x > area.end.x:
		pos.x = clampf(pos.x, area.position.x, area.end.x)
		vel.x = 0.0
	if pos.z < area.position.y or pos.z > area.end.y:
		pos.z = clampf(pos.z, area.position.y, area.end.y)
		vel.z = 0.0
	cam_step = lerpf(cam_step, 0.0, minf(1.0, dt * CAM_SETTLE))
	game.cam.position = pos + Vector3(0, eye + cam_step, 0)
	_footsteps(dt, crouch_held, sprinting)


## Stand on a staircase ramp if you are on one, then push the player out of any box
## they walked into, or stand them on top if their feet are near its top edge.
func _collide_with_cover() -> void:
	var boxes: Array[AABB] = game.world.cover_boxes
	var ramps: Array[Dictionary] = game.world.cover_ramps
	var height := eye + 0.2
	var feet_before := pos.y
	on_ramp = -1
	for i in ramps.size():
		# Grown by your radius so you are on the ramp before your feet touch the first step.
		var area: AABB = ramps[i]["box"].grow(PLAYER_RADIUS)
		if pos.x < area.position.x or pos.x > area.end.x or pos.z < area.position.z or pos.z > area.end.z:
			continue
		var surface := MapLoader.ramp_height(ramps[i], pos)
		# Where the stairs meet a floor or deck, stand on whichever is higher under your feet,
		# so the two do not take turns moving you.
		var steps: Array = ramps[i]["steps"]
		for box_id in boxes.size():
			var box := boxes[box_id]
			if box_id in steps or box.end.y <= surface or box.end.y > pos.y + STEP_UP:
				continue
			if pos.x + PLAYER_RADIUS > box.position.x and pos.x - PLAYER_RADIUS < box.end.x \
					and pos.z + PLAYER_RADIUS > box.position.z and pos.z - PLAYER_RADIUS < box.end.z:
				surface = box.end.y
		if vel.y <= 1.0 and pos.y <= surface + RAMP_SNAP_UP and pos.y >= surface - RAMP_SNAP_DOWN:
			if absf(surface - pos.y) > 0.05:
				cam_step -= surface - pos.y  # smooth out the odd bump getting on
			pos.y = surface
			vel.y = 0.0
			grounded = true
			on_ramp = i
			break
	var skip: Array = ramps[on_ramp]["steps"] if on_ramp >= 0 else []
	for box_id in boxes.size():
		if box_id in skip:
			continue
		var box := boxes[box_id]
		var low := pos - Vector3(PLAYER_RADIUS, 0.0, PLAYER_RADIUS)
		var high := pos + Vector3(PLAYER_RADIUS, height, PLAYER_RADIUS)
		if high.x <= box.position.x or low.x >= box.end.x \
				or high.z <= box.position.z or low.z >= box.end.z \
				or high.y <= box.position.y or low.y >= box.end.y:
			continue
		var center := box.get_center()
		var push_x := box.end.x - low.x if pos.x > center.x else box.position.x - high.x
		var push_z := box.end.z - low.z if pos.z > center.z else box.position.z - high.z
		var push_up := box.end.y - low.y
		if push_up <= STEP_UP and vel.y <= 0.0:
			pos.y = box.end.y
			vel.y = 0.0
			grounded = true
			cam_step -= pos.y - feet_before  # the view eases up instead of popping
		elif absf(push_x) < absf(push_z):
			pos.x += push_x
			vel.x = 0.0
		else:
			pos.z += push_z
			vel.z = 0.0


func _footsteps(dt: float, crouching: bool, sprinting: bool) -> void:
	var speed := flat_speed()
	if grounded and not was_grounded and fall_speed < -4.0:
		game.sfx.play("land", -4.0)
	if not grounded:
		fall_speed = vel.y
	was_grounded = grounded
	if not grounded or sliding or speed < 1.0:
		return
	step_left -= speed * dt
	if step_left <= 0.0:
		step_left = 2.4 if sprinting else (1.4 if crouching else 1.9)
		game.sfx.play("step", (-20.0 if crouching else -13.0) + speed * 0.6, 1.0, 0.08)
