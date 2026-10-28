class_name SkyClouds
extends RefCounted
## The sky material (shaders/sky.gdshader) behind the same colour properties ProceduralSkyMaterial
## had, so the day / night and weather code can keep writing sky_top_color and friends.

var mat := ShaderMaterial.new()

var sky_top_color := Color("2c6cb0"):
	set(v):
		sky_top_color = v
		mat.set_shader_parameter("sky_top_color", v)
var sky_horizon_color := Color("a9c8dc"):
	set(v):
		sky_horizon_color = v
		mat.set_shader_parameter("sky_horizon_color", v)
var ground_horizon_color := Color("a9c8dc"):
	set(v):
		ground_horizon_color = v
		mat.set_shader_parameter("ground_horizon_color", v)
var ground_bottom_color := Color("0b2a40"):
	set(v):
		ground_bottom_color = v
		mat.set_shader_parameter("ground_bottom_color", v)


func _init() -> void:
	mat.shader = load("res://shaders/sky.gdshader")
	mat.set_shader_parameter("octaves", 4 if OS.has_feature("web") or Hud.is_touch() else 5)


## Cloud look for this moment: cover 0..1, storm 0..1, lit / shade colours, night 0..1, drift seconds.
func set_clouds(cover: float, storm: float, lit: Color, shade: Color, night: float, drift: float) -> void:
	mat.set_shader_parameter("cover", cover)
	mat.set_shader_parameter("storm", storm)
	mat.set_shader_parameter("cloud_lit", lit)
	mat.set_shader_parameter("cloud_shade", shade)
	mat.set_shader_parameter("night", night)
	mat.set_shader_parameter("drift", drift)
