## Keys during play (physical keys, so QWERTY / AZERTY does not matter): Esc pause, R reload
## (or restart the 360 test), Backspace restart, Enter set sens from the 360 test, Up / Down
## sens, F fullscreen. Left click shoots in the flick drill. (B, the emote wheel, is in
## player/emote.gd.)

const E := preload("res://scripts/core/enums.gd")
const Settings := preload("res://scripts/core/settings.gd")


static func handle(g: Node3D, event: InputEvent) -> void:
	var state: E.State = g.state
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == E.State.PLAYING and g.mode == E.Mode.FLICKS:
			g.flicks.shoot()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Physical keys so the layout (QWERTY/AZERTY) does not matter.
	match event.physical_keycode:
		KEY_ESCAPE:
			match state:
				E.State.COUNTDOWN, E.State.PLAYING:
					g.session.pause()
				E.State.PAUSED:
					g.session.resume()
				E.State.CALIBRATE:
					g.session.show_menu()
		KEY_R:
			if state == E.State.CALIBRATE:
				g.reset_view()
				g.session.calib_deg = 0.0
			elif state == E.State.PLAYING and g.mode == E.Mode.TRACKING:
				g.gun.start_reload()
		KEY_BACKSPACE:
			if state in [E.State.COUNTDOWN, E.State.PLAYING]:
				g.session.start_round(g.mode)
		KEY_ENTER, KEY_KP_ENTER:
			if state == E.State.CALIBRATE and absf(g.session.calib_deg) > 30.0:
				set_sens(g, g.sens * 360.0 / absf(g.session.calib_deg))
				g.reset_view()
				g.session.calib_deg = 0.0
		KEY_UP:
			set_sens(g, g.sens * (1.1 if event.shift_pressed else 1.01))
		KEY_DOWN:
			set_sens(g, g.sens / (1.1 if event.shift_pressed else 1.01))
		KEY_F:
			toggle_fullscreen()


static func set_sens(g: Node3D, value: float) -> void:
	g.sens = clampf(value, 0.01, 50.0)
	g.lobby.refresh_settings(g.sens, g.fov, g.move_enabled)
	Settings.save(g)


static func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
