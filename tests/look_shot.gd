extends Node
## Close-up look-dev shots: a varied raft with a hut, devices and a farm, at a few angles.

var game
var f := 0
var out := ""
var shots := [[0.7, 0.42, 9.0, "look_a"], [2.4, 0.3, 6.0, "look_b"], [4.2, 0.62, 14.0, "look_c"], [5.6, 0.12, 8.0, "look_d"]]

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _paint(kind: String, cells: Array) -> void:
	game._set_build(kind)
	for c in cells:
		game._tap_ghost(c)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.shark_on = false
		game.weather.t = 999.0
		game.game_t = 45.0
		for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, -1)]:
			_paint("floor", [c])
		_paint("still", [Vector2i(2, 0)])
		_paint("grill", [Vector2i(2, 1)])
		_paint("sail", [Vector2i(0, -1)])
		_paint("chest", [Vector2i(1, 2)])
		_paint("catcher", [Vector2i(0, 2)])
		_paint("field", [Vector2i(-1, 0), Vector2i(-1, 1)])
		_paint("kelpfarm", [Vector2i(3, 0)])
		game._set_build("")
		for o in game._objs_of("field"):
			o.moist = 0.5
			for k in 4:
				o.spots[k].crop = "tomato"
				o.spots[k].grow = 0.8
		game._objs_of("sail")[0].up = true
		var sh = game.shelter
		for k in [sh.edge_key(Vector2i(0, 0), Vector2i(0, -1), 0), sh.edge_key(Vector2i(1, 0), Vector2i(1, -1), 0)]:
			sh.place("wall", k)
		sh.place("window", sh.edge_key(Vector2i(1, 0), Vector2i(2, 0), 0))
		sh.place("door", sh.edge_key(Vector2i(0, 0), Vector2i(-1, 0), 0))
		for c in [Vector2i(0, 0), Vector2i(1, 0)]:
			sh.place("roof", "%d|%d|0" % [c.x, c.y])
		game.P["x"] = 1.5 * game.TILE; game.P["z"] = 1.2 * game.TILE
	var i := (f - 40) / 50
	if f >= 40 and i < shots.size():
		var s: Array = shots[i]
		game.cam_yaw = s[0]; game.cam_pitch = s[1]; game.cam_dist = s[2]
		if (f - 40) % 50 == 49:
			game.hud.toast_label.visible = false
			get_viewport().get_texture().get_image().save_png(out + "/" + s[3] + ".png")
	if f >= 40 + 50 * shots.size():
		get_tree().quit()
