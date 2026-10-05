"""Emote clips, part 1: Wave, Salute, Clap.

A clip is a dict: name, length (frames at 30 fps), loop, keys = [(frame, pose spec)],
optional delays {bone: frames late} for overlap, and shots = frames for the previews.
Pose specs are explained in emote_poses.py. {} is the neutral pose.
Points are metres in armature space as seen in the neutral pose (he faces -Y, +X is his
left). Handy spots: right shoulder (-0.20, -0.02, 1.46), chest front y -0.15 at z 1.3,
brow (0, -0.16, 1.75), belly front y -0.145 at z 1.1.
"""
from emote_poses import both, merge

N = {}  # neutral
# right arm swinging down at his side, nearly straight (in-between from a raised arm)
ARM_DOWN = {"at": (-0.47, -0.08, 1.03), "elbow": (-0.2, 1.0, 0.0), "palm": (0.9, 0.2, 0.0),
            "point": (-0.35, -0.15, -1.0)}

# ---- Wave: right hand up beside the head, palm forward, waving side to side --------------
WAVE_ELBOW = (-1.0, 0.15, -0.55)


def _wave(x: float, y: float, z: float, lean: float, tilt: float) -> dict:
    """Right hand up and open, fingers leaning `lean` (+ = toward his head)."""
    return {
        "arm_r": {"at": (x, y, z), "palm": (0.0, -1.0, 0.1), "point": (lean, -0.05, 1.0),
                  "elbow": WAVE_ELBOW},
        "hand_r": "open", "clav_r": (9, 2), "spine": (0, 3, 2), "head": (-3, tilt, 3),
    }


WAVE_IN = _wave(-0.35, -0.13, 1.72, 0.30, -6)
WAVE_OUT = _wave(-0.51, -0.10, 1.67, -0.35, -3)

WAVE = {
    "name": "Emote_Wave", "length": 75, "loop": False,
    "keys": [
        (0, N),
        (13, _wave(-0.40, -0.13, 1.70, 0.05, -5)),
        (21, WAVE_OUT), (29, WAVE_IN), (37, WAVE_OUT), (45, WAVE_IN),
        (53, _wave(-0.47, -0.11, 1.68, -0.20, -4)),
        (63, {"arm_r": {"at": (-0.42, -0.10, 1.22), "elbow": (-0.6, 0.7, -0.6)},
              "hand_r": "relaxed", "head": (-1, -2, 1), "spine": (0, 1, 1)}),
        (75, N),
    ],
    "delays": {"hand_r": 1},
    "shots": [13, 21, 29, 45, 63],
}

# ---- Salute: flat right hand to the brow, hold, snap down ------------------------------
SALUTE_HAND = {"at": (-0.165, -0.162, 1.695), "frame": "head", "palm": (0.0, 0.35, -1.0),
               "point": (0.9, -0.25, 0.35), "elbow": (-1.0, -0.45, 0.0)}
ATTENTION = {"chest": (-4, 0, 0), "head": (-3, 0, 0), "clav_l": (0, -4), "clav_r": (2, -2),
             "arm_l": {"at": (0.245, -0.03, 0.90), "elbow": (0.3, 1.0, 0.0),
                       "palm": (-1.0, 0.0, 0.0), "point": (0.0, -0.1, -1.0)},
             "hand_l": "flat"}


def _salute(dx: float = 0.0, dz: float = 0.0, head=(-3, 0, 0)) -> dict:
    x, y, z = SALUTE_HAND["at"]
    hand = dict(SALUTE_HAND, at=(x + dx, y, z + dz))
    return merge(ATTENTION, {"arm_r": hand, "hand_r": "flat", "head": head})


SALUTE = {
    "name": "Emote_Salute", "length": 75, "loop": False,
    "keys": [
        (0, N),
        (9, _salute(-0.012, 0.012)),   # a bit past the brow ...
        (12, _salute()),               # ... and settles
        (28, _salute(0.0, 0.003, (-4, 0, 0))),
        (44, _salute(0.0, -0.002, (-3, 0, 0))),
        (50, merge(ATTENTION, {"arm_r": {"at": (-0.38, -0.08, 1.30), "elbow": (-0.6, 0.6, -0.5),
                                         "palm": (0.8, 0.2, -0.5), "point": (-0.3, -0.4, -0.85)},
                               "hand_r": "flat"})),
        (58, merge(ATTENTION, {"arm_r": {"at": (-0.245, -0.03, 0.90), "elbow": (-0.3, 1.0, 0.0),
                                         "palm": (1.0, 0.0, 0.0), "point": (0.0, -0.1, -1.0)},
                               "hand_r": "flat"})),
        (75, N),
    ],
    "delays": {"hand_r": 1, "hand_l": 2},
    "shots": [9, 12, 30, 50, 58],
}

# ---- Clap: palms meet in front of the chest, three claps per loop ----------------------
def _clap(x: float, open_by: float, nod: float, dip: float) -> dict:
    """Both hands at +-x (palm centres); open_by turns the palms out a little."""
    hand = {"at": (-x, -0.36, 1.28), "palm": (1.0, -open_by, 0.05),
            "point": (0.12 - open_by * 0.3, -0.72, 0.68), "elbow": (-1.0, 0.45, -0.8)}
    return merge(both(hand, "flat"), {"head": (nod, 0, 0), "hips": (0, 0, -dip),
                                      "spine": (2 + nod * 0.3, 0, 0)})


CLAP_HIT = _clap(0.0165, 0.0, 4, 0.012)  # palms just touch (checked on the mesh)
CLAP_NEAR = _clap(0.05, 0.12, 3, 0.008)
CLAP_OPEN = _clap(0.15, 0.35, 1, 0.0)

CLAP = {
    "name": "Emote_Clap", "length": 48, "loop": True,
    "keys": [(f, CLAP_HIT if f % 16 == 0 else CLAP_OPEN if f % 16 == 8 else CLAP_NEAR)
             for f in (0, 3, 8, 13, 16, 19, 24, 29, 32, 35, 40, 45, 48)],
    "shots": [0, 4, 8, 13, 16],
}

CLIPS = [WAVE, SALUTE, CLAP]
