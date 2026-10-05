"""Mesh builders. Each one returns a new bmesh: lathe (revolve a profile), prism and
frame_prism (extrude an outline), box, flat discs, plus small helpers to place and
bevel them.
"""
import math

import bmesh
from mathutils import Matrix, Vector

from profiles import fillet, uniform


def frame_matrix(axis, center):
    """Matrix whose local X points along axis, placed at center."""
    ax = Vector(axis).normalized()
    hint = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((1, 0, 0))
    y = hint.cross(ax).normalized()
    z = ax.cross(y)
    m = Matrix((ax, y, z)).transposed().to_4x4()
    m.translation = Vector(center)
    return m


def lathe(points, axis=(1, 0, 0), center=(0, 0, 0), angles=None, segs=48, closed=True):
    """Revolves a profile of P(along_axis, radius, ...) points around an axis.
    Points with radius 0 become poles. Returns bmesh."""
    prof = fillet(points, closed)
    angles = angles or uniform(segs)
    mat = frame_matrix(axis, center)
    bm = bmesh.new()
    rings = []
    for x, r, (m, shape) in prof:
        if r < 1e-7:
            rings.append([bm.verts.new(mat @ Vector((x, 0, 0)))])
            continue
        ring = []
        for j, th in enumerate(angles):
            rr = shape(r, th, j) if shape else r
            ring.append(bm.verts.new(mat @ Vector((x, rr * math.cos(th), rr * math.sin(th)))))
        rings.append(ring)
    n = len(rings)
    s = len(angles)
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        if len(a) == 1 and len(b) == 1:
            continue
        for j in range(s):
            j2 = (j + 1) % s
            if len(a) == 1:
                vs = (a[0], b[j2], b[j])
            elif len(b) == 1:
                vs = (a[j], a[j2], b[0])
            else:
                vs = (a[j], a[j2], b[j2], b[j])
            f = bm.faces.new(vs)
            f.material_index = prof[i][2][0]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def bevel_sharp(bm, offset, segs=3, thresh=math.radians(40)):
    if offset <= 0:
        return
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > thresh]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segs, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


def _to3(axis, a, b, t):
    return {"X": (t, a, b), "Y": (a, t, b), "Z": (a, b, t)}[axis]


def prism(outline, axis, t0, t1, bevel=0.0, segs=3, mat=0):
    """Extrudes a 2D outline along axis from t0 to t1.
    Outline coords: axis X -> (y, z), Y -> (x, z), Z -> (x, y)."""
    bm = bmesh.new()
    front = [bm.verts.new(_to3(axis, a, b, t1)) for a, b in outline]
    back = [bm.verts.new(_to3(axis, a, b, t0)) for a, b in outline]
    n = len(outline)
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))
    for f in bm.faces:
        f.material_index = mat
    bevel_sharp(bm, bevel, segs)
    return bm


def frame_prism(outer, inner, axis, t0, t1, bevel=0.0, segs=3, warp=None):
    """Extrudes the ring between two outlines with matching point counts (a frame).
    warp(co) may move vertices (e.g. slant the ends) before the bevel."""
    assert len(outer) == len(inner)
    bm = bmesh.new()
    of = [bm.verts.new(_to3(axis, a, b, t1)) for a, b in outer]
    ob = [bm.verts.new(_to3(axis, a, b, t0)) for a, b in outer]
    inf = [bm.verts.new(_to3(axis, a, b, t1)) for a, b in inner]
    inb = [bm.verts.new(_to3(axis, a, b, t0)) for a, b in inner]
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((of[i], of[j], inf[j], inf[i]))
        bm.faces.new((ob[i], ob[j], inb[j], inb[i]))
        bm.faces.new((of[i], of[j], ob[j], ob[i]))
        bm.faces.new((inf[i], inf[j], inb[j], inb[i]))
    if warp:
        for v in bm.verts:
            v.co = warp(v.co)
    bevel_sharp(bm, bevel, segs)
    return bm


def box(size, center, bevel=0.0, segs=3, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bevel,
                        segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def transform(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def disc_facing(center, radius, normal, segs=24, inner=0.0):
    """Flat disc (or ring when inner > 0) facing normal; used for reticles."""
    mat = frame_matrix(normal, center)
    bm = bmesh.new()
    angles = uniform(segs)
    outer = [bm.verts.new(mat @ Vector((0, radius * math.cos(a), radius * math.sin(a)))) for a in angles]
    if inner > 0:
        inn = [bm.verts.new(mat @ Vector((0, inner * math.cos(a), inner * math.sin(a)))) for a in angles]
        for j in range(segs):
            j2 = (j + 1) % segs
            bm.faces.new((outer[j], outer[j2], inn[j2], inn[j]))
    else:
        bm.faces.new(outer)
    n = Vector(normal).normalized()
    for f in bm.faces:
        f.normal_update()
        if f.normal.dot(n) < 0:
            f.normal_flip()
    return bm
