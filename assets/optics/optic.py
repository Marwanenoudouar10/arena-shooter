"""Scene assembly: the Optic class collects the parts of one optic into named groups
(body, mount, lens_front, ...), cuts holes with booleans, adds the marker Empties, then
joins each group into one object and saves <name>.blend / exports <name>.glb.
"""
import math
import os

import bpy
from mathutils import Vector

from materials import make_materials

HERE = os.path.dirname(os.path.abspath(__file__))
SHARP_ANGLE = math.radians(40)  # edges sharper than this shade hard


class Optic:
    def __init__(self, name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.name = name
        self.mats = make_materials()
        self.groups = {}  # group name -> list of objects

    def add(self, bm, mats, group="body", cutters=()):
        """Turns a bmesh into an object in group, using material keys mats[index]."""
        mesh = bpy.data.meshes.new(group)
        bm.to_mesh(mesh)
        bm.free()
        for key in mats:
            mesh.materials.append(self.mats[key])
        obj = bpy.data.objects.new(group, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for cut in cutters:
            self._cut(obj, cut)
        self.groups.setdefault(group, []).append(obj)
        return obj

    def _cut(self, obj, cutter_bm):
        cme = bpy.data.meshes.new("cutter")
        cutter_bm.to_mesh(cme)
        cutter_bm.free()
        cutter = bpy.data.objects.new("cutter", cme)
        bpy.context.scene.collection.objects.link(cutter)
        mod = obj.modifiers.new("cut", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cutter
        with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter)
        bpy.data.meshes.remove(cme)

    def empty(self, name, loc, size=0.01):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = size
        e.location = loc
        bpy.context.scene.collection.objects.link(e)
        return e

    def finish(self):
        """Joins each group into one object, sets hard-surface normals, saves and exports."""
        tris = 0
        for group, objs in self.groups.items():
            target = objs[0]
            if len(objs) > 1:
                with bpy.context.temp_override(active_object=target, object=target,
                                               selected_objects=objs, selected_editable_objects=objs):
                    bpy.ops.object.join()
            target.name = group
            target.data.name = group
            me = target.data
            me.shade_smooth()
            me.set_sharp_from_angle(angle=SHARP_ANGLE)
            if group not in ("reticle", "lens_front", "lens_rear"):
                mod = target.modifiers.new("wn", "WEIGHTED_NORMAL")
                mod.keep_sharp = True
                mod.weight = 50
                mod.mode = "FACE_AREA"
                with bpy.context.temp_override(object=target, active_object=target, selected_objects=[target]):
                    bpy.ops.object.modifier_apply(modifier=mod.name)
            me.calc_loop_triangles()
            n = len(me.loop_triangles)
            tris += n
            print(f"  {self.name}/{group}: {n} tris")
        dims = self._bounds()
        print(f"OPTIC {self.name}: {tris} tris, size {dims}")
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, self.name + ".blend"))
        bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, self.name + ".glb"),
                                  export_format="GLB", export_apply=True, export_yup=True)

    def _bounds(self):
        lo = Vector((1e9, 1e9, 1e9))
        hi = -lo
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH":
                continue
            for v in obj.data.vertices:
                p = obj.matrix_world @ v.co
                lo = Vector(map(min, lo, p))
                hi = Vector(map(max, hi, p))
        return tuple(round(c, 4) for c in (hi - lo)), tuple(round(c, 4) for c in lo), tuple(round(c, 4) for c in hi)
