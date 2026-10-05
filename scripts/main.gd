extends Node3D
## Arena shooter and aim trainer: track a moving enemy, flick between targets, or match your
## sensitivity from another game with the 360 test. The whole scene is built in code. This file only
## creates the parts, holds your settings and loadout, and runs each frame and key press.

const E := preload("res://scripts/core/enums.gd")
const Guns := preload("res://scripts/data/guns.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")
const Glb := preload("res://scripts/core/glb.gd")
const Settings := preload("res://scripts/core/settings.gd")
const World := preload("res://scripts/world/world.gd")
const Player := preload("res://scripts/player/player.gd")
const Mantle := preload("res://scripts/player/mantle.gd")
const Emote := preload("res://scripts/player/emote.gd")
const Emotes := preload("res://scripts/data/emotes.gd")
const Enemy := preload("res://scripts/enemies/enemy.gd")
const Gun := preload("res://scripts/weapons/gun.gd")
const Shooting := preload("res://scripts/weapons/shooting.gd")
const ScopeView := preload("res://scripts/weapons/scope_view.gd")
const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")
const Flicks := preload("res://scripts/modes/flicks.gd")
const Session := preload("res://scripts/modes/session.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const LobbyLink := preload("res://scripts/ui/lobby_link.gd")
const Lobby := preload("res://scripts/ui/lobby/lobby.gd")
const Crosshair := preload("res://scripts/ui/crosshair.gd")
const Sounds := preload("res://scripts/fx/sounds.gd")
const Impacts := preload("res://scripts/fx/impacts.gd")
const Dev := preload("res://scripts/dev/dev_runs.gd")
const Keys := preload("res://scripts/core/keys.gd")

const DEG_PER_UNIT := 0.022  # degrees turned per mouse unit at sensitivity 1.0

# Settings and loadout (saved, see core/settings.gd).
var sens := 1.0
var fov := 90.0
var move_enabled := true
var quality := "Medium"
var volume := 0.8
var map_name := "Open"
var gun_name := "Striker"
var optic_name := "RedDot"
var my_class := "Medium"
var enemies := "Mixed"  # enemy class, or Mixed for a random one each time
var outfits := {}  # class -> what you wear on it instead of the class look, e.g. {"Top": "swat"}
var best := {}  # "fight_arena", "flicks_cover", ... -> best score

var state := E.State.MENU
var mode := E.Mode.TRACKING
var test_fire := false  # self-test only: pretend the fire button is held
var dev_run := false  # self-test/screenshot runs never touch saved scores

# The parts. Each owns its own state; they reach each other through this node.
var cam: Camera3D
var world: World
var player: Player
var mantle: Mantle
var emote: Emote
var enemy: Enemy
var gun: Gun
var shooting: Shooting
var scope: ScopeView
var viewmodel: Viewmodel
var flicks: Flicks
var session: Session
var hud: Hud
var pause_menu: PauseMenu
var lobby_link: LobbyLink
var lobby: Lobby
var crosshair: Crosshair
var sfx: Sounds
var impacts: Impacts
var ui: CanvasLayer


func _ready() -> void:
	Input.use_accumulated_input = false
	Settings.load_into(self)
	_build()
	world.apply_quality(quality)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	var args := OS.get_cmdline_user_args()
	dev_run = args.size() > 0
	if dev_run:
		var handled: bool = await Dev.run(self, args)
		if handled:
			return
	session.show_menu()


func _part(script: GDScript) -> Node:
	var node: Node = script.new()
	node.set("game", self)
	add_child(node)
	return node


func _build() -> void:
	world = _part(World)
	world.build()
	impacts = _part(Impacts)
	cam = Camera3D.new()
	cam.position = Vector3(0, Player.EYE_HEIGHT, 0)
	cam.keep_aspect = Camera3D.KEEP_WIDTH  # fov is horizontal
	cam.fov = fov
	add_child(cam)
	player = _part(Player)
	mantle = _part(Mantle)
	session = _part(Session)
	gun = _part(Gun)
	shooting = _part(Shooting)
	enemy = _part(Enemy)
	enemy.build()
	viewmodel = Viewmodel.new()
	cam.add_child(viewmodel)
	var files := {}
	for gun_id in Guns.GUN_NAMES:
		files[gun_id] = Guns.GUNS[gun_id]["file"]
	var bodies := {}
	for cls in Classes.CLASS_NAMES:
		bodies[cls] = Kit.build(my_look(cls), Glb.scene)
	viewmodel.setup(files, Glb.scene, self, bodies)
	viewmodel.hide()
	apply_gun()
	if enemies != "Mixed":
		enemy.kind = enemies
	enemy.apply_class()
	flicks = _part(Flicks)
	flicks.build()
	apply_map()
	sfx = _part(Sounds)

	ui = CanvasLayer.new()
	add_child(ui)
	crosshair = Crosshair.new()
	ui.add_child(crosshair)
	scope = _part(ScopeView)
	scope.build(ui)
	hud = _part(Hud)
	hud.build(ui)
	lobby_link = _part(LobbyLink)
	lobby = lobby_link.build(ui)
	pause_menu = PauseMenu.new()
	ui.add_child(pause_menu)
	pause_menu.build(lobby, session.resume, session.end)
	emote = _part(Emote)
	var make := func() -> Node3D: return lobby_link.preview_character(my_class)
	emote.build(ui, Emotes.LIST.map(func(e: Dictionary) -> Texture2D: return lobby.icons.emote(e, make)), hud.heavy)


## The class look with your own clothes on top.
func my_look(cls: String) -> Dictionary:
	return Kit.look_for(cls, outfits.get(cls, {}))


func apply_map() -> void:
	map_name = world.show_map(map_name)


func apply_gun() -> void:
	var allowed: Array = gun.data()["optics"]
	var sight: String = optic_name if optic_name in allowed else allowed[0]
	viewmodel.set_loadout(gun_name, sight, my_class, gun.data()["hold"])
	gun.ammo = gun.data()["mag"]
	gun.cycle_left = 0.0


func reset_view() -> void:
	player.reset(world.spawn_pos)
	mantle.stop()
	gun.ads = 0.0
	cam.fov = fov


func hide_world_targets() -> void:
	if emote:
		emote.reset()
	enemy.target.hide()
	viewmodel.hide()
	scope.overlay.hide()
	world.marker.hide()
	flicks.hide_all()


func update_viewmodel(dt: float) -> void:
	viewmodel.update(dt, {
		"ads": gun.ads,
		"speed": player.flat_speed(),
		"grounded": player.grounded,
		"sprint": player.move_label == "SPRINT",
		"slide": player.sliding,
		"reload_t": gun.reload_t(),
		"reload_style": gun.data()["reload_style"],
		"cycle_t": gun.cycle_t(),
		"empty": gun.ammo == 0,
		"climb": sin(PI * mantle.t) if mantle.climbing() else 0.0,
		"ledge": cam.to_local(mantle.hands),
	})


func _process(dt: float) -> void:
	var firing := test_fire or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var in_round := state in [E.State.COUNTDOWN, E.State.PLAYING]
	var emoting := in_round and emote.active()
	if emoting:
		emote.update(dt)
	elif move_enabled and in_round:
		player.move(dt, firing, gun.ads)
	if in_round and not emoting:
		var want_ads := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and player.move_label != "SPRINT" and not mantle.climbing()
		gun.update_ads(dt, want_ads)
		cam.fov = lerpf(fov, fov * viewmodel.zoom(), gun.ads)
		crosshair.modulate.a = clampf(1.0 - gun.ads * 2.0, 0.0, 1.0)
		update_viewmodel(dt)
		scope.update(gun.ads)
	var playing := state == E.State.PLAYING  # the countdown ending starts play next frame
	session.update(dt)
	if playing:
		if mode == E.Mode.TRACKING:
			enemy.update(dt)
			if not emoting:
				gun.update(dt, firing and not mantle.climbing())
		if not emoting:
			gun.apply_recoil(dt)
	hud.update()


func _input(event: InputEvent) -> void:
	if emote and emote.handle_input(event):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var zoom_mult := tan(deg_to_rad(fov * viewmodel.zoom()) / 2.0) / tan(deg_to_rad(fov) / 2.0) / viewmodel.magnification()
		var deg: Vector2 = event.screen_relative * sens * DEG_PER_UNIT * lerpf(1.0, zoom_mult, gun.ads)
		player.yaw -= deg_to_rad(deg.x)
		player.pitch = clampf(player.pitch - deg_to_rad(deg.y), deg_to_rad(-89.0), deg_to_rad(89.0))
		player.look()
		session.calib_deg += deg.x
		viewmodel.add_sway(event.screen_relative)


func _unhandled_input(event: InputEvent) -> void:
	Keys.handle(self, event)


func _notification(what: int) -> void:
	# Leaving the window mid-round would leave the mouse stuck; pause instead.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not dev_run and session:
		if state == E.State.CALIBRATE:
			session.show_menu()
		else:
			session.pause()
