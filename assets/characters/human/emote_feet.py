"""Keeps the feet planted. Between two key poses Blender blends every bone on its own, so
when the hips move the feet would slide a little. This pass plays the clip, and on every
frame solves the legs again (IK) so each foot is exactly where the key poses say: on its
neutral spot, or lifted/moved by the clip's foot keys (blended smoothly). The leg bones
then get one key per frame.
"""
import bpy

from emote_poses import leg
from emote_rig import Pose, quat_close

LEG_BONES = ("thigh", "calf", "foot", "ball")


def smooth(keys: list, x: float) -> float:
    """Value at x of a smooth curve through (x, y) keys. Like Blender's auto clamped
    Bezier: flat at the first, last and every highest/lowest key, so nothing overshoots."""
    if x <= keys[0][0]:
        return keys[0][1]
    if x >= keys[-1][0]:
        return keys[-1][1]
    i = max(j for j in range(len(keys) - 1) if keys[j][0] <= x)
    (x0, y0), (x1, y1) = keys[i], keys[i + 1]
    m0, m1 = _slope(keys, i), _slope(keys, i + 1)
    h = x1 - x0
    t = (x - x0) / h
    return ((2 * t ** 3 - 3 * t ** 2 + 1) * y0 + (t ** 3 - 2 * t ** 2 + t) * h * m0
            + (-2 * t ** 3 + 3 * t ** 2) * y1 + (t ** 3 - t ** 2) * h * m1)


def _slope(keys: list, i: int) -> float:
    if i == 0 or i == len(keys) - 1:
        return 0.0
    (xa, ya), (_, y), (xb, yb) = keys[i - 1], keys[i], keys[i + 1]
    if (y - ya) * (yb - y) <= 0.0:
        return 0.0  # a peak, a dip or a hold
    return (yb - ya) / (xb - xa)


def foot_at(clip: dict, side: str, frame: float) -> dict:
    """The clip's foot spec for one side, blended at any frame."""
    specs = [(f, spec.get("foot_" + side) or {}) for f, spec in clip["keys"]]
    off = [smooth([(f, s.get("off", (0, 0, 0))[i]) for f, s in specs], frame) for i in range(3)]
    heel = smooth([(f, s.get("heel", 0.0)) for f, s in specs], frame)
    return {"off": tuple(off), "heel": heel}


def pin_feet(arm, rig, clip: dict, action) -> float:
    """Re-solves both legs on every frame and rewrites their keys. Returns how far the
    feet were sliding before (metres), for the log."""
    scene = bpy.context.scene
    ad = arm.animation_data
    ad.action = action
    if ad.action_slot is None and len(action.slots):
        ad.action_slot = action.slots[0]
    frames = range(0, clip["length"] + 1)
    solved, slide = {}, 0.0
    for f in frames:
        scene.frame_set(f)
        pose = Pose(rig)
        for pb in arm.pose.bones:
            loc, quat, _ = pb.matrix_basis.decompose()
            pose.loc[pb.name], pose.quat[pb.name] = loc, quat
        pose.fk()
        before = {s: pose.head("foot_" + s) for s in "lr"}
        for side in "lr":
            leg(pose, side, foot_at(clip, side, f))
            slide = max(slide, (before[side] - pose.head("foot_" + side)).length)
        solved[f] = {b + "_" + s: pose.quat[b + "_" + s].copy() for b in LEG_BONES for s in "lr"}
    _rewrite(action, arm, solved, clip["loop"])
    ad.action = None
    return slide


def _rewrite(action, arm, solved: dict, loop: bool) -> None:
    frames = sorted(solved)
    for bone in solved[frames[0]]:
        quats, prev = [], None
        for f in frames:
            q = solved[f][bone] if prev is None else quat_close(solved[f][bone], prev)
            quats.append(q)
            prev = q
        for i in range(4):
            fc = action.fcurve_ensure_for_datablock(
                arm, 'pose.bones["%s"].rotation_quaternion' % bone, index=i, group_name=bone)
            fc.keyframe_points.clear()
            fc.keyframe_points.add(len(frames))
            fc.keyframe_points.foreach_set("co", [v for f, q in zip(frames, quats)
                                                  for v in (float(f), q[i])])
            for key in fc.keyframe_points:
                key.interpolation = "BEZIER"
                key.handle_left_type = key.handle_right_type = "AUTO_CLAMPED"
            fc.update()
