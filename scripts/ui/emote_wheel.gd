extends Control
## The emote wheel: a ring of emote pictures around the screen centre. While it is open the
## mouse picks a slot (move toward it); the picked emote's name shows in the middle.

const RADIUS := 230.0
const SLOT := Vector2(96, 120)
const PICK_DEADZONE := 25.0  # mouse travel before a slot is picked
const RED := Color(0.9, 0.08, 0.14)

var slots: Array[Panel] = []
var names: Array[String] = []
var title: Label
var aim := Vector2.ZERO
var picked := -1


func build(pictures: Array, emote_names: Array[String], font: Font) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	names = emote_names
	for i in pictures.size():
		var slot := Panel.new()
		slot.size = SLOT
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := TextureRect.new()
		picture.texture = pictures[i]
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(picture)
		add_child(slot)
		slots.append(slot)
	title = Label.new()
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(title)
	resized.connect(_layout)
	hide()


func open() -> void:
	aim = Vector2.ZERO
	picked = -1
	_layout()
	_show_pick()
	show()


## Closes the wheel. Returns the picked slot, or -1 when the mouse stayed in the middle.
func close() -> int:
	hide()
	return picked


func steer(relative: Vector2) -> void:
	aim = (aim + relative).limit_length(120.0)
	if aim.length() > PICK_DEADZONE:
		var step := TAU / slots.size()
		var angle := fposmod(atan2(aim.x, -aim.y) + step / 2.0, TAU)  # 0 = straight up, clockwise
		picked = int(angle / step) % slots.size()
	_show_pick()


func _layout() -> void:
	var center := size / 2.0
	for i in slots.size():
		var angle := TAU * i / slots.size()
		slots[i].position = center + Vector2(sin(angle), -cos(angle)) * RADIUS - SLOT / 2.0
	title.position = center - title.size / 2.0


func _show_pick() -> void:
	for i in slots.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.06, 0.82) if i != picked else RED.darkened(0.45)
		style.border_color = RED if i == picked else Color(1, 1, 1, 0.15)
		style.set_border_width_all(3 if i == picked else 1)
		style.set_corner_radius_all(10)
		slots[i].add_theme_stylebox_override("panel", style)
	title.text = names[picked].to_upper() if picked >= 0 else "EMOTES"
	title.reset_size()
	title.position = size / 2.0 - title.size / 2.0


func _draw() -> void:
	draw_circle(size / 2.0, RADIUS + 90.0, Color(0, 0, 0, 0.45))
