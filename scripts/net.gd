class_name Net
extends RefCounted
## Co-op: play with friends who have the same game page open.
##
## The page's "room" (see tools/mwnet.js) reaches everyone viewing it right now. One player
## HOSTS: their game runs the world (sea, raft sailing, debris, shark, weather, farms, devices).
## Friends JOIN: their game mirrors that world and only simulates their own castaway (moving,
## swimming, thirst / hunger, their own backpack). Everything is plain JSON:
##
##   presence, 10 Hz, every player   {"r": "host"|"client", "pl": pose, "v": world version,
##                                     "w": fast world state (host only: raft, shark, debris...)}
##   topic "w"  host -> everyone      world patch  {"v", "full", "e": {entity key: value | null}}
##   topic "a"  client -> host        the entities the client just changed, or {"ev": event}
##   topic "j"  client -> host        "send me the whole world"
##   topic "x"  host -> one client    {"to": peer, "ev": event}  (e.g. the shark bit you)
##
## World entities are the same pieces the save file stores (a tile, a device, the shelter, the
## islands...). Each side remembers the last value everyone agreed on and sends only what changed.
## Messages are capped at 4 KB, so bigger payloads travel as base64 chunks.

const TICK := 0.1                 ## presence rate
const HOST_DIFF := 0.5
const CLIENT_DIFF := 0.25
const CHUNK := 2800
const COLORS := [Color("3b8fe8"), Color("5fbf4a"), Color("b05fd8"), Color("e8c23b"), Color("e85b8f"), Color("3bd0c8")]

var g
var tr                            ## transport: JSTransport (web page) or LoopTransport (tests)
var role := "solo"                ## "solo" | "host" | "client"
var code := ""
var me := ""
var host_peer := ""
var peers := {}                   ## peer -> {"name", "p" (their game presence), "av" (avatar)}
var rooms := []                   ## lobby: [{"code", "name", "n", "peer"}]
var version := 0
var synced := false               ## client: has the first full world arrived?
var base := {}                    ## entity key -> JSON text everyone agreed on
var last_err := ""
var nick := ""                    ## shown over my castaway when the platform has no name for me
var _pres_t := 0.0
var _diff_t := 0.0
var _ask_t := 0.0
var _behind_t := 0.0
var _gone_t := 0.0
var _steer_t := 0.0
var _chunks := {}
var _msg := 0
var _rooms_key := ""


const NICKS := ["海豚", "章魚", "海龜", "海星", "鯨魚", "水母", "螃蟹", "飛魚", "海獺", "企鵝", "海馬", "魟魚"]


func _init(game) -> void:
	g = game
	tr = make_transport()
	nick = "%s%d" % [NICKS[randi() % NICKS.size()], randi_range(1, 99)]


## "room" (inside Claude: rooms are listed), "peer" (elsewhere: type a code), "mock", or "".
func kind() -> String:
	return tr.kind() if tr != null else ""


static func make_transport():
	if OS.has_feature("web"):
		var t := JSTransport.new()
		if t.ok():
			return t
	return null


func available() -> bool:
	return tr != null and tr.available()


func is_host() -> bool:
	return role == "host"


func is_client() -> bool:
	return role == "client"


func in_room() -> bool:
	return role != "solo"


func player_count() -> int:
	return 1 + peers.size()


func host_name() -> String:
	if is_host():
		return "你"
	return peers[host_peer].name if peers.has(host_peer) else "房主"


# ---------------------------------------------------------------- room lifecycle

static func new_code() -> String:
	return "%04d" % randi_range(1000, 9999)


func host(c: String) -> void:
	if tr == null:
		return
	code = c
	role = "host"
	synced = true
	version = 0
	host_peer = tr.me()
	tr.join("mw-" + code, "host")
	tr.lobby({"mw": code})
	base = _serialize(g.world_entities())
	_pres_t = 0.0


func join(c: String) -> void:
	if tr == null:
		return
	code = c
	role = "client"
	synced = false
	version = 0
	host_peer = ""
	tr.join("mw-" + code, "client")
	_ask_t = 0.5


func leave() -> void:
	if tr != null and role == "host":
		tr.emit("x", {"to": "*", "ev": {"e": "closed"}})
	if tr != null and role != "solo":
		tr.leave()
		tr.lobby({"mw": null})
	for p in peers.values():
		_drop_avatar(p)
	peers.clear()
	role = "solo"
	code = ""
	synced = false
	host_peer = ""
	_chunks.clear()


# ---------------------------------------------------------------- per frame

func update(dt: float) -> void:
	if tr == null:
		return
	var res: Dictionary = tr.poll()
	if me == "":
		me = tr.me()
	if res.has("lobby"):
		_on_lobby(res.lobby)
	for ev in res.get("ev", []):
		_on_event(ev)
	if res.has("peers"):
		_on_peers(res.peers)
	if role == "solo":
		return
	_pres_t -= dt
	if _pres_t <= 0.0:
		_pres_t = TICK
		var pr := {"r": role, "pl": g.net_pose(), "v": version, "n": nick}
		if is_host():
			pr["w"] = g.net_fast()
		tr.presence(pr)
	_diff_t -= dt
	if is_host():
		if _diff_t <= 0.0:
			_diff_t = HOST_DIFF
			var patch := _diff()
			if not patch.is_empty():
				version += 1
				_send("w", {"v": version, "e": patch})
	else:
		if not synced:
			_ask_t -= dt
			if _ask_t <= 0.0:
				_ask_t = 3.0
				tr.emit("j", {"want": 1})
		else:
			if _diff_t <= 0.0:
				flush()
			# missed a patch? ask for the whole world again
			var hv := int(peers[host_peer].p.get("v", 0)) if peers.has(host_peer) else version
			_behind_t = (_behind_t + dt) if hv > version else 0.0
			if _behind_t > 2.5:
				_behind_t = -5.0
				tr.emit("j", {"want": 1})
			# the host left
			_gone_t = (_gone_t + dt) if not peers.has(host_peer) else 0.0
			if _gone_t > 4.0:
				_gone_t = 0.0
				g.net_host_left()
				return
		if g.steer != null:
			_steer_t -= dt
			if _steer_t <= 0.0:
				_steer_t = 0.2
				event({"a": "heading", "h": snappedf(g.heading, 0.001)})
	_tick_avatars(dt)
	var now := Time.get_ticks_msec()
	for id in _chunks.keys():
		if now - int(_chunks[id].t) > 8000:
			_chunks.erase(id)


## Client: send the entities this player just changed (call right after an action).
func flush() -> void:
	if not is_client() or not synced:
		return
	_diff_t = CLIENT_DIFF
	var patch := _diff()
	if not patch.is_empty():
		_send("a", {"e": patch})


## Client -> host: a one-off event (claimed a piece of debris, hit the shark...).
func event(ev: Dictionary) -> void:
	if is_client():
		tr.emit("a", {"ev": ev, "to": host_peer})


## Host -> one client.
func send_to(peer: String, ev: Dictionary) -> void:
	if is_host():
		tr.emit("x", {"to": peer, "ev": ev})


## Host: everyone else who is swimming right now: [{"peer", "pos"}].
func remote_swimmers() -> Array:
	var out := []
	for k in peers:
		var pl: Array = peers[k].p.get("pl", [])
		if pl.size() >= 4 and int(pl[0]) == 1:
			out.append({"peer": k, "pos": Vector3(float(pl[1]), float(pl[2]), float(pl[3]))})
	return out


# ---------------------------------------------------------------- incoming

func _on_event(ev: Dictionary) -> void:
	match str(ev.get("k", "")):
		"joined":
			if bool(ev.get("ok", false)):
				if is_host():
					host_peer = tr.me()
			else:
				last_err = str(ev.get("code", ""))
				if last_err == "taken" and is_host():
					# someone else already has this room code: pick another
					var keep := version
					host(new_code())
					version = keep
					g.net_code_changed()
				else:
					g.net_failed(last_err)
		"err":
			last_err = str(ev.get("code", ""))
			if last_err == "not_permitted":
				g.net_failed(last_err)
		"msg":
			if bool(ev.get("me", false)) or typeof(ev.get("data")) != TYPE_DICTIONARY:
				return
			var data: Dictionary = ev.data
			var from: String = str(ev.get("peer", ""))
			match str(ev.get("topic", "")):
				"w":
					if is_client() and (host_peer == "" or from == host_peer):
						var p = _assemble(data, from)
						if p != null:
							if host_peer == "":
								host_peer = from
							_on_world(p)
				"a":
					if is_host():
						if data.has("ev"):
							if str(data.get("to", me)) == me:
								g.net_client_event(data.ev, from)
						else:
							var p = _assemble(data, from)
							if p != null and p.has("e"):
								g.apply_entities(p.e, false)
				"j":
					if is_host():
						_send("w", {"v": version, "full": true, "e": g.world_entities(), "cfg": g.net_config()})
				"x":
					if is_client() and str(data.get("to", "")) in [me, "*"] and typeof(data.get("ev")) == TYPE_DICTIONARY:
						g.net_host_event(data.ev)


func _on_world(p: Dictionary) -> void:
	var v := int(p.get("v", 0))
	var full := bool(p.get("full", false))
	if full:
		if not synced:
			g.net_begin_client(p.get("cfg", {}))
			synced = true
		else:
			flush()
		g.apply_entities(p.e, true)
		version = v
		base = _serialize(g.world_entities())
		_behind_t = 0.0
		return
	if not synced or v <= version:
		return
	flush()       # our own pending changes go first, so the host's view does not erase them
	g.apply_entities(p.e, false)
	var now: Dictionary = g.world_entities()
	for k in p.e:
		if now.has(k):
			base[k] = JSON.stringify(now[k])
		else:
			base.erase(k)
	if v > version + 1:
		tr.emit("j", {"want": 1})
	version = v


func _on_peers(list: Array) -> void:
	var seen := {}
	for e in list:
		var pe: String = str(e.get("peer", ""))
		if bool(e.get("me", false)):
			me = pe
			continue
		var pr = e.get("p", {})
		if typeof(pr) != TYPE_DICTIONARY:
			continue
		var gp = pr.get("g", {})
		if typeof(gp) != TYPE_DICTIONARY or not gp.has("r"):
			continue
		seen[pe] = true
		if not peers.has(pe):
			peers[pe] = {"name": "", "p": {}, "av": null, "idx": peers.size() + 1}
			if g.hud != null:
				g.hud.toast("%s 加入了" % _name(pe, str(e.get("name", ""))))
		peers[pe].name = _name(pe, str(e.get("name", "")) if str(e.get("name", "")) != "" else str(gp.get("n", "")))
		peers[pe].p = gp
		if str(gp.get("r", "")) == "host" and is_client():
			host_peer = pe
			if gp.has("w") and synced:
				g.net_apply_fast(gp.w)
	for pe in peers.keys():
		if not seen.has(pe):
			if g.hud != null and pe != host_peer:
				g.hud.toast("%s 離開了" % peers[pe].name)
			_drop_avatar(peers[pe])
			peers.erase(pe)


func _name(peer: String, n: String) -> String:
	if n != "":
		return n
	return "玩家" + peer.substr(0, 3).to_upper()


func _on_lobby(list: Array) -> void:
	var out := []
	for e in list:
		var pr = e.get("p", {})
		if typeof(pr) != TYPE_DICTIONARY or bool(e.get("me", false)):
			continue
		var c = pr.get("mw")
		if c == null or str(c) == "":
			continue
		out.append({"code": str(c), "name": _name(str(e.get("peer", "")), str(e.get("name", ""))), "peer": str(e.get("peer", ""))})
	var key := JSON.stringify(out)
	if key != _rooms_key:
		_rooms_key = key
		rooms = out
		g.net_rooms_changed()


# ---------------------------------------------------------------- diffing and chunks

func _serialize(ents: Dictionary) -> Dictionary:
	var out := {}
	for k in ents:
		out[k] = JSON.stringify(ents[k])
	return out


func _diff() -> Dictionary:
	var now: Dictionary = g.world_entities()
	var patch := {}
	for k in now:
		var s := JSON.stringify(now[k])
		if base.get(k, "") != s:
			patch[k] = now[k]
			base[k] = s
	for k in base.keys():
		if not now.has(k):
			patch[k] = null
			base.erase(k)
	return patch


func _send(topic: String, payload: Dictionary) -> void:
	var b64 := Marshalls.utf8_to_base64(JSON.stringify(payload))
	var n := ceili(float(b64.length()) / CHUNK)
	_msg += 1
	var id := "%s%d" % [me.substr(0, 4), _msg]
	for i in n:
		tr.emit(topic, {"id": id, "i": i, "n": n, "s": b64.substr(i * CHUNK, CHUNK)})


func _assemble(data: Dictionary, from: String):
	if not data.has("id") or not data.has("s"):
		return null
	var n := int(data.get("n", 1))
	var id := from + ":" + str(data.id)
	if n <= 1:
		return _decode(str(data.s))
	if not _chunks.has(id):
		_chunks[id] = {"parts": {}, "t": Time.get_ticks_msec()}
	_chunks[id].parts[int(data.get("i", 0))] = str(data.s)
	if _chunks[id].parts.size() < n:
		return null
	var s := ""
	for i in n:
		s += str(_chunks[id].parts.get(i, ""))
	_chunks.erase(id)
	return _decode(s)


func _decode(b64: String):
	var txt := Marshalls.base64_to_utf8(b64)
	var v = JSON.parse_string(txt)
	return v if typeof(v) == TYPE_DICTIONARY else null


# ---------------------------------------------------------------- other players' castaways

func _avatar(p: Dictionary) -> Dictionary:
	if p.av == null:
		var rig := PlayerRig.new()
		rig.set_shirt(COLORS[(int(p.idx) - 1) % COLORS.size()])
		var lb: Label3D = g._label3d(rig)
		lb.position.y = 2.15
		lb.pixel_size = 0.0055
		lb.modulate = Color("ffe9b0")
		p.av = {"rig": rig, "label": lb, "mode": -1}
	return p.av


func _drop_avatar(p: Dictionary) -> void:
	if p.av != null:
		(p.av.rig as Node3D).queue_free()
		p.av = null


func _tick_avatars(dt: float) -> void:
	for k in peers:
		var p: Dictionary = peers[k]
		var pl = p.p.get("pl", [])
		if typeof(pl) != TYPE_ARRAY or pl.size() < 9:
			continue
		var av := _avatar(p)
		var rig: PlayerRig = av.rig
		var m := int(pl[0])
		if m != int(av.mode):
			av.mode = m
			if rig.get_parent() != null:
				rig.get_parent().remove_child(rig)
			if m == 1:
				g.add_child(rig)
			else:
				g.raft.add_child(rig)
			rig.position = Vector3(float(pl[1]), float(pl[2]), float(pl[3]))
		var want := Vector3(float(pl[1]), float(pl[2]), float(pl[3]))
		rig.position = rig.position.lerp(want, minf(1.0, dt * 10.0))
		rig.rotation = Vector3(float(pl[7]), lerp_angle(rig.rotation.y, float(pl[4]), minf(1.0, dt * 10.0)), 0.0)
		rig.animate(dt, int(pl[5]) == 1, str(pl[6]), g.wall_t)
		rig.bubbles.emitting = m == 1 and float(pl[2]) < g.ocean.height(float(pl[1]), float(pl[3])) - 0.9
		(av.label as Label3D).text = p.name


# ---------------------------------------------------------------- transports

## The real thing: window.MWNet in the web page (tools/mwnet.js), over the page's room.
class JSTransport:
	var mw = null

	func _init() -> void:
		mw = JavaScriptBridge.get_interface("MWNet")

	func ok() -> bool:
		return mw != null

	func _status() -> Dictionary:
		var v = JSON.parse_string(str(mw.status()))
		return v if typeof(v) == TYPE_DICTIONARY else {}

	func state() -> String:
		return str(_status().get("avail", "no"))

	func available() -> bool:
		return state() == "yes"

	func me() -> String:
		return str(_status().get("me", ""))

	func lobby(d: Dictionary) -> void:
		mw.lobbySet(JSON.stringify(d))

	func kind() -> String:
		return str(_status().get("kind", ""))

	func join(room: String, role := "") -> void:
		mw.join(room, role)

	func leave() -> void:
		mw.leave()

	func emit(topic: String, data: Dictionary) -> void:
		mw.emit(topic, JSON.stringify(data))

	func presence(d: Dictionary) -> void:
		mw.presence(JSON.stringify(d))

	func poll() -> Dictionary:
		var v = JSON.parse_string(str(mw.poll()))
		return v if typeof(v) == TYPE_DICTIONARY else {}


## In-process stand-in for tests: several games in one SceneTree share a static bus.
class LoopTransport:
	static var all: Array = []
	var id := ""
	var room := ""
	var pres := {}
	var lob := {}
	var q: Array = []
	var dirty := true
	var lobby_dirty := true

	func _init() -> void:
		id = "p%d" % (all.size() + 1) + str(randi() % 1000)
		all.append(self)

	func state() -> String:
		return "yes"

	func kind() -> String:
		return "loop"

	func available() -> bool:
		return true

	func me() -> String:
		return id

	func lobby(d: Dictionary) -> void:
		for k in d:
			if d[k] == null:
				lob.erase(k)
			else:
				lob[k] = d[k]
		for t in all:
			t.lobby_dirty = true

	func join(r: String, _role := "") -> void:
		room = r
		pres = {}
		q.append({"k": "joined", "ok": true})
		for t in all:
			t.dirty = true

	func leave() -> void:
		room = ""
		pres = {}
		for t in all:
			t.dirty = true

	func emit(topic: String, data: Dictionary) -> void:
		var copy = JSON.parse_string(JSON.stringify(data))
		for t in all:
			if t.room == room and room != "":
				t.q.append({"k": "msg", "topic": topic, "peer": id, "me": t == self, "data": copy})

	func presence(d: Dictionary) -> void:
		pres = {"g": JSON.parse_string(JSON.stringify(d))}
		for t in all:
			if t.room == room:
				t.dirty = true

	func poll() -> Dictionary:
		var out := {"ev": q}
		q = []
		if dirty and room != "":
			dirty = false
			var list := []
			for t in all:
				if t.room == room:
					list.append({"peer": t.id, "me": t == self, "name": "", "p": t.pres})
			out["peers"] = list
		if lobby_dirty:
			lobby_dirty = false
			var l2 := []
			for t in all:
				l2.append({"peer": t.id, "me": t == self, "name": "", "p": t.lob})
			out["lobby"] = l2
		return out
