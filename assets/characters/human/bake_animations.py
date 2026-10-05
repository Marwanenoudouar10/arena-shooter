"""Retargets the 24 Quaternius clips (characters/real/hoodie.glb) onto the realistic human's
MPFB "game_engine" rig and writes human_anims.glb: the armature plus every clip, each as
its own glTF animation, with the same names as before (e.g. "CharacterArmature|Idle_Gun").

Run:
  blender -b --python assets/characters/human/bake_animations.py -- [target.blend] [armature] [out.glb] [--with-mesh]
Defaults: human_blueprint.blend, HumanRig and human_anims.glb next to this script.
--with-mesh also puts the body meshes in the file (by default it is the armature only).
The target .blend is only read, never saved. Floors are at z = 0 in both rigs.

This file is only the entry point. The code lives in the modules next to it:
  anim_bone_map.py  which source bone drives which target bone, and how rests line up
  anim_retarget.py  the maths: rest pose lining up, one frame -> target pose values
  anim_keys.py      plays each clip on the source rig and writes the baked keyframes
  anim_export.py    glTF export settings (one animation per clip, nothing leaks)
  anim_preview.py   contact sheets (source next to target) to check the result
"""
import os
import sys

# Blender runs this file as a script, so its folder is not on the import path yet.
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
sys.dont_write_bytecode = True  # keep __pycache__ out of the assets folder

import bpy

from anim_export import export_glb, keep_only_actions, remove_objects
from anim_keys import bake_clips
from anim_retarget import Retarget

SOURCE = os.path.normpath(os.path.join(HERE, "..", "real", "hoodie.glb"))
SOURCE_FPS = 24  # the Quaternius clips are keyed on whole frames at 24 fps


def load_and_bake(target_blend: str, armature: str, source: str = SOURCE):
    """Opens the target, imports the source and bakes all clips onto the target armature.
    Returns (source armature, target armature, clip names, imported objects)."""
    bpy.ops.wm.open_mainfile(filepath=target_blend)
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = SOURCE_FPS, 1.0  # set before import: frames = seconds x fps
    layer = bpy.context.view_layer
    layer.active_layer_collection = layer.layer_collection
    old_objects, old_actions = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=source)
    imported = [o for o in bpy.data.objects if o not in old_objects]
    clips = sorted((a for a in bpy.data.actions if a not in old_actions), key=lambda a: a.name)
    src = next(o for o in imported if o.type == "ARMATURE")
    tgt = bpy.data.objects[armature]
    retarget = Retarget(src, tgt)
    print("retarget:", retarget.report())
    names = bake_clips(scene, src, tgt, retarget, clips)
    return src, tgt, names, imported


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    plain = [a for a in args if not a.startswith("--")]
    target = plain[0] if len(plain) > 0 else os.path.join(HERE, "human_blueprint.blend")
    armature = plain[1] if len(plain) > 1 else "HumanRig"
    out = os.path.abspath(plain[2] if len(plain) > 2 else os.path.join(HERE, "human_anims.glb"))
    src, tgt, names, imported = load_and_bake(os.path.abspath(target), armature)
    remove_objects(imported)
    keep_only_actions(names)
    export_glb(tgt, out, "--with-mesh" in args)
    print("BAKED %d clips -> %s" % (len(names), out))


if __name__ == "__main__":
    main()
