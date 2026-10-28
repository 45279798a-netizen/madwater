class_name Models
## Procedural low-poly models built from Godot primitive meshes, so the prototype needs no art files.

const BARK := [Color("8a5a34"), Color("7d5230"), Color("936239"), Color("845632"), Color("7a4e2c")]

static var _cache := {}
## One raft tile is TILE metres square. Pieces drawn for the old 2 m tile are stretched by K
## across the deck (never upward); the raft logs themselves are laid out for the real size.
const TILE := 3.0
const K := TILE / 2.0


static func mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static var _tex := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://textures/%s.png" % name)
	return _tex[name]


## Textured material: a family's detail texture (textures/<fam>.png, mostly light grey, made by
## tools/gen_materials.py) tinted with c, plus its bump map. Families: bark, planks, thatch, rope,
## metal, cloth, soil, stone, sand, grass, plastic. Projected along three axes, so it works on boxes,
## spheres and hand-made meshes without UVs; rep = repeats per metre. uv = use the mesh's own UVs
## instead (cylinders: u around, v along), rep then being repeats across them.
static var _all_tmats: Array = []
static var bumps := true          ## graphics setting: bump (normal) maps on textured materials


## Graphics setting: turn the bump maps of every textured material on or off.
static func set_bumps(on: bool) -> void:
	bumps = on
	var alive := []
	for w in _all_tmats:
		var m = (w as WeakRef).get_ref()
		if m != null:
			(m as StandardMaterial3D).normal_enabled = on
			alive.append(w)
	_all_tmats = alive


static func tmat(c: Color, fam: String, rough := 0.88, rep := 1.0, bump := 1.0, uv := false, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	_all_tmats.append(weakref(m))
	m.albedo_color = Color(c.r * 1.25, c.g * 1.25, c.b * 1.25, c.a)
	m.albedo_texture = tex(fam)
	m.roughness = rough
	m.metallic = metal
	m.normal_enabled = bumps
	m.normal_texture = tex(fam + "_n")
	m.normal_scale = bump
	if uv:
		m.uv1_scale = Vector3(rep, rep, 1.0)
	else:
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 3.0
		m.uv1_scale = Vector3.ONE * rep
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Same, shared: for pieces that never get tinted individually.
static func tm(c: Color, fam: String, rough := 0.88, rep := 1.0, bump := 1.0) -> StandardMaterial3D:
	var key := "tm|%s|%s|%.2f|%.2f|%.2f" % [c.to_html(), fam, rough, rep, bump]
	if not _cache.has(key):
		_cache[key] = tmat(c, fam, rough, rep, bump)
	return _cache[key]


## Bark on a log lying along its own y axis: fibres run down the log.
static func log_mat(c: Color, length: float) -> StandardMaterial3D:
	var m := tmat(c, "bark", 0.95, 1.0, 1.2, true)
	m.uv1_scale = Vector3(2.0, maxf(1.0, roundf(length / 1.2)), 1.0)
	return m


## Bake every MeshInstance under root (except those under a node in `keep`) into one mesh per
## material, placed in root's own space: dozens of little parts become a few draw calls (phones care).
## A part with meta "vc" (Color) has that colour written into its vertices (pair it with a material
## that uses vertex colour), so differently tinted pieces can still share one material.
static func bake(root: Node3D, keep: Array = [], shadows := true) -> void:
	var groups := {}
	var order := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var skip := false
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != root:
			if keep.has(cur):
				skip = true
				break
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		if skip or not (mi as Node3D).visible or mi.mesh == null:
			continue
		var m: Material = mi.material_override
		if not groups.has(m):
			groups[m] = []
			order.append(m)
		groups[m].append([mi, xf])
	for m in order:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		var any_col := m is BaseMaterial3D and (m as BaseMaterial3D).vertex_color_use_as_albedo
		for item in groups[m]:
			if (item[0] as Node).has_meta("vc"):
				any_col = true
		for item in groups[m]:
			var mi: MeshInstance3D = item[0]
			var xf: Transform3D = item[1]
			var vc: Color = CreatureMesh._lin(mi.get_meta("vc")) if mi.has_meta("vc") else Color.WHITE
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nrm = arr[Mesh.ARRAY_NORMAL]
				var uv = arr[Mesh.ARRAY_TEX_UV]
				var col = arr[Mesh.ARRAY_COLOR]
				var ind = arr[Mesh.ARRAY_INDEX]
				var base := verts.size()
				var nb := xf.basis.inverse().transposed()
				for k in v.size():
					verts.append(xf * v[k])
					norms.append((nb * nrm[k]).normalized() if nrm != null and k < nrm.size() else Vector3.UP)
					uvs.append(uv[k] if uv != null and k < uv.size() else Vector2.ZERO)
					if any_col:
						cols.append((col[k] if col != null and k < col.size() else Color.WHITE) * vc)
				if ind != null and ind.size() > 0:
					for k in ind:
						idx.append(base + k)
				else:
					for k in v.size():
						idx.append(base + k)
			mi.get_parent().remove_child(mi)
			mi.queue_free()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if any_col:
			arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = m
		if not shadows:
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(out)


static func glass(c: Color, alpha: float) -> StandardMaterial3D:
	var m := mat(c, 0.2)
	m.albedo_color.a = alpha
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func ghost(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func cyl(top: float, bottom: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func capsule(r: float, h: float, seg := 10) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = seg
	c.rings = 4
	return c


static func sphere(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = max(4, seg / 2)
	return s


static func prism(x: float, y: float, z: float, apex := 0.5) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = Vector3(x, y, z)
	p.left_to_right = apex
	return p


static func part(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	n.scale = scl
	parent.add_child(n)
	return n


static func shared(key: String, maker: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## One raft cell: seven lashed logs on two cross beams. Every cell is a little different (seeded by
## its grid position): log lengths and twist, and now and then a plastic float lashed underneath, a
## patch plank nailed across, or weed trailing off an end. Returns the bark materials (damage tint).
static func raft_tile(parent: Node3D, i: int, j: int) -> Array:
	var log_a: Mesh = shared("log_a", func(): return cyl(0.21, 0.21, TILE - 0.02, 12))
	var log_b: Mesh = shared("log_b", func(): return cyl(0.195, 0.2, TILE - 0.06, 12))
	var beam: Mesh = shared("beam", func(): return cyl(0.1, 0.1, TILE + 0.04, 8))
	var rope: Mesh = shared("rope", func(): return box(TILE, 0.04, 0.08))
	var knot: Mesh = shared("knot", func(): return sphere(0.075, 7))
	var rope_m: Material = shared("rope_m", func(): return tmat(Color("8a7448"), "rope", 1.0, 6.0, 1.5))
	var beam_m: Material = shared("beam_m", func(): return log_mat(Color("5e3f25"), TILE))
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(i * 92821 + j * 68917, 999983) + 7
	# one bark material per tile (the damage tint darkens it); each log keeps its own shade in its vertices
	var bark := log_mat(Color(0.8, 0.8, 0.8), TILE)
	bark.vertex_color_use_as_albedo = true
	bark.uv1_offset = Vector3(rng.randf(), rng.randf(), 0)
	var mats := [bark]
	var n := 7
	var step := (TILE - 0.42) / (n - 1)
	for k in n:
		var lg := part(parent, log_a if posmod(i + j + k, 2) == 1 else log_b, bark,
			Vector3(-(TILE - 0.42) / 2.0 + k * step + rng.randf_range(-0.015, 0.015), -0.1 + rng.randf_range(-0.02, 0.02), (posmod(i * 3 + j * 5 + k * 7, 3) - 1) * 0.05),
			Vector3.ZERO)
		# lie the log along z and turn it about its own axis, so the bark pattern differs log to log
		lg.basis = Basis(Vector3.FORWARD, rng.randf_range(-0.012, 0.012)) * Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.UP, rng.randf() * TAU) \
			* Basis.from_scale(Vector3(1.0, rng.randf_range(0.965, 1.02), 1.0))
		# sun-bleached, salt-greyed logs: each its own shade
		var shade: Color = (BARK[posmod(i * 7 + j * 3 + k * 2, 5)] as Color).lerp(Color("c8ae8a"), 0.45 + rng.randf() * 0.2).lerp(Color("9a948a"), rng.randf() * 0.25)
		lg.set_meta("vc", shade * 1.15)
	for z in [-0.31 * TILE, 0.31 * TILE]:
		part(parent, beam, beam_m, Vector3(0, -0.3, z), Vector3(0, 0, PI / 2))
		part(parent, rope, rope_m, Vector3(0, 0.11, z))
		part(parent, knot, rope_m, Vector3(TILE / 2.0 - 0.02, 0.0, z))
		part(parent, knot, rope_m, Vector3(-TILE / 2.0 + 0.04, -0.02, z), Vector3.ZERO, Vector3(0.8, 0.8, 0.8))
	var roll := rng.randf()
	if roll < 0.3:
		# a plastic float lashed under the logs, half in the water
		var cols := [Color("2c6fc4"), Color("c4462c"), Color("e0b22a"), Color("3d8f5a")]
		var bm := tmat(cols[rng.randi() % cols.size()], "plastic", 0.45, 1.5, 0.6)
		var bx := rng.randf_range(-0.6, 0.6)
		part(parent, cyl(0.34, 0.34, 1.05, 14), bm, Vector3(bx, -0.5, 0), Vector3(PI / 2, 0, 0))
		for z in [-0.28, 0.28]:
			part(parent, cyl(0.355, 0.355, 0.05, 14), rope_m, Vector3(bx, -0.5, z), Vector3(PI / 2, 0, 0))
	elif roll < 0.5:
		# a patch plank nailed across the logs
		var pm := tm(Color("a07a52").lerp(Color("8a6a4a"), rng.randf()), "planks", 0.9, 1.3)
		var pz := rng.randf_range(-0.7, 0.7)
		var plank := part(parent, box(rng.randf_range(1.0, 1.6), 0.045, 0.26), pm, Vector3(rng.randf_range(-0.4, 0.4), 0.13, pz), Vector3(0, rng.randf_range(-0.25, 0.25), 0))
		var nail: Material = shared("nail_m", func(): return mat(Color("4a4c4e"), 0.5, 0.6))
		for sx in [-0.4, 0.4]:
			part(plank, cyl(0.018, 0.018, 0.02, 6), nail, Vector3(sx * plank.mesh.size.x, 0.03, 0))
	if rng.randf() < 0.3:
		# weed trailing off a log end
		var wm: Material = shared("trail_weed", func():
			var w := tmat(Color("4f7a34"), "grass", 0.8, 2.0, 0.6)
			w.cull_mode = BaseMaterial3D.CULL_DISABLED
			return w)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var wx := rng.randf_range(-1.0, 1.0)
		for k in 3:
			part(parent, box(0.07, 0.02, 0.4), wm, Vector3(wx + k * 0.06, -0.22 - k * 0.03, side * (TILE / 2.0 + 0.12)), Vector3(side * 0.9, k * 0.4, 0))
	bake(parent, [], false)   # the deck's own shadow on the sea isn't worth a second draw of every log
	return mats


## Floating junk. Each type comes in a few looks so the sea doesn't fill with copies.
static func debris(type: String) -> Node3D:
	var g := Node3D.new()
	var look := randi() % 3
	var nail: Material = shared("nail_m", func(): return mat(Color("4a4c4e"), 0.5, 0.6))
	match type:
		"plank":
			var wood := tm([Color("9b6b42"), Color("8e6039"), Color("a5744a"), Color("7d6a55")].pick_random(), "planks", 0.9, 1.2)
			match look:
				0:   # a single board with a bent nail
					part(g, box(1.6, 0.1, 0.34), wood)
					part(g, cyl(0.015, 0.015, 0.14, 5), nail, Vector3(-0.55, 0.08, 0.05), Vector3(0.3, 0, 0.5))
				1:   # two boards still nailed together, one snapped short
					part(g, box(1.6, 0.1, 0.3), wood)
					part(g, box(0.9, 0.08, 0.26), wood, Vector3(0.3, 0.08, 0), Vector3(0, 1.4, 0))
					for x in [-0.05, 0.6]:
						part(g, cyl(0.016, 0.016, 0.04, 5), nail, Vector3(x, 0.13, 0))
				_:   # a broken pallet: three slats on two runners
					for z in [-0.3, 0.0, 0.3]:
						part(g, box(1.3, 0.06, 0.22), wood, Vector3(0, 0.08, z))
					for x in [-0.45, 0.45]:
						part(g, box(0.12, 0.1, 0.95), wood, Vector3(x, -0.0, 0))
		"plastic":
			var b := Node3D.new()
			b.rotation.z = PI / 2
			b.position.x = 0.3
			g.add_child(b)
			var caps := [Color("2a6fd0"), Color("d04a3a"), Color("3a9a4a"), Color("f0c030")]
			var cap := mat(caps.pick_random())
			if look == 2:
				# a milk jug: square-ish body with a handle
				var jug := tm(Color("f4f2ea"), "plastic", 0.5, 2.0)
				part(b, box(0.3, 0.42, 0.26), jug, Vector3(0, 0.21, 0))
				part(b, cyl(0.06, 0.12, 0.12, 10), jug, Vector3(0.04, 0.47, 0))
				part(b, cyl(0.065, 0.065, 0.06, 10), cap, Vector3(0.04, 0.56, 0))
				var tor := TorusMesh.new()
				tor.rings = 14
				tor.ring_segments = 6
				tor.inner_radius = 0.07
				tor.outer_radius = 0.1
				part(b, tor, jug, Vector3(-0.12, 0.32, 0), Vector3(PI / 2, 0, 0))
			else:
				var tint := Color("cfeaf6") if look == 0 else Color("bfe8c8")
				part(b, cyl(0.14, 0.15, 0.46, 12), glass(tint, 0.75), Vector3(0, 0.23, 0))
				part(b, cyl(0.06, 0.13, 0.1, 12), glass(tint, 0.75), Vector3(0, 0.51, 0))
				part(b, cyl(0.065, 0.065, 0.07, 10), cap, Vector3(0, 0.6, 0))
				part(b, cyl(0.153, 0.153, 0.16, 12), tm(Color("f0e6c8") if look == 0 else Color("e05a4a"), "cloth", 0.7, 3.0), Vector3(0, 0.22, 0))
		"palm":
			var leaf := tmat(Color("5a9e3c").lerp(Color("8a9a3c"), look * 0.25), "grass", 0.8, 2.0, 0.8)
			leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
			var leaf2 := tmat(Color("86ad48").lerp(Color("b0a050"), look * 0.25), "grass", 0.8, 2.0, 0.8)
			leaf2.cull_mode = BaseMaterial3D.CULL_DISABLED
			var n_fronds := 1 if look < 2 else 2
			for fi in n_fronds:
				var fr := Node3D.new()
				fr.rotation.y = fi * 0.9
				fr.position = Vector3(fi * 0.2, fi * 0.03, fi * 0.15)
				g.add_child(fr)
				part(fr, cyl(0.025, 0.04, 1.6, 6), tm(Color("9a8a4a"), "bark", 0.9, 3.0), Vector3.ZERO, Vector3(0, 0, PI / 2))
				for k in 9:
					var x := -0.6 + k * 0.15
					var ln := 0.55 - k * 0.035
					for sd in [-1.0, 1.0]:
						part(fr, box(ln, 0.015, 0.09), leaf2 if k % 3 == 1 else leaf,
							Vector3(x + 0.08, 0.01 + 0.02 * sin(k), sd * ln * 0.45), Vector3(0, sd * 1.05, sd * (0.12 + 0.05 * sin(k * 2.0))))
		"coconut":
			var husk := tm(Color("6b4423"), "rope", 0.95, 3.0, 1.5)
			var n_nuts := 1 + look % 2
			for k in n_nuts:
				part(g, sphere(0.27, 12), husk, Vector3(k * 0.45, 0, k * 0.1), Vector3(k, k * 2.0, 0), Vector3(1, 0.9, 1.12))
				for e in 3:
					part(g, sphere(0.03, 5), mat(Color("2a1a10")), Vector3(k * 0.45 + cos(e * 2.1) * 0.07, sin(e * 2.1) * 0.07, 0.29 + k * 0.1))
			if look == 2:
				part(g, box(0.5, 0.015, 0.12), tmat(Color("86ad48"), "grass", 0.8, 2.0), Vector3(0.15, 0.2, 0), Vector3(0, 0.6, 0.3))
		_:
			var br := Node3D.new()
			br.rotation.z = PI / 2
			g.add_child(br)
			var woods := [Color("8a5a33"), Color("6e4a2e"), Color("9a6b3c")]
			var wood := tm(woods[look], "planks", 0.9, 1.5)
			part(br, cyl(0.42, 0.36, 0.48, 18), wood, Vector3(0, 0.24, 0))
			part(br, cyl(0.36, 0.42, 0.48, 18), wood, Vector3(0, -0.24, 0))
			var metal := tm(Color("55595c") if look != 1 else Color("7a4a30"), "metal", 0.5, 2.0)
			for y in [-0.36, -0.12, 0.12, 0.36]:
				part(br, cyl(0.43 - absf(y) * 0.14, 0.43 - absf(y) * 0.14, 0.04, 18), metal, Vector3(0, y, 0))
			part(br, cyl(0.37, 0.37, 0.02, 18), tm(woods[look].darkened(0.2), "planks", 0.9, 2.0), Vector3(0, 0.49, 0))
			part(br, cyl(0.05, 0.05, 0.03, 8), metal, Vector3(0.2, 0.5, 0))
	bake(g, [], false)
	return g


## Solar-and-fire still: a stone hearth, a dented pot of sea water under a clear dome, a copper
## coil dripping into a plastic cup. "fire" is shown while it burns (the game flickers its scale).
static func still() -> Dictionary:
	var g := Node3D.new()
	var stone := tm(Color("8a8378"), "stone", 0.95, 2.5, 1.5)
	var stone2 := tm(Color("6e6a62"), "stone", 0.95, 2.5, 1.5)
	for k in 9:
		var a := TAU * k / 9.0
		part(g, sphere(0.17 + 0.03 * sin(k * 2.3), 8), stone if k % 2 == 0 else stone2, Vector3(cos(a) * 0.42, 0.12, sin(a) * 0.42), Vector3(k, k * 1.3, 0), Vector3(1.2, 0.8, 1.0))
	part(g, cyl(0.38, 0.4, 0.06, 16), tm(Color("2a2420"), "soil", 1.0, 3.0), Vector3(0, 0.05, 0))   # ash bed
	var logs := tm(Color("6a4a2a"), "bark", 0.95, 3.0)
	for k in 3:
		part(g, cyl(0.05, 0.05, 0.55, 7), logs, Vector3(0, 0.13, 0), Vector3(PI / 2, k * 1.05, 0.12))
	var pot := tm(Color("8f979b"), "metal", 0.45, 2.5, 1.2)
	pot.metallic = 0.4
	part(g, cyl(0.33, 0.27, 0.36, 18), pot, Vector3(0, 0.46, 0))
	part(g, cyl(0.345, 0.345, 0.04, 18), pot, Vector3(0, 0.64, 0))
	var dome := SphereMesh.new()
	dome.radius = 0.34
	dome.height = 0.34
	dome.is_hemisphere = true
	dome.radial_segments = 20
	part(g, dome, glass(Color("d8f1ff"), 0.4), Vector3(0, 0.66, 0))
	# condensing coil to the cup
	var cu := mat(Color("c07a48"), 0.35, 0.8)
	_rod(g, Vector3(0.0, 0.98, 0.0), Vector3(0.28, 1.05, 0.2), 0.022, cu)
	_rod(g, Vector3(0.28, 1.05, 0.2), Vector3(0.52, 0.58, 0.36), 0.022, cu)
	var tor := TorusMesh.new()
	tor.rings = 14
	tor.ring_segments = 6
	tor.inner_radius = 0.06
	tor.outer_radius = 0.085
	for k in 3:
		part(g, tor, cu, Vector3(0.45, 0.72 + k * 0.07, 0.31), Vector3(0, 0, 0.2))
	part(g, cyl(0.12, 0.09, 0.22, 12), tm(Color("eaf6fb"), "plastic", 0.4, 3.0), Vector3(0.55, 0.42, 0.38))
	part(g, box(0.22, 0.3, 0.22), tm(Color("7a5232"), "planks", 0.9, 3.0), Vector3(0.55, 0.15, 0.38))
	var fire := Node3D.new()
	fire.position = Vector3(0, 0.1, 0)
	g.add_child(fire)
	for f in [Vector3(0, 0, 0.36), Vector3(0.12, 0.08, 0.26), Vector3(-0.11, -0.07, 0.28), Vector3(0.02, -0.14, 0.22)]:
		part(fire, cyl(0.0, 0.1, f.z, 7), fire_mat(), Vector3(f.x, f.z / 2.0, f.y))
	fire.visible = false
	bake(g, [fire])
	return {"node": g, "fire": fire}


static func fire_mat() -> StandardMaterial3D:
	if not _cache.has("fire_m"):
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color("ff8a2a")
		fm.emission_enabled = true
		fm.emission = Color("ff7a1a")
		fm.emission_energy_multiplier = 2.5
		_cache["fire_m"] = fm
	return _cache["fire_m"]


## Campfire grill: a ring of stones, crossed logs, an iron grate on legs, a spit at one side.
static func grill() -> Dictionary:
	var g := Node3D.new()
	var iron := tm(Color("3b4045"), "metal", 0.6, 2.0)
	var stone := tm(Color("8b8178"), "stone", 0.95, 2.5, 1.5)
	var stone2 := tm(Color("6f675e"), "stone", 0.95, 2.5, 1.5)
	for k in 10:
		var a := TAU * k / 10.0
		part(g, sphere(0.15 + 0.03 * cos(k * 1.7), 8), stone if k % 2 == 0 else stone2, Vector3(cos(a) * 0.46, 0.1, sin(a) * 0.36), Vector3(k, k * 0.7, 0), Vector3(1.2, 0.8, 1.0))
	part(g, cyl(0.42, 0.44, 0.05, 16), tm(Color("2a2420"), "soil", 1.0, 3.0), Vector3(0, 0.04, 0))
	var logs := tm(Color("6a4a2a"), "bark", 0.95, 3.0)
	for k in 3:
		part(g, cyl(0.05, 0.05, 0.6, 7), logs, Vector3(0, 0.12, 0), Vector3(PI / 2, k * 1.05 + 0.3, 0.1))
	for p in [Vector2(-0.4, -0.25), Vector2(0.4, -0.25), Vector2(-0.4, 0.25), Vector2(0.4, 0.25)]:
		part(g, cyl(0.025, 0.03, 0.56, 6), iron, Vector3(p.x, 0.28, p.y))
	part(g, box(0.92, 0.03, 0.04), iron, Vector3(0, 0.56, -0.3))
	part(g, box(0.92, 0.03, 0.04), iron, Vector3(0, 0.56, 0.3))
	for k in 7:
		part(g, box(0.02, 0.025, 0.62), iron, Vector3(-0.42 + k * 0.14, 0.565, 0))
	# spit on a forked stick
	var stick := tm(Color("7a5a3a"), "bark", 0.95, 3.0)
	_rod(g, Vector3(0.62, 0.0, -0.15), Vector3(0.62, 0.72, -0.15), 0.025, stick)
	_rod(g, Vector3(0.62, 0.66, -0.15), Vector3(0.7, 0.8, -0.15), 0.018, stick)
	_rod(g, Vector3(0.62, 0.66, -0.15), Vector3(0.54, 0.8, -0.15), 0.018, stick)
	var fire := Node3D.new()
	g.add_child(fire)
	for f in [Vector3(0, 0, 0.34), Vector3(0.14, 0.08, 0.24), Vector3(-0.13, -0.06, 0.26), Vector3(0.04, -0.12, 0.2)]:
		part(fire, cyl(0.0, 0.1, f.z, 7), fire_mat(), Vector3(f.x, 0.1 + f.z / 2.0, f.y))
	fire.visible = false
	var fishes := []
	var fish_mesh: Mesh = shared("grill_fish", func(): return sphere(1.0, 10))
	for x in [-0.2, 0.2]:
		var m := part(g, fish_mesh, mat(Color("8fa9b8")), Vector3(x, 0.62, 0), Vector3.ZERO, Vector3(0.28, 0.07, 0.11))
		m.visible = false
		part(m, prism(0.5, 0.9, 0.2), mat(Color("6f8a99")), Vector3(1.05, 0, 0), Vector3(0, 0, PI / 2))   # tail
		fishes.append(m)
	bake(g, [fire] + fishes)
	return {"node": g, "fire": fire, "fishes": fishes}


static func sail_cloth() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 6
	var ny := 8
	var pts := []
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx * 2.0 - 1.0
			var v := float(j) / ny * 2.0 - 1.0
			pts.append(Vector3(u * 0.85, v * 1.1, 0.38 * (1.0 - u * u) * (1.0 - v * v)))
	for j in ny:
		for i in nx:
			var a: Vector3 = pts[j * (nx + 1) + i]
			var b: Vector3 = pts[j * (nx + 1) + i + 1]
			var c: Vector3 = pts[(j + 1) * (nx + 1) + i]
			var d: Vector3 = pts[(j + 1) * (nx + 1) + i + 1]
			for p in [a, c, b, b, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## Square sail on a lashed mast: yard and boom turn with the wind (rig), stays run to the deck,
## a pennant flies at the top. The cloth is patched; the game rolls it up when furled.
static func sail() -> Dictionary:
	var g := Node3D.new()
	var wood := tm(Color("7a5232"), "bark", 0.9, 2.0)
	part(g, cyl(0.065, 0.09, 3.5, 10), shared("mast_m", func(): return log_mat(Color("7a5232"), 3.5)), Vector3(0, 1.75, 0))
	part(g, cyl(0.16, 0.2, 0.22, 10), tm(Color("6a4a2a"), "planks", 0.9, 2.0), Vector3(0, 0.11, 0))    # step block
	var rope: Material = shared("rope_m", func(): return tmat(Color("8a7448"), "rope", 1.0, 6.0, 1.5))
	for k in 3:
		part(g, cyl(0.1, 0.1, 0.05, 10), rope, Vector3(0, 0.35 + k * 0.06, 0))
	# stays from the masthead down to the deck corners
	for p in [Vector3(0.95, 0.08, 0.95), Vector3(-0.95, 0.08, 0.95), Vector3(0.95, 0.08, -0.95), Vector3(-0.95, 0.08, -0.95)]:
		_rod(g, Vector3(0, 3.35, 0), p, 0.012, rope)
		part(g, sphere(0.04, 6), rope, p)
	var rig := Node3D.new()
	g.add_child(rig)
	part(rig, cyl(0.04, 0.04, 2.0, 8), wood, Vector3(0, 3.15, 0), Vector3(0, 0, PI / 2))
	part(rig, cyl(0.04, 0.04, 2.0, 8), wood, Vector3(0, 0.92, 0), Vector3(0, 0, PI / 2))
	for sx in [-1.0, 1.0]:
		part(rig, sphere(0.05, 6), rope, Vector3(sx * 0.95, 3.15, 0))
	var cm := tmat(Color("d8c493"), "cloth", 0.95, 1.2, 1.0)
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := part(rig, shared("sail_cloth", func(): return sail_cloth()), cm, Vector3(0, 2.05, 0))
	# patches sewn onto the cloth (children of it, so they furl with it)
	var pm := tmat(Color("b9874f"), "cloth", 0.95, 2.0)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(cloth, box(0.38, 0.32, 0.01), pm, Vector3(-0.35, 0.3, 0.3), Vector3(0.0, -0.25, 0.08))
	var pm2 := tmat(Color("8aa0b4"), "cloth", 0.95, 2.0)
	pm2.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(cloth, box(0.28, 0.24, 0.01), pm2, Vector3(0.38, -0.45, 0.24), Vector3(0.0, 0.28, -0.1))
	var flag := tmat(Color("e8543c"), "cloth", 0.9, 3.0)
	flag.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(rig, prism(0.55, 0.22, 0.01), flag, Vector3(0.28, 3.52, 0), Vector3(0, 0, -PI / 2))
	part(g, sphere(0.06, 8), tm(Color("6a4a2a"), "planks", 0.9, 2.0), Vector3(0, 3.52, 0))
	bake(g, [rig])
	bake(rig, [cloth])
	return {"node": g, "rig": rig, "cloth": cloth}


## Ship's wheel on a post: eight spokes with turned handles, a brass hub. "wheel" spins when steering.
static func helm() -> Dictionary:
	var g := Node3D.new()
	var wood := tm(Color("6e4a2b"), "planks", 0.85, 2.0)
	var dark := tm(Color("4a3220"), "planks", 0.8, 3.0)
	var brass := mat(Color("c9a24a"), 0.35, 0.8)
	part(g, box(0.5, 0.08, 0.5), wood, Vector3(0, 0.04, 0))
	part(g, box(0.22, 0.95, 0.2), wood, Vector3(0, 0.55, 0))
	part(g, box(0.28, 0.08, 0.26), dark, Vector3(0, 1.0, 0))
	for y in [0.3, 0.75]:
		part(g, box(0.24, 0.03, 0.22), brass, Vector3(0, y, 0))
	var wheel := Node3D.new()
	wheel.position = Vector3(0, 1.08, 0.16)
	g.add_child(wheel)
	var tor := TorusMesh.new()
	tor.rings = 14
	tor.ring_segments = 6
	tor.inner_radius = 0.3
	tor.outer_radius = 0.37
	tor.rings = 28
	tor.ring_segments = 8
	part(wheel, tor, dark, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	var tor2 := TorusMesh.new()
	tor2.rings = 14
	tor2.ring_segments = 6
	tor2.inner_radius = 0.1
	tor2.outer_radius = 0.14
	part(wheel, tor2, dark, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	part(wheel, cyl(0.07, 0.07, 0.1, 12), brass, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for k in 8:
		var a := k * PI / 4.0
		part(wheel, cyl(0.018, 0.024, 0.5, 6), dark, Vector3(cos(a) * 0.22, sin(a) * 0.22, 0), Vector3(0, 0, a - PI / 2))
		var hnd := part(wheel, cyl(0.025, 0.035, 0.16, 8), wood, Vector3(cos(a) * 0.45, sin(a) * 0.45, 0), Vector3(0, 0, a - PI / 2))
		hnd.name = "H%d" % k
	bake(g, [wheel])
	bake(wheel)
	return {"node": g, "wheel": wheel}


static func bobber() -> Node3D:
	var g := Node3D.new()
	var top := SphereMesh.new()
	top.radius = 0.1
	top.height = 0.1
	top.is_hemisphere = true
	part(g, top, mat(Color("e8453c")))
	part(g, top, mat(Color("f4f1ea")), Vector3.ZERO, Vector3(PI, 0, 0))
	return g


## Island ground height at distance d from the centre of an island of radius r (local y).
## Grassy hump in the middle, beach from 0.5 r to 1.1 r, then the slope into the sea.
static func island_h(d: float, r: float) -> float:
	var t := d / r
	if t < 0.55:
		return 1.05 - 0.55 * t * t
	if t < 1.1:
		var k := (t - 0.55) / 0.55
		return lerpf(0.88, 0.05, k * k * (3.0 - 2.0 * k))
	return lerpf(0.05, -2.2, clampf((t - 1.1) / 0.45, 0.0, 1.0))


static func _island_ground(r: float, seed_i: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var harm := []
	for k in 4:
		harm.append([rng.randf_range(0.05, 0.11) / (k * 0.6 + 1.0), rng.randf() * TAU, k + 2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const NS := 72
	const NR := 22
	var grass := Color("6f9a44")
	var grass2 := Color("8aa848")
	var sand := Color("e8d29a")
	var wet := Color("b8a074")
	var under := Color("8a9a7a")
	var add := func(d: float, a: float, wob: float) -> void:
		var dd := d * wob
		var p := Vector3(cos(a) * dd, island_h(d, r), sin(a) * dd)
		var t := d / r
		var n := sin(a * 7.0 + d * 0.7) * 0.5 + 0.5
		var c: Color
		if t < 0.42:
			c = grass.lerp(grass2, n * 0.6)
		elif t < 0.56:
			c = grass.lerp(sand, (t - 0.42) / 0.14)
		elif t < 0.98:
			c = sand.lerp(Color("f2e2b0"), n * 0.3)
		elif t < 1.14:
			c = sand.lerp(wet, (t - 0.98) / 0.16)
		else:
			c = wet.lerp(under, clampf((t - 1.14) / 0.3, 0.0, 1.0))
		st.set_color(CreatureMesh._lin(c))
		st.set_uv(Vector2(p.x, p.z) * 0.35)
		st.add_vertex(p)
	add.call(0.0, 0.0, 1.0)
	for i2 in range(1, NR + 1):
		var d := float(i2) / NR * r * 1.55
		for j2 in NS:
			var a := TAU * j2 / NS
			var wob := 1.0
			if d > r * 0.6:      # the coastline wanders; the grassy middle stays round
				var w := 0.0
				for h in harm:
					w += h[0] * sin(a * h[2] + h[1])
				wob = 1.0 + w * clampf((d / r - 0.6) / 0.4, 0.0, 1.0)
			add.call(d, a, wob)
	for j2 in NS:
		st.add_index(0)
		st.add_index(1 + (j2 + 1) % NS)
		st.add_index(1 + j2)
	for i2 in NR - 1:
		for j2 in NS:
			var a0 := 1 + i2 * NS + j2
			var b0 := 1 + (i2 + 1) * NS + j2
			var c0 := 1 + (i2 + 1) * NS + (j2 + 1) % NS
			var d0 := 1 + i2 * NS + (j2 + 1) % NS
			for idx in [a0, c0, b0, a0, d0, c0]:
				st.add_index(idx)
	st.generate_normals()
	return st.commit()


## One palm frond: a drooping midrib with leaflets down both sides, ~2.2 m long, along +x.
static func _frond_mesh(len_m: float, dry: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Color("3f7a2e") if not dry else Color("8a8a3a")
	var tip := Color("8ab84a") if not dry else Color("c0a85a")
	const N := 14
	var spine := []
	for i2 in N + 1:
		var u := float(i2) / N
		spine.append(Vector3(u * len_m, 0.45 * u * len_m - 0.95 * u * u * len_m, 0))
	for i2 in N:
		var u := float(i2) / N
		var p0: Vector3 = spine[i2]
		var p1: Vector3 = spine[i2 + 1]
		var w := 0.5 * sin(PI * minf(1.0, u * 1.15 + 0.1)) * len_m / 2.2
		for sd in [-1.0, 1.0]:
			# a leaflet: from the rib out and down, pointing toward the tip
			var a := p0
			var b := p1
			var c := p0.lerp(p1, 0.6) + Vector3(0.12 * len_m / 2.2, -0.22 * w, sd * w)
			var col := base.lerp(tip, u)
			for q in [a, b, c] if sd > 0.0 else [a, c, b]:
				st.set_color(CreatureMesh._lin(col if q != c else col.lightened(0.1)))
				st.set_uv(Vector2(q.x, q.z) * 2.0)
				st.add_vertex(q)
	st.generate_normals()
	return st.commit()


static func _palm(g: Node3D, at: Vector3, lean: float, yaw: float, h: float, rng: RandomNumberGenerator) -> Dictionary:
	var tree := Node3D.new()
	tree.position = at
	tree.rotation.y = yaw
	g.add_child(tree)
	var bark: StandardMaterial3D = shared("palm_bark", func():
		var m := tmat(Color("8b6a43"), "bark", 0.95, 1.0, 1.6, true)
		m.uv1_scale = Vector3(2.0, 6.0, 1.0)
		return m)
	var R := CreatureMesh.ring
	var ctrl := []
	var top := Vector3.ZERO
	for k in 7:
		var u := float(k) / 6.0
		var c := Vector3(sin(lean) * u * u * h * 0.55, u * h, 0)
		var rad := lerpf(0.21, 0.13, u)
		ctrl.append([c, Vector3(rad, 0, 0), Vector3(0, 0, rad)])
		top = c
	var rings := CreatureMesh.spline_rings(ctrl, 20)
	# leaf scars: the trunk swells a little every few rings
	for k in rings.size():
		var sw := 1.0 + 0.07 * (1.0 if k % 2 == 0 else -0.3)
		rings[k][1] = (rings[k][1] as Vector3) * sw
		rings[k][2] = (rings[k][2] as Vector3) * sw
	part(tree, CreatureMesh.tube(rings, 10, func(_th, _t): return Color.WHITE, true), bark)
	var leaf: StandardMaterial3D = shared("frond_m", func():
		var m := tmat(Color(0.8, 0.8, 0.8), "grass", 0.85, 1.0, 0.6)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)
	var frond: Mesh = shared("frond", func(): return _frond_mesh(2.3, false))
	var frond_dry: Mesh = shared("frond_dry", func(): return _frond_mesh(1.9, true))
	var crown := Node3D.new()
	crown.position = top + Vector3(0, 0.05, 0)
	tree.add_child(crown)
	var n := 9
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.2, 0.2)
		var fr := part(crown, frond if k % 4 != 3 else frond_dry, leaf, Vector3.ZERO, Vector3(0, -a, rng.randf_range(-0.25, 0.15)))
		fr.scale = Vector3.ONE * rng.randf_range(0.85, 1.1)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		part(crown, frond, leaf, Vector3(0, 0.08, 0), Vector3(0, -a, 0.55), Vector3(0.55, 0.55, 0.55))   # young fronds standing up
	var nuts := Node3D.new()
	tree.add_child(nuts)
	var nut_m := tm(Color("6b4423"), "rope", 0.95, 3.0, 1.5)
	var nut_g := tm(Color("7a8a3a"), "rope", 0.9, 3.0, 1.0)
	for k in 4:
		part(nuts, sphere(0.16, 9), nut_m if k != 2 else nut_g, top + Vector3(cos(k * 1.6) * 0.2, -0.22 - (k % 2) * 0.08, sin(k * 1.6) * 0.2), Vector3.ZERO, Vector3(1, 1.1, 1))
	bake(tree, [nuts])
	return {"tree": tree, "nuts": nuts, "top": top}


## Small island: an irregular sandy mound with a grassy middle, palms, bushes, rocks, driftwood,
## shells and a crate. Returns the node and its lootable spots (trees, crate).
static func island(r: float) -> Dictionary:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 1000.0) + 17
	var ground_m: StandardMaterial3D = shared("island_ground_m", func():
		var m := tmat(Color(0.8, 0.8, 0.8), "sand", 1.0, 0.5, 1.0)
		m.vertex_color_use_as_albedo = true
		return m)
	var ground := part(g, _island_ground(r, rng.randi()), ground_m)
	ground.position.y = -0.2
	var oy := -0.2
	var rock := tm(Color("8a8f8c"), "stone", 0.9, 0.8, 1.4)
	var rock2 := tm(Color("6f7471"), "stone", 0.9, 0.8, 1.4)
	var rock_mesh: Mesh = shared("rock7", func(): return sphere(1.0, 7))
	for k in 5 + rng.randi() % 3:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.85, 1.25)
		var sz := rng.randf_range(0.35, 0.95)
		part(g, rock_mesh, rock if k % 2 == 0 else rock2, Vector3(cos(a) * d, oy + island_h(d, r) + sz * 0.2, sin(a) * d),
			Vector3(rng.randf() * 3.0, rng.randf() * 3.0, rng.randf()), Vector3(sz * 1.3, sz * 0.75, sz))
	var nodes := []
	var spots := [Vector2(-0.25, -0.15), Vector2(0.2, 0.25), Vector2(0.05, -0.38)]
	for idx in (3 if r > 8.0 else 2):
		var sp: Vector2 = spots[idx] * r
		var pm := _palm(g, Vector3(sp.x, oy + island_h(sp.length(), r) - 0.05, sp.y), 0.25 + idx * 0.12, rng.randf() * TAU, rng.randf_range(4.3, 5.4), rng)
		var tree: Node3D = pm.tree
		var top: Vector3 = pm.top
		nodes.append({"kind": "tree", "node": tree, "nuts": pm.nuts, "cd": 0.0, "hit": Vector3(top.x * 0.6, 2.6, 0)})
	# bushes and grass tufts on the green
	var bush := tm(Color("4f7f34"), "grass", 0.9, 1.5, 1.2)
	var bush2 := tm(Color("6a9440"), "grass", 0.9, 1.5, 1.2)
	var flower := [mat(Color("e8504a"), 0.6), mat(Color("f2d04a"), 0.6), mat(Color("f4f0f0"), 0.6)]
	var puff: Mesh = shared("bush_puff", func(): return sphere(1.0, 9))
	for k in 3 + rng.randi() % 3:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.1, 0.48)
		var b := Node3D.new()
		b.position = Vector3(cos(a) * d, oy + island_h(d, r), sin(a) * d)
		g.add_child(b)
		for q in 4 + rng.randi() % 3:
			var s := rng.randf_range(0.3, 0.55)
			part(b, puff, bush if q % 2 == 0 else bush2, Vector3(rng.randf_range(-0.45, 0.45), s * 0.6, rng.randf_range(-0.45, 0.45)), Vector3.ZERO, Vector3(s, s * 0.8, s))
		if rng.randf() < 0.6:
			var fm: Material = flower[rng.randi() % flower.size()]
			for q in 5:
				part(b, sphere(0.05, 5), fm, Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.35, 0.7), rng.randf_range(-0.5, 0.5)))
	var blade_m: Material = shared("tuft_m", func():
		var m := tmat(Color("7aa04a"), "grass", 0.9, 2.0, 0.5)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)
	for k in 14:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.05, 0.5)
		var tuft := Node3D.new()
		tuft.position = Vector3(cos(a) * d, oy + island_h(d, r), sin(a) * d)
		g.add_child(tuft)
		for q in 5:
			part(tuft, box(0.04, 0.45, 0.01), blade_m, Vector3(0, 0.2, 0), Vector3(rng.randf_range(-0.4, 0.4), q * 1.2, rng.randf_range(-0.4, 0.4)))
	# beach: driftwood, shells, a starfish
	var drift := tm(Color("b8aa94"), "bark", 0.95, 1.5, 1.5)
	for k in 1 + rng.randi() % 2:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.7, 0.95)
		part(g, cyl(0.12, 0.16, rng.randf_range(1.6, 2.8), 9), drift, Vector3(cos(a) * d, oy + island_h(d, r) + 0.08, sin(a) * d), Vector3(PI / 2, a + rng.randf_range(-0.5, 0.5), 0))
	var shell_m := [mat(Color("f4e8dc"), 0.5), mat(Color("f0c8b0"), 0.5)]
	for k in 6:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.6, 1.0)
		part(g, prism(0.16, 0.08, 0.12), shell_m[k % 2], Vector3(cos(a) * d, oy + island_h(d, r) + 0.02, sin(a) * d), Vector3(0.2, rng.randf() * TAU, 0))
	var star := mat(Color("e8804a"), 0.8)
	var sa := rng.randf() * TAU
	var sd := r * 0.9
	var st_n := Node3D.new()
	st_n.position = Vector3(cos(sa) * sd, oy + island_h(sd, r) + 0.03, sin(sa) * sd)
	g.add_child(st_n)
	for k in 5:
		part(st_n, box(0.22, 0.03, 0.06), star, Vector3(cos(k * TAU / 5.0) * 0.11, 0, sin(k * TAU / 5.0) * 0.11), Vector3(0, -k * TAU / 5.0, 0))
	# the crate washed up on the beach
	var crate := Node3D.new()
	var cd := r * 0.72
	crate.position = Vector3(cd * 0.92, oy + island_h(cd, r) + 0.35, -cd * 0.4)
	crate.rotation = Vector3(0.05, 0.4, -0.06)
	g.add_child(crate)
	part(crate, box(0.9, 0.7, 0.7), tm(Color("9a6b3c"), "planks", 0.9, 1.6))
	var band := tm(Color("5c5f61"), "metal", 0.5, 2.0)
	part(crate, box(0.94, 0.08, 0.74), band, Vector3(0, 0.18, 0))
	part(crate, box(0.94, 0.08, 0.74), band, Vector3(0, -0.2, 0))
	nodes.append({"kind": "crate", "node": crate, "used": false, "hit": Vector3.ZERO})
	bake(crate)
	var keep := [crate]
	for nd in nodes:
		if nd.kind == "tree":
			keep.append(nd.node)
			bake(nd.nuts)
	bake(g, keep)
	# bushes, tufts, shells and the like only need drawing up close
	for mi in g.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).material_override != ground_m and (mi as MeshInstance3D).material_override != rock and (mi as MeshInstance3D).material_override != rock2:
			(mi as MeshInstance3D).visibility_range_end = 80.0
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"node": g, "nodes": nodes}


## Storage chest: planked box with a domed lid, iron corner straps, a hasp and padlock.
static func chest() -> Dictionary:
	var g := Node3D.new()
	var wood := tm(Color("8a5a33"), "planks", 0.9, 1.5)
	var dark := tm(Color("5c3d22"), "planks", 0.9, 2.0)
	var metal := tm(Color("55595c"), "metal", 0.5, 2.0)
	for k in 4:
		part(g, box(1.1, 0.13, 0.7), wood if k % 2 == 0 else dark, Vector3(0, 0.1 + k * 0.135, 0))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.36
	lid.bottom_radius = 0.36
	lid.height = 1.12
	lid.radial_segments = 16
	var lid_n := part(g, lid, wood, Vector3(0, 0.62, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.42))
	lid_n.scale = Vector3(0.42, 1, 1)
	for x in [-0.48, 0.48]:
		part(g, box(0.06, 0.62, 0.74), metal, Vector3(x, 0.33, 0))
		part(g, box(0.06, 0.05, 0.74), metal, Vector3(x, 0.72, 0))
	for x in [-0.56, 0.56]:
		for z in [-0.36, 0.36]:
			part(g, box(0.04, 0.62, 0.04), metal, Vector3(x, 0.33, z))
	part(g, box(0.12, 0.18, 0.04), metal, Vector3(0, 0.6, 0.37))
	part(g, box(0.1, 0.1, 0.05), mat(Color("c9a24a"), 0.35, 0.8), Vector3(0, 0.47, 0.39))
	for sx in [-1.0, 1.0]:
		var tor := TorusMesh.new()
		tor.rings = 14
		tor.ring_segments = 6
		tor.inner_radius = 0.05
		tor.outer_radius = 0.07
		part(g, tor, metal, Vector3(sx * 0.6, 0.45, 0), Vector3(0, 0, PI / 2))
	bake(g)
	return {"node": g}


## The castaway's backpack floating on a little buoy after a blackout (standard mode).
static func lost_bag() -> Node3D:
	var g := Node3D.new()
	var glow := mat(Color("ff9f1c"))
	glow.emission_enabled = true
	glow.emission = Color("ff8a1a")
	glow.emission_energy_multiplier = 1.5
	part(g, cyl(0.42, 0.42, 0.16, 16), glow, Vector3(0, 0.0, 0))
	part(g, box(0.7, 0.5, 0.42), mat(Color("6b4a2e"), 0.9), Vector3(0, 0.32, 0))
	part(g, box(0.72, 0.08, 0.44), mat(Color("e8743b")), Vector3(0, 0.5, 0))
	part(g, cyl(0.03, 0.03, 0.9, 6), mat(Color("3a3f44")), Vector3(0.3, 0.75, 0))
	part(g, box(0.02, 0.22, 0.3), glow, Vector3(0.3, 1.08, 0.15))
	return g


# ---------------------------------------------------------------- seabed

static func sand_mound(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var m := tm(Color("e6d3a0"), "sand", 1.0, 1.0, 1.5)
	for k in 3:
		var a := rng.randf() * TAU
		part(g, sphere(0.38 + rng.randf() * 0.2, 9), m, Vector3(cos(a) * 0.3, 0.02, sin(a) * 0.3), Vector3.ZERO, Vector3(1.3, 0.35, 1.1))
	var shell := mat(Color("f1e6dc"), 0.5)
	part(g, prism(0.14, 0.08, 0.1), shell, Vector3(0.1, 0.16, -0.12), Vector3(0, rng.randf() * TAU, 0.3))
	bake(g, [], false)
	return g


static func clay_lump(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var m := tm(Color("a35a3c"), "soil", 0.95, 1.5, 1.2)
	var m2 := tm(Color("8c4a30"), "soil", 0.95, 1.5, 1.2)
	for k in 4:
		var a := rng.randf() * TAU
		part(g, sphere(0.22 + rng.randf() * 0.18, 8), m if k % 2 == 0 else m2,
			Vector3(cos(a) * 0.28, 0.08, sin(a) * 0.28), Vector3.ZERO, Vector3(1.2, 0.6, 1.0))
	bake(g, [], false)
	return g


static func ore_rock(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	part(g, sphere(0.55, 9), tm(Color("4a4f52"), "stone", 0.85, 1.5, 1.6), Vector3(0, 0.2, 0), Vector3(rng.randf(), rng.randf() * 3.0, 0), Vector3(1.2, 0.8, 1.0))
	var vein := mat(Color("d98a3a"), 0.35, 0.8)
	vein.emission_enabled = true
	vein.emission = Color("b8651c")
	vein.emission_energy_multiplier = 0.6
	for k in 4:
		var a := rng.randf() * TAU
		part(g, box(0.16, 0.1, 0.12), vein, Vector3(cos(a) * 0.45, 0.3 + rng.randf() * 0.2, sin(a) * 0.4), Vector3(rng.randf(), a, rng.randf()))
	bake(g, [], false)
	return g


static func seaweed(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var cols := [Color("3f7a3a"), Color("5b8f3c"), Color("2f6a4a"), Color("6a7a2a")]
	var m := tmat(cols[rng.randi() % cols.size()], "grass", 0.8, 2.0, 0.6)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stalks := 1 + rng.randi() % 3
	for s_i in stalks:
		var segs := 4 + rng.randi() % 5
		var y := 0.0
		var ox := rng.randf_range(-0.2, 0.2)
		var oz := rng.randf_range(-0.2, 0.2)
		for k in segs:
			var w := 0.18 + 0.06 * sin(k * 0.9)
			part(g, box(w, 0.55, 0.02), m, Vector3(ox + sin(k * 0.8 + s_i) * 0.1, y + 0.27, oz), Vector3(0, k * 0.5 + s_i, sin(k * 1.1) * 0.15))
			if k % 2 == 1:
				part(g, sphere(0.05, 6), m, Vector3(ox + sin(k * 0.8 + s_i) * 0.1 + 0.1, y + 0.5, oz))   # gas bladders
			y += 0.5
	bake(g, [], false)
	return g


## A reef piece: branching coral, a sea fan, a brain coral or a cluster of tube sponges.
static func coral(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var cols := [Color("e86a7a"), Color("f0a050"), Color("b46ad0"), Color("f2d06a"), Color("5ac0c0"), Color("f08aa8")]
	var c: Color = cols[rng.randi() % cols.size()]
	var m := tm(c, "stone", 0.7, 2.5, 1.2)
	match rng.randi() % 4:
		0:   # branching: forked arms
			for k in 5:
				var a := rng.randf() * TAU
				var h := 0.4 + rng.randf() * 0.6
				var arm := part(g, cyl(0.04, 0.08, h, 7), m, Vector3(cos(a) * 0.15, h / 2.0, sin(a) * 0.15), Vector3(cos(a) * 0.4, 0, sin(a) * 0.4))
				part(arm, cyl(0.02, 0.04, h * 0.5, 6), m, Vector3(0.05, h * 0.55, 0), Vector3(0, 0, -0.6))
				part(arm, sphere(0.045, 6), m, Vector3(0, h * 0.5, 0))
		1:   # sea fan: a flat lattice
			var fm := tmat(c, "cloth", 0.8, 6.0, 1.5)
			fm.cull_mode = BaseMaterial3D.CULL_DISABLED
			var fan := part(g, sphere(0.6, 12), fm, Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.04))
			part(g, cyl(0.03, 0.05, 0.3, 6), m, Vector3(0, 0.12, 0))
			fan.rotation.x = 0.1
		2:   # brain coral
			var bm := tm(c, "soil", 0.8, 4.0, 2.5)
			part(g, sphere(0.45 + rng.randf() * 0.25, 14), bm, Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1.2, 0.7, 1.1))
		_:   # tube sponges
			for k in 3 + rng.randi() % 3:
				var a := rng.randf() * TAU
				var h := rng.randf_range(0.35, 0.9)
				var r := rng.randf_range(0.07, 0.13)
				part(g, cyl(r, r * 0.8, h, 9), m, Vector3(cos(a) * 0.18, h / 2.0, sin(a) * 0.18), Vector3(cos(a) * 0.15, 0, sin(a) * 0.15))
				part(g, cyl(r * 0.7, r * 0.7, 0.02, 9), mat(c.darkened(0.6), 0.9), Vector3(cos(a) * 0.18 + cos(a) * 0.15 * h * 0.5, h + 0.005, sin(a) * 0.18))
	bake(g, [], false)
	return g


## Small things on the sea floor that are only there to look at: stones, a starfish, shells, a sea urchin.
static func reef_bits(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	match rng.randi() % 4:
		0:
			var rm := tm(Color("6a7068"), "stone", 0.9, 1.2, 1.5)
			for k in 2 + rng.randi() % 3:
				var s := rng.randf_range(0.25, 0.7)
				part(g, shared("rock7", func(): return sphere(1.0, 7)), rm, Vector3(rng.randf_range(-0.6, 0.6), s * 0.3, rng.randf_range(-0.6, 0.6)), Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0), Vector3(s * 1.3, s * 0.7, s))
		1:
			var sm := mat([Color("e8804a"), Color("d04a6a"), Color("f0b040")][rng.randi() % 3], 0.8)
			for k in 5:
				part(g, box(0.26, 0.04, 0.07), sm, Vector3(cos(k * TAU / 5.0) * 0.13, 0.03, sin(k * TAU / 5.0) * 0.13), Vector3(0, -k * TAU / 5.0, 0))
		2:
			var um := mat(Color("2a1e3a"), 0.6)
			part(g, sphere(0.14, 8), um, Vector3(0, 0.1, 0))
			for k in 12:
				var d := Vector3(cos(k * 2.4), 0.5 + 0.5 * sin(k * 1.3), sin(k * 2.4)).normalized()
				_rod(g, Vector3(0, 0.1, 0), Vector3(0, 0.1, 0) + d * 0.32, 0.01, um)
		_:
			var shm := mat(Color("f4e8dc"), 0.5)
			for k in 3:
				part(g, prism(0.18, 0.1, 0.14), shm, Vector3(rng.randf_range(-0.4, 0.4), 0.04, rng.randf_range(-0.4, 0.4)), Vector3(0.1, rng.randf() * TAU, 0))
	return g


## Sunken boat with a chest inside. Returns the node and the chest.
static func wreck() -> Dictionary:
	var g := Node3D.new()
	var wood := tm(Color("4e3a28"), "planks", 1.0, 0.8, 1.5)
	var rot := tm(Color("3a3226"), "bark", 1.0, 1.0, 1.5)
	part(g, box(7.0, 0.25, 2.0), wood, Vector3(0, 0.1, 0))
	for sd in [-1.0, 1.0]:
		part(g, box(6.6, 1.2, 0.14), wood, Vector3(0, 0.7, sd * 1.05), Vector3(sd * 0.25, 0, 0))
	for k in 7:
		var x := -3.0 + k * 1.0
		for sd in [-1.0, 1.0]:
			part(g, box(0.12, 1.5, 0.12), rot, Vector3(x, 0.8, sd * 1.15), Vector3(sd * 0.3, 0, 0))
	part(g, prism(1.6, 1.2, 2.0, 0.5), wood, Vector3(3.9, 0.6, 0), Vector3(0, 0, -PI / 2))
	part(g, cyl(0.1, 0.13, 3.6, 7), rot, Vector3(-1.2, 0.5, 2.2), Vector3(0.2, 0.4, PI / 2 - 0.15))
	var chest := Node3D.new()
	chest.position = Vector3(-1.4, 0.55, 0)
	g.add_child(chest)
	part(chest, box(0.9, 0.6, 0.6), tm(Color("7a5230"), "planks", 0.9, 1.6))
	part(chest, box(0.94, 0.08, 0.64), mat(Color("c9a24a"), 0.4, 0.7), Vector3(0, 0.15, 0))
	part(chest, box(0.94, 0.08, 0.64), mat(Color("c9a24a"), 0.4, 0.7), Vector3(0, -0.15, 0))
	g.rotation = Vector3(0.18, 0.0, 0.08)
	return {"node": g, "chest": chest}


## Ceramic water filter: a clay jar on a stand, dripping into a cup. No fuel needed.
static func filter() -> Dictionary:
	var g := Node3D.new()
	var wood := tm(Color("7a5232"), "planks", 0.9, 2.0)
	var clay := tm(Color("b4673f"), "soil", 0.9, 2.0, 0.6)
	for p in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
		part(g, box(0.07, 0.6, 0.07), wood, Vector3(p.x, 0.3, p.y))
	part(g, box(0.75, 0.05, 0.75), wood, Vector3(0, 0.6, 0))
	part(g, cyl(0.3, 0.2, 0.55, 14), clay, Vector3(0, 0.9, 0))
	part(g, cyl(0.33, 0.33, 0.06, 14), mat(Color("8c4a30")), Vector3(0, 1.18, 0))
	part(g, cyl(0.025, 0.025, 0.15, 6), clay, Vector3(0, 0.55, 0))
	part(g, cyl(0.1, 0.08, 0.18, 8), mat(Color("eaf6fb")), Vector3(0, 0.1, 0))
	bake(g)
	return {"node": g}


## Rain catcher: a plastic tarp sagging into a funnel over a barrel.
static func rain_catcher() -> Dictionary:
	var g := Node3D.new()
	var wood := tm(Color("7a5232"), "bark", 0.9, 2.0)
	for p in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
		part(g, cyl(0.04, 0.05, 1.5, 6), wood, Vector3(p.x, 0.75, p.y))
	var tarp := tmat(Color("3d7fb5"), "cloth", 0.55, 1.5, 0.8)
	tarp.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var panel := part(g, box(1.1, 0.02, 0.95), tarp, Vector3(cos(a) * 0.38, 1.28, sin(a) * 0.38), Vector3(0, -a, 0))
		panel.rotation = Vector3(0, -a + PI / 2.0, 0)
		panel.rotate_object_local(Vector3.RIGHT, -0.38)
	part(g, cyl(0.08, 0.05, 0.4, 8), tarp, Vector3(0, 1.0, 0))
	part(g, cyl(0.24, 0.24, 0.55, 16), tm(Color("2b7bc0"), "plastic", 0.45, 2.0), Vector3(0, 0.3, 0))
	var level := part(g, cyl(0.22, 0.22, 0.02, 14), mat(Color("8fd0ef"), 0.1), Vector3(0, 0.05, 0))
	level.name = "Level"
	bake(g, [level])
	return {"node": g, "level_node": level}


# ---------------------------------------------------------------- farm & animals
# Farm pieces are one raft tile each. Fences / borders are drawn only on edges that don't touch a
# tile of the same kind (farm_edges), so neighbouring tiles read as one big field or pen.

static var _soil_dry: StandardMaterial3D
static var _soil_wet: StandardMaterial3D


static func soil_mat(wet: bool) -> StandardMaterial3D:
	if _soil_dry == null:
		_soil_dry = tmat(Color("6b4a32"), "soil", 1.0, 1.0, 1.5)
		_soil_wet = tmat(Color("3a281c"), "soil", 0.55, 1.0, 1.5)
	return _soil_wet if wet else _soil_dry


static func field_tile() -> Dictionary:
	var g := Node3D.new()
	var soil := part(g, box(1.86, 0.16, 1.86), soil_mat(false), Vector3(0, 0.1, 0))
	soil.name = "Soil"
	for i in 4:
		var x := -0.45 + (i % 2) * 0.9
		var z := -0.45 + floorf(i / 2.0) * 0.9
		part(g, cyl(0.2, 0.22, 0.04, 10), mat(Color("4e3526"), 1.0), Vector3(x, 0.19, z))
	bake(g, [soil])
	_edges_node(g)
	return {"node": g}


## Kelp farm: a frame floating on the sea beside the raft (one water cell), ropes across it,
## orange buoys at the corners; kelp hangs from the ropes down into the water and grows longer.
## The node sits at the water line. Built at full TILE size (not stretched like deck pieces).
static func kelp_tile() -> Dictionary:
	var g := Node3D.new()
	var h := TILE * 0.5 - 0.12
	var wood: StandardMaterial3D = shared("kelp_wood", func(): return tmat(Color("8a6a40"), "bark", 0.9, 2.0))
	var rope: StandardMaterial3D = shared("kelp_rope", func(): return tmat(Color("d8c49a"), "rope", 0.95, 8.0))
	var buoy: StandardMaterial3D = shared("kelp_buoy", func(): return mat(Color("ff8a1c"), 0.5))
	var band: StandardMaterial3D = shared("kelp_band", func(): return mat(Color("f4ecd6"), 0.6))
	# bamboo-like frame: two long floats and two cross bars
	for z in [-h, h]:
		part(g, cyl(0.09, 0.09, TILE - 0.1, 8), wood, Vector3(0, 0.02, z), Vector3(0, 0, PI / 2))
	for x in [-h, h]:
		part(g, cyl(0.07, 0.07, TILE - 0.3, 8), wood, Vector3(x, 0.05, 0), Vector3(PI / 2, 0, 0))
	for x in [-h, h]:
		for z in [-h, h]:
			part(g, sphere(0.27, 12), buoy, Vector3(x, 0.1, z), Vector3.ZERO, Vector3(1, 0.85, 1))
			part(g, cyl(0.275, 0.275, 0.06, 12), band, Vector3(x, 0.1, z))
	# grow lines across the frame
	var lines := [-0.55, 0.0, 0.55]
	for lx in lines:
		part(g, cyl(0.02, 0.02, TILE - 0.3, 5), rope, Vector3(lx * TILE / 2.0, 0.07, 0), Vector3(PI / 2, 0, 0))
	var kelp := Node3D.new()
	kelp.name = "Kelp"
	g.add_child(kelp)
	var km: StandardMaterial3D = shared("kelp_leaf", func():
		var m := mat(Color("6b8a2c"), 0.7)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)
	var km2: StandardMaterial3D = shared("kelp_leaf2", func():
		var m := mat(Color("4f6e22"), 0.7)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)
	# blades hang from the lines: tops at the surface, the node's y scale makes them longer
	for i in 12:
		var lx: float = lines[i % 3] * TILE / 2.0
		var z := -h + 0.35 + (floorf(i / 3.0)) * (2.0 * h - 0.7) / 3.0
		var blade := part(kelp, box(0.16, 1.0, 0.02), km if i % 2 == 0 else km2, Vector3(lx + 0.05 * sin(i * 1.7), -0.5, z), Vector3(0.08 * cos(i), i * 0.7, 0.12 * sin(i * 2.3)))
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kelp.visible = false
	# fronds floating at the surface show from the deck how far along it is
	var tips := Node3D.new()
	tips.name = "Tips"
	g.add_child(tips)
	for i in 9:
		var lx: float = lines[i % 3] * TILE / 2.0
		part(tips, box(0.28, 0.015, 0.1), km, Vector3(lx + 0.12, 0.09, -h + 0.5 + floorf(i / 3.0) * (2.0 * h - 1.0) / 2.0), Vector3(0, i * 1.1, 0))
	bake(kelp, [], false)
	bake(g, [kelp, tips])
	tips.visible = false
	_edges_node(g)
	return {"node": g}


static func coop_tile() -> Dictionary:
	var g := Node3D.new()
	part(g, box(1.86, 0.04, 1.86), tm(Color("d9c27a"), "thatch", 1.0, 1.5, 0.8), Vector3(0, 0.08, 0))
	part(g, cyl(0.22, 0.18, 0.1, 10), mat(Color("c9a65a"), 1.0), Vector3(0.6, 0.13, -0.6))
	var eggs := Node3D.new()
	eggs.name = "Eggs"
	g.add_child(eggs)
	for i in 3:
		var e := part(eggs, sphere(0.045, 7), mat(Color("f3e6cf")), Vector3(0.54 + i * 0.06, 0.2, -0.6 + (i % 2) * 0.05), Vector3.ZERO, Vector3(1, 1.25, 1))
		e.visible = false
	bake(g, [eggs])
	_edges_node(g)
	return {"node": g}


static func pen_tile() -> Dictionary:
	var g := Node3D.new()
	part(g, box(1.86, 0.03, 1.86), tm(Color("b8a466"), "thatch", 1.0, 1.5, 0.8), Vector3(0, 0.08, 0))
	part(g, box(0.36, 0.12, 0.18), mat(Color("7a5232")), Vector3(-0.6, 0.14, -0.62))
	part(g, box(0.3, 0.04, 0.12), mat(Color("5a7a2c"), 0.9), Vector3(-0.6, 0.21, -0.62))
	bake(g)
	_edges_node(g)
	return {"node": g}


## Small thatched hut that sits on the first tile of each chicken yard.
static func hen_house() -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(-0.35, 0.08, -0.35)
	var wood := tm(Color("8a5a33"), "planks", 0.9, 2.0)
	part(g, box(0.9, 0.45, 0.7), wood, Vector3(0, 0.25, 0))
	part(g, box(0.26, 0.3, 0.02), mat(Color("2c1d12")), Vector3(0, 0.17, 0.36))
	part(g, prism(1.05, 0.35, 0.85), tm(Color("d6b86a"), "thatch", 1.0, 2.0), Vector3(0, 0.65, 0))
	bake(g)
	return g


static func _edges_node(g: Node3D) -> void:
	var e := Node3D.new()
	e.name = "Edges"
	g.add_child(e)


## Rebuild a farm tile's border; open[i] is true where DIRS[i] (+x, -x, +z, -z) joins the same kind.
static func farm_edges(tile_node: Node3D, kind: String, open: Array) -> void:
	var e: Node3D = tile_node.get_node("Edges")
	for c in e.get_children():
		e.remove_child(c)
		c.queue_free()
	if kind == "kelpfarm":
		return   # the floating frame has its own edges
	var wood: StandardMaterial3D = shared("farm_wood", func(): return tmat(Color("7a5232"), "planks", 0.9, 2.0))
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for i in 4:
		if open[i]:
			continue
		var d: Vector2 = dirs[i]
		var along_x := d.x == 0.0      # edge runs along x when it faces ±z
		var at := Vector3(d.x * 0.93, 0, d.y * 0.93)
		match kind:
			"field":
				part(e, box(1.96 if along_x else 0.08, 0.24, 0.08 if along_x else 1.96), wood, at + Vector3(0, 0.14, 0))
			"kelpfarm":
				part(e, cyl(0.06, 0.06, 1.96, 6), wood, at + Vector3(0, 0.12, 0), Vector3(0, 0, PI / 2) if along_x else Vector3(PI / 2, 0, 0))
			"coop", "pen":
				var hgt := 0.45 if kind == "coop" else 0.75
				for k in 3:
					var t := -0.9 + k * 0.9
					part(e, box(0.06, hgt, 0.06), wood, at + (Vector3(t, hgt / 2.0, 0) if along_x else Vector3(0, hgt / 2.0, t)))
				for y in ([0.18, 0.38] if kind == "coop" else [0.3, 0.62]):
					part(e, box(1.9 if along_x else 0.04, 0.05, 0.04 if along_x else 1.9), wood, at + Vector3(0, y, 0))
	bake(e, [], false)


static func set_crop(plant: Node3D, crop: String, grow: float, dead: bool) -> void:
	for c in plant.get_children():
		plant.remove_child(c)
		c.queue_free()
	if crop == "":
		return
	var leaf := mat(Color("7a5a2e") if dead else Color("4f9a3a"), 0.8)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var k := clampf(grow, 0.15, 1.0)
	var ripe := grow >= 1.0 and not dead
	match crop:
		"potato":
			for i in 5:
				var a := TAU * i / 5.0
				part(plant, box(0.12, 0.02, 0.32 * k), leaf, Vector3(cos(a) * 0.1 * k, 0.12 * k, sin(a) * 0.1 * k), Vector3(0.5, -a, 0))
			part(plant, cyl(0.02, 0.025, 0.3 * k, 5), leaf, Vector3(0, 0.15 * k, 0))
			if ripe:
				for i in 3:
					var a := TAU * i / 3.0 + 0.4
					part(plant, sphere(0.07, 7), mat(Color("b08a55")), Vector3(cos(a) * 0.2, 0.03, sin(a) * 0.2), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
		"tomato":
			part(plant, cyl(0.015, 0.015, 0.8, 5), mat(Color("9b7a4a")), Vector3(0.12, 0.4, 0))
			for i in 4:
				part(plant, sphere(0.12 * k + 0.03, 7), leaf, Vector3(sin(i * 1.7) * 0.08, (0.15 + i * 0.13) * k, cos(i * 1.7) * 0.08), Vector3.ZERO, Vector3(1.2, 0.7, 1.2))
			if ripe:
				for i in 4:
					part(plant, sphere(0.055, 8), mat(Color("d8392b"), 0.5), Vector3(sin(i * 2.3) * 0.13, 0.22 + i * 0.1, cos(i * 2.3) * 0.13))
		"melon":
			for i in 4:
				var a := TAU * i / 4.0
				part(plant, box(0.22 * k, 0.02, 0.18 * k), leaf, Vector3(cos(a) * 0.2 * k, 0.03, sin(a) * 0.2 * k), Vector3(0, -a, 0))
			if ripe or grow > 0.5:
				var s := 0.12 + 0.16 * clampf((grow - 0.5) * 2.0, 0.0, 1.0)
				part(plant, sphere(s, 12), mat(Color("3b7a2e"), 0.6), Vector3(0.08, s * 0.8, 0.05), Vector3.ZERO, Vector3(1.15, 0.95, 1.0))
	bake(plant, [], false)


static func chicken() -> Node3D:
	var g := Node3D.new()
	var white := mat(Color("f2efe6"), 0.9)
	part(g, sphere(0.16, 10), white, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.25))
	part(g, sphere(0.09, 8), white, Vector3(0, 0.36, 0.14))
	part(g, prism(0.06, 0.07, 0.05), mat(Color("d83a2a")), Vector3(0, 0.46, 0.13))
	part(g, prism(0.04, 0.05, 0.06), mat(Color("e8a23a")), Vector3(0, 0.35, 0.24), Vector3(PI / 2, 0, 0))
	part(g, box(0.1, 0.06, 0.12), white, Vector3(0, 0.26, -0.2), Vector3(0.6, 0, 0))
	for x in [-0.05, 0.05]:
		part(g, cyl(0.012, 0.012, 0.12, 4), mat(Color("e8a23a")), Vector3(x, 0.06, 0))
	bake(g)
	return g


static func goat() -> Node3D:
	var g := Node3D.new()
	var fur := mat(Color("e9e2d4"), 1.0)
	var dark := mat(Color("4a3a2c"))
	part(g, box(0.75, 0.38, 0.32), fur, Vector3(0, 0.6, 0))
	for p in [Vector2(-0.28, -0.1), Vector2(-0.28, 0.1), Vector2(0.28, -0.1), Vector2(0.28, 0.1)]:
		part(g, box(0.07, 0.42, 0.07), fur, Vector3(p.x, 0.21, p.y))
	var head := Node3D.new()
	head.position = Vector3(0.42, 0.85, 0)
	g.add_child(head)
	part(head, box(0.26, 0.2, 0.18), fur, Vector3(0.06, 0, 0), Vector3(0, 0, -0.4))
	for z in [-0.06, 0.06]:
		part(head, cyl(0.015, 0.03, 0.22, 5), dark, Vector3(-0.02, 0.15, z), Vector3(0, 0, 0.6))
		part(head, sphere(0.02, 5), mat(Color("111111")), Vector3(0.1, 0.04, z * 1.4))
	part(head, box(0.05, 0.12, 0.05), fur, Vector3(0.14, -0.14, 0))
	part(g, box(0.08, 0.1, 0.06), fur, Vector3(-0.4, 0.72, 0), Vector3(0, 0, 0.8))
	bake(g)
	return g


## A drifting wooden cage with a chicken inside (hook it to get the chicken).
static func cage() -> Node3D:
	var g := Node3D.new()
	var wood := mat(Color("8a5a33"))
	part(g, box(0.7, 0.06, 0.55), wood, Vector3(0, 0.0, 0))
	part(g, box(0.7, 0.06, 0.55), wood, Vector3(0, 0.55, 0))
	for x in [-0.32, -0.11, 0.11, 0.32]:
		for z in [-0.25, 0.25]:
			part(g, box(0.04, 0.55, 0.04), wood, Vector3(x, 0.28, z))
	var hen := chicken()
	hen.position.y = 0.02
	g.add_child(hen)
	return g


# ---------------------------------------------------------------- trade boats
# Hulls are lofted from cross-sections: a U-shaped section whose half-width narrows to a
# pointed stem at the bow, a keel that sweeps up at the bow, and a sheer line that rises at
# both ends. Planking, the painted stripe and the bottom paint are vertex colours.

static func _hw(t: float) -> float:
	if t <= 0.45:
		return 0.72 + 0.28 * sin(t / 0.45 * PI / 2.0)
	return pow(maxf(0.0, cos((t - 0.45) / 0.55 * PI / 2.0)), 0.7)


static func _keel(t: float, d: float) -> float:
	return -d * (0.88 + 0.12 * sin(PI * t)) + d * 0.6 * pow(maxf(0.0, (t - 0.68) / 0.32), 2.0)


static func _sheer(t: float, s: float) -> float:
	return s * (1.0 + 0.22 * pow((t - 0.45) * 2.0, 2.0) + 0.45 * pow(maxf(0.0, (t - 0.62) / 0.38), 2.0))


static func _hull_pt(t: float, v: float, L: float, W: float, d: float, s: float) -> Vector3:
	var k := _keel(t, d)
	var top := _sheer(t, s)
	return Vector3(W * 0.5 * _hw(t) * v, k + (top - k) * pow(absf(v), 2.4), (t - 0.5) * L)


## Adds triangle a-b-c facing `out` (Godot's front face is clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		var tv := b; b = c; c = tv
		var tn := nb; nb = nc; nc = tn
		var tc := cb; cb = cc; cc = tc
	for q in [[a, na, ca], [b, nb, cb], [c, nc, cc]]:
		st.set_normal(q[1])
		st.set_color((q[2] as Color).srgb_to_linear())   # stored linear: the web renderer ignores vertex_color_is_srgb
		st.add_vertex(q[0])


static func _hull(g: Node3D, L: float, W: float, d: float, s: float, plank: Color, stripe: Color, bottom: Color, inner: Color, deck_col: Color) -> float:
	const NT := 30
	const NV := 26
	var pts := []
	var nrm := []
	for i in NT + 1:
		var t := float(i) / NT
		var row := []
		var nrow := []
		for j in NV + 1:
			var v := -1.0 + 2.0 * j / NV
			var p := _hull_pt(t, v, L, W, d, s)
			var dt := _hull_pt(minf(1.0, t + 0.01), v, L, W, d, s) - _hull_pt(maxf(0.0, t - 0.01), v, L, W, d, s)
			var dv := _hull_pt(t, clampf(v + 0.02, -1.0, 1.0), L, W, d, s) - _hull_pt(t, clampf(v - 0.02, -1.0, 1.0), L, W, d, s)
			var n := dt.cross(dv)
			if n.length() < 1e-6:
				n = Vector3(signf(v), 0, 0.3)
			n = n.normalized()
			var mid := (_keel(t, d) + _sheer(t, s)) * 0.5
			if n.dot(Vector3(p.x, p.y - mid, 0.15 * (t - 0.5))) < 0.0:
				n = -n
			row.append(p)
			nrow.append(n)
		pts.append(row)
		nrm.append(nrow)
	var colour := func(p: Vector3, t: float) -> Color:
		var top := _sheer(t, s)
		if p.y < 0.02:
			return bottom
		if p.y > top - 0.11 * s / 0.5:
			return stripe
		return plank if int(floorf((p.y + 2.0) / 0.1)) % 2 == 0 else plank.darkened(0.1)
	# outer skin and inner skin (offset along the normal, facing in)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ins := SurfaceTool.new()
	ins.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th := 0.05
	for i in NT:
		for j in NV:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i + 1][j]
			var c: Vector3 = pts[i + 1][j + 1]
			var e: Vector3 = pts[i][j + 1]
			var na: Vector3 = nrm[i][j]
			var nb: Vector3 = nrm[i + 1][j]
			var nc: Vector3 = nrm[i + 1][j + 1]
			var ne: Vector3 = nrm[i][j + 1]
			var out := (na + nb + nc + ne).normalized()
			var ta := float(i) / NT
			var tb := float(i + 1) / NT
			_tri(st, a, b, c, na, nb, nc, colour.call(a, ta), colour.call(b, tb), colour.call(c, tb), out)
			_tri(st, a, c, e, na, nc, ne, colour.call(a, ta), colour.call(c, tb), colour.call(e, ta), out)
			_tri(ins, a - na * th, b - nb * th, c - nc * th, -na, -nb, -nc, inner, inner, inner, -out)
			_tri(ins, a - na * th, c - nc * th, e - ne * th, -na, -nc, -ne, inner, inner, inner, -out)
	# gunwale cap along both top edges
	for side in [0, NV]:
		for i in NT:
			var a: Vector3 = pts[i][side]
			var b: Vector3 = pts[i + 1][side]
			var ai: Vector3 = a - nrm[i][side] * th
			var bi: Vector3 = b - nrm[i + 1][side] * th
			var up := Vector3.UP
			var cap := stripe.darkened(0.25)
			_tri(st, a, b, bi, up, up, up, cap, cap, cap, up)
			_tri(st, a, bi, ai, up, up, up, cap, cap, cap, up)
	# transom (flat stern)
	var centre := Vector3(0, (_keel(0.0, d) + _sheer(0.0, s)) * 0.55, -0.5 * L)
	for j in NV:
		var a: Vector3 = pts[0][j]
		var b: Vector3 = pts[0][j + 1]
		var back := Vector3.BACK * -1.0
		var tc := plank.darkened(0.05)
		_tri(st, centre, a, b, back, back, back, tc, colour.call(a, 0.0), colour.call(b, 0.0), back)
	# top of the transom
	var t0a: Vector3 = pts[0][0]
	var t0b: Vector3 = pts[0][NV]
	_tri(st, t0a, t0b, centre, Vector3.BACK * -1.0, Vector3.BACK * -1.0, Vector3.BACK * -1.0, plank, plank, plank, Vector3.BACK * -1.0)
	var hm := MeshInstance3D.new()
	hm.mesh = st.commit()
	var mm := StandardMaterial3D.new()
	mm.vertex_color_use_as_albedo = true
	mm.roughness = 0.75
	hm.material_override = mm
	g.add_child(hm)
	var im := MeshInstance3D.new()
	im.mesh = ins.commit()
	var imat := StandardMaterial3D.new()
	imat.vertex_color_use_as_albedo = true
	imat.roughness = 0.9
	im.material_override = imat
	g.add_child(im)
	# deck: planks running fore and aft, at a height just above the waterline
	var dy := _keel(0.45, d) + (_sheer(0.45, s) - _keel(0.45, d)) * 0.42
	var ds := SurfaceTool.new()
	ds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in NT:
		var t0 := float(i) / NT
		var t1 := float(i + 1) / NT
		var w0 := _deck_half(t0, dy, W, d, s) - th
		var w1 := _deck_half(t1, dy, W, d, s) - th
		if w0 <= 0.02 and w1 <= 0.02:
			continue
		for k in 8:
			var u0 := -1.0 + k / 4.0
			var u1 := -1.0 + (k + 1) / 4.0
			var col := deck_col if k % 2 == 0 else deck_col.darkened(0.08)
			var a := Vector3(w0 * u0, dy, (t0 - 0.5) * L)
			var b := Vector3(w1 * u0, dy, (t1 - 0.5) * L)
			var c := Vector3(w1 * u1, dy, (t1 - 0.5) * L)
			var e := Vector3(w0 * u1, dy, (t0 - 0.5) * L)
			var up := Vector3.UP
			_tri(ds, a, b, c, up, up, up, col, col, col, up)
			_tri(ds, a, c, e, up, up, up, col, col, col, up)
	var dm := MeshInstance3D.new()
	dm.mesh = ds.commit()
	dm.material_override = mm
	g.add_child(dm)
	return dy


static func _deck_half(t: float, y: float, W: float, d: float, s: float) -> float:
	var k := _keel(t, d)
	var top := _sheer(t, s)
	if y <= k:
		return 0.0
	var v := pow(clampf((y - k) / (top - k), 0.0, 1.0), 1.0 / 2.4)
	return W * 0.5 * _hw(t) * v


## A thin pole from a to b.
static func _rod(g: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = cyl(r, r, a.distance_to(b), 6)
	n.material_override = m
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	n.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	g.add_child(n)
	return n


## A billowing sail stretched over four corners (tack, throat, peak, clew).
static func _sail(g: Node3D, tack: Vector3, throat: Vector3, peak: Vector3, clew: Vector3, col: Color, billow: float, band := Color(0, 0, 0, 0)) -> void:
	const N := 10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := (throat - tack).cross(clew - tack).normalized()
	var grid := []
	for i in N + 1:
		var row := []
		for j in N + 1:
			var u := float(i) / N
			var v := float(j) / N
			var p := tack.lerp(clew, u).lerp(throat.lerp(peak, u), v)
			p += side * billow * sin(PI * u) * sin(PI * v)
			row.append(p)
		grid.append(row)
	for i in N:
		for j in N:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]
			var e: Vector3 = grid[i][j + 1]
			var n := (b - a).cross(e - a).normalized()
			if n.dot(side) < 0.0:
				n = -n
			var cc := col
			if band.a > 0.0 and j >= 4 and j <= 5:
				cc = band
			_tri(st, a, b, c, n, n, n, cc, cc, cc, n)
			_tri(st, a, c, e, n, n, n, cc, cc, cc, n)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat_ := StandardMaterial3D.new()
	mat_.vertex_color_use_as_albedo = true
	mat_.roughness = 0.95
	mat_.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat_
	g.add_child(m)


static func _skipper(g: Node3D, at: Vector3, coat: Color, beard: bool) -> void:
	var w := Node3D.new()
	w.position = at
	g.add_child(w)
	var skin := mat(Color("d9a57a"))
	part(w, cyl(0.06, 0.07, 0.42, 6), mat(Color("3b3a4a")), Vector3(-0.08, 0.21, 0))
	part(w, cyl(0.06, 0.07, 0.42, 6), mat(Color("3b3a4a")), Vector3(0.08, 0.21, 0))
	part(w, cyl(0.15, 0.19, 0.5, 10), mat(coat), Vector3(0, 0.66, 0))
	for x in [-0.22, 0.22]:
		part(w, cyl(0.045, 0.05, 0.42, 6), mat(coat), Vector3(x, 0.66, 0.04), Vector3(0.3, 0, -signf(x) * 0.25))
	part(w, sphere(0.13, 12), skin, Vector3(0, 1.04, 0))
	if beard:
		part(w, sphere(0.1, 10), mat(Color("ece7dc")), Vector3(0, 0.97, 0.07), Vector3.ZERO, Vector3(1.0, 1.1, 0.8))
	part(w, cyl(0.1, 0.13, 0.1, 12), mat(Color("cdb06a")), Vector3(0, 1.17, 0))
	part(w, cyl(0.3, 0.3, 0.02, 16), mat(Color("d9bd74")), Vector3(0, 1.13, 0))


static func _barrel(g: Node3D, at: Vector3, body: Material, band: Material, h := 0.62, r := 0.22) -> void:
	part(g, cyl(r * 0.92, r * 0.92, h, 14), body, at + Vector3(0, h / 2.0, 0))
	part(g, cyl(r, r, h * 0.5, 14), body, at + Vector3(0, h / 2.0, 0))
	for y in [0.1, 0.5, 0.9]:
		part(g, cyl(r * 1.01 if y == 0.5 else r * 0.95, r * 1.01 if y == 0.5 else r * 0.95, 0.03, 14), band, at + Vector3(0, h * y, 0))


## Turn a point about a vertical mast at `pivot` (sails braced round to the wind).
static func _brace(p: Vector3, pivot: Vector3, ang: float) -> Vector3:
	return pivot + (p - pivot).rotated(Vector3.UP, ang)


## A visiting trade boat, bow along +Z: "fisher" (small skiff), "water" (barrel boat), "ark" (animal ship).
static func trade_boat(kind: String) -> Node3D:
	var g := Node3D.new()
	var wood := mat(Color("6e4a2e"), 0.85)
	var rope := mat(Color("cdb68a"), 0.95)
	match kind:
		"fisher":
			var dy := _hull(g, 4.4, 1.55, 0.45, 0.5, Color("8c5d38"), Color("2f6f8f"), Color("7a2e22"), Color("a7784c"), Color("b98f5e"))
			_rod(g, Vector3(0, dy, 0.55), Vector3(0, dy + 2.6, 0.55), 0.05, wood)
			# lateen yard and sail
			_rod(g, Vector3(0.08, dy + 0.5, 1.75), Vector3(0.08, dy + 3.5, -1.25), 0.035, wood)
			_sail(g, Vector3(0.1, dy + 0.55, 1.6), Vector3(0.1, dy + 2.2, 0.55), Vector3(0.1, dy + 3.4, -1.15), Vector3(0.1, dy + 0.55, -1.05),
				Color("c45a30"), 0.28, Color("e0a064"))
			_rod(g, Vector3(0.1, dy + 0.55, -1.05), Vector3(0.0, dy + 0.1, -1.6), 0.012, rope)
			# oars across the thwart, a thwart, net, basket, lantern
			part(g, box(1.45, 0.06, 0.22), wood, Vector3(0, dy + 0.3, -0.3))
			_rod(g, Vector3(-0.9, dy + 0.38, -0.6), Vector3(0.6, dy + 0.42, 0.9), 0.03, mat(Color("a98458")))
			var net := mat(Color("4f7a5a"), 1.0)
			for k in 4:
				part(g, sphere(0.2, 8), net, Vector3(-0.2 + k * 0.12, dy + 0.12, 1.05 - k * 0.1), Vector3(0, k, 0), Vector3(1.3, 0.45, 1.0))
			part(g, cyl(0.2, 0.15, 0.24, 12), mat(Color("b8965a"), 1.0), Vector3(0.35, dy + 0.12, -0.9))
			for k in 3:
				part(g, box(0.06, 0.04, 0.24), mat(Color("9fb4c0"), 0.4, 0.3), Vector3(0.3 + k * 0.05, dy + 0.26, -0.9), Vector3(0, k * 0.6, 0.3))
			_rod(g, Vector3(-0.45, dy, -1.7), Vector3(-0.45, dy + 1.3, -1.9), 0.025, wood)
			var lamp := mat(Color("ffcc66"), 0.3)
			lamp.emission_enabled = true
			lamp.emission = Color("ffb347")
			lamp.emission_energy_multiplier = 1.5
			part(g, box(0.14, 0.18, 0.14), lamp, Vector3(-0.45, dy + 1.22, -1.93))
			_skipper(g, Vector3(0.1, dy, -1.15), Color("8a6b3a"), true)
		"water":
			var dy := _hull(g, 5.2, 2.0, 0.5, 0.55, Color("e8eef2"), Color("2c6fb0"), Color("1f3550"), Color("c9d3da"), Color("b08a5a"))
			var blue := mat(Color("2b7bc0"), 0.45)
			var band := mat(Color("3a4148"), 0.5, 0.6)
			for k in 6:
				_barrel(g, Vector3(-0.42 + (k % 2) * 0.84, dy, -0.3 + floorf(k / 2.0) * 0.62), blue, band)
			_barrel(g, Vector3(0, dy + 0.62, 0.0), blue, band)
			# awning over the barrels
			for x in [-0.8, 0.8]:
				for z in [-0.8, 1.2]:
					_rod(g, Vector3(x, dy, z), Vector3(x, dy + 1.55, z), 0.03, wood)
			_sail(g, Vector3(-0.85, dy + 1.55, -0.8), Vector3(-0.85, dy + 1.55, 1.2), Vector3(0.85, dy + 1.55, 1.2), Vector3(0.85, dy + 1.55, -0.8),
				Color("f2f5f7"), 0.12, Color("2c6fb0"))
			# square sail forward
			_rod(g, Vector3(0, dy, 1.7), Vector3(0, dy + 3.0, 1.7), 0.05, wood)
			var mp := Vector3(0, 0, 1.7)
			var br := 0.6
			_rod(g, _brace(Vector3(-0.95, dy + 2.75, 1.68), mp, br), _brace(Vector3(0.95, dy + 2.75, 1.68), mp, br), 0.03, wood)
			_sail(g, _brace(Vector3(-0.85, dy + 1.0, 1.62), mp, br), _brace(Vector3(-0.92, dy + 2.72, 1.66), mp, br),
				_brace(Vector3(0.92, dy + 2.72, 1.66), mp, br), _brace(Vector3(0.85, dy + 1.0, 1.62), mp, br),
				Color("dcebf5"), -0.25, Color("2c6fb0"))
			part(g, box(0.02, 0.22, 0.36), mat(Color("2c6fb0")), Vector3(0, dy + 3.1, 1.52))
			_rod(g, Vector3(0, dy + 3.0, 1.7), Vector3(0, dy + 0.45, -2.4), 0.012, rope)
			_skipper(g, Vector3(0.5, dy, -1.6), Color("2f5f8a"), false)
		"ark":
			var dy := _hull(g, 7.8, 3.0, 0.75, 0.7, Color("7b5236"), Color("3e7d4a"), Color("3a3f45"), Color("9b7650"), Color("b69064"))
			# cabin aft with windows and a green roof
			var wall := mat(Color("d8bf8a"))
			part(g, box(2.2, 1.25, 2.4), wall, Vector3(0, dy + 0.62, -2.1))
			var glass := mat(Color("3b5566"), 0.2)
			for x in [-1.105, 1.105]:
				for z in [-2.7, -1.5]:
					part(g, box(0.02, 0.36, 0.42), glass, Vector3(x, dy + 0.78, z))
			part(g, box(0.5, 0.8, 0.02), mat(Color("5a3f28")), Vector3(0, dy + 0.42, -0.89))
			part(g, prism(2.6, 0.75, 2.8), mat(Color("4f8a3e"), 0.85), Vector3(0, dy + 1.62, -2.1))
			# mast with a big square sail
			_rod(g, Vector3(0, dy, 0.6), Vector3(0, dy + 4.6, 0.6), 0.08, wood)
			var mp := Vector3(0, 0, 0.6)
			var br := 0.6
			_rod(g, _brace(Vector3(-1.55, dy + 4.2, 0.57), mp, br), _brace(Vector3(1.55, dy + 4.2, 0.57), mp, br), 0.045, wood)
			_sail(g, _brace(Vector3(-1.35, dy + 1.5, 0.5), mp, br), _brace(Vector3(-1.5, dy + 4.15, 0.55), mp, br),
				_brace(Vector3(1.5, dy + 4.15, 0.55), mp, br), _brace(Vector3(1.35, dy + 1.5, 0.5), mp, br),
				Color("efe2c0"), -0.4, Color("c9a65a"))
			part(g, box(0.02, 0.3, 0.5), mat(Color("3e7d4a")), Vector3(0, dy + 4.75, 0.35))
			for x in [-1.3, 1.3]:
				_rod(g, Vector3(0, dy + 4.4, 0.6), Vector3(x, dy + 0.4, 0.4), 0.012, rope)
			_rod(g, Vector3(0, dy + 4.4, 0.6), Vector3(0, dy + 0.7, 3.7), 0.012, rope)
			# animal pen on the foredeck
			var fence := mat(Color("8a5a33"))
			for z in [1.5, 3.0]:
				part(g, box(2.0, 0.06, 0.06), fence, Vector3(0, dy + 0.45, z))
				part(g, box(2.0, 0.06, 0.06), fence, Vector3(0, dy + 0.25, z))
			for x in [-1.0, 1.0]:
				part(g, box(0.06, 0.06, 1.5), fence, Vector3(x * 0.95, dy + 0.45, 2.25))
			part(g, box(0.7, 0.35, 0.45), mat(Color("d9c27a"), 1.0), Vector3(0.55, dy + 0.18, 2.6))
			var hen := chicken()
			hen.position = Vector3(-0.5, dy, 2.0)
			g.add_child(hen)
			var hen2 := chicken()
			hen2.position = Vector3(-0.15, dy, 2.6)
			hen2.rotation.y = 1.4
			g.add_child(hen2)
			var gt := goat()
			gt.scale = Vector3.ONE * 0.75
			gt.position = Vector3(0.35, dy, 1.95)
			gt.rotation.y = -0.6
			g.add_child(gt)
			_barrel(g, Vector3(1.0, dy, -0.4), mat(Color("8a5a33")), mat(Color("3a4148"), 0.5, 0.6), 0.5, 0.2)
			_skipper(g, Vector3(-0.7, dy, -0.5), Color("3e7d4a"), true)
	bake(g)
	return g


# ---------------------------------------------------------------- shelter pieces
# Built along X, standing on y = 0, centred on the tile edge (z = 0). Wall height leaves room
# for the upper floor slab.

const WALL_H := 2.26


static var _boards_cache: Array = []


static func _board_mats() -> Array:
	if _boards_cache.is_empty():
		for c in [Color("9a7048"), Color("8c6440"), Color("a57a50"), Color("94693f")]:
			var m := tmat(c, "planks", 0.9, 1.0, 1.2)
			m.uv1_offset = Vector3(randf(), randf(), randf())
			_boards_cache.append(m)
	return _boards_cache


## Vertical boards filling x0..x1 between heights y0..y1.
static func _boards(g: Node3D, x0: float, x1: float, y0: float, y1: float, seed_i := 0) -> void:
	var mats: Array = _board_mats()
	var n := maxi(1, roundi((x1 - x0) / 0.38))
	var w := (x1 - x0) / n
	for i in n:
		var hjit := 0.03 * sin(float(i + seed_i) * 2.7)
		part(g, box(w - 0.02, y1 - y0 + hjit, 0.07), mats[(i + seed_i) % mats.size()], Vector3(x0 + w * (i + 0.5), (y0 + y1 + hjit) / 2.0, 0))


static func wall_piece(kind: String) -> Node3D:
	var g := Node3D.new()
	var dark: StandardMaterial3D = shared("batten", func(): return tmat(Color("6b4a2e"), "planks", 0.9, 1.5))
	var rope: StandardMaterial3D = shared("lash", func(): return tmat(Color("cdb68a"), "rope", 0.95, 6.0, 1.5))
	match kind:
		"wall":
			_boards(g, -0.97, 0.97, 0.0, WALL_H)
		"window":
			_boards(g, -0.97, -0.5, 0.0, WALL_H)
			_boards(g, 0.5, 0.97, 0.0, WALL_H, 1)
			_boards(g, -0.5, 0.5, 0.0, 0.9, 2)
			_boards(g, -0.5, 0.5, 1.72, WALL_H, 3)
			for x in [-0.52, 0.52]:
				part(g, box(0.06, 0.92, 0.12), dark, Vector3(x, 1.31, 0))
			for y in [0.9, 1.72]:
				part(g, box(1.1, 0.06, 0.14), dark, Vector3(0, y, 0))
			# shutters swung open on the outside
			for sx in [-1.0, 1.0]:
				var sh := Node3D.new()
				sh.position = Vector3(sx * 0.5, 1.31, 0.08)
				sh.rotation.y = sx * 1.4
				g.add_child(sh)
				part(sh, box(0.5, 0.8, 0.04), _board_mats()[1], Vector3(sx * 0.25, 0, 0))
		"door":
			_boards(g, -0.97, -0.56, 0.0, WALL_H)
			_boards(g, 0.56, 0.97, 0.0, WALL_H, 1)
			_boards(g, -0.56, 0.56, 2.02, WALL_H, 2)
			for x in [-0.57, 0.57]:
				part(g, box(0.08, 2.04, 0.12), dark, Vector3(x, 1.01, 0))
			part(g, box(1.22, 0.08, 0.14), dark, Vector3(0, 2.04, 0))
			var leaf := Node3D.new()
			leaf.position = Vector3(-0.52, 0, 0)
			leaf.rotation.y = -1.25     # standing open
			g.add_child(leaf)
			_boards(leaf, 0.0, 1.02, 0.02, 1.98, 1)
			part(leaf, box(1.0, 0.08, 0.05), dark, Vector3(0.51, 0.5, 0.05))
			part(leaf, box(1.0, 0.08, 0.05), dark, Vector3(0.51, 1.5, 0.05))
			part(leaf, sphere(0.035, 6), mat(Color("3a3a3a"), 0.4, 0.7), Vector3(0.9, 1.0, 0.08))
			return g
		"rail":
			for x in [-0.9, 0.0, 0.9]:
				part(g, box(0.08, 0.9, 0.08), dark, Vector3(x, 0.45, 0))
			for y in [0.45, 0.86]:
				part(g, box(1.94, 0.07, 0.06), _board_mats()[0], Vector3(0, y, 0))
			return g
	# horizontal battens and rope lashings on both faces
	for y in [0.35, 1.95]:
		for zf in [-0.055, 0.055]:
			part(g, box(1.94, 0.1, 0.04), dark, Vector3(0, y, zf))
	for x in [-0.8, 0.8]:
		for y in [0.35, 1.95]:
			part(g, box(0.05, 0.14, 0.16), rope, Vector3(x, y, 0))
	bake(g)
	return g


static func post() -> Node3D:
	var g := Node3D.new()
	part(g, cyl(0.12, 0.13, WALL_H, 12), shared("post_m", func(): return log_mat(Color("8a6240"), WALL_H)), Vector3(0, WALL_H / 2.0, 0))
	for y in [0.25, WALL_H - 0.2]:
		part(g, cyl(0.138, 0.138, 0.09, 12), shared("lash", func(): return tmat(Color("cdb68a"), "rope", 0.95, 6.0, 1.5)), Vector3(0, y, 0))
	return g


## Upper-storey floor: planks on two beams; the node sits at the walking surface.
static func upper_floor() -> Node3D:
	var g := Node3D.new()
	var mats: Array = _board_mats()
	for i in 6:
		part(g, box(1.99, 0.08, 0.31), mats[i % mats.size()], Vector3(0, -0.04, -0.825 + i * 0.33))
	for x in [-0.7, 0.7]:
		part(g, box(0.14, 0.16, 1.99), shared("batten", func(): return tmat(Color("6b4a2e"), "planks", 0.9, 1.5)), Vector3(x, -0.16, 0))
	bake(g)
	return g


## Palm-thatch roof over one tile; the node sits on the wall tops. Fringe is added per open edge.
static func roof_tile() -> Node3D:
	var g := Node3D.new()
	part(g, box(2.0, 0.06, 2.0), shared("batten", func(): return tmat(Color("6b4a2e"), "planks", 0.9, 1.5)), Vector3(0, 0.03, 0))
	var thatch: Array = shared("thatch", func(): return [tmat(Color("9c7a34"), "thatch", 1.0, 1.2, 1.4), tmat(Color("86672a"), "thatch", 1.0, 1.2, 1.4), tmat(Color("ad8a40"), "thatch", 1.0, 1.2, 1.4)])
	# overlapping courses of palm thatch, humped toward a ridge in the middle of the tile
	for i in 6:
		var z := -0.85 + i * 0.34
		part(g, box(2.04, 0.11, 0.42), thatch[i % 3], Vector3(0, 0.12 + 0.16 * sin(PI * (i + 0.5) / 6.0), z), Vector3(0.18 * signf(-z), 0, 0))
	part(g, box(2.04, 0.12, 0.3), thatch[1], Vector3(0, 0.33, 0))
	part(g, cyl(0.07, 0.07, 2.04, 8), shared("post_m", func(): return log_mat(Color("8a6240"), WALL_H)), Vector3(0, 0.4, 0), Vector3(0, 0, PI / 2.0))
	bake(g)
	var fr := Node3D.new()
	fr.name = "Fringe"
	g.add_child(fr)
	return g


static func roof_edges(roof: Node3D, open: Array) -> void:
	var fr: Node3D = roof.get_node("Fringe")
	for c in fr.get_children():
		fr.remove_child(c)
		c.queue_free()
	var thatch: Array = shared("thatch", func(): return [tmat(Color("9c7a34"), "thatch", 1.0, 1.2, 1.4), tmat(Color("86672a"), "thatch", 1.0, 1.2, 1.4), tmat(Color("ad8a40"), "thatch", 1.0, 1.2, 1.4)])
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for i in 4:
		if open[i]:
			continue
		var d: Vector2 = dirs[i]
		var along_x := d.x == 0.0
		for layer in 2:
			var s := part(fr, box(2.3 if along_x else 0.42, 0.08, 0.42 if along_x else 2.3), thatch[(i + layer) % 3],
				Vector3(d.x * (1.12 + layer * 0.06), 0.04 - layer * 0.1, d.y * (1.12 + layer * 0.06)))
			s.rotation = Vector3(d.y * (0.55 + layer * 0.25), 0, -d.x * (0.55 + layer * 0.25))


## Stairs rising toward +z from the deck to the upper floor of the next tile.
static func stairs() -> Dictionary:
	var g := Node3D.new()
	var mats: Array = _board_mats()
	var steps := 7
	for i in steps:
		var y := (i + 1) * 2.45 / steps
		part(g, box(1.1, 0.07, 0.3), mats[i % mats.size()], Vector3(0, y - 0.035, -0.85 + i * 0.29))
	var dark: StandardMaterial3D = shared("batten", func(): return tmat(Color("6b4a2e"), "planks", 0.9, 1.5))
	for x in [-0.58, 0.58]:
		_rod(g, Vector3(x, 0.0, -1.0), Vector3(x, 2.45, 1.0), 0.06, dark)
		_rod(g, Vector3(x, 0.9, -1.0), Vector3(x, 3.3, 1.0), 0.03, dark)
		part(g, box(0.06, 0.9, 0.06), dark, Vector3(x, 0.45, -0.95))
	return {"node": g}


# ---------------------------------------------------------------- sea companions (all face +Z)

static func _mix3(up: float, back: Color, flank: Color, belly: Color, hi := 0.25, lo := -0.35) -> Color:
	if up > hi:
		return flank.lerp(back, clampf((up - hi) / 0.35, 0.0, 1.0))
	if up > lo:
		return belly.lerp(flank, smoothstep(lo, hi, up))
	return belly


static func _eye(g: Node3D, at: Vector3, r: float, iris: Color, out: Vector3) -> void:
	var eye := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	eye.mesh = sm
	var em := StandardMaterial3D.new()
	em.albedo_color = iris
	em.roughness = 0.08
	em.metallic_specular = 0.9
	eye.material_override = em
	eye.position = at
	g.add_child(eye)
	if iris.get_luminance() > 0.2:
		part(g, sphere(r * 0.5, 8), mat(Color("0a0a0a"), 0.1), at + out.normalized() * r * 0.62)


## Load a rigged, animated glTF creature from models3d/, scaled so its largest side is `size`
## metres and turned to face +Z. The AnimationPlayer is kept in meta "anim"; every clip loops.
## retex: material name -> {"albedo": texture path, "rough": float, "white": bool} to repaint parts.
static func _creature_glb(path: String, size: float, yaw: float, tint := Color.WHITE, retex := {}) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var root := Node3D.new()
	var inst: Node3D = ps.instantiate()
	root.add_child(inst)
	var box := AABB()
	var first := true
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var tr := Transform3D()
		var cur: Node = mi
		while cur != inst and cur is Node3D:
			tr = (cur as Node3D).transform * tr
			cur = cur.get_parent()
		var b := tr * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	# scanned / converted materials come in mirror-shiny: make them matte so they keep their colours
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if sm != null:
				var m2: StandardMaterial3D = sm.duplicate()
				m2.metallic = 0.0
				m2.roughness = maxf(m2.roughness, 0.7)
				m2.metallic_specular = 0.3
				if m2.albedo_texture != null and m2.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
					m2.albedo_color = m2.albedo_color * tint
				if retex.has(sm.resource_name):
					var rt: Dictionary = retex[sm.resource_name]
					if rt.has("albedo"):
						m2.albedo_texture = load(rt.albedo)
					if rt.has("rough"):
						m2.roughness = rt.rough
						m2.metallic_specular = 0.5 if rt.rough < 0.3 else 0.25
					if rt.get("white", false):
						m2.albedo_color = Color.WHITE
				mi.set_surface_override_material(si, m2)
	var k := size / maxf(0.001, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	inst.scale = Vector3.ONE * k
	inst.rotation.y = yaw
	inst.position = -(Basis(Vector3.UP, yaw) * box.get_center()) * k
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		for an in ap.get_animation_list():
			ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		root.set_meta("anim", ap)
	return root


## Seagull: the animated "Flying Seagull" model (clips "flap", "planer", "planer 2"); falls back to
## the procedural bird if the file is missing.
static func seagull() -> Node3D:
	var m := _creature_glb("res://models3d/seagull.glb", 1.4, 0.0)
	return m if m != null else seagull_procedural()


## Sea turtle. Look chosen by TURTLE_STYLE: "real" = the scanned hawksbill repainted in warm,
## living colours; "lowpoly" = faceted like the gull; "cartoon" = big-eyed toy turtle.
static var turtle_style := "real"

static func turtle() -> Node3D:
	match turtle_style:
		"lowpoly":
			return turtle_lowpoly()
		"cartoon":
			return turtle_procedural()
	var m := _creature_glb("res://models3d/turtle.glb", 1.15, PI, Color(1.3, 1.12, 0.85), {
		"hawksbill.body": {"albedo": "res://models3d/turtle_paint.png", "rough": 0.75},
		"hawksbill.eyes": {"albedo": "res://models3d/turtle_eye.png", "rough": 0.12, "white": true}})
	return m if m != null else turtle_lowpoly()


## Low-poly sea turtle in the same faceted style as the gull: realistic proportions, flat facets.
static func turtle_lowpoly() -> Node3D:
	var g := Node3D.new()
	var m := CreatureMesh.vmat().duplicate() as StandardMaterial3D
	m.roughness = 0.75
	var m2 := m.duplicate() as StandardMaterial3D
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plates := [Vector2(0, 0.6), Vector2(0, 0.28), Vector2(0, -0.04), Vector2(0, -0.36), Vector2(0, -0.66)]
	for sx in [-1.0, 1.0]:
		for z in [0.45, 0.12, -0.2, -0.5]:
			plates.append(Vector2(sx * 0.52, z))
	var pal := [Color("9a7f46"), Color("a88a4c"), Color("8c7440"), Color("b39552"), Color("94804a")]
	var shell := CreatureMesh.dome(0.4, 0.48, 0.2, func(uv):
		var q: Vector2 = uv * 2.0 - Vector2.ONE
		if q.length() > 0.85:
			return Color("c2a565")
		var best := 0
		var bd := 9.0
		for k in plates.size():
			var dd: float = q.distance_to(plates[k])
			if dd < bd:
				bd = dd
				best = k
		return (pal[best % pal.size()] as Color).lerp(Color("d1b06a"), clampf(0.35 - bd, 0.0, 0.35)), false, 7, 18)
	var sh := CreatureMesh.node_m(CreatureMesh.flat(shell, 0.06), m)
	sh.position.y = 0.035
	g.add_child(sh)
	var pl := CreatureMesh.node_m(CreatureMesh.flat(CreatureMesh.dome(0.37, 0.45, 0.05, func(uv): return Color("e2d2a0"), true, 3, 14), 0.04), m)
	pl.position.y = 0.03
	g.add_child(pl)
	var top := Color("a68c5a")
	var under := Color("efe2b4")
	var col := func(th, t): return under if sin(th) < -0.25 else (top if sin(th) > 0.4 else Color("c2a66e"))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.0, 0.3)
	g.add_child(head)
	var R := CreatureMesh.ring
	var hr := [R.call(0.0, 0.1, 0.075, 0.0), R.call(0.12, 0.092, 0.072, 0.015), R.call(0.2, 0.1, 0.085, 0.035),
		R.call(0.3, 0.105, 0.092, 0.055), R.call(0.38, 0.09, 0.085, 0.065), R.call(0.44, 0.066, 0.066, 0.062),
		R.call(0.48, 0.035, 0.04, 0.052), R.call(0.5, 0.008, 0.01, 0.046)]
	head.add_child(CreatureMesh.node_m(CreatureMesh.flat(CreatureMesh.tube(CreatureMesh.spline_rings(hr, 8), 8, col, true), 0.05), m))
	var eye := mat(Color("140f0b"), 0.1)
	eye.metallic_specular = 0.9
	for x in [-1.0, 1.0]:
		part(head, sphere(0.024, 8), eye, Vector3(x * 0.078, 0.09, 0.37))
		part(head, sphere(0.007, 5), mat(Color("ffffff"), 0.2), Vector3(x * 0.09, 0.1, 0.385))
	for nm in ["FL", "FR", "BL", "BR"]:
		var side := -1.0 if nm.ends_with("L") else 1.0
		var is_front: bool = nm.begins_with("F")
		var f := Node3D.new()
		f.name = nm
		f.position = Vector3(side * (0.3 if is_front else 0.22), 0.0, 0.25 if is_front else -0.36)
		g.add_child(f)
		var ctrl: Array
		if is_front:
			ctrl = [[Vector3(0, 0, 0), Vector3(0, 0, 0.08), Vector3(0, 0.032, 0)], [Vector3(side * 0.16, -0.01, -0.03), Vector3(0, 0, 0.088), Vector3(0, 0.024, 0)],
				[Vector3(side * 0.33, -0.02, -0.12), Vector3(0, 0, 0.074), Vector3(0, 0.016, 0)], [Vector3(side * 0.47, -0.03, -0.26), Vector3(0, 0, 0.046), Vector3(0, 0.01, 0)],
				[Vector3(side * 0.53, -0.034, -0.35), Vector3(0, 0, 0.008), Vector3(0, 0.003, 0)]]
		else:
			ctrl = [[Vector3(0, 0, 0), Vector3(0, 0, 0.06), Vector3(0, 0.026, 0)], [Vector3(side * 0.08, -0.01, -0.08), Vector3(0, 0, 0.07), Vector3(0, 0.018, 0)],
				[Vector3(side * 0.13, -0.015, -0.17), Vector3(0, 0, 0.05), Vector3(0, 0.01, 0)], [Vector3(side * 0.15, -0.017, -0.22), Vector3(0, 0, 0.01), Vector3(0, 0.003, 0)]]
		var fc := func(th, t): return under if sin(th) < 0.0 else (top if t < 0.75 else Color("8a7246"))
		f.add_child(CreatureMesh.node_m(CreatureMesh.flat(CreatureMesh.tube(CreatureMesh.spline_rings(ctrl, 6), 6, fc, true), 0.05), m2))
	part(g, cyl(0.0, 0.03, 0.1, 5), mat(top, 0.8), Vector3(0, 0.01, -0.5), Vector3(-PI / 2.0, 0, 0))
	return g


## Herring gull, ~0.55 m long, wingspan ~1.4 m. Wings: WingL / WingR, hand sections OutL / OutR.
static func seagull_procedural() -> Node3D:
	var g := Node3D.new()
	var white := Color("f6f6f2")
	var mantle := Color("a7b1b9")
	var R := CreatureMesh.ring
	var body := CreatureMesh.tube(CreatureMesh.spline_rings([R.call(-0.3, 0.012, 0.008, 0.04), R.call(-0.24, 0.05, 0.03, 0.035),
		R.call(-0.14, 0.09, 0.075, 0.012), R.call(-0.02, 0.11, 0.1, 0.0), R.call(0.08, 0.1, 0.095, 0.02), R.call(0.15, 0.075, 0.08, 0.06),
		R.call(0.2, 0.055, 0.06, 0.1)], 22), 24,
		func(th, t): return white.lerp(mantle, smoothstep(0.45, 0.75, sin(th)) * (1.0 - smoothstep(0.7, 0.9, t)) * smoothstep(0.1, 0.25, t)))
	g.add_child(CreatureMesh.node_m(body, CreatureMesh.vmat()))
	var head := CreatureMesh.tube(CreatureMesh.spline_rings([R.call(0.16, 0.045, 0.045, 0.11), R.call(0.2, 0.064, 0.068, 0.135), R.call(0.25, 0.071, 0.071, 0.146),
		R.call(0.3, 0.058, 0.055, 0.143), R.call(0.33, 0.038, 0.035, 0.136), R.call(0.345, 0.022, 0.02, 0.13)], 14), 22, func(th, t): return white)
	g.add_child(CreatureMesh.node_m(head, CreatureMesh.vmat()))
	# hooked yellow bill with the red gonys spot on the lower mandible
	var bill := CreatureMesh.tube(CreatureMesh.spline_rings([R.call(0.325, 0.022, 0.027, 0.128), R.call(0.36, 0.016, 0.022, 0.123), R.call(0.39, 0.013, 0.018, 0.119),
		R.call(0.415, 0.009, 0.016, 0.111), R.call(0.43, 0.005, 0.01, 0.1), R.call(0.437, 0.001, 0.002, 0.092)], 12), 14,
		func(th, t): return Color("d8392b") if t > 0.5 and t < 0.75 and sin(th) < -0.3 else Color("f0c23a").lerp(Color("e9a92a"), t))
	g.add_child(CreatureMesh.node_m(bill, CreatureMesh.vmat()))
	for x in [-1.0, 1.0]:
		_eye(g, Vector3(x * 0.052, 0.158, 0.29), 0.0115, Color("e8d24a"), Vector3(x, 0.1, 0.4))
		part(g, cyl(0.014, 0.014, 0.004, 10), mat(Color("c8463a")), Vector3(x * 0.05, 0.158, 0.29), Vector3(0, 0, PI / 2.0))
	# wings: airfoil sections, chord along z (half-length a), thickness up y (b)
	var wing_col := func(th, t):
		if cos(th) < -0.78:
			return Color("f2f3f0")
		return Color("98a3ac") if sin(th) > 0.0 else Color("e4e8ea")
	var hand_col := func(th, t):
		if t > 0.35:
			return Color("1c1c1e")
		if cos(th) < -0.8:
			return Color("f2f3f0")
		return Color("98a3ac") if sin(th) > 0.0 else Color("e4e8ea")
	for side in [-1.0, 1.0]:
		var left: bool = side < 0.0
		var w := Node3D.new()
		w.name = "WingL" if left else "WingR"
		w.position = Vector3(side * 0.08, 0.07, 0.035)
		g.add_child(w)
		var arm := []
		for k in 5:
			var f := k / 4.0
			var chord := lerpf(0.115, 0.088, f)
			arm.append([Vector3(side * 0.36 * f, 0.008 * sin(f * PI), -0.01 - 0.01 * f), Vector3(0, 0.0, chord), Vector3(0, lerpf(0.026, 0.012, f), 0)])
		w.add_child(CreatureMesh.node_m(CreatureMesh.tube(CreatureMesh.spline_rings(arm, 12), 16, wing_col), CreatureMesh.vmat()))
		var o := Node3D.new()
		o.name = "OutL" if left else "OutR"
		o.position = Vector3(side * 0.355, 0, 0.0)
		w.add_child(o)
		var hand := []
		for k in 5:
			var f := k / 4.0
			hand.append([Vector3(side * 0.3 * f, 0.0, -0.02 - 0.09 * f * f), Vector3(0, 0, lerpf(0.086, 0.035, f)), Vector3(0, lerpf(0.012, 0.006, f), 0)])
		o.add_child(CreatureMesh.node_m(CreatureMesh.tube(CreatureMesh.spline_rings(hand, 12), 16, hand_col), CreatureMesh.vmat()))
		# splayed primary feathers at the tip, black with white tips
		for q in 4:
			var spread := -0.05 * q
			var base := Vector3(side * 0.24, 0.0, -0.06 + spread * 0.6)
			var tip := Vector3(side * (0.4 - 0.03 * q), 0.0, -0.14 + spread)
			var feather := [[base, Vector3(0, 0, 0.022), Vector3(0, 0.004, 0)], [base.lerp(tip, 0.6), Vector3(0, 0, 0.018), Vector3(0, 0.003, 0)], [tip, Vector3(0, 0, 0.004), Vector3(0, 0.001, 0)]]
			o.add_child(CreatureMesh.node_m(CreatureMesh.tube(CreatureMesh.spline_rings(feather, 6), 8,
				func(th, t): return Color("f2f2ee") if t > 0.86 else Color("1c1c1e")), CreatureMesh.vmat()))
	var tail := CreatureMesh.tube(CreatureMesh.spline_rings([[Vector3(0, 0.035, -0.24), Vector3(0.05, 0, 0), Vector3(0, 0.01, 0)],
		[Vector3(0, 0.035, -0.31), Vector3(0.075, 0, 0), Vector3(0, 0.008, 0)], [Vector3(0, 0.033, -0.37), Vector3(0.08, 0, 0), Vector3(0, 0.004, 0)]], 8), 14,
		func(th, t): return white)
	g.add_child(CreatureMesh.node_m(tail, CreatureMesh.vmat()))
	for x in [-0.028, 0.028]:
		_rod(g, Vector3(x, -0.06, -0.02), Vector3(x, -0.07, -0.16), 0.008, mat(Color("e2a184")))
	return g


## Bottlenose dolphin, ~2.3 m, glossy wet skin with a dark dorsal cape. "Tail" holds stock + flukes.
static func dolphin() -> Node3D:
	var g := Node3D.new()
	var cape := Color("5b6b77")
	var flank := Color("9aabb5")
	var belly := Color("eef1f2")
	var skin := func(th, t):
		var up := sin(th)
		var edge := 0.5 - 0.28 * exp(-pow((t - 0.42) / 0.2, 2.0))
		var c: Color = flank.lerp(cape, smoothstep(edge - 0.12, edge + 0.12, up))
		c = c.lerp(belly, smoothstep(-0.2, -0.55, up))
		if t > 0.86 and up > -0.32 and up < -0.12:
			c = c.darkened(0.45)        # mouth line along the beak
		return c
	var R := CreatureMesh.ring
	var glossy := CreatureMesh.glossy()
	var body := CreatureMesh.tube(CreatureMesh.spline_rings([R.call(-0.62, 0.14, 0.2, 0.03), R.call(-0.45, 0.19, 0.25, 0.03),
		R.call(-0.2, 0.26, 0.31, 0.02), R.call(0.1, 0.3, 0.33, 0.02), R.call(0.4, 0.28, 0.3, 0.03), R.call(0.62, 0.22, 0.24, 0.05),
		R.call(0.76, 0.17, 0.2, 0.06), R.call(0.86, 0.13, 0.15, 0.04), R.call(0.915, 0.085, 0.085, -0.03), R.call(0.98, 0.066, 0.06, -0.05),
		R.call(1.08, 0.046, 0.04, -0.06), R.call(1.15, 0.022, 0.02, -0.062), R.call(1.17, 0.004, 0.004, -0.062)], 44), 32, skin)
	g.add_child(CreatureMesh.node_m(body, glossy))
	for x in [-1.0, 1.0]:
		_eye(g, Vector3(x * 0.158, 0.0, 0.78), 0.02, Color("15181b"), Vector3(x, 0, 0.3))
		part(g, sphere(0.006, 6), mat(Color("ffffff"), 0.1), Vector3(x * 0.175, 0.01, 0.79))
	part(g, sphere(0.022, 8), mat(Color("2a3238")), Vector3(0, 0.262, 0.6), Vector3.ZERO, Vector3(1.5, 0.25, 0.7))
	var fin := func(ctrl: Array, n: int) -> MeshInstance3D:
		return CreatureMesh.node_m(CreatureMesh.tube(CreatureMesh.spline_rings(ctrl, n), 16, func(th, t): return cape.lerp(flank, 0.15 * t)), glossy)
	# falcate dorsal fin: chord along z, thickness across x
	g.add_child(fin.call([[Vector3(0, 0.29, 0.06), Vector3(0, 0, 0.25), Vector3(0.045, 0, 0)], [Vector3(0, 0.42, -0.04), Vector3(0, 0, 0.16), Vector3(0.03, 0, 0)],
		[Vector3(0, 0.55, -0.17), Vector3(0, 0, 0.09), Vector3(0.018, 0, 0)], [Vector3(0, 0.63, -0.3), Vector3(0, 0, 0.035), Vector3(0.008, 0, 0)],
		[Vector3(0, 0.65, -0.36), Vector3(0, 0, 0.004), Vector3(0.002, 0, 0)]], 16))
	for side in [-1.0, 1.0]:
		g.add_child(fin.call([[Vector3(side * 0.2, -0.12, 0.5), Vector3(0, 0, 0.12), Vector3(0, 0.03, 0)], [Vector3(side * 0.32, -0.2, 0.42), Vector3(0, 0, 0.1), Vector3(0, 0.022, 0)],
			[Vector3(side * 0.42, -0.26, 0.31), Vector3(0, 0, 0.065), Vector3(0, 0.015, 0)], [Vector3(side * 0.48, -0.29, 0.21), Vector3(0, 0, 0.012), Vector3(0, 0.004, 0)]], 12))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.03, -0.55)
	g.add_child(tail)
	var stock := CreatureMesh.tube(CreatureMesh.spline_rings([R.call(0.1, 0.16, 0.21, 0.0), R.call(-0.05, 0.135, 0.195, 0.0), R.call(-0.2, 0.09, 0.15, 0.0),
		R.call(-0.35, 0.055, 0.11, 0.0), R.call(-0.48, 0.035, 0.07, 0.0), R.call(-0.56, 0.025, 0.045, 0.0)], 18), 28, skin)
	tail.add_child(CreatureMesh.node_m(stock, glossy))
	for side in [-1.0, 1.0]:
		tail.add_child(fin.call([[Vector3(0, 0, -0.52), Vector3(0, 0, 0.12), Vector3(0, 0.03, 0)], [Vector3(side * 0.15, 0, -0.6), Vector3(0, 0, 0.1), Vector3(0, 0.02, 0)],
			[Vector3(side * 0.3, 0, -0.7), Vector3(0, 0, 0.07), Vector3(0, 0.013, 0)], [Vector3(side * 0.43, 0, -0.79), Vector3(0, 0, 0.014), Vector3(0, 0.004, 0)]], 14))
	return g


## Green sea turtle, carapace ~0.95 m: textured scutes and scaly skin. Flippers FL / FR / BL / BR.
static func turtle_procedural() -> Node3D:
	var g := Node3D.new()
	var skin := CreatureMesh.vmat().duplicate() as StandardMaterial3D
	skin.roughness = 0.6
	skin.metallic_specular = 0.35
	var skin2 := skin.duplicate() as StandardMaterial3D
	skin2.cull_mode = BaseMaterial3D.CULL_DISABLED
	# shell: round plates (one in the middle, six around it), dark seams, a pale rim
	var plates := [Vector2(0, 0.04)]
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		plates.append(Vector2(cos(a) * 0.6, sin(a) * 0.62))
	var plate := Color("63a94a")
	var plate_hi := Color("a3d36a")
	var seam := Color("2f5d2b")
	var rim := Color("e9d77f")
	var shell := CreatureMesh.dome(0.36, 0.42, 0.27, func(uv):
		var q: Vector2 = uv * 2.0 - Vector2.ONE
		var r := q.length()
		if r > 0.86:
			return rim if r < 0.97 else rim.darkened(0.12)
		if r > 0.8:
			return seam
		var d1 := 9.0
		var d2 := 9.0
		for sd in plates:
			var dd: float = q.distance_to(sd)
			if dd < d1:
				d2 = d1
				d1 = dd
			elif dd < d2:
				d2 = dd
		if d2 - d1 < 0.07:
			return seam
		return plate.lerp(plate_hi, clampf(1.0 - d1 * 2.2, 0.0, 1.0)))
	var sh := CreatureMesh.node_m(shell, skin)
	sh.position.y = 0.03
	g.add_child(sh)
	var belly := Color("f3e6a6")
	var pl := CreatureMesh.node_m(CreatureMesh.dome(0.34, 0.4, 0.07, func(uv): return belly, true), skin)
	pl.position.y = 0.03
	g.add_child(pl)
	# head on a short neck, pivoting at the shell so it can bob
	var green := Color("a2d66c")
	var col := func(th, t): return belly if sin(th) < -0.35 else green
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.03, 0.3)
	g.add_child(head)
	var R := CreatureMesh.ring
	var rings := [R.call(-0.05, 0.085, 0.07, -0.01), R.call(0.06, 0.085, 0.075, 0.01), R.call(0.13, 0.115, 0.11, 0.05),
		R.call(0.2, 0.135, 0.13, 0.07), R.call(0.27, 0.13, 0.12, 0.075), R.call(0.33, 0.1, 0.095, 0.07),
		R.call(0.37, 0.05, 0.05, 0.065), R.call(0.385, 0.005, 0.005, 0.06)]
	head.add_child(CreatureMesh.node_m(CreatureMesh.tube(CreatureMesh.spline_rings(rings, 22), 24, col, true), skin))
	# big shiny eyes and rosy cheeks
	var white := mat(Color("ffffff"), 0.3)
	var pupil := mat(Color("1d1a22"), 0.12)
	pupil.metallic_specular = 0.9
	var pink := mat(Color("f59aa0"), 0.7)
	for x in [-1.0, 1.0]:
		var e := Vector3(x * 0.064, 0.125, 0.3)
		var out := Vector3(x * 0.3, 0.1, 0.95).normalized()
		part(head, sphere(0.058, 16), white, e)
		var pp := e + out * 0.034
		part(head, sphere(0.036, 14), pupil, pp)
		part(head, sphere(0.012, 8), white, pp + Vector3(x * 0.006, 0.016, 0.0) + out * 0.026)
		part(head, sphere(0.024, 10), pink, Vector3(x * 0.1, 0.045, 0.3), Vector3.ZERO, Vector3(1.0, 0.6, 0.5))
	# paddle flippers (true mirrored copies on the left)
	var fcol := func(uv): return green.darkened(0.12) if uv.x > 0.27 else green
	var front := CreatureMesh.smooth_outline([Vector2(0, 0.06), Vector2(0.12, 0.075), Vector2(0.27, 0.035), Vector2(0.38, -0.06),
		Vector2(0.37, -0.14), Vector2(0.24, -0.09), Vector2(0.1, -0.05), Vector2(0, -0.05)], 5)
	var back := CreatureMesh.smooth_outline([Vector2(0, 0.04), Vector2(0.08, 0.035), Vector2(0.15, -0.03), Vector2(0.14, -0.1),
		Vector2(0.06, -0.08), Vector2(0, -0.04)], 5)
	for nm in ["FL", "FR", "BL", "BR"]:
		var side := -1.0 if nm.ends_with("L") else 1.0
		var is_front: bool = nm.begins_with("F")
		var f := Node3D.new()
		f.name = nm
		f.position = Vector3(side * (0.26 if is_front else 0.2), 0.02, 0.2 if is_front else -0.28)
		g.add_child(f)
		f.add_child(CreatureMesh.node_m(CreatureMesh.blade(front if is_front else back, 0.04, "flat", fcol, side < 0.0), skin2))
	part(g, cyl(0.0, 0.035, 0.12, 10), mat(green, 0.6), Vector3(0, 0.02, -0.44), Vector3(-PI / 2.0, 0, 0))
	return g


## A tangle of green fishing net draped over a caught turtle, with a float.
static func fishing_net() -> Node3D:
	var g := Node3D.new()
	var m := mat(Color("5a9a63"), 1.0)
	var pts := []
	for i in 7:
		var row := []
		for j in 7:
			var u := -1.0 + 2.0 * i / 6.0
			var v := -1.0 + 2.0 * j / 6.0
			var r2 := u * u * 0.8 + v * v * 0.6
			row.append(Vector3(u * 0.55, 0.28 - r2 * 0.2 + 0.04 * sin(i * 2.1 + j * 1.3), v * 0.6))
		pts.append(row)
	for i in 7:
		for j in 7:
			if i < 6:
				_rod(g, pts[i][j], pts[i + 1][j], 0.008, m)
			if j < 6:
				_rod(g, pts[i][j], pts[i][j + 1], 0.008, m)
	_rod(g, pts[6][3], Vector3(0.9, 0.5, 0.3), 0.01, m)
	part(g, sphere(0.07, 8), mat(Color("e3b23c"), 0.5), Vector3(0.95, 0.52, 0.32))
	bake(g, [], false)
	return g


## Small bobbing marker over debris the seagull spotted.
static func spot_marker() -> Node3D:
	var g := Node3D.new()
	var m := mat(Color("ffb347"), 0.4)
	m.emission_enabled = true
	m.emission = Color("ff9f1c")
	m.emission_energy_multiplier = 0.8
	part(g, cyl(0.16, 0.0, 0.3, 8), m, Vector3.ZERO)
	return g


static func gull_nest() -> Dictionary:
	var g := Node3D.new()
	var wood := mat(Color("7a5232"))
	part(g, cyl(0.07, 0.09, 1.1, 8), wood, Vector3(0, 0.55, 0))
	part(g, cyl(0.35, 0.3, 0.06, 12), wood, Vector3(0, 1.12, 0))
	var twig := mat(Color("a5814f"), 1.0)
	for i in 10:
		var a := TAU * i / 10.0
		part(g, box(0.34, 0.05, 0.05), twig, Vector3(cos(a) * 0.26, 1.2 + 0.03 * (i % 2), sin(a) * 0.26), Vector3(0, -a + PI / 2.0, 0.2))
	part(g, cyl(0.22, 0.18, 0.06, 12), mat(Color("d6ba6c"), 1.0), Vector3(0, 1.17, 0))
	return {"node": g}


static func dolphin_post() -> Dictionary:
	var g := Node3D.new()
	var wood := mat(Color("6b4a2e"))
	part(g, cyl(0.14, 0.17, 1.0, 10), wood, Vector3(0, 0.5, 0))
	part(g, cyl(0.2, 0.2, 0.06, 12), wood, Vector3(0, 1.02, 0))
	var rope := mat(Color("cdb68a"), 0.95)
	for i in 4:
		part(g, cyl(0.19, 0.19, 0.05, 12), rope, Vector3(0, 0.55 + i * 0.07, 0))
	part(g, sphere(0.16, 10), mat(Color("ff7a2a"), 0.5), Vector3(0.35, 0.3, 0))
	part(g, cyl(0.02, 0.02, 0.4, 4), rope, Vector3(0.22, 0.55, 0), Vector3(0, 0, 0.8))
	return {"node": g}


static func turtle_tank() -> Dictionary:
	var g := Node3D.new()
	var wood := mat(Color("7a5232"))
	part(g, box(1.4, 0.06, 1.1), wood, Vector3(0, 0.05, 0))
	for z in [-0.55, 0.55]:
		part(g, box(1.4, 0.45, 0.06), wood, Vector3(0, 0.27, z))
	for x in [-0.7, 0.7]:
		part(g, box(0.06, 0.45, 1.1), wood, Vector3(x, 0.27, 0))
	var water := mat(Color("3d9cc0"), 0.05)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color.a = 0.6
	part(g, box(1.32, 0.03, 1.02), water, Vector3(0, 0.4, 0))
	part(g, box(0.5, 0.06, 0.3), mat(Color("8b8178")), Vector3(-0.35, 0.12, 0.25))
	return {"node": g}
