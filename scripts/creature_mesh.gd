class_name CreatureMesh
extends RefCounted
## Smooth procedural meshes for animals: lofted bodies (elliptic rings along +Z), flat blades for
## fins / wings / flippers (an outline extruded to a thin slab), and a domed turtle shell with
## Voronoi scutes. Colours are vertex colours so one material serves a whole creature.
## Godot's front face is clockwise, so every triangle is ordered with (b-a)x(c-a) pointing
## INTO the surface before generate_normals() / explicit normals.

static var _vc: StandardMaterial3D
static var _vc2: StandardMaterial3D


## Vertex-colour material (two-sided version for thin blades).
static func vmat(two_sided := false) -> StandardMaterial3D:
	if _vc == null:
		_vc = StandardMaterial3D.new()
		_vc.vertex_color_use_as_albedo = true
		_vc.roughness = 0.82
		_vc.metallic_specular = 0.25
		_vc2 = _vc.duplicate()
		_vc2.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _vc2 if two_sided else _vc


## Vertex colours are stored linear: the web / phone renderer ignores vertex_color_is_srgb.
static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


static func _tri(st: SurfaceTool, ia: int, ib: int, ic: int, pts: Array, out: Vector3) -> void:
	var a: Vector3 = pts[ia]
	var b: Vector3 = pts[ib]
	var c: Vector3 = pts[ic]
	if (b - a).cross(c - a).dot(out) > 0.0:
		st.add_index(ia)
		st.add_index(ic)
		st.add_index(ib)
	else:
		st.add_index(ia)
		st.add_index(ib)
		st.add_index(ic)


## rings: [[z, half_width, half_height, y_offset], ...] ordered along +z.
## colour.call(up, t, side) -> Color, where up = sin(angle) (-1 belly .. 1 back), t = 0..1 along
## the rings, side = cos(angle).
static func loft(rings: Array, seg: int, colour: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	var n := rings.size()
	for i in n:
		var r: Array = rings[i]
		for j in seg:
			var a := TAU * j / seg
			var p := Vector3(r[1] * cos(a), r[3] + r[2] * sin(a), r[0])
			st.set_color(_lin(colour.call(sin(a), float(i) / (n - 1), cos(a))))
			st.add_vertex(p)
			pts.append(p)
	for i in n - 1:
		var yc: float = (rings[i][3] + rings[i + 1][3]) * 0.5
		for j in seg:
			var a := i * seg + j
			var b := (i + 1) * seg + j
			var c := (i + 1) * seg + (j + 1) % seg
			var d := i * seg + (j + 1) % seg
			var mid: Vector3 = (pts[a] + pts[c]) * 0.5
			var out := Vector3(mid.x, mid.y - yc, 0.0)
			_tri(st, a, b, c, pts, out)
			_tri(st, a, c, d, pts, out)
	# end caps
	for end in [0, n - 1]:
		var r: Array = rings[end]
		var ci := pts.size()
		var cp := Vector3(0, r[3], r[0])
		st.set_color(_lin(colour.call(0.0, float(end) / (n - 1), 0.0)))
		st.add_vertex(cp)
		pts.append(cp)
		var out := Vector3(0, 0, -1.0 if end == 0 else 1.0)
		for j in seg:
			_tri(st, ci, end * seg + j, end * seg + (j + 1) % seg, pts, out)
	st.generate_normals()
	return st.commit()


## Outline (u, v) extruded to a slab `thick` thick.
## plane "flat": u -> x, v -> z, thickness along y (wings, flukes, flippers).
## plane "upright": u -> z, v -> y, thickness along x (dorsal fins).
## colour.call(uv) -> Color.
static func blade(outline: PackedVector2Array, thick: float, plane: String, colour: Callable, mirror := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(outline)
	# mirror = a true left-hand copy (negative node scale would flip the lighting)
	var mx := -1.0 if mirror else 1.0
	var put := func(uv: Vector2, h: float) -> Vector3:
		return Vector3(uv.x * mx, h, uv.y) if plane == "flat" else Vector3(h, uv.y, uv.x * mx)
	var up := Vector3.UP if plane == "flat" else Vector3.RIGHT
	for face in [1.0, -1.0]:
		var n: Vector3 = up * face
		for k in range(0, tris.size(), 3):
			var ids := [tris[k], tris[k + 1], tris[k + 2]]
			var p: Array = ids.map(func(i): return put.call(outline[i], face * thick * 0.5))
			if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
				ids = [ids[0], ids[2], ids[1]]
				p = [p[0], p[2], p[1]]
			for q in 3:
				st.set_normal(n)
				st.set_color(_lin(colour.call(outline[ids[q]])))
				st.add_vertex(p[q])
	# rim
	var m := outline.size()
	var centre := Vector2.ZERO
	for v in outline:
		centre += v
	centre /= m
	for i in m:
		var a2: Vector2 = outline[i]
		var b2: Vector2 = outline[(i + 1) % m]
		var e := (b2 - a2).orthogonal().normalized()
		if e.dot((a2 + b2) * 0.5 - centre) < 0.0:
			e = -e
		var nn: Vector3 = (put.call(e, 0.0) as Vector3).normalized()
		var quad := [put.call(a2, thick * 0.5), put.call(b2, thick * 0.5), put.call(b2, -thick * 0.5), put.call(a2, -thick * 0.5)]
		var ca: Color = colour.call(a2)
		var cb: Color = colour.call(b2)
		for tri in [[0, 1, 2], [0, 2, 3]]:
			var pa: Vector3 = quad[tri[0]]
			var pb: Vector3 = quad[tri[1]]
			var pc: Vector3 = quad[tri[2]]
			var order: Array = tri
			if (pb - pa).cross(pc - pa).dot(nn) > 0.0:
				order = [tri[0], tri[2], tri[1]]
			for q in order:
				st.set_normal(nn)
				st.set_color(_lin(ca if q == 0 or q == 3 else cb))
				st.add_vertex(quad[q])
	return st.commit()


## A smooth outline from a few control points (Catmull-Rom, closed).
static func smooth_outline(ctrl: Array, per := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0: Vector2 = ctrl[(i - 1 + n) % n]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % n]
		var p3: Vector2 = ctrl[(i + 2) % n]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## Domed turtle shell over an ellipse a × b (x × z), height h; scutes from Voronoi seeds.
static func shell(a: float, b: float, h: float) -> ArrayMesh:
	var seeds := [Vector2(0, 0.62), Vector2(0, 0.3), Vector2(0, -0.02), Vector2(0, -0.34), Vector2(0, -0.64)]
	for s in [-1.0, 1.0]:
		for z in [0.48, 0.15, -0.18, -0.5]:
			seeds.append(Vector2(s * 0.5, z))
	var base := Color("7e6c35")
	var light := Color("b09c55")
	var seam := Color("3f3519")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const NR := 22
	const NS := 56
	var pts := []
	var cp := Vector3(0, h, 0)
	st.set_color(_lin(light))
	st.add_vertex(cp)
	pts.append(cp)
	for i in range(1, NR + 1):
		var r := float(i) / NR
		for j in NS:
			var th := TAU * j / NS
			var u := Vector2(cos(th) * r, sin(th) * r)
			var y := h * pow(maxf(0.0, 1.0 - r * r), 0.55) - (0.025 if r > 0.97 else 0.0)
			var p := Vector3(u.x * a, y, u.y * b)
			# Voronoi: distance to the two nearest seeds; marginal ring of small scutes at the rim
			var d1 := 9.0
			var d2 := 9.0
			for sd in seeds:
				var dd: float = u.distance_to(sd)
				if dd < d1:
					d2 = d1
					d1 = dd
				elif dd < d2:
					d2 = dd
			var col := base.lerp(light, clampf(1.0 - d1 * 2.6, 0.0, 1.0))
			if r > 0.86:
				var segm := fmod(th / TAU * 26.0, 1.0)
				col = base.lightened(0.08) if r < 0.98 else base.darkened(0.2)
				if absf(segm - 0.5) > 0.42 or absf(r - 0.86) < 0.025:
					col = seam
			elif d2 - d1 < 0.05:
				col = seam
			st.set_color(_lin(col))
			st.add_vertex(p)
			pts.append(p)
	for j in NS:
		_tri(st, 0, 1 + j, 1 + (j + 1) % NS, pts, Vector3.UP)
	for i in NR - 1:
		for j in NS:
			var a0 := 1 + i * NS + j
			var b0 := 1 + (i + 1) * NS + j
			var c0 := 1 + (i + 1) * NS + (j + 1) % NS
			var d0 := 1 + i * NS + (j + 1) % NS
			var mid: Vector3 = (pts[a0] + pts[c0]) * 0.5
			var out := Vector3(mid.x / (a * a), mid.y / (h * h), mid.z / (b * b))
			_tri(st, a0, b0, c0, pts, out)
			_tri(st, a0, c0, d0, pts, out)
	st.generate_normals()
	return st.commit()


static func node(mesh: Mesh, two_sided := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = vmat(two_sided)
	return m


# ---------------------------------------------------------------- general tubes

## Catmull-Rom through control rings [[centre, axis_a, axis_b], ...] -> `count` rings.
static func spline_rings(ctrl: Array, count: int) -> Array:
	var out := []
	var n := ctrl.size()
	for k in count:
		var f := float(k) / (count - 1) * (n - 1)
		var i := mini(int(floorf(f)), n - 2)
		var t := f - i
		var ring := []
		for q in 3:
			var p0: Vector3 = ctrl[maxi(i - 1, 0)][q]
			var p1: Vector3 = ctrl[i][q]
			var p2: Vector3 = ctrl[i + 1][q]
			var p3: Vector3 = ctrl[mini(i + 2, n - 1)][q]
			var t2 := t * t
			var t3 := t2 * t
			ring.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		out.append(ring)
	return out


## Body-style control ring: centre (0, y, z), half-width w across x, half-height h up y.
static func ring(z: float, w: float, h: float, y: float) -> Array:
	return [Vector3(0, y, z), Vector3(w, 0, 0), Vector3(0, h, 0)]


## A tube through rings [[centre, a, b]]: point = centre + a·cos θ + b·sin θ. Smooth analytic
## normals, UV = (θ / TAU · uv_scale.x, t · uv_scale.y), colour.call(θ, t) -> Color (sRGB).
static func tube(rings: Array, seg: int, colour: Callable, caps := true, uv_scale := Vector2.ONE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := rings.size()
	var grid := []
	for i in n:
		var row := []
		var r: Array = rings[i]
		for j in seg:
			var th := TAU * j / seg
			row.append((r[0] as Vector3) + (r[1] as Vector3) * cos(th) + (r[2] as Vector3) * sin(th))
		grid.append(row)
	var pts := []
	for i in n:
		var c: Vector3 = rings[i][0]
		var along: Vector3 = (rings[mini(i + 1, n - 1)][0] as Vector3) - (rings[maxi(i - 1, 0)][0] as Vector3)
		for j in seg + 1:
			var jj := j % seg
			var p: Vector3 = grid[i][jj]
			var dth: Vector3 = (grid[i][(jj + 1) % seg] as Vector3) - (grid[i][(jj - 1 + seg) % seg] as Vector3)
			var dt: Vector3 = (grid[mini(i + 1, n - 1)][jj] as Vector3) - (grid[maxi(i - 1, 0)][jj] as Vector3)
			var nrm := dth.cross(dt)
			var radial := p - c
			if nrm.length() < 1e-10:
				nrm = radial if radial.length() > 1e-6 else along
			nrm = nrm.normalized()
			if radial.length() > 1e-6 and nrm.dot(radial) < 0.0:
				nrm = -nrm
			var t := float(i) / (n - 1)
			st.set_normal(nrm)
			st.set_uv(Vector2(float(j) / seg * uv_scale.x, t * uv_scale.y))
			st.set_color(_lin(colour.call(TAU * j / seg, t)))
			st.add_vertex(p)
			pts.append(p)
	var w := seg + 1
	for i in n - 1:
		var cm: Vector3 = ((rings[i][0] as Vector3) + (rings[i + 1][0] as Vector3)) * 0.5
		for j in seg:
			var a := i * w + j
			var b := (i + 1) * w + j
			var cc := (i + 1) * w + j + 1
			var d := i * w + j + 1
			var out: Vector3 = (pts[a] + pts[cc]) * 0.5 - cm
			_tri(st, a, b, cc, pts, out)
			_tri(st, a, cc, d, pts, out)
	if caps:
		for end in [0, n - 1]:
			var c: Vector3 = rings[end][0]
			var dir: Vector3 = ((rings[1][0] as Vector3) - (rings[0][0] as Vector3)) if end == 0 else ((rings[n - 1][0] as Vector3) - (rings[n - 2][0] as Vector3))
			var nn := dir.normalized() * (-1.0 if end == 0 else 1.0)
			var ci := pts.size()
			st.set_normal(nn)
			st.set_uv(Vector2(0.5 * uv_scale.x, float(end) / (n - 1) * uv_scale.y))
			st.set_color(_lin(colour.call(0.0, float(end) / (n - 1))))
			st.add_vertex(c)
			pts.append(c)
			for j in seg:
				_tri(st, ci, end * w + j, end * w + j + 1, pts, nn)
	return st.commit()


## Domed shell over an ellipse a × b with height h, top-view UVs for a carapace texture.
## The rear rim is scalloped. invert = true builds a shallow plastron facing down.
static func dome(a: float, b: float, h: float, colour: Callable, invert := false, NR := 30, NS := 72) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	var sgn := -1.0 if invert else 1.0
	var add := func(p: Vector3, uv: Vector2, nrm: Vector3) -> void:
		st.set_normal(nrm)
		st.set_uv(uv)
		st.set_color(_lin(colour.call(uv)))
		st.add_vertex(p)
		pts.append(p)
	add.call(Vector3(0, h * sgn, 0), Vector2(0.5, 0.5), Vector3(0, sgn, 0))
	for i in range(1, NR + 1):
		var r := float(i) / NR
		for j in NS + 1:
			var th := TAU * j / NS
			var scal := 1.0
			if not invert and sin(th) < 0.0:
				scal += 0.035 * pow(-sin(th), 2.0) * absf(sin(th * 13.0)) * smoothstep(0.85, 1.0, r)
			var u := Vector2(cos(th), sin(th)) * r * scal
			var y := h * pow(maxf(0.0, 1.0 - r * r), 0.5) * sgn
			var p := Vector3(u.x * a, y, u.y * b)
			var nrm := Vector3(p.x / (a * a), (p.y / (h * h)) if r < 0.999 else 0.0, p.z / (b * b)).normalized()
			if invert:
				nrm.y = -absf(nrm.y)
			add.call(p, Vector2(u.x * 0.5 + 0.5, u.y * 0.5 + 0.5), nrm)
	var w := NS + 1
	for j in NS:
		_tri(st, 0, 1 + j, 1 + j + 1, pts, Vector3(0, sgn, 0))
	for i in NR - 1:
		for j in NS:
			var a0 := 1 + i * w + j
			var b0 := 1 + (i + 1) * w + j
			var c0 := 1 + (i + 1) * w + j + 1
			var d0 := 1 + i * w + j + 1
			var mid: Vector3 = (pts[a0] + pts[c0]) * 0.5
			var out := Vector3(mid.x, mid.y if not invert else -absf(mid.y) - 0.01, mid.z)
			_tri(st, a0, b0, c0, pts, out)
			_tri(st, a0, c0, d0, pts, out)
	return st.commit()


## Low-poly look: split every triangle off with its own face normal and one colour (the average
## of its corners, nudged by up to ±jitter so neighbouring facets read as separate planes).
static func flat(mesh: ArrayMesh, jitter := 0.05) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))
		for k in range(0, idx.size(), 3):
			var a: Vector3 = v[idx[k]]
			var b: Vector3 = v[idx[k + 1]]
			var cc: Vector3 = v[idx[k + 2]]
			var n := -(b - a).cross(cc - a)
			if n.length() < 1e-12:
				continue
			n = n.normalized()
			var col := Color.WHITE
			if not c.is_empty():
				col = (c[idx[k]] + c[idx[k + 1]] + c[idx[k + 2]]) / 3.0
			var j := 1.0 + rng.randf_range(-jitter, jitter)
			col = Color(col.r * j, col.g * j, col.b * j)
			for p in [a, b, cc]:
				st.set_normal(n)
				st.set_color(col)
				st.add_vertex(p)
	return st.commit()


## Textured material (albedo × vertex colour), optional normal map.
static func textured(albedo: String, normal := "", rough := 0.6, uv_scale := Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(albedo)
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = 0.35
	m.uv1_scale = uv_scale
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = 1.0
	return m


## Wet, glossy skin (dolphins).
static func glossy() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.32
	m.metallic_specular = 0.45
	return m


static func node_m(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	return mi
