extends Node
## Renders the game for a few seconds and saves screenshots (used to check shaders and look).

var game
var frame := 0
var out := ""

func _ready() -> void:
	Engine.max_fps = 30
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	frame += 1
	if frame == 3:
		game._on_action("start_survival")
		game.shark.x = 4.0; game.shark.z = 6.0; game.shark.timer = 999.0
	if frame == 90:
		get_viewport().get_texture().get_image().save_png(out + "/g1.png")
		game.cam_pitch = 0.22; game.cam_dist = 9.0; game.cam_yaw = 2.3
	if frame == 130:
		get_viewport().get_texture().get_image().save_png(out + "/g2.png")
		get_tree().quit()
