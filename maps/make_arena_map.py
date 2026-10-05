"""Builds the big arena and exports it for the trainer.

Run:  blender --background --factory-startup --python maps/make_arena_map.py

Blender axes -> game: X = left/right, +Y = forward from the spawn, Z = up.
Every mesh is a box for the game (bullets and walking), so only rotate in 90° steps.
Names with special meaning:
  zone_*        areas where enemies walk (zone_flicks = where flick targets float)
  spawn_player  where you start, facing +Y
  ref_*         guides only
Everything else is solid.
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


CONCRETE = material("Concrete", (0.62, 0.6, 0.55, 1.0))
BUILDING = material("Building", (0.45, 0.5, 0.58, 1.0))
CRATE = material("Crate", (0.86, 0.52, 0.14, 1.0))
FLOOR = material("Floor", (0.44, 0.44, 0.45, 1.0))
ZONE = material("Zone", (0.2, 0.5, 1.0, 1.0))


def box(name, cx, cy, cz, sx, sy, sz, mat=CONCRETE):
    """Box centred on (cx, cy, cz) with size (sx, sy, sz), metres."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cz))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (sx, sy, sz)
    obj.data.materials.append(mat)
    return obj


def on_floor(name, cx, cy, sx, sy, height, mat=CONCRETE):
    return box(name, cx, cy, height / 2.0, sx, sy, height, mat)


# Floor and outer walls: x -30..30, y -10..50.
box("floor", 0, 20, -0.1, 60, 60, 0.2, FLOOR)
box("outer_south", 0, -10.5, 4, 62, 1, 8, BUILDING)
box("outer_north", 0, 50.5, 4, 62, 1, 8, BUILDING)
box("outer_west", -30.5, 20, 4, 1, 62, 8, BUILDING)
box("outer_east", 30.5, 20, 4, 1, 62, 8, BUILDING)

# Warehouse (west): 12 x 12 m, 5 m tall, door facing the middle, flat roof.
box("warehouse_west", -23.8, 20, 2.5, 0.4, 12, 5, BUILDING)
box("warehouse_north", -18, 25.8, 2.5, 12, 0.4, 5, BUILDING)
box("warehouse_south", -18, 14.2, 2.5, 12, 0.4, 5, BUILDING)
box("warehouse_east_a", -12.2, 16.4, 2.5, 0.4, 4.8, 5, BUILDING)
box("warehouse_east_b", -12.2, 23.6, 2.5, 0.4, 4.8, 5, BUILDING)
box("warehouse_door_top", -12.2, 20, 3.8, 0.4, 2.4, 2.4, BUILDING)
box("warehouse_roof", -18, 20, 5.15, 12.4, 12.4, 0.3, BUILDING)
# Stairs to the roof along the south side: 18 steps of 0.3 m, rising westward.
for i in range(18):
    top = 0.3 * (i + 1)
    x0 = -1.2 - 0.6 * (i + 1)
    on_floor("roof_step_%02d" % i, x0 + 0.3, 13.25, 0.6, 1.3, top)

# Platform (east): deck at 3 m on four pillars, railings, stairs from the south.
box("deck", 18, 23, 2.85, 12, 10, 0.3, BUILDING)
for i, (px, py) in enumerate([(12.5, 18.5), (23.5, 18.5), (12.5, 27.5), (23.5, 27.5)]):
    on_floor("deck_pillar_%d" % i, px, py, 0.5, 0.5, 2.7, BUILDING)
box("deck_rail_north", 18, 27.8, 3.5, 12, 0.3, 1.0)
box("deck_rail_west", 12.2, 25, 3.5, 0.3, 6, 1.0)
box("deck_rail_east", 23.8, 23, 3.5, 0.3, 10, 1.0)
for i in range(10):
    top = 0.3 * (i + 1)
    on_floor("deck_step_%02d" % i, 12.75, 12 + 0.6 * i + 0.3, 1.5, 0.6, top)

# Middle: container, tall walls, low walls, crates.
on_floor("container", 0, 26, 2.5, 6.5, 2.6, CRATE)
on_floor("wall_tall_a", 0, 16, 5, 0.4, 2.6)
on_floor("wall_tall_b", -10, 38, 5, 0.4, 2.6)
on_floor("wall_tall_c", 12, 38, 5, 0.4, 2.6)
on_floor("wall_low_a", -6, 12, 4, 0.4, 1.0)
on_floor("wall_low_b", 6, 12, 4, 0.4, 1.0)
on_floor("wall_low_c", -3, 34, 4, 0.4, 1.0)
on_floor("wall_low_d", 5, 36, 4, 0.4, 1.0)
for i, (cx, cy, size) in enumerate([(-4, 4, 1.2), (4.5, 7, 1.2), (8, 22, 1.2), (-8, 28, 1.2), (2, 42, 1.5)]):
    on_floor("crate_%d" % i, cx, cy, size, size, size, CRATE)

# Where enemies walk (thin boxes; the bottom is the ground they stand on).
box("zone_far", 0, 44, 0.05, 24, 8, 0.1, ZONE)
box("zone_mid", 0, 32, 0.05, 20, 4, 0.1, ZONE)
box("zone_platform", 18.5, 23.5, 3.05, 9, 7, 0.1, ZONE)
box("zone_roof", -18, 20, 5.35, 10, 10, 0.1, ZONE)
box("zone_flicks", 0, 20, 4.5, 16, 4, 3, ZONE)

bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=1.8, location=(0, 6, 0.9))
spawn = bpy.context.active_object
spawn.name = "spawn_player"
spawn.data.materials.append(ZONE)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "arena_map.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, "arena_map.glb"), export_format="GLB")
print("ARENA OK:", len(bpy.data.objects), "objects")
