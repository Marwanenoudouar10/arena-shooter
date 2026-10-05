extends RefCounted
## Puts a gun in a character's right hand: grip in the palm, barrel along the hand,
## following the hand through every animation (BoneAttachment3D on the wrist).
## Works out the hand's frame from the model's rest pose, so any character on the shared
## skeleton works (bone names in rig.gd). gun_scale = metres per gun model unit.

const Rig := preload("res://scripts/enemies/rig.gd")


static func attach(skeleton: Skeleton3D, gun: Node3D, grip: Vector3, gun_scale: float) -> BoneAttachment3D:
	var wrist := skeleton.find_bone(Rig.hand("R"))
	var at := BoneAttachment3D.new()
	at.bone_name = Rig.hand("R")
	skeleton.add_child(at)
	at.add_child(gun)
	var w := skeleton.get_bone_global_rest(wrist)
	var knuckle := skeleton.get_bone_global_rest(skeleton.find_bone(Rig.knuckle(1, "R"))).origin
	var index := skeleton.get_bone_global_rest(skeleton.find_bone(Rig.knuckle(0, "R"))).origin
	var pinky := skeleton.get_bone_global_rest(skeleton.find_bone(Rig.knuckle(3, "R"))).origin
	# Barrel along the back of the hand, grip running up the knuckle line toward the barrel.
	var forward := (knuckle - w.origin).normalized()
	var up := index - pinky
	up = (up - forward * up.dot(forward)).normalized()
	var right := forward.cross(up)
	var palm := w.origin + forward * w.origin.distance_to(knuckle) * 0.45
	var units := gun_scale / skeleton.global_basis.get_scale().x  # skeleton space is not metres
	var axes := Basis(forward, up, right).scaled(Vector3.ONE * units)
	var in_skeleton := Transform3D(axes, palm - axes * grip)
	gun.transform = w.affine_inverse() * in_skeleton
	return at
