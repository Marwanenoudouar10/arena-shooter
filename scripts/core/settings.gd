## Saving and loading: your settings and loadout, best scores, and one history line per
## session. Dev runs (any command-line flag) never write anything.

const Guns := preload("res://scripts/data/guns.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Maps := preload("res://scripts/data/maps.gd")
const Viewmodel := preload("res://scripts/weapons/viewmodel/viewmodel.gd")

const SETTINGS_PATH := "user://settings.cfg"
const HISTORY_PATH := "user://history.csv"


static func load_into(game: Node) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	game.sens = cfg.get_value("aim", "sens", game.sens)
	game.fov = cfg.get_value("aim", "fov", game.fov)
	game.move_enabled = cfg.get_value("aim", "move", game.move_enabled)
	game.quality = cfg.get_value("aim", "quality", game.quality)
	game.volume = cfg.get_value("aim", "volume", game.volume)
	if not game.quality in Maps.QUALITY:
		game.quality = "Medium"
	game.map_name = cfg.get_value("aim", "map", game.map_name)
	if not game.map_name in Maps.MAP_NAMES:
		game.map_name = "Open"
	game.gun_name = cfg.get_value("loadout", "gun", game.gun_name)
	game.optic_name = cfg.get_value("loadout", "optic", game.optic_name)
	if not game.optic_name in Viewmodel.OPTICS:
		game.optic_name = "RedDot"
	game.my_class = cfg.get_value("loadout", "class", game.my_class)
	game.enemies = cfg.get_value("loadout", "enemies", game.enemies)
	var saved_outfits: Variant = cfg.get_value("loadout", "outfits", {})
	if saved_outfits is Dictionary:
		game.outfits = saved_outfits
	if not game.gun_name in Guns.GUNS:
		game.gun_name = "Striker"
	if not game.my_class in Classes.PLAYER_CLASSES:
		game.my_class = "Medium"
	if game.enemies != "Mixed" and not game.enemies in Classes.CLASSES:
		game.enemies = "Mixed"
	if cfg.has_section("best"):
		for key in cfg.get_section_keys("best"):
			game.best[key] = cfg.get_value("best", key, 0.0)


static func save(game: Node) -> void:
	if game.dev_run:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("aim", "sens", game.sens)
	cfg.set_value("aim", "fov", game.fov)
	cfg.set_value("aim", "move", game.move_enabled)
	cfg.set_value("aim", "quality", game.quality)
	cfg.set_value("aim", "volume", game.volume)
	cfg.set_value("loadout", "gun", game.gun_name)
	cfg.set_value("loadout", "optic", game.optic_name)
	cfg.set_value("loadout", "class", game.my_class)
	cfg.set_value("loadout", "enemies", game.enemies)
	cfg.set_value("loadout", "outfits", game.outfits)
	cfg.set_value("aim", "map", game.map_name)
	for key in game.best:
		cfg.set_value("best", key, game.best[key])
	cfg.save(SETTINGS_PATH)


## One line per session so progress over days can be compared.
static func append_history(game: Node, mode_name: String, score: float, detail: String) -> void:
	if game.dev_run:
		return
	var exists := FileAccess.file_exists(HISTORY_PATH)
	var f := FileAccess.open(HISTORY_PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		return
	if exists:
		f.seek_end()
	else:
		f.store_line("date,mode,score,sens,fov,detail")
	f.store_line("%s,%s,%.1f,%.4f,%d,%s" % [Time.get_datetime_string_from_system(), mode_name, score, game.sens, int(game.fov), detail])
