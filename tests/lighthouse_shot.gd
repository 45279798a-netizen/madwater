extends Node
## The lighthouse island by day and by night (SHOT_DIR/lh_day.png, lh_night.png).

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
		var lh: Dictionary = game._lighthouse()
		var dir := Vector2(lh.x, lh.z).normalized()
		game.raft_pos = Vector2(lh.x, lh.z) - dir * 30.0
		game.game_t = 60.0
		game.P["x"] = 0.5 * game.TILE; game.P["z"] = 0.5 * game.TILE
		game.cam_yaw = atan2(-dir.x, -dir.y)
		game.cam_pitch = 0.12; game.cam_dist = 9.0
		game.set_meta("dir", dir)
	if f == 60:
		game.hud.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/lh_day.png")
		game.game_t = 150.0
	if f == 100:
		get_viewport().get_texture().get_image().save_png(out + "/lh_night.png")
		get_tree().quit()
