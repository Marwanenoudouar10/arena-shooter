extends Control
## EMOTES: a picture card for each emote, your character frozen in it. Click one and your
## character plays it on the stage; loops (clap, dance) keep going until you pick another.

const Lobby := preload("res://scripts/ui/lobby/lobby.gd")
const Widgets := preload("res://scripts/ui/lobby/widgets.gd")
const Emotes := preload("res://scripts/data/emotes.gd")

const PICTURE := 104.0  # height of an emote picture

var lobby: Lobby
var ui: Widgets
var grid: GridContainer
var playing := ""  # id of the emote playing on the stage


func build(lobby_node: Lobby) -> void:
	lobby = lobby_node
	ui = lobby.ui
	var box := ui.side_panel(self, "EMOTES", func() -> void: lobby.show_screen("main"))
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	box.add_child(ui.label("In a match: hold B, aim, let go", ui.SMALL, Color(1, 1, 1, 0.35)))


## Rebuild the cards, the one playing lit up.
func refresh() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var make: Callable = func() -> Node3D: return lobby.data["load_character"].call(lobby.choice["class"])
	for emote in Emotes.LIST:
		grid.add_child(ui.card(lobby.icons.emote(emote, make), emote["name"], _play.bind(emote), emote["id"] == playing, PICTURE))


func _play(emote: Dictionary) -> void:
	playing = emote["id"]
	lobby.stage.play_emote(emote)
	refresh()


## Leaving the screen stops a looping emote.
func stop() -> void:
	if playing != "":
		playing = ""
		lobby.stage.play_emote({})
