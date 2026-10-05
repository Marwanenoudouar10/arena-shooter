extends Control
## LOCKER: the clothes your current class wears, one row of picture cards per slot (head,
## top, legs, feet). Your character wears the pick right away; drag to turn him.

const Lobby := preload("res://scripts/ui/lobby/lobby.gd")
const Widgets := preload("res://scripts/ui/lobby/widgets.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")

const PICTURE := 64.0  # height of a clothes picture

var lobby: Lobby
var ui: Widgets
var rows := {}  # slot -> HBoxContainer


func build(lobby_node: Lobby) -> void:
	lobby = lobby_node
	ui = lobby.ui
	var box := ui.side_panel(self, "LOCKER", func() -> void: lobby.show_screen("main"))
	for slot in Kit.SLOTS:
		box.add_child(ui.label(slot.to_upper(), ui.SMALL, ui.ACCENT, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		rows[slot] = row


## Rebuild the cards for the current class, the worn piece of each slot lit up.
func refresh() -> void:
	var cls: String = lobby.choice["class"]
	var look := Kit.look_for(cls, lobby.choice["outfits"].get(cls, {}))
	for slot in Kit.SLOTS:
		var row: HBoxContainer = rows[slot]
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		for id in Kit.PARTS:
			if Kit.PARTS[id]["slot"] == slot:
				row.add_child(ui.card(lobby.icons.part(id), Kit.PARTS[id]["label"], lobby.wear.bind(slot, id), id == look[slot], PICTURE))
