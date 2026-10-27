class_name Farm
extends RefCounted
## Tile-built farms: fields, kelp lines, chicken yards and goat pens.
## Each is laid one raft tile at a time; touching tiles of the same kind form one group with a single
## label, shared feed / water, one tap that acts on the whole group, animals that wander across it,
## and breeding while there is room.

const KINDS := ["field", "kelpfarm", "coop", "pen"]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SPOTS := [Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(-0.45, 0.45), Vector2(0.45, 0.45)]
const HENS_PER_TILE := 2
const GOATS_PER_TILE := 1
const EGGS_PER_TILE := 3
const MILK_PER_TILE := 2
const COOP_FEED_PER_TILE := 4
const PEN_FEED_PER_TILE := 2
const KELP_PER_TILE := 3
const EGG_SEC := 60.0       ## one egg per hen per minute while fed
const MILK_SEC := 90.0      ## one milk per goat per 90 s while fed and watered
const KELP_SEC := 60.0
const HEN_BREED_SEC := 120.0
const GOAT_BREED_SEC := 180.0
const MOIST_SEC := 90.0     ## one cup keeps a field tile wet this long
const WITHER_SEC := 60.0    ## dry this long and the tile's crops die

var g                       ## the main game script
var groups: Array = []      ## [{kind, objs, leader}]
var dirty := true
var _houses: Array = []


func _init(game) -> void:
	g = game


static func is_farm(kind: String) -> bool:
	return kind in KINDS


func setup(o: Dictionary) -> void:
	match o.kind:
		"field":
			o["spots"] = []
			for i in 4:
				var pn := Node3D.new()
				pn.position = Vector3(SPOTS[i].x, 0.2, SPOTS[i].y)
				pn.scale = Vector3(0.8 / Models.K, 0.8, 0.8 / Models.K)   # plants keep their shape on the stretched tile
				o.node.add_child(pn)
				o.spots.append({"crop": "", "grow": 0.0, "dead": false, "shown": "", "node": pn})
			o["moist"] = 0.0
			o["dry"] = 0.0
		"kelpfarm":
			o["planted"] = false
			o["kelp"] = 0
			o["prog"] = 0.0
		"coop":
			o["hens"] = 0
			o["food"] = 0
			o["eggs"] = 0
			o["prog"] = 0.0
			o["breed"] = 0.0
		"pen":
			o["goats"] = 0
			o["food"] = 0
			o["water"] = 0
			o["milk"] = 0
			o["prog"] = 0.0
			o["breed"] = 0.0
	o["label"] = g._label3d(o.node)
	o["beasts"] = []
	o["gi"] = -1
	dirty = true


# ---------------------------------------------------------------- groups

func _same(o: Dictionary, c: Vector2i) -> bool:
	var t = g.tiles.get(c)
	return t != null and t.obj != null and t.obj.kind == o.kind


func _rebuild() -> void:
	dirty = false
	groups.clear()
	for h in _houses:
		h.queue_free()
	_houses.clear()
	var seen := {}
	for o in g.objs:
		if not is_farm(o.kind) or seen.has(o.tile.cell):
			continue
		var members := []
		seen[o.tile.cell] = true
		var stack := [o]
		while not stack.is_empty():
			var a: Dictionary = stack.pop_back()
			members.append(a)
			for d in DIRS:
				var c: Vector2i = a.tile.cell + d
				if _same(o, c) and not seen.has(c):
					seen[c] = true
					stack.append(g.tiles[c].obj)
		members.sort_custom(func(a, b): return a.tile.cell.y < b.tile.cell.y or (a.tile.cell.y == b.tile.cell.y and a.tile.cell.x < b.tile.cell.x))
		var grp := {"kind": o.kind, "objs": members, "leader": members[0]}
		var gi := groups.size()
		groups.append(grp)
		var lead: Dictionary = members[0]
		# shared feed / water lives on the leader: pool what merged groups brought in
		for k in ["food", "water"]:
			if lead.has(k):
				for a in members:
					if a != lead:
						lead[k] += a[k]
						a[k] = 0
		var centre := Vector2.ZERO
		for a in members:
			a.gi = gi
			centre += Vector2(a.tile.cell)
			var open := []
			for d in DIRS:
				open.append(_same(o, a.tile.cell + d))
			Models.farm_edges(a.node, o.kind, open)
			a.label.visible = a == lead
		centre /= members.size()
		var off: Vector2 = (centre - Vector2(lead.tile.cell)) * g.TILE
		lead.label.position = Vector3(off.x / Models.K, 1.35, off.y / Models.K)   # the tile node is stretched by K
		if o.kind == "coop":
			var h := Models.hen_house()
			h.scale = Vector3(1.0 / Models.K, 1.0, 1.0 / Models.K)
			lead.node.add_child(h)
			_houses.append(h)


func group_of(o: Dictionary) -> Dictionary:
	if dirty:
		_rebuild()
	return groups[o.gi]


func _sum(grp: Dictionary, k: String) -> int:
	var n := 0
	for a in grp.objs:
		n += int(a[k])
	return n


## Called when a farm tile is about to disappear: keep the group's shared pool, free its animals' meshes.
func forget(o: Dictionary) -> void:
	if not dirty and o.gi >= 0 and o.gi < groups.size():
		var grp: Dictionary = groups[o.gi]
		if grp.leader == o and grp.objs.size() > 1:
			var heir: Dictionary = grp.objs[1]
			for k in ["food", "water", "prog", "breed"]:
				if o.has(k):
					heir[k] = o[k]
	for b in o.beasts:
		b.node.queue_free()
	o.beasts.clear()
	dirty = true


## Animals living on this tile, as inventory items.
func animals_on(o: Dictionary) -> Dictionary:
	if o.kind == "coop" and o.hens > 0:
		return {"chicken": o.hens}
	if o.kind == "pen" and o.goats > 0:
		return {"goat": o.goats}
	return {}


# ---------------------------------------------------------------- simulation

## sdt: how far the farm's own timers run (0 on a friend's game: the host grows everything).
func update(dt: float, sdt := -1.0) -> void:
	if sdt < 0.0:
		sdt = dt
	if dirty:
		_rebuild()
	for grp in groups:
		match grp.kind:
			"field":
				_sim_field(grp, sdt)
			"kelpfarm":
				_sim_kelp(grp, sdt)
			"coop":
				_sim_coop(grp, sdt)
			"pen":
				_sim_pen(grp, sdt)
		for a in grp.objs:
			_sync_beasts(a, grp, dt)
		_label(grp)


func _sim_field(grp: Dictionary, dt: float) -> void:
	for a in grp.objs:
		var living: Array = a.spots.filter(func(s): return s.crop != "" and not s.dead)
		if not living.is_empty():
			if a.moist > 0.0:
				a.moist = maxf(0.0, a.moist - dt / MOIST_SEC)
				a.dry = 0.0
				for s in living:
					s.grow = minf(1.0, s.grow + dt / g.CROPS[s.crop][1])
			else:
				a.dry += dt
				if a.dry >= WITHER_SEC:
					for s in living:
						s.dead = true
					g.hud.toast("有一格菜田缺水，作物枯死了")
		for s in a.spots:
			var shown := "%s|%d|%s" % [s.crop, int(s.grow * 5.0), s.dead]
			if shown != s.shown:
				s.shown = shown
				Models.set_crop(s.node, s.crop, s.grow, s.dead)
		a.node.get_node("Soil").material_override = Models.soil_mat(a.moist > 0.0)


func _sim_kelp(grp: Dictionary, dt: float) -> void:
	for a in grp.objs:
		if a.planted and a.kelp < KELP_PER_TILE:
			a.prog += dt
			if a.prog >= KELP_SEC:
				a.prog = 0.0
				a.kelp += 1
		var strips: Node3D = a.node.get_node("Kelp")
		strips.visible = a.planted
		if a.planted:
			strips.scale = Vector3(1, 0.4 + 0.2 * a.kelp + 0.2 * a.prog / KELP_SEC, 1)


func _sim_coop(grp: Dictionary, dt: float) -> void:
	var lead: Dictionary = grp.leader
	var hens := _sum(grp, "hens")
	var cap: int = grp.objs.size() * HENS_PER_TILE
	if _scared(grp):
		pass
	elif hens > 0 and lead.food > 0 and _sum(grp, "eggs") < grp.objs.size() * EGGS_PER_TILE:
		lead.prog += dt * hens
		if lead.prog >= EGG_SEC:
			lead.prog -= EGG_SEC
			lead.food -= 1
			var best = null
			for a in grp.objs:
				if a.eggs < EGGS_PER_TILE and (best == null or a.eggs < best.eggs):
					best = a
			best.eggs += 1
	if hens >= 2 and hens < cap and lead.food > 0 and not _scared(grp):
		lead.breed += dt
		if lead.breed >= HEN_BREED_SEC:
			lead.breed = 0.0
			lead.food -= 1
			_add_animal(grp, "hens", HENS_PER_TILE, 1)
			g.S["bred"] += 1
			g.hud.toast("孵出一隻小雞！（雞 %d/%d）" % [hens + 1, cap])
			g.sfx.play("pickup")
	for a in grp.objs:
		var eggs: Node3D = a.node.get_node("Eggs")
		for i in eggs.get_child_count():
			eggs.get_child(i).visible = i < a.eggs


func _sim_pen(grp: Dictionary, dt: float) -> void:
	var lead: Dictionary = grp.leader
	var goats := _sum(grp, "goats")
	var cap: int = grp.objs.size() * GOATS_PER_TILE
	if _scared(grp):
		pass
	elif goats > 0 and lead.food > 0 and lead.water > 0 and _sum(grp, "milk") < grp.objs.size() * MILK_PER_TILE:
		lead.prog += dt * goats
		if lead.prog >= MILK_SEC:
			lead.prog -= MILK_SEC
			lead.food -= 1
			lead.water -= 1
			var best = null
			for a in grp.objs:
				if a.milk < MILK_PER_TILE and (best == null or a.milk < best.milk):
					best = a
			best.milk += 1
	if goats >= 2 and goats < cap and lead.food > 0 and lead.water > 0 and not _scared(grp):
		lead.breed += dt
		if lead.breed >= GOAT_BREED_SEC:
			lead.breed = 0.0
			lead.food -= 1
			lead.water -= 1
			_add_animal(grp, "goats", GOATS_PER_TILE, 1)
			g.S["bred"] += 1
			g.hud.toast("生了一隻小山羊！（山羊 %d/%d）" % [goats + 1, cap])
			g.sfx.play("pickup")


## A storm over an unroofed coop / pen: the animals hide and stop producing.
func _scared(grp: Dictionary) -> bool:
	return g.weather != null and grp.objs.any(func(a): return g.weather.animals_scared(a.tile.cell))


## Put n animals into the tiles that still have room; returns how many fitted.
func _add_animal(grp: Dictionary, key: String, per_tile: int, n: int) -> int:
	var placed := 0
	for a in grp.objs:
		while placed < n and a[key] < per_tile:
			a[key] += 1
			placed += 1
	return placed


# ---------------------------------------------------------------- wandering animals

func _sync_beasts(a: Dictionary, grp: Dictionary, dt: float) -> void:
	if not a.has("hens") and not a.has("goats"):
		return
	var want: int = a.hens if a.has("hens") else a.goats
	while a.beasts.size() < want:
		var node := Models.chicken() if a.kind == "coop" else Models.goat()
		if a.kind == "pen":
			node.scale = Vector3.ONE * 0.75
		g.raft.add_child(node)
		var p: Vector2 = Vector2(a.tile.cell) * g.TILE + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * Models.K
		a.beasts.append({"node": node, "pos": p, "target": p, "wait": randf_range(0.0, 2.0)})
	while a.beasts.size() > want:
		a.beasts.pop_back().node.queue_free()
	var speed := 0.45 if a.kind == "coop" else 0.3
	for b in a.beasts:
		var to: Vector2 = b.target - b.pos
		if b.wait > 0.0:
			b.wait -= dt
			if b.wait <= 0.0:
				var pick: Dictionary = grp.objs[randi() % grp.objs.size()]
				b.target = Vector2(pick.tile.cell) * g.TILE + Vector2(randf_range(-0.65, 0.65), randf_range(-0.65, 0.65)) * Models.K
		elif to.length() < 0.05:
			b.wait = randf_range(1.0, 4.0)
		else:
			b.pos += to.normalized() * minf(speed * dt, to.length())
			b.node.rotation.y = atan2(to.x, to.y)
		var peck: float = maxf(0.0, sin(g.wall_t * 6.0 + b.pos.x * 3.0)) * 0.45 if b.wait > 0.0 and a.kind == "coop" else 0.0
		b.node.rotation.x = peck
		b.node.position = Vector3(b.pos.x, 0.08 + (absf(sin(g.wall_t * 12.0)) * 0.03 if b.wait <= 0.0 else 0.0), b.pos.y)


# ---------------------------------------------------------------- labels

func _label(grp: Dictionary) -> void:
	var lead: Dictionary = grp.leader
	var lb: Label3D = lead.label
	var n: int = grp.objs.size()
	lb.modulate = Color("f4ecd6")
	match grp.kind:
		"field":
			var planted := 0
			var ripe := 0
			var dead := 0
			var grow := 0.0
			var dry := 0
			var worst := 0.0
			for a in grp.objs:
				var living := 0
				for s in a.spots:
					if s.crop == "":
						continue
					planted += 1
					if s.dead:
						dead += 1
					else:
						living += 1
						grow += s.grow
						if s.grow >= 1.0:
							ripe += 1
				if living > 0 and a.moist <= 0.0:
					dry += 1
					worst = maxf(worst, a.dry)
			var head := "菜田 %d 格" % n
			if planted == 0:
				lb.text = "空的%s · 點我種（每格 4 株）" % head
			elif ripe > 0:
				lb.modulate = Color("7fd88a")
				lb.text = "%s · %d 株成熟 · 點我收成" % [head, ripe]
			elif dry > 0:
				lb.modulate = Color("ef5b5b")
				lb.text = "%s · %d 格缺水！點我澆水（%d 秒後枯死）" % [head, dry, ceili(WITHER_SEC - worst)]
			elif dead > 0 and dead == planted:
				lb.modulate = Color("ef5b5b")
				lb.text = "%s · 全枯死了 · 點我清掉" % head
			else:
				lb.text = "%s · %d/%d 株 · 生長 %d%%" % [head, planted, n * 4, int(grow / maxi(1, planted - dead) * 100.0)]
		"kelpfarm":
			var kelp := _sum(grp, "kelp")
			var planted := 0
			for a in grp.objs:
				planted += 1 if a.planted else 0
			if planted == 0:
				lb.text = "海藻養殖架 %d 格 · 每格放 1 條海帶當種苗" % n
			elif kelp > 0:
				lb.modulate = Color("7fd88a")
				lb.text = "海藻養殖架 %d 格 · 海帶 %d 條 · 點我收" % [n, kelp]
			else:
				lb.text = "海藻養殖架 %d/%d 格在長 · %d 秒" % [planted, n, ceili(KELP_SEC - grp.objs.reduce(func(m, a): return maxf(m, a.prog if a.planted else 0.0), 0.0))]
		"coop":
			var hens := _sum(grp, "hens")
			var eggs := _sum(grp, "eggs")
			var cap := n * HENS_PER_TILE
			var t := "雞 %d/%d · 飼料 %d/%d" % [hens, cap, lead.food, n * COOP_FEED_PER_TILE]
			if hens == 0:
				lb.text = "空的雞舍 %d 格 · 每格住 2 隻雞" % n
			elif _scared(grp):
				lb.modulate = Color("ef5b5b")
				lb.text = t + " · 風暴中雞嚇得不生蛋（蓋屋頂保護）"
			elif eggs > 0:
				lb.modulate = Color("f3e6cf")
				lb.text = t + " · 蛋 %d · 點我撿" % eggs
			elif lead.food <= 0:
				lb.modulate = Color("ef5b5b")
				lb.text = t + " · 雞餓了，點我餵"
			elif hens >= 2 and hens < cap:
				lb.text = t + " · %d 秒後孵小雞" % ceili(HEN_BREED_SEC - lead.breed)
			elif hens >= cap:
				lb.text = t + " · 雞舍滿了，再擴建才會孵小雞"
			else:
				lb.text = t + " · 再 1 隻雞就能孵小雞"
		"pen":
			var goats := _sum(grp, "goats")
			var milk := _sum(grp, "milk")
			var cap := n * GOATS_PER_TILE
			var t := "山羊 %d/%d · 海帶 %d · 淡水 %d" % [goats, cap, lead.food, lead.water]
			if goats == 0:
				lb.text = "空的山羊圍欄 %d 格 · 每格住 1 隻" % n
			elif _scared(grp):
				lb.modulate = Color("ef5b5b")
				lb.text = t + " · 風暴中山羊躲起來了（蓋屋頂保護）"
			elif milk > 0:
				lb.text = t + " · 羊奶 %d · 點我擠" % milk
			elif lead.food <= 0 or lead.water <= 0:
				lb.modulate = Color("ef5b5b")
				lb.text = t + " · 山羊%s了，點我給" % ("餓" if lead.food <= 0 else "渴")
			elif goats >= 2 and goats < cap:
				lb.text = t + " · %d 秒後生小羊" % ceili(GOAT_BREED_SEC - lead.breed)
			elif goats >= cap and goats >= 2:
				lb.text = t + " · 圍欄滿了，擴建才會生小羊"
			else:
				lb.text = t


# ---------------------------------------------------------------- taps

func tap(o: Dictionary, pw: Vector3) -> void:
	if not g._near(o, pw, "照顧" + g.OBJ_NAME[o.kind]):
		return
	var grp := group_of(o)
	match o.kind:
		"field":
			_tap_field(o, grp)
		"kelpfarm":
			_tap_kelp(grp)
		"coop":
			_tap_coop(grp)
		"pen":
			_tap_pen(grp)
	g._refresh_inv()


func _tap_field(o: Dictionary, grp: Dictionary) -> void:
	# 1. harvest everything ripe and clear what died
	var loot := {}
	var ripe := []
	var dead := 0
	for a in grp.objs:
		for s in a.spots:
			if s.crop == "":
				continue
			if s.dead:
				dead += 1
			elif s.grow >= 1.0:
				var c: Array = g.CROPS[s.crop]
				loot[c[2]] = int(loot.get(c[2], 0)) + c[3]
				if randf() < 0.3:
					loot[c[0]] = int(loot.get(c[0], 0)) + 1
				ripe.append(s)
	if not ripe.is_empty():
		if not g._fits(loot):
			g._full_toast()
			return
		for s in ripe:
			s.crop = ""
			s.grow = 0.0
		g.S["harvested"] += ripe.size()
		g.hud.toast("收成 %d 株：" % ripe.size() + g._give(loot))
		g.sfx.play("pickup")
		return
	if dead > 0:
		for a in grp.objs:
			for s in a.spots:
				if s.dead:
					s.crop = ""
					s.dead = false
					s.grow = 0.0
		g.hud.toast("清掉 %d 株枯掉的作物" % dead)
		return
	# 2. water the driest tiles, one cup per tile
	var thirsty: Array = grp.objs.filter(func(a): return a.moist < 0.5 and a.spots.any(func(s): return s.crop != "" and not s.dead))
	thirsty.sort_custom(func(a, b): return a.moist < b.moist)
	if not thirsty.is_empty() and g.inv["water"] > 0:
		var n := mini(thirsty.size(), g.inv["water"])
		for i in n:
			thirsty[i].moist = 1.0
			thirsty[i].dry = 0.0
		g.inv["water"] -= n
		g.sfx.play("drink", null, -6.0)
		g.hud.toast("澆了 %d 杯淡水%s" % [n, ("，還有 %d 格缺水" % (thirsty.size() - n)) if thirsty.size() > n else ""])
		return
	# 3. plant the empty spots
	var empty := 0
	for a in grp.objs:
		for s in a.spots:
			if s.crop == "":
				empty += 1
	if empty > 0:
		g.set_meta("planting", o)
		g._open_sheet("plant")
		return
	if not thirsty.is_empty():
		g.hud.toast("作物要喝淡水（蒸餾杯或濾水缸裝水）")
	else:
		g.hud.toast("作物還在長，水也夠")


## Fill the group's empty spots with one crop, starting at the tile that was tapped.
func plant(o: Dictionary, crop: String) -> void:
	var seed: String = g.CROPS[crop][0]
	var have: int = 9999 if g.creative else g.inv[seed]
	if have < 1:
		g.hud.toast("沒有%s" % g.ITEMS[seed])
		return
	var order: Array = [o] + group_of(o).objs.filter(func(a): return a != o)
	var n := 0
	for a in order:
		for s in a.spots:
			if s.crop == "" and n < have:
				s.crop = crop
				s.grow = 0.0
				s.dead = false
				n += 1
	if not g.creative:
		g.inv[seed] -= n
	g._close_sheet()
	g.hud.toast("種下 %d 株%s，記得澆水" % [n, g.CROP_NAME[crop]])
	g._refresh_inv()


func _tap_kelp(grp: Dictionary) -> void:
	var kelp := _sum(grp, "kelp")
	if kelp > 0:
		if not g._fits({"kelp": kelp}):
			g._full_toast()
			return
		for a in grp.objs:
			a.kelp = 0
		g.hud.toast("收了 " + g._give({"kelp": kelp}))
		return
	var bare: Array = grp.objs.filter(func(a): return not a.planted)
	if bare.is_empty():
		g.hud.toast("海帶還在長")
		return
	var have: int = bare.size() if g.creative else mini(bare.size(), g.inv["kelp"])
	if have < 1:
		g.hud.toast("每格要 1 條海帶當種苗（戴潛水鏡去海底採）")
		return
	for i in have:
		bare[i].planted = true
	if not g.creative:
		g.inv["kelp"] -= have
	g.hud.toast("掛上 %d 條海帶種苗，每格每 60 秒長 1 條" % have)


func _tap_coop(grp: Dictionary) -> void:
	var lead: Dictionary = grp.leader
	var eggs := _sum(grp, "eggs")
	if eggs > 0:
		if not g._fits({"egg": eggs}):
			g._full_toast()
			return
		for a in grp.objs:
			a.eggs = 0
		g.S["eggs"] += eggs
		g.hud.toast("撿到 " + g._give({"egg": eggs}))
		g.sfx.play("pickup")
		return
	var room: int = grp.objs.size() * HENS_PER_TILE - _sum(grp, "hens")
	if g.inv["chicken"] > 0 and room > 0:
		var n := _add_animal(grp, "hens", HENS_PER_TILE, mini(room, g.inv["chicken"]))
		g.inv["chicken"] -= n
		g.hud.toast("放了 %d 隻雞進雞舍，記得餵海帶或種子" % n)
		return
	if _sum(grp, "hens") == 0:
		g.hud.toast("需要雞（用鉤子撈漂來的雞籠）")
		return
	var need: int = grp.objs.size() * COOP_FEED_PER_TILE - lead.food
	if need <= 0:
		g.hud.toast("飼料槽滿了" if room > 0 or g.inv["chicken"] == 0 else "雞舍滿了，再鋪一格雞舍才放得下")
		return
	var fed := {}
	for k in ["kelp", "seed_tomato", "seed_potato", "seed_melon"]:
		var take: int = mini(need, g.inv[k])
		if take > 0:
			fed[k] = take
			need -= take
	if fed.is_empty():
		g.hud.toast("沒有飼料：海帶或種子都可以")
		return
	var parts := []
	for k in fed:
		if not g.creative:
			g.inv[k] -= fed[k]
		lead.food += fed[k]
		parts.append("%s ×%d" % [g.ITEMS[k], fed[k]])
	g.hud.toast("餵了 " + "、".join(parts))


func _tap_pen(grp: Dictionary) -> void:
	var lead: Dictionary = grp.leader
	var milk := _sum(grp, "milk")
	if milk > 0:
		if not g._fits({"milk": milk}):
			g._full_toast()
			return
		for a in grp.objs:
			a.milk = 0
		g.hud.toast("擠了 " + g._give({"milk": milk}))
		g.sfx.play("drink", null, -6.0)
		return
	var room: int = grp.objs.size() * GOATS_PER_TILE - _sum(grp, "goats")
	if g.inv["goat"] > 0 and room > 0:
		var n := _add_animal(grp, "goats", GOATS_PER_TILE, mini(room, g.inv["goat"]))
		g.inv["goat"] -= n
		g.hud.toast("放了 %d 隻山羊進圍欄，記得給海帶和淡水" % n)
		return
	if _sum(grp, "goats") == 0:
		g.hud.toast("需要山羊（第三座小島上有，帶海帶去）")
		return
	var cap: int = grp.objs.size() * PEN_FEED_PER_TILE
	var food: int = mini(cap - lead.food, g.inv["kelp"])
	var water: int = mini(cap - lead.water, g.inv["water"])
	if food <= 0 and water <= 0:
		if lead.food >= cap and lead.water >= cap:
			g.hud.toast("山羊吃飽喝足了")
		else:
			g.hud.toast("山羊要吃海帶、喝淡水")
		return
	if not g.creative:
		g.inv["kelp"] -= food
	g.inv["water"] -= water
	lead.food += food
	lead.water += water
	var parts := []
	if food > 0:
		parts.append("海帶 ×%d" % food)
	if water > 0:
		parts.append("淡水 ×%d" % water)
	g.hud.toast("給了 " + "、".join(parts))


# ---------------------------------------------------------------- save / load

func save_state(o: Dictionary, e: Dictionary) -> void:
	match o.kind:
		"field":
			e["spots"] = o.spots.map(func(s): return [s.crop, s.grow, s.dead])
			e["moist"] = o.moist
			e["dry"] = o.dry
		"kelpfarm":
			for k in ["planted", "kelp", "prog"]:
				e[k] = o[k]
		"coop":
			for k in ["hens", "food", "eggs", "prog", "breed"]:
				e[k] = o[k]
		"pen":
			for k in ["goats", "food", "water", "milk", "prog", "breed"]:
				e[k] = o[k]


## e may come from an older save: a one-plant "planter", or a coop / pen with a single "animal" flag.
func load_state(o: Dictionary, e: Dictionary) -> void:
	match o.kind:
		"field":
			var sp: Array = e.get("spots", [])
			if e.has("crop"):
				sp = [[e.crop, e.get("grow", 0.0), e.get("dead", false)]]
			for i in mini(4, sp.size()):
				o.spots[i].crop = str(sp[i][0])
				o.spots[i].grow = float(sp[i][1])
				o.spots[i].dead = bool(sp[i][2])
			o.moist = float(e.get("moist", 0.0))
			o.dry = float(e.get("dry", 0.0))
		"kelpfarm":
			o.planted = bool(e.get("planted", false))
			o.kelp = int(e.get("kelp", 0))
			o.prog = float(e.get("prog", 0.0))
		"coop":
			o.hens = int(e.get("hens", 1 if e.get("animal", false) else 0))
			o.food = int(e.get("food", 0))
			o.eggs = int(e.get("eggs", 0))
			o.prog = float(e.get("prog", 0.0))
			o.breed = float(e.get("breed", 0.0))
		"pen":
			o.goats = int(e.get("goats", 1 if e.get("animal", false) else 0))
			for k in ["food", "water", "milk"]:
				o[k] = int(e.get(k, 0))
			o.prog = float(e.get("prog", 0.0))
			o.breed = float(e.get("breed", 0.0))
	dirty = true
