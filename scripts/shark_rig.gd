class_name SharkRig
extends Node3D
## Reef shark sculpted procedurally: the body is lofted along X through real shark cross-sections
## (pointed snout, deepest girth behind the gills, thin tail stalk), countershaded with vertex
## colours (slate back, white belly). The lower jaw is a separate hinged piece under the snout.
## Faces +X, length about 4 m.

const L := 4.0
const X0 := -2.1
const U_HINGE := 0.835
const SEAM := 0.55          # mouth seam sits this far (radians) below the side line
const TOP := Color("4a5f6c")
const SIDE := Color("6c8290")
const BELLY := Color("e4e8e6")
const GUM := Color("6b2a30")
# u (0 = tail end, 1 = snout tip), half-height, half-width, centre height
const PROFILE := [
	[0.00, 0.07, 0.05, 0.06], [0.12, 0.12, 0.09, 0.04], [0.28, 0.26, 0.21, 0.01],
	[0.45, 0.40, 0.34, 0.0], [0.62, 0.47, 0.42, 0.0], [0.76, 0.45, 0.41, -0.01],
	[0.86, 0.36, 0.35, -0.03], [0.93, 0.25, 0.27, -0.05], [0.975, 0.13, 0.15, -0.07], [1.0, 0.015, 0.02, -0.09],
]

var tail: Node3D
var jaw: Node3D
var _mats: Array[StandardMaterial3D] = []


func _init() -> void:
	var body_mat := _vc_mat()
	var hinge := _ring(U_HINGE, -SEAM)
	jaw = Node3D.new()
	jaw.position = Vector3(hinge.x, hinge.y, 0)
	add_child(jaw)

	# body: full rings up to the hinge, then only the part above the mouth seam
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, 0.0, U_HINGE, -PI / 2, 3.0 * PI / 2, 40, 28, Vector3.ZERO)
	_loft(st, U_HINGE, 1.0, -SEAM, PI + SEAM, 14, 22, Vector3.ZERO)
	_palate(st, Vector3.ZERO, -0.004, false)
	_part(self, st.commit(), body_mat)

	# lower jaw: the belly arc under the seam, plus its inner floor
	var sj := SurfaceTool.new()
	sj.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(sj, U_HINGE, 1.0, PI + SEAM, 2.0 * PI - SEAM, 14, 10, jaw.position)
	_palate(sj, jaw.position, 0.004, true)
	_part(jaw, sj.commit(), body_mat)

	# teeth along both rims of the mouth
	var tooth := Models.mat(Color("f2efe6"), 0.35)
	var tooth_mesh := Models.prism(0.045, 0.085, 0.025)
	for k in 8:
		var u := 0.865 + k * 0.016
		for sd in [-1.0, 1.0]:
			var p := _ring(u, -SEAM if sd > 0 else PI + SEAM)
			p.z *= 0.9
			_part(self, tooth_mesh, tooth, p + Vector3(0, -0.035, 0), Vector3(PI, 0, 0))
			_part(jaw, tooth_mesh, tooth, p - jaw.position + Vector3(0, 0.035, 0))

	# eyes and gill slits
	var dark := Models.mat(Color("0c0e10"), 0.2)
	var gill := Models.mat(Color("34434d"), 0.8)
	for sd in [-1.0, 1.0]:
		var e := _ring(0.925, 0.45 if sd > 0 else PI - 0.45)
		_part(self, Models.sphere(0.038, 8), dark, e * Vector3(1, 1, 0.98))
		for k in 5:
			var g := _ring(0.79 + k * 0.016, 0.1 if sd > 0 else PI - 0.1)
			_part(self, Models.box(0.012, 0.2 - k * 0.012, 0.01), gill, g * Vector3(1, 1, 1.01), Vector3(0, 0, 0.18))

	# fins
	var fin_c := Color("4f6573")
	var dorsal := _fin([Vector2(0.58, 0), Vector2(0.3, 0.32), Vector2(0.05, 0.66), Vector2(-0.14, 0.88), Vector2(-0.26, 0.9),
		Vector2(-0.22, 0.62), Vector2(-0.26, 0.32), Vector2(-0.45, 0.06), Vector2(-0.42, 0)], 0.05, fin_c)
	_part(self, dorsal, body_mat, Vector3(X0 + 0.6 * L, _prof(0.6).z + _prof(0.6).x - 0.06, 0))
	var small := _fin([Vector2(0.16, 0), Vector2(0.02, 0.16), Vector2(-0.08, 0.22), Vector2(-0.1, 0.12), Vector2(-0.16, 0)], 0.03, fin_c)
	_part(self, small, body_mat, Vector3(X0 + 0.24 * L, _prof(0.24).z + _prof(0.24).x - 0.03, 0))
	_part(self, small, body_mat, Vector3(X0 + 0.22 * L, _prof(0.22).z - _prof(0.22).x + 0.03, 0), Vector3(PI, 0, 0))
	var pect := _fin([Vector2(0.28, 0), Vector2(0.12, 0.22), Vector2(-0.12, 0.52), Vector2(-0.36, 0.78), Vector2(-0.44, 0.76),
		Vector2(-0.32, 0.42), Vector2(-0.24, 0.12), Vector2(-0.26, 0)], 0.035, fin_c)
	var pelvic := _fin([Vector2(0.14, 0), Vector2(-0.06, 0.2), Vector2(-0.18, 0.24), Vector2(-0.14, 0)], 0.025, fin_c)
	for sd in [-1.0, 1.0]:
		var pb := _ring(0.73, -0.75 if sd > 0 else PI + 0.75)
		_part(self, pect, body_mat, pb, Vector3(sd * (PI / 2 + 0.38), 0, -0.12))
		var vb := _ring(0.36, -0.9 if sd > 0 else PI + 0.9)
		_part(self, pelvic, body_mat, vb, Vector3(sd * (PI / 2 + 0.5), 0, -0.2))

	# heterocercal tail: long upper lobe, shorter lower lobe, notch between
	tail = Node3D.new()
	tail.position = Vector3(X0 + 0.08 * L, _prof(0.08).z, 0)
	add_child(tail)
	var caudal := _fin([Vector2(0.3, 0.08), Vector2(0.05, 0.2), Vector2(-0.28, 0.52), Vector2(-0.58, 0.9), Vector2(-0.72, 1.02),
		Vector2(-0.72, 0.9), Vector2(-0.5, 0.42), Vector2(-0.42, 0.12), Vector2(-0.5, -0.22), Vector2(-0.6, -0.48),
		Vector2(-0.52, -0.5), Vector2(-0.24, -0.2), Vector2(0.0, -0.08), Vector2(0.3, -0.06)], 0.04, fin_c)
	_part(tail, caudal, body_mat)


func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.42
	m.metallic_specular = 0.55
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.append(m)
	return m


func _part(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(parent, mesh, m, pos, rot)


## half-height, half-width, centre height at body position u (smooth between profile keys)
func _prof(u: float) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	for i in range(1, PROFILE.size()):
		var b: Array = PROFILE[i]
		if u <= b[0]:
			var a: Array = PROFILE[i - 1]
			var k := smoothstep(a[0], b[0], u)
			return Vector3(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k))
	var last: Array = PROFILE[-1]
	return Vector3(last[1], last[2], last[3])


## point on the body surface; th = 0 is the +Z side, th = PI/2 the back, th = -PI/2 the belly
func _ring(u: float, th: float) -> Vector3:
	var p := _prof(u)
	var s := sin(th)
	var hh := p.x * (0.84 if s < 0.0 else 1.0)
	return Vector3(X0 + u * L, p.z + hh * s, p.y * cos(th))


func _shade(th: float) -> Color:
	var s := sin(th)
	if s > 0.0:
		return SIDE.lerp(TOP, smoothstep(0.0, 0.7, s))
	return SIDE.lerp(BELLY, smoothstep(-0.05, -0.35, s))


func _normal(u: float, th: float) -> Vector3:
	var p := _prof(u)
	var s := sin(th)
	var hh := p.x * (0.84 if s < 0.0 else 1.0)
	var du := 0.01
	var slope := (_prof(u + du).y + _prof(u + du).x - _prof(u - du).y - _prof(u - du).x) / (4.0 * du * L)
	return Vector3(-slope, s / maxf(hh, 0.01), cos(th) / maxf(p.y, 0.01)).normalized()


func _loft(st: SurfaceTool, u0: float, u1: float, th0: float, th1: float, nu: int, nth: int, offset: Vector3) -> void:
	for i in nu:
		for j in nth:
			var ua := lerpf(u0, u1, float(i) / nu)
			var ub := lerpf(u0, u1, float(i + 1) / nu)
			var ta := lerpf(th0, th1, float(j) / nth)
			var tb := lerpf(th0, th1, float(j + 1) / nth)
			for q in [[ua, ta], [ub, ta], [ub, tb], [ua, ta], [ub, tb], [ua, tb]]:
				st.set_color(_shade(q[1]))
				st.set_normal(_normal(q[0], q[1]))
				st.add_vertex(_ring(q[0], q[1]) - offset)


## flat surface closing the mouth from inside (roof for the head, floor for the jaw)
func _palate(st: SurfaceTool, offset: Vector3, dy: float, floor: bool) -> void:
	var n := 14
	for i in n:
		var ua := lerpf(U_HINGE, 1.0, float(i) / n)
		var ub := lerpf(U_HINGE, 1.0, float(i + 1) / n)
		var a0 := _ring(ua, -SEAM)
		var a1 := _ring(ua, PI + SEAM)
		var b0 := _ring(ub, -SEAM)
		var b1 := _ring(ub, PI + SEAM)
		for p in [a0, b0, b1, a0, b1, a1]:
			st.set_color(GUM)
			st.set_normal(Vector3.UP if floor else Vector3.DOWN)
			st.add_vertex(p - offset + Vector3(0, dy, 0))


func _fin(pts: Array, thick: float, c: Color) -> ArrayMesh:
	var poly := PackedVector2Array(pts)
	var tris := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := c.darkened(0.25)
	var ymax := 0.0
	for p in pts:
		ymax = maxf(ymax, absf(p.y))
	for side in [1.0, -1.0]:
		for i in range(0, tris.size(), 3):
			for k in 3:
				var p: Vector2 = poly[tris[i + k]]
				st.set_color(c.lerp(tip, absf(p.y) / maxf(ymax, 0.01)))
				st.set_normal(Vector3(0, 0, side))
				st.add_vertex(Vector3(p.x, p.y, side * thick * 0.5 * (1.0 - 0.6 * absf(p.y) / maxf(ymax, 0.01))))
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		for q in [[a, 1.0], [b, 1.0], [b, -1.0], [a, 1.0], [b, -1.0], [a, -1.0]]:
			var p: Vector2 = q[0]
			st.set_color(tip)
			st.set_normal(n)
			st.add_vertex(Vector3(p.x, p.y, q[1] * thick * 0.5 * (1.0 - 0.6 * absf(p.y) / maxf(ymax, 0.01))))
	return st.commit()


func swim(t: float, fast: bool) -> void:
	tail.rotation.y = sin(t * (9.0 if fast else 5.0)) * 0.38


## 0 = closed, 1 = wide open
func set_jaw(open: float) -> void:
	jaw.rotation.z = -open * 0.6


func flash(on: bool) -> void:
	for m in _mats:
		m.albedo_color = Color(1.0, 0.55, 0.55) if on else Color(1, 1, 1)
