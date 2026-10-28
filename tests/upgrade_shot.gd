extends Node
## Close-ups of the metal-tier devices (SHOT_DIR/up_<kind>.png) and one wide shot of them all.

var game
var f := 0
var out := ""
var kinds := ["smelter", "bgrill", "purifier", "sprinkler", "anchor", "engine", "colnet", "fishtrap"]
var cells := {}

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
		game.game_t = 40.0
		for x in range(1, 13):
			game._set_build("floor"); game._tap_ghost(Vector2i(x, 0))
		var deck := 0
		for k in kinds:
			var c: Vector2i
			if k in game.SEA_KINDS:
				c = Vector2i(3 if k == "colnet" else 7, 1)
				game._set_build(k); game._tap_ghost(c)
			else:
				c = Vector2i(2 + deck * 2, 0)
				deck += 1
				game._set_build(k); game._tap_ghost(c)
			cells[k] = c
		game._set_build("")
		for o in game.objs:
			match o.kind:
				"smelter":
					o.slots = [[10.0, "ore"]]
					o.done = {"ingot": 2}
				"bgrill":
					o.slots = [[5.0, "rawfish"], [6.0, "rawfish"], [7.0, "rawfish"]]
					o.done = {"cooked": 1}
				"purifier":
					o.fuel = 60.0
					o.water = 3
				"sprinkler":
					o.water = 6
					o.prog = 99.0
				"anchor":
					o.down = true
				"engine":
					o.on = true
					o.fuel = 200.0
				"colnet":
					o.count = 9
				"fishtrap":
					o.fish = 2
		game.player.visible = false
		for d in game.debris:
			d.node.visible = false
	var i := (f - 40) / 30
	if f >= 40 and i < kinds.size():
		var c: Vector2i = cells[kinds[i]]
		game.P["x"] = c.x * game.TILE; game.P["z"] = c.y * game.TILE
		game.cam_yaw = 0.6; game.cam_pitch = 0.42 if kinds[i] in game.SEA_KINDS else 0.32; game.cam_dist = 5.0
		game.cam_target = game.raft.to_global(Vector3(game.P["x"], 0.1, game.P["z"])) + Vector3(0, 0.9, 0)
		if (f - 40) % 30 == 29:
			game.hud.visible = false
			get_viewport().get_texture().get_image().save_png(out + "/up_" + kinds[i] + ".png")
	if f == 40 + 30 * kinds.size():
		game.hud.visible = true
		game.P["x"] = 7.0 * game.TILE; game.P["z"] = 0.0
		game.cam_yaw = 0.25; game.cam_pitch = 0.62; game.cam_dist = 16.0
	if f == 40 + 30 * kinds.size() + 40:
		get_viewport().get_texture().get_image().save_png(out + "/up_all.png")
		get_tree().quit()
