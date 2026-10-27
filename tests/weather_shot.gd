extends Node
## Screenshots of a rain shower and a storm (big waves, dark sky, lightning).

var game
var f := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	var w = game.weather
	if f == 2:
		game._on_action("start_creative")
		game.game_t = 60.0
		for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0), Vector2i(-1, 1)]:
			game._set_build("floor"); game._tap_ghost(c)
		game._set_build("catcher"); game._tap_ghost(Vector2i(2, 0))
		game._set_build("field"); game._tap_ghost(Vector2i(-1, 0)); game._tap_ghost(Vector2i(-1, 1))
		game._set_build("")
		for o in game._objs_of("field"):
			for sp in o.spots:
				sp.crop = "tomato"; sp.grow = 0.7
		game.tiles[Vector2i(2, 0)].obj.water = 2
		w.kind = "rain"; w.t = 999.0; w.cloud = 0.6; w.rain = 0.75
		game.cam_yaw = 0.4; game.cam_pitch = 0.3; game.cam_dist = 11.0
	if f == 80:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/weather_rain.png")
		w.kind = "storm"; w.cloud = 1.0; w.rain = 1.0; w.storm = 1.0; w._bolt_t = 999.0
	if f == 150:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/weather_storm.png")
		w._flash = 1.0
	if f == 152:
		get_viewport().get_texture().get_image().save_png(out + "/weather_flash.png")
		get_tree().quit()
