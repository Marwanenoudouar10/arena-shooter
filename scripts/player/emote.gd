extends Node
## Emotes in a match: hold B for the emote wheel, move the mouse toward one, let go to play
## it. The camera swings out in front of you so you can watch your character (move the mouse
## to circle around). Moving, jumping, firing or aiming ends it; one-shots end by themselves.

const E := preload("res://scripts/core/enums.gd")
const Emotes := preload("res://scripts/data/emotes.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")
const Glb := preload("res://scripts/core/glb.gd")
const EmoteAnims := preload("res://scripts/enemies/emote_anims.gd")
const Wheel := preload("res://scripts/ui/emote_wheel.gd")

const CAM_DISTANCE := 3.0
const CAM_HEIGHT := 1.5
const CANCEL_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_C]

var game: Node3D
var body: Node3D  # your character in third person
var player: EmoteAnims
var wheel: Wheel
var orbit := 0.0  # camera angle around you, radians
var showing := false


func build(ui: CanvasLayer, pictures: Array, font: Font) -> void:
	body = Kit.build(game.my_look(game.my_class), Glb.scene)
	game.add_child(body)
	body.hide()
	var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	EmoteAnims.add_to(anim, Glb.scene)
	player = EmoteAnims.new(anim, "CharacterArmature|Idle")
	wheel = Wheel.new()
	ui.add_child(wheel)
	var emote_names: Array[String] = []
	for emote in Emotes.LIST:
		emote_names.append(emote["name"])
	wheel.build(pictures, emote_names, font)


func active() -> bool:
	return showing


## B opens / closes the wheel, the mouse steers it or circles the camera. True when used.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.physical_keycode == KEY_B and not event.echo:
		if event.pressed and game.state in [E.State.COUNTDOWN, E.State.PLAYING]:
			wheel.open()
			return true
		if not event.pressed and wheel.visible:
			var slot := wheel.close()
			if slot >= 0:
				start(Emotes.LIST[slot])
			return true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if wheel.visible:
			wheel.steer(event.screen_relative)
			return true
		if showing:
			orbit -= event.screen_relative.x * 0.005
			return true
	return false


func start(emote: Dictionary) -> void:
	Kit.dress(body, game.my_look(game.my_class), Glb.scene)
	body.position = game.player.pos
	body.rotation.y = game.player.yaw + PI  # the model faces +Z, you look along -Z
	body.show()
	game.viewmodel.hide()
	game.crosshair.hide()
	orbit = 0.0
	showing = true
	player.play(emote)


func update(dt: float) -> void:
	player.update(dt)
	var cancel := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	for key in CANCEL_KEYS:
		cancel = cancel or Input.is_physical_key_pressed(key)
	if cancel or not player.active:
		finish()
		return
	var forward := Vector3(-sin(game.player.yaw), 0.0, -cos(game.player.yaw)).rotated(Vector3.UP, orbit)
	var cam: Camera3D = game.cam
	cam.position = body.position + forward * CAM_DISTANCE + Vector3.UP * CAM_HEIGHT
	cam.look_at(body.position + Vector3.UP * 1.1)


## Back to first person, where you were looking.
func finish() -> void:
	if not showing:
		return
	reset()
	game.viewmodel.show()
	game.crosshair.show()
	game.player.look()
	game.cam.position = game.player.pos + Vector3(0, game.player.eye, 0)


## Stop everything without touching the view (new round, menu).
func reset() -> void:
	player.stop()
	body.hide()
	wheel.hide()
	showing = false
