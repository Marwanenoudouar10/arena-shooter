"""Red dot sight (Aimpoint Micro T-2 class): short tube with the reticle dot behind the
front lens, top and right turret caps, brightness dial on the left, and an integral low
mount with a cross-bolt.
"""
import math

from mathutils import Matrix

from meshes import box, disc_facing, frame_matrix, frame_prism, lathe, prism, transform
from optic import Optic
from parts import hex_nut, lens, rail_clamp_outline, slotted_head
from profiles import P, cradle, fillet, knurl, knurl_angles, rrect


def build_reddot():
    o = Optic("reddot")
    H = 0.0300      # optical axis height above the rail
    R = 0.0148      # housing radius
    X_RET = 0.0209  # reticle plane, just behind the front lens

    # Housing: one closed profile around the optical axis (outside rear->front, inside front->rear).
    prof = [
        P(-0.0310, 0.0119, 0.0003, 1),
        P(-0.0310, 0.0137, 0.0008, 3),
        P(-0.0263, 0.0137, 0.0003, 1),
        P(-0.0254, R, 0.0005, 2),
        P(-0.0002, R, 0.0002, 1), P(0.0003, R - 0.0006), P(0.0015, R - 0.0006), P(0.0020, R, 0.0002, 1),
        P(0.0300, R),
        P(0.0305, R + 0.0004, 0.0002, 1),
        P(0.0330, R + 0.0004, 0.0008, 3),
        P(0.0330, 0.0129, 0.0004, 2, m=1),
        P(0.0240, 0.0129, 0.0002, 1, m=1),
        P(0.0240, 0.0109, 0.0002, 1, m=1),
        P(0.0229, 0.0109, m=1),
        P(0.0229, 0.0100, m=1),
        P(-0.0254, 0.0100, m=1),
        P(-0.0254, 0.0110, m=1),
        P(-0.0272, 0.0110, m=1),
        P(-0.0272, 0.0119, m=1),
    ]
    o.add(lathe(prof, (1, 0, 0), (0, 0, H), segs=56), ["body", "inner"])

    # Keel under the tube that carries the housing on the mount (top buried in the tube wall).
    keel = cradle(0.0101, 0.0108, H, 0.0125, wall_z=H - 0.0030)
    o.add(prism(keel, "X", -0.0236, 0.0175, bevel=0.0012, segs=3), ["body"])
    # Square shoulders around the tube where the turrets sit; hollow so the bore stays clear.
    shoulder = rrect(0.0, H, 0.0156, 0.0156, (0.006, 0.006, 0.006, 0.006), segs=6)
    hole = rrect(0.0, H, 0.0125, 0.0125, (0.0124,) * 4, segs=6)
    o.add(frame_prism(shoulder, hole, "X", -0.0215, 0.0045, bevel=0.0014, segs=3), ["body"])

    # Elevation (top) and windage (right) caps, brightness dial on the left.
    xt = -0.0085
    for axis in ((0, 0, 1), (0, -1, 0)):
        o.add(lathe([P(0.0106, 0.0), P(0.0106, 0.0083), P(0.0172, 0.0083, 0.0006, 2), P(0.0172, 0.0)],
                    axis, (xt, 0, H), segs=40), ["body"])
        cap = [P(0.0168, 0.0), P(0.0168, 0.0064), P(0.0172, 0.0069, sh=knurl(0.0004)),
               P(0.0218, 0.0069, 0.0005, 1, sh=knurl(0.0004)), P(0.0222, 0.0058, 0.0003, 1), P(0.0222, 0.0)]
        slot = box((0.0009, 0.016, 0.0024), (0, 0, 0))
        slot = transform(slot, frame_matrix(axis, (xt, 0, H)) @ Matrix.Translation((0.0222, 0, 0))
                         @ Matrix.Rotation(math.pi / 2, 4, "Y"))
        o.add(lathe(cap, axis, (xt, 0, H), angles=knurl_angles(30)), ["body"], cutters=[slot])
    xd = -0.0110
    o.add(lathe([P(0.0106, 0.0), P(0.0106, 0.0092), P(0.0168, 0.0092, 0.0005, 2), P(0.0168, 0.0)],
                (0, 1, 0), (xd, 0, H), segs=40), ["body"])
    dial = [P(0.0164, 0.0), P(0.0164, 0.0090), P(0.0170, 0.0097, sh=knurl(0.0005)),
            P(0.0216, 0.0097, 0.0005, 1, sh=knurl(0.0005)), P(0.0220, 0.0086, 0.0003, 1), P(0.0220, 0.0)]
    o.add(lathe(dial, (0, 1, 0), (xd, 0, H), angles=knurl_angles(32)), ["body"])
    # Raised pointer bar across the dial face.
    o.add(box((0.0110, 0.0012, 0.0020), (xd, 0.0226, H), bevel=0.0004, segs=2), ["body"])
    o.add(box((0.0016, 0.0003, 0.0016), (xd - 0.0042, 0.0232, H), bevel=0.0), ["white"])

    # Integral low mount with cross-bolt.
    clamp = rail_clamp_outline(0.0118, 0.0112, 0.0132)
    o.add(prism(clamp, "X", -0.0200, 0.0200, bevel=0.0008, segs=3), ["body"], group="mount")
    jaw = [(q[0], q[1]) for q in fillet([P(-0.0128, -0.0046), P(-0.0139, -0.0046, 0.0004, 1),
                                         P(-0.0139, 0.0072, 0.0004, 1), P(-0.0128, 0.0072)])]
    o.add(prism(jaw, "X", -0.0150, 0.0150, bevel=0.0003, segs=2), ["body"], group="mount")
    xb, zb = 0.0045, 0.0018
    o.add(hex_nut((xb, -0.0139, zb), (0, -1, 0), 0.0078, 0.0040, 0.0021, 0.0010), ["steel"], group="mount")
    head_cut = transform(box((0.0009, 0.0024, 0.012), (0, 0, 0)),
                         Matrix.Translation((xb, 0.0152, zb)))
    o.add(slotted_head((xb, 0.0132, zb), (0, 1, 0), 0.0042, 0.0020), ["steel"], group="mount",
          cutters=[head_cut])
    # Recoil lug that sits in the rail slot.
    o.add(box((0.0040, 0.0150, 0.0030), (-0.0080, 0, -0.0012), bevel=0.0004, segs=2), ["body"], group="mount")

    # Glass and reticle.
    o.add(lens(0.02225, 0.0105, 0.0011, 0.00035, 0.0001, H), ["glass"], group="lens_front")
    o.add(lens(-0.02595, 0.0106, 0.0010, 0.0001, 0.00030, H), ["glass"], group="lens_rear")
    o.add(disc_facing((X_RET, 0, H), 0.0006, (-1, 0, 0), segs=20), ["red"], group="reticle")
    o.empty("sight_point", (X_RET, 0, H))
    o.finish()
