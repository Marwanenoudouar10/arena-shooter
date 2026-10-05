"""Hand shapes for the emotes (fist, thumbs up, flat salute hand, open wave hand ...).

Every finger bone bends around its own X axis (+ = curl toward the palm) and spreads
around its Z axis. In the rest pose the fingers are already bent about 20 degrees at the
knuckle, so a straight finger needs about -18 on _01. Values are written for the RIGHT hand, in degrees, as
    finger: (bend of _01, bend of _02, bend of _03, spread of _01)   spread + = toward pinky
    thumb:  ((x, y, z) Euler of thumb_01, bend of thumb_02, bend of thumb_03)
The left hand gets the mirror image: x stays, y and z change sign.
"""
import math

from mathutils import Euler

FINGERS = ("index", "middle", "ring", "pinky")


def _same(b1, b2, b3, spreads=(-4, 0, 3, 7)) -> dict:
    """All four fingers bent the same, with a small fan."""
    return {f: (b1, b2, b3, s) for f, s in zip(FINGERS, spreads)}


SHAPES = {
    # loose, natural hand (between poses)
    "relaxed": {**_same(2, 20, 10), "thumb": ((10, 0, -8), 10, 10)},
    # open hand with fingers a bit apart (wave, cheer start)
    "open": {**_same(-16, 4, 2, (-8, 0, 6, 13)), "thumb": ((-6, 0, 12), 0, 2)},
    # flat hand, fingers together (salute, clap)
    "flat": {**_same(-18, 2, 1, (3, 0, -3, -5)), "thumb": ((-12, 0, 28), 0, 0)},
    # palm up, soft fingers (shrug)
    "soft": {**_same(-6, 14, 8, (-6, 0, 5, 10)), "thumb": ((-4, 0, 8), 4, 6)},
    # tight fist, thumb wrapped over the index and middle fingers
    "fist": {**_same(72, 98, 62, (-2, 0, 2, 4)), "thumb": ((52, 0, 12), 22, 28)},
    # fist with the thumb sticking straight out
    "thumb_up": {**_same(72, 98, 62, (-2, 0, 2, 4)), "thumb": ((-18, 10, 30), -4, -8)},
    # loose fist (dance)
    "loose_fist": {**_same(48, 76, 46, (-3, 0, 3, 6)), "thumb": ((36, 0, 8), 16, 20)},
    # hand resting on the belly
    "rest": {**_same(-4, 20, 12, (-5, 0, 4, 9)), "thumb": ((-10, 0, 8), 6, 8)},
}


def _local(x: float, y: float, z: float, side: str):
    if side == "l":
        y, z = -y, -z
    # "XYZ": the bend (X) happens first, then the spread (Z)
    return Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_quaternion()


def apply_shape(pose, side: str, shape) -> None:
    """Sets the finger bones of one hand to a shape (name from SHAPES, or a dict)."""
    data = SHAPES[shape] if isinstance(shape, str) else shape
    for finger in FINGERS:
        b1, b2, b3, spread = data[finger]
        pose.quat["%s_01_%s" % (finger, side)] = _local(b1, 0.0, spread, side)
        pose.quat["%s_02_%s" % (finger, side)] = _local(b2, 0.0, 0.0, side)
        pose.quat["%s_03_%s" % (finger, side)] = _local(b3, 0.0, 0.0, side)
    (x, y, z), t2, t3 = data["thumb"]
    pose.quat["thumb_01_" + side] = _local(x, y, z, side)
    pose.quat["thumb_02_" + side] = _local(t2, 0.0, 0.0, side)
    pose.quat["thumb_03_" + side] = _local(t3, 0.0, 0.0, side)
    pose.fk()

