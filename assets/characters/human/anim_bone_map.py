"""Bone map from the Quaternius character rig (source) to the MPFB "game_engine" rig (target).
Each target bone says which source bone drives it and how its rest pose is lined up.
"""

# How a bone's rest pose is lined up with the source rest pose (source is a T-pose):
#   "keep"  - no change. Both rests already mean the same thing (spine, neck, feet...).
#   "swing" - turn the bone so it points the same way as the source bone (arms, legs, fingers).
#   "frame" - like swing, and also turn it around its length so the palm faces the same way.
KEEP, SWING, FRAME = "keep", "swing", "frame"

# target bone: (source bone, mode, source aim point, target aim point)
# An aim point is the head of another bone; None means "this bone's own tail".
CENTRE = {
    "Root": ("Root", KEEP, None, None),
    "pelvis": ("Hips", KEEP, None, None),
    "spine_01": ("Abdomen", KEEP, None, None),
    "spine_02": ("Torso", KEEP, None, None),
    "spine_03": ("Chest", KEEP, None, None),
    "neck_01": ("Neck", KEEP, None, None),
    "head": ("Head", KEEP, None, None),
}

# Quaternius finger 1 sits inside the palm, so fingers 2/3/4 drive game_engine 01/02/03.
FINGERS = [("Index", "index"), ("Middle", "middle"), ("Ring", "ring"), ("Pinky", "pinky")]


def _side(s: str, t: str) -> dict:
    """Bone map for one side. s is the source suffix ("L"), t the target one ("l")."""
    m = {
        "clavicle_" + t: ("Shoulder." + s, KEEP, None, None),
        "upperarm_" + t: ("UpperArm." + s, SWING, "LowerArm." + s, "lowerarm_" + t),
        "lowerarm_" + t: ("LowerArm." + s, SWING, "Wrist." + s, "hand_" + t),
        "hand_" + t: ("Wrist." + s, FRAME, "Middle2." + s, "middle_01_" + t),
        "thigh_" + t: ("UpperLeg." + s, SWING, "LowerLeg." + s, "calf_" + t),
        "calf_" + t: ("LowerLeg." + s, SWING, "Foot." + s, "foot_" + t),
        "foot_" + t: ("Foot." + s, KEEP, None, None),
        # ball_l/r has no source bone: it just follows the foot.
    }
    for src, tgt in FINGERS:
        m["%s_01_%s" % (tgt, t)] = ("%s2.%s" % (src, s), SWING, "%s3.%s" % (src, s), "%s_02_%s" % (tgt, t))
        m["%s_02_%s" % (tgt, t)] = ("%s3.%s" % (src, s), SWING, "%s4.%s" % (src, s), "%s_03_%s" % (tgt, t))
        m["%s_03_%s" % (tgt, t)] = ("%s4.%s" % (src, s), SWING, None, None)
    # Quaternius thumb 1 is the long bone at the base of the thumb, like game_engine thumb_01.
    m["thumb_01_" + t] = ("Thumb1." + s, SWING, "Thumb2." + s, "thumb_02_" + t)
    m["thumb_02_" + t] = ("Thumb2." + s, SWING, "Thumb3." + s, "thumb_03_" + t)
    m["thumb_03_" + t] = ("Thumb3." + s, SWING, None, None)
    return m


BONE_MAP = {**CENTRE, **_side("L", "l"), **_side("R", "r")}

# Bones used to find which way the palm faces: (source index, source pinky, target index, target pinky).
PALM = {
    "hand_l": ("Index2.L", "Pinky2.L", "index_01_l", "pinky_01_l"),
    "hand_r": ("Index2.R", "Pinky2.R", "index_01_r", "pinky_01_r"),
}

# The hip joints (left, right). The new pelvis is placed so its hip joints sit where the
# source hip joints are, with heights scaled by the hip-height ratio of the two bodies.
SOURCE_HIPS, TARGET_HIPS = ("UpperLeg.L", "UpperLeg.R"), ("thigh_l", "thigh_r")
TARGET_PELVIS = "pelvis"
