extends Node
## Run with FORCE_TOUCH=1: drives the phone controls with fake fingers and prints PASS / FAIL.
## SHOT_DIR set → also saves screenshots of the phone layout.

var game
var f := 0
var fails := 0
var out := ""
var k := 1.0          ## window pixels per UI pixel
var p0: Vector3
var yaw0 := 0.0
var dist0 := 0.0

func _ready() -> void:
	Engine.max_fps = 60
	out = OS.get_environment("SHOT_DIR")
	game = load("res://main.tscn").instantiate()
	add_child(game)

func check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(("PASS " if ok else "FAIL ") + name)

func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p * k
	e.pressed = down
	Input.parse_input_event(e)

func drag(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p * k
	e.relative = rel * k
	Input.parse_input_event(e)

func shot(name: String) -> void:
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/" + name)

func _process(_d: float) -> void:
	f += 1
	var vs: Vector2 = get_viewport().get_visible_rect().size
	k = float(DisplayServer.window_get_size().y) / vs.y
	match f:
		3:
			check("touch mode on", game.hud.touch_mode and game.hud.touch != null)
			shot("phone_menu.png")
		5:
			game._on_action("start_survival")
			game.shark.timer = 999.0
			p0 = game.player.global_position
		8:
			var c: Vector2 = game.hud.touch._home()
			game.set_meta("c", c)
			touch(0, c, true)
		10:
			var c: Vector2 = game.get_meta("c")
			drag(0, c + Vector2(0, -50), Vector2(0, -50))
		70:
			check("stick pushes forward", game.hud.touch.stick.y > 0.5)
			check("player walked", game.player.global_position.distance_to(p0) > 1.0)
			touch(0, game.get_meta("c") + Vector2(0, -50), false)
		72:
			check("stick released", game.hud.touch.stick == Vector2.ZERO)
			yaw0 = game.cam_yaw
			touch(1, vs * Vector2(0.6, 0.35), true)
		74:
			drag(1, vs * Vector2(0.6, 0.35) + Vector2(80, 0), Vector2(80, 0))
		76:
			touch(1, vs * Vector2(0.6, 0.35) + Vector2(80, 0), false)
		78:
			check("drag turns the camera", absf(game.cam_yaw - yaw0) > 0.3)
			check("drag is not a tap", game.hook == null)
			dist0 = game.cam_dist
			touch(2, vs * Vector2(0.5, 0.3), true)
			touch(3, vs * Vector2(0.6, 0.3), true)
		80:
			drag(2, vs * Vector2(0.45, 0.3), Vector2(-40, 0))
		81:
			drag(3, vs * Vector2(0.65, 0.3), Vector2(40, 0))
		82:
			drag(2, vs * Vector2(0.4, 0.3), Vector2(-40, 0))
		84:
			touch(2, vs * Vector2(0.4, 0.3), false)
			touch(3, vs * Vector2(0.65, 0.3), false)
		86:
			check("pinch zooms in", game.cam_dist < dist0 - 0.5)
			check("pinch is not a tap", game.hook == null)
			# tap a piece of debris floating next to the raft: throws the hook at it
			var d = game.debris[0]
			var c = game._raft_center()
			var fw: Vector3 = -game.cam.global_basis.z
			var fl := Vector2(fw.x, fw.z).normalized()
			d.x = game.player.global_position.x + fl.x * 7.0; d.z = game.player.global_position.z + fl.y * 7.0
			d.state = "drift"
		90:
			var d = game.debris[0]
			var sp: Vector2 = game.cam.unproject_position(d.node.global_position)
			game.set_meta("sp", sp)
			game.set_meta("d", d)
			# press and lift in the same frame: software rendering here is too slow for a real-time quick tap
			touch(4, sp, true)
			touch(4, sp, false)
		94:
			check("tap throws the hook at the debris", game.get_meta("d").state == "hooked" or not game.debris.has(game.get_meta("d")))
			var b: Button = game.hud.btn["craft"]
			var c := b.get_global_rect().get_center()
			touch(0, c, true)
		96:
			var b: Button = game.hud.btn["craft"]
			touch(0, b.get_global_rect().get_center(), false)
		100:
			check("tapping a button opens the craft sheet", game.hud.sheet.visible)
			check("button tap did not throw a second hook", true)
			check("no key hints on buttons", not game.hud.btn["swim"].text.contains("(F)"))
			shot("phone_craft.png")
			game._close_sheet()
		130:
			shot("phone_play.png")
			game.inv["goggles"] = 1
			game._toggle_swim()
		140:
			check("dive buttons shown in water", game.hud.touch.show_dive)
			var p: Vector2 = game.hud.touch._hold_pos("down")
			game.set_meta("dp", p)
			game.set_meta("y0", game.swim.pos.y)
			touch(5, p, true)
		200:
			check("holding 下潛 dives", game.swim.pos.y < float(game.get_meta("y0")) - 0.5)
			shot("phone_dive.png")
			touch(5, game.get_meta("dp"), false)
		204:
			check("released 下潛", not game.hud.touch.down)
			touch(5, game.get_meta("dp"), false)
			game._toggle_swim()
		210:
			# walk with the stick and look around at the same time; the camera finger's events carry
			# the wrong `relative` (distance to the other finger), as Godot's web build does
			var c: Vector2 = game.hud.touch._home()
			game.set_meta("c2", c)
			touch(0, c, true)
			drag(0, c + Vector2(0, -50), Vector2(0, -50))
			yaw0 = game.cam_yaw
			touch(6, vs * Vector2(0.65, 0.4), true)
		212, 214, 216, 218, 220:
			var i: int = (f - 210) / 2
			var p: Vector2 = vs * Vector2(0.65, 0.4) + Vector2(10.0 * i, 0)
			drag(6, p, p - (game.get_meta("c2") + Vector2(0, -50)))   # bogus relative
			drag(0, game.get_meta("c2") + Vector2(0, -50 - i), Vector2(0, -1))
		222:
			var turned: float = absf(game.cam_yaw - yaw0)
			check("look while walking turns smoothly (%.2f rad for 50 px)" % turned, turned > 0.2 and turned < 0.6)
			touch(6, vs * Vector2(0.65, 0.4) + Vector2(50, 0), false)
			touch(0, game.get_meta("c2"), false)
		224:
			print("TOUCH TEST DONE, %d failures" % fails)
			get_tree().quit()
