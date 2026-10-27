extends Node
## 8-second clip of a shark attack seen from the side (for --write-movie).

var game
var f := 0
var started := -1

func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_survival")
		game.hud.toast_label.visible = false
		game.shark.timer = 0.1
		game.cam_dist = 8.5
		game.cam_pitch = 0.3
	if game.shark.target != null:
		var side: Vector2 = game.shark.side
		var perp := Vector2(-side.y, side.x)
		game.cam_yaw = lerp_angle(game.cam_yaw, atan2(perp.x + side.x * 0.6, perp.y + side.y * 0.6), 0.08)
	if f >= 300:
		get_tree().quit()
