extends Node3D
## First-person view: the gun in your hands, your arms, the optic on top, and the
## animations (recoil kick, sway, walk bob, sprint, slide, raise, reload with the
## magazine coming out, shell casings, muzzle flash). Lives under the camera; main.gd
## feeds it the game state every frame and calls fired() on each shot.
##
## This file keeps the state, places the gun each frame and answers main. The rest lives
## in helpers next to it: gun_loader.gd (gun rigs and optics), gun_animation.gd (reload
## and moving parts), effects.gd (flash, casings, magazines) and arms.gd (your arms).

const GunLoader := preload("res://scripts/weapons/viewmodel/gun_loader.gd")
const Anim := preload("res://scripts/weapons/viewmodel/gun_animation.gd")
const Effects := preload("res://scripts/weapons/viewmodel/effects.gd")
const Arms := preload("res://scripts/weapons/viewmodel/arms.gd")

const GUN_SCALE := 0.11  # model units -> metres
const HOLDS := {  # hip position relative to the camera
	"rifle": Vector3(0.2, -0.2, -0.32),
	"pistol": Vector3(0.13, -0.17, -0.36),
}
const PISTOL_ADS_DEPTH := -0.4  # pistols are aimed at arm's length, not against the cheek
const SCOPE_EYE_RELIEF := 0.06  # eye to scope eyepiece when aiming
# Optics are real-size models (assets/optics, made by make_optics.py) shrunk to match these
# guns, which are a bit smaller than life in first person. zoom = view zoom when aiming;
# the scope also magnifies the picture inside its lens (main.gd draws that).
const OPTICS := {
	"Iron": {"name": "Iron sights", "zoom": 0.75},
	"RedDot": {"name": "Red dot", "zoom": 0.72, "file": "res://assets/optics/reddot.glb"},
	"Holo": {"name": "Holo sight", "zoom": 0.72, "file": "res://assets/optics/holo.glb"},
	"Scope": {"name": "Scope 4x", "zoom": 0.8, "mag": 4.0, "file": "res://assets/optics/scope.glb"},
}
const OPTIC_IDS: Array[String] = ["Iron", "RedDot", "Holo", "Scope"]
const OPTIC_SCALE := 0.7
const VIEW_LAYER := 2  # render layer bit for the gun and arms (the scope camera skips it)

var world: Node3D  # where dropped magazines and casings go
var guns := {}  # gun id -> {node, parts, rests, sockets, stock_x}
var gun_id := ""
var hold := "rifle"
var optic := "Iron"
var optic_nodes := {}  # gun id -> {optic id -> {node, sight, lens, eye}}
var slide_back := 0.0  # pistol slide kick after a shot
var reload_style := "mag"
var reload_pose := 0.0  # 0..1 gun tilted up for loading
var cycle_t := -1.0  # pump / bolt action progress, -1 when idle

var kick := 0.0
var sway := Vector2.ZERO
var bob := 0.0
var raise := 0.0  # 1 = gun down out of view (equip), eases to 0
var climb := 0.0  # 0..1: gun drops away and both hands reach for the ledge
var ledge := Vector3.ZERO  # ledge edge point, camera space

var debug_targets := {}  # side -> camera-space palm target (for the side-view debug shot)
var bodies := {}  # class -> {root, skeleton, bone ids}
var body := {}
var dropped: Array[Dictionary] = []  # empty magazines falling away {node, vel, spin, life}

var anim: Anim  # reload and moving parts
var effects: Effects  # muzzle flash, casings, dropped magazines
var arms: Arms  # your arms on the gun


func _init() -> void:
	anim = Anim.new(self)
	effects = Effects.new(self)
	arms = Arms.new(self)


## body_models: class -> that class's character (main builds them from the character kit).
func setup(gun_files: Dictionary, load_glb: Callable, world_node: Node3D, body_models: Dictionary) -> void:
	world = world_node
	var loader := GunLoader.new()
	for id in gun_files:
		guns[id] = loader.load_gun(gun_files[id], load_glb, self)
		optic_nodes[id] = loader.load_optics(guns[id]["sockets"]["mount"], load_glb)
		guns[id]["node"].hide()
	effects.build()
	for cls in body_models:
		bodies[cls] = arms.build_body(body_models[cls])
		_set_layer(bodies[cls]["root"])
	_set_layer(self)
	position = HOLDS["rifle"]


func set_loadout(gun: String, optic_id: String, player_class: String, hold_style := "rifle") -> void:
	gun_id = gun
	hold = hold_style if HOLDS.has(hold_style) else "rifle"
	optic = optic_id if OPTICS.has(optic_id) else "Iron"
	for id in guns:
		guns[id]["node"].visible = id == gun_id
		for sight_id in optic_nodes[id]:
			optic_nodes[id][sight_id]["node"].visible = id == gun_id and sight_id == optic
	for cls in bodies:
		bodies[cls]["root"].visible = cls == player_class and visible
	body = bodies.get(player_class, bodies.values()[0])
	effects.muzzle_flash.reparent(guns[gun_id]["sockets"]["muzzle"], false)
	anim.reset_magazine()


func zoom() -> float:
	return OPTICS[optic]["zoom"]


## How much the picture is magnified for aiming, including the scope's lens.
func magnification() -> float:
	return OPTICS[optic].get("mag", 1.0)


## Where the scope's rear lens is (world centre and radius), for drawing the zoomed picture.
func scope_lens() -> Dictionary:
	if optic != "Scope" or not optic_nodes[gun_id].has("Scope"):
		return {}
	var lens: MeshInstance3D = optic_nodes[gun_id]["Scope"]["lens"]
	if lens == null:
		return {}
	var box := lens.get_aabb()
	var center := lens.global_transform * box.get_center()
	var edge := lens.global_transform * (box.get_center() + Vector3(0, box.size.y * 0.5, 0))
	return {"center": center, "radius": center.distance_to(edge)}


## Gun position that puts the aiming point (front sight or optic) on the screen centre,
## with the stock tucked against your cheek.
func ads_pose() -> Vector3:
	var gun: Dictionary = guns[gun_id]
	var root: Node3D = gun["node"]
	var point: Vector3
	if optic == "Iron":
		point = gun["sockets"]["iron"].position
	else:
		var sight: Node3D = optic_nodes[gun_id][optic]["sight"]
		point = root.to_local(sight.global_position)
	var in_view := root.transform * point
	var depth: float = -(point.x - gun["stock_x"]) * GUN_SCALE - 0.03
	if hold == "pistol":
		depth = PISTOL_ADS_DEPTH
	if optic != "Iron" and optic_nodes[gun_id][optic]["eye"] != null:
		# A scope is looked into: put its eyepiece a few centimetres in front of your eye.
		var eye := root.transform * root.to_local(optic_nodes[gun_id][optic]["eye"].global_position)
		return Vector3(-in_view.x, -in_view.y, -SCOPE_EYE_RELIEF - eye.z)
	return Vector3(-in_view.x, -in_view.y, depth - in_view.z)


func muzzle_position() -> Vector3:
	return guns[gun_id]["sockets"]["muzzle"].global_position


func equip() -> void:
	raise = 1.0
	anim.reset_magazine()


func add_sway(mouse: Vector2) -> void:
	sway = (sway + Vector2(-mouse.x, mouse.y) * 0.15).limit_length(12.0)


func fired() -> void:
	kick = minf(kick + 0.5, 1.6)
	slide_back = 1.0
	effects.fired()


## state: ads (0..1), speed (m/s on the ground), grounded, sprint, slide, reload_t (0..1,
## -1 = not reloading), climb (0..1) and ledge (camera-space point the hands grab)
func update(dt: float, state: Dictionary) -> void:
	var ads: float = state["ads"]
	climb = state.get("climb", 0.0)
	ledge = state.get("ledge", Vector3.ZERO)
	if state["grounded"] and state["speed"] > 0.5:
		bob += dt * state["speed"] * 1.8
	var bob_offset := Vector3(sin(bob) * 0.006, -absf(cos(bob)) * 0.008, 0.0)
	kick = lerpf(kick, 0.0, minf(1.0, dt * 14.0))
	sway = sway.lerp(Vector2.ZERO, minf(1.0, dt * 10.0))
	raise = move_toward(raise, 0.0, dt / 0.4)
	var reload_t: float = state["reload_t"]
	reload_style = state.get("reload_style", "mag")
	cycle_t = state.get("cycle_t", -1.0)
	slide_back = 1.0 if state.get("empty", false) and hold == "pistol" else lerpf(slide_back, 0.0, minf(1.0, dt * 18.0))
	var sprint := 1.0 if state["sprint"] else 0.0
	var calm := 1.0 - ads * 0.8  # aiming steadies bob, sway and kick
	# The gun tilts up toward you to load. A magazine swap runs one tilt over the reload;
	# shell-by-shell loading holds the tilt while rounds go in.
	reload_pose = move_toward(reload_pose, 1.0 if reload_t >= 0.0 else 0.0, dt / 0.2)
	var tilt := Anim.bump(reload_t, 0.0, 0.12, 0.86, 1.0) if reload_style != "shells" and reload_t >= 0.0 else (reload_pose * 0.7 if reload_style == "shells" else 0.0)
	var jolt := Anim.bump(reload_t, 0.8, 0.83, 0.83, 0.86) if reload_style == "mag" and reload_t >= 0.0 else 0.0
	jolt += Anim.bump(cycle_t, 0.1, 0.3, 0.4, 0.7) if cycle_t >= 0.0 else 0.0  # working the action
	var lift := ease(raise, 2.0)
	# During a reload the gun comes up and rolls toward you so the loading is in view.
	position = (HOLDS[hold] as Vector3).lerp(ads_pose(), ads) + (bob_offset + Vector3(sway.x * 0.002, sway.y * 0.002, 0.0)) * calm \
			+ Vector3(-tilt * 0.09, -sprint * 0.04 - lift * 0.3 + tilt * 0.1 - climb * 0.4, kick * 0.04 * calm + jolt * 0.02 + tilt * 0.05)
	rotation_degrees = Vector3(kick * 4.0 * calm - sprint * 12.0 - lift * 30.0 + tilt * 14.0 - climb * 50.0, sprint * 25.0 + tilt * 12.0,
			(-8.0 if state["slide"] else 0.0) * calm - tilt * 30.0)
	anim.animate_reload(reload_t if reload_style == "mag" else -1.0)
	anim.animate_parts(reload_t)
	arms.update()
	effects.update(dt, ads)


func _set_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = VIEW_LAYER
	for child in node.get_children():
		_set_layer(child)


## Arms hang off the camera, not off the gun, so they follow this node's visibility by hand.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not body.is_empty():
		body["root"].visible = visible
