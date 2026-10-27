extends Node
## Studio shots of the shark model: side view with closed mouth, front-three-quarter with open jaws.

var game
var f := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.shark_on = true
		game.hud.visible = false
	if f > 2:
		game.shark.state = "circle"; game.shark.timer = 999.0
		game.shark.x = 1.0; game.shark.z = 9.0; game.shark.head = 0.0
		game.raft.visible = false
	if f == 40:
		_place_cam(Vector3(1.2, 0.6, 15.5))
	if f == 50:
		get_viewport().get_texture().get_image().save_png(out + "/sh_side.png")
		game.shark.jaw = 1.0
		game.shark_rig.set_jaw(1.0)
		_place_cam(Vector3(5.5, 0.9, 12.0))
	if f > 50:
		game.shark.jaw = 1.0
	if f == 60:
		get_viewport().get_texture().get_image().save_png(out + "/sh_mouth.png")
		_place_cam(Vector3(2.0, 4.5, 13.0))
	if f == 70:
		get_viewport().get_texture().get_image().save_png(out + "/sh_top.png")
		get_tree().quit()

func _place_cam(p: Vector3) -> void:
	game.set_process(false)
	game.shark_rig.position = Vector3(1.0, -0.05, 9.0)
	game.shark_rig.rotation = Vector3.ZERO
	game.shark_rig.set_jaw(game.shark.jaw)
	game.cam.global_position = p
	game.cam.look_at(Vector3(1.0, 0.0, 9.0), Vector3.UP)
