## The maps you can play on and the graphics quality presets.

const MAP_INFO := {
	"Open": {"name": "Open Room", "desc": "Flat room with nothing to hide behind. Pure tracking."},
	"Cover": {"name": "Cover Yard", "desc": "Walls and crates. Enemies hide and peek out."},
	"Arena": {"name": "The Arena", "desc": "60 m arena: warehouse, platform, stairs, container."},
}

# Maps. "Cover" and "Arena" are built in Blender (maps/*.blend) and read from the exported
# .glb at startup, so a fresh export shows up the next time the game starts. Every mesh is
# treated as a box (its bounding box) for bullets and for walking into. Special names:
# zone_* = where enemies walk, zone_flicks = where flick targets float, spawn_player, ref_*.
const MAP_NAMES: Array[String] = ["Open", "Cover", "Arena"]
const MAP_FILES := {"Cover": "res://maps/cover_map.glb", "Arena": "res://maps/arena_map.glb"}
const LANES := {"Open": Vector2(-18.0, -8.0), "Cover": Vector2(-16.0, -12.0)}  # target z range without zones
const ROOM_AREA := Rect2(-18.0, -5.0, 36.0, 12.0)  # where you can walk in the small room (x, z)

# Graphics presets: render scale (FSR upscaling), MSAA, ambient occlusion, glow, shadow range.
const QUALITY := {
	"Low": {"scale": 0.6, "msaa": Viewport.MSAA_DISABLED, "ssao": false, "glow": false, "shadow": 25.0, "fog": false},
	"Medium": {"scale": 0.8, "msaa": Viewport.MSAA_DISABLED, "ssao": true, "glow": true, "shadow": 40.0, "fog": true},
	"High": {"scale": 1.0, "msaa": Viewport.MSAA_2X, "ssao": true, "glow": true, "shadow": 60.0, "fog": true},
}
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High"]
