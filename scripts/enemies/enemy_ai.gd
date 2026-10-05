extends RefCounted
## How an enemy fights from cover: on the Cover map it hides in the shadow of a tall wall
## (worked out from where you stand), then steps out past one edge to peek, then hides
## again. Also the quick sidestep dash every class but Heavy uses.

enum Plan { STRAFE, HIDE, PEEK }

const DASH_SPEED := 14.0
const DASH_COOLDOWN := 1.2

var enemy: Node
var plan := Plan.STRAFE
var goal_x := 0.0
var wait := 0.0  # seconds to stay once the goal is reached
var hide_x := 0.0
var hide_half := 0.0  # half-width of the wall's shadow at the target's depth


func _init(owner_enemy: Node) -> void:
	enemy = owner_enemy


func update(dt: float) -> void:
	var dx: float = goal_x - enemy.target.position.x
	var arrived := absf(dx) < 0.2
	if arrived:
		wait -= dt
		if wait <= 0.0:
			if plan == Plan.HIDE:
				plan_peek()
			else:
				plan_hide()
			dx = goal_x - enemy.target.position.x
	var top_speed: float = enemy.cls()["speed"].y
	var speed := minf(top_speed, absf(dx) * 6.0)
	enemy.goal_vel = Vector3(signf(dx) * speed, 0.0, 0.0)
	if arrived and plan == Plan.PEEK:
		var clock: float = enemy.game.session.round_clock
		enemy.goal_vel.x = sin(clock * 9.0) * 2.0  # small left-right wiggle while exposed


## Pick a tall wall between you and the target and go stand in its shadow,
## worked out from where you are right now. No usable wall: plain strafing.
func plan_hide() -> void:
	var view: Vector3 = enemy.game.cam.global_position
	var target_z: float = enemy.target.position.z
	var radius: float = enemy.body_radius()
	var height: float = enemy.cls()["height"]
	var zone: AABB = enemy.zone
	var spots: Array[Vector2] = []  # x = hide x, y = shadow half-width
	for box in enemy.game.world.cover_boxes:
		var c: Vector3 = box.get_center()
		if box.end.y < height or c.z <= target_z or c.z >= view.z:
			continue
		var widen := (target_z - view.z) / (c.z - view.z)  # the shadow grows behind the wall
		var x := view.x + (c.x - view.x) * widen
		var half: float = box.size.x * 0.5 * widen
		if half > radius + 0.2 and x >= zone.position.x and x <= zone.end.x:
			spots.append(Vector2(x, half))
	if spots.is_empty():
		plan = Plan.STRAFE
		return
	var spot: Vector2 = spots.pick_random()
	plan = Plan.HIDE
	hide_x = spot.x
	hide_half = spot.y
	goal_x = spot.x
	wait = randf_range(0.4, 1.4)


## Step just past one edge of the current wall's shadow.
func plan_peek() -> void:
	var zone: AABB = enemy.zone
	var body_radius: float = enemy.body_radius()
	var out: float = hide_half + body_radius + 0.4
	var side := -1.0 if randf() < 0.5 else 1.0
	var peek_x := hide_x + side * out
	if peek_x < zone.position.x or peek_x > zone.end.x:
		side = -side
	plan = Plan.PEEK
	goal_x = clampf(hide_x + side * out, zone.position.x, zone.end.x)
	wait = randf_range(0.6, 1.4)


## Instant sidestep that bleeds off over ~0.3 s. Toward the goal when peeking, random otherwise.
func dash() -> void:
	var dir := -1.0 if randf() < 0.5 else 1.0
	var x: float = enemy.target.position.x
	if plan != Plan.STRAFE:
		dir = signf(goal_x - x) if absf(goal_x - x) > 0.5 else dir
	enemy.vel.x = dir * DASH_SPEED
	enemy.dash_cooldown = DASH_COOLDOWN
