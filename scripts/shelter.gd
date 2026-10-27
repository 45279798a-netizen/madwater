class_name Shelter
extends RefCounted
## Houses on the raft: walls, window walls, doors, posts and railings sit on tile EDGES / CORNERS;
## second-storey floors and roofs sit on whole tiles. Two storeys: level 0 is the raft deck,
## level 1 the upper floor. Pieces need support: an upper floor or a roof rests on a wall or post
## below one of its edges / corners, or hangs one tile out from a supported neighbour.
## Walls and window walls stop the player; doors and railings-free edges don't.

const H := 2.4                       ## storey height
const FLOOR_Y := [0.07, 2.52]        ## top of the deck / upper floor, raft-local
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MODES := ["wall", "window", "door", "rail", "pillar", "upper", "roof"]
const EDGE_KINDS := ["wall", "window", "door", "rail"]
const BLOCKS := ["wall", "window", "rail"]
const NAME := {"wall": "牆", "window": "窗牆", "door": "門", "rail": "欄杆", "pillar": "支柱", "upper": "二樓地板", "roof": "屋頂", "stairs": "樓梯"}

var g                     ## the main game script
var edges := {}           ## "x|cx|cy|L" (east edge of cell) or "z|cx|cy|L" (south edge) -> {kind, node, level}
var posts := {}           ## "cx|cy|L" (corner at the cell's +x+z) -> node
var uppers := {}          ## Vector2i -> node
var roofs := {}           ## "cx|cy|L" (roof over floor level L) -> node
var ghosts := []          ## [{node, key, at (raft-local), y}]
var _hidden := false


func _init(game) -> void:
	g = game


static func is_mode(m: String) -> bool:
	return m in MODES


# ---------------------------------------------------------------- keys & geometry

static func edge_key(a: Vector2i, b: Vector2i, level: int) -> String:
	var lo := a if (a.x < b.x or a.y < b.y) else b
	var axis := "x" if a.y == b.y else "z"
	return "%s|%d|%d|%d" % [axis, lo.x, lo.y, level]


static func _parse(key: String) -> PackedStringArray:
	var p := key.split("|")
	return p


## Edge midpoint in raft-local space, and whether the edge runs along z (an "x" edge).
func edge_pos(key: String) -> Vector3:
	var p := _parse(key)
	var c := Vector2i(int(p[1]), int(p[2]))
	var lv := int(p[3])
	if p[0] == "x":
		return Vector3((c.x + 0.5) * g.TILE, FLOOR_Y[lv], c.y * g.TILE)
	return Vector3(c.x * g.TILE, FLOOR_Y[lv], (c.y + 0.5) * g.TILE)


func corner_pos(key: String) -> Vector3:
	var p := _parse(key)
	return Vector3((int(p[0]) + 0.5) * g.TILE, FLOOR_Y[int(p[2])], (int(p[1]) + 0.5) * g.TILE)


func has_floor(c: Vector2i, level: int) -> bool:
	return g.tiles.has(c) if level == 0 else uppers.has(c)


func _edge_cells(key: String) -> Array:
	var p := _parse(key)
	var c := Vector2i(int(p[1]), int(p[2]))
	return [c, c + (Vector2i(1, 0) if p[0] == "x" else Vector2i(0, 1))]


func _corner_cells(key: String) -> Array:
	var p := _parse(key)
	var c := Vector2i(int(p[0]), int(p[1]))
	return [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]


func _cell_edges(c: Vector2i, level: int) -> Array:
	var out := []
	for d in DIRS:
		out.append(edge_key(c, c + d, level))
	return out


func _cell_corners(c: Vector2i, level: int) -> Array:
	return ["%d|%d|%d" % [c.x, c.y, level], "%d|%d|%d" % [c.x - 1, c.y, level], "%d|%d|%d" % [c.x, c.y - 1, level], "%d|%d|%d" % [c.x - 1, c.y - 1, level]]


## Something solid under this tile at `level`: a wall / window / door on an edge or a post on a corner.
func _held_by(c: Vector2i, level: int) -> bool:
	for k in _cell_edges(c, level):
		if edges.has(k) and edges[k].kind != "rail":
			return true
	for k in _cell_corners(c, level):
		if posts.has(k):
			return true
	return false


func upper_ok(c: Vector2i) -> bool:
	if not g.tiles.has(c) or uppers.has(c) or roofs.has("%d|%d|0" % [c.x, c.y]) or _stairs_at(c):
		return false
	if _held_by(c, 0):
		return true
	for d in DIRS:
		if uppers.has(c + d) and _held_by(c + d, 0):
			return true
	return false


func roof_ok(c: Vector2i, level: int) -> bool:
	var key := "%d|%d|%d" % [c.x, c.y, level]
	if roofs.has(key) or not has_floor(c, level) or (level == 0 and uppers.has(c)):
		return false
	if _held_by(c, level):
		return true
	for d in DIRS:
		var nk := "%d|%d|%d" % [c.x + d.x, c.y + d.y, level]
		if roofs.has(nk) and _held_by(c + d, level):
			return true
	return false


func _stairs_at(c: Vector2i) -> bool:
	var t = g.tiles.get(c)
	return t != null and t.obj != null and t.obj.kind == "stairs"


# ---------------------------------------------------------------- walking

## Can the player step from (x, z) to (nx, nz) on this level? Floors must be there and no
## wall / window / railing may lie between.
func can_walk(x: float, z: float, nx: float, nz: float, level: int) -> bool:
	var m := 0.22
	for o in [Vector2(-m, -m), Vector2(m, -m), Vector2(-m, m), Vector2(m, m)]:
		if not has_floor(_cell(nx + o.x, nz + o.y), level):
			return false
	var c0 := _cell(x, z)
	for o in [Vector2(-m, 0), Vector2(m, 0), Vector2(0, -m), Vector2(0, m)]:
		var c1 := _cell(nx + o.x, nz + o.y)
		if c1 == c0:
			continue
		var steps := []
		if c1.x != c0.x:
			steps.append([c0, Vector2i(c1.x, c0.y)])
		if c1.y != c0.y:
			steps.append([c0, Vector2i(c0.x, c1.y)])
		for s in steps:
			var k := edge_key(s[0], s[1], level)
			if edges.has(k) and edges[k].kind in BLOCKS:
				return false
	return true


func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x / g.TILE), roundi(z / g.TILE))


## Hide everything above the player while they stand under a floor or roof, so the camera sees in.
func update_view(level: int, x: float, z: float) -> void:
	var c := _cell(x, z)
	var covered := (level == 0 and (uppers.has(c) or roofs.has("%d|%d|0" % [c.x, c.y]))) or (level == 1 and roofs.has("%d|%d|1" % [c.x, c.y]))
	if covered == _hidden:
		return
	_hidden = covered
	for k in edges:
		edges[k].node.visible = not covered or edges[k].level <= level
	for k in posts:
		posts[k].visible = not covered or int(_parse(k)[2]) <= level
	for c2 in uppers:
		uppers[c2].visible = not covered or level >= 1
	for k in roofs:
		roofs[k].visible = not covered or int(_parse(k)[2]) < level


# ---------------------------------------------------------------- building

func clear_ghosts() -> void:
	for gh in ghosts:
		gh.node.queue_free()
	ghosts.clear()


## Ghost pieces for every spot the current build mode can go, on the player's level.
func show_ghosts(mode: String, level: int, mat: Material) -> void:
	clear_ghosts()
	match mode:
		"wall", "window", "door", "rail":
			var seen := {}
			var cells: Array = g.tiles.keys() if level == 0 else uppers.keys()
			for c in cells:
				for d in DIRS:
					var k := edge_key(c, c + d, level)
					if seen.has(k) or edges.has(k):
						continue
					seen[k] = true
					if mode == "rail" and level == 0:
						continue
					var at := edge_pos(k)
					var along_z := _parse(k)[0] == "x"
					var hgt := 0.9 if mode == "rail" else H - 0.14
					var n := Models.part(g.raft, Models.box(0.14 if along_z else 1.9, hgt, 1.9 if along_z else 0.14), mat, at + Vector3(0, hgt / 2.0, 0))
					ghosts.append({"node": n, "key": k, "at": at})
		"pillar":
			var seen := {}
			var cells: Array = g.tiles.keys() if level == 0 else uppers.keys()
			for c in cells:
				for k in _cell_corners(c, level):
					if seen.has(k) or posts.has(k):
						continue
					seen[k] = true
					var at := corner_pos(k)
					var n := Models.part(g.raft, Models.cyl(0.16, 0.16, H - 0.14, 8), mat, at + Vector3(0, (H - 0.14) / 2.0, 0))
					ghosts.append({"node": n, "key": k, "at": at})
		"upper":
			for c in g.tiles:
				if upper_ok(c):
					var at := Vector3(c.x * g.TILE, FLOOR_Y[1] - 0.06, c.y * g.TILE)
					var n := Models.part(g.raft, Models.box(1.9, 0.12, 1.9), mat, at)
					ghosts.append({"node": n, "key": "%d|%d" % [c.x, c.y], "at": at})
		"roof":
			var cells: Array = g.tiles.keys() if level == 0 else uppers.keys()
			for c in cells:
				if roof_ok(c, level):
					var at := Vector3(c.x * g.TILE, FLOOR_Y[level] + H - 0.1, c.y * g.TILE)
					var n := Models.part(g.raft, Models.box(1.9, 0.2, 1.9), mat, at)
					ghosts.append({"node": n, "key": "%d|%d|%d" % [c.x, c.y, level], "at": at})
	for gh in ghosts:
		(gh.node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The ghost nearest to where the ray o + t·d crosses that ghost's height.
func pick_ghost(o: Vector3, d: Vector3) -> String:
	var best := ""
	var bd := 1.3
	for gh in ghosts:
		var at: Vector3 = g.raft.to_global(gh.at)
		if absf(d.y) < 0.0001:
			continue
		var t := (at.y + 0.6 - o.y) / d.y
		if t <= 0.0:
			continue
		var hp := o + d * t
		var dd := Vector2(hp.x - at.x, hp.z - at.z).length()
		if dd < bd:
			bd = dd
			best = gh.key
	return best


func place(mode: String, key: String) -> bool:
	match mode:
		"wall", "window", "door", "rail":
			if edges.has(key):
				return false
			_add_edge(key, mode)
		"pillar":
			if posts.has(key):
				return false
			_add_post(key)
		"upper":
			var p := _parse(key)
			var c := Vector2i(int(p[0]), int(p[1]))
			if not upper_ok(c):
				return false
			_add_upper(c)
		"roof":
			var p := _parse(key)
			if not roof_ok(Vector2i(int(p[0]), int(p[1])), int(p[2])):
				return false
			_add_roof(key)
	_hidden = false
	_refresh_roof_edges()
	return true


func _add_edge(key: String, kind: String) -> void:
	var n := Models.wall_piece(kind)
	n.position = edge_pos(key)
	if _parse(key)[0] == "x":
		n.rotation.y = PI / 2.0
	g.raft.add_child(n)
	edges[key] = {"kind": kind, "node": n, "level": int(_parse(key)[3])}


func _add_post(key: String) -> void:
	var n := Models.post()
	n.position = corner_pos(key)
	g.raft.add_child(n)
	posts[key] = n


func _add_upper(c: Vector2i) -> void:
	var n := Models.upper_floor()
	n.position = Vector3(c.x * g.TILE, FLOOR_Y[1], c.y * g.TILE)
	g.raft.add_child(n)
	uppers[c] = n


func _add_roof(key: String) -> void:
	var p := _parse(key)
	var lv := int(p[2])
	var n := Models.roof_tile()
	n.position = Vector3(int(p[0]) * g.TILE, FLOOR_Y[lv] + H - 0.12, int(p[1]) * g.TILE)
	g.raft.add_child(n)
	roofs[key] = n


## Thatch fringe only along the outside of each roof.
func _refresh_roof_edges() -> void:
	for k in roofs:
		var p := _parse(k)
		var c := Vector2i(int(p[0]), int(p[1]))
		var open := []
		for d in DIRS:
			open.append(roofs.has("%d|%d|%s" % [c.x + d.x, c.y + d.y, p[2]]))
		Models.roof_edges(roofs[k], open)


# ---------------------------------------------------------------- picking & removing pieces

## For demolish mode: the piece nearest the tap ray, as [kind, key], or [].
func pick_piece(o: Vector3, d: Vector3) -> Array:
	var best := []
	var bd := 0.95
	var cands := []
	for k in edges:
		if edges[k].node.visible:
			cands.append([edges[k].kind, k, edge_pos(k) + Vector3(0, 1.1 if edges[k].kind != "rail" else 0.45, 0)])
	for k in posts:
		if posts[k].visible:
			cands.append(["pillar", k, corner_pos(k) + Vector3(0, 1.1, 0)])
	for c in uppers:
		if uppers[c].visible:
			cands.append(["upper", "%d|%d" % [c.x, c.y], Vector3(c.x * g.TILE, FLOOR_Y[1], c.y * g.TILE)])
	for k in roofs:
		if roofs[k].visible:
			var p := _parse(k)
			cands.append(["roof", k, Vector3(int(p[0]) * g.TILE, FLOOR_Y[int(p[2])] + H, int(p[1]) * g.TILE)])
	for cd in cands:
		var w: Vector3 = g.raft.to_global(cd[2])
		var t := maxf(0.0, (w - o).dot(d))
		var dist := (o + d * t).distance_to(w)
		if dist < bd:
			bd = dist
			best = [cd[0], cd[1]]
	return best


func remove(kind: String, key: String) -> void:
	match kind:
		"wall", "window", "door", "rail":
			if edges.has(key):
				edges[key].node.queue_free()
				edges.erase(key)
		"pillar":
			if posts.has(key):
				posts[key].queue_free()
				posts.erase(key)
		"upper":
			var p := _parse(key)
			var c := Vector2i(int(p[0]), int(p[1]))
			if uppers.has(c):
				uppers[c].queue_free()
				uppers.erase(c)
		"roof":
			if roofs.has(key):
				roofs[key].queue_free()
				roofs.erase(key)
	_hidden = false
	_refresh_roof_edges()


## Drop whatever has lost its floor or its support (after demolishing or a shark bite).
## Returns how many pieces fell.
func settle() -> int:
	var fell := 0
	var changed := true
	while changed:
		changed = false
		for k in edges.keys():
			var lv: int = edges[k].level
			var cs := _edge_cells(k)
			if not has_floor(cs[0], lv) and not has_floor(cs[1], lv):
				remove(edges[k].kind, k)
				fell += 1
				changed = true
		for k in posts.keys():
			var lv := int(_parse(k)[2])
			if not _corner_cells(k).any(func(c): return has_floor(c, lv)):
				remove("pillar", k)
				fell += 1
				changed = true
		for c in uppers.keys():
			var held: bool = g.tiles.has(c) and (_held_by(c, 0) or DIRS.any(func(d): return uppers.has(c + d) and _held_by(c + d, 0)))
			if not held:
				remove("upper", "%d|%d" % [c.x, c.y])
				fell += 1
				changed = true
		for k in roofs.keys():
			var p := _parse(k)
			var c := Vector2i(int(p[0]), int(p[1]))
			var lv := int(p[2])
			var held: bool = has_floor(c, lv) and (_held_by(c, lv) or DIRS.any(func(d): return roofs.has("%d|%d|%d" % [c.x + d.x, c.y + d.y, lv]) and _held_by(c + d, lv)))
			if not held:
				remove("roof", k)
				fell += 1
				changed = true
	return fell


func clear() -> void:
	for k in edges:
		edges[k].node.queue_free()
	for k in posts:
		posts[k].queue_free()
	for c in uppers:
		uppers[c].queue_free()
	for k in roofs:
		roofs[k].queue_free()
	edges.clear()
	posts.clear()
	uppers.clear()
	roofs.clear()
	clear_ghosts()
	_hidden = false


## How many tiles of deck have something over them (for goals / the weather later).
func covered_count() -> int:
	var n := 0
	for c in g.tiles:
		if uppers.has(c) or roofs.has("%d|%d|0" % [c.x, c.y]):
			n += 1
	return n


# ---------------------------------------------------------------- save / load

func save_state() -> Dictionary:
	var e := []
	for k in edges:
		e.append([k, edges[k].kind])
	var u := []
	for c in uppers:
		u.append([c.x, c.y])
	return {"edges": e, "posts": posts.keys(), "uppers": u, "roofs": roofs.keys()}


func load_state(d: Dictionary) -> void:
	clear()
	for e in d.get("edges", []):
		_add_edge(str(e[0]), str(e[1]))
	for k in d.get("posts", []):
		_add_post(str(k))
	for u in d.get("uppers", []):
		_add_upper(Vector2i(int(u[0]), int(u[1])))
	for k in d.get("roofs", []):
		_add_roof(str(k))
	_refresh_roof_edges()
