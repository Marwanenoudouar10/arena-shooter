extends Node
## The enemy you track: one at a time, of one class (or a random one each spawn). It
## strafes, jumps and dashes inside its zone (or fights from cover, see enemy_ai.gd), faces
## you, plays the right animation, flashes when hit and falls over when killed. Its
## hitboxes follow the bones: a sphere for the head, a capsule for the body.

const E := preload("res://scripts/core/enums.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Maps := preload("res://scripts/data/maps.gd")
const Guns := preload("res://scripts/data/guns.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")
const Body := preload("res://scripts/enemies/enemy_body.gd")
const AI := preload("res://scripts/enemies/enemy_ai.gd")
const AimMath := preload("res://scripts/weapons/aim_math.gd")

# The models face +Z and stand 1.86 m tall. Sizes are metres at model scale.
const MODEL_HEIGHT := 1.86
const HEAD_RADIUS := 0.13
const HEAD_UP := 0.12  # head centre above the head bone
const BODY_RADIUS := 0.21
const DEATH_TIME := 1.0  # seconds the body stays down before the next target appears
const X_LIMIT := 8.0  # half-width of the lane on maps without zones

var game: Node3D
var ai: AI
var target: Node3D  # origin at the feet
var hp_label: Label3D
var kind := "Medium"  # class of the enemy in play
var models := {}  # class -> {pivot, skeleton, anim, head, neck, wrist, meshes, gun}
var model := {}
var hp := 0.0
var dead_left := 0.0  # > 0 while the death animation plays
var vel := Vector3.ZERO
var goal_vel := Vector3.ZERO
var change_in := 0.0
var jump_vel := 0.0
var dash_cooldown := 0.0
var spawn_time := 0.0
var zone := AABB()  # where the enemy walks; its bottom is the ground
var flash := 0.0  # flashes white while > 0
var flashing := false
var flash_mat: StandardMaterial3D


func build() -> void:
	ai = AI.new(self)
	target = Node3D.new()
	game.add_child(target)
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0.55)
	for cls_name in Classes.CLASS_NAMES:
		models[cls_name] = Body.load_model(Kit.look_for(cls_name), target)  # enemies wear the class look
		models[cls_name]["gun"] = Body.load_gun(Guns.GUNS[Classes.ENEMY_GUNS[cls_name]]["file"], target)
	hp_label = Label3D.new()
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.no_depth_test = false  # walls hide it, no seeing through cover
	hp_label.font_size = 96
	hp_label.outline_size = 18
	target.add_child(hp_label)


func cls() -> Dictionary:
	return Classes.CLASSES[kind]


func model_scale() -> float:
	return cls()["height"] / MODEL_HEIGHT


func apply_class() -> void:
	for cls_name in models:
		models[cls_name]["pivot"].hide()
		models[cls_name]["gun"]["node"].hide()
	model = models[kind]
	var s := model_scale()
	model["pivot"].scale = Vector3(s * cls()["width"], s, s * cls()["width"])
	model["pivot"].show()
	hp_label.position = Vector3(0, cls()["height"] + 0.45, 0)


# --- Hitboxes --------------------------------------------------------------------------

func bone_pos(bone: int) -> Vector3:
	var skeleton: Skeleton3D = model["skeleton"]
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin


func head_radius() -> float:
	return HEAD_RADIUS * model_scale()


func body_radius() -> float:
	return BODY_RADIUS * model_scale() * cls()["width"]


func head_center() -> Vector3:
	return bone_pos(model["head"]) + Vector3.UP * HEAD_UP * model_scale()


## Body hitbox: capsule from just above the feet up to the neck.
func body_ends() -> Array[Vector3]:
	return [target.position + Vector3.UP * body_radius(), bone_pos(model["neck"])]


func body_center() -> Vector3:
	var ends := body_ends()
	return (ends[0] + ends[1]) / 2.0


## What a shot from the camera along `dir` (default: straight ahead) hits. Head is checked
## first, so a shot that clips both counts as a headshot. Walls in the way stop it.
func aim_hit(dir := Vector3.ZERO) -> E.Hit:
	if dead_left > 0.0:
		return E.Hit.MISS
	var origin: Vector3 = game.cam.global_position
	if dir == Vector3.ZERO:
		dir = -game.cam.global_basis.z
	var hit := E.Hit.MISS
	var ends := body_ends()
	if AimMath.ray_hits_sphere(origin, dir, head_center(), head_radius()):
		hit = E.Hit.HEAD
	elif AimMath.ray_hits_capsule(origin, dir, ends[0], ends[1], body_radius()):
		hit = E.Hit.BODY
	if hit != E.Hit.MISS and game.world.blocks(origin, dir, body_center()):
		return E.Hit.MISS
	return hit


## Takes the damage. Returns true when that killed it.
func hurt(damage: float) -> bool:
	hp -= damage
	flash = 0.06
	if hp > 0.0:
		hp_label.text = str(ceili(hp))
		return false
	dead_left = DEATH_TIME
	vel = Vector3.ZERO
	goal_vel = Vector3.ZERO
	hp_label.hide()
	return true


# --- Spawning and moving ---------------------------------------------------------------

## Map zones, or a lane in front of you on maps without zones.
func zones() -> Array[AABB]:
	var out: Array[AABB] = []
	out.assign(game.world.maps.get(game.map_name, {}).get("zones", []))
	if out.is_empty():
		var lane: Vector2 = Maps.LANES.get(game.map_name, Maps.LANES["Open"])
		out.append(AABB(Vector3(-X_LIMIT, 0.0, lane.x), Vector3(X_LIMIT * 2.0, 0.1, lane.y - lane.x)))
	return out


func spawn() -> void:
	if game.enemies == "Mixed":
		kind = Classes.CLASS_NAMES.pick_random()
		apply_class()
	zone = zones().pick_random()
	var margin := minf(1.0, minf(zone.size.x, zone.size.z) * 0.25)
	target.position = Vector3(
			randf_range(zone.position.x + margin, zone.end.x - margin),
			zone.position.y,
			randf_range(zone.position.z + margin, zone.end.z - margin))
	vel = Vector3.ZERO
	goal_vel = Vector3.ZERO
	jump_vel = 0.0
	change_in = 0.0
	hp = cls()["hp"]
	hp_label.text = str(int(hp))
	hp_label.show()
	dead_left = 0.0
	spawn_time = game.session.round_clock
	dash_cooldown = AI.DASH_COOLDOWN
	ai.plan = AI.Plan.STRAFE
	if game.map_name == "Cover":  # hide/peek assumes walls facing you, as on that map
		ai.plan_hide()
	target.show()


func update(dt: float) -> void:
	if dead_left > 0.0:
		dead_left -= dt
		if dead_left <= 0.0:
			spawn()
		_animate(dt)
		return
	# Strafe pattern: new direction and speed every few tenths of a second, sometimes a jump.
	var c := cls()
	if ai.plan != AI.Plan.STRAFE:
		ai.update(dt)
	else:
		change_in -= dt
		if change_in <= 0.0:
			change_in = randf_range(c["turn"].x, c["turn"].y)
			# Strafe sideways as seen from you, drifting a little closer or further.
			var to_you: Vector3 = game.cam.global_position - target.position
			var toward := Vector3(to_you.x, 0.0, to_you.z).normalized()
			var side := Vector3(toward.z, 0.0, -toward.x)
			var dir := -1.0 if randf() < 0.5 else 1.0
			goal_vel = side * dir * randf_range(c["speed"].x, c["speed"].y) + toward * randf_range(-1.5, 1.5)
			if randf() < c["jump"] and target.position.y <= zone.position.y + 0.001:
				jump_vel = 5.5
	dash_cooldown -= dt
	if dash_cooldown <= 0.0 and randf() < c["dash"] * dt:
		ai.dash()
	vel = vel.move_toward(goal_vel, 35.0 * dt)

	var p := target.position + vel * dt
	if p.x < zone.position.x or p.x > zone.end.x:
		p.x = clampf(p.x, zone.position.x, zone.end.x)
		goal_vel.x = -goal_vel.x
		vel.x = 0.0
	if p.z < zone.position.z or p.z > zone.end.z:
		p.z = clampf(p.z, zone.position.z, zone.end.z)
		goal_vel.z = -goal_vel.z
		vel.z = 0.0
	var ground := zone.position.y
	jump_vel -= 16.0 * dt
	p.y += jump_vel * dt
	if p.y <= ground:
		p.y = ground
		jump_vel = 0.0
	target.position = p
	_animate(dt)

	flash -= dt
	if (flash > 0.0) != flashing:
		flashing = flash > 0.0
		for mesh in model["meshes"]:
			mesh.material_overlay = flash_mat if flashing else null


## Test helper: park the enemy and stop it from changing direction, dashing or jumping.
func hold_still(pos: Vector3) -> void:
	target.position = pos
	vel = Vector3.ZERO
	goal_vel = Vector3.ZERO
	jump_vel = 0.0
	change_in = 10.0
	dash_cooldown = 10.0


## Pick the clip from speed, face you, lean toward where it runs.
func _animate(dt: float) -> void:
	var speed := Vector2(vel.x, vel.z).length()
	var in_air := target.position.y > zone.position.y + 0.05
	var to_you: Vector3 = game.cam.global_position - target.position
	var yaw_to_you := atan2(to_you.x, to_you.z)
	# Always face you; run sideways, backwards or forwards by how the target moves relative to that.
	var facing := Vector3(sin(yaw_to_you), 0.0, cos(yaw_to_you))
	var side := Vector3(facing.z, 0.0, -facing.x)  # the target's left
	var forward_speed := Vector3(vel.x, 0.0, vel.z).dot(facing)
	var side_speed := Vector3(vel.x, 0.0, vel.z).dot(side)
	if dead_left > 0.0:
		Body.play(model, "Death")
	elif in_air:
		Body.play(model, "Jump_Idle")
	elif speed < 0.6:
		Body.play(model, "Idle_Shoot")
	elif absf(side_speed) > absf(forward_speed):
		Body.play(model, "Run_Left" if side_speed > 0.0 else "Run_Right")
	elif forward_speed > 0.0:
		Body.play(model, "Run_Shoot" if speed > 3.5 else "Walk")
	else:
		Body.play(model, "Run_Back")
	var pivot: Node3D = model["pivot"]
	pivot.rotation.y = lerp_angle(pivot.rotation.y, yaw_to_you, minf(1.0, dt * 10.0))
	Body.hold_gun(model, dead_left <= 0.0 and target.visible, game.cam.global_position, model_scale())
