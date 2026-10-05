"""Emote clips, part 3: Shrug, Bow, Dance, Laugh. Clip and pose format: see
emote_clips_a.py and emote_poses.py.
"""
from emote_poses import both, merge, mirror

N = {}  # neutral

# ---- Shrug: shoulders up, palms up, head tilted ----------------------------------------
def _shrug(up: float, tilt: float, reach: float = 1.0) -> dict:
    hand = {"at": (-0.30 - 0.04 * reach, -0.30 - 0.03 * reach, 1.06), "palm": (-0.25, 0.0, 1.0),
            "point": (-0.45, -1.0, 0.05), "elbow": (-0.35, 0.5, -1.0), "share": 0.8}
    return merge(both(hand, "soft"), {"clav_l": (up, 3), "clav_r": (up, 3),
                                      "head": (-3, tilt, 6), "spine": (-2, -2, 0),
                                      "hips": (0, 0, -0.005)})


SHRUG = {
    "name": "Emote_Shrug", "length": 60, "loop": False,
    "keys": [
        (0, N),
        (11, _shrug(19, 13)),     # up a bit past ...
        (15, _shrug(16, 12)),     # ... and settle
        (34, _shrug(15, 15, 1.2)),
        (44, merge(both({"at": (-0.35, -0.17, 1.03), "elbow": (-0.4, 0.7, -0.8),
                         "palm": (0.5, -0.1, 0.8), "point": (-0.2, -1.0, -0.2)}, "soft"),
                   {"clav_l": (3, 1), "clav_r": (3, 1), "head": (-1, 5, 2)})),
        (60, N),
    ],
    "delays": {"hand_l": 1, "hand_r": 1},
    "shots": [11, 15, 34, 44, 52],
}

# ---- Bow: polite bow from the hips, hands along the sides ------------------------------
SIDES = {"at": (-0.245, -0.03, 0.90), "frame": "Root", "elbow": (-0.3, 1.0, 0.0),
         "palm": (1.0, 0.0, 0.0), "point": (0.0, -0.1, -1.0)}


def _bow(deep: float) -> dict:
    """deep = 1 is the full bow (about 30 degrees at the hips plus the back)."""
    hand = dict(SIDES, at=(-0.25 - 0.005 * deep, -0.03 - 0.10 * deep, 0.90 - 0.05 * deep),
                point=(0.0, -0.1 - 0.5 * deep, -1.0))
    return merge(both(hand, "flat"), {"hips_turn": (24 * deep, 0, 0),
                                      "hips": (0, 0.045 * deep, -0.008 * deep),
                                      "spine": (9 * deep, 0, 0), "head": (10 * deep, 0, 0)})


BOW = {
    "name": "Emote_Bow", "length": 75, "loop": False,
    "keys": [
        (0, N),
        (9, merge(_bow(0.0), {"chest": (-2, 0, 0)})),   # stand up straight first
        (24, _bow(1.0)),
        (38, _bow(1.06)),
        (52, _bow(0.35)),
        (61, merge(_bow(0.0), {"head": (-2, 0, 0)})),
        (75, N),
    ],
    "delays": {"hand_l": 1, "hand_r": 1, "spine_03": 1},
    "shots": [9, 24, 38, 52, 61],
}

# ---- Dance: step out and back to each side, hips bounce, arms swing (loops) ------------
def _groove(sway: float, low: float, step_r=(0.0, 0.0), step_l=(0.0, 0.0)) -> dict:
    """sway: -1 = weight on his right, +1 = on his left. low: knee bounce (0..1).
    step_*: (how far out, how high) for each foot."""
    y = 0.07 * sway  # arms swing to the side and pump forward/back in turn
    swing = {"at": (-0.22 + 0.13 * sway, -0.25 + y, 1.12 + 0.03 * low),
             "palm": (0.9, 0.0, -0.4), "point": (0.15 + 0.3 * sway, -1.0, 0.15),
             "elbow": (-0.7, 0.9, -0.6)}
    other = {"at": (0.22 + 0.13 * sway, -0.25 - y, 1.12 + 0.03 * low),
             "palm": (-0.9, 0.0, -0.4), "point": (-0.15 + 0.3 * sway, -1.0, 0.15),
             "elbow": (0.7, 0.9, -0.6)}
    return {
        "arm_r": swing, "arm_l": other, "hand_r": "loose_fist", "hand_l": "loose_fist",
        "hips": (0.06 * sway, 0.0, -0.045 * low - 0.01),
        "hips_turn": (0, -4 * sway, 6 * sway),
        "spine": (4, 7 * sway, -9 * sway), "head": (3 + 4 * low, -6 * sway, 4 * sway),
        "clav_l": (5 * (1 - low), 2), "clav_r": (5 * (1 - low), 2),
        "foot_r": {"off": (-step_r[0], 0.0, step_r[1]), "heel": 25 * min(step_r[1] * 20, 1)},
        "foot_l": {"off": (step_l[0], 0.0, step_l[1]), "heel": 25 * min(step_l[1] * 20, 1)},
    }


DANCE_HOME = _groove(0.0, 1.0)

DANCE = {
    "name": "Emote_Dance", "length": 60, "loop": True,
    "keys": [
        (0, DANCE_HOME),
        (7, _groove(-0.6, 0.0, step_r=(0.08, 0.06))),     # right foot up and out
        (15, _groove(-1.0, 1.0, step_r=(0.15, 0.0))),     # lands wide, weight right
        (22, _groove(-0.5, 0.0, step_r=(0.08, 0.05))),    # and comes back
        (30, _groove(0.0, 1.0)),
        (37, _groove(0.6, 0.0, step_l=(0.08, 0.06))),     # left foot up and out
        (45, _groove(1.0, 1.0, step_l=(0.15, 0.0))),
        (52, _groove(0.5, 0.0, step_l=(0.08, 0.05))),
        (60, DANCE_HOME),
    ],
    "delays": {"neck_01": 2, "head": 4, "hand_l": 2, "hand_r": 2},
    "shots": [0, 7, 15, 30, 45],
}

# ---- Laugh: hand on the belly, head back, the upper body rocks -------------------------
BELLY = {"at": (-0.04, -0.178, 1.08), "frame": "spine_01", "palm": (0.0, 1.0, 0.1),
         "point": (1.0, -0.15, -0.25), "elbow": (-1.0, 0.3, -0.4)}
LEFT_LOOSE = mirror({"at": (-0.29, -0.08, 0.96), "elbow": (-0.3, 1.0, 0.0),
                     "palm": (1.0, 0.0, 0.0), "point": (0.0, -0.1, -1.0)})


def _laugh(bend: float, bounce: float, head: float) -> dict:
    """bend: forward lean (degrees), bounce: 0/1 for the quick 'ha ha' shoulder bumps."""
    return {
        "arm_r": BELLY, "hand_r": "rest", "arm_l": LEFT_LOOSE, "hand_l": "relaxed",
        "spine": (bend, 0, 0), "chest": (-3 * bounce, 0, 0), "head": (head, 3, 0),
        "clav_l": (5 * bounce, 1), "clav_r": (5 * bounce, 1),
        "hips": (0, 0.0012 * max(bend, 0), -0.006 * bounce),
    }


LAUGH = {
    "name": "Emote_Laugh", "length": 75, "loop": False,
    "keys": [
        (0, N),
        (8, _laugh(-6, 1, -20)),       # head back, hand to the belly
        (11, _laugh(-7, 0, -22)),
        (14, _laugh(-6, 1, -19)),
        (17, _laugh(-6, 0, -20)),
        (20, _laugh(-4, 1, -15)),
        (23, _laugh(-2, 0, -10)),
        (31, _laugh(22, 1, 12)),       # folds forward
        (34, _laugh(24, 0, 14)),
        (37, _laugh(21, 1, 11)),
        (40, _laugh(24, 0, 14)),
        (43, _laugh(20, 1, 10)),
        (46, _laugh(22, 0, 12)),
        (55, _laugh(-3, 1, -12)),      # comes up, one more laugh
        (58, _laugh(-4, 0, -13)),
        (61, _laugh(-2, 1, -8)),
        (75, N),
    ],
    "delays": {"hand_l": 2, "neck_01": 1, "head": 2},
    "shots": [8, 17, 34, 43, 58],
}

CLIPS = [SHRUG, BOW, DANCE, LAUGH]
