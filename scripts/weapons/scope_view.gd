extends Node
## The scope's magnified picture: a second camera renders the world (not your gun) zoomed
## in, and it is drawn over the scope's lens where the lens sits on screen.

const SHOWS_AT := 0.6  # how far into aiming the scope's lens shows the zoomed picture
# Inside the scope lens: round picture, dark edge like a real eyepiece, fine crosshair with
# heavy outer posts and a small lit centre dot.
const SCOPE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	vec3 col = texture(TEXTURE, UV).rgb;
	col *= smoothstep(1.0, 0.72, r) * 0.85 + 0.15;
	float w = fwidth(p.x) * 1.2;
	float thin = (1.0 - smoothstep(0.0, w, abs(p.x))) * step(0.06, abs(p.y)) + (1.0 - smoothstep(0.0, w, abs(p.y))) * step(0.06, abs(p.x));
	float posts = (1.0 - smoothstep(0.0, w * 4.0, abs(p.x))) * step(0.55, abs(p.y)) + (1.0 - smoothstep(0.0, w * 4.0, abs(p.y))) * step(0.55, abs(p.x));
	col = mix(col, vec3(0.02), clamp(thin + posts, 0.0, 1.0));
	col = mix(col, vec3(1.0, 0.15, 0.08), 1.0 - smoothstep(0.012, 0.02, r));
	COLOR = vec4(col, 1.0);
}
"""

var game: Node3D
var view: SubViewport  # renders the magnified picture seen inside the scope's lens
var cam: Camera3D
var overlay: TextureRect


func build(ui: CanvasLayer) -> void:
	view = SubViewport.new()
	view.size = Vector2i(720, 720)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.add_child(view)
	cam = Camera3D.new()
	cam.cull_mask = 1  # the world only, not your gun and arms
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	view.add_child(cam)
	overlay = TextureRect.new()
	overlay.texture = view.get_texture()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lens_shader := Shader.new()
	lens_shader.code = SCOPE_SHADER
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = lens_shader
	overlay.material = lens_mat
	overlay.hide()
	ui.add_child(overlay)


## The scope's lens shows the world magnified, drawn over the lens where it sits on screen.
func update(ads: float) -> void:
	var eye: Camera3D = game.cam
	var lens: Dictionary = game.viewmodel.scope_lens() if ads >= SHOWS_AT else {}
	var on := not lens.is_empty() and not eye.is_position_behind(lens["center"])
	overlay.visible = on
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		return
	var center := eye.unproject_position(lens["center"])
	var edge := eye.unproject_position(lens["center"] + eye.global_basis.y * lens["radius"])
	var radius := maxf(center.distance_to(edge), 8.0)
	var view_size := game.get_viewport().get_visible_rect().size
	overlay.position = center - Vector2(radius, radius)
	overlay.size = Vector2(radius, radius) * 2.0
	# Same direction as your eye; the lens covers this much of your view, shown 4x bigger.
	cam.global_transform = eye.global_transform
	var lens_view := 2.0 * atan(radius * 2.0 / view_size.x * tan(deg_to_rad(eye.fov) / 2.0))
	var magnification: float = game.viewmodel.magnification()
	cam.fov = rad_to_deg(lens_view / magnification)
