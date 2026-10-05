extends Node
## See-through hitboxes drawn on the enemy (screenshot flag --hitboxes): a sphere for the
## head and a capsule for the body, following the bones every frame.

var game: Node3D
var head: MeshInstance3D
var body: MeshInstance3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 1.0, 0.5, 0.35)
	mat.no_depth_test = true
	head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.material_override = mat
	game.add_child(head)
	body = MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.material_override = mat
	game.add_child(body)


func _process(_dt: float) -> void:
	var enemy: Node = game.enemy
	var head_radius: float = enemy.head_radius()
	var body_radius: float = enemy.body_radius()
	var sphere := head.mesh as SphereMesh
	sphere.radius = head_radius
	sphere.height = head_radius * 2.0
	head.global_position = enemy.head_center()
	var ends: Array[Vector3] = enemy.body_ends()
	var capsule := body.mesh as CapsuleMesh
	capsule.radius = body_radius
	capsule.height = (ends[1] - ends[0]).length() + body_radius * 2.0
	body.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, (ends[1] - ends[0]).normalized())), (ends[0] + ends[1]) / 2.0)
