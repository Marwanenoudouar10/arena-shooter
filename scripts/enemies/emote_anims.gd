extends RefCounted
## Emotes on a character. add_to() copies the clips from emotes.glb into the character's own
## AnimationPlayer (same skeleton, same track paths). An instance plays them on one
## character and brings it back to its idle when a one-shot emote ends.

const Emotes := preload("res://scripts/data/emotes.gd")

static var _clips := {}  # clip name -> Animation (loaded once)
static var _loaded := false

var anim: AnimationPlayer
var idle: String
var active := false
var looping := false
var left := 0.0  # seconds until a one-shot ends


func _init(player: AnimationPlayer, idle_clip: String) -> void:
	anim = player
	idle = idle_clip


## blend = seconds to blend in from what was playing.
func play(emote: Dictionary, blend := 0.2) -> void:
	var clip: String = emote["clip"] if anim.has_animation(emote["clip"]) else Emotes.FALLBACK
	if not anim.has_animation(clip):
		return
	var animation := anim.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR if emote["loop"] else Animation.LOOP_NONE
	anim.play(clip, blend)
	anim.seek(0.0, true)
	active = true
	looping = emote["loop"]
	left = animation.length


func stop() -> void:
	if active and anim.has_animation(idle):
		anim.play(idle, 0.25)
	active = false


## Call every frame. One-shots go back to idle when they end; loops run until stop().
func update(dt: float) -> void:
	if active and not looping:
		left -= dt
		if left <= 0.0:
			stop()


static func add_to(player: AnimationPlayer, load_glb: Callable) -> void:
	_load(load_glb)
	var library := player.get_animation_library("")
	for clip in _clips:
		if not library.has_animation(clip):
			library.add_animation(clip, _clips[clip])


static func _load(load_glb: Callable) -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(Emotes.FILE):
		return
	var source: Node = load_glb.call(Emotes.FILE)
	var players := source.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		for clip in player.get_animation_list():
			var name_ := String(clip)
			_clips[name_.get_slice("|", 1) if name_.contains("|") else name_] = player.get_animation(clip)
	source.free()
