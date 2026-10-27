extends Node
## Close-ups of every device on its own tile (SHOT_DIR/gal_<kind>.png), plus floating debris.

var game
var f := 0
var out := ""
var kinds := ["still", "grill", "sail", "helm", "chest", "filter", "catcher", "gullnest", "dolphinpost", "turtletank"]
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
		for i in kinds.size():
			var c := Vector2i(2 + i * 2, 0)
			for x in range(1, c.x + 1):
				if not game.tiles.has(Vector2i(x, 0)):
					game._set_build("floor"); game._tap_ghost(Vector2i(x, 0))
			game._set_build(kinds[i]); game._tap_ghost(c)
			cells[kinds[i]] = c
		game._set_build("")
		for o in game.objs:
			if o.kind == "still":
				o.fuel = 30.0
			if o.kind == "grill":
				o.slots = [[10.0, "rawfish"], [12.0, "rawfish"]]
			if o.kind == "sail":
				o.up = true
		game.player.visible = false
		for d in game.debris:
			d.node.visible = false
	var i := (f - 30) / 30
	if f >= 30 and i < kinds.size():
		var c: Vector2i = cells[kinds[i]]
		game.P["x"] = c.x * game.TILE; game.P["z"] = c.y * game.TILE
		game.cam_yaw = 0.6; game.cam_pitch = 0.32; game.cam_dist = 4.2 if kinds[i] != "sail" else 7.5
		game.cam_target = game.raft.to_global(Vector3(game.P["x"], 0.1, game.P["z"])) + Vector3(0, 1.1, 0)
		if (f - 30) % 30 == 29:
			game.hud.visible = false
			get_viewport().get_texture().get_image().save_png(out + "/gal_" + kinds[i] + ".png")
	if f >= 30 + 30 * kinds.size():
		get_tree().quit()
