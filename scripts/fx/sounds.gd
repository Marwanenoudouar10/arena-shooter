extends Node
## Game sounds (all CC0, see assets/CREDITS.txt): real gunshot recordings, reload and
## pump/bolt sounds, footsteps, hit markers, shell casings and UI clicks. play() picks a
## random take and nudges the pitch so repeated sounds never sound copied.

const ROOT := "res://assets/sounds/"
const SRC := "res://assets/sounds/src/"
const IMPACT := "res://assets/sounds/src/kenney_impact-sounds/Audio/"
const UI := "res://assets/sounds/src/kenney_interface-sounds/Audio/"
# name -> files (a "*" pattern picks every match in that folder)
const FILES := {
	"shot_rifle": [ROOT + "shots/rifle_*.wav"],
	"shot_pistol": [ROOT + "shots/pistol_*.wav"],
	"shot_sniper": [ROOT + "shots/sniper_*.wav"],
	"shot_shotgun": [ROOT + "shots/shotgun_*.wav"],
	"mag_out": [SRC + "clipload2.wav"],
	"mag_in": [SRC + "clipload1.wav"],
	"round_in": [SRC + "singlebullet1.wav"],
	"pump": [SRC + "shotguncock_0.wav"],
	"shell_in": [SRC + "shotgunsounds/ShotgunSounds/Subsequent Shells.mp3"],
	"step": [IMPACT + "footstep_concrete_*.ogg"],
	"land": [IMPACT + "impactSoft_medium_*.ogg"],
	"hit_body": [IMPACT + "impactPunch_medium_*.ogg"],
	"hit_head": [IMPACT + "impactMetal_light_*.ogg"],
	"kill": [IMPACT + "impactBell_heavy_*.ogg"],
	"casing": [IMPACT + "impactTin_medium_*.ogg"],
	"click": [UI + "click_*.ogg"],
	"confirm": [UI + "confirmation_001.ogg"],
	"back": [UI + "back_001.ogg"],
}
const POOL := 24

var clips := {}  # name -> Array[AudioStream]
var players: Array[AudioStreamPlayer] = []
var next_player := 0


func _ready() -> void:
	for name_ in FILES:
		var found: Array[AudioStream] = []
		for pattern in FILES[name_]:
			for path in _expand(pattern):
				var stream := _load(path)
				if stream:
					found.append(stream)
		clips[name_] = found
	for i in POOL:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)


## Play a sound by name. pitch scales the take; vary is the random +/- around it.
func play(sound: String, volume_db := 0.0, pitch := 1.0, vary := 0.04) -> void:
	var takes: Array = clips.get(sound, [])
	if takes.is_empty():
		return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = takes.pick_random()
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.05, pitch * randf_range(1.0 - vary, 1.0 + vary))
	player.play()


## Play after a short delay (shell casings land a moment after the shot).
func play_later(sound: String, delay: float, volume_db := 0.0, pitch := 1.0) -> void:
	get_tree().create_timer(delay).timeout.connect(play.bind(sound, volume_db, pitch))


func has(sound: String) -> bool:
	return not clips.get(sound, []).is_empty()


func _expand(pattern: String) -> PackedStringArray:
	if not pattern.contains("*"):
		return PackedStringArray([pattern])
	var folder := pattern.get_base_dir()
	var mask := pattern.get_file()
	var out := PackedStringArray()
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.match(mask):
			out.append(folder.path_join(file))
	out.sort()
	return out


func _load(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null
