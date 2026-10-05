extends Node
## Pictures for the lobby's cards, rendered once at start: every gun from the side, every
## piece of clothing from the front, and your character frozen in the middle of each emote,
## each in its own little studio (a SubViewport with a clear background). New guns, clothes
## or emotes get a picture with no extra work.

const Kit := preload("res://scripts/enemies/character_kit.gd")

const GUN_SIZE := Vector2i(320, 200)
const PART_SIZE := Vector2i(220, 240)
const EMOTE_SIZE := Vector2i(200, 260)
const EmoteAnims := preload("res://scripts/enemies/emote_anims.gd")

var load_glb: Callable
var _cache := {}  # file -> Texture2D


func _init(loader: Callable) -> void:
	load_glb = loader


## A gun seen from its right side, barrel pointing right.
func gun(file: String) -> Texture2D:
	if not _cache.has(file):
		var model: Node3D = load_glb.call(file)
		for node in model.find_children("scope", "", true, false):
			(node as Node3D).hide()  # the sniper's own scope; the game fits optics separately
		_cache[file] = _render(model, Vector3(0.0, 0.12, 1.0), GUN_SIZE)
	return _cache[file]


## A piece of clothing (or a head) seen from the front, a little from the side.
func part(id: String) -> Texture2D:
	var file := Kit.PARTS_DIR + id + ".glb"
	if not _cache.has(file):
		_cache[file] = _render(load_glb.call(file), Vector3(0.45, 0.1, 1.0), PART_SIZE)
	return _cache[file]


## Your character (made by `make_character`) frozen partway through the emote.
func emote(emote_info: Dictionary, make_character: Callable) -> Texture2D:
	var key: String = "emote:" + emote_info["id"]
	if not _cache.has(key):
		var person: Node3D = make_character.call()
		_cache[key] = _render(person, Vector3(0.35, 0.05, 1.0), EMOTE_SIZE)
		var anim: AnimationPlayer = person.find_children("*", "AnimationPlayer", true, false)[0]
		var player := EmoteAnims.new(anim, "")
		player.play(emote_info, 0.0)  # no blend, or the frozen frame would still be the idle
		anim.seek(player.left * 0.45, true)
		anim.pause()
	return _cache[key]


func _render(model: Node3D, view_from: Vector3, size: Vector2i) -> Texture2D:
	var view := SubViewport.new()
	view.size = size
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)
	view.add_child(model)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	var dir := view_from.normalized()
	_light(view, Color(1.0, 0.95, 0.88), 1.8, dir + Vector3(-0.6, 0.8, 0.0))
	_light(view, Color(1.0, 0.55, 0.3), 1.2, Vector3(0.7, 0.4, -1.0))  # warm rim from behind
	var bounds := _bounds(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := float(size.x) / size.y
	var wide := Vector2(bounds.size.x, bounds.size.z).length() if dir.x != 0.0 else bounds.size.x
	cam.size = maxf(bounds.size.y, wide / aspect) * 1.12
	cam.near = 0.01
	cam.far = bounds.size.length() * 4.0 + 2.0
	view.add_child(cam)
	cam.look_at_from_position(bounds.get_center() + dir * (bounds.size.length() + 1.0), bounds.get_center())
	return view.get_texture()


func _light(view: SubViewport, color: Color, energy: float, from: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	view.add_child(light)
	light.look_at_from_position(from, Vector3.ZERO)


## Everything the model shows, in world space.
func _bounds(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
