# Arena Shooter

A 3D arena shooter and aim trainer. Godot 4.7 (GDScript, Forward+ on Metal), developed on
an Apple M4 Mac. Art and maps are made with Blender 5.2 scripts. Played with mouse and
keyboard.

Personal working notes live in `CLAUDE.local.md` (not in git).

## Hard rules

1. **No file over 300 lines.** That includes `.gd` and `.py` files. When a file
   gets close, split it by job (see Architecture). Check with
   `wc -l scripts/**/*.gd assets/**/*.py maps/*.py`.
2. **One job per file.** A file gets a short `##` comment at the top saying what it does.
3. **Only CC0 assets.** Add every new asset to `assets/CREDITS.txt` (what it is, the
   author, the link and the licence).
4. **The self-test must pass** after every change (see Testing). Add a test for each new
   feature.
5. Match the style already in use: tabs, static types (`var x: T`, `:=`), simple
   English in comments, about the same number of comments as nearby code.

## Run

| What | Command |
|---|---|
| Play | double-click `play.command`, or `godot --path .` |
| Editor | `godot -e --path .` |
| Self-test | `godot --headless --path . --quit-after 36000 -- --selftest` (must print `SELFTEST OK`) |
| Screenshot | `godot --path . -- --shot=out.png [flags]` — run it in the background, wait about 30 s, then kill it. It can hang. |
| Map thumbnails | `godot --path . -- --thumbs` |

Screenshot flags (see `scripts/dev/debug_shot.gd`): `--menu[=build|settings]`,
`--flicks`, `--map=Open|Cover|Arena`, `--class=Light|Medium|Heavy`, `--gun=<name>`,
`--optic=Iron|RedDot|Holo|Scope`, `--ads`, `--reload=0..1`, `--near`, `--hitboxes`,
`--pause`, `--marks`, `--close`, `--yaw=<deg>`, `--vmside`.

Any run with arguments is a **dev run**. It never saves settings, best scores or history.
Saved data lives in `~/Library/Application Support/Godot/app_userdata/Arena Shooter/`.

## Architecture

The whole scene is built in code. `main.tscn` is a single node running
`scripts/main.gd`. Each part owns its own state. No autoloads. Scripts are loaded with
`const X := preload("res://…")`, never `class_name`.

```
scripts/
  main.gd                 entry: builds the parts, holds settings + loadout, frame loop, keys
  core/                   enums (State/Mode/Hit), glb loader, settings save/load + history, keys.gd (play keys)
  data/                   tables only: guns.gd, classes.gd, maps.gd (maps + quality presets), emotes.gd
  world/                  world.gd (sky, room, maps in play, cover boxes), materials.gd, map_loader.gd (glb -> boxes/zones/ramps)
  player/                 player.gd (move, sprint, slide, jump, collide, stairs, footsteps), mantle.gd (climbing), emote.gd (B wheel, third-person emotes)
  enemies/                enemy.gd (spawn, move, hitboxes, damage), enemy_ai.gd (hide/peek, dash), enemy_body.gd (model, anims, held gun), character_kit.gd
  weapons/                gun.gd (ammo, reload, fire modes, ADS, recoil), shooting.gd (pellets, damage, holes), aim_math.gd, scope_view.gd, hand_gun.gd
  weapons/viewmodel/      viewmodel.gd (entry + pose), gun_loader.gd, gun_animation.gd, effects.gd, arms.gd (IK)
  modes/                  session.gd (lobby/round/pause/360 test flow, stats, best scores), flicks.gd
  ui/                     hud.gd, pause_menu.gd, crosshair.gd, lobby_link.gd (lobby <-> game)
  ui/lobby/               lobby.gd (entry, public API), stage.gd (3D turntable) + studio.gd (red/white set, LED wall) + dragon.gd (hologram dragon) + showcase.gd (spinnable gun), main_screen.gd, build_panel.gd (class, weapon cards, sight), locker_panel.gd (clothes cards), settings_panel.gd, icons.gd (card pictures rendered at start), widgets.gd
  fx/                     sounds.gd (pooled players), impacts.gd (bullet holes, dust, sparks, tracers)
  dev/                    dev_runs.gd (flag dispatch), self_test.gd + test_*.gd, debug_shot.gd, thumbnails.gd, hitbox_debug.gd
assets/                   (has .gdignore, so everything is loaded at runtime)
  characters/human/       realistic MakeHuman characters: Blender pipeline, parts/, human_anims.glb
  characters/real/        Quaternius modular men (hoodie.glb is the animation source)
  guns/                   *_rig.glb + Blender rig scripts (moving parts + socket_* empties)
  optics/                 reddot / holo / scope .glb; make_optics.py is the entry, one module per optic + shared helpers
  sounds/                 src/ (CC0 packs), shots/ (cut by make_sounds.py)
  textures/               Poly Haven 1k photo textures
  ui/                     map thumbnails
  lobby/                  dragon.glb (Quaternius, CC0): the hologram dragon flying behind the lobby stage
maps/                     cover_map / arena_map .blend + .glb + generator scripts
```

How the parts talk: `main.gd` creates each part with `_part(Script)`, which sets the part's
`game` variable to main. A part reads others as `game.player`, `game.gun`, `game.world`, …
and settings as `game.map_name`, `game.sens`, …. Because `game` is untyped there, give
explicit types when reading from it (`var x: float = game.gun.ads`, not `:=`).
Shared names live in `core/enums.gd` (`E.State`, `E.Mode`, `E.Hit`).

### Characters: one blueprint (`scripts/enemies/character_kit.gd`)

Every character is the same realistic man, made with MPFB (MakeHuman for Blender). He wears
one part in each slot: `Head`, `Top`, `Legs`, `Feet`.
- `BASE` is the blueprint. `CLASS_LOOKS` lists only the parts each class changes.
- What the player wears goes on top (saved as `outfits`, chosen in MY BUILD → TOP).
- `human_anims.glb` gives the skeleton and the 24 animations. Each part is one glb in
  `assets/characters/human/parts/` (`head_*`, `top_*`, `legs_*`, `feet_*`), all exported from
  the same rig, so any part fits any body.
- To add clothing: add the part in the Blender pipeline (`assets/characters/human/`, run
  `blender -b --python assets/characters/human/make_human.py`), then add one entry to `PARTS`.
- Rig changed? Re-run `blender -b --python assets/characters/human/bake_animations.py` (it
  retargets the Quaternius clips from `characters/real/hoodie.glb`).
- Emotes: `make_emotes.py` in the same folder makes `emotes.glb` (10 clips, `Emote_<Name>`).
  `scripts/data/emotes.gd` lists them; `scripts/enemies/emote_anims.gd` adds them to a
  character's AnimationPlayer at runtime.
- Bone names live only in `scripts/enemies/rig.gd` (MakeHuman `game_engine` rig: `head`,
  `neck_01`, `upperarm_l`, `hand_r`, `index_01_l` …). The skeleton is in metres.
- Slot holders are `Wear_<Slot>` nodes under the skeleton; meshes inside need
  `skeleton = "../.."`. `Kit.dress()` swaps clothes live (lobby, first-person arms).

### Weapons

Weapon data lives in `data/guns.gd` (`GUNS`). Each gun has:
- a class, a model file and a fire mode: `auto`, `semi`, `pump` or `bolt`
- fire rate, damage, pellets, spread and magazine size
- a reload style: `mag`, `shells` or `revolver`
- recoil, a hold (`rifle` or `pistol`), the optics it allows, and damage falloff

The classes carry these guns:
- **Light:** Wasp, Needle, Sting
- **Medium:** Striker, Bulldog, Judge
- **Heavy:** KS-12, Mauler

Gun rigs in Blender:
- The moving parts are separate meshes: `magazine`, `pump`, `bolt`, `slide`,
  `cylinder` and `scope`.
- The `socket_*` empties mark `grip` (right hand), `hand` (left hand), `mount` (optic),
  `iron` (iron sight), `muzzle`, `eject`, `charge` (bolt handle), `magwell` and
  `cylinder_pivot`.

## Conventions

- Blender → glTF: Blender X is the barrel (forward) and -Y is right. glTF is (x, z, -y).
- In the viewmodel the gun node is turned +90° on Y and scaled by `GUN_SCALE` 0.11 (model
  units to metres).
- Character skeletons are in metres. Keep IK limits relative to bone lengths anyway.
- After `set_bone_global_pose`, call `force_update_all_bone_transforms()` before reading
  bones again.
- Render layers: the world is on layer 1. The viewmodel and arms are on layer 2. The scope
  camera only sees layer 1, and bullet-hole decals use cull mask 1.
- Collision and hit tests use AABBs and ray maths, not physics bodies:
  - ray against a sphere for heads
  - ray against a capsule (segment distance) for bodies
  - `AABB.intersects_ray` for cover
- UI font: SystemFont "Avenir Next Condensed". Use weight 800 for headings and 500 for
  body text. Colours: red (`Widgets.ACCENT`) and white only; the lobby stage too.
- Lobby cards show pictures (rendered at start by `ui/lobby/icons.gd`) with a short name,
  not long text.

## Testing

`scripts/dev/` holds the self-test. It drives the real game and checks:
- tracking kills for each class
- headshot damage, recoil and reload
- fire modes, pellets and falloff
- movement, slide, stairs and mantle
- cover AI, bullet holes and the lobby flow
- the character kit

Write checks as `T.check(ok, "message")` (dev/test_helpers.gd), not `assert`: a failed
assert inside a helper function only stops that function, so the run could still say OK.
`T.check` counts failures and the run ends with `SELFTEST FAILED: n checks` and exit code 1.

When a test is flaky, fix the cause (hold the target still, wait for settle frames, take
randomness such as decal scale out of checks). Don't loosen the check.
