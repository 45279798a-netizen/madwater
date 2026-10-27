extends Node
## Close-up portraits of the companion models (posed above the raft deck).

var game
var f := 0
var out := ""
var shots := [["dolphin", 0.9, 0.25, 3.4], ["dolphin", 2.6, 0.55, 3.4], ["gull", 0.6, 0.35, 1.6], ["gull", 3.0, 0.9, 1.8], ["turtle:real", 0.35, 0.4, 1.8], ["turtle:real", 2.4, 0.6, 2.0]]
var subj: Node3D

func _ready() -> void:
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _pose(kind: String) -> void:
	if subj != null:
		subj.queue_free()
	if kind.begins_with("turtle:"):
		Models.turtle_style = kind.substr(7)
	subj = Models.seagull() if kind == "gull" else (Models.dolphin() if kind == "dolphin" else Models.turtle())
	game.raft.add_child(subj)
	subj.position = Vector3(1.0, 1.4, 1.0)
	if subj.has_meta("anim"):
		var ap: AnimationPlayer = subj.get_meta("anim")
		ap.play(ap.get_animation_list()[0])
	game.player.visible = false

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.weather.t = 999.0
		for k in game.companions.pets:
			game.companions.pets[k].node.visible = false
		game.game_t = 70.0
	var i := (f - 10) / 30
	if f >= 10 and i < shots.size():
		var s: Array = shots[i]
		if (f - 10) % 30 == 0:
			_pose(s[0])
		game.P["x"] = 1.0; game.P["z"] = 1.0
		game.cam_yaw = s[1]; game.cam_pitch = s[2]; game.cam_dist = s[3]
		for k in game.companions.pets:
			game.companions.pets[k].node.visible = false
		if (f - 10) % 30 == 29:
			game.hud.toast_label.visible = false
			get_viewport().get_texture().get_image().save_png(out + "/pet_%d_%s.png" % [i, s[0].replace(":", "_")])
	if f >= 10 + 30 * shots.size():
		get_tree().quit()
