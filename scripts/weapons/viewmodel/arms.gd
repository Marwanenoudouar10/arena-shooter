extends RefCounted
## Your arms in first person. They are your class character's own (same model as the
## menu), standing under the camera facing forward; only the arms reach up into view.
## Bones are bent each frame so the hands land on the gun (two-bone IK), the forearm
## turns the palm the right way and the fingers curl around the grip.

const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")
const Anim := preload("res://scripts/weapons/viewmodel/gun_animation.gd")
const Rig := preload("res://scripts/enemies/rig.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")

# Bones are only ever rotated (scaling one would also scale everything below it, hands
# included), so the body sits close enough for natural-length arms to reach the gun.
const BODY_SCALE := 1.15
const BODY_OFFSET := Vector3(0.0, -1.92, -0.0165)  # shoulders 30 cm under and 12 cm ahead of the eye
const COLLAPSE := [Rig.HEAD, Rig.NECK]  # shrunk away: never in view
const HIDE_SLOTS := ["Head", "Legs", "Feet"]  # character kit slots not needed in first person

var vm: Viewmodel


func _init(viewmodel: Viewmodel) -> void:
	vm = viewmodel


## Stands one class character under the camera (the viewmodel's parent): {root, skeleton, ids}.
func build_body(root: Node3D) -> Dictionary:
	root.rotation_degrees = Vector3(0, 180, 0)  # the model faces +Z, the camera looks -Z
	root.scale = Vector3.ONE * BODY_SCALE
	root.position = BODY_OFFSET
	vm.get_parent().add_child(root)
	root.set_meta("no_shadows", true)  # clothes put on later keep this too
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skeleton: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	for slot in HIDE_SLOTS:
		var holder := skeleton.get_node_or_null(NodePath(Kit.NODE_PREFIX + slot)) as Node3D
		if holder:
			holder.hide()
	var ids := {}
	for i in skeleton.get_bone_count():
		ids[skeleton.get_bone_name(i)] = i
	root.hide()
	return {"root": root, "skeleton": skeleton, "ids": ids}


## Bends the arms so the hands sit on the gun (or on a ledge while climbing).
## Each hand gets a wanted frame in camera space: palm point, finger direction (wrist ->
## knuckles) and palm normal.
func update() -> void:
	var body: Dictionary = vm.body
	if body.is_empty():
		return
	var cam := vm.get_parent() as Node3D
	var gun: Dictionary = vm.guns[vm.gun_id]
	var s: Dictionary = gun["sockets"]
	var root: Node3D = gun["node"]
	var to_cam := cam.global_basis.inverse()
	var gun_fwd: Vector3 = (to_cam * root.global_basis * Vector3.RIGHT).normalized()  # model +X = muzzle
	var gun_up: Vector3 = (to_cam * root.global_basis * Vector3.UP).normalized()
	var gun_right: Vector3 = (to_cam * root.global_basis * Vector3.BACK).normalized()  # model +Z = right side
	var bolt_hand := 0.0
	if vm.cycle_t >= 0.0 and gun["parts"].has("bolt"):
		bolt_hand = Anim.bump(vm.cycle_t, 0.0, 0.12, 0.8, 0.95)
	var right_palm: Vector3 = cam.to_local(root.to_global(s["grip"].position)) + gun_right * 0.02
	if bolt_hand > 0.0:  # the right hand leaves the grip to work the bolt
		var bolt: Node3D = gun["parts"]["bolt"]
		right_palm = right_palm.lerp(cam.to_local(bolt.get_parent().to_global(bolt.transform * (gun["rests"]["bolt"] as Transform3D).affine_inverse() * s["charge"].position)), bolt_hand)
	var right := {
		"palm": right_palm,
		"fingers": (gun_fwd - gun_up * 0.35).normalized(),  # knuckles at the front of the grip
		"normal": -gun_right,  # palm against the grip's right side
	}
	var left := {
		"palm": cam.to_local(root.to_global(vm.anim.left_hand_local(vm.anim.last_reload_t))) - gun_up * 0.015,
		"fingers": (gun_right + gun_fwd * 0.3).normalized(),  # fingers wrap up the far side
		"normal": gun_up,  # palm up under the handguard
	}
	var grip := 1.0
	if vm.climb > 0.0:  # let go of the gun and plant both hands flat on the ledge
		var grab := smoothstep(0.0, 0.6, vm.climb)
		right["palm"] = (right["palm"] as Vector3).lerp(vm.ledge + Vector3(0.2, 0.03, 0.0), grab)
		left["palm"] = (left["palm"] as Vector3).lerp(vm.ledge + Vector3(-0.2, 0.03, 0.0), grab)
		right["fingers"] = (right["fingers"] as Vector3).lerp(Vector3.FORWARD, grab).normalized()
		left["fingers"] = (left["fingers"] as Vector3).lerp(Vector3.FORWARD, grab).normalized()
		right["normal"] = (right["normal"] as Vector3).lerp(Vector3.DOWN, grab).normalized()
		left["normal"] = (left["normal"] as Vector3).lerp(Vector3.DOWN, grab).normalized()
		grip = 1.0 - grab * 0.8
	var skeleton: Skeleton3D = body["skeleton"]
	skeleton.reset_bone_poses()
	for bone in COLLAPSE:
		if body["ids"].has(bone):
			skeleton.set_bone_pose_scale(body["ids"][bone], Vector3.ONE * 0.001)
	skeleton.force_update_all_bone_transforms()
	var cam_to_skeleton := skeleton.global_transform.affine_inverse() * cam.global_transform
	vm.debug_targets = {"R": right["palm"], "L": left["palm"]}
	_reach(skeleton, "R", right, cam_to_skeleton, Vector3(1, -1, 0.4), grip)
	_reach(skeleton, "L", left, cam_to_skeleton, Vector3(-1, -1.2, 0.4), grip)


## One arm, in skeleton space: place the wrist so the palm lands on the target, two-bone IK
## for upper arm and forearm, turn the wrist to the wanted hand frame, curl the fingers.
func _reach(skeleton: Skeleton3D, side: String, hand: Dictionary, cam_to_skeleton: Transform3D, pole_cam: Vector3, grip: float) -> void:
	var ids: Dictionary = vm.body["ids"]
	var upper: int = ids[Rig.upper_arm(side)]
	var lower: int = ids[Rig.lower_arm(side)]
	var wrist: int = ids[Rig.hand(side)]
	var upper_rest := skeleton.get_bone_global_rest(upper)
	var lower_rest := skeleton.get_bone_global_rest(lower)
	var wrist_rest := skeleton.get_bone_global_rest(wrist)
	var knuckle_rest := skeleton.get_bone_global_rest(ids[Rig.knuckle(1, side)]).origin
	var index_rest := skeleton.get_bone_global_rest(ids[Rig.knuckle(0, side)]).origin
	var pinky_rest := skeleton.get_bone_global_rest(ids[Rig.knuckle(3, side)]).origin
	# Wanted hand frame in skeleton space.
	var fingers: Vector3 = (cam_to_skeleton.basis * hand["fingers"]).normalized()
	var normal: Vector3 = (cam_to_skeleton.basis * hand["normal"]).normalized()
	normal = (normal - fingers * normal.dot(fingers)).normalized()
	var palm: Vector3 = cam_to_skeleton * (hand["palm"] as Vector3)
	var palm_len := wrist_rest.origin.distance_to(knuckle_rest) * 0.55
	var target := palm - fingers * palm_len
	# Two-bone IK to the wrist.
	var shoulder := upper_rest.origin
	var to_target := target - shoulder
	var len_upper := shoulder.distance_to(lower_rest.origin)
	var len_lower := lower_rest.origin.distance_to(wrist_rest.origin)
	# Skeleton space is not in metres (this rig is scaled 100x), so limits are relative.
	var reach := clampf(to_target.length(), (len_upper + len_lower) * 0.05, (len_upper + len_lower) * 0.9999)
	var dir := to_target.normalized()
	var cos_a := (len_upper * len_upper + reach * reach - len_lower * len_lower) / (2.0 * len_upper * reach)
	var pole := (cam_to_skeleton.basis * pole_cam).normalized()
	var bend := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + (dir * cos_a + bend * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))) * len_upper
	var wrist_at := shoulder + dir * reach
	var upper_dir := (elbow - shoulder).normalized()
	var upper_turn := Quaternion((lower_rest.origin - shoulder).normalized(), upper_dir)
	_set_global(skeleton, upper, Transform3D(Basis(upper_turn) * upper_rest.basis, shoulder))
	var fore_dir := (wrist_at - elbow).normalized()
	var fore_turn := Quaternion((wrist_rest.origin - lower_rest.origin).normalized(), fore_dir)
	_set_global(skeleton, lower, Transform3D(Basis(fore_turn) * lower_rest.basis, elbow))
	# Wrist: rotate the rest hand frame onto the wanted one. Frames are (fingers, knuckle
	# line pinky -> index, palm normal); right and left hands are mirror images.
	var f_rest := (knuckle_rest - wrist_rest.origin).normalized()
	var k_rest := index_rest - pinky_rest
	k_rest = (k_rest - f_rest * k_rest.dot(f_rest)).normalized()
	var n_rest := k_rest.cross(f_rest) if side == "R" else f_rest.cross(k_rest)
	var knuckles := normal.cross(fingers) if side == "R" else fingers.cross(normal)
	var rest_frame := Basis(f_rest, k_rest, n_rest)
	var want_frame := Basis(fingers, knuckles, normal)
	var turn := want_frame * rest_frame.inverse()
	_set_global(skeleton, wrist, Transform3D(turn * wrist_rest.basis, wrist_at))
	# Fingers curl toward the palm around the knuckle line (the frames above are built so
	# that is a positive turn for both hands).
	var curl_sign := 1.0
	for finger in Rig.FINGERS.size():
		var chain: Array = Rig.FINGERS[finger]
		var thumb: bool = finger == Rig.THUMB
		var axis := fingers if thumb else knuckles
		for joint in chain:
			var id: int = ids.get(Rig.finger_bone(joint, side), -1)
			if id < 0:
				continue
			var pose := skeleton.get_bone_global_pose(id)
			pose.basis = Basis(axis, grip * (0.35 if thumb else 1.05) * curl_sign) * pose.basis
			_set_global(skeleton, id, pose)


## set_bone_global_pose works from the parent's cached pose; refresh the cache right away so
## the next joint down the arm is placed from where this one really ended up.
func _set_global(skeleton: Skeleton3D, bone: int, pose: Transform3D) -> void:
	skeleton.set_bone_global_pose(bone, pose)
	skeleton.force_update_all_bone_transforms()
