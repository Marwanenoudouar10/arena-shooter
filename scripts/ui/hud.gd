extends Node
## The numbers on screen while you play: accuracy, headshots and kills (or flick hits), ammo,
## how you are moving, the countdown, fps and sens, and the 360 test instructions.

const E := preload("res://scripts/core/enums.gd")
const Session := preload("res://scripts/modes/session.gd")

const CALIB_HELP := """360 TEST
1. In your other game: mark your mousepad, turn exactly one full circle, mark where the mouse stopped.
2. Here: press R, then move your mouse from the first mark to the second.
3. Press Enter. Sensitivity is set so that move = 360°.
4. Press R and repeat the move to check it reads 360°.

Up / Down arrows: sens ±1% (Shift ±10%)
Esc: menu"""

var game: Node3D
var ui: CanvasLayer
var font: SystemFont
var heavy: SystemFont
var timer: Label
var stats: Label
var info: Label
var big_label: Label
var move: Label
var ammo: Label


func build(layer: CanvasLayer) -> void:
	ui = layer
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next Condensed", "Helvetica Neue"])
	font.font_weight = 600
	heavy = SystemFont.new()
	heavy.font_names = PackedStringArray(["Avenir Next Condensed", "Helvetica Neue"])
	heavy.font_weight = 800
	timer = _label(40, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	stats = _label(22, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	stats.anchor_right = 0.42
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info = _label(16, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	big_label = _label(110, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	move = _label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	ammo = _label(32, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)


func update() -> void:
	var s: Node = game.session
	var state: E.State = game.state
	info.visible = state != E.State.MENU
	info.text = "%d fps  ·  sens %.4f  ·  fov %d" % [Engine.get_frames_per_second(), game.sens, int(game.fov)]
	timer.text = ""
	stats.text = ""
	move.text = ""
	ammo.text = ""
	if game.move_enabled and state in [E.State.COUNTDOWN, E.State.PLAYING]:
		move.text = "%s   %.1f m/s" % [game.player.move_label, game.player.flat_speed()]
	match state:
		E.State.COUNTDOWN, E.State.PLAYING:
			if game.mode == E.Mode.TRACKING:
				stats.text = "Accuracy %.0f%%\nHeadshots %.0f%%\nKills %d" % [
					Session.pct(s.shot_hits, s.shots), Session.pct(s.head_hits, s.shot_hits), s.kills]
				var gun: Node = game.gun
				var rounds: String = "RELOADING" if gun.reloading() else "%d / %d" % [gun.ammo, gun.data()["mag"]]
				ammo.text = "%s   %s" % [game.gun_name, rounds]
			else:
				stats.text = "Hits %d\nAccuracy %.0f%%" % [s.hits, Session.pct(s.hits, s.hits + s.misses)]
		E.State.CALIBRATE:
			timer.text = "Turned %.1f°" % absf(s.calib_deg)
			stats.text = CALIB_HELP


func _label(font_size: int, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", heavy if font_size >= 30 else font)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	ui.add_child(l)
	return l
