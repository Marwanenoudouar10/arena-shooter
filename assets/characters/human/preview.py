## Renders previews/<outfit>.png from the EXPORTED part glbs (proves the export works): the
## outfit twice, standing in the rest pose (front) and in a bent test pose (back), to catch
## skin or cloth poking through when the skeleton moves.
import math
import os

import bpy
from mathutils import Matrix, Vector

import human_config as C

# bone, world axis, degrees (applied parent first)
TEST_POSE = [
    ("spine_02", "Z", 15), ("head", "Z", -20),
    ("upperarm_l", "Y", 38), ("upperarm_r", "Y", -38),
    ("lowerarm_l", "X", -75), ("lowerarm_r", "X", -30),
    ("thigh_l", "X", -50), ("calf_l", "X", 85), ("thigh_r", "X", 15), ("foot_l", "X", -15),
]


def _import_outfit(files, offset, turn_deg):
    rigs = []
    for f in files:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(C.PARTS_DIR, f + ".glb"))
        for obj in set(bpy.data.objects) - before:
            if obj.parent is None:
                obj.location = offset
                obj.rotation_mode = "XYZ"
                obj.rotation_euler = (0, 0, math.radians(turn_deg))
            if obj.type == "ARMATURE":
                rigs.append(obj)
    return rigs


def _pose(rig):
    for bone, axis, deg in TEST_POSE:
        pb = rig.pose.bones[bone]
        head = pb.head.copy()
        rot = Matrix.Rotation(math.radians(deg), 4, axis)
        pb.matrix = Matrix.Translation(head) @ rot @ Matrix.Translation(-head) @ pb.matrix
        bpy.context.view_layer.update()


def _light(scene, name, energy, loc, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.color = energy, size, color
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)


def _stage(scene):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.055, 0.06, 1)
    _light(scene, "key", 900, (2.4, -3.2, 3.0), 3.0, (1.0, 0.95, 0.88))
    _light(scene, "rim", 600, (-2.2, 2.6, 2.6), 2.0, (1.0, 0.6, 0.3))
    _light(scene, "fill", 250, (-3.0, -2.4, 1.4), 3.0, (0.7, 0.8, 1.0))
    floor = bpy.data.meshes.new("floor")
    floor.from_pydata([(-6, -6, 0), (6, -6, 0), (6, 6, 0), (-6, 6, 0)], [], [(0, 1, 2, 3)])
    fo = bpy.data.objects.new("floor", floor)
    scene.collection.objects.link(fo)
    mat = bpy.data.materials.new("floor")
    mat.diffuse_color = (0.08, 0.08, 0.09, 1)
    floor.materials.append(mat)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 42
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = (0.15, -4.4, 1.1)
    cam.rotation_euler = (Vector((0.08, 0, 0.92)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam


def render(name, files):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    _stage(scene)
    _import_outfit(files, (-0.6, 0, 0), 20)
    for rig in _import_outfit(files, (0.75, 0.3, 0), 200):
        _pose(rig)
    os.makedirs(C.PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(C.PREVIEW_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", scene.render.filepath)


def render_all():
    for name, files in C.OUTFITS.items():
        render(name, files)
