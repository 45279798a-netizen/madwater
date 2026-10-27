extends Node
## Screenshots of the sea companions: gull and dolphin around the raft, turtle with a diver.

var game
var f := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	var cp = game.companions
	if f == 2:
		game._on_action("start_creative")
		game.game_t = 70.0
		game.weather.t = 999.0
		for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0), Vector2i(-1, 1)]:
			game._set_build("floor"); game._tap_ghost(c)
		game._set_build("dolphinpost"); game._tap_ghost(Vector2i(2, 0))
		game._set_build("gullnest"); game._tap_ghost(Vector2i(-1, 0))
		game._set_build("sail"); game._tap_ghost(Vector2i(0, 0))
		game._set_build("")
		game._objs_of("sail")[0].up = true
		for k in ["gull", "dolphin", "turtle"]:
			cp._tame(k)
			cp.pets[k].follow = true
			cp.pets[k].aff = 70.0
		cp.pets.turtle.net.visible = false
		cp.pets.gull.decay_fetch = 999.0
		game.cam_yaw = 2.2; game.cam_pitch = 0.32; game.cam_dist = 13.0
	if f == 120:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/pets_raft.png")
		# wild animals at home: put the camera on the seagull over the first island
		var t = game.tiles.values()[0]
		game.P["x"] = t.cell.x * 2.0; game.P["z"] = t.cell.y * 2.0
		game._toggle_swim()
		game.swim.pos = Vector3(game.swim.pos.x, game.ocean.height(game.swim.pos.x, game.swim.pos.z) - 2.5, game.swim.pos.z)
		game.cam_yaw = 0.9; game.cam_pitch = 0.15; game.cam_dist = 4.5
	if f == 200:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/pets_turtle.png")
		get_tree().quit()
