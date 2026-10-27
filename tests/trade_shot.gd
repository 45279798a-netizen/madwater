extends Node
## Screenshots of the trade boats beside the raft and the trade sheet.

var game
var f := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _dock(kind: String) -> void:
	game.traders._remove_boat()
	var c = game._raft_center()
	game.traders._spawn(kind, c)
	var tb = game.traders.boat
	tb.dir = Vector2(0.0, -1.0)
	tb.x = c.x; tb.z = c.z - (c.r + 7.0)
	tb.state = "stay"; tb.t = 185.0
	game.P["x"] = 1.0; game.P["z"] = -0.6
	game.cam_yaw = 0.75; game.cam_pitch = 0.22; game.cam_dist = 6.5

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_standard")
		game.shark.timer = 999.0
		game.game_t = 60.0
		game.inv["rawfish"] = 6; game.inv["rope"] = 4; game.inv["shell"] = 14
		_dock("fisher")
	if f == 60:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/trade_fisher.png")
		var tb = game.traders.boat
		game.traders.tap(Vector3(tb.x, 0, tb.z))
	if f == 75:
		get_viewport().get_texture().get_image().save_png(out + "/trade_sheet.png")
		game._close_sheet()
		_dock("ark")
	if f == 130:
		get_viewport().get_texture().get_image().save_png(out + "/trade_ark.png")
		_dock("water")
	if f == 185:
		get_viewport().get_texture().get_image().save_png(out + "/trade_water.png")
		get_tree().quit()
