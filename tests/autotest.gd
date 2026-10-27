extends Node
## Headless smoke test: drives every gameplay system and prints PASS / FAIL lines.

var game
var frame := 0
var fails := 0

func _ready() -> void:
	Engine.max_fps = 60
	game = load("res://main.tscn").instantiate()
	add_child(game)
	if not game.has_method("_reset"):
		print("FAIL main script did not load")
		get_tree().quit(1)

func check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(("PASS " if ok else "FAIL ") + name)

func pw() -> Vector3:
	return game.player.global_position

func _process(_d: float) -> void:
	frame += 1
	match frame:
		5:
			game._on_action("start_survival")
			check("game started", not game.paused)
			game.inv["palm"] = 30; game.inv["plastic"] = 20; game.inv["wood"] = 60
			game._on_action("craft")
			for i in 8:
				game._on_recipe("rope")
			game._on_recipe("cup"); game._on_recipe("spear"); game._on_recipe("rod")
			check("crafted rope/cup/spear/rod", game.inv["cup"] == 1 and game.inv["spear"] == 1 and game.inv["rod"] == 1)
			game._on_action("build")
			game._on_recipe("floor")
			check("floor ghosts", game.ghosts.size() == 8)
			game._tap_ghost(Vector2i(2, 0)); game._tap_ghost(Vector2i(2, 1)); game._tap_ghost(Vector2i(-1, 0))
			check("tiles added", game.tiles.size() == 7)
			game.inv["rope"] = 20; game.inv["wood"] = 40; game.inv["plastic"] = 20; game.inv["palm"] = 20
			for spec in [["still", Vector2i(2, 0)], ["grill", Vector2i(2, 1)], ["sail", Vector2i(0, 0)], ["helm", Vector2i(-1, 0)]]:
				game._set_build(spec[0]); game._tap_ghost(spec[1])
			check("props placed", game.objs.size() == 4)
			var still = game._objs_of("still")[0]
			game.P["x"] = 4.0; game.P["z"] = 0.0
			game._tap_still(still, pw())
			check("still fueled", still.fuel > 0.0)
			still.prog = 19.9
			# grill
			game.inv["rawfish"] = 1
			game.P["x"] = 4.0; game.P["z"] = 2.0
			var grill = game._objs_of("grill")[0]
			game._tap_grill(grill, pw())
			check("fish on grill", grill.slots.size() == 1)
			grill.slots[0][0] = 0.05
		20:
			var still = game._objs_of("still")[0]
			check("still produced water", still.water >= 1)
			game._tap_still(still, pw())
			game._drink()
			check("drank", game.S["drank"] == 1)
			var grill = game._objs_of("grill")[0]
			check("fish cooked", grill.done.get("cooked", 0) == 1)
			game._tap_grill(grill, pw())
			game._eat()
			check("ate cooked fish", game.S["ate_cooked"] == 1)
			# fishing: cast onto water beside the raft
			game.P["x"] = 1.0; game.P["z"] = 1.0
			var o := pw() + Vector3(0, 8, 0)
			var target := pw() + Vector3(0, -0.25 - pw().y, 5.0)
			game._try_cast(o, (target - o).normalized(), pw())
			check("cast", game.fishing != null)
			game.fishing.wait = 0.1
		60:
			check("fish bite", game.fishing != null and game.fishing.phase == "bite")
			game._reel()
			check("caught fish", game.S["fished"] == 1 and game.inv["rawfish"] >= 1)
			var d = game.debris[0]
			d.x = pw().x + 5.0; d.z = pw().z
			game._tap_debris(d, pw())
			check("hook thrown", game.hook != null)
			game._pick(Vector2(640, 360))
			game.shark.timer = 0.01
		160:
			check("hook finished", game.hook == null)
			check("shark approaching or biting", game.shark.state in ["approach", "bite"])
			game.shark.state = "bite"
			game.shark.x = pw().x + 2.0; game.shark.z = pw().z
			for i in 3:
				game._tap_shark(pw())
			check("shark repelled", game.S["repelled"] == 1 and game.shark.state == "flee")
			# sailing
			var sail = game._objs_of("sail")[0]
			game.P["x"] = 0.0; game.P["z"] = 0.0
			game._tap_sail(sail, pw())
			var helm = game._objs_of("helm")[0]
			game.P["x"] = -2.0; game.P["z"] = 0.0
			game._tap_helm(helm, pw())
			check("steering", game.steer != null)
			game.heading = game.wind
		400:
			check("raft sailed", game.raft_pos.length() > 3.0)
			var isl = game.islands[0]
			game.raft_pos = Vector2(isl.x - 20.0, isl.z)
		420:
			check("island visited", game.S["islands"] == 1)
			var tree = game.islands[0].nodes[0]
			var before: int = game.inv["coconut"]
			game._tap_island(tree, Vector3(tree.node.global_position.x + 3.0, 0, tree.node.global_position.z))
			check("looted tree", game.inv["coconut"] == before + 2)
			game._exit_steer()
			game._set_build("demolish")
			var n_obj: int = game.objs.size()
			game._tap_ghost(Vector2i(2, 0))
			check("demolished prop", game.objs.size() == n_obj - 1)
			game._set_build("")
			# save / load round trip
			var snap := {"tiles": game.tiles.size(), "objs": game.objs.size(), "wood": game.inv["wood"],
				"raft": game.raft_pos, "islands": game.S["islands"], "fished": game.S["fished"]}
			game._save_game()
			game._reset()
			check("reset cleared state", game.tiles.size() == 4 and game.objs.is_empty())
			check("load ok", game._load_game())
			check("loaded tiles/props", game.tiles.size() == snap.tiles and game.objs.size() == snap.objs)
			check("loaded inventory/stats", game.inv["wood"] == snap.wood and game.S["islands"] == snap.islands and game.S["fished"] == snap.fished)
			check("loaded raft position", game.raft_pos.distance_to(snap.raft) < 0.01)
			check("loaded island state", game.islands[0].visited and not game.islands[0].nodes[0].nuts.visible)
			game.set_meta("wood_before", game.inv["wood"])
			check("skills gained xp", game.skills.hook.xp > 0 or game.skills.hook.lv > 0)
			check("build skill trained", game.skills.build.xp > 0 or game.skills.build.lv > 0)
			game.S["thirst"] = 0.0; game.S["hunger"] = 0.0; game.S["health"] = 0.5
		500:
			var bag = null
			for d in game.debris:
				if d.type == "bag":
					bag = d
			check("standard death keeps playing", not game.over and game.S["health"] >= 59.0)
			check("backpack dropped into the sea", bag != null and game.inv["wood"] == 0)
			if bag != null:
				bag.x = pw().x + 4.0; bag.z = pw().z
				game._tap_debris(bag, pw())
		620:
			check("backpack recovered", game.inv["wood"] == game.get_meta("wood_before"))
			# capacity: 20 slots of wood fills the starting backpack
			for k in game.STACK:
				game.inv[k] = 0
			game.inv["wood"] = 400
			check("full backpack blocks pickups", not game._fits({"wood": 2}))
			var free := []
			for t in game.tiles.values():
				if t.obj == null:
					free.append(t)
			game._place("chest", free[0])
			check("chest adds 12 slots", game._capacity() == 32 and game._fits({"wood": 2}))
			game._on_action("start_hardcore")
			check("hardcore has shark", game.shark_on and game.mode == "hardcore")
			game.S["thirst"] = 0.0; game.S["hunger"] = 0.0; game.S["health"] = 0.5
		700:
			check("hardcore death is game over", game.over)
			check("hardcore save removed on death", not FileAccess.file_exists(game.SAVE_PATH))
			game._on_action("retry")
			check("reset after retry", game.tiles.size() == 4 and not game.paused and game.objs.is_empty())
			# ---- diving
			game._on_action("start_standard")
			game.shark.timer = 999.0
			game.inv["plastic"] = 10; game.inv["rope"] = 6
			game._on_action("craft")
			game._on_recipe("goggles")
			check("crafted goggles", game.inv["goggles"] == 1)
			game._close_sheet()
			game._toggle_swim()
			check("in the water", game.swim != null and game.player.get_parent() == game)
			var clay = null
			for n in game.seabed_nodes:
				if n.kind == "clay":
					clay = n
					break
			check("seabed has clay", clay != null)
			game.set_meta("clay", clay)
			game.swim.pos = clay.pos + Vector3(0, 1.2, 0)
			game.shark.hunt_t = 0.05
		760:
			var clay = game.get_meta("clay")
			check("oxygen drains under water", game.swim != null and game.swim.o2 < game._o2_max())
			check("held near the seabed", game.swim.pos.y >= game.seabed_h(game.swim.pos.x, game.swim.pos.z) + 0.4)
			game._tap_seabed(clay, game.swim.pos)
			check("dug clay", game.inv["clay"] == 2 and game.S["dug"] == 1 and not clay.node.visible)
			check("shark hunts the diver", game.shark.state in ["hunt", "flee"])
			game.S["health"] = 100.0
			game.shark.state = "hunt"
			game.shark.x = game.swim.pos.x - 2.6; game.shark.z = game.swim.pos.z
			game.shark.head = 0.0
			game.shark.dep = game.ocean.height(game.shark.x, game.shark.z) - game.swim.pos.y
			game.swim.o2 = game._o2_max()
		820:
			check("shark bit the diver", game.S["health"] < 100.0 and game.shark.state == "flee")
			# swim back to the raft and climb on
			var t = game.tiles.values()[0]
			var tw := Vector2(game.raft_pos.x + t.cell.x * 2.0, game.raft_pos.y + t.cell.y * 2.0)
			game.swim.pos = Vector3(tw.x + 2.0, game.ocean.height(tw.x + 2.0, tw.y) - 0.7, tw.y)
			game._toggle_swim()
			check("climbed back aboard", game.swim == null and game.player.get_parent() == game.raft)
			game.inv["clay"] = 10; game.inv["sand"] = 10; game.inv["wood"] = 10
			var free = null
			for tt in game.tiles.values():
				if tt.obj == null:
					free = tt
					break
			game._set_build("filter")
			game._tap_ghost(free.cell)
			var filt = game._objs_of("filter")
			check("built ceramic filter", filt.size() == 1)
			if filt.size() == 1:
				filt[0].prog = 29.9
		880:
			check("filter made water", game._objs_of("filter")[0].water >= 1)
			game._save_game()
			game._reset()
			game._load_game()
			check("filter survives save", game._objs_of("filter").size() == 1)
			game._on_action("start_peaceful")
			check("peaceful has no shark", not game.shark_on)
			game._on_action("start_creative")
			check("creative infinite", game.inv["wood"] == 99)
			# ---- farming & animals, survival rules on a fresh raft; farms are laid tile by tile
			game.creative = false
			for k in game.inv:
				game.inv[k] = 0
			game.inv["wood"] = 40; game.inv["plastic"] = 12; game.inv["clay"] = 6; game.inv["rope"] = 12; game.inv["palm"] = 6
			game.P["x"] = 1.0; game.P["z"] = 1.0
			for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0), Vector2i(-1, 1)]:
				game._set_build("floor"); game._tap_ghost(c)
			game._set_build("field"); game._tap_ghost(Vector2i(0, 0)); game._tap_ghost(Vector2i(1, 0))
			check("farm build mode stays on for painting", game.build_mode == "field")
			game._set_build("coop"); game._tap_ghost(Vector2i(0, 1)); game._tap_ghost(Vector2i(1, 1))
			game._set_build("pen"); game._tap_ghost(Vector2i(-1, 0)); game._tap_ghost(Vector2i(-1, 1))
			game._set_build("kelpfarm"); game._tap_ghost(Vector2i(2, 0)); game._tap_ghost(Vector2i(2, 1))
			game._set_build("")
			var fl = game.tiles[Vector2i(0, 0)].obj
			check("8 farm tiles placed", game._objs_of("field").size() == 2 and game._objs_of("coop").size() == 2 and game._objs_of("pen").size() == 2 and game._objs_of("kelpfarm").size() == 2)
			check("touching tiles form one group", game.farm.group_of(fl).objs.size() == 2 and game.farm.group_of(game.tiles[Vector2i(0, 1)].obj).objs.size() == 2)
			# field: one tap plants the whole group
			game.inv["seed_potato"] = 5
			game._on_action("build"); game._close_sheet()
			game.farm.tap(fl, pw())
			check("plant sheet opens", game.sheet_mode == "plant")
			game._on_recipe("potato")
			var spots := 0
			for o in game._objs_of("field"):
				for sp in o.spots:
					spots += 1 if sp.crop == "potato" else 0
			check("planted 5 potatoes across the field", spots == 5 and game.inv["seed_potato"] == 0)
			game.inv["water"] = 6
			game.farm.tap(fl, pw())
			check("one tap waters every dry tile", game._objs_of("field").all(func(o): return o.moist == 1.0) and game.inv["water"] == 4)
			for o in game._objs_of("field"):
				for sp in o.spots:
					sp.grow = 0.9999 if sp.crop != "" else 0.0
			# coop: 3 hens, shared feed, eggs and breeding
			var cp = game.tiles[Vector2i(0, 1)].obj
			game.inv["chicken"] = 3; game.inv["kelp"] = 10
			game.farm.tap(cp, pw())
			check("3 hens moved in", game.farm._sum(game.farm.group_of(cp), "hens") == 3 and game.inv["chicken"] == 0)
			game.farm.tap(cp, pw())
			var lead = game.farm.group_of(cp).leader
			check("shared feed fills to 4 per tile", lead.food == 8 and game.inv["kelp"] == 2)
			lead.prog = game.farm.EGG_SEC - 0.01
			lead.breed = game.farm.HEN_BREED_SEC - 0.01
			# pen: full with 2 goats
			var pn = game.tiles[Vector2i(-1, 0)].obj
			game.inv["goat"] = 2
			game.farm.tap(pn, pw()); game.farm.tap(pn, pw())
			var pl = game.farm.group_of(pn).leader
			check("2 goats, fed and watered", game.farm._sum(game.farm.group_of(pn), "goats") == 2 and pl.food == 2 and pl.water == 4)
			pl.prog = game.farm.MILK_SEC - 0.01
			# kelp line
			var kf = game.tiles[Vector2i(2, 0)].obj
			game.inv["kelp"] = 2
			game.farm.tap(kf, pw())
			check("kelp seeded on both tiles", game._objs_of("kelpfarm").all(func(o): return o.planted) and game.inv["kelp"] == 0)
			for o in game._objs_of("kelpfarm"):
				o.prog = 59.99
		900:
			var fl = game.tiles[Vector2i(0, 0)].obj
			var before: int = game.inv["potato"]
			game.farm.tap(fl, pw())
			check("harvested the whole field", game.inv["potato"] == before + 15 and game.S["harvested"] == 5)
			var cp = game.tiles[Vector2i(0, 1)].obj
			var grp = game.farm.group_of(cp)
			check("hens laid", game.farm._sum(grp, "eggs") >= 1)
			check("a chick hatched", game.S["bred"] == 1 and game.farm._sum(grp, "hens") == 4)
			game.farm.tap(cp, pw())
			check("collected eggs", game.inv["egg"] >= 1 and game.S["eggs"] >= 1)
			check("hens wander as meshes", game.tiles[Vector2i(1, 1)].obj.beasts.size() == game.tiles[Vector2i(1, 1)].obj.hens)
			var pn = game.tiles[Vector2i(-1, 0)].obj
			check("goats gave milk", game.farm._sum(game.farm.group_of(pn), "milk") >= 1)
			game.farm.tap(pn, pw())
			check("milked", game.inv["milk"] >= 1)
			game.S["thirst"] = 50.0; game.S["hunger"] = 50.0; game.inv["water"] = 0
			game.inv["milk"] = 1
			game._drink()
			check("drank milk", game.inv["milk"] == 0 and game.S["thirst"] == 70.0 and game.S["hunger"] == 65.0)
			var kf = game.tiles[Vector2i(2, 0)].obj
			game.farm.tap(kf, pw())
			check("kelp harvested from the whole line", game.inv["kelp"] == 2)
			# the shark bites off a coop tile: its 2 hens float away, the rest of the coop keeps the feed
			var nd: int = game.debris.size()
			var food: int = grp.leader.food
			game._remove_tile(game.tiles[Vector2i(1, 1)])
			var last = game.debris[game.debris.size() - 1]
			check("bitten tile drops its hens", game.debris.size() == nd + 1 and last.give.get("chicken", 0) == 2)
			check("coop shrinks, feed stays", game.farm.group_of(cp).objs.size() == 1 and cp.food == food and cp.hens == 2)
			game._collect(last)
			check("rescued hens", game.inv["chicken"] == 2)
			# demolishing a pen tile puts its goat back in the bag
			game.inv["goat"] = 0
			game._set_build("demolish"); game._tap_ghost(Vector2i(-1, 1)); game._set_build("")
			check("demolish returns the goat", game.inv["goat"] == 1 and game._objs_of("pen").size() == 1)
			# grill an egg on the freed tile
			game.inv["rawfish"] = 0; game.inv["potato"] = 0; game.inv["egg"] = 1; game.inv["wood"] = 10; game.inv["rope"] = 4
			game._set_build("grill"); game._tap_ghost(Vector2i(-1, 1))
			var gr = game._objs_of("grill")[0]
			game._tap_grill(gr, pw())
			check("egg on grill", gr.slots.size() == 1 and gr.slots[0][1] == "egg")
			gr.slots[0][0] = 0.05
			# an unwatered crop withers
			game.inv["seed_tomato"] = 1
			game.farm.tap(fl, pw()); game._on_recipe("tomato")
			for o in game._objs_of("field"):
				o.moist = 0.0; o.dry = 59.99
		920:
			var fl = game.tiles[Vector2i(0, 0)].obj
			check("unwatered crop withered", fl.spots[0].dead)
			check("fried egg", game._objs_of("grill")[0].done.get("fegg", 0) == 1)
			var goat = null
			for n in game.islands[2].nodes:
				if n.kind == "goat":
					goat = n
			game.inv["goat"] = 0; game.inv["kelp"] = 1
			game._tap_island(goat, goat.node.global_position)
			check("tamed island goat", game.inv["goat"] == 1 and goat.used)
			game._save_game()
			game._reset()
			game._load_game()
			var cp = game.tiles[Vector2i(0, 1)].obj
			check("farm survives save", game._objs_of("field").size() == 2 and cp != null and cp.kind == "coop" and cp.hens == 2 and game.tiles[Vector2i(0, 0)].obj.spots[0].dead)
			check("goat stays tamed after load", goat.used and not goat.node.visible)
			check("grill dict survives save", game._objs_of("grill")[0].done.get("fegg", 0) == 1)
			var old := {"kind": "planter", "crop": "tomato", "grow": 0.5, "dead": false, "moist": 0.4}
			var f2 = game.tiles[Vector2i(1, 0)].obj
			game.farm.load_state(f2, old)
			check("old one-pot save loads into a field", f2.spots[0].crop == "tomato" and f2.spots[0].grow == 0.5)
			# ---- trade boats
			game.creative = false
			game.traders.reset()
			game.traders.timers["fisher"] = 0.01
		930:
			var tb = game.traders.boat
			check("fisherman's boat arrives", tb != null and tb.kind == "fisher" and tb.state == "arrive")
			game.traders.tap(pw())
			check("can't trade while it is still far away", game.sheet_mode != "trade")
			var c = game._raft_center()
			tb.x = c.x + tb.dir.x * (c.r + 7.0); tb.z = c.z + tb.dir.y * (c.r + 7.0)
		934:
			var tb = game.traders.boat
			check("boat docks beside the raft", tb.state == "stay")
			game.P["x"] = 1.0; game.P["z"] = 1.0
		936:
			var tb = game.traders.boat
			game.traders.tap(Vector3(tb.x, 0, tb.z))
			check("trade sheet opens", game.sheet_mode == "trade" and game.hud.sheet.visible)
			game.inv["rawfish"] = 5; game.inv["shell"] = 0
			for i in 4:
				game.traders.trade("sell:rawfish")
			check("sold 4 fish, price drops on the 4th", game.inv["rawfish"] == 1 and game.inv["shell"] == 11)
			game.inv["shell"] = 30
			game.traders.trade("buy:3")
			check("bought the better rod", game.inv["rod2"] == 1 and game.inv["shell"] == 5)
			game.traders.trade("buy:3")
			check("can't buy a second rod", game.inv["rod2"] == 1 and game.inv["shell"] == 5)
			game.traders.rep["fisher"] = 7
			game.traders.trade("sell:rawfish")
			check("rapport level 1 after 8 trades", game.traders.level("fisher") == 1)
			var before: int = game.inv["shell"]
			game.traders.trade("buy:0")
			check("rapport discount (6 -> 5 coins)", game.inv["shell"] == before - 5 and game.inv["seed_tomato"] >= 2)
			check("trade goal counted", game.S["trades"] >= 1)
			game.traders.rep["fisher"] = 20
			check("hidden item at 老朋友", game.traders.sheet().any(func(r): return str(r.name).contains("私藏")))
			# bait halves the wait for a bite
			game._close_sheet()
			game.inv["bait"] = 2; game.inv["rod"] = 1; game._set_build("")
			game.P["x"] = 1.0; game.P["z"] = 1.0
		940:
			var o: Vector3 = pw() + Vector3(0, 8, 0)
			var target: Vector3 = pw() + Vector3(0, -0.25 - pw().y, 5.0)
			game.fishing = null
			game._try_cast(o, (target - o).normalized(), pw())
			check("bait used on cast", game.inv["bait"] == 1 and game.fishing != null and game.fishing.wait < 4.0)
			game.fishing = null
			game.bobber.visible = false
			game.traders.boat.t = 0.01
		944:
			check("boat leaves when its time is up", game.traders.boat.state == "leave")
			var tb = game.traders.boat
			tb.x += tb.dir.x * 200.0; tb.z += tb.dir.y * 200.0
		946:
			check("boat gone once far away", game.traders.boat == null)
			game._save_game()
			game._reset()
			check("reset clears rapport", game.traders.rep["fisher"] == 0)
			game._load_game()
			check("rapport survives save", game.traders.rep["fisher"] >= 20)
			# the animal ship sells chickens
			game.traders.timers["fisher"] = 999.0; game.traders.timers["water"] = 999.0; game.traders.timers["ark"] = 0.01
		950:
			var tb = game.traders.boat
			check("animal ship arrives", tb != null and tb.kind == "ark")
			tb.state = "stay"; tb.t = 100.0
			game.inv["shell"] = 12; game.inv["chicken"] = 0
			game.traders.trade("buy:0")
			check("bought a chicken from 諾亞號", game.inv["chicken"] == 1 and game.inv["shell"] == 0)
			# ---- houses: walls, doors, upper floor, stairs, roofs
			game._on_action("start_creative")
			game.creative = false
			game.traders.timers["fisher"] = 999.0; game.traders.timers["water"] = 999.0; game.traders.timers["ark"] = 999.0
			game.traders._remove_boat()
			for c in [Vector2i(2, 0), Vector2i(2, 1)]:
				game._set_build("floor"); game._tap_ghost(c)
			game.P["x"] = 0.0; game.P["z"] = 0.0
			var sh = game.shelter
			game._set_build("wall")
			check("wall ghosts on every free edge", sh.ghosts.size() == 17)
			var wk: String = Shelter.edge_key(Vector2i(0, 0), Vector2i(1, 0), 0)
			var wood0: int = game.inv["wood"]
			game._place_shelter(wk)
			check("wall built", sh.edges.has(wk) and sh.edges[wk].kind == "wall" and game.inv["wood"] == wood0 - 4)
			check("wall blocks walking", not sh.can_walk(0.0, 0.0, 1.3, 0.0, 0))
			game._set_build("door")
			var dk: String = Shelter.edge_key(Vector2i(0, 0), Vector2i(0, 1), 0)
			game._place_shelter(dk)
			check("door lets you through", sh.can_walk(0.0, 0.0, 0.0, 1.3, 0))
			check("upper floor needs support", sh.upper_ok(Vector2i(1, 0)) and not sh.upper_ok(Vector2i(2, 1)))
			game._set_build("window")
			var wnk: String = Shelter.edge_key(Vector2i(1, 1), Vector2i(2, 1), 0)
			game._place_shelter(wnk)
			check("window wall blocks walking", not sh.can_walk(2.0, 2.0, 3.3, 2.0, 0))
			game._set_build("upper")
			game._place_shelter("1|0")
			game._place_shelter("2|0")
			check("upper floor + one tile out", sh.uppers.has(Vector2i(1, 0)) and sh.uppers.has(Vector2i(2, 0)))
			game._set_build("stairs")
			game._tap_ghost(Vector2i(1, 1))
			var st = game.tiles[Vector2i(1, 1)].obj
			check("stairs placed facing the upper floor", st != null and st.kind == "stairs" and st.dir == Vector2i(0, -1))
			game._set_build("")
			game.P["x"] = 2.0; game.P["z"] = 2.0
			game._tap_stairs(st, Vector3(2.0, 0, 2.0) + game.raft.global_position)
			check("climbed the stairs", game.P["level"] == 1)
		962:
			var sh = game.shelter
			check("player stands on the upper floor", game.player.position.y > 2.3)
			check("upper floor walkable, edge is not", sh.can_walk(game.P["x"], game.P["z"], 4.0, 0.0, 1) and not sh.can_walk(game.P["x"], game.P["z"], 2.0, 3.2, 1))
			game._set_build("pillar")
			check("posts offered on the upper floor", sh.ghosts.size() > 0)
			game._place_shelter("1|0|1")
			game._set_build("roof")
			game._place_shelter("1|0|1")
			game._place_shelter("2|0|1")
			check("roof over the upper floor", sh.roofs.has("1|0|1") and sh.roofs.has("2|0|1"))
			game.P["level"] = 0; game.P["x"] = 0.0; game.P["z"] = 0.0
			game._set_build("roof")
			game._place_shelter("0|0|0")
			check("roof on the deck rests on the wall", sh.roofs.has("0|0|0"))
			check("house goal", game.S["built_house"] == 1 and sh.covered_count() >= 3)
			game._set_build("")
			game.P["level"] = 1; game.P["x"] = 2.0; game.P["z"] = 0.0
		966:
			var sh = game.shelter
			check("roof hidden while you stand under it", not sh.roofs["1|0|1"].visible)
			game._save_game()
			game._reset()
			check("reset clears houses", sh.edges.is_empty() and sh.uppers.is_empty())
			game._load_game()
			check("house survives save", sh.edges.size() == 3 and sh.uppers.size() == 2 and sh.roofs.size() == 3 and sh.posts.size() == 1 and game.P["level"] == 1)
			check("stairs still aimed after load", game.tiles[Vector2i(1, 1)].obj.dir == Vector2i(0, -1))
			# knock out the wall holding everything up
			game._set_build("demolish")
			var wk: String = Shelter.edge_key(Vector2i(0, 0), Vector2i(1, 0), 0)
			game._demolish_shelter(["wall", wk])
			check("upper floor falls without support", sh.uppers.is_empty() and not sh.roofs.has("1|0|1") and sh.posts.is_empty())
			check("deck roof still held by the door", sh.roofs.has("0|0|0"))
			check("player dropped to the deck", game.P["level"] == 0)
			game._set_build("")
			# the shark bites off the roofed tile
			game._remove_tile(game.tiles[Vector2i(0, 0)])
			check("roof goes with its tile", not sh.roofs.has("0|0|0"))
			# ---- weather: rain fills catchers and waters fields, storms hurt what is in the open
			game._on_action("start_standard")
			game.shark.timer = 999.0
			for k in ["wood", "plastic", "rope", "clay", "palm"]:
				game.inv[k] = 20
			game.inv["cup"] = 3; game.inv["water"] = 0; game.inv["seed_potato"] = 2
			game.P["x"] = 1.0; game.P["z"] = 1.0
			game._set_build("catcher"); game._tap_ghost(Vector2i(1, 0))
			game._set_build("field"); game._tap_ghost(Vector2i(0, 1)); game._set_build("")
			var fl = game.tiles[Vector2i(0, 1)].obj
			fl.spots[0].crop = "potato"; fl.moist = 0.0
			var w = game.weather
			w.kind = "rain"; w.rain = 1.0; w.t = 100.0
			game.tiles[Vector2i(1, 0)].obj.prog = 14.99
		970:
			var w = game.weather
			check("rain waters the open field", game.tiles[Vector2i(0, 1)].obj.moist > 0.95)
			var ct = game.tiles[Vector2i(1, 0)].obj
			check("rain catcher fills", ct.water >= 1)
			game._tap_filter(ct, game.player.global_position)
			check("collected rain water", game.inv["water"] == 1)
			# storm
			for c in [Vector2i(2, 0), Vector2i(2, 1)]:
				game._set_build("floor"); game._tap_ghost(c)
			game._set_build("")
			w.kind = "storm"; w.storm = 1.0; w.rain = 1.0; w.cloud = 1.0; w.t = 100.0
			w._tick = 0.01
			game.S["health"] = 100.0
		990:
			var w = game.weather
			var dmg := 0
			for t in game.tiles.values():
				dmg += 3 - int(t.hp)
			check("storm waves damage an exposed tile", dmg >= 1)
			check("chilled out in the storm", game.S["health"] < 100.0)
			check("animals in the open get scared", w.animals_scared(Vector2i(0, 0)))
			check("waves grow in the storm", game.ocean.storm > 0.9)
			check("weather shown on the clock", game.hud.clock.text.ends_with("風暴"))
			game._save_game()
			game._reset()
			check("reset clears the weather", w.kind == "clear")
			game._load_game()
			check("weather survives save", w.kind == "storm")
			w.t = 0.01
		992:
			check("storm passes into clear weather", game.weather.kind == "clear")
			# ---- sea companions
			game._on_action("start_standard")
			game.shark.timer = 999.0
			game.weather.t = 999.0
			var cp = game.companions
			game.inv["rawfish"] = 8; game.inv["kelp"] = 3; game.inv["goggles"] = 1
			var gull: Node3D = cp.pets.gull.node
			for i in 3:
				cp.pets.gull.cd = 0.0
				cp.tap("gull", gull.global_position)
			check("seagull tamed after 3 fish", cp.pets.gull.tamed and cp.pets.gull.follow and game.S["pets"] == 1)
			check("companion button appears", game.hud.btn["skills"].text == "夥伴")
			cp.pets.gull.decay_fetch = 0.0
			game.set_meta("fish0", game.inv["rawfish"])
		1000:
			var cp = game.companions
			check("seagull marks nearby debris", game.debris.any(func(d): return d.has("mark")))
			check("seagull flies off to fetch", cp.pets.gull.task != null or int(cp.pets.gull.get("fetched", 0)) > 0)
			# dolphin: feed, then swim beside it three times
			var dol: Node3D = cp.pets.dolphin.node
			cp.tap("dolphin", dol.global_position)
			check("dolphin fed", cp.pets.dolphin.fed_once)
			var t = game.tiles.values()[0]
			game.P["x"] = t.cell.x * 2.0; game.P["z"] = t.cell.y * 2.0
			game._toggle_swim()
			check("in the water", game.swim != null)
			for i in 3:
				game.swim.pos = dol.global_position
				cp.swim_tick(6.1)
			check("dolphin tamed after 3 swims", cp.pets.dolphin.tamed and cp.pets.dolphin.follow)
			# turtle: dive to the wreck and cut the net
			var tur: Node3D = cp.pets.turtle.node
			for i in 3:
				game.swim.pos = tur.global_position + Vector3(0.5, 0, 0)
				cp.tap("turtle", game.swim.pos)
			check("turtle freed from the net", cp.pets.turtle.tamed and not cp.pets.turtle.net.visible)
			check("all three follow without huts", cp.pets.values().all(func(q): return q.follow))
			cp.set_follow("gull", false)
			check("can't send the gull home without a nest", cp.pets.gull.follow)
			# low on air: the turtle gives a bubble
			game.swim.pos = Vector3(game.swim.pos.x, game.ocean.height(game.swim.pos.x, game.swim.pos.z) - 3.0, game.swim.pos.z)
			game.swim.o2 = 5.0
		1006:
			var cp = game.companions
			check("turtle gives an air bubble", game.swim.o2 > 12.0 and cp.pets.turtle.bubble_used)
			# back aboard
			var t = game.tiles.values()[0]
			var tw := Vector2(game.raft_pos.x + t.cell.x * 2.0, game.raft_pos.y + t.cell.y * 2.0)
			game.swim.pos = Vector3(tw.x + 2.0, game.ocean.height(tw.x + 2.0, tw.y) - 0.7, tw.y)
			game._toggle_swim()
			check("climbed back", game.swim == null)
			for k in ["wood", "plastic", "palm", "rope", "clay"]:
				game.inv[k] = 30
			for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0)]:
				game._set_build("floor"); game._tap_ghost(c)
			game._set_build("gullnest"); game._tap_ghost(Vector2i(2, 0))
			game._set_build("dolphinpost"); game._tap_ghost(Vector2i(2, 1))
			game._set_build("")
			cp.set_follow("gull", false)
			check("gull goes to its nest", not cp.pets.gull.follow)
			check("dolphin on a post pulls the raft", cp.pull() > 1.15 and cp.upwind() > 0.3)
			cp.pets.gull.cd = 0.0
			var a0: float = cp.pets.gull.aff
			cp.feed("gull")
			check("feeding raises affinity", cp.pets.gull.aff == a0 + 12.0)
			cp.pets.dolphin.aff = 100.0
			var rammed := false
			for i in 30:
				cp.pets.dolphin.ram_cd = 0.0
				if cp.shark_bite():
					rammed = true
					break
			check("dolphin can ram the shark", rammed)
		1010:
			var cp = game.companions
			var nest: Node3D = game._objs_of("gullnest")[0].node
			check("gull rests on the nest", cp.pets.gull.node.global_position.distance_to(nest.global_position) < 2.0)
			game._save_game()
			game._reset()
			check("reset releases companions", not cp.any_tamed())
			game._load_game()
			check("companions survive save", cp.pets.dolphin.tamed and cp.pets.turtle.tamed and not cp.pets.gull.follow)
			cp.pets.turtle.aff = 0.5; cp.pets.turtle.decay = 0.01
		1012:
			check("neglected companion leaves", not game.companions.pets.turtle.tamed)
			print("AUTOTEST DONE, %d failures" % fails)
			get_tree().quit()
