class_name Weather
extends RefCounted
## Clear spells, rain showers and storms, on a prototype-speed schedule.
## Rain fills rain catchers and waters open fields. A storm darkens the sky, raises the waves,
## and hurts whatever is out in the open: deck tiles at the edge of the raft, crops, animals
## (they stop laying) and the player. Anything under a roof or an upper floor is safe.

const FIRST_CLEAR := 150.0
const FIRST_STORM_AFTER := 420.0     ## no storms in the first 7 minutes
const WARN_SEC := 25.0
const STORM_TICK := 12.0

var g
var kind := "clear"                  ## "clear" | "rain" | "storm"
var t := FIRST_CLEAR                 ## seconds left in this spell
var cloud := 0.0                     ## 0 clear .. 1 black sky (eased)
var rain := 0.0                      ## 0 dry .. 1 downpour (eased)
var storm := 0.0                     ## 0 calm .. 1 full storm (eased)
var warned := false
var _next_storm := false
var _tick := STORM_TICK
var _flash := 0.0
var _bolt_t := 4.0
var _cold_warned := false
var drops: CPUParticles3D


func _init(game) -> void:
	g = game


func setup(parent: Node3D) -> void:
	drops = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.9, 1.0, 0.45)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	drops.mesh = q
	drops.amount = 450 if OS.has_feature("web") else 900
	drops.lifetime = 1.1
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drops.emission_box_extents = Vector3(16, 0.5, 16)
	drops.direction = Vector3(0.12, -1, 0.05)
	drops.spread = 3.0
	drops.gravity = Vector3(0, -9.8, 0)
	drops.initial_velocity_min = 16.0
	drops.initial_velocity_max = 20.0
	drops.local_coords = false
	drops.emitting = false
	parent.add_child(drops)


func reset() -> void:
	kind = "clear"
	t = FIRST_CLEAR
	cloud = 0.0
	rain = 0.0
	storm = 0.0
	warned = false
	_next_storm = false
	_tick = STORM_TICK
	_cold_warned = false


func name_now() -> String:
	return {"clear": "晴", "rain": "下雨", "storm": "風暴"}[kind]


func storm_on() -> bool:
	return kind == "storm" and storm > 0.5


func raining() -> bool:
	return kind != "clear" and rain > 0.3


## mirror = a friend's game: the host decides the weather (net_apply); only show it here.
func update(dt: float, centre: Vector3, mirror := false) -> void:
	if not mirror:
		_schedule(dt)
	g.ocean.storm = storm
	drops.emitting = rain > 0.08 and not (g.swim != null and g.swim.under)
	drops.global_position = centre + Vector3(0, 12, 0)
	((drops.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a = 0.5 * clampf(rain, 0.1, 1.0)
	g.sfx.set_rain(rain * (0.35 if g.swim != null and g.swim.under else 1.0), dt)
	# lightning
	_flash = maxf(0.0, _flash - dt * 4.0)
	if storm > 0.6 and not mirror:
		_bolt_t -= dt
		if _bolt_t <= 0.0:
			_bolt_t = randf_range(5.0, 12.0)
			_flash = 1.0
			g.sfx.play("thunder", null, -2.0 if randf() < 0.5 else -8.0)
	if g.paused or g.over:
		return
	if raining() and not mirror:
		_rain_effects(dt)
	if storm_on():
		if not mirror:
			_tick -= dt
			if _tick <= 0.0:
				_tick = STORM_TICK
				_storm_hit()
		_chill(dt)


func _schedule(dt: float) -> void:
	t -= dt
	if kind == "clear" and _next_storm and not warned and t <= WARN_SEC:
		warned = true
		g.hud.toast("天空暗下來了……風暴要來了！把作物和動物蓋在屋頂下")
		g.sfx.play("thunder", null, -14.0)
	if t <= 0.0:
		_advance()
	# ease toward the targets of the current spell (clouds gather before a storm)
	var tc := 0.0
	var tr := 0.0
	var ts := 0.0
	match kind:
		"rain":
			tc = 0.6
			tr = 0.75
		"storm":
			tc = 1.0
			tr = 1.0
			ts = 1.0
		_:
			if warned:
				tc = 0.8 * clampf(1.0 - t / WARN_SEC, 0.0, 1.0)
	cloud = move_toward(cloud, tc, dt * 0.12)
	rain = move_toward(rain, tr, dt * 0.25)
	storm = move_toward(storm, ts, dt * 0.1)


## Co-op: what the host sends, and how a friend's game takes it.
func net_state() -> Array:
	return [kind, snappedf(cloud, 0.01), snappedf(rain, 0.01), snappedf(storm, 0.01), snappedf(_flash, 0.05)]


func net_apply(a: Array) -> void:
	if a.size() < 5:
		return
	var k := str(a[0])
	if k != kind:
		match k:
			"rain":
				g.hud.toast("下雨了，集雨布開始接雨水")
			"storm":
				g.hud.toast("風暴來了！待在屋頂下面")
				g.sfx.play("thunder", null, 0.0)
			_:
				if kind == "storm":
					g.hud.toast("風暴過去了")
		kind = k
	cloud = float(a[1])
	rain = float(a[2])
	storm = float(a[3])
	var f := float(a[4])
	if f > _flash + 0.3:
		g.sfx.play("thunder", null, -2.0 if randf() < 0.5 else -8.0)
	_flash = maxf(_flash, f)


func _advance() -> void:
	match kind:
		"clear":
			if _next_storm:
				kind = "storm"
				t = randf_range(100.0, 140.0)
				g.hud.toast("風暴來了！待在屋頂下面")
				g.sfx.play("thunder", null, 0.0)
			else:
				kind = "rain"
				t = randf_range(75.0, 110.0)
				g.hud.toast("下雨了，集雨布開始接雨水")
		_:
			if kind == "storm":
				g.hud.toast("風暴過去了")
			kind = "clear"
			t = randf_range(220.0, 320.0)
			_next_storm = g.game_t > FIRST_STORM_AFTER - t and randf() < 0.45
			warned = false
			_cold_warned = false


# ---------------------------------------------------------------- effects

## Is this deck tile sheltered by an upper floor or a roof?
func covered(c: Vector2i) -> bool:
	return g.shelter.uppers.has(c) or g.shelter.roofs.has("%d|%d|0" % [c.x, c.y])


func _rain_effects(dt: float) -> void:
	for o in g.objs:
		match o.kind:
			"catcher":
				if not covered(o.tile.cell) and o.water < 4:
					o.prog += dt * rain
					if o.prog >= 15.0:
						o.prog = 0.0
						o.water += 1
			"field":
				if not covered(o.tile.cell) and o.spots.any(func(s): return s.crop != "" and not s.dead):
					o.moist = 1.0
					o.dry = 0.0


## Every few seconds the storm breaks something that is out in the open.
func _storm_hit() -> void:
	if g.mode == "peaceful":
		return
	# a wave smashes an exposed tile at the edge of the raft
	var exposed: Array = g._edge_tiles().filter(func(tt): return not covered(tt.cell))
	if not exposed.is_empty() and g.tiles.size() > 4:
		var tl: Dictionary = exposed[randi() % exposed.size()]
		tl.hp -= 1
		tl.shake = 0.5
		g._tint(tl)
		var w := Vector3(g.raft_pos.x + tl.cell.x * g.TILE, 0, g.raft_pos.y + tl.cell.y * g.TILE)
		g.sfx.play("splash", w, -2.0)
		g.ocean.ripple(w.x, w.z, 1.2)
		if tl.hp <= 0:
			g.hud.toast("大浪打碎了一格沒有遮蔽的地板！")
			g._remove_tile(tl)
		elif tl.hp == 1:
			g.hud.toast("大浪打在木筏邊上，那格地板快撐不住了")
	# wind flattens crops that have no roof
	for o in g.objs:
		if o.kind == "field" and not covered(o.tile.cell) and randf() < 0.35:
			var living: Array = o.spots.filter(func(s): return s.crop != "" and not s.dead)
			if not living.is_empty():
				living[randi() % living.size()].dead = true
				g.hud.toast("風暴吹倒了沒有屋頂的作物")


## Out in a storm without a roof, you slowly get chilled.
func _chill(dt: float) -> void:
	if g.creative or g.swim != null:
		return
	var c := Vector2i(roundi(g.P["x"] / g.TILE), roundi(g.P["z"] / g.TILE))
	var under: bool = covered(c) if int(g.P["level"]) == 0 else g.shelter.roofs.has("%d|%d|1" % [c.x, c.y])
	if under:
		return
	g.S["health"] -= dt * 0.4
	if not _cold_warned:
		_cold_warned = true
		g.hud.toast("淋著風暴會失溫，生命慢慢減少，躲到屋頂下！")


## Animals stop laying while a storm rages over them.
func animals_scared(c: Vector2i) -> bool:
	return storm_on() and not covered(c)


# ---------------------------------------------------------------- sky

## Darken the day/night colours the main loop just set, and flash for lightning.
func apply_sky() -> void:
	var k := cloud
	var grey := Color("5d6b78")
	g.sky_mat.sky_top_color = g.sky_mat.sky_top_color.lerp(Color("3b4651"), k * 0.85)
	g.sky_mat.sky_horizon_color = g.sky_mat.sky_horizon_color.lerp(grey, k * 0.8)
	g.sky_mat.ground_horizon_color = g.sky_mat.sky_horizon_color
	g.env.fog_light_color = g.env.fog_light_color.lerp(grey, k * 0.8)
	g.sun.light_energy *= 1.0 - 0.6 * k
	if _flash > 0.0:
		g.sun.light_energy += _flash * 2.5
		g.sky_mat.sky_top_color = g.sky_mat.sky_top_color.lerp(Color("dfe8ff"), _flash * 0.5)


func fog_extra() -> float:
	return 0.012 * cloud + 0.01 * storm


func save_state() -> Dictionary:
	return {"kind": kind, "t": t, "next_storm": _next_storm}


func load_state(d: Dictionary) -> void:
	reset()
	kind = str(d.get("kind", "clear"))
	t = float(d.get("t", FIRST_CLEAR))
	_next_storm = bool(d.get("next_storm", false))
	cloud = {"clear": 0.0, "rain": 0.6, "storm": 1.0}.get(kind, 0.0)
	rain = {"clear": 0.0, "rain": 0.75, "storm": 1.0}.get(kind, 0.0)
	storm = 1.0 if kind == "storm" else 0.0
