extends RefCounted
## Moving parts of the gun in your hands: the magazine and the left hand through a reload,
## the shotgun pump, the sniper bolt, the pistol slide and the revolver cylinder.
## Also the bump() timing curve the other viewmodel scripts use.

const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")

var vm: Viewmodel
var last_reload_t := -1.0
var mag_dropped := false


func _init(viewmodel: Viewmodel) -> void:
	vm = viewmodel


## Left hand and magazine through a reload, as a share t (0..1) of the reload time:
## grab the magazine, pull it out and drop it, fetch a new one, push it in, pull the
## charging handle, hand back on the handguard.
func animate_reload(t: float) -> void:
	var gun: Dictionary = vm.guns[vm.gun_id]
	var mag: MeshInstance3D = gun["parts"].get("magazine")
	if t < 0.0 or mag == null:
		if last_reload_t >= 0.0:
			reset_magazine()
		last_reload_t = t
		return
	if last_reload_t < 0.0 or t < last_reload_t:
		mag_dropped = false
	last_reload_t = t
	var mag_rest: Vector3 = (gun["rests"]["magazine"] as Transform3D).origin
	var down := Vector3(0, -1, 0)
	var out := 0.0  # how far the magazine has moved down, model units
	if t < 0.12:
		out = 0.0
	elif t < 0.3:
		out = 0.7 * _smooth((t - 0.12) / 0.18)
	elif t < 0.5:
		out = 3.5  # out of view: hand went to fetch a new one
	elif t < 0.62:
		out = lerpf(3.5, 0.8, _smooth((t - 0.5) / 0.12))
	elif t < 0.72:
		out = lerpf(0.8, 0.0, _smooth((t - 0.62) / 0.1))
	if t >= 0.3 and not mag_dropped:
		mag_dropped = true
		vm.effects.drop_magazine(mag)
	mag.visible = t < 0.3 or t >= 0.5
	mag.position = mag_rest + down * out


## Where the left hand holds the gun (gun model space) at reload share t.
func left_hand_local(t: float) -> Vector3:
	var s: Dictionary = vm.guns[vm.gun_id]["sockets"]
	var rest: Vector3 = s["hand"].position
	if vm.cycle_t >= 0.0 and vm.guns[vm.gun_id]["parts"].has("pump"):
		return rest + _pump_offset()  # the hand rides the pump
	if t < 0.0:
		return rest
	if vm.reload_style == "shells" or not s.has("magwell"):
		# Fetch a round from below and push it into the ejection port.
		var port: Vector3 = s["eject"].position + Vector3(0, -0.15, 0)
		var below := port + Vector3(-0.3, -1.4, 0)
		if t < 0.35:
			return rest.lerp(below, _smooth(t / 0.35))
		if t < 0.7:
			return below.lerp(port, _smooth((t - 0.35) / 0.35))
		return port.lerp(rest, _smooth((t - 0.7) / 0.3))
	var well: Vector3 = s["magwell"].position
	var charge: Vector3 = s["charge"].position
	var down := Vector3(0, -1, 0)
	if t < 0.12:
		return rest.lerp(well, _smooth(t / 0.12))
	if t < 0.3:
		return well + down * 0.7 * _smooth((t - 0.12) / 0.18)
	if t < 0.5:
		return (well + down * 0.7).lerp(well + down * 3.5, _smooth((t - 0.3) / 0.2))
	if t < 0.62:
		return well + down * lerpf(3.5, 0.8, _smooth((t - 0.5) / 0.12))
	if t < 0.72:
		return well + down * lerpf(0.8, 0.0, _smooth((t - 0.62) / 0.1))
	if t < 0.8:
		return well.lerp(charge, _smooth((t - 0.72) / 0.08))
	if t < 0.86:
		return charge + Vector3(-0.5, 0, 0) * bump(t, 0.8, 0.83, 0.83, 0.86)
	return charge.lerp(rest, _smooth((t - 0.86) / 0.14))


## Every moving part back in place and showing.
func reset_magazine() -> void:
	if vm.gun_id == "":
		return
	var gun: Dictionary = vm.guns[vm.gun_id]
	for part in gun["parts"]:
		if part != "scope":
			gun["parts"][part].transform = gun["rests"][part]
			gun["parts"][part].visible = true
	last_reload_t = -1.0
	mag_dropped = false


## Pump slides back and forward on the shotgun's action.
func _pump_offset() -> Vector3:
	return Vector3(-0.75, 0, 0) * bump(vm.cycle_t, 0.05, 0.35, 0.45, 0.85)


## Moving parts other than the magazine: pistol slide, pump, bolt, revolver cylinder.
func animate_parts(reload_t: float) -> void:
	var gun: Dictionary = vm.guns[vm.gun_id]
	var parts: Dictionary = gun["parts"]
	var rests: Dictionary = gun["rests"]
	var cycle_t := vm.cycle_t
	if parts.has("slide"):
		parts["slide"].transform = Transform3D(rests["slide"].basis, rests["slide"].origin + Vector3(-0.35 * vm.slide_back, 0, 0))
	if parts.has("pump"):
		parts["pump"].transform = Transform3D(rests["pump"].basis, rests["pump"].origin + (_pump_offset() if cycle_t >= 0.0 else Vector3.ZERO))
	if parts.has("bolt"):
		# Lift the handle, pull it back, push it home, turn it down.
		var lift := bump(cycle_t, 0.0, 0.18, 0.72, 0.9) if cycle_t >= 0.0 else 0.0
		var pull := bump(cycle_t, 0.18, 0.4, 0.5, 0.72) if cycle_t >= 0.0 else 0.0
		var axis_at := Vector3(0, gun["sockets"]["muzzle"].position.y, 0)  # the bore line
		var turn := Transform3D(Basis(Vector3.RIGHT, -lift * 1.1), Vector3.ZERO)
		var around := Transform3D(Basis(), axis_at) * turn * Transform3D(Basis(), -axis_at)
		parts["bolt"].transform = Transform3D(Basis(), Vector3(-0.7 * pull, 0, 0)) * around * rests["bolt"]
	if parts.has("cylinder"):
		# Swing out to the left around the crane, hold while loading, swing back in.
		var swing := bump(reload_t, 0.08, 0.22, 0.78, 0.9) if vm.reload_style == "revolver" and reload_t >= 0.0 else 0.0
		var pivot: Vector3 = gun["sockets"]["cylinder_pivot"].position if gun["sockets"].has("cylinder_pivot") else rests["cylinder"].origin
		var around := Transform3D(Basis(), pivot) * Transform3D(Basis(Vector3.RIGHT, -swing * 1.4), Vector3.ZERO) * Transform3D(Basis(), -pivot)
		parts["cylinder"].transform = around * rests["cylinder"]


## 0 before a, rising to 1 by b, holding until c, back to 0 by d.
static func bump(t: float, a: float, b: float, c: float, d: float) -> float:
	if t <= a or t >= d:
		return 0.0
	if t < b:
		return _smooth((t - a) / (b - a))
	if t <= c:
		return 1.0
	return 1.0 - _smooth((t - c) / (d - c))


static func _smooth(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))
