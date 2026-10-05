## Makes the cloth piece of each part: a copy of the fitted MPFB cloth, cut to the top or legs
## half when the source is a one-piece suit, optionally smoothed once (very low-poly pants).
import bpy
import bmesh

import human_config as C

LEG_BONES = set(C.SLOT_BONES["Legs"]) | set(C.SLOT_BONES["Feet"])


def copy_object(obj, name):
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = new.data.name = name
    for coll in obj.users_collection:
        coll.objects.link(new)
    return new


def strongest_bone(obj, rig):
    """For each vertex: the name of the bone that moves it most (or None)."""
    names = {g.index: g.name for g in obj.vertex_groups}
    out = []
    for v in obj.data.vertices:
        best = max(((g.weight, names[g.group]) for g in v.groups if names[g.group] in rig.data.bones), default=(0, None))
        out.append(best[1])
    return out


def _components(bm):
    seen, comps = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        comps.append(comp)
    return comps


def keep_half(obj, rig, keep):
    """One-piece suits (shirt + jeans) are separate loose parts: keep the 'top' or 'legs' ones.
    A loose part is 'legs' when most of its vertices follow leg bones."""
    bones = strongest_bone(obj, rig)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    drop = []
    for comp in _components(bm):
        legs = sum(1 for v in comp if bones[v.index] in LEG_BONES) / len(comp) > 0.6
        if legs != (keep == "legs"):
            drop.extend(comp)
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def smooth_once(obj):
    """Bake one level of Catmull-Clark (weights and UVs follow) for meshes that are too blocky."""
    mod = obj.modifiers.new("smooth", "SUBSURF")
    mod.levels = 1
    mod.uv_smooth = "PRESERVE_BOUNDARIES"
    bpy.context.view_layer.objects.active = obj
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_move_to_index(modifier="smooth", index=0)
        bpy.ops.object.modifier_apply(modifier="smooth")


def flatten_hems(obj, below=1.15, steps=12):
    """MPFB fitting can leave a saw-tooth bottom hem on loose tops. Even out the height of every
    open edge below `below` metres along its loop (height only, so the cloth does not shrink)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    ring = {}
    for e in bm.edges:
        if e.is_boundary and max(v.co.z for v in e.verts) < below:
            a, b = e.verts
            ring.setdefault(a.index, []).append(b.index)
            ring.setdefault(b.index, []).append(a.index)
    me = obj.data
    for _ in range(steps):
        z = {i: me.vertices[i].co.z for i in ring}
        for i, nb in ring.items():
            me.vertices[i].co.z = 0.5 * z[i] + 0.5 * sum(z[j] for j in nb) / len(nb)
    bm.free()
    me.update()


def make(part, objs, rig):
    src = objs["Cloth_" + part["cloth"]]
    piece = copy_object(src, part["prefix"] + "_cloth")
    if part.get("keep"):
        keep_half(piece, rig, part["keep"])
    if part.get("smooth"):
        smooth_once(piece)
    if part["slot"] == "Top":
        flatten_hems(piece)
    return piece
