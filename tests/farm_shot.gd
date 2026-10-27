extends Node
## Screenshots of a big farming raft: a 3×2 field, a 2×2 chicken yard, a 2-tile goat pen, a kelp line.

var game
var f := 0
var out := ""

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
		game.game_t = 70.0
		var floor := []
		for x in range(-2, 3):
			for z in range(-1, 3):
				if not game.tiles.has(Vector2i(x, z)):
					floor.append(Vector2i(x, z))
		# lay floor outward so every new tile touches the raft
		for pass_i in 4:
			for c in floor.duplicate():
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if game.tiles.has(c + d) and not game.tiles.has(c):
						_paint("floor", [c])
						floor.erase(c)
						break
		_paint("field", [Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0)])
		_paint("coop", [Vector2i(1, -1), Vector2i(2, -1), Vector2i(1, 0), Vector2i(2, 0)])
		_paint("pen", [Vector2i(-2, 2), Vector2i(-1, 2)])
		_paint("kelpfarm", [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
		_paint("still", [Vector2i(2, 1)])
		game._set_build("")
		var crops := ["potato", "potato", "tomato", "tomato", "melon", "melon"]
		var fields = game._objs_of("field")
		for i in fields.size():
			fields[i].moist = 0.8
			for k in 4:
				fields[i].spots[k].crop = crops[i]
				fields[i].spots[k].grow = [1.0, 0.6, 1.0, 0.45, 0.9, 1.0][i]
		var cp = game.tiles[Vector2i(1, -1)].obj
		var grp = game.farm.group_of(cp)
		for o in grp.objs:
			o.hens = 2
			o.eggs = 1
		grp.leader.food = 10
		var pn = game.tiles[Vector2i(-2, 2)].obj
		for o in game.farm.group_of(pn).objs:
			o.goats = 1
		game.farm.group_of(pn).leader.food = 3
		game.farm.group_of(pn).leader.water = 3
		for o in game._objs_of("kelpfarm"):
			o.planted = true; o.kelp = 2
		game.P["x"] = 0.0; game.P["z"] = 1.0
		game.cam_pitch = 0.85; game.cam_dist = 14.0; game.cam_yaw = 0.25
	if f == 160:
		game.hud.toast_label.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/farm_raft.png")
		game._on_action("build")
	if f == 175:
		get_viewport().get_texture().get_image().save_png(out + "/farm_build.png")
		get_tree().quit()
