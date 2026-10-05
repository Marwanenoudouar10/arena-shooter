## Builds the live MPFB human: body, game_engine rig, eyes, brows, lashes, every hair and every
## piece of clothing from human_config, all fitted to the same body. Returns (rig, objects by key).
import bpy
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.assetservice import AssetService

import human_config as C


def _add(path, body, subdir, kind):
    """Fit one MPFB asset (hair or clothes) to the body and return the new mesh object."""
    full = AssetService.find_asset_absolute_path(path, asset_subdir=subdir)
    if full is None:
        raise IOError("MPFB asset not found: " + path)
    return HumanService.add_mhclo_asset(full, body, asset_type=kind, subdiv_levels=0, material_type="GAMEENGINE")


def _uuid(path, subdir):
    full = AssetService.find_asset_absolute_path(path, asset_subdir=subdir)
    with open(full, encoding="utf-8") as f:
        for line in f:
            if line.startswith("uuid "):
                return line.split()[1]
    return None


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    info = HumanService._create_default_human_info_dict()
    info["phenotype"].update(C.PHENOTYPE)
    info["rig"] = C.RIG
    info["eyes"] = C.EYES
    info["eyebrows"] = C.EYEBROWS
    info["eyelashes"] = C.EYELASHES
    info["skin_mhmat"] = C.SKIN
    info["skin_material_type"] = "GAMEENGINE"  # plain Principled BSDF + images, which glTF understands
    info["eyes_material_type"] = "GAMEENGINE"
    info["clothes_material_type"] = "GAMEENGINE"
    info["alternative_materials"] = {_uuid(C.EYES, "eyes"): C.EYE_MATERIAL}
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0  # no subdivision anywhere
    body = HumanService.deserialize_from_dict(info, settings)
    rig = body.parent

    objs = {"Body": body}
    for child in rig.children:  # name the body parts MPFB added
        for key, path in (("Eyes", C.EYES), ("Eyebrows", C.EYEBROWS), ("Eyelashes", C.EYELASHES)):
            if child.name.endswith("." + path.split("/")[-1].replace(".mhclo", "")):
                objs[key] = child
    for key, path in C.HAIRS.items():
        objs["Hair_" + key] = _add(path, body, "hair", "Hair")
    for key, path in C.CLOTHES.items():
        objs["Cloth_" + key] = _add(path, body, "clothes", "Clothes")
    for key, obj in objs.items():
        obj.name = key
    missing = [k for k in ("Eyes", "Eyebrows", "Eyelashes") if k not in objs]
    if missing:
        raise RuntimeError("MPFB did not add: %s" % missing)
    return rig, objs
