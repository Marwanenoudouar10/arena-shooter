#!/bin/zsh
# Double-click in Finder to start the trainer.
cd "$(dirname "$0")"
exec /opt/homebrew/bin/godot --path .
