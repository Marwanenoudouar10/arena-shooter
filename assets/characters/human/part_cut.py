## Builds one finished mesh per part (head, tops, legs, feet): cloth pieces layered so outer
## clothes sit over inner ones (top over pants, pants over shoes), plus the skin that stays visible.
import os

import bpy

import human_config as C
import body_cut
import body_lod
import coverage
import game_materials
import pieces

LEG_ZONE = lambda co: co.z < 0.42            # noqa: E731  pants hem area, over the shoes
WAIST_ZONE = lambda co: 0.80 < co.z < 1.25   # noqa: E731  shirt hem area, over the pants


def _delete_group(part):
    return "Delete." + os.path.basename(C.CLOTHES[part["cloth"]]).replace(".mhclo", "")


def _layer(outer, inner, zone):
    """outer pieces go over inner pieces: push them out, then cut inner faces every outer covers."""
    for o in outer.values():
        n = coverage.push_out(o, list(inner.values()), zone)
        print("LAYER pushed %d verts of %s" % (n, o.name))
    trees = [coverage.tree(o) for o in outer.values()]
    for i in inner.values():
        common = set.intersection(*(coverage.hidden_verts(i, t, back=0.006) for t in trees))
        faces = coverage.faces_inside(i, coverage.erode(coverage.neighbours(i), common))
        coverage.delete_faces(i, faces)
        print("LAYER cut %d hidden faces from %s" % (len(faces), i.name))


def _join(name, objs):
    first = objs[0]
    with bpy.context.temp_override(active_object=first, selected_editable_objects=objs, object=first):
        bpy.ops.object.join()
    first.name = first.data.name = name
    return first


_skin_mats = {}  # texture size -> skin material


def _skin_copy(body, faces, name, size):
    skin = pieces.copy_object(body, name)
    coverage.delete_faces(skin, set(range(len(body.data.polygons))) - faces)
    if size not in _skin_mats:
        _skin_mats[size] = game_materials.variant(body.data.materials[0], size)
        _skin_mats[size].name = "Skin" if size == C.SKIN_TEX else "Skin_%d" % size
    skin.data.materials[0] = _skin_mats[size]
    return skin


def make_all(rig, objs):
    by_slot = {s: {} for s in C.SLOT_SUFFIX}
    for part in C.PARTS:
        if part.get("cloth"):
            by_slot[part["slot"]][part["file"]] = pieces.make(part, objs, rig)
    _layer(by_slot["Legs"], by_slot["Feet"], LEG_ZONE)
    _layer(by_slot["Top"], by_slot["Legs"], WAIST_ZONE)

    body = objs["Body"]
    body_lod.thin_hands(body, rig)
    body_cut.freeze_normals(body)
    hidden = {}
    for part in C.PARTS:
        if part.get("cloth"):
            piece = by_slot[part["slot"]][part["file"]]
            hidden[part["file"]] = body_cut.hidden_by(body, rig, piece, _delete_group(part), part.get("keep"))
    slot_files = {s: list(d.keys()) for s, d in by_slot.items() if d}
    always, per_part = body_cut.skin_faces(body, rig, slot_files, hidden)

    out = []
    for part in C.PARTS:
        name = part["prefix"] + "_" + C.SLOT_SUFFIX[part["slot"]]
        if part["slot"] == "Head":
            items = [_skin_copy(body, always["Head"], name, C.SKIN_TEX)]
            for key in ("Eyes", "Eyebrows", "Eyelashes", "Hair_" + part["hair"]):
                items.append(pieces.copy_object(objs[key], key + "_" + part["prefix"]))
        else:
            piece = by_slot[part["slot"]][part["file"]]
            mat = piece.data.materials[0]
            if part.get("tint") or part.get("erase"):
                mat = game_materials.variant(mat, C.TEX, part.get("tint", (1, 1, 1)), part.get("erase", ()))
            else:
                mat = mat.copy()
            mat.name = part["prefix"]
            piece.data.materials[0] = mat
            items = [piece]
            if per_part[part["file"]]:
                items.append(_skin_copy(body, per_part[part["file"]], name + "_skin", C.TEX))
        out.append((part, _join(name, items)))
    return out
