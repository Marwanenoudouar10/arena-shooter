## Entry: builds the realistic MakeHuman (MPFB) character for the game.
##
## Run:  blender -b --python assets/characters/human/make_human.py -- [--blueprint] [--no-previews]
##
## 1. Builds one man with the game_engine rig and every hair / cloth from human_config.
## 2. human_blueprint.blend: the bare man on HumanRig. Written only when it is missing or with
##    --blueprint, because the animation job works in it; otherwise the rig is checked against it.
## 3. parts/<slot>_<name>.glb: one skinned mesh per part, all on the same HumanRig.
## 4. previews/<outfit>.png: each class outfit rendered from the exported glbs.
import os
import sys
import tempfile

import bpy

sys.dont_write_bytecode = True  # no __pycache__ next to the scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import human_config as C  # noqa: E402
import mpfb_build  # noqa: E402
import bake_body  # noqa: E402
import game_materials  # noqa: E402
import blueprint  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def objects_by_key(rig):
    return {obj.name: obj for obj in rig.children}


def main():
    rig, objs = mpfb_build.build()
    bake_body.bake(rig, objs)
    bake_body.check_facing(rig)
    game_materials.convert_all(objs)
    work = os.path.join(tempfile.mkdtemp(prefix="human_work_"), "work.blend")
    bpy.ops.wm.save_as_mainfile(filepath=work)

    if "--blueprint" in ARGS or not os.path.exists(C.BLUEPRINT):
        blueprint.save(rig, objs)
        bpy.ops.wm.open_mainfile(filepath=work)
        game_materials.reset()
    rig = bpy.data.objects[C.RIG_NAME]
    if not blueprint.bones_match(rig):
        raise RuntimeError("HumanRig differs from human_blueprint.blend; rerun with --blueprint")
    print("RIG matches the blueprint")
    if "--blueprint-only" in ARGS:
        return

    import part_cut  # noqa: E402  (loaded late: only needed for parts)
    import part_export  # noqa: E402
    objs = objects_by_key(rig)
    pieces = part_cut.make_all(rig, objs)
    part_export.export_all(rig, pieces)
    if "--no-previews" not in ARGS:
        import preview  # noqa: E402
        preview.render_all()


main()
