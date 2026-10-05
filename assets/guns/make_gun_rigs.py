"""Splits each rifle's magazine into its own object and adds attachment points.

Run:  blender --background --factory-startup --python assets/guns/make_gun_rigs.py

Writes <gun>_rig.blend (to look at / edit) and <gun>_rig.glb (used by the game).
Blender axes: X = along the barrel (+X = muzzle), Z = up, -Y = the gun's right side.
Empties the game looks for:
  socket_grip     right hand on the pistol grip
  socket_hand     left hand on the handguard
  socket_magwell  where the left hand grabs the magazine
  socket_charge   charging handle the left hand pulls
  socket_mount    top of the gun where a red dot / holo / scope sits
  socket_muzzle   end of the barrel (muzzle flash)
  socket_eject    ejection port (shell casings fly out here)
  socket_iron     top of the front sight post (aiming without an optic)
"""
import os
import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))

# Per model: magazine region (faces whose centre is inside it) and socket positions.
RIGS = {
    "rifle_a": {  # M16 style: carry handle on top, charging handle at the back
        "mag": {"x": (0.5, 1.35), "z_max": 0.15},
        "sockets": {
            "socket_grip": (-0.1, 0.0, -0.05), "socket_hand": (1.8, 0.0, 0.4),
            "socket_magwell": (0.9, 0.0, -0.35), "socket_charge": (-0.5, 0.0, 0.78),
            "socket_mount": (0.2, 0.0, 0.95), "socket_muzzle": (3.6, 0.0, 0.64),
            "socket_eject": (0.6, -0.12, 0.6), "socket_iron": (2.52, 0.0, 1.04),
        },
    },
    "rifle_c": {  # AK style: curved magazine, charging handle on the right
        "mag": {"x": (0.7, 1.75), "z_max": 0.3},
        "sockets": {
            "socket_grip": (0.0, 0.0, -0.05), "socket_hand": (2.1, 0.0, 0.38),
            "socket_magwell": (1.2, 0.0, -0.3), "socket_charge": (1.3, -0.14, 0.62),
            "socket_mount": (0.6, 0.0, 0.82), "socket_muzzle": (3.8, 0.0, 0.69),
            "socket_eject": (1.0, -0.12, 0.62), "socket_iron": (3.72, 0.0, 0.84),
        },
    },
}


for name, rig in RIGS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, name + ".glb"))
    body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    body.name = "body"
    # Bake the import transform into the mesh so every part shares one clean origin.
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for other in list(bpy.context.scene.objects):
        if other != body:
            bpy.data.objects.remove(other)

    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(body.data)
    x0, x1 = rig["mag"]["x"]
    count = 0
    for face in bm.faces:
        c = face.calc_center_median()
        face.select = x0 <= c.x <= x1 and c.z <= rig["mag"]["z_max"]
        count += face.select
    bmesh.update_edit_mesh(body.data)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    mag = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != body][0]
    mag.name = "magazine"

    for socket, pos in rig["sockets"].items():
        empty = bpy.data.objects.new(socket, None)
        empty.empty_display_type = "SPHERE"
        empty.empty_display_size = 0.08
        empty.location = pos
        bpy.context.scene.collection.objects.link(empty)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, name + "_rig.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, name + "_rig.glb"), export_format="GLB")
    print("RIG OK %s: magazine faces %d" % (name, count))
