extends SubViewportContainer
## The 3D stage behind the lobby UI, in its own little world (SubViewport): the red and white
## studio set (studio.gd), a glowing dragon flying behind it (dragon.gd), and one character
## per class standing on the turntable. Only the picked class is shown, holding the picked
## gun. While you pick weapons the gun itself floats there instead (showcase.gd). The lobby
## passes mouse drags here to spin whichever is shown.

const Widgets := preload("res://scripts/ui/lobby/widgets.gd")
const HandGun := preload("res://scripts/weapons/hand_gun.gd")
const Showcase := preload("res://scripts/ui/lobby/showcase.gd")
const Studio := preload("res://scripts/ui/lobby/studio.gd")
const Dragon := preload("res://scripts/ui/lobby/dragon.gd")
const EmoteAnims := preload("res://scripts/enemies/emote_anims.gd")
const ACCENT := Widgets.ACCENT

var viewport: SubViewport
var turntable: Node3D
var camera: Camera3D
var characters := {}  # class -> {root, guns: {gun id -> Node3D}, emotes: EmoteAnims}
var showcase: Showcase
var dragging := false
var spin_speed := 0.0
var mode := "character"  # or "gun": the picked gun floats on the stage on its own
var pick := ["", ""]  # class, gun


## Build the whole stage. `data` is the lobby data from main.gd (classes, guns, loaders).
func build(data: Dictionary) -> void:
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	turntable = Studio.new().build(viewport)
	var dragon := Dragon.new()
	viewport.add_child(dragon)
	dragon.build(data["load_glb"])
	_build_characters(data)
	showcase = Showcase.new()
	viewport.add_child(showcase)
	showcase.position = Vector3(0, 1.25, 0.2)
	showcase.build(data["guns"], data["load_glb"])
	camera = Camera3D.new()
	camera.fov = 34
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(1.05, 1.32, 4.6), Vector3(0.75, 1.0, 0), Vector3.UP)


## Let a flick of the mouse coast to a stop. The lobby calls this every frame it is shown.
func coast(dt: float) -> void:
	showcase.coast(dt, dragging)
	for id in characters:
		var emotes: EmoteAnims = characters[id]["emotes"]
		var was_active := emotes.active
		emotes.update(dt)
		if was_active and not emotes.active:
			show_pick(pick[0], pick[1])  # gun back in hand
	if not dragging:
		turntable.rotation.y += spin_speed * dt
		spin_speed = lerpf(spin_speed, 0.0, minf(1.0, dt * 3.0))


## Drag anywhere on the stage (outside the panels) to turn your character, or the gun.
func drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		if mode == "gun":
			showcase.turn(event.relative.x * 0.01)
			showcase.spin_speed = event.relative.x * 0.6
		else:
			turntable.rotation.y += event.relative.x * 0.01
			spin_speed = event.relative.x * 0.6


## Show only the picked class's character, holding only the picked gun.
func show_pick(cls: String, gun: String) -> void:
	pick = [cls, gun]
	for id in characters:
		characters[id]["root"].visible = id == cls and mode == "character"
		var emoting: bool = characters[id]["emotes"].active
		for gun_id in characters[id]["guns"]:
			characters[id]["guns"][gun_id].visible = gun_id == gun and not emoting
	showcase.visible = mode == "gun"
	showcase.show_gun(gun)


## "character" (you on the turntable) or "gun" (the picked gun on its own).
func set_mode(new_mode: String) -> void:
	mode = new_mode
	show_pick(pick[0], pick[1])


## Your character plays an emote (gun put away until it ends). An empty emote stops it.
func play_emote(emote: Dictionary) -> void:
	var emotes: EmoteAnims = characters[pick[0]]["emotes"]
	if emote.is_empty():
		emotes.stop()
	else:
		emotes.play(emote)
	show_pick(pick[0], pick[1])


## Your character stands on the turntable, left of centre so the panels have room. Every
## class's character is loaded once, each holding all of its class's guns (shown one at a time).
func _build_characters(data: Dictionary) -> void:
	for cls in data["classes"]:
		var person: Node3D = data["load_character"].call(cls["id"])
		turntable.add_child(person)
		person.position = Vector3(0, 0.14, 0)
		var guns := {}
		var skeleton: Skeleton3D = person.find_children("*", "Skeleton3D", true, false)[0]
		for gun in data["guns"]:
			if gun["class"] == cls["id"]:
				var model: Node3D = data["load_glb"].call(gun["file"])
				var grip := Vector3.ZERO
				for node in model.find_children("*", "", true, false):
					if node.name == "socket_grip":
						grip = (node as Node3D).position
					elif node.name == "scope":
						(node as Node3D).hide()
				HandGun.attach(skeleton, model, grip, 0.11)
				guns[gun["id"]] = model
		var anim: AnimationPlayer = person.find_children("*", "AnimationPlayer", true, false)[0]
		characters[cls["id"]] = {"root": person, "guns": guns, "emotes": EmoteAnims.new(anim, anim.autoplay)}
	turntable.rotation.y = deg_to_rad(-18)
