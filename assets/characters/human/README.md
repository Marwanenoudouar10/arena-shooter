# Realistic human (MakeHuman / MPFB)

One realistic man, cut into parts for `character_kit.gd`: every part glb holds the same
`HumanRig` skeleton plus ONE skinned mesh.

## Run

```
blender -b --python assets/characters/human/make_human.py -- [--blueprint] [--blueprint-only] [--no-previews]
```

Needs Blender 5.2 with the MPFB 2 extension and its asset packs (makehuman_system_assets,
shirts01, pants01, shoes01, skins02). About 20 seconds.

- `human_blueprint.blend` is only written when it is missing or with `--blueprint` (the
  animation job works from it). Otherwise the new rig is checked against it and the run
  stops if bones or rest pose differ.
- Every run rewrites `parts/*.glb` and `previews/<outfit>.png`.

## The man and the rig

- Height **1.86 m** to the top of the head (hair adds about 1.5 cm). Feet at 0.
- Units are **metres**, not centimetres like the Quaternius models.
- Faces Blender -Y, so he faces **+Z in Godot**. Rest pose is MPFB's A-pose.
- `HumanRig`: MPFB `game_engine` rig, 53 bones, scale 1, in this order:

```
Root, pelvis, spine_01, spine_02, spine_03,
clavicle_l, upperarm_l, lowerarm_l, hand_l,
index_01_l, index_02_l, index_03_l, middle_01_l, middle_02_l, middle_03_l,
pinky_01_l, pinky_02_l, pinky_03_l, ring_01_l, ring_02_l, ring_03_l,
thumb_01_l, thumb_02_l, thumb_03_l,
clavicle_r, upperarm_r, lowerarm_r, hand_r,
index_01_r, index_02_r, index_03_r, middle_01_r, middle_02_r, middle_03_r,
pinky_01_r, pinky_02_r, pinky_03_r, ring_01_r, ring_02_r, ring_03_r,
thumb_01_r, thumb_02_r, thumb_03_r,
neck_01, head, thigh_l, calf_l, foot_l, ball_l, thigh_r, calf_r, foot_r, ball_r
```

## Parts

Mesh names follow the kit: `<Prefix>_Head / _Body / _Legs / _Feet`.

| File | Mesh | What | Triangles |
|---|---|---|---|
| head_short.glb | Short_Head | head + neck skin, eyes, brows, lashes, short brown hair | 12.7k |
| head_slick.glb | Slick_Head | same face, dark slicked-back hair | 10.4k |
| top_tshirt.glb | Tshirt_Body | olive t-shirt + arms and hands | 10.1k |
| top_polo.glb | Polo_Body | navy polo + arms and hands | 8.5k |
| top_sweater.glb | Sweater_Body | red knit sweater + hands | 7.6k |
| top_jacket.glb | Jacket_Body | green field jacket over a striped shirt + hands | 7.6k |
| legs_jeans.glb | Jeans_Legs | blue jeans | 1.8k |
| legs_cargo.glb | Cargo_Legs | dark cargo trousers | 1.7k |
| feet_shoes.glb | Shoes_Feet | black leather shoes | 3.9k |
| feet_sneakers.glb | Sneakers_Feet | blue sneakers | 2.8k |
| feet_boots.glb | Boots_Feet | brown leather ankle boots | 4.0k |

A full character is 23.7k to 27.4k triangles. Each glb is 0.2 to 2.2 MB.

Suggested looks (rendered in `previews/`):
- **Light**: head_short, top_tshirt, legs_jeans, feet_sneakers
- **Medium**: head_slick, top_polo, legs_jeans, feet_boots
- **Heavy**: head_short, top_jacket, legs_cargo, feet_shoes
- extra: head_slick, top_sweater, legs_cargo, feet_boots

## How the parts fit together

- Skin is split by bone (head/neck, arms/torso, hips/legs, feet). A part keeps only the
  skin its own cloth does not cover, and drops skin that every choice in another slot
  covers. So no hidden skin can poke through.
- Layers: tops go over trousers, trousers go over shoes. The outer cloth is pushed out over
  every inner choice, and inner cloth that is always covered is cut away.
- Skin normals are saved before cutting, so the neck seam does not show.
- Materials are plain Principled BSDF: base colour JPG (PNG with alpha for hair, brows,
  lashes), normal map where the asset has one, fixed roughness. Skin 2048 px in the head,
  1024 px elsewhere.

## Scripts

| File | Job |
|---|---|
| make_human.py | entry, runs the steps below |
| human_config.py | body sliders, height, assets, parts, outfits |
| mpfb_build.py | builds the MPFB man with the rig and all hair and clothes |
| bake_body.py | applies shape keys, removes helpers, scales to 1.86 m |
| game_materials.py | glTF-friendly materials, small textures, tints, logo removal |
| blueprint.py | saves the bare man to human_blueprint.blend |
| pieces.py | cloth piece per part (half of a suit, smoothing, hem fix) |
| coverage.py | "is this under that cloth" ray tests and push-out |
| body_cut.py | splits the skin into slots |
| body_lod.py | fewer triangles in the fingers |
| part_cut.py | puts each part together |
| part_export.py | writes the glbs |
| preview.py | renders previews from the exported glbs |

## Credits (all CC0 1.0)

All from the MakeHuman community asset library (makehumancommunity.org), installed through MPFB.

- MakeHuman base mesh, `game_engine` rig and weights, skin `young_caucasian_male`, eyes
  `low-poly` with `brownlight` material, `eyebrow001`, `eyelashes01`, hair `short02` and
  `short04`, `male_casualsuit05` (jacket, shirt, jeans), `male_casualsuit06` (t-shirt),
  `shoes03`, `shoes06`: MakeHuman team (Data Collection AB, Joel Palmius, Jonas Hauquier),
  released CC0 in 2020.
- Polo t-shirt (`namuhekam_male_polo_shirt`): Namuhekam, makehumancommunity.org/node/2909
- Fisherman sweater (`toigo_fisherman_sweater`): Margaret Toigo (MRT), makehumancommunity.org/node/1187
- Ankle boots (`toigo_ankle_boots_male`): Margaret Toigo (MRT), makehumancommunity.org/node/1743
- Cargo pants (`cortu_cargo_pants`): Cortu Johnstone, makehumancommunity.org/node/2798

The MPFB add-on itself is GPL, but none of its code is shipped; only the CC0 assets are.

## Emotes

`blender -b --python assets/characters/human/make_emotes.py -- [--previews] [--only=Wave,Clap]`
keys 10 emotes on HumanRig (Wave, Salute, Clap, ThumbsUp, Cheer, Flex, Shrug, Bow, Dance,
Laugh) and exports `emotes.glb` (clips `Emote_<Name>`, 30 fps; Clap and Dance loop). Modules:
`emote_rig.py` (aiming + IK), `emote_poses.py`, `emote_hands.py`, `emote_keys.py`,
`emote_feet.py`, `emote_neutral.py`, `emote_clips_a/b/c.py`, `emote_preview.py`.
