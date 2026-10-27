extends Node
## ~15 s clip: jump off the raft, dive to the seabed, dig clay, fend off the shark, swim up.

var game
var f := 0
var clay
var dug_f := -1
var keys := {}

func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)

func key(code: int, on: bool) -> void:
	if keys.get(code, false) == on:
		return
	keys[code] = on
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = on
	Input.parse_input_event(ev)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.shark_on = true
		game.shark.timer = 999.0
		game.hud.toast_label.visible = false
		var isl = game.islands[0]
		var best = null
		for n in game.seabed_nodes:
			if n.kind == "clay" and n.pos.y < -6.0 and n.pos.y > -11.0:
				if best == null or Vector2(n.pos.x - isl.x, n.pos.z - isl.z).length() < Vector2(best.pos.x - isl.x, best.pos.z - isl.z).length():
					best = n
		clay = best
		var away := Vector2(clay.pos.x - isl.x, clay.pos.z - isl.z).normalized()
		var rp := Vector2(clay.pos.x, clay.pos.z) + away * 10.0
		game.raft_pos = rp - Vector2(1, 1)
		game.cam_dist = 9.0
		game.cam_pitch = 0.3
		game.cam_yaw = atan2(away.x, away.y) + 0.5
	if f == 35:
		game._toggle_swim()
		game.shark.hunt_t = 999.0
	if f > 45 and game.swim != null and dug_f < 0:
		var to := Vector2(clay.pos.x - game.swim.pos.x, clay.pos.z - game.swim.pos.z)
		game.cam_yaw = lerp_angle(game.cam_yaw, atan2(-to.x, -to.y), 0.08)
		game.cam_pitch = lerpf(game.cam_pitch, 0.18, 0.05)
		key(KEY_W, to.length() > 1.4)
		key(KEY_SHIFT, game.swim.pos.y > clay.pos.y + 1.5)
		if to.length() < 1.6 and game.swim.pos.y < clay.pos.y + 2.2:
			game._tap_seabed(clay, game.swim.pos)
			dug_f = f
			key(KEY_W, false)
			key(KEY_SHIFT, false)
	if dug_f > 0 and f == dug_f + 25:
		game.shark.state = "hunt"
		var back := Vector2(sin(game.cam_yaw), cos(game.cam_yaw))
		game.shark.x = game.swim.pos.x - back.y * 12.0
		game.shark.z = game.swim.pos.z + back.x * 12.0
		game.shark.dep = game.ocean.height(game.shark.x, game.shark.z) - game.swim.pos.y
	if dug_f > 0 and f > dug_f + 25 and game.shark.state == "hunt":
		var sw := Vector2(game.shark.x - game.swim.pos.x, game.shark.z - game.swim.pos.z)
		game.cam_yaw = lerp_angle(game.cam_yaw, atan2(sw.x, sw.y) + PI + 0.6, 0.05)
		if sw.length() < 5.0 and f % 12 == 0:
			game._tap_shark(game.swim.pos)
	if dug_f > 0 and game.shark.state == "flee" and f > dug_f + 40:
		key(KEY_SPACE, true)
	if f >= 470:
		key(KEY_SPACE, false)
		get_tree().quit()
