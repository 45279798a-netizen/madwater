extends Node
## Close-ups of the home / food / way-home pieces (SHOT_DIR/home_<kind>.png), the lighthouse, and the raft at night.

var game
var f := 0
var out := ""
var kinds := ["bed", "table", "lantern", "flag", "flowerpot", "pot", "bigchest", "radio"]
var cells := {}

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _shot(n: String) -> void:
	game.hud.visible = false
	get_viewport().get_texture().get_image().save_png(out + "/" + n)

func _process(_d: float) -> void:
	f += 1
	var n := kinds.size()
	if f == 2:
		game._on_action("start_creative")
		game.shark_on = false
		game.weather.t = 999.0
		game.game_t = 40.0
		for x in range(1, 2 * n + 2):
			game._set_build("floor"); game._tap_ghost(Vector2i(x, 0))
		for x in range(0, 5):
			game._set_build("floor"); game._tap_ghost(Vector2i(x, 1))
		for i in n:
			var c := Vector2i(2 + i * 2, 0)
			game._set_build(kinds[i]); game._tap_ghost(c)
			cells[kinds[i]] = c
		game._set_build("reinforce")
		for x in range(0, 5):
			game._tap_ghost(Vector2i(x, 1))
		game._set_build("")
		var po = game._objs_of("pot")[0]
		po.slots = [[10.0, "fishsoup"]]
		po.done = {"fishsoup": 1}
		game.player.visible = false
		for d in game.debris:
			d.node.visible = false
	var i := (f - 40) / 30
	if f >= 40 and i < n:
		var c: Vector2i = cells[kinds[i]]
		game.P["x"] = c.x * game.TILE; game.P["z"] = c.y * game.TILE
		game.cam_yaw = 0.6; game.cam_pitch = 0.36; game.cam_dist = 4.4 if kinds[i] != "flag" and kinds[i] != "radio" else 6.5
		game.cam_target = game.raft.to_global(Vector3(game.P["x"], 0.1, game.P["z"])) + Vector3(0, 0.8, 0)
		if (f - 40) % 30 == 29:
			_shot("home_" + kinds[i] + ".png")
	var t0 := 40 + 30 * n
	if f == t0:
		# reinforced tiles from the side
		game.P["x"] = 2.0 * game.TILE; game.P["z"] = 1.0 * game.TILE
		game.cam_yaw = 0.2; game.cam_pitch = 0.2; game.cam_dist = 7.0
	if f == t0 + 30:
		_shot("home_reinforce.png")
		# night on the raft: lanterns and the torch
		game.player.visible = true
		game.inv["torch"] = 1
		game.game_t = 138.4
		game.P["x"] = 4.0 * game.TILE; game.P["z"] = 0.5 * game.TILE
		game.cam_yaw = 0.5; game.cam_pitch = 0.5; game.cam_dist = 9.0
	if f == t0 + 70:
		_shot("home_night.png")
		# sail up to the lighthouse
		var lh: Dictionary = game._lighthouse()
		var dir := Vector2(lh.x, lh.z).normalized()
		game.raft_pos = Vector2(lh.x, lh.z) - dir * 36.0
		game.game_t = 60.0
		game.P["x"] = 1.0 * game.TILE; game.P["z"] = 0.0
		game.cam_yaw = atan2(-dir.x, -dir.y) + PI
		game.cam_pitch = 0.18; game.cam_dist = 10.0
	if f == t0 + 130:
		_shot("home_lighthouse.png")
		game.game_t = 150.0
	if f == t0 + 170:
		_shot("home_lighthouse_night.png")
		get_tree().quit()
