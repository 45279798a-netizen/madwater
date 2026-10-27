extends Node
## Captures the shark attack from the side to check it stays outside the raft and bites with its mouth.

var game
var f := 0
var shots := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_survival")
		game.hud.toast_label.visible = false
		game.shark.timer = 0.5
		game.cam_dist = 6.0
		game.cam_pitch = 0.3
	if game.shark.state in ["approach", "bite"] and game.shark.target != null:
		var side: Vector2 = game.shark.side
		# look along the raft edge so the snout and the logs are both in view
		var perp := Vector2(-side.y, side.x)
		game.cam_yaw = atan2(perp.x + side.x * 0.5, perp.y + side.y * 0.5)
	if game.shark.state == "bite" and shots < 3 and f % 20 == 0:
		get_viewport().get_texture().get_image().save_png(out + "/bite%d.png" % shots)
		shots += 1
	if shots >= 3 or f > 1500:
		print("state ", game.shark.state, " shots ", shots)
		get_tree().quit()
