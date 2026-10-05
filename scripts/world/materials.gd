## Surface materials: photo textures (Poly Haven, CC0) with a generated fallback.


## Photo PBR material from assets/textures/<name>_{diff,nor_gl,rough}_1k.jpg, world-mapped
## so one texture repeat covers `tile_m` metres on every box. `grade` = brightness,
## contrast, saturation applied to the colour photo before `tint`.
static func photo(tex_name: String, tile_m: float, tint: Color, grade: Vector3, fallback: Callable) -> Material:
	var base := "res://assets/textures/%s_%s_1k.jpg"
	var albedo := load_texture(base % [tex_name, "diff"], grade)
	if albedo == null:
		return fallback.call()  # only built when the photo is missing
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load_texture(base % [tex_name, "nor_gl"])
	mat.roughness_texture = load_texture(base % [tex_name, "rough"])
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / tile_m
	return mat


static func load_texture(path: String, grade := Vector3.ONE) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	if grade != Vector3.ONE:
		img.adjust_bcs(grade.x, grade.y, grade.z)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Painted/concrete surface: noisy base colour with a seam line every `tile_m` metres
## and a bumpy normal map. World-mapped, so it tiles evenly on boxes of any size.
static func painted(base: Color, seam: Color, tile_m: float, variation: float, roughness: float, noise_seed: int) -> StandardMaterial3D:
	const SIZE := 256
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var c := seam
			if x >= 3 and y >= 3:  # the noise does not wrap, the seam line hides the edge
				var n := noise.get_noise_2d(x, y)
				c = base.lightened(n * variation) if n > 0.0 else base.darkened(-n * variation)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var bumps := NoiseTexture2D.new()
	bumps.width = SIZE
	bumps.height = SIZE
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 4.0
	bumps.noise = FastNoiseLite.new()
	bumps.noise.seed = noise_seed + 100
	bumps.noise.frequency = 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.normal_enabled = true
	mat.normal_texture = bumps
	mat.normal_scale = 0.35
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / tile_m
	return mat
