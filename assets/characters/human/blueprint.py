## Saves human_blueprint.blend: the bare man (body, eyes, brows, lashes, one hair) on HumanRig,
## no clothes. Animations are baked onto this file's armature by a separate job.
import os

import bpy

import human_config as C


def bone_groups_only(obj, rig):
    """Drop every vertex group that is not a bone (MPFB delete groups, lips, ears...)."""
    bones = set(rig.data.bones.keys())
    for group in list(obj.vertex_groups):
        if group.name not in bones:
            obj.vertex_groups.remove(group)


def save(rig, objs, hair="short02"):
    keep = {"Body", "Eyes", "Eyebrows", "Eyelashes", "Hair_" + hair}
    for key, obj in list(objs.items()):
        if key not in keep:
            bpy.data.objects.remove(obj)
    for obj in rig.children:
        bone_groups_only(obj, rig)
    objs["Body"].name = "HumanBody"
    objs["Hair_" + hair].name = "HumanHair"
    for key in ("Eyes", "Eyebrows", "Eyelashes"):
        objs[key].name = "Human" + key
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.file.pack_all()  # textures live in a temp folder, so keep them inside the .blend
    scene = bpy.context.scene
    scene.render.fps = 30
    bpy.ops.wm.save_as_mainfile(filepath=C.BLUEPRINT, compress=True)
    if os.path.exists(C.BLUEPRINT + "1"):
        os.remove(C.BLUEPRINT + "1")  # Blender's backup of the previous blueprint
    print("SAVED", C.BLUEPRINT)


def bones_match(rig, path=C.BLUEPRINT, tol=1e-5):
    """True when the saved blueprint's armature has the same bones, order and rest pose as rig."""
    with bpy.data.libraries.load(path) as (src, dst):
        dst.armatures = [n for n in src.armatures if n == C.RIG_NAME]
    if not dst.armatures:
        return False
    other = dst.armatures[0]
    ok = [b.name for b in other.bones] == [b.name for b in rig.data.bones]
    for a, b in zip(other.bones, rig.data.bones):
        if any(abs(x - y) > tol for ra, rb in zip(a.matrix_local, b.matrix_local) for x, y in zip(ra, rb)):
            ok = False
    bpy.data.armatures.remove(other)
    return ok
