"""Contact sheets to check the emotes by eye: the bare blueprint man playing each clip,
seen from the front (top row) and from his right side (bottom row) at a few frames.
One PNG per clip: previews/emote_<name>.png. Cameras stay still, so steps and jumps show
against the checker floor.
"""
import os

import bpy
from mathutils import Vector

from anim_keys import play
from anim_preview_scene import glue, make_label, place_label, setup_stage

LOOK = Vector((0.0, 0.0, 1.02))  # the cameras look at this point
# camera position seen from LOOK: in front of him (-Y) and on his right side (-X)
VIEWS = {"front": Vector((0.45, -5.9, 0.2)), "side": Vector((-5.9, -0.25, 0.2))}


def setup(scene) -> tuple:
    """Floor, lights, the two cameras and the frame label."""
    cams = setup_stage(scene)
    for name, cam in cams.items():
        cam.location = LOOK + VIEWS[name]
        cam.rotation_euler = (-VIEWS[name]).to_track_quat("-Z", "Y").to_euler()
    return cams, make_label(scene)


def render_tile(scene, cam, label, text: str, path: str) -> str:
    scene.camera = cam
    place_label(label, cam, text)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_sheets(arm, clips: list, actions: dict, out_dir: str) -> list:
    """Renders one sheet per clip at the clip's "shots" frames. Returns the PNG paths."""
    scene = bpy.context.scene
    cams, label = setup(scene)
    tmp = os.path.join(bpy.app.tempdir, "emote_tiles")
    os.makedirs(tmp, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    sheets = []
    for clip in clips:
        play(arm, actions[clip["name"]])
        short = clip["name"].replace("Emote_", "")
        tiles = []
        for view in ("front", "side"):
            for f in clip["shots"]:
                scene.frame_set(f)
                path = os.path.join(tmp, "%s_%s_%03d.png" % (short, view, f))
                tiles.append(render_tile(scene, cams[view], label, "%s f%d" % (short, f), path))
        out = os.path.join(out_dir, "emote_%s.png" % short)
        glue(tiles, len(clip["shots"]), out)
        sheets.append(out)
        print("PREVIEW", out)
    return sheets
