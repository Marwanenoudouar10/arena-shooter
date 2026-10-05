extends Node
## The gun in your hands: magazine, reloading (whole mag, shell by shell, or revolver),
## fire modes (auto, semi, pump, bolt), aiming down sights and recoil.

const Guns := preload("res://scripts/data/guns.gd")

const ADS_TIME := 0.12  # seconds to raise the sights to your eye
const RECOIL_SIDE := 0.43  # random sideways kick, as a share of the gun's upward kick
const RECOIL_GROWTH := 0.05  # each shot in a burst kicks 5% harder, up to 10 shots
const BURST_RESET := 0.25  # seconds without firing before the kick resets

var game: Node3D
var ammo := 30
var ads := 0.0  # 0 = hip, 1 = aiming down sights
var reload_left := 0.0  # > 0 while reloading
var fire_cooldown := 0.0
var burst := 0  # shots in the current burst, recoil grows with it
var since_shot := 0.0
var recoil_pending := Vector2.ZERO  # degrees still to apply: x = right, y = up
var trigger_was_down := false  # single-shot guns fire once per click
var cycle_left := 0.0  # > 0 while a pump or bolt is being worked
var reload_sound_t := -1.0  # last reload progress a sound was checked at


func data() -> Dictionary:
	return Guns.GUNS[game.gun_name]


## Full magazine, nothing in progress (new round or new gun).
func reset() -> void:
	ammo = data()["mag"]
	reload_left = 0.0
	cycle_left = 0.0
	trigger_was_down = false
	fire_cooldown = 0.0
	burst = 0
	since_shot = 0.0
	recoil_pending = Vector2.ZERO


func reloading() -> bool:
	return reload_left > 0.0


## Reload progress 0..1, or -1 when not reloading.
func reload_t() -> float:
	return 1.0 - reload_left / data()["reload"] if reload_left > 0.0 else -1.0


## Pump / bolt progress 0..1, or -1 when not working the action.
func cycle_t() -> float:
	return 1.0 - cycle_left * data()["fire_rate"] if cycle_left > 0.0 else -1.0


## Hold right click to aim (not while reloading, sprinting or climbing).
func update_ads(dt: float, want: bool) -> void:
	ads = move_toward(ads, 1.0 if want and reload_left <= 0.0 else 0.0, dt / ADS_TIME)


func update(dt: float, firing: bool) -> void:
	var gun := data()
	var pressed := firing and not trigger_was_down
	trigger_was_down = firing
	since_shot += dt
	if since_shot > BURST_RESET:
		burst = 0
	cycle_left = maxf(cycle_left - dt, 0.0)
	_reload_sounds()
	if pressed and ammo == 0 and reload_left <= 0.0:
		game.sfx.play("mag_in", -8.0, 1.8)  # dry click
	if reload_left > 0.0:
		if gun["reload_style"] == "shells" and pressed and ammo > 0:
			reload_left = 0.0  # stop loading and shoot
		else:
			reload_left -= dt
			if reload_left <= 0.0:
				if gun["reload_style"] == "shells":
					ammo += 1  # one round in; keep going until full
					if ammo < gun["mag"]:
						reload_left = gun["reload"]
				else:
					ammo = gun["mag"]
			return
	fire_cooldown -= dt
	if gun["mode"] == "auto":
		if not firing:
			fire_cooldown = maxf(fire_cooldown, 0.0)
			return
		# Loop so the fire rate holds even when a frame is longer than one shot.
		while fire_cooldown <= 0.0 and ammo > 0:
			game.shooting.fire()
			fire_cooldown += 1.0 / gun["fire_rate"]
	else:
		fire_cooldown = maxf(fire_cooldown, 0.0)
		if pressed and fire_cooldown <= 0.0 and cycle_left <= 0.0 and ammo > 0:
			game.shooting.fire()
			fire_cooldown = 1.0 / gun["fire_rate"]
			if gun["mode"] in ["pump", "bolt"]:
				cycle_left = 1.0 / gun["fire_rate"]
				# Rack the pump / work the bolt, and the empty shell flies out.
				game.sfx.play_later("pump", cycle_left * 0.12, -2.0, 1.0 if gun["mode"] == "pump" else 1.3)
				game.sfx.play_later("casing", cycle_left * 0.5, -16.0)
	if ammo == 0 and cycle_left <= 0.0:
		start_reload()


func start_reload() -> void:
	if reload_left <= 0.0 and ammo < data()["mag"] and cycle_left <= 0.0:
		reload_left = data()["reload"]


## One shot's kick: up, a little sideways, harder deeper into a burst.
func kick() -> void:
	burst += 1
	since_shot = 0.0
	var growth := 1.0 + RECOIL_GROWTH * mini(burst, 10)
	var amount: float = data()["recoil"] * growth * lerpf(1.0, 0.8, ads)  # aiming softens the kick a little
	recoil_pending += Vector2(randf_range(-RECOIL_SIDE, RECOIL_SIDE) * amount, amount)


## Spread each kick over a few frames so the camera climbs instead of jumping.
func apply_recoil(dt: float) -> void:
	if recoil_pending.length_squared() < 0.000001:
		return
	var step := recoil_pending * minf(1.0, dt * 30.0)
	recoil_pending -= step
	var player: Node = game.player
	player.yaw -= deg_to_rad(step.x)
	player.pitch = clampf(player.pitch + deg_to_rad(step.y), deg_to_rad(-89.0), deg_to_rad(89.0))
	player.look()


## Reload sounds land on the moments the hands do them (see the viewmodel's timings).
func _reload_sounds() -> void:
	if reload_left <= 0.0:
		reload_sound_t = -1.0
		return
	var gun := data()
	var t: float = 1.0 - reload_left / gun["reload"]
	if t < reload_sound_t:
		reload_sound_t = -1.0  # the next round of a shell-by-shell load
	var cues: Array = []
	match gun["reload_style"]:
		"mag":
			cues = [[0.15, "mag_out", -2.0, 0.85], [0.62, "mag_in", 0.0, 1.0], [0.8, "pump", -6.0, 1.5]]
		"revolver":
			cues = [[0.12, "mag_out", -2.0, 0.7], [0.35, "round_in", -4.0, 1.0], [0.45, "round_in", -4.0, 1.1],
					[0.55, "round_in", -4.0, 0.95], [0.86, "mag_in", 0.0, 0.8]]
		"shells":
			cues = [[0.55, "shell_in" if gun["mode"] == "pump" else "round_in", -2.0, 1.0]]
	for cue in cues:
		if reload_sound_t < cue[0] and t >= cue[0]:
			game.sfx.play(cue[1], cue[2], cue[3])
	reload_sound_t = t
