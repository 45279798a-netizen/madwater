class_name Traders
extends RefCounted
## Drifting trade boats. Every few minutes one sails up, stays beside the raft for a while, then
## leaves. Trades are paid in 貝殼幣 (shell coins): sell what you make, buy what you can't find.
## Flooding a boat with one good lowers its price (it recovers over time); every trade builds that
## boat's 交情 (rapport), which brings a discount and, at the top level, a hidden item.

const STAY_SEC := 210.0          ## how long a boat waits beside the raft
const SPEED := 4.0               ## m/s while arriving / leaving
const REACH := 18.0              ## how close the player must be to trade
const REP_LEVELS := [0, 8, 20]   ## trades needed for each 交情 level
const REP_NAME := ["初次見面", "熟客", "老朋友"]
const DISCOUNT := [0.0, 0.1, 0.2]

## sells / hidden: [item, amount, price]
const BOATS := {
	"fisher": {
		"name": "老漁夫的舢舨", "first": 120.0, "every": 300.0,
		"buys": {"rawfish": 3, "cooked": 5, "rope": 2},
		"sells": [["seed_tomato", 2, 6], ["seed_potato", 2, 6], ["bait", 3, 4], ["rod2", 1, 25]],
		"hidden": [["seed_melon", 1, 10]],
		"hello": "老漁夫的舢舨靠過來了：「有魚嗎？我拿種子跟你換。」",
	},
	"water": {
		"name": "水商「藍桶」", "first": 360.0, "every": 420.0,
		"buys": {"water": 4, "tjuice": 5, "mjuice": 7, "milk": 6},
		"sells": [["cup", 1, 5], ["clay", 3, 6], ["sand", 3, 4], ["plastic", 3, 5], ["ingot", 2, 9]],
		"hidden": [["goggles", 1, 15]],
		"hello": "水商「藍桶」的船靠過來了：「淡水我全收！」",
	},
	"ark": {
		"name": "動物船「諾亞號」", "first": 540.0, "every": 480.0,
		"buys": {"potato": 2, "tomato": 2, "melon": 8, "egg": 3, "bpotato": 3, "fegg": 4},
		"sells": [["chicken", 1, 12], ["goat", 1, 28], ["seed_melon", 2, 8], ["kelp", 4, 6]],
		"hidden": [["chicken", 2, 18]],
		"hello": "動物船「諾亞號」來了！船上咯咯叫、咩咩叫。",
	},
}
const ONCE := ["rod2", "goggles"]          ## tools you only ever need one of
const NOTE := {"bait": "下次拋竿魚上鉤快一倍", "rod2": "魚上鉤更快，收竿時間更長", "goggles": "潛水看得清楚，能挖海底"}

var g                       ## the main game script
var timers := {}            ## boat -> seconds until its next visit
var rep := {}               ## boat -> trades done
var sold := {}              ## boat -> {item: how many sold recently}
var boat = null             ## the visiting boat, or null
var _decay := 0.0


func _init(game) -> void:
	g = game
	reset()


func reset() -> void:
	for k in BOATS:
		timers[k] = BOATS[k].first
		rep[k] = 0
		sold[k] = {}
	_remove_boat()


func level(kind: String) -> int:
	var lv := 0
	for i in REP_LEVELS.size():
		if rep[kind] >= REP_LEVELS[i]:
			lv = i
	return lv


func sell_price(kind: String, item: String) -> int:
	var base: int = BOATS[kind].buys[item]
	var n: int = sold[kind].get(item, 0)
	return maxi(1, roundi(base * maxf(0.4, 1.0 - 0.08 * n)))


func buy_price(kind: String, price: int) -> int:
	return maxi(1, roundi(price * (1.0 - DISCOUNT[level(kind)])))


func _offers(kind: String) -> Array:
	var b: Dictionary = BOATS[kind]
	return b.sells + (b.hidden if level(kind) >= 2 else [])


# ---------------------------------------------------------------- the boat on the water

func update(dt: float, c: Dictionary) -> void:
	_decay += dt
	if _decay >= 30.0:
		_decay = 0.0
		for k in sold:
			for item in sold[k].keys():
				sold[k][item] = maxi(0, sold[k][item] - 1)
	if boat == null:
		for k in BOATS:
			timers[k] -= dt
		for k in BOATS:
			if timers[k] <= 0.0:
				timers[k] = BOATS[k].every * randf_range(0.9, 1.1)
				_spawn(k, c)
				break
		return
	var centre := Vector2(c.x, c.z)
	var pos := Vector2(boat.x, boat.z)
	var dock: Vector2 = centre + boat.dir * (c.r + 7.0)
	var face: Vector2 = Vector2(-boat.dir.y, boat.dir.x)   # side-on to the raft while docked
	match boat.state:
		"arrive":
			var to := dock - pos
			if to.length() < 0.6:
				boat.state = "stay"
				boat.t = STAY_SEC
			else:
				pos += to.normalized() * minf(SPEED * dt, to.length())
				face = to.normalized()
		"stay":
			pos = pos.lerp(dock, minf(1.0, dt * 2.0))   # keeps up when the raft sails
			boat.t -= dt
			if boat.t <= 30.0 and not boat.warned:
				boat.warned = true
				g.hud.toast("%s 30 秒後要開走了" % BOATS[boat.kind].name)
			if boat.t <= 0.0:
				boat.state = "leave"
				g.hud.toast("%s 開走了" % BOATS[boat.kind].name)
				if g.sheet_mode == "trade":
					g._close_sheet()
		"leave":
			pos += boat.dir * SPEED * dt
			face = boat.dir
			if pos.distance_to(centre) > 95.0:
				_remove_boat()
				return
	boat.x = pos.x
	boat.z = pos.y
	_show_boat(dt, face)


func _show_boat(dt: float, face: Vector2) -> void:
	var pos := Vector2(boat.x, boat.z)
	var n: Node3D = boat.node
	n.position = Vector3(pos.x, g.ocean.height(pos.x, pos.y) - 0.05 + sin(g.wall_t * 1.3) * 0.04, pos.y)
	boat.yaw = lerp_angle(boat.yaw, atan2(face.x, face.y), minf(1.0, dt * 2.0))
	n.rotation = Vector3(sin(g.wall_t * 0.9) * 0.03, boat.yaw, sin(g.wall_t * 1.1) * 0.04)
	var lb: Label3D = boat.label
	var bname: String = BOATS[boat.kind].name
	match boat.state:
		"arrive":
			lb.text = "%s 靠過來了" % bname
		"stay":
			lb.text = "%s · 點我交易 · %d:%02d 後離開" % [bname, int(boat.t / 60.0), int(fmod(boat.t, 60.0))]
		_:
			lb.text = bname


func _spawn(kind: String, c: Dictionary) -> void:
	var a := randf() * TAU
	var dir := Vector2(cos(a), sin(a))
	_make_boat(kind, dir, c.x + dir.x * 75.0, c.z + dir.y * 75.0)
	g.hud.toast(BOATS[kind].hello)
	g.sfx.play("whoosh", null, -6.0)


func _make_boat(kind: String, dir: Vector2, x: float, z: float) -> void:
	var node := Models.trade_boat(kind)
	g.add_child(node)
	var lb: Label3D = g._label3d(node)
	lb.position.y = 5.6 if kind == "ark" else 4.0
	lb.pixel_size = 0.013
	lb.modulate = Color("ffd27a")
	boat = {"kind": kind, "node": node, "label": lb, "state": "arrive", "dir": dir, "t": 0.0, "warned": false,
		"x": x, "z": z, "yaw": atan2(-dir.x, -dir.y)}


func _remove_boat() -> void:
	if boat != null:
		boat.node.queue_free()
	boat = null


## Where the nav line should point, or null.
func nav_target():
	if boat == null or boat.state == "leave":
		return null
	return Vector2(boat.x, boat.z)


# ---------------------------------------------------------------- trading

func tap(pw: Vector3) -> void:
	if boat == null:
		return
	if g._flat(pw, boat.x, boat.z) > REACH:
		g.hud.toast("再靠近商船一點")
		return
	if boat.state == "arrive":
		g.hud.toast("等船靠過來再交易")
		return
	if boat.state == "leave":
		g.hud.toast("商船已經要走了")
		return
	g._open_sheet("trade")


func sheet() -> Array:
	var kind: String = boat.kind
	var b: Dictionary = BOATS[kind]
	var rows := []
	rows.append({"id": "", "name": "賣給他", "desc": "價錢會跟著你賣的數量變低，過一陣子會回升", "cost_text": "", "ok": false, "label": ""})
	for item in b.buys:
		var p := sell_price(kind, item)
		var have: int = g.inv[item]
		rows.append({"id": "sell:" + item, "name": g.ITEMS[item], "desc": "你有 %d 個%s" % [have, "（收太多了，價錢變低）" if p < b.buys[item] else ""],
			"cost_text": "每個 %d 貝殼幣" % p, "ok": have > 0, "label": "賣 1"})
	var lv := level(kind)
	rows.append({"id": "", "name": "跟他買", "desc": ("交情%s：全部打 %d 折" % [REP_NAME[lv], roundi((1.0 - DISCOUNT[lv]) * 10)]) if lv > 0 else "多交易幾次，交情變好就會打折", "cost_text": "", "ok": false, "label": ""})
	for i in _offers(kind).size():
		var o: Array = _offers(kind)[i]
		var item: String = o[0]
		var cost := buy_price(kind, o[2])
		var owned: bool = item in ONCE and g.inv[item] > 0
		var hidden: bool = i >= b.sells.size()
		rows.append({"id": "buy:%d" % i, "name": "%s ×%d%s" % [g.ITEMS[item], o[1], "（私藏）" if hidden else ""],
			"desc": "已經有了" if owned else NOTE.get(item, ""), "cost_text": "%d 貝殼幣" % cost,
			"ok": not owned and (g.creative or g.inv["shell"] >= cost), "label": "買"})
	return rows


func title() -> String:
	var kind: String = boat.kind
	return "%s · 貝殼幣 %d · 交情：%s" % [BOATS[kind].name, g.inv["shell"], REP_NAME[level(kind)]]


func trade(id: String) -> void:
	if boat == null or boat.state != "stay":
		return
	var kind: String = boat.kind
	var before := level(kind)
	if id.begins_with("sell:"):
		var item := id.substr(5)
		if g.inv[item] < 1:
			return
		var p := sell_price(kind, item)
		g.inv[item] -= 1
		g.inv["shell"] += p
		sold[kind][item] = int(sold[kind].get(item, 0)) + 1
		g.hud.toast("賣掉 1 個%s，得到 %d 貝殼幣" % [g.ITEMS[item], p])
	elif id.begins_with("buy:"):
		var offers := _offers(kind)
		var i := id.substr(4).to_int()
		if i < 0 or i >= offers.size():
			return
		var o: Array = offers[i]
		var cost := buy_price(kind, o[2])
		if o[0] in ONCE and g.inv[o[0]] > 0:
			return
		if not g.creative and g.inv["shell"] < cost:
			g.hud.toast("貝殼幣不夠（要 %d）" % cost)
			return
		if not g._fits({o[0]: o[1]}):
			g._full_toast()
			return
		if not g.creative:
			g.inv["shell"] -= cost
		g.hud.toast("買到 " + g._give({o[0]: o[1]}))
	else:
		return
	rep[kind] += 1
	g.S["trades"] += 1
	g.sfx.play("pickup", null, -4.0)
	var after := level(kind)
	if after > before:
		g.hud.toast("跟%s的交情變成「%s」了！買東西打 %d 折%s" % [BOATS[kind].name, REP_NAME[after], roundi((1.0 - DISCOUNT[after]) * 10),
			"，還拿出了私藏的貨" if after >= 2 else ""])
	g._refresh_inv()
	g._open_sheet("trade")


# ---------------------------------------------------------------- save / load

func save_state() -> Dictionary:
	return {"timers": timers.duplicate(), "rep": rep.duplicate()}


# ---------------------------------------------------------------- co-op

## The shared part (rapport and recent sales); visit timers stay with the host.
func net_state() -> Dictionary:
	return {"rep": rep.duplicate(), "sold": sold.duplicate(true)}


func net_load(d: Dictionary) -> void:
	for k in d.get("rep", {}):
		if rep.has(k):
			rep[k] = int(d.rep[k])
	var sd = d.get("sold", {})
	if typeof(sd) == TYPE_DICTIONARY:
		for k in sd:
			if sold.has(k) and typeof(sd[k]) == TYPE_DICTIONARY:
				sold[k] = {}
				for item in sd[k]:
					sold[k][item] = int(sd[k][item])


## Host -> friends: where the visiting boat is.
func net_fast():
	if boat == null:
		return null
	return [boat.kind, snappedf(boat.x, 0.05), snappedf(boat.z, 0.05), snappedf(boat.yaw, 0.01), boat.state, snappedf(boat.t, 1.0), boat.dir.x, boat.dir.y]


func net_apply(a) -> void:
	if typeof(a) != TYPE_ARRAY or a.size() < 8:
		if boat != null:
			_remove_boat()
			if g.sheet_mode == "trade":
				g._close_sheet()
		return
	var kind := str(a[0])
	if not BOATS.has(kind):
		return
	if boat == null or boat.kind != kind:
		_remove_boat()
		_make_boat(kind, Vector2(float(a[6]), float(a[7])), float(a[1]), float(a[2]))
		g.hud.toast(BOATS[kind].hello)
	boat["tx"] = float(a[1])
	boat["tz"] = float(a[2])
	boat["tyaw"] = float(a[3])
	boat.state = str(a[4])
	boat.t = float(a[5])


func net_tick(dt: float, _c: Dictionary) -> void:
	if boat == null or not boat.has("tx"):
		return
	boat.x = lerpf(boat.x, boat.tx, minf(1.0, dt * 5.0))
	boat.z = lerpf(boat.z, boat.tz, minf(1.0, dt * 5.0))
	boat.t = maxf(0.0, boat.t - dt)
	var yaw: float = boat.tyaw
	_show_boat(dt, Vector2(sin(yaw), cos(yaw)))


func load_state(d: Dictionary) -> void:
	reset()
	for k in d.get("timers", {}):
		if timers.has(k):
			timers[k] = float(d.timers[k])
	for k in d.get("rep", {}):
		if rep.has(k):
			rep[k] = int(d.rep[k])
