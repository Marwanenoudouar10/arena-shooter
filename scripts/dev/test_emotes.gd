## Self-test: the lobby's EMOTES screen plays emotes on your character (gun put away), and in
## a match the wheel picks one, the camera goes third person and moving ends it.

const E := preload("res://scripts/core/enums.gd")
const Emotes := preload("res://scripts/data/emotes.gd")
const T := preload("res://scripts/dev/test_helpers.gd")


static func run(g: Node3D) -> void:
	_lobby(g)
	await _match(g)


static func _lobby(g: Node3D) -> void:
	var lobby: Control = g.lobby
	g.session.show_menu()
	lobby.show_screen("emotes")
	var cards: int = lobby.emote_ui.grid.get_child_count()
	T.check(cards == Emotes.LIST.size(), "emote screen shows %d cards" % cards)
	lobby.emote_ui._play(Emotes.LIST[2])  # clap, loops
	var me: Dictionary = lobby.characters[lobby.choice["class"]]
	var gun_shown: bool = me["guns"][lobby.choice["gun"]].visible
	T.check(me["emotes"].active and not gun_shown, "lobby emote did not play or the gun stayed in hand")
	lobby.show_screen("main")
	T.check(not me["emotes"].active and me["guns"][lobby.choice["gun"]].visible, "leaving the emote screen did not stop it")
	print("emotes: %d in the lobby, gun put away while emoting" % cards)


static func _match(g: Node3D) -> void:
	var emote: Node = g.emote
	g.session.start_round(E.Mode.TRACKING, false)
	g.state = E.State.PLAYING
	emote.wheel.open()
	emote.wheel.steer(Vector2(100, -30))  # toward the slot right of top-right
	T.check(emote.wheel.close() == 2, "wheel picked the wrong slot")
	emote.start(Emotes.LIST[0])
	await T.frames(g, 5)
	var eye: Vector3 = g.player.pos + Vector3(0, g.player.eye, 0)
	T.check(emote.active() and emote.body.visible and not g.viewmodel.visible, "third-person emote did not start")
	T.check(g.cam.position.distance_to(eye) > 2.0, "camera did not swing out for the emote")
	T.press(KEY_W, true)
	await T.frames(g, 2)
	T.press(KEY_W, false)
	T.check(not emote.active() and g.viewmodel.visible and not emote.body.visible, "moving did not end the emote")
	print("emotes: wheel picks, camera goes third person, moving ends it")
