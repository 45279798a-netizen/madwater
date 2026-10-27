class_name PlayerRig
extends Node3D
## Jointed castaway figure (straw hat, rolled sleeves) with a procedural walk cycle.

var hips: Node3D
var torso: Node3D
var arm_l := {}
var arm_r := {}
var leg_l := {}
var leg_r := {}
var walk := 0.0
var bubbles: CPUParticles3D
var shirt_mat: StandardMaterial3D


func _init() -> void:
	var skin := Models.mat(Color("c98a5e"), 0.65)
	var shirt := Models.tmat(Color("e8743b"), "cloth", 0.9, 3.0, 0.8)
	shirt.resource_name = "shirt"
	shirt_mat = shirt
	var pants := Models.tmat(Color("2c4468"), "cloth", 0.9, 3.0, 1.0)
	var sandal := Models.tm(Color("6a4a2e"), "planks", 0.8, 6.0)
	var straw := Models.tm(Color("e3c46a"), "thatch", 0.95, 4.0, 1.0)
	var band := Models.mat(Color("8a3b2a"))
	var hair := Models.tm(Color("3b2a20"), "rope", 0.9, 8.0, 0.6)
	var dark := Models.mat(Color("1b1612"), 0.3)
	var white := Models.mat(Color("f4f0ea"), 0.4)
	var rope := Models.tm(Color("a08a5c"), "rope", 0.95, 8.0)
	var leather := Models.tm(Color("7a5232"), "planks", 0.75, 4.0, 0.6)
	var body := Node3D.new()
	body.scale = Vector3.ONE * 0.88
	add_child(body)
	hips = Node3D.new()
	hips.position.y = 0.78
	body.add_child(hips)
	Models.part(hips, Models.cyl(0.19, 0.2, 0.2, 14), pants, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.05, 1, 0.72))
	torso = Node3D.new()
	hips.add_child(torso)
	# shirt: tapered from the chest to the waist, shoulders rounded off, collar open at the neck
	Models.part(torso, Models.cyl(0.235, 0.2, 0.5, 16), shirt, Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1.0, 1, 0.62))
	Models.part(torso, Models.capsule(0.105, 0.6), shirt, Vector3(0, 0.55, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.8))
	for sx in [-1.0, 1.0]:   # collar points
		Models.part(torso, Models.box(0.09, 0.02, 0.07), shirt, Vector3(sx * 0.06, 0.58, 0.13), Vector3(0.5, sx * 0.4, sx * 0.3))
	Models.part(torso, Models.cyl(0.205, 0.205, 0.05, 16), rope, Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.0, 1, 0.65))
	Models.part(torso, Models.sphere(0.03, 6), rope, Vector3(0.06, 0.1, 0.14))
	# satchel strap over one shoulder, bag on the other hip
	Models.part(torso, Models.box(0.05, 0.7, 0.015), leather, Vector3(0.0, 0.32, 0.15), Vector3(0, 0, 0.62))
	Models.part(torso, Models.box(0.05, 0.7, 0.015), leather, Vector3(0.0, 0.32, -0.15), Vector3(0, 0, 0.62))
	Models.part(torso, Models.box(0.2, 0.17, 0.08), leather, Vector3(-0.22, 0.06, 0.06), Vector3(0, 0.3, 0))
	Models.part(torso, Models.box(0.21, 0.07, 0.085), Models.tm(Color("5c3d22"), "planks", 0.75, 4.0, 0.6), Vector3(-0.22, 0.13, 0.06), Vector3(0, 0.3, 0))
	Models.part(torso, Models.cyl(0.07, 0.08, 0.1, 10), skin, Vector3(0, 0.63, 0))
	var head := Node3D.new()
	head.position.y = 0.82
	torso.add_child(head)
	Models.part(head, Models.sphere(0.2, 16), skin, Vector3.ZERO, Vector3.ZERO, Vector3(0.95, 1.08, 1))
	Models.part(head, Models.sphere(0.13, 12), skin, Vector3(0, -0.09, 0.045), Vector3.ZERO, Vector3(1.05, 0.8, 1.0))    # jaw
	Models.part(head, Models.sphere(0.207, 14), hair, Vector3(0, 0.035, -0.035), Vector3.ZERO, Vector3(0.98, 0.9, 1))
	for k in 5:
		Models.part(head, Models.box(0.05, 0.03, 0.09), hair, Vector3(-0.1 + k * 0.05, 0.1, 0.15), Vector3(0.5, 0, -0.3 + k * 0.15))  # fringe
	Models.part(head, Models.prism(0.06, 0.09, 0.07), skin, Vector3(0, -0.01, 0.2), Vector3(-0.2, 0, 0))            # nose
	for sx in [-1.0, 1.0]:
		Models.part(head, Models.sphere(0.045, 7), skin, Vector3(sx * 0.19, -0.01, 0.0), Vector3.ZERO, Vector3(0.5, 1, 0.8))   # ears
		Models.part(head, Models.sphere(0.03, 8), white, Vector3(sx * 0.07, 0.035, 0.172), Vector3.ZERO, Vector3(1, 0.85, 0.6))
		Models.part(head, Models.sphere(0.018, 6), dark, Vector3(sx * 0.07, 0.035, 0.188))
		Models.part(head, Models.box(0.07, 0.015, 0.02), hair, Vector3(sx * 0.072, 0.085, 0.18), Vector3(0, 0, -sx * 0.12))  # brows
	Models.part(head, Models.box(0.07, 0.012, 0.015), Models.mat(Color("a8604a"), 0.6), Vector3(0, -0.1, 0.178))   # mouth
	# straw hat: frayed brim, crown, band (the brim casts no shadow, or it would black out the face)
	var brim := Models.part(head, Models.cyl(0.45, 0.45, 0.025, 20), straw, Vector3(0, 0.14, 0))
	brim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 16:
		var a := TAU * k / 16.0
		var fray := Models.part(head, Models.box(0.06, 0.012, 0.07), straw, Vector3(cos(a) * 0.46, 0.135, sin(a) * 0.46), Vector3(0, -a, 0.15 * sin(k * 2.7)))
		fray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.part(head, Models.cyl(0.165, 0.21, 0.17, 16), straw, Vector3(0, 0.23, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.part(head, Models.cyl(0.212, 0.212, 0.045, 16), band, Vector3(0, 0.17, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm_l = _arm(-1.0, shirt, skin)
	arm_r = _arm(1.0, shirt, skin)
	leg_l = _leg(-1.0, pants, sandal, skin)
	leg_r = _leg(1.0, pants, sandal, skin)
	bubbles = CPUParticles3D.new()
	var bm := Models.sphere(0.035, 6)
	bm.material = Models.glass(Color(0.85, 0.95, 1.0), 0.55)
	bubbles.mesh = bm
	bubbles.amount = 12
	bubbles.lifetime = 2.0
	bubbles.local_coords = false
	bubbles.direction = Vector3.UP
	bubbles.spread = 25.0
	bubbles.initial_velocity_min = 0.2
	bubbles.initial_velocity_max = 0.5
	bubbles.gravity = Vector3(0, 1.2, 0)
	bubbles.scale_amount_min = 0.6
	bubbles.scale_amount_max = 1.5
	bubbles.position = Vector3(0, 0.85, 0.18)
	bubbles.emitting = false
	torso.add_child(bubbles)


## Friends' castaways wear their own shirt colour.
func set_shirt(c: Color) -> void:
	shirt_mat = shirt_mat.duplicate()
	shirt_mat.resource_name = "shirt"
	shirt_mat.albedo_color = Color(c.r * 1.25, c.g * 1.25, c.b * 1.25)
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override != null and mi.material_override.resource_name == "shirt":
			mi.material_override = shirt_mat


func _arm(side: float, shirt: Material, skin: Material) -> Dictionary:
	var sh := Node3D.new()
	sh.position = Vector3(side * 0.29, 0.52, 0)
	torso.add_child(sh)
	# short sleeve, rolled cuff, bare forearm and a rounded hand
	Models.part(sh, Models.capsule(0.078, 0.26), shirt, Vector3(0, -0.1, 0))
	Models.part(sh, Models.cyl(0.082, 0.082, 0.04, 10), shirt, Vector3(0, -0.2, 0))
	Models.part(sh, Models.capsule(0.06, 0.24), skin, Vector3(0, -0.22, 0))
	var el := Node3D.new()
	el.position.y = -0.3
	sh.add_child(el)
	Models.part(el, Models.capsule(0.056, 0.3), skin, Vector3(0, -0.13, 0))
	Models.part(el, Models.sphere(0.065, 9), skin, Vector3(0, -0.3, 0.01), Vector3.ZERO, Vector3(0.8, 1.1, 1.0))
	Models.part(el, Models.capsule(0.022, 0.08), skin, Vector3(side * -0.04, -0.27, 0.04), Vector3(0.4, 0, side * 0.6))   # thumb
	sh.rotation.z = -side * 0.08
	return {"sh": sh, "el": el}


func _leg(side: float, pants: Material, sandal: Material, skin: Material) -> Dictionary:
	var hip := Node3D.new()
	hip.position = Vector3(side * 0.11, -0.06, 0)
	hips.add_child(hip)
	# rolled-up trousers to mid-calf, bare ankles, sandals
	Models.part(hip, Models.capsule(0.098, 0.42), pants, Vector3(0, -0.18, 0))
	var knee := Node3D.new()
	knee.position.y = -0.36
	hip.add_child(knee)
	Models.part(knee, Models.capsule(0.082, 0.24), pants, Vector3(0, -0.1, 0))
	Models.part(knee, Models.cyl(0.088, 0.088, 0.05, 10), pants, Vector3(0, -0.2, 0))
	Models.part(knee, Models.capsule(0.055, 0.2), skin, Vector3(0, -0.25, 0))
	Models.part(knee, Models.capsule(0.06, 0.22), skin, Vector3(0, -0.34, 0.05), Vector3(PI / 2, 0, 0))      # foot
	Models.part(knee, Models.box(0.12, 0.025, 0.26), sandal, Vector3(0, -0.385, 0.05))
	Models.part(knee, Models.box(0.125, 0.02, 0.03), sandal, Vector3(0, -0.34, 0.1))
	return {"hip": hip, "knee": knee}


## pose: "", "steer", "fish", "fish_bite", "hook_out", "hook_reel", "swim", "tread"
func animate(dt: float, moving: bool, pose: String, t: float) -> void:
	var k := minf(1.0, dt * 12.0)
	if moving:
		walk += dt * 9.0
	var sw := sin(walk) if moving else 0.0
	if pose == "swim" or pose == "tread":
		_animate_swim(k, pose == "swim", t)
		return
	arm_l.sh.rotation.z = lerpf(arm_l.sh.rotation.z, 0.08, k)
	arm_r.sh.rotation.z = lerpf(arm_r.sh.rotation.z, -0.08, k)
	leg_l.hip.rotation.x = lerpf(leg_l.hip.rotation.x, -sw * 0.6, k)
	leg_r.hip.rotation.x = lerpf(leg_r.hip.rotation.x, sw * 0.6, k)
	leg_l.knee.rotation.x = lerpf(leg_l.knee.rotation.x, maxf(0.0, sin(walk + 1.2)) * 0.8 if moving else 0.0, k)
	leg_r.knee.rotation.x = lerpf(leg_r.knee.rotation.x, maxf(0.0, -sin(walk + 1.2)) * 0.8 if moving else 0.0, k)
	var a_l := sw * 0.5
	var a_r := -sw * 0.5
	var e_l := -0.2
	var e_r := -0.2
	match pose:
		"steer":
			a_l = -1.05; a_r = -1.05; e_l = -0.35; e_r = -0.35
		"fish":
			a_r = -1.25; e_r = -0.3
		"fish_bite":
			a_r = -1.5 + sin(t * 25.0) * 0.15; e_r = -0.3
		"hook_out":
			a_r = -2.2
		"hook_reel":
			a_r = -1.0
	arm_l.sh.rotation.x = lerpf(arm_l.sh.rotation.x, a_l, k)
	arm_r.sh.rotation.x = lerpf(arm_r.sh.rotation.x, a_r, k)
	arm_l.el.rotation.x = lerpf(arm_l.el.rotation.x, e_l, k)
	arm_r.el.rotation.x = lerpf(arm_r.el.rotation.x, e_r, k)
	hips.position.y = 0.78 + (absf(cos(walk)) * 0.04 if moving else sin(t * 2.0) * 0.008)
	torso.rotation.x = lerpf(torso.rotation.x, 0.08 if moving else 0.0, k)


## Front crawl while moving (the caller tilts the whole rig horizontal); treading water when idle.
func _animate_swim(k: float, stroking: bool, t: float) -> void:
	hips.position.y = 0.78
	torso.rotation.x = lerpf(torso.rotation.x, 0.0, k)
	if stroking:
		var ph := t * 5.0
		arm_l.sh.rotation.x = lerpf(arm_l.sh.rotation.x, -1.6 + sin(ph) * 1.5, k)
		arm_r.sh.rotation.x = lerpf(arm_r.sh.rotation.x, -1.6 - sin(ph) * 1.5, k)
		arm_l.sh.rotation.z = lerpf(arm_l.sh.rotation.z, 0.15, k)
		arm_r.sh.rotation.z = lerpf(arm_r.sh.rotation.z, -0.15, k)
		arm_l.el.rotation.x = lerpf(arm_l.el.rotation.x, -0.25, k)
		arm_r.el.rotation.x = lerpf(arm_r.el.rotation.x, -0.25, k)
		var kick := sin(t * 11.0) * 0.35
		leg_l.hip.rotation.x = lerpf(leg_l.hip.rotation.x, kick, k)
		leg_r.hip.rotation.x = lerpf(leg_r.hip.rotation.x, -kick, k)
		leg_l.knee.rotation.x = lerpf(leg_l.knee.rotation.x, 0.25 + kick * 0.3, k)
		leg_r.knee.rotation.x = lerpf(leg_r.knee.rotation.x, 0.25 - kick * 0.3, k)
	else:
		var sc := sin(t * 3.0) * 0.3
		arm_l.sh.rotation.x = lerpf(arm_l.sh.rotation.x, -0.5 + sc, k)
		arm_r.sh.rotation.x = lerpf(arm_r.sh.rotation.x, -0.5 - sc, k)
		arm_l.sh.rotation.z = lerpf(arm_l.sh.rotation.z, 0.95, k)
		arm_r.sh.rotation.z = lerpf(arm_r.sh.rotation.z, -0.95, k)
		arm_l.el.rotation.x = lerpf(arm_l.el.rotation.x, -0.4, k)
		arm_r.el.rotation.x = lerpf(arm_r.el.rotation.x, -0.4, k)
		var kick := sin(t * 2.6) * 0.45
		leg_l.hip.rotation.x = lerpf(leg_l.hip.rotation.x, -0.3 + kick, k)
		leg_r.hip.rotation.x = lerpf(leg_r.hip.rotation.x, -0.3 - kick, k)
		leg_l.knee.rotation.x = lerpf(leg_l.knee.rotation.x, 0.7, k)
		leg_r.knee.rotation.x = lerpf(leg_r.knee.rotation.x, 0.7, k)
