extends Node
## The first island seen from a raft parked beside it, from two sides and from above.

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
		game.weather.t = 999.0
		game.game_t = 40.0
	var isl: Dictionary = game.islands[0]
	if f >= 2 and f < 200:
		var away: Vector2 = Vector2(isl.x, isl.z).normalized()
		var at: Vector2 = Vector2(isl.x, isl.z) - away * (isl.r * 1.3 + 6.0)
		game.raft_pos = at - Vector2(1.5, 1.5)
		game.raft_vel = Vector2.ZERO
	if f == 10:
		var to: Vector3 = Vector3(isl.x, 0, isl.z) - game.raft.global_position
		game.cam_yaw = atan2(-to.x, -to.z) + 0.25
		game.cam_pitch = 0.22; game.cam_dist = 9.0
	if f == 70:
		game.hud.visible = false
		get_viewport().get_texture().get_image().save_png(out + "/isl_a.png")
		game.cam_yaw += 0.9
		game.cam_pitch = 0.6; game.cam_dist = 20.0
	if f == 130:
		get_viewport().get_texture().get_image().save_png(out + "/isl_b.png")
		get_tree().quit()
