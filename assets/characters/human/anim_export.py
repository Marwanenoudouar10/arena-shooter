"""Writes the target armature and its baked clips to a .glb. Every clip becomes its own
glTF animation (named like the action), and every bone is in every clip, so no clip
leaks a pose into another one.
"""
import bpy

from anim_keys import clear_animation, reset_pose


def remove_objects(objects: list) -> None:
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)


def keep_only_actions(names: list) -> None:
    """Deletes every action that is not one of the baked clips (in memory only)."""
    for action in list(bpy.data.actions):
        if action.name not in names:
            bpy.data.actions.remove(action)


def export_glb(rig, path: str, with_mesh: bool = False) -> None:
    """Exports the armature (and its meshes if with_mesh) with all actions as animations."""
    layer = bpy.context.view_layer
    rig.hide_set(False)
    rig.hide_viewport = False
    for obj in layer.objects:
        obj.select_set(obj == rig or (with_mesh and obj.type == "MESH" and obj.parent == rig
                                      and obj.visible_get()))
    layer.objects.active = rig
    clear_animation(rig)
    reset_pose(rig)
    rig.data.pose_position = "POSE"
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=with_mesh,  # bakes mask modifiers into the meshes (armature stays live)
        export_skins=True,
        export_morph=False,
        export_def_bones=False,
        export_leaf_bone=False,
        export_rest_position_armature=True,
        export_animations=True,
        export_animation_mode="ACTIONS",   # one glTF animation per action
        export_merge_animation="ACTION",
        export_anim_single_armature=True,
        export_reset_pose_bones=True,      # rest pose between clips, so nothing leaks
        export_force_sampling=True,
        export_frame_step=1,
        export_frame_range=False,
        export_anim_slide_to_zero=False,
        export_optimize_animation_size=False,  # keep every bone in every clip
        export_bake_animation=False,
    )
