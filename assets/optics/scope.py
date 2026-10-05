"""Rifle scope (variable power, 30 mm tube): eyecup, diopter and magnification rings,
turrets with painted marks, an illumination knob, and a one-piece mount with rings.
The game draws the scope's reticle itself, so there is no reticle object here.
"""
import math

from mathutils import Matrix, Vector

from meshes import box, frame_matrix, frame_prism, lathe, prism, transform
from optic import Optic
from parts import cap_screw, hash_marks, hex_nut, lens, rail_clamp_outline, slotted_head
from profiles import P, cradle, fillet, knurl, knurl_angles, rrect


def build_scope():
    o = Optic("scope")
    H = 0.0385   # optical axis height (1.5 in)
    R = 0.0150   # 30 mm tube
    X_EYE = -0.1140

    # Rubber eyecup with a soft rolled lip.
    o.add(lathe([P(X_EYE, 0.0166, 0.0006, 1), P(X_EYE, 0.0197, 0.0020, 2), P(-0.1098, 0.0207, 0.0025, 2),
                 P(-0.1052, 0.0201), P(-0.1052, 0.0168)], (1, 0, 0), (0, 0, H), segs=36), ["rubber"])
    # Diopter (focus) ring with fine ridges.
    o.add(lathe([P(-0.1056, 0.0172), P(-0.1056, 0.0196), P(-0.1049, 0.0205, sh=knurl(0.0006)),
                 P(-0.0962, 0.0205, sh=knurl(0.0006)), P(-0.0954, 0.0194), P(-0.0954, 0.0172)],
                (1, 0, 0), (0, 0, H), angles=knurl_angles(22)), ["body"])
    # Main body: eyepiece, tube, objective bell (one closed profile).
    prof = [
        P(-0.0956, 0.0160),
        P(-0.0956, 0.0199, 0.0004, 1),
        P(-0.0836, 0.0199, 0.0010, 2),
        P(-0.0806, 0.0181, 0.0005, 1),
        P(-0.0620, 0.0181, 0.0010, 2),
        P(-0.0570, R, 0.0020, 2),
        P(0.0570, R, 0.0030, 3),
        P(0.0800, 0.0215, 0.0040, 3),
        P(0.1078, 0.0215),
        P(0.1080, 0.0222),
        P(0.1130, 0.0222, 0.0009, 2),
        P(0.1130, 0.0199, 0.0004, 1, m=1),
        P(0.1060, 0.0199, m=1),
        P(0.1060, 0.0182, m=1),
        P(0.0800, 0.0182, m=1),
        P(0.0570, 0.0125, m=1),
        P(-0.0800, 0.0125, m=1),
        P(-0.0800, 0.0160, m=1),
    ]
    o.add(lathe(prof, (1, 0, 0), (0, 0, H), segs=36), ["body", "inner"])
    # Magnification ring with coarse ridges and a throw lever.
    o.add(lathe([P(-0.0796, 0.0180), P(-0.0796, 0.0186), P(-0.0789, 0.0194, sh=knurl(0.0009)),
                 P(-0.0641, 0.0194, sh=knurl(0.0009)), P(-0.0634, 0.0186), P(-0.0634, 0.0180)],
                (1, 0, 0), (0, 0, H), angles=knurl_angles(16, (0.0, 0.25, 0.75))), ["body"])
    lever = box((0.0070, 0.0030, 0.0080), (0, 0, 0), bevel=0.0010, segs=3)
    transform(lever, Matrix.Translation((-0.0735, 0, H)) @ Matrix.Rotation(math.radians(40), 4, "X")
              @ Matrix.Translation((0, 0, 0.0215)))
    o.add(lever, ["body"])
    o.add(box((0.0012, 0.0006, 0.0003), (-0.0900, 0, H + 0.0199), bevel=0.0), ["white"])

    # Turret saddle.
    saddle = rrect(0.0, H, 0.0176, 0.0176, (0.0090,) * 4, 6)
    hole = rrect(0.0, H, 0.0140, 0.0140, (0.01395,) * 4, 6)
    o.add(frame_prism(saddle, hole, "X", -0.0235, 0.0235, bevel=0.0030, segs=3), ["body"])
    # Elevation (top) and windage (right): collar, exposed knurled knob, painted marks.
    # phase: angle (about the turret axis) of the zero line: toward the shooter / the top.
    for axis, phase in (((0, 0, 1), 1.5 * math.pi), ((0, -1, 0), 0.5 * math.pi)):
        c = (0, 0, H)
        o.add(lathe([P(0.0160, 0.0), P(0.0160, 0.0110), P(0.0198, 0.0110, 0.0005, 2), P(0.0198, 0.0)],
                    axis, c, segs=36), ["body"])
        knob = [P(0.0196, 0.0), P(0.0196, 0.0123, 0.0003, 1), P(0.0246, 0.0124),
                P(0.0249, 0.0129, sh=knurl(0.0008)), P(0.0318, 0.0129, 0.0006, 1, sh=knurl(0.0008)),
                P(0.0326, 0.0115, 0.0003, 1), P(0.0326, 0.0)]
        o.add(lathe(knob, axis, c, angles=knurl_angles(18, (0.0, 0.25, 0.75))), ["body"])
        o.add(cap_screw(frame_matrix(axis, c) @ Vector((0.0326, 0, 0)), axis, 0.0032, 0.0008, segs=18),
              ["body", "inner"])
        o.add(hash_marks(c, axis, 0.0124, 0.0244, 40, 5, 0.0020, 0.0034, phase), ["white"])
        # Reference line on the collar, toward the shooter / the top.
        ref = box((0.0030, 0.0003, 0.0005), (0, 0, 0))
        transform(ref, frame_matrix(axis, c) @ Matrix.Rotation(phase, 4, "X")
                  @ Matrix.Translation((0.0182, 0.0110, 0)))
        o.add(ref, ["white"])
    # Illumination knob on the left.
    o.add(lathe([P(0.0160, 0.0), P(0.0160, 0.0104), P(0.0196, 0.0104, 0.0005, 2), P(0.0196, 0.0)],
                (0, 1, 0), (0, 0, H), segs=40), ["body"])
    o.add(lathe([P(0.0194, 0.0), P(0.0194, 0.0108), P(0.0199, 0.0113, sh=knurl(0.0006)),
                 P(0.0262, 0.0113, 0.0005, 1, sh=knurl(0.0006)), P(0.0268, 0.0100, 0.0003, 1),
                 P(0.0268, 0.0)], (0, 1, 0), (0, 0, H), angles=knurl_angles(18)), ["body"])
    o.add(box((0.0090, 0.0010, 0.0018), (0, 0.0273, H), bevel=0.0004, segs=2), ["body"])

    # One-piece mount: rail clamp base, two stanchions, rings with split caps.
    base = rail_clamp_outline(0.0125, 0.0080, 0.0140)
    o.add(prism(base, "X", -0.0560, 0.0560, bevel=0.0009, segs=1), ["body"], group="mount")
    # Stanchion section: tapered post whose top is an arc buried in the ring wall.
    stan = cradle(0.0112, 0.0070, H, 0.0170, wall_z=H - 0.0041)
    for xc in (-0.0420, 0.0420):
        o.add(prism(stan, "X", xc - 0.0080, xc + 0.0080, bevel=0.0009, segs=1), ["body"], group="mount")
        o.add(lathe([P(xc - 0.0080, R - 0.0001), P(xc - 0.0080, 0.0186, 0.0010, 2),
                     P(xc + 0.0080, 0.0186, 0.0010, 2), P(xc + 0.0080, R - 0.0001)],
                    (1, 0, 0), (0, 0, H), segs=36), ["body"], group="mount")
        for s in (1, -1):
            for z0, z1 in ((0.0004, 0.0058), (-0.0058, -0.0004)):
                o.add(box((0.0160, 0.0060, z1 - z0), (xc, s * 0.0186, H + (z0 + z1) / 2), bevel=0.0008, segs=1),
                      ["body"], group="mount")
            for dx in (-0.0040, 0.0040):
                o.add(cap_screw((xc + dx, s * 0.0190, H + 0.0058), (0, 0, 1), 0.0021, 0.0019, segs=12),
                      ["steel", "inner"], group="mount")
        # Cross-bolt clamp: plate and nut on the right, slotted head on the left.
        jaw = [(q[0], q[1]) for q in fillet([P(-0.0136, -0.0047), P(-0.0147, -0.0047, 0.0004, 1),
                                             P(-0.0147, 0.0068, 0.0004, 1), P(-0.0136, 0.0068)])]
        o.add(prism(jaw, "X", xc - 0.0090, xc + 0.0090, bevel=0.0003, segs=2), ["body"], group="mount")
        o.add(hex_nut((xc, -0.0147, 0.0018), (0, -1, 0), 0.0078, 0.0040, 0.0021, 0.0010), ["steel"], group="mount")
        cut = transform(box((0.0009, 0.0024, 0.012), (0, 0, 0)), Matrix.Translation((xc, 0.0160, 0.0018)))
        o.add(slotted_head((xc, 0.0140, 0.0018), (0, 1, 0), 0.0042, 0.0020), ["steel"], group="mount",
              cutters=[cut])

    # Glass.
    o.add(lens(0.10345, 0.0189, 0.0024, 0.0012, 0.0004, H, segs=32), ["glass"], group="lens_front")
    o.add(lens(-0.1090, 0.0170, 0.0022, 0.0004, 0.0010, H, segs=32), ["glass"], group="lens_rear")
    o.empty("sight_point", (0.0, 0, H))
    o.empty("eye_point", (X_EYE, 0, H))
    o.finish()
