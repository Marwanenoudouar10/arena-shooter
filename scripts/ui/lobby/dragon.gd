extends Node3D
## A glowing white dragon flying slow loops behind the stage, like a hologram over the red
## LED wall. The model is Quaternius' Dragon (CC0, assets/lobby/dragon.glb), drawn with a
## see-through light shader instead of its cartoon colours.

const FILE := "res://assets/lobby/dragon.glb"
const FLY_CLIP := "CharacterArmature|Fast_Flying"
const LAP_TIME := 18.0  # seconds per loop
const CENTER := Vector3(0.6, 2.2, -4.0)
const RADIUS := Vector2(5.2, 1.8)  # x, z of the oval it flies
const SIZE := 0.7  # scale of the model (about 3 m wingspan)
const BODY_UP := 2.4  # the model's body sits this high above its origin (at scale 1)
const HOLOGRAM := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float scan = 0.8 + 0.2 * sin(FRAGCOORD.y * 0.9 - TIME * 8.0);
	ALBEDO = vec3(1.0, 0.96, 0.96) * (0.18 + rim * 1.6) * scan;
}
"""

var model: Node3D
var clock := 0.0


func build(load_glb: Callable) -> void:
	if not FileAccess.file_exists(FILE):
		return
	model = load_glb.call(FILE)
	model.scale = Vector3.ONE * SIZE
	model.position.y = -BODY_UP * SIZE  # fly by the body, not the feet
	add_child(model)
	var shader := Shader.new()
	shader.code = HOLOGRAM
	var glow := ShaderMaterial.new()
	glow.shader = shader
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = glow
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var anim := players[0] as AnimationPlayer
		if anim.has_animation(FLY_CLIP):
			anim.get_animation(FLY_CLIP).loop_mode = Animation.LOOP_LINEAR
			anim.play(FLY_CLIP)


func _process(dt: float) -> void:
	if model == null or not is_visible_in_tree():
		return
	clock += dt
	var angle := clock / LAP_TIME * TAU
	position = _path(angle)
	var ahead := _path(angle + 0.05)
	look_at(ahead, Vector3.UP, true)  # the model faces +Z
	rotation.z = -cos(angle) * 0.35  # lean into the turn


## A point on the oval, rising and dipping a little as it goes.
func _path(angle: float) -> Vector3:
	return CENTER + Vector3(sin(angle) * RADIUS.x, sin(angle * 2.0) * 0.5, cos(angle) * RADIUS.y)
