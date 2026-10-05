"""2D helpers: profile points with corner fillets, rounded rectangles, the cradle outline
under a tube, and ring shapes (flutes, knurling, hexagon) that lathe() uses to bend a
circle into a grip pattern. No Blender data is created here.
"""
import math

from mathutils import Vector

TAU = 2.0 * math.pi


# --- 2D outlines and fillets ----------------------------------------------------

def P(u, v, f=0.0, s=2, m=0, sh=None):
    """Profile point: position (u, v), corner fillet radius f with s segments
    (s=1 is a chamfer), material index m for the span that starts here, ring shape sh."""
    return (u, v, f, s, (m, sh))


def fillet(points, closed=True):
    """Rounds the corners of a polyline. Returns [(u, v, tag)]."""
    out = []
    n = len(points)
    for i, (u, v, r, segs, tag) in enumerate(points):
        if r <= 0 or (not closed and i in (0, n - 1)):
            out.append((u, v, tag))
            continue
        a, b = points[i - 1], points[(i + 1) % n]
        p = Vector((u, v))
        d1, d2 = Vector((a[0], a[1])) - p, Vector((b[0], b[1])) - p
        l1, l2 = d1.length, d2.length
        d1.normalize()
        d2.normalize()
        ang = math.acos(max(-1.0, min(1.0, d1.dot(d2))))
        if ang < 1e-4 or ang > math.pi - 1e-4:
            out.append((u, v, tag))
            continue
        t = min(r / math.tan(ang / 2), l1 * 0.5, l2 * 0.5)
        rr = t * math.tan(ang / 2)
        t1, t2 = p + d1 * t, p + d2 * t
        c = p + (d1 + d2).normalized() * (rr / math.sin(ang / 2))
        a1 = math.atan2(t1.y - c.y, t1.x - c.x)
        a2 = math.atan2(t2.y - c.y, t2.x - c.x)
        da = (a2 - a1 + math.pi) % TAU - math.pi
        for k in range(segs + 1):
            ak = a1 + da * k / segs
            out.append((c.x + rr * math.cos(ak), c.y + rr * math.sin(ak), tag))
    # Drop duplicate neighbours (fillets that ate a whole segment).
    clean = []
    for q in out:
        if not clean or abs(q[0] - clean[-1][0]) + abs(q[1] - clean[-1][1]) > 1e-7:
            clean.append(q)
    if closed and len(clean) > 1 and abs(clean[0][0] - clean[-1][0]) + abs(clean[0][1] - clean[-1][1]) < 1e-7:
        clean.pop()
    return clean


def rrect(cu, cv, hu, hv, radii, segs=6):
    """Rounded rectangle outline (always the same point count for equal segs).
    radii = (bottom-left, bottom-right, top-right, top-left)."""
    pts = [P(cu - hu, cv - hv, max(radii[0], 1e-5), segs),
           P(cu + hu, cv - hv, max(radii[1], 1e-5), segs),
           P(cu + hu, cv + hv, max(radii[2], 1e-5), segs),
           P(cu - hu, cv + hv, max(radii[3], 1e-5), segs)]
    return [(q[0], q[1]) for q in fillet(pts)]


def cradle(bottom_half, bottom_z, center_z, arc_r, wall_z=None, n=12):
    """YZ outline of a block under a tube: flat bottom, tapered sides, and a top that is
    an arc of radius arc_r around the tube axis (buried in the tube wall, clear of the bore)."""
    a0 = -math.asin(min(0.999, (center_z - wall_z) / arc_r)) if wall_z else -math.radians(10)
    a1 = -math.pi - a0
    arc = [(arc_r * math.cos(a0 + (a1 - a0) * k / n), center_z + arc_r * math.sin(a0 + (a1 - a0) * k / n))
           for k in range(n + 1)]
    side = arc[0][0]
    knee = bottom_z + (arc[0][1] - bottom_z) * 0.45
    return [(-bottom_half, bottom_z), (bottom_half, bottom_z), (side, knee)] + arc + [(-side, knee)]


# --- Ring shapes (angles and radius per sample around a lathe ring) ---------------

def uniform(segs, phase=0.0):
    return [phase + TAU * j / segs for j in range(segs)]


def flute_angles(n, frac=(0.0, 0.36, 0.5, 0.86)):
    period = TAU / n
    return [period * (k + f) for k in range(n) for f in frac]


def flute(depth):
    """Ring shape for flute_angles(): samples 0,1 are the groove, 2,3 the ridge."""
    return lambda r, th, j: r - depth if j % 4 < 2 else r


def knurl_angles(n, frac=(0.0, 0.18, 0.82)):
    period = TAU / n
    return [period * (k + f) for k in range(n) for f in frac]


def knurl(depth):
    """Ring shape for knurl_angles(): flat ridges with a V groove at sample 0."""
    return lambda r, th, j: r - depth if j % 3 == 0 else r


def hexagon(r, th, j):
    """Ring shape: hexagon with circumradius r (corners at 30 + k*60 degrees)."""
    a = ((th + math.pi / 6) % (math.pi / 3)) - math.pi / 6
    return r * math.cos(math.pi / 6) / math.cos(a)
