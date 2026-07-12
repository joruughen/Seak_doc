extends MeshInstance3D

var material: ShaderMaterial
var noise: Image

var noise_scale: float
var noise_scale2: float
var wave_speed: float
var height_scale: float
var wave_blend: float
var wave_sharpness: float
var wave_direction: Vector2
var wave_direction2: Vector2

var time: float = 0.0


func _ready():
	material = mesh.surface_get_material(0)
	noise = material.get_shader_parameter("wave").noise.get_seamless_image(512, 512)
	noise_scale = material.get_shader_parameter("noise_scale")
	noise_scale2 = material.get_shader_parameter("noise_scale2")
	wave_speed = material.get_shader_parameter("wave_speed")
	height_scale = material.get_shader_parameter("height_scale")
	wave_blend = material.get_shader_parameter("wave_blend")
	wave_sharpness = material.get_shader_parameter("wave_sharpness")
	wave_direction = material.get_shader_parameter("wave_direction")
	wave_direction2 = material.get_shader_parameter("wave_direction2")


func _process(delta):
	time += delta
	material.set_shader_parameter("wave_time", time)


func get_height(world_position: Vector3) -> float:
	return global_position.y + _wave_height(Vector2(world_position.x, world_position.z)) * height_scale


# Gemelo exacto de wave_height() en Water2.gdshader.
# Cualquier cambio en la fórmula del shader debe replicarse aquí.
func _wave_height(pos: Vector2) -> float:
	var t := time * wave_speed
	var uv1 := pos / noise_scale + t * wave_direction
	var uv2 := pos / noise_scale2 - t * 1.31 * wave_direction2
	var h := lerpf(_sample_noise(uv1), _sample_noise(uv2), wave_blend)
	return pow(h, wave_sharpness)


# Muestreo bilineal con wrap, equivalente a texture() sobre la textura seamless.
func _sample_noise(uv: Vector2) -> float:
	var w := noise.get_width()
	var h := noise.get_height()
	var x := wrapf(uv.x, 0.0, 1.0) * float(w)
	var y := wrapf(uv.y, 0.0, 1.0) * float(h)
	var x0 := int(x) % w
	var y0 := int(y) % h
	var x1 := (x0 + 1) % w
	var y1 := (y0 + 1) % h
	var fx := x - floorf(x)
	var fy := y - floorf(y)
	var top := lerpf(noise.get_pixel(x0, y0).r, noise.get_pixel(x1, y0).r, fx)
	var bottom := lerpf(noise.get_pixel(x0, y1).r, noise.get_pixel(x1, y1).r, fx)
	return lerpf(top, bottom, fy)
