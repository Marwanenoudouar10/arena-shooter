## Every gun in the game and what makes each one different.

# Guns (Quaternius models, CC0, rigged in Blender: assets/guns/make_*_rigs.py). Each class
# carries its own. mode: auto (hold), semi (one shot per click), pump / bolt (one shot,
# then the action is worked before the next). reload: mag (swap the magazine), shells
# (one round at a time, fire to stop), revolver (swing the cylinder out). falloff: damage
# drops from the first distance to the second, down to the given share.
const GUNS := {
	"Wasp": {"sound": "rifle", "pitch": 1.18, "volume": -3.0, "class": "Light", "file": "res://assets/guns/smg_rig.glb", "desc": "Fast-firing SMG. Shreds up close.",
			"mode": "auto", "fire_rate": 15.0, "damage": 9.0, "mag": 32, "reload": 1.7, "reload_style": "mag", "recoil": 0.22,
			"hold": "rifle", "optics": ["Iron", "RedDot", "Holo"]},
	"Needle": {"sound": "sniper", "pitch": 1.0, "volume": 0.0, "class": "Light", "file": "res://assets/guns/sniper_rig.glb", "desc": "Bolt-action sniper. A headshot drops a Light.",
			"mode": "bolt", "fire_rate": 0.8, "damage": 110.0, "mag": 5, "reload": 0.65, "reload_style": "shells", "recoil": 3.0,
			"hold": "rifle", "optics": ["Scope", "RedDot", "Iron"]},
	"Sting": {"sound": "pistol", "pitch": 1.05, "volume": -2.0, "class": "Light", "file": "res://assets/guns/pistol_rig.glb", "desc": "Semi-auto pistol. Quick and accurate.",
			"mode": "semi", "fire_rate": 6.0, "damage": 20.0, "mag": 15, "reload": 1.4, "reload_style": "mag", "recoil": 0.9,
			"hold": "pistol", "optics": ["Iron"]},
	"Striker": {"sound": "rifle", "pitch": 1.0, "volume": -1.0, "class": "Medium", "file": "res://assets/guns/rifle_a_rig.glb", "desc": "Balanced assault rifle. Good at every range.",
			"mode": "auto", "fire_rate": 10.0, "damage": 15.0, "mag": 30, "reload": 2.0, "reload_style": "mag", "recoil": 0.35,
			"hold": "rifle", "optics": ["RedDot", "Holo", "Scope", "Iron"]},
	"Bulldog": {"sound": "rifle", "pitch": 0.9, "volume": 0.0, "class": "Medium", "file": "res://assets/guns/rifle_c_rig.glb", "desc": "Fires slow, hits hard. Strong kick to pull down.",
			"mode": "auto", "fire_rate": 7.0, "damage": 22.0, "mag": 24, "reload": 2.3, "reload_style": "mag", "recoil": 0.55,
			"hold": "rifle", "optics": ["Holo", "RedDot", "Scope", "Iron"]},
	"Judge": {"sound": "pistol", "pitch": 0.78, "volume": 1.0, "class": "Medium", "file": "res://assets/guns/revolver_rig.glb", "desc": "Heavy revolver. Six big hits, slow reload.",
			"mode": "semi", "fire_rate": 2.5, "damage": 55.0, "mag": 6, "reload": 2.6, "reload_style": "revolver", "recoil": 2.2,
			"hold": "pistol", "optics": ["Iron"]},
	"KS-12": {"sound": "shotgun", "pitch": 1.0, "volume": 0.0, "class": "Heavy", "file": "res://assets/guns/shotgun_rig.glb", "desc": "Pump shotgun. 8 pellets, devastating up close.",
			"mode": "pump", "fire_rate": 1.1, "damage": 12.0, "pellets": 8, "spread": 4.0, "mag": 6, "reload": 0.5, "reload_style": "shells",
			"recoil": 3.5, "hold": "rifle", "optics": ["Iron", "RedDot", "Holo"], "falloff": [8.0, 22.0, 0.25]},
	"Mauler": {"sound": "rifle", "pitch": 0.95, "volume": -1.0, "class": "Heavy", "file": "res://assets/guns/bullpup_rig.glb", "desc": "Bullpup machine gun. Big magazine, steady fire.",
			"mode": "auto", "fire_rate": 9.0, "damage": 15.0, "mag": 60, "reload": 3.4, "reload_style": "mag", "recoil": 0.4,
			"hold": "rifle", "optics": ["Holo", "RedDot", "Scope", "Iron"]},
}
const GUN_NAMES: Array[String] = ["Wasp", "Needle", "Sting", "Striker", "Bulldog", "Judge", "KS-12", "Mauler"]
