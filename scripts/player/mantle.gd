extends Node
## Climbing: hold jump while moving into a ledge between knee and just above head height,
## and you pull yourself up and roll over onto it, hands on the edge.

const MANTLE_MIN := 0.45  # lower than this you just step or jump
const MANTLE_MAX := 2.1  # highest ledge you can pull yourself onto
const MANTLE_REACH := 0.75  # how far in front of you a ledge counts
const MANTLE_TIME := 0.45  # seconds for a head-high climb (lower ones are quicker)

var game: Node3D
var t := -1.0  # 0..1 while climbing, -1 otherwise
var from := Vector3.ZERO
var to := Vector3.ZERO
var time := MANTLE_TIME
var hands := Vector3.ZERO  # ledge edge point where the hands go


func climbing() -> bool:
	return t >= 0.0


func stop() -> void:
	t = -1.0


## Looks for a ledge just in front of you, between knee and just above head height, with
## room to stand on top. Starts the climb and returns true when there is one.
func try_start() -> bool:
	if not game.world.cover_on():
		return false
	var player: Node = game.player
	var boxes: Array[AABB] = game.world.cover_boxes
	var feet: Vector3 = player.pos
	var forward: Vector3 = player.forward()
	var probe := feet + forward * MANTLE_REACH
	var best := -1
	for i in boxes.size():
		var box := boxes[i]
		var rise := box.end.y - feet.y
		if rise < MANTLE_MIN or rise > MANTLE_MAX:
			continue
		if probe.x < box.position.x - 0.05 or probe.x > box.end.x + 0.05 or probe.z < box.position.z - 0.05 or probe.z > box.end.z + 0.05:
			continue
		if best < 0 or box.end.y < boxes[best].end.y:
			best = i  # the lowest ledge you are facing
	if best < 0:
		return false
	var ledge := boxes[best]
	var radius: float = player.PLAYER_RADIUS
	var margin := minf(radius + 0.05, minf(ledge.size.x, ledge.size.z) * 0.5)
	var top := feet + forward * (MANTLE_REACH + 0.35)
	top.x = clampf(top.x, ledge.position.x + margin, ledge.end.x - margin)
	top.z = clampf(top.z, ledge.position.z + margin, ledge.end.z - margin)
	top.y = ledge.end.y
	# Room to stand on top. Other steps of the same staircase do not count: you walk those.
	var same_stairs: Array = []
	for ramp in game.world.cover_ramps:
		if best in ramp["steps"]:
			same_stairs = ramp["steps"]
	var room := AABB(top - Vector3(radius, -0.02, radius), Vector3(radius * 2.0, player.EYE_HEIGHT + 0.15, radius * 2.0)).grow(-0.01)
	for i in boxes.size():
		if not i in same_stairs and boxes[i].intersects(room):
			return false
	var edge := feet + forward * MANTLE_REACH
	edge.x = clampf(edge.x, ledge.position.x, ledge.end.x)
	edge.z = clampf(edge.z, ledge.position.z, ledge.end.z)
	from = feet
	to = top
	hands = Vector3(edge.x, ledge.end.y, edge.z)
	time = MANTLE_TIME * lerpf(0.6, 1.0, (ledge.end.y - feet.y) / MANTLE_MAX)
	t = 0.0
	player.vel = Vector3.ZERO
	player.sliding = false
	game.sfx.play("land", -8.0, 1.2)  # hands slap the ledge
	return true


## Pull up (first 65%: mostly up), then roll over the top onto it.
func climb(dt: float) -> void:
	var player: Node = game.player
	t = minf(1.0, t + dt / time)
	var up := smoothstep(0.0, 0.65, t)
	var over := smoothstep(0.45, 1.0, t)
	var lift := to.y + 0.05 - from.y
	player.pos = Vector3(lerpf(from.x, to.x, over), from.y + lift * up, lerpf(from.z, to.z, over))
	if t >= 1.0:
		player.pos = to
		t = -1.0
		player.vel = player.forward() * 2.0  # come out of it moving
		player.grounded = true
	player.move_label = "CLIMB" if t >= 0.0 else ""
	var dip := sin(PI * clampf(t, 0.0, 1.0))
	var eye: float = player.eye
	game.cam.position = player.pos + Vector3(0, eye - dip * 0.12, 0)
	game.cam.rotation = Vector3(player.pitch - dip * 0.08, player.yaw, dip * 0.05)
