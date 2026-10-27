class_name Ocean
extends MeshInstance3D
## Open ocean: builds the radial LOD mesh, owns the wave spectrum and the CPU copy of the
## surface height so floating objects sit exactly on the drawn water.

const NW := 20
const MASK_N := 32

var dx := PackedFloat32Array()
var dz := PackedFloat32Array()
var kk := PackedFloat32Array()
var amp := PackedFloat32Array()
var omega := PackedFloat32Array()
var phase := PackedFloat32Array()
var calm := Vector3(1.0, 1.0, 3.0)
var t := 0.0
var wind := atan2(0.35, 1.0)
var storm := 0.0      ## 0 calm .. 1 storm: scales the wave heights (set by Weather)
var mat: ShaderMaterial

var _mask_img: Image
var _mask_tex: ImageTexture
var _rips: Array[Vector4] = []
var _rip_idx := 0


## Set before creating the ocean: a coarser mesh for phones / web builds.
static var lite := false


func _init() -> void:
	_make_waves()
	mesh = _radial_mesh(160, 110, 260.0) if lite else _radial_mesh(256, 170, 260.0)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	var wa := PackedVector4Array()
	var wb := PackedVector4Array()
	for i in NW:
		wa.append(Vector4(dx[i], dz[i], kk[i], amp[i]))
		var q := 0.72 / (kk[i] * amp[i] * NW)
		wb.append(Vector4(omega[i], phase[i], q, 0.0))
	mat.set_shader_parameter("wave_a", wa)
	mat.set_shader_parameter("wave_b", wb)
	_mask_img = Image.create(MASK_N, MASK_N, false, Image.FORMAT_L8)
	_mask_tex = ImageTexture.create_from_image(_mask_img)
	mat.set_shader_parameter("raft_mask", _mask_tex)
	mat.set_shader_parameter("raft_cell", Models.TILE)
	for i in 8:
		_rips.append(Vector4(0, 0, -99, 0))
	mat.set_shader_parameter("rip", PackedVector4Array(_rips))
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_waves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in NW:
		var L := 64.0 * pow(4.0 / 64.0, float(i) / (NW - 1))
		var k := TAU / L
		var ang := wind + rng.randfn(0.0, 1.0) * (0.3 + 0.7 * float(i) / NW)
		dx.append(cos(ang))
		dz.append(sin(ang))
		kk.append(k)
		amp.append(0.0068 * pow(L, 0.92) * (0.7 + 0.6 * rng.randf()))
		omega.append(sqrt(9.8 * k) * 0.8)
		phase.append(rng.randf() * TAU)


func _radial_mesh(m: int, n: int, radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.append(Vector3.ZERO)
	norms.append(Vector3.UP)
	for j in range(1, n + 1):
		var r := radius * pow(float(j) / n, 2.4)
		for i in m:
			var a := TAU * i / m
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
			norms.append(Vector3.UP)
	var ind := PackedInt32Array()
	for i in m:
		ind.append(0)
		ind.append(1 + i)
		ind.append(1 + (i + 1) % m)
	for j in range(1, n):
		var r0 := 1 + (j - 1) * m
		var r1 := 1 + j * m
		for i in m:
			var i1 := (i + 1) % m
			ind.append(r0 + i)
			ind.append(r1 + i)
			ind.append(r0 + i1)
			ind.append(r0 + i1)
			ind.append(r1 + i)
			ind.append(r1 + i1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = ind
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.custom_aabb = AABB(Vector3(-300, -10, -300), Vector3(600, 20, 600))
	return am


func damp(x: float, z: float) -> float:
	var d := Vector2(x - calm.x, z - calm.y).length()
	var k := clampf((d - calm.z) / 8.0, 0.0, 1.0)
	return 0.32 + 0.68 * k * k * (3.0 - 2.0 * k)


## Height of the drawn water surface at a world position (ignores the small Gerstner side shift).
func height(x: float, z: float) -> float:
	var h := 0.0
	for i in NW:
		h += amp[i] * sin((dx[i] * x + dz[i] * z) * kk[i] + t * omega[i] + phase[i])
	return h * damp(x, z) * (1.0 + 1.3 * storm) - 0.25


func ripple(x: float, z: float, strength: float) -> void:
	_rips[_rip_idx] = Vector4(x, z, t, strength)
	_rip_idx = (_rip_idx + 1) % _rips.size()
	mat.set_shader_parameter("rip", PackedVector4Array(_rips))


func set_raft_mask(cells: Array, offset: Vector2) -> void:
	_mask_img.fill(Color(0, 0, 0))
	for c in cells:
		var u: int = c.x + 16
		var v: int = c.y + 16
		if u >= 0 and v >= 0 and u < MASK_N and v < MASK_N:
			_mask_img.set_pixel(u, v, Color(1, 1, 1))
	_mask_tex.update(_mask_img)
	mat.set_shader_parameter("raft_off", offset)


func update_frame(cam_target: Vector3, sun_dir: Vector3, light_k: float) -> void:
	position = Vector3(roundf(cam_target.x * 2.0) / 2.0, 0.0, roundf(cam_target.z * 2.0) / 2.0)
	mat.set_shader_parameter("time_s", t)
	mat.set_shader_parameter("calm", calm)
	mat.set_shader_parameter("sun_dir", sun_dir)
	mat.set_shader_parameter("light_k", light_k)
	mat.set_shader_parameter("amp_mul", 1.0 + 1.3 * storm)
