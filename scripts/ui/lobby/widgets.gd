extends RefCounted
## The lobby's look and its small building blocks: colours, the two text sizes, the fonts,
## and helpers for labels, boxes, pills, links, picture cards, form rows and side panels.
## The lobby makes one and every part of it (and main.gd's pause menu) shares it.

const ACCENT := Color(0.9, 0.08, 0.14)  # red (with white: the only two colours)
const PANEL := Color(0.05, 0.055, 0.065, 0.78)
const LINE := Color(1, 1, 1, 0.1)
const DIM := Color(1, 1, 1, 0.58)
const BIG := 46  # headings (two sizes only)
const SMALL := 19
const RIGHT_W := 440.0
const MARGIN := 56.0

var heavy_font: SystemFont
var body_font: SystemFont
var play_sound: Callable  # from main.gd: plays a UI sound by name (empty = no sound)


func _init(sound: Callable) -> void:
	play_sound = sound
	heavy_font = SystemFont.new()
	heavy_font.font_names = PackedStringArray(["Avenir Next Condensed", "DIN Condensed", "Helvetica Neue"])
	heavy_font.font_weight = 800
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Avenir Next Condensed", "Avenir Next", "Helvetica Neue"])
	body_font.font_weight = 500


## The lobby's theme: the body font at the small size.
func make_theme() -> Theme:
	var look := Theme.new()
	look.default_font = body_font
	look.default_font_size = SMALL
	return look


func sfx(sound: String) -> void:
	if not play_sound.is_null():
		play_sound.call(sound)


func label(text: String, size: int, color: Color, heavy := false) -> Label:
	var text_label := Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", size)
	text_label.add_theme_color_override("font_color", color)
	if heavy:
		text_label.add_theme_font_override("font", heavy_font)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return text_label


func box(bg: Color, border: Color, pad: float, skew := 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_content_margin_all(pad)
	style.skew = Vector2(skew, 0)
	return style


func panel_button(picked := false) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", box(PANEL, ACCENT if picked else LINE, 14))
	button.add_theme_stylebox_override("hover", box(PANEL.lightened(0.06), ACCENT, 14))
	button.add_theme_stylebox_override("pressed", box(PANEL.lightened(0.1), ACCENT, 14))
	button.add_theme_stylebox_override("focus", box(PANEL, ACCENT if picked else LINE, 14))
	button.pressed.connect(sfx.bind("click"))
	return button


func pill(text: String, on_press: Callable, picked := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_override("font", heavy_font)
	button.add_theme_font_size_override("font_size", SMALL)
	button.pressed.connect(on_press)
	button.pressed.connect(sfx.bind("click"))
	style_pill(button, picked)
	return button


func style_pill(button: Button, picked: bool) -> void:
	var bg := ACCENT if picked else PANEL
	button.add_theme_stylebox_override("normal", box(bg, LINE, 8, 0.12))
	button.add_theme_stylebox_override("hover", box(bg.lightened(0.12), ACCENT, 8, 0.12))
	button.add_theme_stylebox_override("pressed", box(bg.darkened(0.1), ACCENT, 8, 0.12))
	button.add_theme_stylebox_override("focus", box(bg, LINE, 8, 0.12))
	button.add_theme_color_override("font_color", Color.WHITE)


func link(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", heavy_font)
	button.add_theme_font_size_override("font_size", SMALL)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_pressed_color", ACCENT)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(on_press)
	button.pressed.connect(sfx.bind("click"))
	return button


func arrow(text: String, on_press: Callable) -> Button:
	var button := link(text, on_press)
	button.add_theme_font_size_override("font_size", BIG)
	button.custom_minimum_size = Vector2(36, 0)
	return button


## A picture card: the picture on top, the name under it, outlined orange when picked.
func card(texture: Texture2D, title: String, on_press: Callable, picked: bool, picture_height: float) -> Button:
	var button := panel_button(picked)
	if picked:
		button.add_theme_stylebox_override("normal", box(ACCENT.darkened(0.7), ACCENT, 14))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = Vector2(0, picture_height)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(picture)
	var name_label := label(title.to_upper(), SMALL, ACCENT if picked else Color.WHITE, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	fill_button(button, column)
	button.pressed.connect(on_press)
	return button


func spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin_box := SpinBox.new()
	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = step
	spin_box.value = value
	spin_box.custom_minimum_size = Vector2(170, 0)
	return spin_box


func form_row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := label(title, SMALL, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(control)
	return row


func gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Pin a control to a screen corner (anchor 0/1 per axis) so it grows away from it.
func pin(control: Control, corner: Vector2, offset: Vector2) -> void:
	control.anchor_left = corner.x
	control.anchor_right = corner.x
	control.anchor_top = corner.y
	control.anchor_bottom = corner.y
	control.offset_left = offset.x
	control.offset_right = offset.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN if corner.x > 0.5 else Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if corner.y > 0.5 else Control.GROW_DIRECTION_END


## Buttons do not size to what is inside them: lay the content over the button with
## padding and make the button as tall as the content needs.
func fill_button(button: Button, inner: Control) -> void:
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	var fit := func() -> void: button.custom_minimum_size.y = inner.get_combined_minimum_size().y + 28
	fit.call_deferred()


## Turn `root` (already in the lobby) into a right-hand panel over the stage with a title,
## a content box and a DONE button that calls `on_done`. Returns the content box.
func side_panel(root: Control, title: String, on_done: Callable) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -620
	panel.add_theme_stylebox_override("panel", box(Color(0.03, 0.035, 0.04, 0.9), LINE, 36))
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(label(title, BIG, Color.WHITE, true))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	var done := pill("DONE", on_done, true)
	done.custom_minimum_size = Vector2(0, 58)
	column.add_child(done)
	column.add_child(label("Esc to go back", SMALL, Color(1, 1, 1, 0.35)))
	return content
