extends Control
## The lobby: your character on a lit turntable stage (drag to spin), MY BUILD (class,
## weapon, sight), the LOCKER (clothes), EMOTES, the map picker and PLAY in the bottom right.
## UI only: main.gd owns the game, hands in the lists with setup() and reacts to signals.
## This file keeps your choices and the public API. The parts live next to it: stage.gd
## (+ showcase.gd), main_screen.gd, build_panel.gd, locker_panel.gd, emote_panel.gd, settings_panel.gd,
## icons.gd (card pictures) and widgets.gd (look + building blocks).

# The first four are emitted by main_screen.gd and settings_panel.gd, so Godot thinks they are unused.
@warning_ignore_start("unused_signal")
signal play(mode: String)  # "fight" or "flicks"
signal calibrate
signal quit
signal setting_changed(key: String, value: Variant)
@warning_ignore_restore("unused_signal")
signal loadout_changed(choice: Dictionary)  # {map, class, gun, optic, enemies}

const Widgets := preload("res://scripts/ui/lobby/widgets.gd")
const Stage := preload("res://scripts/ui/lobby/stage.gd")
const MainScreen := preload("res://scripts/ui/lobby/main_screen.gd")
const BuildPanel := preload("res://scripts/ui/lobby/build_panel.gd")
const LockerPanel := preload("res://scripts/ui/lobby/locker_panel.gd")
const EmotePanel := preload("res://scripts/ui/lobby/emote_panel.gd")
const Icons := preload("res://scripts/ui/lobby/icons.gd")
const SettingsPanel := preload("res://scripts/ui/lobby/settings_panel.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")

# The look lives in widgets.gd. These copies stay here because main.gd's pause menu reads them.
const DIM := Widgets.DIM
const BIG := Widgets.BIG
const SMALL := Widgets.SMALL
const RIGHT_W := Widgets.RIGHT_W
const MARGIN := Widgets.MARGIN
const ENEMY_OPTIONS: Array[String] = ["Mixed", "Light", "Medium", "Heavy"]

var data := {}
var choice := {"map": "Arena", "class": "Medium", "gun": "Striker", "optic": "RedDot", "enemies": "Mixed", "outfits": {}}
var screen := "main"
var ui: Widgets  # fonts and building blocks, shared by every part
var icons: Icons  # pictures of guns and clothes for the cards
var stage: Stage
var characters := {}  # class -> {root, guns: {gun id -> Node3D}} (they live on the stage)
var main_ui: MainScreen
var build_ui: BuildPanel
var locker_ui: LockerPanel
var emote_ui: EmotePanel
var settings_ui: SettingsPanel


func setup(lobby_data: Dictionary) -> void:
	data = lobby_data
	choice.merge(lobby_data.get("choice", {}), true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sound: Callable = lobby_data.get("sfx", Callable())
	ui = Widgets.new(sound)
	theme = ui.make_theme()
	icons = Icons.new(data["load_glb"])
	add_child(icons)
	# Back to front: the 3D stage, a shade over it, then the three screens.
	stage = Stage.new()
	add_child(stage)
	stage.build(data)
	characters = stage.characters
	_build_shade()
	main_ui = MainScreen.new()
	add_child(main_ui)
	main_ui.build(self)
	build_ui = BuildPanel.new()
	add_child(build_ui)
	build_ui.build(self)
	locker_ui = LockerPanel.new()
	add_child(locker_ui)
	locker_ui.build(self)
	emote_ui = EmotePanel.new()
	add_child(emote_ui)
	emote_ui.build(self)
	settings_ui = SettingsPanel.new()
	add_child(settings_ui)
	settings_ui.build(self)
	_refresh()
	show_screen("main")


func show_screen(id: String) -> void:
	screen = id
	main_ui.visible = id == "main"
	build_ui.visible = id == "build"
	locker_ui.visible = id == "locker"
	emote_ui.visible = id == "emotes"
	if id != "emotes":
		emote_ui.stop()
	settings_ui.visible = id == "settings"
	stage.set_mode("gun" if id == "build" else "character")
	show()


func set_best(text: String) -> void:
	main_ui.best_label.text = text


func refresh_settings(sens: float, fov: float, move: bool) -> void:
	settings_ui.set_values(sens, fov, move)


## Same as clicking in the build panel; keeps the gun and sight valid for the class.
func pick_class(cls: String) -> void:
	choice["class"] = cls
	var own := class_guns(cls)
	if not choice["gun"] in own.map(func(g: Dictionary) -> String: return g["id"]):
		choice["gun"] = own[0]["id"]
	_fix_optic()
	_refresh()


func pick_gun(gun_id: String) -> void:
	choice["gun"] = gun_id
	_fix_optic()
	_refresh()


func pick_optic(optic_id: String) -> void:
	choice["optic"] = optic_id
	_refresh()


## Put a piece of clothing on the current class (e.g. "Top", "top_jacket"). Picking the
## class's own piece takes the override off again.
func wear(slot: String, outfit: String) -> void:
	var cls: String = choice["class"]
	var wearing: Dictionary = choice["outfits"].get(cls, {}).duplicate()
	if Kit.look_for(cls)[slot] == outfit:
		wearing.erase(slot)
	else:
		wearing[slot] = outfit
	if wearing.is_empty():
		choice["outfits"].erase(cls)
	else:
		choice["outfits"][cls] = wearing
	Kit.dress(characters[cls]["root"], Kit.look_for(cls, wearing), data["load_glb"])
	_refresh()


func step_map(dir: int) -> void:
	var maps: Array = (data["maps"] as Array).filter(func(m: Dictionary) -> bool: return m["enabled"])
	var ids := maps.map(func(m: Dictionary) -> String: return m["id"])
	var at := maxi(ids.find(choice["map"]), 0)
	choice["map"] = ids[posmod(at + dir, ids.size())]
	_refresh()


# --- Lookups in the lists from main.gd (the parts use these too) ---------------------------

func class_guns(cls: String) -> Array:
	return (data["guns"] as Array).filter(func(g: Dictionary) -> bool: return g["class"] == cls)


func gun_item(id: String) -> Dictionary:
	return (data["guns"] as Array).filter(func(g: Dictionary) -> bool: return g["id"] == id)[0]


func class_item(id: String) -> Dictionary:
	return (data["classes"] as Array).filter(func(c: Dictionary) -> bool: return c["id"] == id)[0]


func map_item(id: String) -> Dictionary:
	return (data["maps"] as Array).filter(func(m: Dictionary) -> bool: return m["id"] == id)[0]


# --- Building blocks main.gd's pause menu borrows ------------------------------------------

func _label(text: String, font_size: int, color: Color, heavy := false) -> Label:
	return ui.label(text, font_size, color, heavy)


func _pill(text: String, on_press: Callable, picked := false) -> Button:
	return ui.pill(text, on_press, picked)


func _gap(height: float) -> Control:
	return ui.gap(height)


# --- Input and state -------------------------------------------------------------------------

func _process(dt: float) -> void:
	if visible:
		stage.coast(dt)


func _gui_input(event: InputEvent) -> void:
	stage.drag(event)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if screen != "main":
			show_screen("main")
			get_viewport().set_input_as_handled()


## Darken the edges and the bottom so the panels and text read cleanly over the stage.
func _build_shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0, 0, 0, 0.72))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.35, 0.45)
	tex.fill_to = Vector2(1.15, 1.1)
	var shade := TextureRect.new()
	shade.texture = tex
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


## Push the current choice to every part, then tell main.gd.
func _refresh() -> void:
	main_ui.refresh()
	build_ui.refresh()
	locker_ui.refresh()
	emote_ui.refresh()
	stage.show_pick(choice["class"], choice["gun"])
	loadout_changed.emit(choice.duplicate(true))


func _fix_optic() -> void:
	var allowed: Array = gun_item(choice["gun"])["optics"]
	if not choice["optic"] in allowed:
		choice["optic"] = allowed[0]
