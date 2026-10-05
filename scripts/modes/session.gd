extends Node
## A play session from start to finish: the lobby, the countdown, the round (no timer, play
## as long as you like), pausing, the 360 sensitivity test, the numbers you get, and saving
## best scores when you leave.

const E := preload("res://scripts/core/enums.gd")
const Settings := preload("res://scripts/core/settings.gd")

const COUNTDOWN_TIME := 2.0
const MIN_SESSION := 10.0  # seconds of play before a session counts for best scores

var game: Node3D
var countdown := 0.0
var round_clock := 0.0
var calib_deg := 0.0  # how far you turned in the 360 test
var kills := 0
var shots := 0
var shot_hits := 0
var head_hits := 0
var damage_done := 0.0
var hits := 0  # flick drill
var misses := 0


func show_menu() -> void:
	game.state = E.State.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hide_world_targets()
	game.crosshair.hide()
	game.pause_menu.hide()
	game.get_viewport().disable_3d = true  # the lobby stage renders on its own
	game.hud.big_label.text = ""
	var best_here: float = game.best.get("fight_" + game.map_name.to_lower(), 0.0)
	game.lobby.set_best("BEST HERE  %.0f DAMAGE / SEC" % best_here if best_here > 0.0 else "NO SCORE ON THIS MAP YET")
	game.lobby.show_screen("main")


func start_round(m: E.Mode, capture := true) -> void:
	game.mode = m
	game.state = E.State.COUNTDOWN
	countdown = COUNTDOWN_TIME
	round_clock = 0.0
	kills = 0
	hits = 0
	misses = 0
	shots = 0
	shot_hits = 0
	head_hits = 0
	damage_done = 0.0
	game.gun.reset()
	game.reset_view()
	game.hide_world_targets()
	game.impacts.clear()
	game.viewmodel.show()
	game.viewmodel.equip()
	if m == E.Mode.TRACKING:
		game.enemy.spawn()
	else:
		game.flicks.show_all()
	_enter_3d()
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func update(dt: float) -> void:
	match game.state:
		E.State.COUNTDOWN:
			countdown -= dt
			game.hud.big_label.text = str(ceili(countdown))
			if countdown <= 0.0:
				game.hud.big_label.text = ""
				game.state = E.State.PLAYING
		E.State.PLAYING:
			round_clock += dt


func pause() -> void:
	if game.state not in [E.State.COUNTDOWN, E.State.PLAYING]:
		return
	game.state = E.State.PAUSED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.pause_menu.stats.text = summary()
	game.pause_menu.show()


func resume() -> void:
	game.pause_menu.hide()
	game.state = E.State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func summary() -> String:
	var minutes := int(round_clock) / 60
	var seconds := int(round_clock) % 60
	if game.mode == E.Mode.TRACKING:
		return "%d:%02d played   ·   %d kills   ·   %.0f%% accuracy   ·   %.0f%% headshots   ·   %.0f damage / sec" % [
				minutes, seconds, kills, pct(shot_hits, shots), pct(head_hits, shot_hits), damage_done / maxf(round_clock, 1.0)]
	return "%d:%02d played   ·   %d hits   ·   %.0f%% accuracy" % [minutes, seconds, hits, pct(hits, hits + misses)]


## Leave to the lobby. Sessions longer than MIN_SESSION count toward best scores and history.
func end() -> void:
	if round_clock >= MIN_SESSION:
		var tracking: bool = game.mode == E.Mode.TRACKING
		var key: String = ("fight_" if tracking else "flicks_") + game.map_name.to_lower()
		var score := 0.0
		var detail := ""
		if tracking:
			score = damage_done / round_clock
			detail = "kills=%d;acc=%.1f;hs=%.1f;secs=%d" % [kills, pct(shot_hits, shots), pct(head_hits, shot_hits), int(round_clock)]
		else:
			score = hits / (round_clock / 60.0) * pct(hits, hits + misses) / 100.0
			detail = "hits=%d;acc=%.1f;secs=%d" % [hits, pct(hits, hits + misses), int(round_clock)]
		if score > game.best.get(key, 0.0):
			game.best[key] = score
			Settings.save(game)
		Settings.append_history(game, key, score, detail)
	show_menu()


func start_calibration() -> void:
	game.state = E.State.CALIBRATE
	game.hide_world_targets()
	game.world.marker.show()
	_enter_3d()
	game.reset_view()
	calib_deg = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func pct(part: float, whole: float) -> float:
	return 100.0 * part / whole if whole > 0.0 else 0.0


## Lobby away, the 3D world back on, crosshair up.
func _enter_3d() -> void:
	game.lobby.hide()
	game.pause_menu.hide()
	game.get_viewport().disable_3d = false
	game.crosshair.show()
	game.get_viewport().gui_release_focus()
