## Small helpers for the self-test: checks that count failures, fake key and mouse presses,
## wait for frames.

static var failures := 0


## Like assert, but a failure inside a helper function can't be missed: it is counted and
## the self-test ends with SELFTEST FAILED instead of SELFTEST OK.
static func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)
		print("FAIL: ", message)


static func press(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


static func press_mouse(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)


static func frames(g: Node, count: int) -> void:
	for i in count:
		await g.get_tree().process_frame
