"""Stage for the animation contact sheets: floor, lights, two cameras (3/4 front and side),
a small text label, and a helper that glues rendered tiles into one PNG.
"""
import bpy
import numpy as np
from mathutils import Vector

TILE_W, TILE_H = 420, 520
LOOK_HEIGHT = 0.85
# Camera position, seen from the point it looks at (the body's hips, at LOOK_HEIGHT).
VIEWS = {"front": Vector((2.3, -4.5, 0.65)), "side": Vector((5.0, 0.0, 0.15))}


def setup_stage(scene) -> dict:
    """Builds the floor, lights and cameras. Returns {view name: camera object}."""
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 16
    scene.render.resolution_x, scene.render.resolution_y = TILE_W, TILE_H
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("preview_world")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1.0)
    _floor(scene)
    _light(scene, "key", 700, (2.5, -3.0, 3.2), 3.0)
    _light(scene, "rim", 400, (-2.5, 2.5, 2.8), 2.0)
    _light(scene, "fill", 200, (-3.0, -2.5, 1.4), 3.0)
    cams = {}
    for name, where in VIEWS.items():
        data = bpy.data.cameras.new("cam_" + name)
        data.lens = 75
        cam = bpy.data.objects.new("cam_" + name, data)
        scene.collection.objects.link(cam)
        cams[name] = cam
    aim_cameras(cams, Vector((0.0, 0.0, 0.0)))
    return cams


def aim_cameras(cams: dict, hips: Vector) -> None:
    """Points every camera at the body's hips (only x and y are followed)."""
    look = Vector((hips.x, hips.y, LOOK_HEIGHT))
    for name, cam in cams.items():
        cam.location = look + VIEWS[name]
        cam.rotation_euler = (-VIEWS[name]).to_track_quat("-Z", "Y").to_euler()


def _floor(scene) -> None:
    """Grey floor at z = 0 with a darker checker, so feet sinking or floating is easy to see."""
    mesh = bpy.data.meshes.new("preview_floor")
    s = 6.0
    mesh.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    obj = bpy.data.objects.new("preview_floor", mesh)
    scene.collection.objects.link(obj)
    mat = bpy.data.materials.new("preview_floor")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 24.0
    checker.inputs["Color1"].default_value = (0.32, 0.32, 0.33, 1.0)
    checker.inputs["Color2"].default_value = (0.24, 0.24, 0.25, 1.0)
    links.new(checker.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    mesh.materials.append(mat)


def _light(scene, name: str, energy: float, loc: tuple, size: float) -> None:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size = energy, size
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, 0.9)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)


def make_label(scene):
    """A text object that follows the active camera (set its body before each render)."""
    curve = bpy.data.curves.new("preview_label", "FONT")
    curve.size = 0.045
    label = bpy.data.objects.new("preview_label", curve)
    mat = bpy.data.materials.new("preview_label")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.55, 0.15, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 4.0
    curve.materials.append(mat)
    scene.collection.objects.link(label)
    return label


def place_label(label, cam, text: str) -> None:
    label.data.body = text
    label.parent = cam
    label.location = (-0.28, 0.33, -1.6)  # top-left corner, just in front of the camera
    label.rotation_euler = (0.0, 0.0, 0.0)


def glue(tiles: list, cols: int, out_path: str) -> None:
    """Joins equal-size PNG tiles (row by row, top-left first) into one image."""
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * TILE_H, cols * TILE_W, 4), dtype=np.float32)
    for i, path in enumerate(tiles):
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(TILE_H, TILE_W, 4)
        r, c = divmod(i, cols)
        y = (rows - 1 - r) * TILE_H  # Blender images start at the bottom row
        sheet[y:y + TILE_H, c * TILE_W:(c + 1) * TILE_W] = px
        bpy.data.images.remove(img)
    out = bpy.data.images.new("sheet", cols * TILE_W, rows * TILE_H, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
