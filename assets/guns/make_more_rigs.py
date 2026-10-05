"""Rigs one gun per weapon type from the Quaternius Ultimate Guns Pack (assets/guns/src).

Run:  blender --background --factory-startup --python assets/guns/make_more_rigs.py
      (add `-- sniper_rig pistol_rig` to rebuild only those)

Same conventions as make_gun_rigs.py: the import transform is baked into one mesh
called "body" (origin unchanged, native units), moving parts are split off as their
own mesh objects by face-centre region, and socket_* Empties mark attachment points.
Writes <rig>.blend (to look at / edit) and <rig>.glb (used by the game).

Blender axes: X = along the barrel (+X = muzzle), Z = up, -Y = the gun's right side.

Moving parts (only the ones a gun has):
  magazine   detachable box magazine (for the pistol this is only the base plate)
  pump       shotgun fore-end, slides back along -X
  bolt       sniper bolt handle + knob
  slide      pistol slide, moves back along -X on each shot
  cylinder   revolver cylinder, swings out to the left (+Y) around socket_cylinder_pivot
  scope      sniper's built-in scope (tube, lenses, rings); hide it to fit another optic
Empties:
  socket_grip      right hand on the pistol grip
  socket_hand      left hand (handguard / foregrip / pump underside; pistol + revolver:
                   front-bottom of the grip where the support hand cups)
  socket_magwell   middle of the magazine (only guns with one)
  socket_charge    what the left hand pulls to chamber (charging handle, bolt knob,
                   pump middle, pistol slide rear, revolver hammer spur)
  socket_mount     top of the gun where an optic sits (centre line)
  socket_muzzle    end of the barrel, centre (muzzle flash)
  socket_eject     ejection port, right side (shell casings fly out here)
  socket_iron      top of the front sight (aiming without an optic)
  socket_cylinder_pivot  revolver only: crane hinge, axis parallel to X
"""
import os
import sys
import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")


def box(x=None, y=None, z=None, mats=None, max_size=None):
    """A face matches when its centre lies inside every given range, its material is in
    `mats` (if given) and its own size per axis is at most `max_size` (if given; keeps
    long body faces whose centre happens to land inside a small part's box out of it)."""
    return {"x": x, "y": y, "z": z, "mats": mats, "max_size": max_size}


# keep = boxes that select faces for the part, drop = boxes that veto faces again.
RIGS = {
    "smg_rig": {  # submachine_gun_1: MP7 style, straight magazine in front of the grip, foregrip
        "src": "submachine_gun_1",
        "parts": {
            "magazine": {"keep": [box(x=(0.615, 0.95), y=(-0.08, 0.08), z=(-0.80, 0.275),
                                      max_size=(0.35, None, None))]},
        },
        "sockets": {
            "socket_grip": (0.0, 0.0, -0.1), "socket_hand": (1.51, 0.0, 0.05),
            "socket_magwell": (0.77, 0.0, -0.37), "socket_charge": (-0.27, 0.0, 0.65),
            "socket_mount": (0.55, 0.0, 0.72), "socket_muzzle": (2.12, 0.0, 0.475),
            "socket_eject": (0.5, -0.16, 0.55), "socket_iron": (1.70, 0.0, 0.775),
        },
    },
    "sniper_rig": {  # sniper_rifle_3: AWP style bolt action, thumbhole stock
        "src": "sniper_rifle_3",
        "parts": {
            "bolt": {"keep": [box(x=(0.295, 0.365), y=(-0.31, 0.09), z=(0.26, 0.49),
                                  mats=["DarkMetal"], max_size=(0.1, None, None))]},
            # Built-in scope: tube (Black, above the rail's notch tops at z 0.53), lenses
            # (Glass) and the two rings with their posts (DarkMetal, rings at x 0.68 / 1.29).
            # The rail (Black notches + DarkMetal base, z <= 0.53) stays on the body.
            "scope": {"keep": [
                box(x=(-0.1, 2.3), y=(-0.2, 0.2), z=(0.54, 0.9), mats=["Black"]),
                box(x=(-0.1, 2.3), y=(-0.2, 0.2), z=(0.5, 0.9), mats=["Glass"]),
                box(x=(0.655, 0.705), y=(-0.035, 0.035), z=(0.44, 0.62), mats=["DarkMetal"],
                    max_size=(0.1, 0.07, None)),  # rear ring post (runs down into the rail)
                box(x=(0.635, 0.725), y=(-0.2, 0.2), z=(0.58, 0.8), mats=["DarkMetal"],
                    max_size=(0.15, None, None)),  # rear ring
                box(x=(1.265, 1.315), y=(-0.035, 0.035), z=(0.44, 0.62), mats=["DarkMetal"],
                    max_size=(0.1, 0.07, None)),  # front ring post
                box(x=(1.245, 1.345), y=(-0.2, 0.2), z=(0.58, 0.8), mats=["DarkMetal"],
                    max_size=(0.15, None, None)),  # front ring
            ]},
        },
        "sockets": {
            "socket_grip": (-0.03, 0.0, -0.05), "socket_hand": (1.9, 0.0, 0.12),
            "socket_charge": (0.33, -0.27, 0.29), "socket_mount": (0.985, 0.0, 0.53),
            "socket_muzzle": (5.31, 0.0, 0.405), "socket_eject": (0.99, -0.03, 0.425),  # port recess
            "socket_iron": (5.30, 0.0, 0.49),
        },
    },
    "pistol_rig": {  # pistol_4: polymer service pistol (USP / P99 style)
        "src": "pistol_4",
        "parts": {
            "slide": {"keep": [box(x=(-0.36, 1.40), y=(-0.15, 0.15), z=(0.385, 0.76),
                                   mats=["LightMetal", "Metal"])],
                      "drop": [box(x=(-0.40, -0.22), y=(-0.05, 0.05), z=(0.5, 0.7),
                                   mats=["Metal"])]},  # hammer stays on the frame
            "magazine": {"keep": [box(x=(-0.31, -0.18), y=(-0.115, 0.115), z=(-0.43, -0.24),
                                      mats=["Black"]),
                                  box(x=(-0.21, 0.14), y=(-0.115, 0.115), z=(-0.49, -0.395),
                                      mats=["Black"])]},
        },
        "sockets": {
            "socket_grip": (-0.06, 0.0, -0.1), "socket_hand": (0.12, 0.0, -0.25),
            "socket_magwell": (-0.07, 0.0, -0.42), "socket_charge": (-0.2, 0.0, 0.58),
            "socket_mount": (0.1, 0.0, 0.67), "socket_muzzle": (1.45, 0.0, 0.56),
            "socket_eject": (0.4, -0.13, 0.6), "socket_iron": (1.27, 0.0, 0.72),
        },
    },
    "revolver_rig": {  # revolver_3: heavy magnum with full-length rail and underlug
        "src": "revolver_3",
        "parts": {
            "cylinder": {"keep": [box(x=(0.35, 0.76), y=(-0.16, 0.16), z=(0.15, 0.55),
                                      mats=["LightMetal"])]},
        },
        "sockets": {
            "socket_grip": (-0.03, 0.0, -0.05), "socket_hand": (0.06, 0.0, -0.2),
            "socket_charge": (0.1, 0.0, 0.47), "socket_mount": (0.9, 0.0, 0.58),
            "socket_muzzle": (1.77, 0.0, 0.425), "socket_eject": (0.55, -0.155, 0.35),
            "socket_iron": (1.70, 0.0, 0.645), "socket_cylinder_pivot": (0.74, 0.07, 0.2),
        },
    },
    "shotgun_rig": {  # shotgun_2: Remington 870 style pump, wooden stock and fore-end
        "src": "shotgun_2",
        "parts": {
            "pump": {"keep": [box(x=(1.6, 2.6), y=(-0.15, 0.15), z=(-0.2, 0.2), mats=["Wood"])]},
        },
        "sockets": {
            "socket_grip": (0.05, 0.0, -0.03), "socket_hand": (2.1, 0.0, -0.14),
            "socket_charge": (2.1, 0.0, 0.0), "socket_mount": (0.85, 0.0, 0.31),
            "socket_muzzle": (4.31, 0.0, 0.215), "socket_eject": (0.93, -0.1, 0.185),
            "socket_iron": (3.82, 0.0, 0.345),
        },
    },
    "bullpup_rig": {  # bullpup_1: magazine behind the grip, long top rail, foregrip
        "src": "bullpup_1",
        "parts": {
            "magazine": {"keep": [box(x=(-1.25, -0.75), y=(-0.07, 0.07), z=(-0.35, 0.34),
                                      mats=["MainLight"]),
                                  box(x=(-1.25, -0.85), y=(-0.07, 0.07), z=(-0.35, -0.2),
                                      mats=["MainDark"])]},
        },
        "sockets": {
            "socket_grip": (0.05, 0.0, 0.05), "socket_hand": (2.04, 0.0, 0.35),
            "socket_magwell": (-1.0, 0.0, 0.02), "socket_charge": (0.9, 0.13, 0.85),
            "socket_mount": (0.3, 0.0, 1.1), "socket_muzzle": (2.72, 0.0, 0.815),
            "socket_eject": (-0.6, -0.13, 0.8), "socket_iron": (2.25, 0.0, 1.11),
        },
    },
}


def matches(b, centre, size, mat):
    for axis, i in (("x", 0), ("y", 1), ("z", 2)):
        rng = b[axis]
        if rng and not rng[0] <= centre[i] <= rng[1]:
            return False
        if b["max_size"] and b["max_size"][i] is not None and size[i] > b["max_size"][i]:
            return False
    return not b["mats"] or mat in b["mats"]


def split_part(body, name, spec):
    """Moves the faces chosen by `spec` out of `body` into a new mesh object `name`."""
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.tool_settings.mesh_select_mode = (False, False, True)
    bm = bmesh.from_edit_mesh(body.data)
    bm.select_mode = {"FACE"}
    for elem in (*bm.verts, *bm.edges, *bm.faces):
        elem.select = False
    mats = [m.name if m else "" for m in body.data.materials]
    count = 0
    for face in bm.faces:
        c = face.calc_center_median()
        lo = [min(v.co[i] for v in face.verts) for i in range(3)]
        hi = [max(v.co[i] for v in face.verts) for i in range(3)]
        size = [hi[i] - lo[i] for i in range(3)]
        mat = mats[face.material_index] if face.material_index < len(mats) else ""
        keep = any(matches(b, c, size, mat) for b in spec["keep"])
        if keep and not any(matches(b, c, size, mat) for b in spec.get("drop", [])):
            face.select = True
            count += 1
    bm.select_flush_mode()
    bmesh.update_edit_mesh(body.data)
    before = set(bpy.context.scene.objects)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    part = (set(bpy.context.scene.objects) - before).pop()
    part.name = name
    part.data.name = name
    return part, count


# Optional: build only some rigs, e.g. `... --python make_more_rigs.py -- sniper_rig`.
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

for rig_name, rig in RIGS.items():
    if ONLY and rig_name not in ONLY:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, rig["src"] + ".glb"))
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
    total = len(body.data.polygons)

    report = []
    for part_name, spec in rig["parts"].items():
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = body
        body.select_set(True)
        part, count = split_part(body, part_name, spec)
        assert count == len(part.data.polygons), (part_name, count, len(part.data.polygons))
        report.append("%s %d faces" % (part_name, count))

    for socket, pos in rig["sockets"].items():
        empty = bpy.data.objects.new(socket, None)
        empty.empty_display_type = "SPHERE"
        empty.empty_display_size = 0.04
        empty.location = pos
        bpy.context.scene.collection.objects.link(empty)

    xs = [v.co.x for o in bpy.context.scene.objects if o.type == "MESH" for v in o.data.vertices]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, rig_name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, rig_name + ".glb"), export_format="GLB")
    print("RIG OK %s (from %s): %s, body %d of %d faces, length %.2f (x %.2f..%.2f)" % (
        rig_name, rig["src"], ", ".join(report), len(body.data.polygons), total,
        max(xs) - min(xs), min(xs), max(xs)))
