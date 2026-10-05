"""Bakes the source clips onto the target armature: plays each clip on the source rig,
turns every frame into target pose values (anim_retarget.py) and writes them as
keyframes in a new action with exactly the same name as the source clip.
"""
import bpy

from anim_retarget import MOVERS

LINEAR = 1  # Keyframe.interpolation value for "LINEAR"


def reset_pose(arm) -> None:
    """Puts every bone of an armature back to its rest pose, using quaternions."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def clear_animation(arm) -> None:
    """Removes the active action and all NLA tracks, so only one clip plays at a time."""
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for track in list(ad.nla_tracks):
        ad.nla_tracks.remove(track)


def play(arm, action) -> None:
    """Plays one clip. Bones the clip does not move go back to rest, not the last clip's pose."""
    reset_pose(arm)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = action
    if ad.action_slot is None and len(action.slots):
        ad.action_slot = action.slots[0]


def bake_clips(scene, src, tgt, retarget, clips: list) -> list:
    """Bakes every source action in `clips`. Returns the names of the new target actions."""
    clear_animation(src)
    clear_animation(tgt)
    reset_pose(tgt)
    names = []
    for action in clips:
        name = action.name
        action.name = "src:" + name  # frees the name for the baked action
        frames, start = _sample_clip(scene, src, retarget, action)
        write_action(tgt, name, start, frames)
        names.append(name)
        print("baked %-36s frames %d..%d" % (name, start, start + len(frames) - 1))
    clear_animation(src)
    return names


def _sample_clip(scene, src, retarget, action):
    play(src, action)
    start, end = (int(round(v)) for v in action.frame_range)
    frames = []
    for f in range(start, end + 1):
        scene.frame_set(f)
        evaluated = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
        frames.append(retarget.solve(retarget.sample(evaluated.pose.bones)))
    return frames, start


def write_action(rig, name: str, start: int, frames: list):
    """Writes one key per frame for every bone (rotation; location for Root and pelvis)."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    play(rig, action)
    xs = [float(start + i) for i in range(len(frames))]
    for pb in rig.pose.bones:
        bone = pb.name
        quats, prev = [], None
        for frame in frames:
            q = frame[bone][1].copy()
            if prev is not None and prev.dot(q) < 0.0:
                q.negate()  # same turn, but keeps the curve from flipping sign
            quats.append(q)
            prev = q
        path = 'pose.bones["%s"].' % bone
        for i in range(4):
            _curve(action, rig, path + "rotation_quaternion", i, bone, xs, [q[i] for q in quats])
        if bone in MOVERS:
            for i in range(3):
                _curve(action, rig, path + "location", i, bone, xs, [f[bone][0][i] for f in frames])
    rig.animation_data.action = None
    return action


def _curve(action, rig, path: str, index: int, group: str, xs: list, ys: list) -> None:
    fc = action.fcurve_ensure_for_datablock(rig, path, index=index, group_name=group)
    fc.keyframe_points.add(len(xs))
    fc.keyframe_points.foreach_set("co", [v for pair in zip(xs, ys) for v in pair])
    fc.keyframe_points.foreach_set("interpolation", [LINEAR] * len(xs))
    fc.update()
