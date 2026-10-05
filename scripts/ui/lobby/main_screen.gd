extends Control
## The lobby's main screen: the logo top left, links top right, your class bottom left and,
## bottom right, MY BUILD, the LOCKER, the map picker, your best score here and PLAY.

const Lobby := preload("res://scripts/ui/lobby/lobby.gd")
const Widgets := preload("res://scripts/ui/lobby/widgets.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")

var lobby: Lobby
var ui: Widgets
var class_label: Label
var build_summary: Label
var gun_picture: TextureRect
var locker_pictures := {}  # slot -> TextureRect
var map_image: TextureRect
var map_name_label: Label
var best_label: Label


func build(lobby_node: Lobby) -> void:
	lobby = lobby_node
	ui = lobby.ui
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var logo := HBoxContainer.new()
	logo.position = Vector2(ui.MARGIN, ui.MARGIN - 10)
	logo.add_theme_constant_override("separation", 10)
	logo.add_child(ui.label("ARENA", ui.BIG, Color.WHITE, true))
	logo.add_child(ui.label("SHOOTER", ui.BIG, Color(1, 1, 1, 0.7), true))
	add_child(logo)

	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 34)
	links.add_child(ui.link("FLICK DRILL", func() -> void: lobby.play.emit("flicks")))
	links.add_child(ui.link("360 SENS TEST", func() -> void: lobby.calibrate.emit()))
	links.add_child(ui.link("EMOTES", func() -> void: lobby.show_screen("emotes")))
	links.add_child(ui.link("SETTINGS", func() -> void: lobby.show_screen("settings")))
	links.add_child(ui.link("QUIT", func() -> void: lobby.quit.emit()))
	add_child(links)
	ui.pin(links, Vector2(1, 0), Vector2(-ui.MARGIN, ui.MARGIN - 6))

	var who := VBoxContainer.new()
	class_label = ui.label("", ui.BIG, Color.WHITE, true)
	who.add_child(class_label)
	who.add_child(ui.label("Drag to turn your character", ui.SMALL, Color(1, 1, 1, 0.35)))
	add_child(who)
	ui.pin(who, Vector2(0, 1), Vector2(ui.MARGIN, -ui.MARGIN))

	# Bottom right: MY BUILD, the map, PLAY.
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(ui.RIGHT_W, 0)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	ui.pin(column, Vector2(1, 1), Vector2(-ui.MARGIN, -ui.MARGIN))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	cards.add_child(_build_button())
	cards.add_child(_locker_button())
	column.add_child(cards)
	column.add_child(_map_picker())
	best_label = ui.label("", ui.SMALL, ui.DIM)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(best_label)
	column.add_child(_play_button())


## Show the picked class, the build summary and the picked map.
func refresh() -> void:
	var choice: Dictionary = lobby.choice
	var cls := lobby.class_item(choice["class"])
	var gun := lobby.gun_item(choice["gun"])
	var optic_name: String = lobby.data["optics"].filter(func(o: Array) -> bool: return o[0] == choice["optic"])[0][1]
	class_label.text = String(cls["name"]).to_upper()
	build_summary.text = "%s  ·  %s" % [String(gun["name"]).to_upper(), optic_name.to_upper()]
	gun_picture.texture = lobby.icons.gun(gun["file"])
	var look := Kit.look_for(choice["class"], choice["outfits"].get(choice["class"], {}))
	for slot in locker_pictures:
		locker_pictures[slot].texture = lobby.icons.part(look[slot])
	var map := lobby.map_item(choice["map"])
	map_name_label.text = "%s   —   %s" % [String(map["name"]).to_upper(), map["desc"]]
	map_image.texture = _thumb(map.get("thumb", ""))


## The MY BUILD card: a picture of your gun and its name; opens the build panel.
func _build_button() -> Button:
	var card := ui.panel_button()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var build_box := VBoxContainer.new()
	build_box.add_theme_constant_override("separation", 2)
	build_box.add_child(ui.label("MY BUILD", ui.SMALL, ui.ACCENT, true))
	gun_picture = _picture(58)
	build_box.add_child(gun_picture)
	build_summary = ui.label("", ui.SMALL, Color.WHITE)
	build_box.add_child(build_summary)
	ui.fill_button(card, build_box)
	card.pressed.connect(func() -> void: lobby.show_screen("build"))
	return card


## The LOCKER card: small pictures of what you wear; opens the locker.
func _locker_button() -> Button:
	var card := ui.panel_button()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var locker_box := VBoxContainer.new()
	locker_box.add_theme_constant_override("separation", 2)
	locker_box.add_child(ui.label("LOCKER", ui.SMALL, ui.ACCENT, true))
	var worn := HBoxContainer.new()
	worn.add_theme_constant_override("separation", 2)
	for slot in Kit.SLOTS:
		var picture := _picture(84)
		picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		worn.add_child(picture)
		locker_pictures[slot] = picture
	locker_box.add_child(worn)
	ui.fill_button(card, locker_box)
	card.pressed.connect(func() -> void: lobby.show_screen("locker"))
	return card


func _picture(height: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(0, height)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


## The map card: picture with ‹ › arrows to step through the maps, name and description below.
func _map_picker() -> PanelContainer:
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", ui.box(ui.PANEL, ui.LINE, 14))
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 8)
	map_box.add_child(ui.label("MAP", ui.SMALL, ui.ACCENT, true))
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	picker.add_child(ui.arrow("‹", func() -> void: lobby.step_map(-1)))
	map_image = TextureRect.new()
	map_image.custom_minimum_size = Vector2(0, 150)
	map_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picker.add_child(map_image)
	picker.add_child(ui.arrow("›", func() -> void: lobby.step_map(1)))
	map_box.add_child(picker)
	map_name_label = ui.label("", ui.SMALL, Color.WHITE)
	map_box.add_child(map_name_label)
	map_panel.add_child(map_box)
	return map_panel


func _play_button() -> Button:
	var play_button := Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(ui.RIGHT_W, 86)
	play_button.add_theme_font_override("font", ui.heavy_font)
	play_button.add_theme_font_size_override("font_size", ui.BIG)
	play_button.add_theme_color_override("font_color", Color.WHITE)
	play_button.add_theme_color_override("font_hover_color", Color.WHITE)
	play_button.add_theme_stylebox_override("normal", ui.box(ui.ACCENT, Color(1, 1, 1, 0.0), 0, 0.12))
	play_button.add_theme_stylebox_override("hover", ui.box(ui.ACCENT.lightened(0.15), Color(1, 1, 1, 0.6), 0, 0.12))
	play_button.add_theme_stylebox_override("pressed", ui.box(ui.ACCENT.darkened(0.15), Color(1, 1, 1, 0.6), 0, 0.12))
	play_button.add_theme_stylebox_override("focus", ui.box(ui.ACCENT, Color(1, 1, 1, 0.6), 0, 0.12))
	play_button.pressed.connect(func() -> void:
		ui.sfx("confirm")
		lobby.play.emit("fight"))
	return play_button


func _thumb(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null
