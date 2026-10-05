"""Small ready-made parts used by more than one optic: screws, nuts, lenses, turret
index marks and the Picatinny rail clamp outline. Each returns a bmesh or an outline.
"""
import math

import bmesh
from mathutils import Matrix, Vector

from meshes import frame_matrix, lathe
from profiles import TAU, P, fillet, hexagon


def cap_screw(center, axis, r, h, segs=18, mat=0):
    """Socket-head screw: round head with a hexagon socket. Base sits at center."""
    rs = r * 0.48
    pts = [P(0.0, 0.0, m=mat), P(0.0, r, m=mat), P(h, r, r * 0.22, 1, m=mat),
           P(h, rs, m=1, sh=hexagon), P(h - r * 0.55, rs, m=1, sh=hexagon), P(h - r * 0.55, 0.0, m=1)]
    return lathe(pts, axis, center, segs=segs)


def lens(center_x, radius, thick, front_sag, rear_sag, axis_z, segs=40):
    """Lens disc along X: front surface bulges by front_sag, rear by rear_sag."""
    xf, xb = center_x + thick / 2, center_x - thick / 2
    rings = [0.0, 0.5, 0.85, 1.0]
    pts = [P(xf + front_sag, 0.0)]
    pts += [P(xf + front_sag * (1 - k * k), radius * k) for k in rings[1:]]
    pts += [P(xb - rear_sag * (1 - k * k), radius * k) for k in reversed(rings[1:])]
    pts += [P(xb - rear_sag, 0.0)]
    return lathe(pts, (1, 0, 0), (0, 0, axis_z), segs=segs)


def hash_marks(center, axis, radius, z_top, count, major_every, minor_len, major_len,
               phase=0.0, width=0.00045, proud=0.00012):
    """Painted index marks around a turret skirt (axis = turret axis)."""
    mat = frame_matrix(axis, center)
    bm = bmesh.new()
    r = radius + proud
    for k in range(count):
        th = TAU * k / count + phase  # phase puts mark 0 next to the reference line
        length = major_len if k % major_every == 0 else minor_len
        m = mat @ Matrix.Rotation(th, 4, "X")
        quad = [m @ Vector((a, r, w)) for a, w in ((z_top - length, -width / 2), (z_top, -width / 2),
                                                   (z_top, width / 2), (z_top - length, width / 2))]
        f = bm.faces.new([bm.verts.new(q) for q in quad])
        f.normal_update()
        out = (m.to_3x3() @ Vector((0, 1, 0)))
        if f.normal.dot(out) < 0:
            f.normal_flip()
    return bm


def rail_clamp_outline(top_half, top_z, side_half, jaw_z=-0.0042, chamfer=0.0018):
    """YZ section of a Picatinny clamp: flat underside at z=0, jaws hooking the rail."""
    right = [
        P(0.0090, 0.0),
        P(0.0106, -0.0016),
        P(0.0096, -0.0030),
        P(0.0096, jaw_z, 0.0003, 1),
        P(side_half, jaw_z, 0.0008, 2),
        P(side_half, top_z - chamfer * 2.5, 0.0012, 2),
        P(top_half, top_z, 0.0010, 2),
    ]
    left = [P(-u, v, f, s) for (u, v, f, s, _) in reversed(right)]
    return [(q[0], q[1]) for q in fillet(right + left)]


def hex_nut(center, axis, af, thick, bolt_r, bolt_len):
    """Hex nut sitting at center (base), with the bolt end sticking out of it."""
    rc = af / 2 / math.cos(math.pi / 6)  # circumradius
    pts = [P(0.0, 0.0), P(0.0, af * 0.47), P(thick * 0.12, rc, sh=hexagon),
           P(thick * 0.88, rc, sh=hexagon), P(thick, af * 0.47),
           P(thick, bolt_r), P(thick + bolt_len, bolt_r, bolt_r * 0.3, 1), P(thick + bolt_len, 0.0)]
    return lathe(pts, axis, center, segs=18)


def slotted_head(center, axis, r, h):
    pts = [P(0.0, 0.0), P(0.0, r), P(h, r, h * 0.45, 2), P(h, 0.0)]
    return lathe(pts, axis, center, segs=28)
