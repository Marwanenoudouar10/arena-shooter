"""The neutral standing pose every emote starts and ends in: the first frame of the
"CharacterArmature|Idle" clip in human_anims.glb. That file has the same skeleton (same
bone names and rest pose) as human_blueprint.blend, so its local pose values fit HumanRig.
"""
import bpy
from mathutils import Quaternion, Vector

IDLE = "CharacterArmature|Idle"


def load_idle(glb_path: str, rig) -> dict:
    """Returns {bone: (location, quaternion)} local values of Idle's first frame.
    Imports the glb, reads the pose and removes everything it imported again."""
    old_objects, old_actions = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    new_objects = [o for o in bpy.data.objects if o not in old_objects]
    new_actions = [a for a in bpy.data.actions if a not in old_actions]
    src = next(o for o in new_objects if o.type == "ARMATURE")
    _check_same_rest(src, rig)
    action = next(a for a in new_actions if a.name == IDLE)
    ad = src.animation_data or src.animation_data_create()
    ad.action = action
    if ad.action_slot is None and len(action.slots):
        ad.action_slot = action.slots[0]
    bpy.context.scene.frame_set(int(round(action.frame_range[0])))
    bpy.context.view_layer.update()
    pose = {}
    for pb in src.pose.bones:
        loc, quat, _ = pb.matrix_basis.decompose()
        pose[pb.name] = (Vector(loc), Quaternion(quat).normalized())
    for obj in new_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in new_actions:
        bpy.data.actions.remove(action)
    return pose


def _check_same_rest(src, rig, tol: float = 1e-4) -> None:
    """Stops with an error when the glb's skeleton is not the blueprint's skeleton."""
    names = [b.name for b in rig.data.bones]
    if sorted(names) != sorted(b.name for b in src.data.bones):
        raise RuntimeError("human_anims.glb has other bones than HumanRig")
    for name in names:
        a = src.matrix_world @ src.data.bones[name].matrix_local
        b = rig.matrix_world @ rig.data.bones[name].matrix_local
        if any(abs(x - y) > tol for ra, rb in zip(a, b) for x, y in zip(ra, rb)):
            raise RuntimeError("rest pose differs for bone " + name)
