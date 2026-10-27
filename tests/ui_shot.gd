extends Node
## Screenshots of the skills panel and a lost backpack after a blackout.

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
		game._on_action("start_standard")
		game.shark.timer = 999.0
		game.skills.hook = {"lv": 3, "xp": 10}
		game.skills.fish = {"lv": 1, "xp": 4}
		game.skills.build = {"lv": 2, "xp": 7}
		game.inv["wood"] = 26; game.inv["plastic"] = 9; game.inv["palm"] = 4; game.inv["rope"] = 3
		game._refresh_inv()
		game._on_action("skills")
	if f == 30:
		get_viewport().get_texture().get_image().save_png(out + "/ui_skills.png")
		game._close_sheet()
		game.S["health"] = 0.0; game.S["thirst"] = 0.0
		game.cam_pitch = 0.5; game.cam_dist = 13.0
	if f == 90:
		for d in game.debris:
			if d.type == "bag":
				var c = game._raft_center()
				game.cam_yaw = atan2(c.x - d.x, c.z - d.z)
		game.hud.toast_label.visible = false
	if f == 110:
		get_viewport().get_texture().get_image().save_png(out + "/ui_bag.png")
		get_tree().quit()
