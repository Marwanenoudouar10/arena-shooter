extends RefCounted
## The lobby's studio set, red and white only: lights, dust, a white glossy floor and the
## turntable, white light pillars, and a big curved red LED wall with white light lines
## moving across it. build() makes it all inside the stage's SubViewport.

const Widgets := preload("res://scripts/ui/lobby/widgets.gd")
const ACCENT := Widgets.ACCENT

var viewport: SubViewport
var turntable: Node3D


## Builds the set into `view` and returns the turntable (characters stand on it).
func build(view: SubViewport) -> Node3D:
	viewport = view
	_build_set()
	_build_lights()
	_build_dust()
	return turntable


# The LED wall: dark-to-bright red, white lines sweeping across, a slow pulse.
const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 red = vec3(0.78, 0.04, 0.08);
uniform vec3 deep = vec3(0.32, 0.0, 0.03);
void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float glow = smoothstep(0.0, 0.55, uv.y) * (1.0 - smoothstep(0.8, 1.0, uv.y));
	vec3 col = mix(deep, red, 0.25 + glow * 0.75);
	float bands = fract(uv.x * 7.0 + uv.y * 2.5 - t * 0.12);
	col = mix(col, vec3(1.0), (smoothstep(0.0, 0.015, bands) - smoothstep(0.015, 0.05, bands)) * 0.55);
	float wave = sin(uv.x * 18.0 + t * 0.9 + sin(uv.y * 5.0 + t * 0.6) * 2.5);
	col = mix(col, vec3(1.0), smoothstep(0.985, 1.0, wave) * 0.35);
	float pulse = 0.5 + 0.5 * sin(t * 0.7 - uv.x * 3.0);
	ALBEDO = col * (0.85 + 0.15 * pulse);
}
"""


func _build_set() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.85, 0.85)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.015
	env.fog_light_color = Color(0.5, 0.08, 0.1)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.94)
	white.roughness = 0.12
	white.metallic = 0.1
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	_mesh(floor_mesh, white, Vector3.ZERO)

	turntable = Node3D.new()
	viewport.add_child(turntable)
	var plinth := CylinderMesh.new()
	plinth.top_radius = 1.0
	plinth.bottom_radius = 1.05
	plinth.height = 0.14
	plinth.radial_segments = 64
	_mesh(plinth, white, Vector3(0, 0.07, 0), turntable)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.035
	ring.rings = 96
	_mesh(ring, _glow(ACCENT, 4.0), Vector3(0, 0.142, 0), turntable)

	# The LED wall: a tall curved screen around the back of the stage.
	var wall := CylinderMesh.new()
	wall.top_radius = 8.0
	wall.bottom_radius = 8.0
	wall.height = 9.0
	wall.radial_segments = 96
	wall.cap_top = false
	wall.cap_bottom = false
	var wall_shader := Shader.new()
	wall_shader.code = WALL_SHADER
	var wall_mat := ShaderMaterial.new()
	wall_mat.shader = wall_shader
	_mesh(wall, wall_mat, Vector3(0, 4.5, -0.5))
	# White light pillars in an arc in front of the wall.
	for i in 7:
		var a := deg_to_rad(-63.0 + i * 21.0)
		var pillar := BoxMesh.new()
		pillar.size = Vector3(0.06, 5.4, 0.06)
		_mesh(pillar, _glow(Color.WHITE, 3.0), Vector3(sin(a) * 6.2, 2.7, -cos(a) * 6.2 - 0.5))


## White key light, red rim light, soft fill.
func _build_lights() -> void:
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.97, 0.95)
	key.light_energy = 6.0
	key.spot_range = 12.0
	key.spot_angle = 28.0
	key.shadow_enabled = true
	viewport.add_child(key)
	key.look_at_from_position(Vector3(-2.2, 4.6, 3.4), Vector3(0, 1.0, 0), Vector3.UP)
	var rim := SpotLight3D.new()
	rim.light_color = ACCENT
	rim.light_energy = 9.0
	rim.spot_range = 10.0
	rim.spot_angle = 30.0
	viewport.add_child(rim)
	rim.look_at_from_position(Vector3(2.4, 3.2, -2.8), Vector3(0, 1.2, 0), Vector3.UP)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.9, 0.9)
	fill.light_energy = 0.8
	fill.omni_range = 7.0
	fill.position = Vector3(3.0, 1.6, 2.5)
	viewport.add_child(fill)


## Dust drifting through the light.
func _build_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 160
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(3.5, 2.5, 2.5)
	motion.gravity = Vector3(0, 0.01, 0)
	motion.initial_velocity_min = 0.02
	motion.initial_velocity_max = 0.08
	motion.direction = Vector3(0.3, 1, 0)
	motion.spread = 180.0
	dust.process_material = motion
	var mote := QuadMesh.new()
	mote.size = Vector2(0.012, 0.012)
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.albedo_color = Color(1, 1, 1, 0.35)
	mote.material = mote_mat
	dust.draw_pass_1 = mote
	dust.position = Vector3(0, 2.4, 0)
	viewport.add_child(dust)


func _mesh(mesh: Mesh, mat: Material, at: Vector3, parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	(parent if parent else viewport).add_child(node)
	return node


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
