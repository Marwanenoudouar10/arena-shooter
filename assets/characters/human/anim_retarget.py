"""Retarget maths: lines up the two rest poses once, then turns one source frame into
local pose values (location + rotation) for every target bone.

The idea, for each mapped bone and frame:
    target rotation = source rotation x source rest rotation^-1 x aligned target rest rotation
All rotations are in the target armature's space. "Aligned target rest" is the target rest
pose turned so that it looks like the source T-pose (see anim_bone_map.py for the modes).
"""
import math

from mathutils import Matrix, Quaternion, Vector

from anim_bone_map import BONE_MAP, FRAME, KEEP, PALM, SOURCE_HIPS, TARGET_HIPS, TARGET_PELVIS

# Bones that also get a position, not only a rotation.
MOVERS = ("Root", TARGET_PELVIS)
# Share of the wrist twist that is moved into the forearm, so the wrist does not look wrung.
FOREARM_TWIST_SHARE = 0.5


def rot(m: Matrix) -> Matrix:
    """3x3 rotation part of a matrix, with any scale taken out."""
    return m.to_3x3().normalized()


def bones_parent_first(arm) -> list:
    """Bone names of an armature, every parent before its children."""
    out = []

    def walk(bone):
        out.append(bone.name)
        for child in bone.children:
            walk(child)
    for bone in arm.data.bones:
        if bone.parent is None:
            walk(bone)
    return out


def axes(x: Vector, y: Vector) -> Matrix:
    """Rotation whose X axis is x and whose Y axis is y (made square to x)."""
    x = x.normalized()
    z = x.cross(y).normalized()
    return Matrix((x, z.cross(x), z)).transposed()


class Retarget:
    def __init__(self, src, tgt):
        self.src, self.tgt = src, tgt
        # Source armature space -> target armature space (both are in the same world).
        self.to_tgt = tgt.matrix_world.inverted() @ src.matrix_world
        self.to_tgt_rot = rot(self.to_tgt)
        self.order = bones_parent_first(tgt)
        self.rest = {b.name: b.matrix_local.copy() for b in tgt.data.bones}
        self.rest_inv = {n: m.inverted() for n, m in self.rest.items()}
        sb = src.data.bones
        self.src_rest_inv = {b.name: (self.to_tgt_rot @ rot(b.matrix_local)).inverted() for b in sb}
        self.src_rest_head = {b.name: self.to_tgt @ b.head_local for b in sb}
        # Hip height ratio: scales the hip movement so feet stay on the floor (floor at z = 0).
        self.src_hip0 = self._mid(self.src_rest_head, SOURCE_HIPS)
        self.tgt_hip0 = self._mid({b.name: b.head_local for b in tgt.data.bones}, TARGET_HIPS)
        self.ratio = self.tgt_hip0.z / self.src_hip0.z
        # Where the hip joints sit, seen from the pelvis head (rest pose).
        self.hip_offset = self.tgt_hip0 - self.rest[TARGET_PELVIS].translation
        self.align = self._align()

    @staticmethod
    def _mid(heads: dict, pair: tuple) -> Vector:
        return (heads[pair[0]] + heads[pair[1]]) * 0.5

    def _pelvis_head(self, src_pose: dict, delta: Matrix) -> Vector:
        """Pelvis position that puts the new hip joints over the (scaled) source hip joints.
        Sideways/forward moves are scaled from rest; the height is scaled from the floor,
        so a body lying on the floor ends up lying on the floor too."""
        hip = self._mid({n: src_pose[n][1] for n in SOURCE_HIPS}, SOURCE_HIPS)
        goal = self.tgt_hip0 + (hip - self.src_hip0) * self.ratio
        goal.z = hip.z * self.ratio
        return goal - delta @ self.hip_offset

    # ---- rest pose lining up -------------------------------------------------------
    def _src_dir(self, name: str, aim) -> Vector:
        b = self.src.data.bones[name]
        end = self.src.data.bones[aim].head_local if aim else b.tail_local
        return (self.to_tgt_rot @ (end - b.head_local)).normalized()

    def _tgt_dir(self, name: str, aim) -> Vector:
        b = self.tgt.data.bones[name]
        end = self.tgt.data.bones[aim].head_local if aim else b.tail_local
        return (end - b.head_local).normalized()

    def _palm_side(self, name: str):
        """Index knuckle minus pinky knuckle, for source and target (rest)."""
        si, sp, ti, tp = PALM[name]
        sb, tb = self.src.data.bones, self.tgt.data.bones
        side_s = self.to_tgt_rot @ (sb[si].head_local - sb[sp].head_local)
        return side_s, tb[ti].head_local - tb[tp].head_local

    def _align(self) -> dict:
        """Per target bone: the turn (armature space) that makes its rest look like the source rest."""
        align = {}
        for name in self.order:
            bone = self.tgt.data.bones[name]
            parent = align[bone.parent.name] if bone.parent else Matrix.Identity(3)
            entry = BONE_MAP.get(name)
            if entry is None:
                align[name] = parent  # unmapped bones (ball_l/r) just ride along
                continue
            src_name, mode, src_aim, tgt_aim = entry
            if mode == KEEP:
                align[name] = Matrix.Identity(3)
                continue
            d_t = parent @ self._tgt_dir(name, tgt_aim)
            d_s = self._src_dir(src_name, src_aim)
            if mode == FRAME:
                side_s, side_t = self._palm_side(name)
                turn = axes(d_s, side_s) @ axes(d_t, parent @ side_t).inverted()
            else:
                turn = d_t.rotation_difference(d_s).to_matrix()
            align[name] = turn @ parent
        self._share_wrist_twist(align)
        return align

    def _share_wrist_twist(self, align: dict) -> None:
        """Moves part of the hand's twist (around the forearm) into the forearm."""
        self.wrist_twist = {}
        for side in ("l", "r"):
            fore, hand = "lowerarm_" + side, "hand_" + side
            axis = (align[fore] @ self._tgt_dir(fore, "hand_" + side)).normalized()
            q = (align[hand] @ align[fore].inverted()).to_quaternion()
            angle = 2.0 * math.atan2(Vector((q.x, q.y, q.z)).dot(axis), q.w)  # signed turn around the forearm
            if angle > math.pi:
                angle -= 2.0 * math.pi
            elif angle < -math.pi:
                angle += 2.0 * math.pi
            self.wrist_twist[side] = angle
            share = Quaternion(axis, angle * FOREARM_TWIST_SHARE).to_matrix()
            align[fore] = share @ align[fore]

    # ---- per frame -----------------------------------------------------------------
    def sample(self, pose_bones) -> dict:
        """Source bone -> (rotation, head) in target armature space, from evaluated pose bones."""
        r, m = self.to_tgt_rot, self.to_tgt
        return {pb.name: (r @ rot(pb.matrix), m @ pb.matrix.translation) for pb in pose_bones}

    def solve(self, src_pose: dict) -> dict:
        """Target bone -> (location, quaternion) local pose values for one frame."""
        pose, out = {}, {}
        for name in self.order:
            bone = self.tgt.data.bones[name]
            rest = self.rest[name]
            if bone.parent:
                p = bone.parent.name
                base = pose[p] @ self.rest_inv[p] @ rest
            else:
                base = rest.copy()
            entry = BONE_MAP.get(name)
            if entry is None:
                world = base
            else:
                src_name = entry[0]
                src_rot, src_head = src_pose[src_name]
                delta = src_rot @ self.src_rest_inv[src_name]
                turn = delta @ self.align[name] @ rot(rest)
                head = base.translation
                if name == TARGET_PELVIS:
                    head = self._pelvis_head(src_pose, delta)
                elif name in MOVERS:
                    moved = src_head - self.src_rest_head[src_name]
                    head = rest.translation + moved * self.ratio
                world = Matrix.LocRotScale(head, turn, None)
            pose[name] = world
            local = base.inverted() @ world
            out[name] = (local.translation.copy(), local.to_quaternion())
        return out

    def report(self) -> str:
        twist = ", ".join("%s %.0f deg" % (s, a * 57.2958) for s, a in self.wrist_twist.items())
        return "hip ratio %.3f, wrist twist found: %s" % (self.ratio, twist)
