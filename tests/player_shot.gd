extends Node3D
## Portrait of the castaway: idle, mid-stride, at the wheel, and a friend in another shirt.

var rigs := []
var f := 0
var t := 0.0

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2c6cb0")
	sm.sky_horizon_color = Color("a9c8dc")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	sun.shadow_enabled = true
	add_child(sun)
	Models.part(self, Models.box(8, 0.1, 3), Models.tm(Color("a08060"), "planks", 0.9, 1.0), Vector3(0, -0.05, 0))
	for i in 4:
		var r := PlayerRig.new()
		r.position = Vector3(-2.4 + i * 1.6, 0, 0)
		r.rotation.y = [0.4, PI / 2 + 0.3, -0.3, -0.6][i]
		add_child(r)
		rigs.append(r)
	rigs[3].set_shirt(Color("3b8fe8"))
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 1.5, 6.2)
	cam.look_at(Vector3(0, 0.95, 0))

func _process(dt: float) -> void:
	f += 1
	t += 1.0 / 30.0
	rigs[0].animate(1.0 / 30.0, false, "", t)
	rigs[1].animate(1.0 / 30.0, true, "", t)
	rigs[2].animate(1.0 / 30.0, false, "steer", t)
	rigs[3].animate(1.0 / 30.0, false, "fish", t)
	if f == 40:
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/player.png")
		get_tree().quit()
