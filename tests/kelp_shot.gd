extends Node
## Close-ups of a kelp line floating beside a small raft: from the deck, and from under the water.

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
		game.game_t = 70.0
		game.weather.t = 999.0
		game._set_build("kelpfarm")
		for c in [Vector2i(2, 0), Vector2i(2, 1)]:
			game._tap_ghost(c)
		game._set_build("")
		var ks = game._objs_of("kelpfarm")
		ks[0].planted = true; ks[0].kelp = 3
		ks[1].planted = true; ks[1].kelp = 1; ks[1].prog = 30.0
		game.P["x"] = 1.0 * game.TILE; game.P["z"] = 0.5 * game.TILE
		game.cam_pitch = 0.5; game.cam_dist = 7.0; game.cam_yaw = -0.9
	if f == 70:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/kelp_deck.png")
		game._toggle_swim()
		var w: Vector3 = game.raft.to_global(Vector3(2.0 * game.TILE, 0, 0.5 * game.TILE))
		game.swim.pos = Vector3(w.x + 4.5, game.ocean.height(w.x, w.z) - 2.4, w.z)
		game.swim.under = true
		game.cam_pitch = 0.1; game.cam_dist = 4.0; game.cam_yaw = PI / 2.0 + 0.25
	if f == 140:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/kelp_under.png")
		get_tree().quit()
