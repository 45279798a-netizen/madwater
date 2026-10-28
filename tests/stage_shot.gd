extends Node
## The craft / build lists grouped by stage (SHOT_DIR/stage_*.png), phone layout with FORCE_TOUCH=1.

var game
var f := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n)

func _process(_d: float) -> void:
	f += 1
	match f:
		5:
			game._on_action("start_standard")
			game.shark.timer = 999.0
			game.S["drank"] = 1
			game.inv["wood"] = 12; game.inv["plastic"] = 8; game.inv["palm"] = 10; game.inv["rope"] = 4
		30:
			game._on_action("craft")
		60:
			_shot("stage_craft_top.png")
			game.hud.sheet_scroll.scroll_vertical = 900
		90:
			_shot("stage_craft_locked.png")
			game._on_action("build")
		120:
			_shot("stage_build_top.png")
			game.hud.sheet_scroll.scroll_vertical = 2400
		150:
			_shot("stage_build_locked.png")
			game._close_sheet()
		170:
			_shot("stage_hud.png")
			get_tree().quit()
