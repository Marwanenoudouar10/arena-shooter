# Arena Shooter

A 3D first-person arena shooter and aim trainer made with Godot 4.

## Features

- Tracking mode: a moving enemy that strafes, jumps, dashes and hides behind cover
- Flick drill: targets that jump to a new spot each time you hit them
- 360 sensitivity test to match your sensitivity from another game
- Three classes (Light, Medium, Heavy), each with its own weapons
- Eight guns: automatic, semi-auto, pump and bolt action, with real reload animations
- Sights: iron sights, red dot, holo sight and a 4x scope
- Movement: sprint, slide, crouch, jump and climbing onto ledges
- Three maps: an open room, a cover yard and a large arena
- Realistic characters with clothes you can swap in the locker
- Ten emotes, in the lobby and in a match (third-person camera)
- Bullet holes, hit markers and real gun sounds

## Requirements

- Godot 4.7 (standard version, not .NET)
- Blender 5.2 only if you want to rebuild the models

## Run

```
godot --path .
```

Or open the folder in the Godot editor and press Play.

## Controls

| Key | Action |
|---|---|
| Mouse | Look |
| Left click | Fire |
| Right click | Aim down sights |
| W A S D | Move |
| Shift | Sprint |
| C | Crouch, or slide while running |
| Space | Jump, hold into a ledge to climb |
| R | Reload |
| B (hold) | Emote wheel |
| Backspace | Restart the round |
| Esc | Pause |
| F | Fullscreen |
| Up / Down | Sensitivity |

## Tests

```
godot --headless --path . --quit-after 36000 -- --selftest
```

The game runs through its features and prints `SELFTEST OK` when everything works.

## Project layout

- `scripts/` game code, split by area (world, player, enemies, weapons, ui, modes)
- `assets/` models, textures and sounds, plus the Blender scripts that build them
- `maps/` the maps and their Blender scripts

## Credits

All art and sound is CC0 (public domain). See `assets/CREDITS.txt` for the full list.

## License

The code is under the MIT License. See `LICENSE`.
