## Command-line dev runs: --selftest, --thumbs, --shot=out.png [flags]. See CLAUDE.md.

const SelfTest := preload("res://scripts/dev/self_test.gd")
const DebugShot := preload("res://scripts/dev/debug_shot.gd")
const Thumbnails := preload("res://scripts/dev/thumbnails.gd")


## Runs the dev task the flags ask for. Returns false when there is none (play normally).
static func run(g: Node3D, args: PackedStringArray) -> bool:
	if "--thumbs" in args:
		await Thumbnails.make(g)
		return true
	if "--selftest" in args:
		await SelfTest.run(g)
		return true
	for arg in args:
		if arg.begins_with("--shot="):
			await DebugShot.take(g, arg.substr(7), args)
			return true
	return false
