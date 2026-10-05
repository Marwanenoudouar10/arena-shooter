"""Emote clips, part 2: ThumbsUp, Cheer, Flex. Clip and pose format: see emote_clips_a.py
and emote_poses.py.
"""
from emote_clips_a import ARM_DOWN
from emote_poses import both, merge

N = {}  # neutral

# ---- ThumbsUp: both fists forward, thumbs up toward the viewer, a small nod -----------
def _thumbs(push: float = 0.0, nod: float = 4.0, lean: float = 3.0) -> dict:
    """Both thumbs-up fists in front of the chest; push moves them toward the viewer."""
    hand = {"at": (-0.17, -0.43 - push, 1.26 + push * 0.3), "palm": (1.0, 0.25, 0.0),
            "point": (0.3, -1.0, 0.1), "elbow": (-0.6, 0.5, -1.0)}
    return merge(both(hand, "thumb_up"), {"spine": (lean, 0, 0), "head": (nod, 0, 0),
                                          "clav_l": (2, 4), "clav_r": (2, 4)})


THUMBS = {
    "name": "Emote_ThumbsUp", "length": 75, "loop": False,
    "keys": [
        (0, N),
        (11, _thumbs(0.05, 2, 5)),     # punch forward a little too far ...
        (15, _thumbs(0.0, 3, 4)),      # ... and settle
        (22, _thumbs(0.0, 14, 5)),     # nod
        (29, _thumbs(0.0, 0, 3)),
        (35, _thumbs(0.01, 9, 4)),     # smaller second nod
        (42, _thumbs(0.0, 3, 3)),
        (50, _thumbs(0.03, 4, 4)),     # small pump toward the viewer
        (56, _thumbs(0.0, 3, 3)),
        (65, merge(both({"at": (-0.25, -0.22, 1.02), "elbow": (-0.5, 0.8, -0.6),
                         "palm": (1.0, 0.3, 0.3), "point": (0.1, -0.7, -0.7)}, "relaxed"),
                   {"head": (2, 0, 0)})),
        (75, N),
    ],
    "delays": {"hand_l": 1},
    "shots": [11, 15, 22, 35, 50],
}

# ---- Cheer: dip, jump with both fists up in a V, land, pump the fists -----------------
def _fists_up(z: float, spread: float = 0.33, head: float = -14) -> dict:
    """Both fists above the head in a V (z = height of the palm centres)."""
    hand = {"at": (-spread, -0.06, z), "palm": (0.45, -1.0, -0.1), "point": (-0.15, 0.05, 1.0),
            "elbow": (-1.0, 0.1, -0.2)}
    return merge(both(hand, "fist"), {"head": (head, 0, 0), "chest": (-6, 0, 0),
                                      "clav_l": (14, 0), "clav_r": (14, 0)})


def _feet(z: float, heel: float) -> dict:
    foot = {"off": (0, 0, z), "heel": heel}
    return {"foot_l": foot, "foot_r": foot}


CHEER_DIP = merge(both({"at": (-0.29, 0.02, 0.95), "elbow": (-0.5, 1.0, 0.2),
                        "palm": (0.8, 0.5, 0.0), "point": (0.0, 0.3, -1.0)}, "fist"),
                  {"hips": (0, 0.02, -0.08), "spine": (12, 0, 0), "head": (6, 0, 0)})

CHEER = {
    "name": "Emote_Cheer", "length": 75, "loop": False,
    "keys": [
        (0, N),
        (7, CHEER_DIP),
        (12, merge(_fists_up(1.75, 0.30, -6), _feet(0, 28), {"hips": (0, 0, 0.035)})),
        (15, merge(_fists_up(2.00), _feet(0.05, 24), {"hips": (0, 0, 0.10)})),
        (18, merge(_fists_up(2.04), _feet(0.085, 20), {"hips": (0, 0, 0.125)})),
        (21, merge(_fists_up(2.02), _feet(0.04, 16), {"hips": (0, 0, 0.08)})),
        (23, merge(_fists_up(1.98), _feet(0, 10), {"hips": (0, 0, 0.0)})),
        (27, merge(_fists_up(1.92, 0.34, -10), {"hips": (0, 0.01, -0.075), "spine": (8, 0, 0)})),
        (33, merge(_fists_up(2.03, 0.33, -16), {"hips": (0, 0, -0.005)})),
        (38, merge(_fists_up(1.90, 0.35, -10), {"hips": (0, 0, -0.035), "spine": (4, 0, 0)})),
        (43, merge(_fists_up(2.03, 0.33, -16), {"hips": (0, 0, -0.005)})),
        (48, merge(_fists_up(1.91, 0.35, -11), {"hips": (0, 0, -0.03), "spine": (3, 0, 0)})),
        (53, merge(_fists_up(2.01, 0.32, -14), {"hips": (0, 0, 0.0)})),
        (63, merge(both(ARM_DOWN, "relaxed"),
                   {"head": (-2, 0, 0), "hips": (0, 0, -0.01)})),
        (75, N),
    ],
    "delays": {"hand_l": 1, "hand_r": 1},
    "shots": [7, 18, 27, 38, 66],
}

# ---- Flex: double biceps, chest out, look at one arm then the other -------------------
def _flex(squeeze: float = 0.0, look=(-4, 0, 0)) -> dict:
    """Upper arms out level with the shoulders, forearms up, fists toward the head.
    squeeze (0..1) pulls the fists in and the elbows up a bit more."""
    hand = {"at": (-0.35 + squeeze * 0.02, -0.04, 1.80 + squeeze * 0.01),
            "palm": (1.0, 0.05 + squeeze * 0.2, -0.35), "point": (0.35 + squeeze * 0.15, 0.05, 1.0),
            "elbow": (-1.0, 0.05, -0.25 + squeeze * 0.1)}
    return merge(both(hand, "fist"), {
        "chest": (-8 - squeeze * 3, 0, 0), "spine": (-3, 0, 0), "head": look,
        "clav_l": (10 + squeeze * 3, -5), "clav_r": (10 + squeeze * 3, -5),
        "hips": (0, 0, -0.01)})


FLEX = {
    "name": "Emote_Flex", "length": 90, "loop": False,
    "keys": [
        (0, N),
        (8, merge(both({"at": (-0.42, -0.08, 1.32), "elbow": (-1.0, 0.2, -0.6)}, "loose_fist"),
                  {"chest": (-3, 0, 0)})),
        (14, _flex(0.3)),
        (19, _flex(1.0)),              # first squeeze
        (26, _flex(0.2)),
        (34, _flex(0.6, (6, -6, -40))),   # look at the right biceps
        (42, _flex(1.0, (8, -7, -42))),
        (52, _flex(0.5, (6, 6, 40))),     # look at the left biceps
        (60, _flex(1.0, (8, 7, 42))),
        (68, _flex(0.4, (-5, 0, 0))),     # back to the front, chin up
        (76, merge(both(ARM_DOWN, "relaxed"),
                   {"chest": (-2, 0, 0)})),
        (90, N),
    ],
    "delays": {"hand_l": 1, "hand_r": 1},
    "shots": [14, 19, 34, 52, 80],
}

CLIPS = [THUMBS, CHEER, FLEX]
