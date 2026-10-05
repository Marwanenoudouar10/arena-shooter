## Turns the live MPFB human into plain game meshes: shape keys applied, helper geometry and mask
## modifiers removed, then everything scaled so he is exactly HEIGHT tall with his feet at z=0.
import bmesh
from mathutils import Matrix

import human_config as C


def _apply_shape_keys(obj):
    """Freeze the current shape-key mix into the mesh and drop the keys."""
    if obj.data.shape_keys is None:
        return
    mix = obj.shape_key_add(name="mix", from_mix=True)
    coords = [p.co.copy() for p in mix.data]
    obj.shape_key_clear()
    for v, co in zip(obj.data.vertices, coords):
        v.co = co


def _delete_helpers(body):
    """MakeHuman hides helper geometry (tights, skirt, hair caps) with the 'body' group. Delete it."""
    index = body.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(body.data)
    deform = bm.verts.layers.deform.verify()
    helpers = [v for v in bm.verts if v[deform].get(index, 0.0) < 0.5]
    bmesh.ops.delete(bm, geom=helpers, context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    for group in list(body.vertex_groups):
        name = group.name
        if name.startswith(("helper-", "joint-")) or name in ("HelperGeometry", "JointCubes", "Left", "Mid", "Right", "body"):
            body.vertex_groups.remove(group)


def bake(rig, objs):
    for obj in objs.values():
        for mod in list(obj.modifiers):
            if mod.type != "ARMATURE":
                obj.modifiers.remove(mod)  # masks (helpers, delete groups) and any subdivision
        _apply_shape_keys(obj)
        if obj.matrix_world != Matrix.Identity(4):
            raise RuntimeError("%s is not at the origin" % obj.name)
    _delete_helpers(objs["Body"])
    rig.name = rig.data.name = C.RIG_NAME
    normalize_height(rig, objs)


def body_range(body):
    zs = [v.co.z for v in body.data.vertices]
    return min(zs), max(zs)


def normalize_height(rig, objs):
    """Scale meshes and bones (data, not objects) so the body is HEIGHT tall and stands on z=0."""
    low, high = body_range(objs["Body"])
    s = C.HEIGHT / (high - low)
    m = Matrix.Translation((0.0, 0.0, -low * s)) @ Matrix.Scale(s, 4)
    for obj in objs.values():
        obj.data.transform(m)
        obj.data.update()
    rig.data.transform(m)
    low, high = body_range(objs["Body"])
    print("HEIGHT body %.4f..%.4f m (scale %.4f)" % (low, high, s))


def check_facing(rig):
    """Toes must be in front of the ankles along -Y (so he faces +Z in Godot after glTF export)."""
    bones = rig.data.bones
    toe, ankle = bones["ball_l"].head_local, bones["foot_l"].head_local
    if not toe.y < ankle.y:
        raise RuntimeError("character does not face -Y")
    print("FACING -Y ok (toe y %.3f < ankle y %.3f)" % (toe.y, ankle.y))
