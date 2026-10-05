"""Turns a short pose description (a dict) into a full skeleton pose. Anything the dict
does not mention stays as in the neutral pose. Keys (angles in degrees, metres, armature
space as seen in the neutral pose: he faces -Y, +X is his left, +Z up):

  hips=(dx, dy, dz)           move the pelvis
  hips_turn=(pitch, roll, yaw) turn the pelvis around the hip joints
  spine=(pitch, roll, yaw)    bend the back (spread over spine_01..03); chest= spine_03 only
  head=(pitch, roll, yaw)     neck and head together (pitch + = chin down)
  clav_l/clav_r=(up, fwd)     lift / push forward a shoulder
  foot_l/foot_r=dict(off=(dx, dy, dz), heel=deg)   feet stay planted unless given
  arm_l/arm_r=dict(at=(x, y, z) palm centre, palm=dir the palm faces,
                   point=dir the fingers point, elbow=dir the elbow points,
                   frame=bone the numbers move with (default spine_03))   or "hang"
  hand_l/hand_r=shape name from emote_hands.SHAPES (or a shape dict)
"""
from mathutils import Vector

from emote_hands import apply_shape
from emote_rig import Pose, basis, limb, rot3, turn_deg, twist_into_forearm

SPINE = (("spine_01", 0.3), ("spine_02", 0.3), ("spine_03", 0.4))
NECK_SHARE = 0.4      # part of the head turn done by the neck
FOREARM_TWIST = 0.6   # part of the hand twist done by the forearm
PALM_SKIN = 0.024     # palm skin, seen from the middle of the hand bone (metres)


def mirror(spec):
    """Left-side copy of a right-side arm or foot spec (x changes sign)."""
    if not isinstance(spec, dict):
        return spec
    out = dict(spec)
    for key in ("at", "palm", "point", "elbow", "off"):
        if key in out:
            x, y, z = out[key]
            out[key] = (-x, y, z)
    return out


def build(rig, spec: dict) -> Pose:
    pose = Pose(rig)
    if not spec:
        return pose  # exactly the neutral pose
    _hips(pose, spec)
    for bone, share in SPINE:
        _turn_in_parent(pose, bone, spec.get("spine"), share)
    _turn_in_parent(pose, "spine_03", spec.get("chest"), 1.0)
    _turn_in_parent(pose, "neck_01", spec.get("head"), NECK_SHARE)
    _turn_in_parent(pose, "head", spec.get("head"), 1.0 - NECK_SHARE)
    for side in "lr":
        _clavicle(pose, side, spec.get("clav_" + side))
        leg(pose, side, spec.get("foot_" + side) or {})
        _arm(pose, side, spec.get("arm_" + side))
        if spec.get("hand_" + side):
            apply_shape(pose, side, spec["hand_" + side])
    return pose


def _hips(pose: Pose, spec: dict) -> None:
    head = pose.head("pelvis")
    if "hips_turn" in spec:
        r = turn_deg(*spec["hips_turn"])
        pivot = (pose.head("thigh_l") + pose.head("thigh_r")) * 0.5
        pose.turn("pelvis", r)
        head = pivot + r @ (head - pivot)
    pose.set_head("pelvis", head + Vector(spec.get("hips", (0, 0, 0))))


def _turn_in_parent(pose: Pose, bone: str, angles, share: float) -> None:
    """Turns a bone by a share of (pitch, roll, yaw), measured in its parent's frame."""
    if not angles:
        return
    frame = rot3(pose.delta(pose.rig.parent[bone]))
    r = turn_deg(*(a * share for a in angles))
    pose.turn(bone, frame @ r @ frame.inverted())


def _clavicle(pose: Pose, side: str, up_fwd) -> None:
    if not up_fwd:
        return
    sign = 1.0 if side == "r" else -1.0
    up, fwd = up_fwd
    _turn_in_parent(pose, "clavicle_" + side, (0.0, up * sign, fwd * sign), 1.0)


def leg(pose: Pose, side: str, foot: dict) -> None:
    """Keeps the foot on its neutral spot (plus off), flat or with the heel lifted."""
    base = pose.rig.base
    rx = turn_deg(foot.get("heel", 0.0))  # heel up = the foot turns around its ball
    ball, ankle = base.head("ball_" + side), base.head("foot_" + side)
    off = Vector(foot.get("off", (0, 0, 0)))
    target = ball + rx @ (ankle - ball) + off
    pole = rot3(pose.delta("pelvis")) @ pose.rig.chains["leg_" + side]["pole"]
    if foot.get("knee"):
        pole = Vector(foot["knee"])
    limb(pose, "leg_" + side, target, pole)
    pose.set_rot("foot_" + side, rx @ base.rot("foot_" + side))
    pose.set_rot("ball_" + side, base.rot("ball_" + side))


def hand_frame(rig, side: str):
    """Finger direction, palm direction and palm centre, in the hand bone's own space."""
    r = rig.rest
    wrist = r["hand_" + side].translation
    knuckle = r["middle_01_" + side].translation
    f = (knuckle - wrist).normalized()
    across = r["pinky_01_" + side].translation - r["index_01_" + side].translation
    n = f.cross(across) if side == "r" else across.cross(f)
    n = (n - f * n.dot(f)).normalized()
    inv = r["hand_" + side].inverted()
    centre = wrist + (knuckle - wrist) * 0.55 + n * PALM_SKIN
    return rot3(inv) @ f, rot3(inv) @ n, inv @ centre


def _arm(pose: Pose, side: str, arm) -> None:
    if not arm:
        return
    upper, lower, hand = "upperarm_" + side, "lowerarm_" + side, "hand_" + side
    if arm == "hang":  # upper arm and forearm keep their neutral direction (gravity)
        base = pose.rig.base
        pose.set_rot(upper, base.rot(upper))
        pose.set_rot(lower, base.rot(lower))
        return
    frame = pose.delta(arm.get("frame", "spine_03"))
    at = frame @ Vector(arm["at"])
    pole = rot3(pose.delta("spine_03")) @ pose.rig.chains["arm_" + side]["pole"]
    if "elbow" in arm:
        pole = rot3(frame) @ Vector(arm["elbow"])
    want = None
    if "palm" in arm and "point" in arm:
        f_loc, n_loc, centre = hand_frame(pose.rig, side)
        f, n = rot3(frame) @ Vector(arm["point"]), rot3(frame) @ Vector(arm["palm"])
        want = basis(f, n) @ basis(f_loc, n_loc).inverted()
        at = at - want @ centre  # the wrist sits back from the palm centre
    limb(pose, "arm_" + side, at, pole)
    if want is not None:
        twist_into_forearm(pose, lower, hand, want, arm.get("share", FOREARM_TWIST))


def merge(*parts, **more) -> dict:
    """One pose spec made of several (later ones win)."""
    out = {}
    for part in parts:
        out.update(part)
    out.update(more)
    return out


def both(arm_r: dict, hand=None) -> dict:
    """The same arm on both sides (the left one mirrored), with an optional hand shape."""
    out = {"arm_r": arm_r, "arm_l": mirror(arm_r)}
    if hand:
        out["hand_r"] = out["hand_l"] = hand
    return out
