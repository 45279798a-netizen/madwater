extends Node
## Co-op test: a host and a friend, two full games in one process, talking over Net.LoopTransport.
## Run: godot --headless --path . res://tests/net_test.tscn   (SHOT_DIR=... with a display for a picture)

var host
var cli
var fails := 0
var vps: Array = []


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _game(x: int) -> Node:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.position = Vector2(x, 0)
	svc.size = Vector2(640, 400)
	add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(640, 400)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	vps.append(vp)
	var gm = load("res://main.tscn").instantiate()
	vp.add_child(gm)
	return gm


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait_for(cond: Callable, sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _ready() -> void:
	host = _game(0)
	cli = _game(640)
	await get_tree().process_frame
	host.net.tr = Net.LoopTransport.new()
	cli.net.tr = Net.LoopTransport.new()
	await _wait(0.3)

	print("lobby")
	host._on_action("mp")
	host._on_action("mp_host")
	host._on_action("start_standard")
	_ok(host.net.is_host() and host.net.code.length() == 4, "host opened room %s" % host.net.code)
	cli._on_action("mp")
	_ok(await _wait_for(func(): return cli.net.rooms.size() == 1, 3.0), "friend sees the room in the lobby")
	_ok(cli.hud.menu.visible, "room list menu shown")
	cli._on_action("mp_join_" + host.net.code)
	_ok(await _wait_for(func(): return cli.net.synced, 6.0), "friend received the world")
	_ok(not cli.paused and not cli.hud.menu.visible, "friend is playing")
	_ok(cli.tiles.size() == host.tiles.size(), "same raft (%d tiles)" % cli.tiles.size())
	_ok(cli.mode == host.mode, "same mode")
	await _wait(0.6)
	_ok(host.net.peers.size() == 1 and cli.net.peers.size() == 1, "each sees one other player")
	_ok(await _wait_for(func(): return host.net.peers.values()[0].av != null and cli.net.peers.values()[0].av != null, 2.0), "avatars spawned")

	print("building")
	host._add_tile(Vector2i(2, 0))
	_ok(await _wait_for(func(): return cli.tiles.has(Vector2i(2, 0)), 2.0), "host's new tile shows up for the friend")
	cli._add_tile(Vector2i(-1, 0))
	cli.net.flush()
	_ok(await _wait_for(func(): return host.tiles.has(Vector2i(-1, 0)), 2.0), "friend's new tile shows up for the host")
	cli._place("still", cli.tiles[Vector2i(-1, 0)])
	cli.net.flush()
	_ok(await _wait_for(func(): return host.tiles[Vector2i(-1, 0)].obj != null and host.tiles[Vector2i(-1, 0)].obj.kind == "still", 2.0), "friend's still appears on the host")
	host.tiles[Vector2i(-1, 0)].obj.water = 2
	_ok(await _wait_for(func(): return int(cli.tiles[Vector2i(-1, 0)].obj.water) == 2, 2.0), "host's still state reaches the friend")
	cli.tiles[Vector2i(-1, 0)].obj.water = 0
	cli.net.flush()
	_ok(await _wait_for(func(): return int(host.tiles[Vector2i(-1, 0)].obj.water) == 0, 2.0), "friend took the water (host sees it)")
	_ok(cli.inv.get("wood", 0) == 2, "friend has their own backpack")

	host._place("kelpfarm", host._add_sea(Vector2i(3, 0)))
	_ok(await _wait_for(func(): return cli.sea.has(Vector2i(3, 0)) and cli.sea[Vector2i(3, 0)].obj != null, 2.0), "host's kelp farm floats beside the friend's raft too")
	cli.sea[Vector2i(3, 0)].obj.planted = true
	cli.net.flush()
	_ok(await _wait_for(func(): return host.sea[Vector2i(3, 0)].obj.planted, 2.0), "friend planted the kelp (host sees it)")
	host._place("colnet", host._add_sea(Vector2i(4, 0)))
	host.sea[Vector2i(4, 0)].obj.store = {"wood": 4, "plastic": 1}
	host.sea[Vector2i(4, 0)].obj.count = 3
	_ok(await _wait_for(func(): return cli.sea.has(Vector2i(4, 0)) and int(cli.sea[Vector2i(4, 0)].obj.store.get("wood", 0)) == 4, 2.0), "host's collection net and its catch show up for the friend")
	cli.inv["wood"] = 0
	cli._tap_colnet(cli.sea[Vector2i(4, 0)].obj, cli.raft.to_global(Vector3(3.2 * Models.TILE, 0, 0)))
	cli.net.flush()
	_ok(cli.inv["wood"] == 4 and await _wait_for(func(): return host.sea[Vector2i(4, 0)].obj.store.is_empty(), 2.0), "friend emptied the net (host's net is empty too)")
	host._place("engine", host.tiles[Vector2i(2, 0)] if host.tiles[Vector2i(2, 0)].obj == null else host.tiles[Vector2i(-1, 0)])
	var eng: Dictionary = host._objs_of("engine")[0]
	eng.fuel = 120.0
	eng.on = true
	_ok(await _wait_for(func(): return not cli._objs_of("engine").is_empty() and cli._objs_of("engine")[0].on, 2.0), "friend sees the engine running")
	eng.on = false

	print("shelter")
	var key := ""
	for c in host.tiles:
		key = host.shelter.edge_key(c, c + Vector2i(0, -1), 0)
		break
	_ok(host.shelter.place("wall", key), "host builds a wall")
	_ok(await _wait_for(func(): return cli.shelter.edges.has(key), 2.0), "wall shows up for the friend")

	print("world")
	_ok(await _wait_for(func(): return cli.debris.filter(func(d): return d.has("nid")).size() >= 8, 2.0), "debris mirrored (%d)" % cli.debris.size())
	var d: Dictionary = cli.debris.filter(func(x): return x.has("nid"))[0]
	var nid := int(d.nid)
	cli._remove_debris(d)
	_ok(await _wait_for(func(): return host.debris.filter(func(x): return int(x.get("nid", -1)) == nid).is_empty(), 2.0), "friend grabbed debris: gone on the host")
	host.raft_pos = Vector2(6, 3)
	_ok(await _wait_for(func(): return cli.raft_pos.distance_to(Vector2(6, 3)) < 0.5, 3.0), "raft position follows the host")
	host.weather.kind = "rain"
	host.weather.rain = 0.8
	_ok(await _wait_for(func(): return cli.weather.kind == "rain", 2.0), "weather follows the host")
	_ok(absf(cli.game_t - host.game_t) < 3.0, "same time of day")

	print("shark")
	cli._toggle_swim()
	_ok(cli.swim != null, "friend jumped in")
	_ok(await _wait_for(func(): return host.net.remote_swimmers().size() == 1, 2.0), "host knows the friend is swimming")
	host.shark.state = "circle"
	host.shark.hunt_t = 0.0
	_ok(await _wait_for(func(): return host.shark.state == "hunt" and host.shark.tpeer == cli.net.me, 2.0), "shark hunts the friend")
	var hp0: float = cli.S.health
	var sp: Vector3 = cli.swim.pos
	host.shark.x = sp.x - 1.6
	host.shark.z = sp.z
	host.shark.dep = host.ocean.height(sp.x, sp.z) - sp.y
	_ok(await _wait_for(func(): return cli.S.health < hp0 - 10.0, 3.0), "the bite hurts the friend (%d -> %d)" % [hp0, cli.S.health])
	_ok(await _wait_for(func(): return Vector2(cli.shark.x - host.shark.x, cli.shark.z - host.shark.z).length() < 2.5, 2.0), "friend sees the shark where the host has it")
	host.shark.target = host._edge_tiles()[0]
	host.shark.side = host._bite_side(host.shark.target)
	host.shark.state = "approach"
	host.shark.lunge = false
	host.shark.warned = true
	cli.inv["spear"] = 1
	var hp_sh: int = host.shark.hp
	await _wait_for(func(): return cli.shark.state == "approach", 2.0)
	cli._tap_shark(Vector3(cli.shark.x, 0, cli.shark.z))
	_ok(await _wait_for(func(): return host.shark.hp < hp_sh or host.shark.state == "flee", 2.0), "friend's spear hits the host's shark")

	var out := OS.get_environment("SHOT_DIR")
	if out != "":
		cli._try_climb()
		cli._leave_water(null, true)
		host.cam_yaw = 0.9
		cli.cam_yaw = 2.6
		await _wait(1.5)
		var a: Image = vps[0].get_texture().get_image()
		var b: Image = vps[1].get_texture().get_image()
		var img := Image.create(a.get_width() * 2, a.get_height(), false, a.get_format())
		img.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
		img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width(), 0))
		img.save_png(out + "/coop.png")

	print("leaving")
	host._leave_room()
	_ok(host.net.role == "solo" and not host.paused, "host closed the room and keeps playing")
	_ok(await _wait_for(func(): return cli.net.role == "solo", 6.0), "friend notices the host left")
	_ok(cli.hud.menu.visible, "friend is back at the start screen")
	print("NET TEST DONE, %d failures" % fails)
	get_tree().quit(1 if fails > 0 else 0)
