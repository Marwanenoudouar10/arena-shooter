"""Builds the starter cover map and exports it for the trainer.

Run:  blender --background --factory-startup --python maps/make_cover_map.py

Blender axes -> game: X = left/right, +Y = towards the targets, Z = up.
You stand at (0, 0). Targets walk in the lane at Y 12..16, behind the cover row at Y 10.
Objects whose name starts with "ref_" are guides only; the game ignores them.
"""
import os
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()


def material(name, rgba):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
    return mat


COVER = material("Cover", (0.62, 0.6, 0.55, 1.0))
GUIDE = material("Guide", (0.2, 0.5, 1.0, 1.0))


def box(name, x, y, width, depth, height, mat=COVER):
    """Box standing on the floor, centred on (x, y). Sizes in metres."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, height / 2.0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, depth, height)
    obj.data.materials.append(mat)
    return obj


# Cover row between you and the targets: tall walls hide them completely,
# low walls (1 m) leave head and shoulders visible.
box("wall_tall_left", -6.0, 10.0, 3.0, 0.4, 2.6)
box("wall_low_left", -3.0, 10.0, 3.0, 0.4, 1.0)
box("wall_tall_mid", 0.0, 10.0, 3.0, 0.4, 2.6)
box("wall_low_right", 3.0, 10.0, 3.0, 0.4, 1.0)
box("wall_tall_right", 6.0, 10.0, 3.0, 0.4, 2.6)

# Crates on your side to slide between and jump on.
box("crate_left", -4.0, 1.0, 1.2, 1.2, 1.2)
box("crate_right", 5.0, 3.0, 1.2, 1.2, 1.2)

# Guides (not exported into the game).
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 9.0, 0.0))
floor = bpy.context.active_object
floor.name = "ref_floor"
floor.scale = (40.0, 34.0, 1.0)
bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=1.8, location=(0.0, 0.0, 0.9))
you = bpy.context.active_object
you.name = "ref_you"
you.data.materials.append(GUIDE)
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 14.0, 0.01))
lane = bpy.context.active_object
lane.name = "ref_target_lane"
lane.scale = (16.0, 4.0, 1.0)
lane.data.materials.append(GUIDE)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "cover_map.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, "cover_map.glb"), export_format="GLB")
print("MAP OK:", [o.name for o in bpy.data.objects])
