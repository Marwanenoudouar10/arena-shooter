extends Node3D
## Where bullets land: bullet holes (decals) and a puff of dust on walls and floors,
## sparks on enemies, and a quick tracer from the muzzle. Everything is pooled so
## automatic fire costs nothing extra.

const HOLES := 80
const PUFFS := 10
const TRACERS := 8
const HOLE_SIZE := 0.13

var holes: Array[Decal] = []
var next_hole := 0
var puffs: Array[CPUParticles3D] = []
var sparks: Array[CPUParticles3D] = []
var next_puff := 0
var tracers: Array[Dictionary] = []  # {node, life}
var next_tracer := 0


func _ready() -> void:
	var hole_tex := _hole_texture()
	for i in HOLES:
		var hole := Decal.new()
		hole.texture_albedo = hole_tex
		hole.size = Vector3(HOLE_SIZE, 0.06, HOLE_SIZE)
		hole.upper_fade = 0.2
		hole.lower_fade = 0.2
		hole.cull_mask = 1  # the world only, never your gun or arms
		hole.visible = false
		add_child(hole)
		holes.append(hole)
	for i in PUFFS:
		puffs.append(_burst(Color(0.6, 0.58, 0.54, 0.7), 16, 0.12, 1.4, 0.6, 1.5))
		sparks.append(_burst(Color(1.0, 0.75, 0.35), 10, 0.025, 4.5, 0.18, 6.0, true))
	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.5)
	for i in TRACERS:
		var line := CylinderMesh.new()
		line.top_radius = 0.004
		line.bottom_radius = 0.004
		line.height = 1.0
		line.radial_segments = 4
		line.rings = 1
		var node := MeshInstance3D.new()
		node.mesh = line
		node.material_override = tracer_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		tracers.append({"node": node, "life": 0.0})


## A shot landed on a surface: hole facing out of it, dust puff.
func surface(point: Vector3, normal: Vector3) -> void:
	var hole := holes[next_hole]
	next_hole = (next_hole + 1) % holes.size()
	var side := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	hole.global_transform = Transform3D(Basis(side, normal, side.cross(normal)).rotated(normal, randf() * TAU), point)
	hole.scale = Vector3.ONE * randf_range(0.8, 1.2)
	hole.visible = true
	var puff := puffs[next_puff]
	next_puff = (next_puff + 1) % puffs.size()
	puff.global_position = point + normal * 0.02
	puff.direction = normal
	puff.restart()


## A shot hit an enemy: a quick spray of sparks.
func body(point: Vector3, toward_shooter: Vector3) -> void:
	var spark := sparks[next_puff]
	next_puff = (next_puff + 1) % sparks.size()
	spark.global_position = point
	spark.direction = toward_shooter
	spark.restart()


func tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var item := tracers[next_tracer]
	next_tracer = (next_tracer + 1) % tracers.size()
	var node: MeshInstance3D = item["node"]
	var dir := (to - from) / length
	node.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)).scaled(Vector3(1, length, 1)), (from + to) / 2.0)
	node.visible = true
	item["life"] = 0.035


func clear() -> void:
	for hole in holes:
		hole.visible = false


func _process(dt: float) -> void:
	for item in tracers:
		if item["life"] > 0.0:
			item["life"] -= dt
			item["node"].visible = item["life"] > 0.0


func _burst(color: Color, amount: int, size: float, speed: float, life: float, gravity: float, glow := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.spread = 35.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_dot()  # round, soft-edged, not square
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	if glow:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	p.mesh = quad
	add_child(p)
	return p


var _dot: GradientTexture2D


func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot


## Dark scorched centre, broken ring of chipped material around it.
func _hole_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.18
	for y in size:
		for x in size:
			var p := Vector2(x, y) / (size - 1) * 2.0 - Vector2.ONE
			var r := p.length() + noise.get_noise_2d(x, y) * 0.18
			var core := 1.0 - smoothstep(0.22, 0.34, r)
			var chip := (1.0 - smoothstep(0.38, 0.85, r)) * 0.85
			var a := clampf(maxf(core, chip), 0.0, 1.0)
			var shade := lerpf(0.16, 0.02, core)
			img.set_pixel(x, y, Color(shade, shade * 0.97, shade * 0.94, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
