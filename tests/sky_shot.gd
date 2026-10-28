extends Node
## The sky and clouds at noon, at sunset, in a storm, and at night (SHOT_DIR/sky_*.png).

var game
var f := 0
var out := ""
var shots := [["noon", 38.0, 0.0, 0.7], ["dusk", 93.0, 0.0, 1.9], ["storm", 50.0, 1.0, 0.7], ["night", 150.0, 0.0, 0.7]]

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.shark_on = false
	var i := (f - 10) / 40
	if f >= 10 and i < shots.size():
		var s: Array = shots[i]
		game.game_t = s[1]
		game.weather.t = 999.0
		game.weather.kind = "storm" if s[2] > 0.5 else "clear"
		game.weather.cloud = s[2]
		game.weather.storm = s[2]
		game.weather.rain = s[2]
		game.cam_yaw = s[3]; game.cam_pitch = 0.1; game.cam_dist = 6.0
		if (f - 10) % 40 == 39:
			game.hud.visible = false
			get_viewport().get_texture().get_image().save_png(out + "/sky_" + s[0] + ".png")
	if f >= 10 + 40 * shots.size():
		get_tree().quit()
