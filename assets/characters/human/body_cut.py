## Cuts the body skin into slots. Each body face belongs to the slot of the bone that moves it most;
## a part keeps only the faces of its slot that its cloth does not cover (and that no choice in
## another slot always covers), so hidden skin can never poke through when he moves.
import human_config as C
import coverage
import pieces


def _slot_of_bone():
    out = {}
    for slot, bones in C.SLOT_BONES.items():
        for b in bones:
            out[b] = slot
    return out


def face_regions(body, rig):
    """slot -> set of body polygon indices."""
    bones = pieces.strongest_bone(body, rig)
    slot_of = _slot_of_bone()
    regions = {s: set() for s in C.SLOT_SUFFIX}
    for p in body.data.polygons:
        votes = {}
        for i in p.vertices:
            s = slot_of.get(bones[i], "Top")
            votes[s] = votes.get(s, 0) + 1
        regions[max(votes, key=votes.get)].add(p.index)
    return regions


def hidden_by(body, rig, piece, delete_group=None, half=None):
    """Body vertices under this cloth piece: ray test, plus MPFB's own delete group if it has
    one (for half a suit only the vertices of that half), shrunk by one ring so the skin goes on
    a little way under every opening."""
    verts = coverage.hidden_verts(body, coverage.tree(piece))
    if delete_group and delete_group in body.vertex_groups:
        gi = body.vertex_groups[delete_group].index
        group = {v.index for v in body.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)}
        if half:
            slot_of, bones = _slot_of_bone(), pieces.strongest_bone(body, rig)
            legs = ("Legs", "Feet")
            group = {i for i in group if (slot_of.get(bones[i], "Top") in legs) == (half == "legs")}
        verts |= group
    return coverage.erode(coverage.neighbours(body), verts)


def skin_faces(body, rig, slot_pieces, hidden):
    """slot_pieces: slot -> [part file]; hidden: part file -> hidden body verts.
    Returns (always: slot -> faces no matter what is worn, per_part: part file -> faces)."""
    regions = face_regions(body, rig)
    covered_any = set().union(*(hidden[f] for f in slot_pieces.get("Top", [])))
    moved = coverage.faces_inside(body, covered_any) & regions["Head"]
    regions["Head"] -= moved  # neck skin under any collar belongs to the tops
    regions["Top"] |= moved
    always_hidden = {}  # slot -> faces that every choice in that slot covers
    for slot, files in slot_pieces.items():
        common = set.intersection(*(hidden[f] for f in files))
        always_hidden[slot] = coverage.faces_inside(body, common)
    always = {}
    for slot, faces in regions.items():
        always[slot] = faces - set().union(*(h for s, h in always_hidden.items() if s != slot))
    per_part = {}
    for slot, files in slot_pieces.items():
        for f in files:
            per_part[f] = always[slot] - coverage.faces_inside(body, hidden[f])
    return always, per_part


def freeze_normals(body):
    """Store the whole body's smooth normals, so faces cut into different parts still shade as
    one surface where the parts meet."""
    me = body.data
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([v.normal.copy() for v in me.vertices])
