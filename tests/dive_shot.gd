extends Node
## Underwater screenshots: near the seabed by the first island, the wreck, and a shark closing in.

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
		game.hud.toast_label.visible = false
		var isl = game.islands[0]
		game.raft_pos = Vector2(isl.x - 40.0, isl.z - 6.0)
	if f == 6:
		game._toggle_swim()
		var isl = game.islands[0]
		var p := Vector2(isl.x - 22.0, isl.z - 4.0)
		game.swim.pos = Vector3(p.x, game.seabed_h(p.x, p.y) + 1.6, p.y)
		game.cam_yaw = -PI / 2 - 0.3
		game.cam_pitch = 0.22
		game.cam_dist = 9.0
	if f > 6 and f < 60:
		game.swim.pos.y = game.seabed_h(game.swim.pos.x, game.swim.pos.z) + 1.6
	if f == 60:
		get_viewport().get_texture().get_image().save_png(out + "/dv_seabed.png")
		var w = game.wreck_node
		game.swim.pos = w.pos + Vector3(-4.0, 1.5, 3.0)
		game.cam_yaw = atan2(-1.0, 1.0) + 0.4
	if f == 100:
		get_viewport().get_texture().get_image().save_png(out + "/dv_wreck.png")
		var isl = game.islands[0]
		var p := Vector2(isl.x - 24.0, isl.z + 3.0)
		game.swim.pos = Vector3(p.x, game.seabed_h(p.x, p.y) + 3.0, p.y)
		game.shark_on = true
		game.shark.state = "hunt"
		game.shark.x = p.x - 9.0; game.shark.z = p.y + 1.0
		game.shark.dep = game.ocean.height(game.shark.x, game.shark.z) - game.swim.pos.y
		game.cam_yaw = PI / 2 - 0.5
		game.cam_pitch = 0.15
	if f > 100 and f < 125:
		game.S["health"] = 100.0
	if f == 125:
		get_viewport().get_texture().get_image().save_png(out + "/dv_shark.png")
		get_tree().quit()
