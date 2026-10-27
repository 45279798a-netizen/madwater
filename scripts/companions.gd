class_name Companions
extends RefCounted
## Sea companions: a seagull, a dolphin and a turtle, each tamed in its own way and each helping
## with one part of the game. Up to two follow you at a time; the rest rest in their hut on the raft.
## 親密度 (affinity, 0–100) rises when you feed them and slowly falls; higher means stronger help,
## and at 0 the animal leaves for the wild again.
##   海鷗 seagull — circles island 1; feed it raw fish 3 times. Marks debris within 40 m and
##                 fetches small pieces.
##   海豚 dolphin — plays off island 2; feed it raw fish, then swim beside it 3 times. With a
##                 韁繩柱 it pulls the raft (faster, even upwind); warns of and rams the shark.
##   海龜 turtle  — caught in a net beside the wreck; dive and cut it free (3 taps). Gives you an
##                 air bubble once per dive and points the way to the wreck.

const MAX_FOLLOW := 2
const FEED_GAIN := 12.0
const FEED_CD := 20.0
const DECAY_SEC := 20.0          ## lose 1 affinity this often (half as fast while resting)
const SPOT_RANGE := 40.0
const INFO := {
	"gull": {"name": "海鷗", "hut": "gullnest", "food": "rawfish", "skill": "標出 40 公尺內的漂流物，還會叼回小東西"},
	"dolphin": {"name": "海豚", "hut": "dolphinpost", "food": "rawfish", "skill": "蓋了韁繩柱就幫你拉船（逆風也能走），會撞開鯊魚"},
	"turtle": {"name": "海龜", "hut": "turtletank", "food": "kelp", "skill": "每次潛水吐 1 個空氣泡給你，帶你找沉船"},
}

var g
var pets := {}             ## kind -> state dict
var _marks := []           ## debris markers currently shown


func _init(game) -> void:
	g = game


func setup() -> void:
	for k in INFO:
		var node: Node3D = Models.seagull() if k == "gull" else (Models.dolphin() if k == "dolphin" else Models.turtle())
		g.add_child(node)
		pets[k] = {"kind": k, "node": node, "tamed": false, "follow": false, "aff": 0.0, "steps": 0, "cd": 0.0,
			"decay": DECAY_SEC, "t": randf() * TAU, "pos": Vector3.ZERO, "task": null, "fed_once": false, "near_t": 0.0,
			"bubble_used": false, "warned": false, "ram_cd": 0.0, "decay_fetch": 10.0}
	var net := Models.fishing_net()
	pets.turtle["net"] = net
	g.add_child(net)
	reset()


func reset() -> void:
	for k in pets:
		var p: Dictionary = pets[k]
		p.tamed = false
		p.follow = false
		p.aff = 0.0
		p.steps = 0
		p.cd = 0.0
		p.fed_once = false
		p.near_t = 0.0
		p.task = null
		p.pos = _home(k)
	pets.turtle.net.visible = true
	_clear_marks()


func any_tamed() -> bool:
	return pets.values().any(func(p): return p.tamed)


func following(k: String) -> bool:
	return pets[k].tamed and pets[k].follow


func _k_aff(k: String) -> float:
	return pets[k].aff / 100.0


## Where each wild animal lives.
func _home(k: String) -> Vector3:
	match k:
		"gull":
			var i: Dictionary = g.islands[0]
			return Vector3(i.x, 13.0, i.z)
		"dolphin":
			var i: Dictionary = g.islands[1]
			var a: float = atan2(i.z, i.x) + 0.4
			return Vector3(i.x - cos(a) * (i.r + 22.0), 0.0, i.z - sin(a) * (i.r + 22.0))
		_:
			var w: Vector3 = g.wreck_node.pos
			return Vector3(w.x + 3.0, g.seabed_h(w.x + 3.0, w.z - 2.0) + 0.35, w.z - 2.0)


func _hut(k: String):
	var objs: Array = g._objs_of(INFO[k].hut)
	return objs[0] if not objs.is_empty() else null


# ---------------------------------------------------------------- per frame

func update(dt: float, c: Dictionary) -> void:
	var t: float = g.wall_t
	for k in pets:
		var p: Dictionary = pets[k]
		p.cd = maxf(0.0, p.cd - dt)
		p.ram_cd = maxf(0.0, p.ram_cd - dt)
		if p.tamed and not g.paused:
			p.decay -= dt * (1.0 if p.follow else 0.5)
			if p.decay <= 0.0:
				p.decay = DECAY_SEC
				p.aff = maxf(0.0, p.aff - 1.0)
				if p.aff <= 0.0:
					_leave(k)
		if not p.tamed:
			_wild(k, p, dt, t)
		elif p.follow or _hut(k) == null:
			p.follow = true
			_follow(k, p, dt, t, c)
		else:
			_rest(k, p, dt, t)
	_update_marks()


func _wild(k: String, p: Dictionary, dt: float, t: float) -> void:
	var h := _home(k)
	var n: Node3D = p.node
	match k:
		"gull":
			p.t += dt * 0.45
			p.pos = h + Vector3(cos(p.t) * 6.0, sin(t * 0.7) * 0.6, sin(p.t) * 6.0)
			n.position = p.pos
			n.rotation = Vector3(0, -p.t, 0.35)
			_flap(n, t, 1.4 if fmod(t + 1.3, 7.0) < 2.5 else 1.0)
		"dolphin":
			p.t += dt * 0.35
			var q := h + Vector3(cos(p.t) * 7.0, 0, sin(p.t) * 7.0)
			p.pos = q
			_swim_dolphin(n, q, Vector3(-sin(p.t), 0, cos(p.t)), t, true)
		"turtle":
			p.pos = h
			n.position = h
			n.rotation = Vector3(0, 0.6, 0.15 * sin(t * 2.0))
			_paddle(n, t * 3.0, 0.6)
			pets.turtle.net.position = h
	n.visible = true


func _follow(k: String, p: Dictionary, dt: float, t: float, c: Dictionary) -> void:
	var n: Node3D = p.node
	var centre := Vector3(c.x, 0, c.z)
	match k:
		"gull":
			if p.task != null:
				_fetch(p, dt, t)
			else:
				p.t += dt * 0.6
				var goal := centre + Vector3(cos(p.t) * (c.r + 4.0), 7.0 + sin(t * 0.8) * 0.5, sin(p.t) * (c.r + 4.0))
				p.pos = p.pos.lerp(goal, minf(1.0, dt * 1.5))
				n.position = p.pos
				n.rotation = Vector3(0, -p.t, 0.3)
				p.decay_fetch -= dt
				if p.decay_fetch <= 0.0:
					p.decay_fetch = 35.0 - 15.0 * _k_aff("gull")
					_start_fetch(p, c)
			_flap(n, t, 1.4 if p.task != null or fmod(t, 6.0) < 2.0 else 1.0)
		"dolphin":
			var post = _hut("dolphin")
			var pulling: bool = post != null and _sails_up()
			var goal: Vector3
			var dir: Vector3
			if pulling:
				var hd := Vector2(cos(g.heading), sin(g.heading)) if not g._objs_of("helm").is_empty() else Vector2(cos(g.wind), sin(g.wind))
				goal = centre + Vector3(hd.x, 0, hd.y) * (c.r + 6.0)
				dir = Vector3(hd.x, 0, hd.y)
			else:
				p.t += dt * 0.4
				goal = centre + Vector3(cos(p.t), 0, sin(p.t)) * (c.r + 5.5)
				dir = Vector3(-sin(p.t), 0, cos(p.t))
			p.pos = p.pos.lerp(goal, minf(1.0, dt * 1.2))
			_swim_dolphin(n, p.pos, dir, t, not pulling)
			_rope(post, n if pulling else null)
		"turtle":
			if g.swim != null:
				var sp: Vector3 = g.swim.pos
				var goal := sp + Vector3(cos(t * 0.5) * 1.6, -0.4, sin(t * 0.5) * 1.6)
				p.pos = p.pos.lerp(goal, minf(1.0, dt * 1.5))
			else:
				p.t += dt * 0.25
				var goal := centre + Vector3(cos(p.t) * 2.5, g.ocean.height(centre.x, centre.z) - 1.8, sin(p.t) * 2.5)
				p.pos = p.pos.lerp(goal, minf(1.0, dt * 0.8))
			n.position = p.pos
			n.rotation = Vector3(0, -p.t + PI / 2.0 if g.swim == null else atan2(g.swim.pos.x - p.pos.x, g.swim.pos.z - p.pos.z), 0)
			_paddle(n, t * 4.0, 1.0)
			_bubble(p)
	n.visible = true


func _rest(k: String, p: Dictionary, dt: float, t: float) -> void:
	var hut: Dictionary = _hut(k)
	var n: Node3D = p.node
	var base: Vector3 = (hut.node as Node3D).global_position
	match k:
		"gull":
			n.global_position = base + Vector3(0, 1.32, 0)
			n.rotation = Vector3(0, sin(t * 0.3), 0)
			_flap(n, t, 0.0)
		"dolphin":
			p.t += dt * 0.5
			var q := base + Vector3(cos(p.t) * 3.0, 0, sin(p.t) * 3.0)
			_swim_dolphin(n, Vector3(q.x, 0, q.z), Vector3(-sin(p.t), 0, cos(p.t)), t, false)
		"turtle":
			n.global_position = base + Vector3(0, 0.32, 0)
			n.rotation = Vector3(0, t * 0.1, 0)
			_paddle(n, t * 1.5, 0.3)
	p.pos = n.global_position
	if k == "dolphin":
		_rope(null, null)


func _sails_up() -> bool:
	return g._objs_of("sail").any(func(s): return s.up)


# ---------------------------------------------------------------- animation helpers

## Gull wings: the inner half beats, the tip lags behind it; folded along the back when resting.
## Drive a loaded model's animation clip; speed 0 holds the pose. Returns false for procedural models.
func _clip(n: Node3D, clip: String, speed: float) -> bool:
	if not n.has_meta("anim"):
		return false
	var ap: AnimationPlayer = n.get_meta("anim")
	if ap.current_animation != clip and ap.has_animation(clip):
		ap.play(clip, 0.4)
	ap.speed_scale = speed
	return true


func _flap(n: Node3D, t: float, k: float) -> void:
	if _clip(n, "flap" if k >= 1.2 else ("planer" if k > 0.0 else "planer 2"), maxf(0.15, k)):
		return
	var beat := sin(t * 8.0) * 0.55 * k
	var lag := sin(t * 8.0 - 0.9) * 0.45 * k
	var fold := 0.0 if k > 0.0 else 1.0
	for side in [-1.0, 1.0]:
		var w: Node3D = n.get_node("WingL" if side < 0.0 else "WingR")
		var o: Node3D = w.get_node("OutL" if side < 0.0 else "OutR")
		w.rotation = Vector3(0, side * fold * 1.25, -side * (beat + 0.08 * k))
		o.rotation = Vector3(0, side * fold * 1.9, -side * (lag - beat) * 0.8)


func _paddle(n: Node3D, ph: float, k: float) -> void:
	if _clip(n, "Swim Cycle", 0.35 + 0.65 * k):
		return
	if n.has_node("Head"):
		var hd: Node3D = n.get_node("Head")
		hd.rotation = Vector3(sin(ph * 0.5) * 0.06 - 0.05 * k, sin(ph * 0.25) * 0.12, 0)
	for nm in ["FL", "FR", "BL", "BR"]:
		var side := -1.0 if nm.ends_with("L") else 1.0
		var off := 0.0 if nm.begins_with("F") else PI
		var f: Node3D = n.get_node(nm)
		if nm.begins_with("F"):
			# front flippers fly up and down like wings
			f.rotation = Vector3(0, side * sin(ph + 1.2) * 0.25 * k, -side * sin(ph) * 0.55 * k)
		else:
			f.rotation.y = side * sin(ph + off) * 0.5 * k


func _swim_dolphin(n: Node3D, at: Vector3, dir: Vector3, t: float, jumps: bool) -> void:
	var surf: float = g.ocean.height(at.x, at.z)
	var arc := 0.0
	if jumps:
		var ph := fmod(t * 0.35 + at.x * 0.01, 1.0)
		arc = maxf(0.0, sin(ph * TAU * 3.0)) * 1.1 if ph < 0.18 else 0.0
	var y := surf - 0.25 + sin(t * 2.2) * 0.15 + arc
	n.position = Vector3(at.x, y, at.z)
	n.rotation = Vector3(-cos(t * 2.2) * 0.25 - (0.6 * cos(fmod(t * 0.35, 1.0) * TAU * 3.0) if arc > 0.0 else 0.0), atan2(dir.x, dir.z), 0)
	n.get_node("Tail").rotation.x = sin(t * 6.0) * 0.35


## A rope from the post on the raft to the dolphin when it is pulling.
func _rope(post, dol) -> void:
	var r: MeshInstance3D = pets.dolphin.get("rope")
	if r == null:
		r = MeshInstance3D.new()
		r.mesh = Models.cyl(0.025, 0.025, 1.0, 5)
		r.material_override = Models.mat(Color("cdb68a"))
		g.add_child(r)
		pets.dolphin["rope"] = r
	if post == null or dol == null:
		r.visible = false
		return
	var a: Vector3 = (post.node as Node3D).global_position + Vector3(0, 0.9, 0)
	var b: Vector3 = (dol as Node3D).global_position + Vector3(0, 0.2, 0)
	var d := b - a
	r.visible = true
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	r.global_transform = Transform3D(Basis(x, y * d.length(), x.cross(y)), (a + b) * 0.5)


# ---------------------------------------------------------------- abilities

func _start_fetch(p: Dictionary, c: Dictionary) -> void:
	var best = null
	var bd := SPOT_RANGE
	for d in g.debris:
		if d.state != "drift" or not d.type in ["plank", "plastic", "palm", "coconut"]:
			continue
		var dist := Vector2(d.x - c.x, d.z - c.z).length()
		if dist < bd:
			bd = dist
			best = d
	if best != null and g._fits(g.DEBRIS[best.type].give):
		best.state = "gull"
		p.task = {"d": best, "phase": "out"}


func _fetch(p: Dictionary, dt: float, t: float) -> void:
	var d: Dictionary = p.task.d
	var n: Node3D = p.node
	if p.task.phase == "out":
		if not g.debris.has(d):
			p.task = null
			return
		var goal := Vector3(d.x, g.ocean.height(d.x, d.z) + 0.6, d.z)
		var to: Vector3 = goal - p.pos
		if to.length() < 0.5:
			p.task.phase = "back"
			d.node.visible = false
		else:
			p.pos += to.normalized() * minf(10.0 * dt, to.length())
			n.rotation = Vector3(0, atan2(to.x, to.z), 0.0)
	else:
		var goal: Vector3 = g.player.global_position + Vector3(0, 2.4, 0)
		var to: Vector3 = goal - p.pos
		if to.length() < 0.8:
			var give: Dictionary = g.DEBRIS[d.type].give
			if g.debris.has(d):
				g._remove_debris(d)
			if g._fits(give):
				g.hud.toast("海鷗叼回了 " + g._give(give))
				p["fetched"] = int(p.get("fetched", 0)) + 1
				g.sfx.play("pickup", null, -6.0)
				g._refresh_inv()
			p.task = null
		else:
			p.pos += to.normalized() * minf(9.0 * dt, to.length())
			n.rotation = Vector3(0, atan2(to.x, to.z), 0.0)
	n.position = p.pos


## Little markers over debris the seagull has spotted.
func _update_marks() -> void:
	if not following("gull"):
		_clear_marks()
		return
	var c: Dictionary = g._raft_center()
	for d in g.debris:
		var near: bool = d.state == "drift" and Vector2(d.x - c.x, d.z - c.z).length() < SPOT_RANGE
		var mk = d.get("mark")
		if near and mk == null:
			mk = Models.spot_marker()
			d.node.add_child(mk)
			d["mark"] = mk
			_marks.append(mk)
		if mk != null and is_instance_valid(mk):
			mk.visible = near
			mk.position.y = 1.2 + sin(g.wall_t * 3.0 + d.seed) * 0.15
	_marks = _marks.filter(func(m): return is_instance_valid(m))


func _clear_marks() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.visible = false


func _bubble(p: Dictionary) -> void:
	if g.swim == null or not g.swim.under:
		p.bubble_used = false
		return
	if not p.bubble_used and g.swim.o2 < g._o2_max() * 0.4:
		p.bubble_used = true
		var add := 10.0 + 10.0 * _k_aff("turtle")
		g.swim.o2 = minf(g._o2_max() + add, g.swim.o2 + add)
		g.hud.toast("海龜吐了一個空氣泡給你：氧氣 +%d 秒" % roundi(add))
		g.sfx.play("splash_small", null, -10.0)


## Seen from the update loop: warn when the shark turns toward the raft.
func shark_watch() -> void:
	if not following("dolphin"):
		return
	var st: String = g.shark.state
	var p: Dictionary = pets.dolphin
	if st in ["approach", "hunt"] and not p.warned:
		p.warned = true
		g.hud.toast("海豚在叫：鯊魚要來了！")
	elif st in ["circle", "flee"]:
		p.warned = false


## Called when the shark starts to bite. Returns true if the dolphin drove it off.
func shark_bite() -> bool:
	if not following("dolphin") or pets.dolphin.ram_cd > 0.0:
		return false
	pets.dolphin.ram_cd = 60.0
	if randf() < 0.35 + 0.4 * _k_aff("dolphin"):
		g.hud.toast("海豚衝過去撞開了鯊魚！")
		g.sfx.play("splash", Vector3(g.shark.x, 0, g.shark.z))
		return true
	return false


func pull() -> float:
	return (1.2 + 0.2 * _k_aff("dolphin")) if following("dolphin") and _hut("dolphin") != null else 1.0


func upwind() -> float:
	return (0.4 + 0.2 * _k_aff("dolphin")) if following("dolphin") and _hut("dolphin") != null else 0.0


func nav_hint(c: Dictionary) -> String:
	if following("turtle") and g.swim != null and not g.wreck_node.used:
		var w: Vector3 = g.wreck_node.pos
		return "海龜：沉船 %s %d m" % [g._arrow_to(w.x - g.swim.pos.x, w.z - g.swim.pos.z), roundi(Vector2(w.x - g.swim.pos.x, w.z - g.swim.pos.z).length())]
	if following("gull"):
		var n := 0
		for d in g.debris:
			if d.state == "drift" and Vector2(d.x - c.x, d.z - c.z).length() < SPOT_RANGE:
				n += 1
		return "海鷗：附近 %d 個漂流物" % n
	return ""


# ---------------------------------------------------------------- taming & caring

func pick_cands(swimming: bool) -> Array:
	var out := []
	for k in pets:
		var p: Dictionary = pets[k]
		var n: Node3D = p.node
		if not n.visible:
			continue
		if k == "turtle" and not p.tamed and not swimming:
			continue
		out.append(["companion", k, n.global_position + Vector3(0, 0.2, 0), 2.2 if k == "gull" else 1.6])
	return out


func tap(k: String, pw: Vector3) -> void:
	var p: Dictionary = pets[k]
	var n: Node3D = p.node
	var dist := Vector2(pw.x - n.global_position.x, pw.z - n.global_position.z).length()
	if p.tamed:
		if dist > 14.0:
			g.hud.toast("%s離太遠了" % INFO[k].name)
			return
		feed(k)
		return
	match k:
		"gull":
			if dist > 24.0:
				g.hud.toast("海鷗在小島上空盤旋，把木筏開近一點")
				return
			if p.cd > 0.0:
				g.hud.toast("海鷗剛吃飽，%d 秒後再餵（%d/3）" % [ceili(p.cd), p.steps])
				return
			if g.inv["rawfish"] < 1:
				g.hud.toast("海鷗想吃生魚")
				return
			g.inv["rawfish"] -= 1
			p.steps += 1
			p.cd = 30.0
			if p.steps >= 3:
				_tame(k)
			else:
				g.hud.toast("海鷗吃了生魚（%d/3），過一會兒再來餵" % p.steps)
		"dolphin":
			if not p.fed_once:
				if dist > 20.0:
					g.hud.toast("把木筏開近海豚一點")
					return
				if g.inv["rawfish"] < 1:
					g.hud.toast("海豚想吃生魚")
					return
				g.inv["rawfish"] -= 1
				p.fed_once = true
				g.hud.toast("海豚吃了生魚！下水陪牠游，靠近牠游 3 次")
			else:
				g.hud.toast("下水游到海豚旁邊陪牠玩（%d/3）" % p.steps)
		"turtle":
			if g.swim == null or dist > 3.5:
				g.hud.toast("游近一點才能解開漁網")
				return
			if g.inv["goggles"] < 1:
				g.hud.toast("水裡太模糊了，需要潛水鏡")
				return
			p.steps += 1
			g.sfx.play("reel", null, -6.0)
			if p.steps >= 3:
				pets.turtle.net.visible = false
				_tame(k)
			else:
				g.hud.toast("扯斷了一段漁網（%d/3）" % p.steps)
	g._refresh_inv()


## While swimming, being near the dolphin you fed counts as playing with it.
func swim_tick(dt: float) -> void:
	var p: Dictionary = pets.dolphin
	if p.tamed or not p.fed_once or g.swim == null:
		return
	var n: Node3D = p.node
	if Vector2(g.swim.pos.x - n.global_position.x, g.swim.pos.z - n.global_position.z).length() < 6.0:
		p.near_t += dt
		if p.near_t >= 6.0:
			p.near_t = 0.0
			p.steps += 1
			if p.steps >= 3:
				_tame("dolphin")
			else:
				g.hud.toast("海豚跟你一起游（%d/3）" % p.steps)
				g.sfx.play("splash_small", null, -6.0)


func _tame(k: String) -> void:
	var p: Dictionary = pets[k]
	p.tamed = true
	p.aff = 30.0
	p.decay = DECAY_SEC
	p.steps = 0
	var n_follow := pets.values().filter(func(q): return q.tamed and q.follow).size()
	p.follow = n_follow < MAX_FOLLOW or _hut(k) == null
	g.S["pets"] += 1
	var hut_name: String = g.OBJ_NAME[INFO[k].hut]
	g.hud.toast("%s成為你的夥伴了！%s。可以蓋%s給牠住" % [INFO[k].name, INFO[k].skill, hut_name])
	g.sfx.play("catch")
	g._refresh_inv()


func feed(k: String) -> void:
	var p: Dictionary = pets[k]
	var food: String = INFO[k].food
	if p.cd > 0.0:
		g.hud.toast("%s還不餓（%d 秒）" % [INFO[k].name, ceili(p.cd)])
		return
	if g.inv[food] < 1:
		g.hud.toast("%s想吃%s" % [INFO[k].name, g.ITEMS[food]])
		return
	g.inv[food] -= 1
	p.aff = minf(100.0, p.aff + FEED_GAIN)
	p.cd = FEED_CD
	g.hud.toast("餵了%s，親密度 %d" % [INFO[k].name, roundi(p.aff)])
	g.sfx.play("eat", null, -6.0)
	g._refresh_inv()


func _leave(k: String) -> void:
	var p: Dictionary = pets[k]
	p.tamed = false
	p.follow = false
	p.steps = 0
	p.fed_once = false
	p.task = null
	if k == "turtle":
		pets.turtle.net.visible = false
	g.hud.toast("%s太久沒人餵，回到海裡去了" % INFO[k].name)


func set_follow(k: String, on: bool) -> void:
	var p: Dictionary = pets[k]
	if not p.tamed:
		return
	if on:
		var n := pets.values().filter(func(q): return q.tamed and q.follow).size()
		if n >= MAX_FOLLOW:
			g.hud.toast("最多帶 %d 隻夥伴，先讓一隻回小屋休息" % MAX_FOLLOW)
			return
		p.follow = true
		g.hud.toast("%s跟著你了" % INFO[k].name)
	else:
		if _hut(k) == null:
			g.hud.toast("先蓋%s，牠才有地方休息" % g.OBJ_NAME[INFO[k].hut])
			return
		p.follow = false
		p.task = null
		g.hud.toast("%s回小屋休息了" % INFO[k].name)


func sheet_rows() -> Array:
	var rows := []
	for k in pets:
		var p: Dictionary = pets[k]
		if not p.tamed:
			continue
		var where := "跟著你" if p.follow else "在小屋休息"
		rows.append({"id": "pet_feed:" + k, "name": "%s · 親密度 %d · %s" % [INFO[k].name, roundi(p.aff), where], "desc": INFO[k].skill,
			"cost_text": "餵%s 1 個" % g.ITEMS[INFO[k].food], "ok": g.inv[INFO[k].food] > 0 and p.cd <= 0.0, "label": "餵"})
		rows.append({"id": "pet_follow:" + k, "name": "", "desc": "親密度越高幫得越多；太久不餵會降，降到 0 會離開", "cost_text": "",
			"ok": true, "label": "回小屋" if p.follow else "帶著"})
	return rows


func sheet_action(id: String) -> void:
	if id.begins_with("pet_feed:"):
		feed(id.substr(9))
	elif id.begins_with("pet_follow:"):
		var k := id.substr(11)
		set_follow(k, not pets[k].follow)


# ---------------------------------------------------------------- save / load

func save_state() -> Dictionary:
	var out := {}
	for k in pets:
		var p: Dictionary = pets[k]
		out[k] = {"tamed": p.tamed, "follow": p.follow, "aff": p.aff, "steps": p.steps, "fed_once": p.fed_once}
	return out


func load_state(d: Dictionary) -> void:
	reset()
	for k in d:
		if not pets.has(k):
			continue
		var p: Dictionary = pets[k]
		var s: Dictionary = d[k]
		p.tamed = bool(s.get("tamed", false))
		p.follow = bool(s.get("follow", false))
		p.aff = float(s.get("aff", 0.0))
		p.steps = int(s.get("steps", 0))
		p.fed_once = bool(s.get("fed_once", false))
	pets.turtle.net.visible = not pets.turtle.tamed


# ---------------------------------------------------------------- co-op

## Host -> friends, ten times a second: where each animal is.
func net_fast() -> Dictionary:
	var out := {}
	for k in pets:
		var n: Node3D = pets[k].node
		out[k] = [snappedf(n.position.x, 0.02), snappedf(n.position.y, 0.02), snappedf(n.position.z, 0.02),
			snappedf(n.rotation.x, 0.01), snappedf(n.rotation.y, 0.01), snappedf(n.rotation.z, 0.01), 1 if n.visible else 0]
	return out


func net_apply(d: Dictionary) -> void:
	for k in d:
		if pets.has(k) and typeof(d[k]) == TYPE_ARRAY and d[k].size() >= 7:
			var a: Array = d[k]
			pets[k]["nt"] = Vector3(float(a[0]), float(a[1]), float(a[2]))
			pets[k]["nr"] = Vector3(float(a[3]), float(a[4]), float(a[5]))
			pets[k].node.visible = int(a[6]) == 1


## A friend's game: glide the animals to where the host has them and keep them animated.
func net_tick(dt: float) -> void:
	var t: float = g.wall_t
	for k in pets:
		var p: Dictionary = pets[k]
		if not p.has("nt"):
			continue
		var n: Node3D = p.node
		var before := n.position
		n.position = n.position.lerp(p.nt, minf(1.0, dt * 8.0)) if n.position.distance_to(p.nt) < 12.0 else p.nt
		var r: Vector3 = p.nr
		n.rotation = Vector3(lerp_angle(n.rotation.x, r.x, minf(1.0, dt * 8.0)), lerp_angle(n.rotation.y, r.y, minf(1.0, dt * 8.0)),
			lerp_angle(n.rotation.z, r.z, minf(1.0, dt * 8.0)))
		var speed := n.position.distance_to(before) / maxf(dt, 0.001)
		match k:
			"gull":
				_flap(n, t, 1.4 if speed > 4.0 else (1.0 if speed > 0.3 else 0.0))
			"turtle":
				_paddle(n, t * 3.0, clampf(speed / 2.0, 0.3, 1.0))
				if not p.tamed:
					pets.turtle.net.position = n.position


## The shared taming state, without resetting where the animals are.
func net_load(d: Dictionary) -> void:
	for k in d:
		if not pets.has(k) or typeof(d[k]) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = pets[k]
		var s: Dictionary = d[k]
		p.tamed = bool(s.get("tamed", false))
		p.follow = bool(s.get("follow", false))
		p.aff = float(s.get("aff", 0.0))
		p.steps = int(s.get("steps", 0))
		p.fed_once = bool(s.get("fed_once", false))
	pets.turtle.net.visible = not pets.turtle.tamed
