## The three classes: how enemies of each class move and how fast you move as one.

# Tracking target classes (light, medium, heavy). height = total in m, width = extra
# girth on top of the model's own build, speed = strafe m/s range,
# turn = seconds between direction changes, jump = chance per direction change,
# dash = sudden sidesteps per second.
const CLASSES := {
	"Light": {"width": 0.95, "height": 1.78, "hp": 150.0, "speed": Vector2(4.0, 8.5), "turn": Vector2(0.2, 0.8), "jump": 0.3, "dash": 0.5},
	"Medium": {"width": 1.0, "height": 1.86, "hp": 250.0, "speed": Vector2(2.5, 7.0), "turn": Vector2(0.25, 1.1), "jump": 0.2, "dash": 0.2},
	"Heavy": {"width": 1.2, "height": 1.95, "hp": 350.0, "speed": Vector2(1.5, 4.5), "turn": Vector2(0.4, 1.4), "jump": 0.1, "dash": 0.0},
}
const CLASS_NAMES: Array[String] = ["Light", "Medium", "Heavy"]

# What each enemy class carries.
const ENEMY_GUNS := {"Light": "Wasp", "Medium": "Striker", "Heavy": "Mauler"}

# Your class: how fast you move. Health is shown for when enemies shoot back.
const PLAYER_CLASSES := {
	"Light": {"speed": 1.15, "hp": 150, "desc": "Fast and hard to hit, but fragile."},
	"Medium": {"speed": 1.0, "hp": 250, "desc": "All-rounder. Normal speed and health."},
	"Heavy": {"speed": 0.85, "hp": 350, "desc": "Slow, but takes a beating."},
}
