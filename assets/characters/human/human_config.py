## Settings for the human pipeline: who he is, how tall, and which CC0 MPFB assets build each part.
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BLUEPRINT = os.path.join(HERE, "human_blueprint.blend")
PARTS_DIR = os.path.join(HERE, "parts")
PREVIEW_DIR = os.path.join(HERE, "previews")

HEIGHT = 1.86  # metres, top of the head (not the hair)
RIG = "game_engine"
RIG_NAME = "HumanRig"

# MakeHuman sliders (0..1): a fit, muscular adult man.
PHENOTYPE = {"gender": 1.0, "age": 0.45, "muscle": 0.8, "weight": 0.55, "height": 0.62, "proportions": 0.7,
             "race": {"asian": 0.0, "caucasian": 1.0, "african": 0.0}}

SKIN = "young_caucasian_male/young_caucasian_male.mhmat"
EYES = "low-poly/low-poly.mhclo"
EYE_MATERIAL = "materials/brownlight.mhmat"  # MPFB's "brown" looks red in game light
EYEBROWS = "eyebrow001/eyebrow001.mhclo"
EYELASHES = "eyelashes01/eyelashes01.mhclo"

# key -> mhclo file (relative to MPFB's hair/ folder)
HAIRS = {
    "short02": "short02/short02.mhclo",
    "short04": "short04/short04.mhclo",
}

# key -> mhclo file (relative to MPFB's clothes/ folder). Every one is loaded on the same body.
CLOTHES = {
    "tee": "male_casualsuit06/male_casualsuit06.mhclo",        # white tee + jeans (we keep the tee)
    "polo": "namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo",
    "sweater": "toigo_fisherman_sweater/toigo_fisherman_sweater.mhclo",
    "jacket": "male_casualsuit05/male_casualsuit05.mhclo",     # field jacket + jeans (both used)
    "cargo": "cortu_cargo_pants/cortu_cargo_pants.mhclo",
    "shoes": "shoes03/shoes03.mhclo",                          # black leather shoes (+ socks)
    "sneakers": "shoes06/shoes06.mhclo",                       # blue sneakers (+ socks)
    "boots": "toigo_ankle_boots_male/toigo_ankle_boots_male.mhclo",  # brown leather ankle boots
}

# Slot -> bones whose skin belongs to that slot (the strongest bone of a vertex decides).
SLOT_BONES = {
    "Head": ["head", "neck_01"],
    "Legs": ["pelvis", "thigh_l", "calf_l", "thigh_r", "calf_r"],
    "Feet": ["foot_l", "ball_l", "foot_r", "ball_r"],
}  # every other bone (spine, arms, hands) is "Top"

# Mesh name inside each glb is <Prefix>_<suffix>, like the Quaternius kit (Casual_Body etc.).
SLOT_SUFFIX = {"Head": "Head", "Top": "Body", "Legs": "Legs", "Feet": "Feet"}

# One entry per glb. "cloth" = CLOTHES key, "keep" = which loose pieces to keep ("top" drops the
# jeans of a suit or a polo's loose hem band, "legs" keeps only the jeans), "smooth" = bake one
# subdivision level, "tint" = colour multiplied into the cloth texture, "erase" = texture boxes
# (u0, v0, u1, v1 from the top-left) painted over with the cloth around them (logos).
PARTS = [
    {"file": "head_short", "slot": "Head", "prefix": "Short", "hair": "short02"},
    {"file": "head_slick", "slot": "Head", "prefix": "Slick", "hair": "short04"},
    {"file": "top_tshirt", "slot": "Top", "prefix": "Tshirt", "cloth": "tee", "keep": "top", "tint": (0.30, 0.31, 0.27),
     "erase": [(0.19, 0.11, 0.30, 0.165), (0.435, 0.115, 0.635, 0.21), (0.725, 0.145, 0.76, 0.185)]},
    {"file": "top_polo", "slot": "Top", "prefix": "Polo", "cloth": "polo", "keep": "top", "tint": (0.36, 0.42, 0.58)},
    {"file": "top_sweater", "slot": "Top", "prefix": "Sweater", "cloth": "sweater"},
    {"file": "top_jacket", "slot": "Top", "prefix": "Jacket", "cloth": "jacket", "keep": "top"},
    {"file": "legs_jeans", "slot": "Legs", "prefix": "Jeans", "cloth": "jacket", "keep": "legs"},
    {"file": "legs_cargo", "slot": "Legs", "prefix": "Cargo", "cloth": "cargo", "smooth": True},
    {"file": "feet_shoes", "slot": "Feet", "prefix": "Shoes", "cloth": "shoes"},
    {"file": "feet_sneakers", "slot": "Feet", "prefix": "Sneakers", "cloth": "sneakers"},
    {"file": "feet_boots", "slot": "Feet", "prefix": "Boots", "cloth": "boots"},
]

# Suggested looks per class (part file names), rendered as previews.
OUTFITS = {
    "light": ["head_short", "top_tshirt", "legs_jeans", "feet_sneakers"],
    "medium": ["head_slick", "top_polo", "legs_jeans", "feet_boots"],
    "heavy": ["head_short", "top_jacket", "legs_cargo", "feet_shoes"],
    "sweater": ["head_slick", "top_sweater", "legs_cargo", "feet_boots"],
}

SKIN_TEX = 2048  # px, skin texture in the head part
TEX = 1024       # px, every other texture
JPG_QUALITY = 88
