## Writes each finished part as parts/<file>.glb: HumanRig plus that one skinned mesh, no
## animations, +Y up. Prints the triangle count and file size of every part.
import os

import bpy

import human_config as C


def _clean_groups(obj, rig):
    bones = set(rig.data.bones.keys())
    for group in list(obj.vertex_groups):
        if group.name not in bones:
            obj.vertex_groups.remove(group)


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export(rig, obj, path):
    _clean_groups(obj, rig)
    for o in bpy.context.view_layer.objects:
        o.select_set(o in (rig, obj))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_skins=True, export_animations=False, export_morph=False, export_apply=False,
        export_yup=True, export_normals=True, export_texcoords=True, export_tangents=False,
        export_materials="EXPORT", export_image_format="AUTO", export_jpeg_quality=C.JPG_QUALITY,
        export_def_bones=False, export_rest_position_armature=True, export_extras=False)


def export_all(rig, parts):
    os.makedirs(C.PARTS_DIR, exist_ok=True)
    report = []
    for part, obj in parts:
        path = os.path.join(C.PARTS_DIR, part["file"] + ".glb")
        export(rig, obj, path)
        report.append((part["file"], obj.name, triangles(obj), os.path.getsize(path)))
    for file, mesh, tris, size in report:
        print("PART %-14s mesh %-14s %6d tris %6.2f MB" % (file, mesh, tris, size / 1e6))
    tris_of = {r[0]: r[2] for r in report}
    for name, files in C.OUTFITS.items():
        print("OUTFIT %-8s %6d tris  (%s)" % (name, sum(tris_of[f] for f in files), ", ".join(files)))
    return report
