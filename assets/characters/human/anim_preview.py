"""Contact sheets to check the retarget by eye: for a few key clips, renders the source
Quaternius character and the retargeted realistic body at the same frames, from a 3/4
front view and from the side. One PNG per clip: previews/anim_<clip>.png.
Each row is one frame; columns are: source front, new front, source side, new side.

Run:
  blender -b --python assets/characters/human/anim_preview.py -- [target.blend] [armature] [out_dir]
Defaults: human_blueprint.blend, HumanRig, previews/ next to this script.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
sys.dont_write_bytecode = True

import bpy
from mathutils import Vector

from anim_keys import play
from anim_preview_scene import aim_cameras, glue, make_label, place_label, setup_stage
from bake_animations import load_and_bake

CLIPS = ["Idle_Gun", "Run_Shoot", "Run_Left", "Walk", "Death", "HitRecieve"]
ONE_SHOTS = ("Death", "HitRecieve")  # these do not loop, so show their last frame too
PREFIX = "CharacterArmature|"


def body_height(arm) -> float:
    """Top of the meshes skinned to this armature, in world space (rest pose)."""
    top = 0.0
    for obj in arm.children_recursive:
        if obj.type == "MESH":
            top = max(top, max((obj.matrix_world @ Vector(c)).z for c in obj.bound_box))
    return top


def pick_frames(action, clip: str) -> list:
    start, end = (int(round(v)) for v in action.frame_range)
    length = end - start
    parts = (0.0, 0.33, 0.66, 1.0) if clip in ONE_SHOTS else (0.0, 0.25, 0.5, 0.75)
    return [start + int(round(p * length)) for p in parts]


def stage_source(src, imported: list, tgt) -> list:
    """Hides imported helper objects and scales the source to the target's height."""
    shown = [src] + [o for o in src.children_recursive]
    for obj in imported:
        obj.hide_render = obj not in shown
    root = src.parent if src.parent else src
    root.scale = root.scale * (body_height(tgt) / body_height(src))
    return [o for o in shown if o.type == "MESH"]


def render_tile(scene, path: str) -> str:
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    target = args[0] if len(args) > 0 else os.path.join(HERE, "human_blueprint.blend")
    armature = args[1] if len(args) > 1 else "HumanRig"
    out_dir = os.path.abspath(args[2] if len(args) > 2 else os.path.join(HERE, "previews"))
    os.makedirs(out_dir, exist_ok=True)
    src, tgt, names, imported = load_and_bake(os.path.abspath(target), armature)
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    src_meshes = stage_source(src, imported, tgt)
    tgt_meshes = [o for o in tgt.children_recursive if o.type == "MESH" and not o.hide_render]
    cams = setup_stage(scene)
    label = make_label(scene)
    tmp = os.path.join(bpy.app.tempdir, "anim_tiles")
    os.makedirs(tmp, exist_ok=True)
    for clip in CLIPS:
        name = PREFIX + clip
        if name not in names:
            print("skip, no clip", name)
            continue
        play(src, bpy.data.actions["src:" + name])
        play(tgt, bpy.data.actions[name])
        tiles = []
        for f in pick_frames(bpy.data.actions[name], clip):
            scene.frame_set(f)
            aim_cameras(cams, tgt.matrix_world @ tgt.pose.bones["pelvis"].head)
            for view, cam in cams.items():
                scene.camera = cam
                for who, show, hide in (("SRC", src_meshes, tgt_meshes), ("NEW", tgt_meshes, src_meshes)):
                    for o in show:
                        o.hide_render = False
                    for o in hide:
                        o.hide_render = True
                    place_label(label, cam, "%s f%d %s" % (who, f, view))
                    tiles.append(render_tile(scene, os.path.join(tmp, "%s_%d_%s_%s.png" % (clip, f, view, who))))
        out = os.path.join(out_dir, "anim_%s.png" % clip)
        glue(tiles, 4, out)
        print("PREVIEW", out)


if __name__ == "__main__":
    main()
