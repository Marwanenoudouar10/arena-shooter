extends Control
## Esc in a round: the game dimmed behind, this session's numbers, and resume / lobby / quit.
## Uses the lobby's look (fonts, buttons) so both menus match.

var stats: Label


func build(lobby: Control, on_resume: Callable, on_lobby: Callable) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = lobby.theme
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.025, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(lobby.MARGIN * 2.0, -200)
	column.custom_minimum_size = Vector2(lobby.RIGHT_W, 0)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(lobby._label("PAUSED", lobby.BIG, Color.WHITE, true))
	stats = lobby._label("", lobby.SMALL, lobby.DIM)
	column.add_child(stats)
	column.add_child(lobby._gap(8))
	var resume: Button = lobby._pill("RESUME", on_resume, true)
	resume.custom_minimum_size = Vector2(0, 64)
	column.add_child(resume)
	column.add_child(lobby._pill("BACK TO LOBBY", on_lobby))
	column.add_child(lobby._pill("QUIT GAME", func() -> void: get_tree().quit()))
	column.add_child(lobby._label("Esc to resume", lobby.SMALL, Color(1, 1, 1, 0.35)))
	hide()
