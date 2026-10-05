extends Control
## SETTINGS: the side panel with sensitivity, field of view, move while aiming, graphics
## quality and volume. Every change goes out through the lobby's setting_changed signal.

const Lobby := preload("res://scripts/ui/lobby/lobby.gd")

var sens_box: SpinBox
var fov_box: SpinBox
var move_box: CheckBox


func build(lobby: Lobby) -> void:
	var ui := lobby.ui
	var box := ui.side_panel(self, "SETTINGS", func() -> void: lobby.show_screen("main"))
	var settings: Dictionary = lobby.data["settings"]
	sens_box = ui.spin(0.01, 50.0, 0.0001, settings["sens"])
	sens_box.value_changed.connect(func(v: float) -> void: lobby.setting_changed.emit("sens", v))
	box.add_child(ui.form_row("Sensitivity", sens_box))
	fov_box = ui.spin(60.0, 130.0, 1.0, settings["fov"])
	fov_box.value_changed.connect(func(v: float) -> void: lobby.setting_changed.emit("fov", v))
	box.add_child(ui.form_row("Field of view (horizontal)", fov_box))
	move_box = CheckBox.new()
	move_box.button_pressed = settings["move"]
	move_box.toggled.connect(func(on: bool) -> void: lobby.setting_changed.emit("move", on))
	box.add_child(ui.form_row("Move while aiming", move_box))
	var quality := OptionButton.new()
	var qualities: Array = settings.get("qualities", [])
	for q in qualities:
		quality.add_item(q)
	quality.selected = maxi(qualities.find(settings.get("quality", "Medium")), 0)
	quality.item_selected.connect(func(i: int) -> void: lobby.setting_changed.emit("quality", qualities[i]))
	box.add_child(ui.form_row("Graphics (Low = fastest)", quality))
	var volume := HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = settings.get("volume", 0.8)
	volume.custom_minimum_size = Vector2(200, 0)
	volume.value_changed.connect(func(v: float) -> void: lobby.setting_changed.emit("volume", v))
	box.add_child(ui.form_row("Volume", volume))


## Show values that changed elsewhere (e.g. after the 360 test) without firing the signal.
func set_values(sens: float, fov: float, move: bool) -> void:
	sens_box.set_value_no_signal(sens)
	fov_box.set_value_no_signal(fov)
	move_box.set_pressed_no_signal(move)
