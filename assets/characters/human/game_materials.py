## Rebuilds every material as a plain glTF-friendly Principled BSDF: one base colour image (shrunk,
## optionally tinted, JPG unless it needs alpha), an optional normal map and a fixed roughness.
import os
import tempfile

import bpy
import numpy as np

import human_config as C

TEX_DIR = tempfile.mkdtemp(prefix="human_tex_")
_cache = {}  # (source path, size, tint, alpha) -> new image

# kind -> roughness, alpha mode (None / "clip" / "blend"), double sided
LOOKS = {
    "skin": (0.5, None, False),
    "eyes": (0.15, None, False),
    "brows": (0.7, "blend", True),
    "hair": (0.55, "clip", True),
    "cloth": (0.85, None, True),
}


def reset():
    """Forget cached images (call after opening another .blend: they belong to the old file)."""
    _cache.clear()


def kind_of(key):
    if key == "Body":
        return "skin"
    if key == "Eyes":
        return "eyes"
    if key in ("Eyebrows", "Eyelashes"):
        return "brows"
    if key.startswith("Hair_"):
        return "hair"
    return "cloth"


def _fill(img, filled, steps):
    """Paint every texel where filled is False with the average of its filled neighbours,
    growing inwards one texel per step; anything still empty gets the mean colour."""
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    rgb = px[..., :3] * filled[..., None]
    for _ in range(steps):
        acc = np.zeros_like(rgb)
        cnt = np.zeros((h, w), dtype=np.float32)
        for axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            acc += np.roll(rgb * filled[..., None], shift, axis)
            cnt += np.roll(filled, shift, axis)
        grow = ~filled & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    rgb[~filled] = rgb[filled].mean(axis=0)
    px[..., :3] = rgb
    px[..., 3] = 1.0
    img.pixels.foreach_set(px.ravel())


def _alpha_mask(img):
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)[..., 3] > 0.5


def _erase_mask(img, boxes):
    """False inside each (u0, v0, u1, v1) box, v measured from the top of the image."""
    w, h = img.size
    keep = np.ones((h, w), dtype=bool)
    for u0, v0, u1, v1 in boxes:
        keep[int((1 - v1) * h):int((1 - v0) * h), int(u0 * w):int(u1 * w)] = False
    return keep


def _image(src, size, tint=(1, 1, 1), alpha=False, normal=False, erase=()):
    """Load src once, shrink it to size px (never up), tint it and save as JPG or PNG.
    Opaque images get their see-through texels filled (stray UVs at seams would show white)."""
    path = bpy.path.abspath(src.filepath) if src.filepath else src.name
    key = (path, size, tuple(tint), alpha, tuple(erase))
    if key in _cache:
        return _cache[key]
    img = src.copy()
    if not alpha and not normal and img.channels == 4:
        mask = _alpha_mask(img)
        if not mask.all():
            _fill(img, mask, 24)
    w, h = img.size
    scale = min(1.0, size / max(w, h))
    if scale < 1.0:
        img.scale(max(1, int(w * scale)), max(1, int(h * scale)))
    if erase:
        _fill(img, _erase_mask(img, erase), 64)
    if tuple(tint) != (1, 1, 1):
        px = np.empty(len(img.pixels), dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        px[:, :3] *= np.array(tint, dtype=np.float32)
        img.pixels.foreach_set(px.ravel())
    name = "%s_%d%s" % (os.path.splitext(os.path.basename(path))[0], size, "_v%d" % len(_cache) if key[2:] != ((1, 1, 1), alpha, ()) else "")
    out = os.path.join(TEX_DIR, name + (".png" if alpha else ".jpg"))
    img.file_format = "PNG" if alpha else "JPEG"
    img.save(filepath=out, quality=C.JPG_QUALITY)
    bpy.data.images.remove(img)
    new = bpy.data.images.load(out)
    new.name = name
    if normal:
        new.colorspace_settings.name = "Non-Color"
    _cache[key] = new
    return new


def _find_images(mat):
    diffuse = normal = None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            if node.name.startswith("Normal"):
                normal = node.image
            elif diffuse is None or node.name == "DiffuseTexture":
                diffuse = node.image
    return diffuse, normal


def rebuild(mat, kind, size, tint=(1, 1, 1)):
    """Replace mat's node tree with: image -> Principled BSDF (+ normal map, + alpha)."""
    rough, alpha, double = LOOKS[kind]
    diffuse, normal = _find_images(mat)
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    if diffuse is not None:
        mat["src_diffuse"] = bpy.path.abspath(diffuse.filepath)  # kept for variant()
        mat["kind"] = kind
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.name = "BaseColor"
        tex.image = _image(diffuse, size, tint, alpha is not None)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha == "blend":
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        elif alpha == "clip":  # 1 - (a < cut) is what the glTF exporter reads as MASK, cutoff cut
            less = nt.nodes.new("ShaderNodeMath")
            less.operation = "LESS_THAN"
            less.inputs[1].default_value = 0.25  # low, so the hair stays full
            inv = nt.nodes.new("ShaderNodeMath")
            inv.operation = "SUBTRACT"
            inv.inputs[0].default_value = 1.0
            nt.links.new(tex.outputs["Alpha"], less.inputs[0])
            nt.links.new(less.outputs[0], inv.inputs[1])
            nt.links.new(inv.outputs[0], bsdf.inputs["Alpha"])
    else:
        bsdf.inputs["Base Color"].default_value = (0.6, 0.6, 0.6, 1.0)
    if normal is not None:
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = _image(normal, min(size, C.TEX), normal=True)
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    mat.use_backface_culling = not double
    mat.surface_render_method = "BLENDED" if alpha == "blend" else "DITHERED"
    return mat


def convert_all(objs):
    """Give every object game materials (skin at SKIN_TEX px, the rest at TEX px)."""
    for key, obj in objs.items():
        kind = kind_of(key)
        size = C.SKIN_TEX if kind == "skin" else C.TEX
        for slot in obj.material_slots:
            if slot.material is not None:
                rebuild(slot.material, kind, size)
                slot.material.name = key


def variant(mat, size, tint=(1, 1, 1), erase=()):
    """A copy of a rebuilt material whose base colour comes from the original image at another
    size, tint or with logos erased (e.g. smaller skin for body parts, a navy polo)."""
    src = mat.get("src_diffuse")
    if not src:
        return mat
    alpha = LOOKS[mat["kind"]][1] is not None
    new = mat.copy()
    src_img = bpy.data.images.load(src, check_existing=True)
    new.node_tree.nodes["BaseColor"].image = _image(src_img, size, tint, alpha, erase=erase)
    return new
