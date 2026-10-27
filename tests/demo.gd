extends Node
## Scripted 30-second showcase for a video: sailing, an island, fishing, the shark. Run with --write-movie.

var game
var f := 0

func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.shark_on = true
		game.hud.toast_label.modulate.a = 0.0
		for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 2), Vector2i(1, 2)]:
			game._add_tile(c)
		game._place("sail", game.tiles[Vector2i(0, 0)])
		game._place("helm", game.tiles[Vector2i(0, 2)])
		game._place("still", game.tiles[Vector2i(2, 0)])
		game._place("grill", game.tiles[Vector2i(2, 1)])
		var st = game._objs_of("still")[0]
		st.fuel = 120.0
		var gr = game._objs_of("grill")[0]
		gr.slots = [[6.0, "rawfish"], [12.0, "rawfish"]]
		game._objs_of("sail")[0].up = true
		game.steer = game._objs_of("helm")[0]
		var isl = game.islands[0]
		game.raft_pos = Vector2(isl.x - 70.0, isl.z - 6.0)
		game.heading = atan2(6.0, 70.0)
		game.raft_vel = Vector2(cos(game.heading), sin(game.heading)) * 2.2
		game.game_t = 20.0
		game.cam_dist = 13.0
		game.cam_pitch = 0.38
		game.shark.timer = 999.0
	var t := f / 30.0
	if t < 9.0:
		game.cam_yaw = 2.2 + t * 0.12
	elif t < 10.0:
		game.cam_yaw = lerpf(game.cam_yaw, 1.4, 0.05)
	if f == 300:
		game._objs_of("sail")[0].up = false
		game._exit_steer()
		game.P["x"] = 1.0; game.P["z"] = 1.0
		game.cam_dist = 9.5
		game.cam_pitch = 0.3
	if f == 330:
		var c = game._raft_center()
		var o: Vector3 = game.player.global_position + Vector3(0, 6, 0)
		var target: Vector3 = Vector3(c.x - 6.0, -0.25, c.z + 2.0)
		game._try_cast(o, (target - o).normalized(), game.player.global_position)
		if game.fishing != null:
			game.fishing.wait = 2.5
	if f > 330 and f < 560:
		var c2 = game._raft_center()
		game.cam_yaw = lerp_angle(game.cam_yaw, atan2(-(-6.0), -(2.0)) + 0.6, 0.03)
		if game.fishing != null and game.fishing.phase == "bite" and game.fishing.bite < 1.4:
			game._reel()
	if f == 560:
		game.shark.timer = 0.01
		game.cam_dist = 11.0
		game.cam_pitch = 0.25
	if f > 560:
		game.cam_yaw = lerp_angle(game.cam_yaw, atan2(game.cam.global_position.x - game.shark.x, game.cam.global_position.z - game.shark.z) * 0.0 + 0.9, 0.02)
		if game.shark.state == "bite" and f % 25 == 0:
			var t2 = game.shark.target
			game.P["x"] = t2.cell.x * 2.0; game.P["z"] = t2.cell.y * 2.0
			game._tap_shark(game.player.global_position)
	if f >= 900:
		get_tree().quit()
