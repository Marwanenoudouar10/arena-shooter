extends Control
## MY BUILD: pick your class, your weapon (picture cards), its sight and which enemies you
## face. The picked gun shows big on the stage. Clicks go through the lobby's pick_*.

const Lobby := preload("res://scripts/ui/lobby/lobby.gd")
const Widgets := preload("res://scripts/ui/lobby/widgets.gd")

const PICTURE := 118.0  # height of a weapon picture

var lobby: Lobby
var ui: Widgets
var class_buttons := {}  # class id -> pill
var enemy_buttons := {}  # Mixed / Light / ... -> pill
var weapon_row: HBoxContainer
var sight_row: HBoxContainer


func build(lobby_node: Lobby) -> void:
	lobby = lobby_node
	ui = lobby.ui
	var box := ui.side_panel(self, "MY BUILD", func() -> void: lobby.show_screen("main"))
	box.add_child(ui.label("CLASS", ui.SMALL, ui.ACCENT, true))
	var classes := _row()
	for cls in lobby.data["classes"]:
		var b := ui.pill(String(cls["name"]).to_upper(), func() -> void: lobby.pick_class(cls["id"]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		class_buttons[cls["id"]] = b
		classes.add_child(b)
	box.add_child(classes)
	box.add_child(ui.gap(6))
	box.add_child(ui.label("WEAPON", ui.SMALL, ui.ACCENT, true))
	weapon_row = _row()
	box.add_child(weapon_row)
	box.add_child(ui.gap(6))
	box.add_child(ui.label("SIGHT", ui.SMALL, ui.ACCENT, true))
	sight_row = _row()
	box.add_child(sight_row)
	box.add_child(ui.gap(6))
	box.add_child(ui.label("ENEMIES", ui.SMALL, ui.ACCENT, true))
	var enemies := _row()
	for e in lobby.ENEMY_OPTIONS:
		var b := ui.pill(e.to_upper(), func() -> void: _pick_enemies(e), e == lobby.choice["enemies"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enemy_buttons[e] = b
		enemies.add_child(b)
	box.add_child(enemies)
	box.add_child(ui.label("Drag the gun to turn it", ui.SMALL, Color(1, 1, 1, 0.35)))


## Light up the picked class and enemies, rebuild the weapon cards and sights.
func refresh() -> void:
	for id in class_buttons:
		ui.style_pill(class_buttons[id], id == lobby.choice["class"])
	_fill_weapons()
	_fill_sights()


func _pick_enemies(enemies: String) -> void:
	lobby.choice["enemies"] = enemies
	for id in enemy_buttons:
		ui.style_pill(enemy_buttons[id], id == enemies)
	lobby.loadout_changed.emit(lobby.choice.duplicate(true))


func _fill_weapons() -> void:
	for child in weapon_row.get_children():
		weapon_row.remove_child(child)
		child.queue_free()
	for gun in lobby.class_guns(lobby.choice["class"]):
		var picked: bool = gun["id"] == lobby.choice["gun"]
		weapon_row.add_child(ui.card(lobby.icons.gun(gun["file"]), gun["name"], lobby.pick_gun.bind(gun["id"]), picked, PICTURE))


func _fill_sights() -> void:
	for child in sight_row.get_children():
		sight_row.remove_child(child)
		child.queue_free()
	var gun := lobby.gun_item(lobby.choice["gun"])
	for optic in lobby.data["optics"]:
		if optic[0] in gun["optics"]:
			var b := ui.pill(String(optic[1]).to_upper(), lobby.pick_optic.bind(optic[0]), optic[0] == lobby.choice["optic"])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sight_row.add_child(b)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row
