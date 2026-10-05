"""Builds the three weapon optics used by the game: a compact red dot, a holographic
sight and a variable rifle scope, with real-world sizes in metres.

Run:  blender --background --factory-startup --python assets/optics/make_optics.py

Writes <name>.blend (to look at / edit) and <name>.glb (used by the game) next to this
script, for name in: reddot, holo, scope.

Axes: +X = forward (toward the target), +Z = up, -Y = the right side.
Origin (0, 0, 0) = bottom centre of the mount, the point that sits on the gun's rail.

Objects in every file:
  body        housing, turrets, knobs (anodized aluminium, rubber, steel)
  mount       rail clamp, rings, cross-bolts
  lens_front  objective glass (transparent)
  lens_rear   eyepiece glass (transparent)
  reticle     glowing red dot / ring (red dot and holo only; the game draws the scope's)
  sight_point Empty on the optical axis, at the reticle (red dot, holo) or the scope centre
  eye_point   Empty on the optical axis at the eyepiece end (scope only)

This file is only the entry point. The code lives in the modules next to it:
  materials.py  the shared materials
  profiles.py   2D outlines, fillets and ring shapes (flutes, knurling, hexagon)
  meshes.py     mesh builders: lathe, prism, frame_prism, box, discs
  parts.py      shared small parts: screws, nuts, lenses, index marks, rail clamp
  optic.py      Optic class: groups parts, joins them, saves .blend and exports .glb
  reddot.py, holo.py, scope.py   one build function per optic
"""
import os
import sys

# Blender runs this file as a script, so its folder is not on the import path yet.
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
sys.dont_write_bytecode = True  # keep __pycache__ out of the assets folder

from holo import build_holo
from reddot import build_reddot
from scope import build_scope

if __name__ == "__main__":
    for build in (build_reddot, build_holo, build_scope):
        build()
