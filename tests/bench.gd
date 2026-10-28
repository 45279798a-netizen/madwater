extends Node
## Performance probe: a mid-game raft (house, devices, farm), then frame stats for a few seconds.
## Prints script time per frame and, with a display, draw calls / objects / primitives.

var game
var f := 0
var acc := {"proc": 0.0, "draw": 0, "obj": 0, "prim": 0, "n": 0}

func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)

func _paint(kind: String, cells: Array) -> void:
	game._set_build(kind)
	for c in cells:
		game._tap_ghost(c)

func _process(_d: float) -> void:
	f += 1
	if f == 2:
		game._on_action("start_creative")
		game.weather.t = 999.0
		game.game_t = 45.0
		var floor := []
		for x in range(-2, 3):
			for z in range(-1, 3):
				floor.append(Vector2i(x, z))
		for pass_i in 4:
			for c in floor.duplicate():
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if game.tiles.has(c + d) and not game.tiles.has(c):
						_paint("floor", [c])
						floor.erase(c)
						break
		_paint("still", [Vector2i(2, 0)]); _paint("grill", [Vector2i(2, 1)]); _paint("sail", [Vector2i(-2, 0)])
		_paint("chest", [Vector2i(2, 2)]); _paint("catcher", [Vector2i(-2, 2)]); _paint("helm", [Vector2i(-2, -1)])
		_paint("field", [Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(0, 2)]); _paint("coop", [Vector2i(1, 2)])
		_paint("kelpfarm", [Vector2i(3, 0), Vector2i(3, 1)])
		game._set_build("")
		var sh = game.shelter
		for c in [Vector2i(0, 0), Vector2i(1, 0)]:
			sh.place("roof", "%d|%d|0" % [c.x, c.y])
		for k in [sh.edge_key(Vector2i(0, 0), Vector2i(0, -1), 0), sh.edge_key(Vector2i(1, 0), Vector2i(1, -1), 0), sh.edge_key(Vector2i(1, 0), Vector2i(2, 0), 0)]:
			sh.place("wall", k)
		game.cam_yaw = 0.7; game.cam_pitch = 0.5; game.cam_dist = 10.0
		print("tiles %d objs %d debris %d" % [game.tiles.size(), game.objs.size(), game.debris.size()])
		match OS.get_environment("BHIDE"):
			"islands":
				for i in game.islands:
					i.node.visible = false
			"ocean":
				game.ocean.visible = false
			"raft":
				game.raft.visible = false
			"pets":
				for k in game.companions.pets:
					game.companions.pets[k].node.visible = false
			"debris":
				for d in game.debris:
					d.node.visible = false
			"shark":
				game.shark_rig.visible = false
			"tiles":
				for t in game.tiles.values():
					t.node.visible = false
			"objs":
				for o in game.objs:
					o.node.visible = false
			"player":
				game.player.visible = false
			"shelter":
				for k in game.shelter.edges:
					game.shelter.edges[k].node.visible = false
				for k in game.shelter.roofs:
					game.shelter.roofs[k].visible = false
		match OS.get_environment("BSHADOW"):
			"off":
				game.sun.shadow_enabled = false
			"ortho":
				game.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			"pssm2":
				game.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if OS.get_environment("PROF") == "2" and f >= 60:
		var stage := (f - 60) / 40
		var names := ["all on", "hud off", "sfx off", "game off", "weather drops off"]
		if (f - 60) % 40 == 0:
			if stage > 0:
				print("PROF2 %-18s %.2f ms process, frame %.1f ms" % [names[stage - 1], acc.get("p2", 0.0) / 30.0, acc.get("w2", 0.0) / 30.0])
			acc["p2"] = 0.0
			acc["w2"] = 0.0
			match stage:
				1: game.hud.set_process(false)
				2: game.sfx.set_process(false)
				3: game.set_process(false)
				4: game.weather.drops.emitting = false
				5: get_tree().quit()
		if (f - 60) % 40 >= 10:
			acc.p2 += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var now := Time.get_ticks_usec()
			acc.w2 += (now - int(acc.get("last", now))) / 1000.0
		acc["last"] = Time.get_ticks_usec()
		return
	if f == 60 and OS.get_environment("PROF") == "1":
		game.set_process(false)
	if f > 60 and f <= 180 and OS.get_environment("PROF") == "1":
		var c: Dictionary = game._raft_center()
		var pw: Vector3 = game.player.global_position
		var parts := {
			"whole _process": func(): game._process(0.016),
			"_simulate": func(): game._simulate(0.016, c),
			"farm.update": func(): game.farm.update(0.016, 0.016),
			"companions.update": func(): game.companions.update(0.016, c),
			"weather.update": func(): game.weather.update(0.016, pw),
			"traders.update": func(): game.traders.update(0.016, c),
			"_update_hud": func(): game._update_hud(c),
			"_update_sky_and_camera": func(): game._update_sky_and_camera(0.016, pw),
			"_raft_center": func(): game._raft_center(),
			"net.update": func(): game.net.update(0.016),
			"_update_shark": func(): game._update_shark(0.016, c),
			"_refresh_goals": func(): game._refresh_goals(),
			"shelter.update_view": func(): game.shelter.update_view(0, game.P["x"], game.P["z"]),
		}
		for k in parts:
			var t0 := Time.get_ticks_usec()
			parts[k].call()
			acc[k] = float(acc.get(k, 0.0)) + (Time.get_ticks_usec() - t0) / 1000.0
		acc.n += 1
		if f == 180:
			for k in parts:
				print("PROF %-26s %.2f ms" % [k, acc[k] / acc.n])
			get_tree().quit()
		return
	if f > 60 and f <= 180:
		acc.proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		acc.draw += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		acc.obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		acc.prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		acc.n += 1
	if f == 181:
		var n: float = acc.n
		print("BENCH process %.2f ms/frame, draw calls %d, objects %d, primitives %dk" % [acc.proc / n, acc.draw / n, acc.obj / n, acc.prim / n / 1000.0])
		var count := 0
		for mi in game.find_children("*", "MeshInstance3D", true, false):
			if (mi as Node3D).is_visible_in_tree():
				count += 1
		print("BENCH visible mesh instances %d" % count)
		var by := {}
		for mi in game.find_children("*", "MeshInstance3D", true, false):
			if not (mi as Node3D).is_visible_in_tree():
				continue
			var cur: Node = mi
			while cur.get_parent() != game and cur.get_parent() != game.raft:
				cur = cur.get_parent()
			var what := ""
			if cur.get_script() != null:
				what = (cur.get_script() as Script).resource_path.get_file()
			elif game.islands.any(func(i): return i.node == cur):
				what = "island"
			elif cur == game.seabed_root:
				what = "seabed"
			elif game.traders.boat != null and game.traders.boat.node == cur:
				what = "trader"
			elif game.companions.pets.values().any(func(pp): return pp.node == cur):
				what = "pet"
			elif game.debris.any(func(d): return d.node == cur):
				what = "debris"
			elif game.objs.any(func(o): return o.node == cur):
				what = "obj:" + str(game.objs.filter(func(o): return o.node == cur)[0].kind)
			else:
				what = "?" + str(cur.get_child_count()) + ":" + ",".join(cur.get_children().slice(0, 3).map(func(c): return c.get_class() + "/" + str((c as MeshInstance3D).mesh.get_class() if c is MeshInstance3D and c.mesh else "")))
			var key: String = ("raft/" if cur.get_parent() == game.raft else "") + what
			if cur.get_parent() == game.raft and game.tiles.values().any(func(t): return t.node == cur):
				key = "raft/tile"
			by[key] = int(by.get(key, 0)) + 1
		var keys := by.keys()
		keys.sort_custom(func(a, b): return by[a] > by[b])
		for k in keys.slice(0, 18):
			print("BENCH   %-32s %d" % [k, by[k]])
		get_tree().quit()
