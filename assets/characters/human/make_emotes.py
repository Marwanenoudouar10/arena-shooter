"""Builds the 10 emote clips on HumanRig (human_blueprint.blend) and writes emotes.glb:
the armature plus one glTF animation per clip, no mesh. Same skeleton and export settings
as human_anims.glb, so in Godot the clips play on any character from the kit.

Run:
  blender -b --python assets/characters/human/make_emotes.py -- [--previews] [--only=Wave,Clap] [--no-export]
--previews  also renders previews/emote_<name>.png contact sheets (front + side)
--only      builds just some clips (names without "Emote_"), handy while tuning
The blueprint .blend is only read, never saved.

Every clip starts and ends in the neutral pose (Idle's first frame), so it blends in and
out cleanly. Clap and Dance loop instead: their first and last frames are the same.
Modules next to this file:
  emote_rig.py      armature maths: rest data, forward kinematics, two-bone IK
  emote_neutral.py  the neutral pose, read from human_anims.glb
  emote_poses.py    short pose description -> full skeleton pose
  emote_hands.py    finger shapes (fist, thumbs up, flat, open ...)
  emote_keys.py     key poses -> Blender action (smooth Bezier curves, overlap)
  emote_feet.py     keeps the feet planted on every frame
  emote_clips_*.py  the clips themselves
  emote_preview.py  contact sheets
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
sys.dont_write_bytecode = True  # keep __pycache__ out of the assets folder

import bpy

from anim_export import export_glb, keep_only_actions
from emote_clips_a import CLIPS as CLIPS_A
from emote_clips_b import CLIPS as CLIPS_B
from emote_clips_c import CLIPS as CLIPS_C
from emote_feet import pin_feet
from emote_keys import write_clip
from emote_neutral import load_idle
from emote_rig import RigData

BLUEPRINT = os.path.join(HERE, "human_blueprint.blend")
ANIMS = os.path.join(HERE, "human_anims.glb")
OUT = os.path.join(HERE, "emotes.glb")
PREVIEWS = os.path.join(HERE, "previews")
FPS = 30
ALL_CLIPS = CLIPS_A + CLIPS_B + CLIPS_C


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = next((a.split("=", 1)[1].split(",") for a in args if a.startswith("--only=")), None)
    clips = [c for c in ALL_CLIPS if only is None or c["name"].replace("Emote_", "") in only]
    bpy.ops.wm.open_mainfile(filepath=BLUEPRINT)
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = FPS, 1.0
    arm = bpy.data.objects["HumanRig"]
    rig = RigData(arm, load_idle(ANIMS, arm))
    actions = {}
    for clip in clips:
        actions[clip["name"]] = action = write_clip(arm, rig, clip)
        slide = pin_feet(arm, rig, clip, action)
        print("EMOTE %-14s %3d frames %.2f s %s  (feet fixed by %.1f mm)" % (
            clip["name"], clip["length"], clip["length"] / FPS,
            "loop" if clip["loop"] else "once", slide * 1000))
    if "--previews" in args:
        from emote_preview import render_sheets
        render_sheets(arm, clips, actions, PREVIEWS)
    if "--no-export" not in args:
        keep_only_actions(list(actions))
        export_glb(arm, OUT)
        print("EXPORTED %d clips -> %s" % (len(actions), OUT))


if __name__ == "__main__":
    main()
