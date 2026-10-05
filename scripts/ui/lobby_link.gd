extends Node
## Connects the lobby to the game: hands it everything it shows (maps, guns, classes,
## clothes, settings, your last loadout) and applies what you pick there right away.

const E := preload("res://scripts/core/enums.gd")
const Guns := preload("res://scripts/data/guns.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Maps := preload("res://scripts/data/maps.gd")
const Kit := preload("res://scripts/enemies/character_kit.gd")
const Glb := preload("res://scripts/core/glb.gd")
const EmoteAnims := preload("res://scripts/enemies/emote_anims.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")
const Lobby := preload("res://scripts/ui/lobby/lobby.gd")

var game: Node3D


func build(ui: CanvasLayer) -> Lobby:
	var lobby := Lobby.new()
	ui.add_child(lobby)
	lobby.setup(_menu_data())
	lobby.play.connect(func(play_mode: String) -> void:
		game.session.start_round(E.Mode.FLICKS if play_mode == "flicks" else E.Mode.TRACKING))
	lobby.calibrate.connect(func() -> void: game.session.start_calibration())
	lobby.quit.connect(func() -> void: get_tree().quit())
	lobby.setting_changed.connect(_on_setting_changed)
	lobby.loadout_changed.connect(_on_loadout_changed)
	return lobby


## Your character for the lobby, in your clothes, with the emotes, idle animation starting
## once it is shown.
func preview_character(cls: String) -> Node3D:
	var root := Kit.build(game.my_look(cls), Glb.scene)
	var anim: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	EmoteAnims.add_to(anim, Glb.scene)
	for clip in ["CharacterArmature|Idle_Gun", "CharacterArmature|Idle", "Idle"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.autoplay = clip
			break
	return root


## Everything the menu shows: arenas, guns, classes, settings and the last loadout.
func _menu_data() -> Dictionary:
	var map_items := []
	for map_id in Maps.MAP_NAMES:
		map_items.append({"id": map_id, "name": Maps.MAP_INFO[map_id]["name"], "desc": Maps.MAP_INFO[map_id]["desc"],
				"thumb": "res://assets/ui/map_%s.png" % map_id.to_lower(),
				"enabled": map_id == "Open" or not game.world.maps.get(map_id, {}).is_empty()})
	var gun_items := []
	for gun_id in Guns.GUN_NAMES:
		var g: Dictionary = Guns.GUNS[gun_id]
		gun_items.append({"id": gun_id, "name": gun_id, "file": g["file"], "class": g["class"], "optics": g["optics"]})
	var class_items := []
	for cls_id in Classes.CLASS_NAMES:
		class_items.append({"id": cls_id, "name": cls_id})
	return {
		"maps": map_items, "guns": gun_items, "classes": class_items,
		"settings": {"sens": game.sens, "fov": game.fov, "move": game.move_enabled, "quality": game.quality,
				"qualities": Maps.QUALITY_NAMES, "volume": game.volume},
		"sfx": func(sound: String) -> void: game.sfx.play(sound, -8.0, 1.0, 0.02),
		"choice": {"map": game.map_name, "gun": game.gun_name, "optic": game.optic_name, "class": game.my_class,
				"enemies": game.enemies, "outfits": game.outfits.duplicate(true)},
		"optics": Viewmodel.OPTIC_IDS.map(func(id: String) -> Array: return [id, Viewmodel.OPTICS[id]["name"]]),
		"load_glb": Glb.scene, "load_character": preview_character,
	}


## The lobby's choices (map, class, weapon, sight, enemies, clothes) take effect right away.
func _on_loadout_changed(choice: Dictionary) -> void:
	game.map_name = choice["map"]
	game.gun_name = choice["gun"]
	game.optic_name = choice.get("optic", game.optic_name)
	game.my_class = choice["class"]
	game.enemies = choice["enemies"]
	if choice.get("outfits", game.outfits) != game.outfits:
		game.outfits = choice["outfits"].duplicate(true)
		if game.viewmodel:
			for cls in game.viewmodel.bodies:
				Kit.dress(game.viewmodel.bodies[cls]["root"], game.my_look(cls), Glb.scene)
	if game.viewmodel == null:
		return
	game.apply_map()
	game.apply_gun()
	if game.enemies != "Mixed":
		game.enemy.kind = game.enemies
		game.enemy.apply_class()
	Settings.save(game)


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"sens":
			game.sens = value
		"fov":
			game.fov = value
			game.cam.fov = value
		"move":
			game.move_enabled = value
		"quality":
			game.quality = value
			game.world.apply_quality(value)
		"volume":
			game.volume = value
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
	Settings.save(game)
