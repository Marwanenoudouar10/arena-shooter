"""Materials shared by all optics: anodized aluminium, rubber, steel, paint, lens glass
and the glowing reticle red. Each optic file gets a fresh set from make_materials().
"""
import bpy


def make_material(name, color, metallic, roughness, alpha=1.0, emission=None,
                  strength=0.0, double_sided=False):
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
        mat.blend_method = "BLEND"  # older name, kept so glTF/Eevee both see it
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    mat.use_backface_culling = not double_sided
    mat.diffuse_color = (*color, alpha)
    mat.metallic = metallic
    mat.roughness = roughness
    return mat


def make_materials():
    return {
        "body": make_material("anodized_black", (0.04, 0.04, 0.042), 0.6, 0.45),
        "inner": make_material("interior_black", (0.012, 0.012, 0.012), 0.0, 0.8),
        "rubber": make_material("rubber", (0.018, 0.018, 0.018), 0.0, 0.9),
        "steel": make_material("steel_dark", (0.03, 0.03, 0.03), 0.85, 0.32),
        "white": make_material("paint_white", (0.75, 0.75, 0.72), 0.0, 0.55),
        "glass": make_material("lens_glass", (0.55, 0.78, 0.74), 0.0, 0.05, alpha=0.25),
        "red": make_material("reticle_red", (1.0, 0.05, 0.02), 0.0, 0.5,
                             emission=(1.0, 0.04, 0.02), strength=5.0),
    }
