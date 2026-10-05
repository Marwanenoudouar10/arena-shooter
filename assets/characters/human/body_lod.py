## Lowers the triangle count of the body skin where it is densest (the fingers), so a full
## character stays near 30k triangles. Only vertices well inside the hands may move; everything
## else, including where the hands meet the arms, keeps its exact shape.
import bpy

import pieces

HAND_WORDS = ("hand_", "thumb_", "index_", "middle_", "ring_", "pinky_")


def _hand_verts(body, rig):
    bones = pieces.strongest_bone(body, rig)
    hand = {i for i, b in enumerate(bones) if b and b.startswith(HAND_WORDS)}
    adj = [set() for _ in body.data.vertices]
    for e in body.data.edges:
        a, b = e.vertices
        adj[a].add(b)
        adj[b].add(a)
    return {i for i in hand if adj[i] <= hand}  # one ring in from the wrist stays fixed


def thin_hands(body, rig, keep=0.45):
    """Collapse edges inside the hands until about keep of their faces are left."""
    verts = _hand_verts(body, rig)
    group = body.vertex_groups.new(name="lod_hands")
    group.add(list(verts), 1.0, "REPLACE")
    hand_tris = sum(len(p.vertices) - 2 for p in body.data.polygons if all(i in verts for i in p.vertices))
    before = sum(len(p.vertices) - 2 for p in body.data.polygons)
    mod = body.modifiers.new("lod", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = (before - hand_tris * (1.0 - keep)) / before  # the ratio counts triangles
    mod.vertex_group = group.name  # weight 0 (everything outside the hands) never collapses
    mod.use_collapse_triangulate = True
    with bpy.context.temp_override(object=body, active_object=body):
        bpy.ops.object.modifier_move_to_index(modifier="lod", index=0)
        bpy.ops.object.modifier_apply(modifier="lod")
    body.vertex_groups.remove(body.vertex_groups["lod_hands"])
    after = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("LOD hands: body %d -> %d triangles" % (before, after))
