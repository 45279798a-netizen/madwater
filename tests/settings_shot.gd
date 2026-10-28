extends Node
## The graphics settings sheet on a phone-sized screen, and the same view on the low and ultra presets.

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
		game.shark_on = false
		game.weather.t = 999.0
		game.game_t = 60.0
		game._on_action("settings")
	if f == 40:
		get_viewport().get_texture().get_image().save_png(out + "/set_sheet.png")
		game._close_sheet()
		game.gfx.use_preset("low")
		game.gfx.apply(game)
		game.cam_pitch = 0.3; game.cam_dist = 7.0; game.cam_yaw = 0.8
	if f == 80:
		get_viewport().get_texture().get_image().save_png(out + "/set_low.png")
		game.gfx.use_preset("ultra")
		game.gfx.apply(game)
	if f == 120:
		get_viewport().get_texture().get_image().save_png(out + "/set_ultra.png")
		DirAccess.remove_absolute(Gfx.PATH)
		get_tree().quit()
