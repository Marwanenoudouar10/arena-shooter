## An enemy's body: the character model (built from the character kit), its animations
## and the gun in its right hand.

const Kit := preload("res://scripts/enemies/character_kit.gd")
const Glb := preload("res://scripts/core/glb.gd")
const Rig := preload("res://scripts/enemies/rig.gd")
const GUN_SCALE := 0.11  # gun model units -> metres, same as in first person


## {pivot, skeleton, anim, head, neck, wrist, meshes}. The pivot turns and scales the model.
static func load_model(look: Dictionary, parent: Node3D) -> Dictionary:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.add_child(Kit.build(look, Glb.scene))
	pivot.hide()
	var skeleton: Skeleton3D = pivot.find_children("*", "Skeleton3D", true, false)[0]
	var anim: AnimationPlayer = pivot.find_children("*", "AnimationPlayer", true, false)[0]
	var meshes: Array[MeshInstance3D] = []
	for node in pivot.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	# Animations from a runtime glTF load do not loop; make the movement ones loop.
	for anim_name in anim.get_animation_list():
		if not (anim_name.ends_with("Death") or anim_name.contains("Jump") or anim_name.ends_with("HitReact")):
			anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return {"pivot": pivot, "skeleton": skeleton, "anim": anim, "head": skeleton.find_bone(Rig.HEAD), "neck": skeleton.find_bone(Rig.NECK),
			"wrist": skeleton.find_bone(Rig.hand("R")), "meshes": meshes}


## The gun an enemy holds: {node, grip}. Its grip follows the right hand.
static func load_gun(path: String, parent: Node3D) -> Dictionary:
	var gun := Glb.scene(path)
	parent.add_child(gun)
	var grip := Vector3.ZERO
	for node in gun.find_children("*", "", true, false):
		if node.name == "socket_grip":
			grip = (node as Node3D).position
		elif node.name == "scope":
			(node as Node3D).hide()
	gun.hide()
	return {"node": gun, "grip": grip}


## Plays e.g. "Run_Shoot", falling back when a model lacks that clip.
static func play(model: Dictionary, clip: String) -> void:
	var anim: AnimationPlayer = model["anim"]
	var fallbacks := {"Run_Shoot": "Run_Gun", "Walk_Shoot": "Walk", "Jump_Idle": "Idle_Gun", "Idle_Shoot": "Idle_Gun_Shoot", "HitReact": "HitRecieve"}
	var tries := [clip, fallbacks.get(clip, "Idle_Gun"), "Idle"]
	for clip_name in tries:
		for full in ["CharacterArmature|" + clip_name, clip_name]:
			if anim.has_animation(full):
				if anim.current_animation != full:
					anim.play(full, 0.15)
				return


## Puts the gun in the right hand, barrel pointing at `aim_at`.
static func hold_gun(model: Dictionary, shown: bool, aim_at: Vector3, model_scale: float) -> void:
	var gun: Dictionary = model["gun"]
	var node: Node3D = gun["node"]
	node.visible = shown
	if not shown or model["wrist"] < 0:
		return
	var skeleton: Skeleton3D = model["skeleton"]
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(model["wrist"]).origin
	var aim := (aim_at - hand).normalized()  # model +X is the barrel
	var side := aim.cross(Vector3.UP).normalized()
	var axes := Basis(aim, side.cross(aim), side).scaled(Vector3.ONE * GUN_SCALE * model_scale)
	node.global_transform = Transform3D(axes, hand - axes * (gun["grip"] as Vector3))
