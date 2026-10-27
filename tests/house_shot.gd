extends Node
## Screenshots of a two-storey raft house: outside, and inside (upper storey hidden).

var game
var f := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _e(a: Vector2i, b: Vector2i, lv: int) -> String:
	return Shelter.edge_key(a, b, lv)

func _put(mode: String, keys: Array) -> void:
	game._set_build(mode)
	for k in keys:
		game._place_shelter(k)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.game_t = 75.0
		for pass_i in 3:
			for x in range(-1, 3):
				for z in range(-1, 3):
					var c := Vector2i(x, z)
					if not game.tiles.has(c):
						for d in Shelter.DIRS:
							if game.tiles.has(c + d):
								game._set_build("floor"); game._tap_ghost(c)
								break
		var V := func(x, y): return Vector2i(x, y)
		_put("wall", [_e(V.call(0, -1), V.call(0, 0), 0), _e(V.call(1, -1), V.call(1, 0), 0), _e(V.call(-1, 1), V.call(0, 1), 0), _e(V.call(1, 1), V.call(2, 1), 0)])
		_put("window", [_e(V.call(-1, 0), V.call(0, 0), 0), _e(V.call(1, 0), V.call(2, 0), 0)])
		_put("door", [_e(V.call(1, 1), V.call(1, 2), 0)])
		_put("upper", ["0|0", "1|0", "0|1", "1|1"])
		game._set_build("stairs"); game._tap_ghost(V.call(0, 2))
		game.P["level"] = 1
		_put("pillar", ["-1|-1|1", "1|-1|1", "-1|1|1", "1|1|1"])
		_put("rail", [_e(V.call(0, -1), V.call(0, 0), 1), _e(V.call(1, -1), V.call(1, 0), 1), _e(V.call(-1, 0), V.call(0, 0), 1), _e(V.call(-1, 1), V.call(0, 1), 1),
			_e(V.call(1, 0), V.call(2, 0), 1), _e(V.call(1, 1), V.call(2, 1), 1), _e(V.call(1, 1), V.call(1, 2), 1)])
		_put("roof", ["0|0|1", "1|0|1", "0|1|1", "1|1|1"])
		game._set_build("")
		var still = null
		game._set_build("grill"); game._tap_ghost(V.call(2, 2))
		game._set_build("sail"); game._tap_ghost(V.call(-1, 2))
		game._set_build("")
		game.P["level"] = 0; game.P["x"] = 4.0; game.P["z"] = 4.2
		game.cam_yaw = 0.55; game.cam_pitch = 0.42; game.cam_dist = 15.0
	if f == 70:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/house_out.png")
		game.cam_yaw = -2.4; game.cam_pitch = 0.3
	if f == 110:
		get_viewport().get_texture().get_image().save_png(out + "/house_back.png")
		game.P["x"] = 1.0; game.P["z"] = 1.0
		game.cam_yaw = 0.6; game.cam_pitch = 0.75; game.cam_dist = 9.0
	if f == 150:
		get_viewport().get_texture().get_image().save_png(out + "/house_in.png")
		get_tree().quit()
