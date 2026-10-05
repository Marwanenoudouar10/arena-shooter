## Layering maths: which vertices of a mesh are hidden under another mesh (so they can be cut
## away), and pushing an outer layer out over an inner one so nothing pokes through.
import bmesh
from mathutils.bvhtree import BVHTree


def tree(obj):
    me = obj.data
    return BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])


def neighbours(obj):
    adj = [set() for _ in obj.data.vertices]
    for e in obj.data.edges:
        a, b = e.vertices
        adj[a].add(b)
        adj[b].add(a)
    return adj


def hidden_verts(inner, outer_tree, reach=0.05, back=0.02):
    """Vertices of inner that sit under the outer mesh: a ray along the vertex normal (started
    `back` below the surface, to catch skin poking out a little) meets the INSIDE of the outer
    mesh within reach metres."""
    out = set()
    for v in inner.data.vertices:
        n = v.normal
        loc, normal, _, _ = outer_tree.ray_cast(v.co - n * back, n, reach + back)
        if loc is not None and normal.dot(n) > 0.0:
            out.add(v.index)
    return out


def erode(adj, verts, rings=1):
    """Shrink a vertex set by rings, so a strip stays under every cloth opening (no gaps)."""
    for _ in range(rings):
        verts = {v for v in verts if adj[v] <= verts}
    return verts


def faces_inside(obj, verts):
    """Polygons whose corners are all in verts."""
    return {p.index for p in obj.data.polygons if all(i in verts for i in p.vertices)}


def delete_faces(obj, faces):
    """Remove the given polygons and any vertex left without a face."""
    if not faces:
        return
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in faces], context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def push_out(outer, inners, zone, margin=0.007, smooth=4):
    """Move outer's vertices (only those with zone(co) true) outside every inner mesh by at least
    margin metres, then smooth the moves so the cloth stays a clean shape."""
    me = outer.data
    idx = [v.index for v in me.vertices if zone(v.co)]
    trees = [tree(o) for o in inners]
    adj = neighbours(outer)
    for _ in range(2):
        move = {i: me.vertices[i].co * 0.0 for i in idx}
        for i in idx:
            co = me.vertices[i].co + move[i]
            for t in trees:
                loc, normal, _, dist = t.find_nearest(co, 0.08)
                if loc is None:
                    continue
                side = (co - loc).dot(normal)
                if side < margin:
                    co = co + normal * (margin - side)
            move[i] = co - me.vertices[i].co
        for _ in range(smooth):  # average each move with its neighbours, never pulling inwards
            new = {}
            for i in idx:
                ring = [move[j] for j in adj[i] if j in move] + [move[i]]
                avg = sum(ring, move[i] * 0.0) / len(ring)
                new[i] = avg if avg.length > move[i].length else move[i]
            move = new
        for i in idx:
            me.vertices[i].co += move[i]
    me.update()
    return len([i for i in idx if move[i].length > 1e-5])
