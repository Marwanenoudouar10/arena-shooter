## The self-test (flag --selftest): drives the real game and checks that everything works.
## Prints one line per area and SELFTEST OK at the end, or FAIL lines and SELFTEST FAILED.
## Areas run in this order because some reuse what the one before set up.

const E := preload("res://scripts/core/enums.gd")
const TestShooting := preload("res://scripts/dev/test_shooting.gd")
const TestTargets := preload("res://scripts/dev/test_targets.gd")
const TestGear := preload("res://scripts/dev/test_gear.gd")
const TestEmotes := preload("res://scripts/dev/test_emotes.gd")
const T := preload("res://scripts/dev/test_helpers.gd")


static func run(g: Node3D) -> void:
	g.map_name = "Open"  # saved settings may differ; tests set what they need
	g.apply_map()
	g.gun_name = "Striker"
	g.optic_name = "RedDot"
	g.my_class = "Medium"
	g.enemies = "Medium"
	g.apply_gun()
	await TestShooting.run(g)
	await TestTargets.run(g)
	await TestGear.run(g)
	await TestEmotes.run(g)

	g.session.start_calibration()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await g.get_tree().process_frame
	g.session.show_menu()
	if T.failures == 0:
		print("SELFTEST OK")
		g.get_tree().quit()
	else:
		print("SELFTEST FAILED: %d checks" % T.failures)
		g.get_tree().quit(1)
