"""Pose maths for the emotes. Everything is in HumanRig's armature space (metres, he faces
-Y, +X is his left, +Z is up).

- RigData: rest data of the armature and the neutral pose (Idle, first frame).
- Pose: one pose of the whole skeleton. Change a bone by giving it a new rotation in
  armature space (set_rot / turn); the children follow, like in Blender.
- limb(): two-bone IK for an arm or a leg (aim at a target, elbow or knee toward a pole).
- turn_deg(): a rotation from easy angles (pitch, roll, yaw in degrees).
"""
import math

from mathutils import Matrix, Quaternion, Vector

ARMS = {"l": ("upperarm_l", "lowerarm_l", "hand_l"), "r": ("upperarm_r", "lowerarm_r", "hand_r")}
LEGS = {"l": ("thigh_l", "calf_l", "foot_l"), "r": ("thigh_r", "calf_r", "foot_r")}


def rot3(m: Matrix) -> Matrix:
    """3x3 rotation part of a 4x4 matrix."""
    return m.to_3x3().normalized()


def basis(y: Vector, x: Vector) -> Matrix:
    """Rotation whose Y axis is exactly y and whose X axis is x made square to y."""
    y = y.normalized()
    x = (x - y * x.dot(y)).normalized()
    return Matrix((x, y, x.cross(y))).transposed()


def turn_deg(pitch: float = 0.0, roll: float = 0.0, yaw: float = 0.0) -> Matrix:
    """pitch + = lean/nod forward, roll + = lean to his left (+X), yaw + = turn to his left."""
    rx = Matrix.Rotation(math.radians(pitch), 3, "X")
    ry = Matrix.Rotation(math.radians(roll), 3, "Y")
    rz = Matrix.Rotation(math.radians(yaw), 3, "Z")
    return rz @ ry @ rx


def twist_angle(r: Matrix, axis: Vector) -> float:
    """How much of rotation r turns around axis (radians, -pi..pi)."""
    q = r.to_quaternion()
    along = Vector(q[1:]).dot(axis.normalized())
    return 2.0 * math.atan2(along, q.w) if abs(q.w) > 1e-9 or abs(along) > 1e-9 else 0.0


class RigData:
    """Rest pose, parents and the neutral pose of one armature object."""

    def __init__(self, arm, neutral: dict):
        self.parent, self.rest, self.order = {}, {}, []
        for bone in arm.data.bones:
            self.parent[bone.name] = bone.parent.name if bone.parent else None
            self.rest[bone.name] = bone.matrix_local.copy()
        self._walk(arm.data.bones)
        # rest matrix of each bone seen from its parent
        self.rel = {n: (self.rest[p].inverted() @ self.rest[n]) if p else self.rest[n].copy()
                    for n, p in self.parent.items()}
        self.neutral = neutral  # bone -> (location, quaternion), local values
        self.base = Pose(self)  # the neutral pose, never changed
        self.chains = {}
        for side in "lr":
            self.chains["arm_" + side] = self._chain(*ARMS[side])
            self.chains["leg_" + side] = self._chain(*LEGS[side])

    def _walk(self, bones) -> None:
        def visit(bone):
            self.order.append(bone.name)
            for child in bone.children:
                visit(child)
        for bone in bones:
            if bone.parent is None:
                visit(bone)

    def _chain(self, upper: str, lower: str, end: str) -> dict:
        """Lengths, and each bone's rotation seen from its bend frame (Y along the bone,
        X along the hinge), taken from the neutral pose so IK there gives back neutral."""
        b = self.base
        a, k, w = b.head(upper), b.head(lower), b.head(end)
        u, v = (k - a).normalized(), (w - k).normalized()
        hinge = u.cross(v)
        if hinge.length < 0.05:  # nearly straight: use the rest pose bend instead
            r = self.rest
            hinge = (r[lower].translation - r[upper].translation).cross(
                r[end].translation - r[lower].translation)
        hinge.normalize()
        return {
            "bones": (upper, lower, end),
            "len": ((k - a).length, (w - k).length),
            "up": basis(u, hinge).inverted() @ b.rot(upper),
            "lo": basis(v, hinge).inverted() @ b.rot(lower),
            "pole": _off_line(k, a, w),  # which way the elbow or knee points
        }


def _off_line(k: Vector, a: Vector, w: Vector) -> Vector:
    """Direction from the line a-w out to point k, square to the line."""
    d = (w - a).normalized()
    off = (k - a) - d * (k - a).dot(d)
    return off.normalized()


class Pose:
    """Local pose values plus their armature-space matrices (kept up to date)."""

    def __init__(self, rig: RigData):
        self.rig = rig
        self.loc = {n: v[0].copy() for n, v in rig.neutral.items()}
        self.quat = {n: v[1].copy() for n, v in rig.neutral.items()}
        self.g = {}
        self.fk()

    def fk(self) -> None:
        """Recomputes every bone's armature-space matrix, parents first."""
        r = self.rig
        for n in r.order:
            local = Matrix.Translation(self.loc[n]) @ self.quat[n].to_matrix().to_4x4()
            p = r.parent[n]
            self.g[n] = (self.g[p] @ r.rel[n] if p else r.rel[n]) @ local

    def head(self, n: str) -> Vector:
        return self.g[n].translation.copy()

    def rot(self, n: str) -> Matrix:
        return rot3(self.g[n])

    def _base(self, n: str) -> Matrix:
        p = self.rig.parent[n]
        return self.g[p] @ self.rig.rel[n] if p else self.rig.rel[n]

    def set_rot(self, n: str, r: Matrix) -> None:
        """Turns bone n so its armature-space rotation becomes r. Children follow."""
        self.quat[n] = (rot3(self._base(n)).inverted() @ r).to_quaternion().normalized()
        self.fk()

    def turn(self, n: str, r: Matrix) -> None:
        """Adds rotation r (armature axes) to bone n, around its head."""
        self.set_rot(n, r @ self.rot(n))

    def set_head(self, n: str, pos: Vector) -> None:
        """Moves bone n (pelvis) so its head sits at pos."""
        base = self._base(n)
        self.loc[n] = rot3(base).inverted() @ (pos - base.translation)
        self.fk()

    def delta(self, n: str) -> Matrix:
        """How bone n moved from the neutral pose (maps neutral points onto this pose)."""
        return self.g[n] @ self.rig.base.g[n].inverted()

    def values(self) -> dict:
        return {n: (self.loc[n].copy(), self.quat[n].copy()) for n in self.rig.order}


def two_bone(root: Vector, target: Vector, l1: float, l2: float, pole: Vector):
    """Where the middle joint and the end go. The end is pulled in if out of reach."""
    d = target - root
    dist = min(max(d.length, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.9995)
    dh = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = (pole - dh * pole.dot(dh)).normalized()
    return root + dh * a + p * h, root + dh * dist, dh, p


def limb(pose: Pose, chain: str, target: Vector, pole: Vector) -> Vector:
    """Aims an arm or leg so its end (wrist or ankle) reaches target, with the middle joint
    pointing toward pole (armature space). Returns where the end really is."""
    c = pose.rig.chains[chain]
    upper, lower, _ = c["bones"]
    root = pose.head(upper)
    mid, end, dh, p = two_bone(root, target, c["len"][0], c["len"][1], pole)
    hinge = p.cross(dh).normalized()
    pose.set_rot(upper, basis(mid - root, hinge) @ c["up"])
    pose.set_rot(lower, basis(end - mid, hinge) @ c["lo"])
    return end


def twist_into_forearm(pose: Pose, lower: str, hand: str, want: Matrix, share: float) -> None:
    """Gives the hand rotation `want`; `share` of its twist goes into the forearm instead of
    the wrist, so the wrist does not look wrung."""
    zero = rot3(pose.g[lower] @ pose.rig.rel[hand])  # hand with no local rotation
    axis = pose.rot(lower).col[1]
    angle = twist_angle(want @ zero.inverted(), axis)
    pose.turn(lower, Matrix.Rotation(angle * share, 3, axis))
    pose.set_rot(hand, want)


def quat_close(q: Quaternion, ref: Quaternion) -> Quaternion:
    """Same rotation as q, on the same side as ref (keeps curves from flipping)."""
    return -q if q.dot(ref) < 0.0 else q.copy()
