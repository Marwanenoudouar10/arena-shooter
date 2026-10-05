extends Control
## Small cross with a centre dot, outlined so it reads on any background.
## show_marker() flashes an X around it: white = body hit, red = headshot, big red = kill.

enum Marker { BODY, HEAD, KILL }

const COLOR := Color(0.3, 1.0, 0.6)
const GAP := 4.0
const LENGTH := 7.0
const WIDTH := 2.0
const DIRS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
const DIAGONALS: Array[Vector2] = [Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]
const HEAD_COLOR := Color(1.0, 0.25, 0.2)

var marker_left := 0.0
var marker_duration := 0.0
var marker_color := Color.WHITE
var marker_length := 8.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_marker(kind: Marker) -> void:
	marker_color = Color.WHITE if kind == Marker.BODY else HEAD_COLOR
	marker_duration = 0.35 if kind == Marker.KILL else 0.18
	marker_length = 14.0 if kind == Marker.KILL else 8.0
	marker_left = marker_duration
	queue_redraw()


func _process(dt: float) -> void:
	if marker_left > 0.0:
		marker_left -= dt
		queue_redraw()


func _draw() -> void:
	var c := (size / 2.0).floor()
	for d in DIRS:
		draw_line(c + d * (GAP - 1.0), c + d * (GAP + LENGTH + 1.0), Color.BLACK, WIDTH + 2.0)
	for d in DIRS:
		draw_line(c + d * GAP, c + d * (GAP + LENGTH), COLOR, WIDTH)
	draw_circle(c, 2.0, Color.BLACK)
	draw_circle(c, 1.0, COLOR)

	if marker_left > 0.0:
		var alpha := clampf(marker_left / marker_duration, 0.0, 1.0)
		for d in DIAGONALS:
			var from := c + d * 7.0
			var to := c + d * (7.0 + marker_length)
			draw_line(from, to, Color(0, 0, 0, alpha), 4.0)
			draw_line(from, to, Color(marker_color, alpha), 2.0)
