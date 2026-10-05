"""Holographic sight (EOTech EXPS class): a hood around a square window with the ring
and dot reticle, a boxy housing with rear buttons and a side battery cap, and a base
with a QD lever on the right.
"""
import math

import bpy
from mathutils import Matrix, Vector

from meshes import box, disc_facing, frame_prism, lathe, prism, transform
from optic import Optic
from parts import cap_screw, rail_clamp_outline
from profiles import P, fillet, flute, flute_angles, rrect


def build_holo():
    o = Optic("holo")
    H = 0.0400                   # window centre / optical axis height
    WY, WZ0, WZ1 = 0.0150, 0.0285, 0.0515
    HX0, HX1 = -0.0140, 0.0400   # hood length (at the bottom; the ends lean in toward the top)
    X_RET = 0.0120               # reticle plane

    # Hood: a thick rounded frame around the window.
    outer = rrect(0.0, (0.0200 + 0.0570) / 2, 0.0195, (0.0570 - 0.0200) / 2, (0.0012, 0.0012, 0.0068, 0.0068), 6)
    inner = rrect(0.0, (WZ0 + WZ1) / 2, WY, (WZ1 - WZ0) / 2, (0.0022, 0.0022, 0.0030, 0.0030), 6)
    def slant(co):  # front edge leans back, rear edge leans forward: trapezoid side view
        up = max(0.0, co.z - 0.0200)
        if co.x > 0.0:
            return Vector((co.x - 0.17 * up, co.y, co.z))
        return Vector((co.x + 0.09 * up, co.y, co.z))
    o.add(frame_prism(outer, inner, "X", HX0, HX1, bevel=0.0013, segs=3, warp=slant), ["body"])
    # Hood screws (two per side).
    for side in (1, -1):
        for x in (HX0 + 0.0075, HX1 - 0.0075):
            o.add(cap_screw((x, side * 0.0195, 0.0245), (0, side, 0), 0.0019, 0.0008), ["steel", "inner"])

    # Main housing: side profile extruded across the width.
    side = [(q[0], q[1]) for q in fillet([
        P(0.0460, 0.0092, 0.0010, 2),
        P(0.0460, 0.0225, 0.0040, 4),
        P(0.0395, 0.0285, 0.0015, 3),
        P(-0.0300, 0.0285, 0.0040, 4),
        P(-0.0470, 0.0213, 0.0030, 4),
        P(-0.0492, 0.0168, 0.0015, 3),
        P(-0.0492, 0.0092, 0.0010, 2)])]
    o.add(prism(side, "Y", -0.0183, 0.0183, bevel=0.0014, segs=3), ["body"])
    # Thin seam band where the housing halves meet (reads as a parting line).
    seam = [(q[0], q[1]) for q in fillet([P(0.0462, 0.0128), P(-0.0494, 0.0128), P(-0.0494, 0.0134), P(0.0462, 0.0134)])]
    o.add(prism(seam, "Y", -0.0186, 0.0186), ["inner"])

    # Rear button panel on the sloped back: up / down rubber buttons with raised arrows.
    d = Vector((-0.0170, -0.0072)).normalized()
    n = Vector((d.y, -d.x))
    if n.y < 0:
        n = -n
    tilt = math.atan2(n.x, n.y)  # rotation about Y that maps +Z to the panel normal
    mid = Vector((-0.0385, 0.0249))
    for y, up in ((0.0062, True), (-0.0062, False)):
        rot = Matrix.Rotation(tilt, 4, "Y")
        c = mid + n * 0.0004
        o.add(box((0.0105, 0.0092, 0.0018), (c.x, y, c.y), bevel=0.0007, segs=3, rot=rot), ["rubber"])
        # Arrow: small triangle prism on the button.
        s = 1 if up else -1
        tri = prism([(s * 0.0024, 0.0), (-s * 0.0016, 0.0026), (-s * 0.0016, -0.0026)], "Z", 0.0, 0.0005)
        c2 = mid + n * 0.0013
        transform(tri, Matrix.Translation((c2.x, y, c2.y)) @ rot)
        o.add(tri, ["rubber"])
    # Battery cap on the left side, rear.
    xb, zb = -0.0330, 0.0190
    o.add(lathe([P(0.0170, 0.0), P(0.0170, 0.0098), P(0.0193, 0.0098, 0.0005, 2), P(0.0193, 0.0)],
                (0, 1, 0), (xb, 0, zb), segs=48), ["body"])
    capprof = [P(0.0190, 0.0), P(0.0190, 0.0086), P(0.0195, 0.0090, sh=flute(0.0005)),
               P(0.0226, 0.0090, 0.0005, 2, sh=flute(0.0005)), P(0.0231, 0.0078, 0.0003, 1), P(0.0231, 0.0)]
    slot = transform(box((0.0011, 0.0030, 0.0140), (0, 0, 0)), Matrix.Translation((xb, 0.0233, zb)))
    o.add(lathe(capprof, (0, 1, 0), (xb, 0, zb), angles=flute_angles(30)), ["body"], cutters=[slot])

    # Base with QD lever on the right.
    clamp = rail_clamp_outline(0.0168, 0.0100, 0.0172)
    o.add(prism(clamp, "X", -0.0370, 0.0370, bevel=0.0009, segs=3), ["body"], group="mount")
    groove = [(q[0], q[1]) for q in fillet([P(0.0174, 0.0062), P(-0.0174, 0.0062), P(-0.0174, 0.0068), P(0.0174, 0.0068)])]
    o.add(prism(groove, "X", -0.0355, 0.0355), ["inner"], group="mount")
    jaw = [(q[0], q[1]) for q in fillet([P(-0.0168, -0.0047), P(-0.0180, -0.0047, 0.0004, 1),
                                         P(-0.0180, 0.0080, 0.0004, 1), P(-0.0168, 0.0080)])]
    o.add(prism(jaw, "X", -0.0290, 0.0290, bevel=0.0003, segs=2), ["body"], group="mount")
    lever = [(q[0], q[1]) for q in fillet([
        P(0.0265, 0.0008, 0.0035, 4), P(0.0265, 0.0082, 0.0035, 4),
        P(-0.0150, 0.0070, 0.0010, 2), P(-0.0225, 0.0082, 0.0020, 3),
        P(-0.0262, 0.0062, 0.0018, 3), P(-0.0240, 0.0016, 0.0015, 3)])]
    o.add(prism(lever, "Y", -0.0214, -0.0181, bevel=0.0006, segs=2), ["body"], group="mount")
    o.add(lathe([P(0.0210, 0.0), P(0.0210, 0.0034), P(0.0226, 0.0034, 0.0006, 2), P(0.0226, 0.0)],
                (0, -1, 0), (0.0215, 0, 0.0045), segs=32), ["body"], group="mount")
    o.add(cap_screw((0.0215, -0.0226, 0.0045), (0, -1, 0), 0.0018, 0.0006), ["steel", "inner"], group="mount")
    o.add(lathe([P(0.0212, 0.0), P(0.0212, 0.0017), P(0.0222, 0.0017, 0.0004, 2), P(0.0222, 0.0)],
                (0, -1, 0), (-0.0120, 0, 0.0040), segs=24), ["steel"], group="mount")

    # Windows and reticle.
    glass_f = rrect(0.0, H, WY + 0.0004, (WZ1 - WZ0) / 2 + 0.0004, (0.0025,) * 4, 4)
    o.add(prism(glass_f, "X", 0.0288, 0.0310, bevel=0.0003, segs=1), ["glass"], group="lens_front")
    o.add(prism(glass_f, "X", -0.0098, -0.0082, bevel=0.0003, segs=1), ["glass"], group="lens_rear")
    ret = disc_facing((X_RET, 0, H), 0.0081, (-1, 0, 0), segs=64, inner=0.0073)
    dot = disc_facing((X_RET, 0, H), 0.0008, (-1, 0, 0), segs=20)
    tmp = bpy.data.meshes.new("tmp")
    dot.to_mesh(tmp)
    dot.free()
    ret.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    o.add(ret, ["red"], group="reticle")
    o.empty("sight_point", (X_RET, 0, H))
    o.finish()
