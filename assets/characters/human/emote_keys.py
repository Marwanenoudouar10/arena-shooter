"""Writes one emote clip as a Blender action: every bone gets a rotation key at each key
pose (pelvis and Root also get location keys), with smooth Bezier (auto clamped) curves.

Overlap: some bones (head, neck ...) can be keyed a few frames late, so they follow the
body instead of moving at the same moment. The first and last keys are never late, so a
clip still starts and ends exactly in the neutral pose. Looping clips get a Cycles
modifier on every curve: the curve wraps around smoothly and late keys wrap too.
"""
import bpy

from anim_keys import play
from emote_poses import build
from emote_rig import quat_close

MOVERS = ("Root", "pelvis")  # bones that also get location keys
DEFAULT_DELAYS = {"neck_01": 2, "head": 3}


def write_clip(arm, rig, clip: dict):
    """clip: {name, length, loop, keys: [(frame, pose spec)], delays (optional)}."""
    keys = clip["keys"]
    if keys[0][0] != 0 or keys[-1][0] != clip["length"]:
        raise ValueError(clip["name"] + ": keys must start at 0 and end at length")
    if clip["loop"] and keys[0][1] != keys[-1][1]:
        raise ValueError(clip["name"] + ": a loop must end on its first pose")
    poses = [(frame, build(rig, spec).values()) for frame, spec in keys]
    delays = dict(DEFAULT_DELAYS, **clip.get("delays", {}))
    action = bpy.data.actions.new(clip["name"])
    action.use_fake_user = True
    play(arm, action)
    for bone in rig.order:
        late = delays.get(bone, 0)
        frames = [f + (late if clip["loop"] or 0 < i < len(poses) - 1 else 0)
                  for i, (f, _) in enumerate(poses)]
        quats, prev = [], None
        for _, values in poses:
            q = values[bone][1] if prev is None else quat_close(values[bone][1], prev)
            quats.append(q)
            prev = q
        path = 'pose.bones["%s"].' % bone
        for i in range(4):
            _curve(action, arm, path + "rotation_quaternion", i, bone, frames,
                   [q[i] for q in quats], clip["loop"])
        if bone in MOVERS:
            for i in range(3):
                _curve(action, arm, path + "location", i, bone, frames,
                       [v[bone][0][i] for _, v in poses], clip["loop"])
    action.use_frame_range = True  # the clip is exactly 0..length, also with late keys
    action.frame_start, action.frame_end = 0, clip["length"]
    action.use_cyclic = clip["loop"]
    arm.animation_data.action = None
    return action


def _curve(action, arm, path: str, index: int, group: str, xs: list, ys: list,
           loop: bool) -> None:
    fc = action.fcurve_ensure_for_datablock(arm, path, index=index, group_name=group)
    for x, y in zip(xs, ys):
        key = fc.keyframe_points.insert(x, y, options={"FAST"})
        key.interpolation = "BEZIER"
        key.handle_left_type = key.handle_right_type = "AUTO_CLAMPED"
    if loop:
        fc.modifiers.new("CYCLES")  # handles are worked out around the wrap, too
    fc.update()
