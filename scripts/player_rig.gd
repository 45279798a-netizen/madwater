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
	var skin := Models.mat(Color("e0a97e"), 0.7)
	var shirt := Models.mat(Color("e8743b"), 0.9)
	shirt_mat = shirt
	var pants := Models.mat(Color("34507e"), 0.9)
	var shoe := Models.mat(Color("3a2f28"))
	var straw := Models.mat(Color("e3c46a"), 0.9)
	var band := Models.mat(Color("8a3b2a"))
	var hair := Models.mat(Color("3b2a20"))
	var dark := Models.mat(Color("1b1612"))
	var body := Node3D.new()
	body.scale = Vector3.ONE * 0.88
	add_child(body)
	hips = Node3D.new()
	hips.position.y = 0.78
	body.add_child(hips)
	Models.part(hips, Models.box(0.4, 0.18, 0.26), pants)
	torso = Node3D.new()
	hips.add_child(torso)
	Models.part(torso, Models.box(0.46, 0.5, 0.28), shirt, Vector3(0, 0.33, 0))
	Models.part(torso, Models.box(0.47, 0.06, 0.29), Models.mat(Color("4a3424")), Vector3(0, 0.1, 0))
	Models.part(torso, Models.cyl(0.075, 0.08, 0.1, 7), skin, Vector3(0, 0.62, 0))
	var head := Node3D.new()
	head.position.y = 0.82
	torso.add_child(head)
	Models.part(head, Models.sphere(0.2, 12), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.08, 1))
	Models.part(head, Models.sphere(0.207, 12), hair, Vector3(0, 0.03, -0.03), Vector3.ZERO, Vector3(1, 0.9, 1))
	Models.part(head, Models.box(0.06, 0.08, 0.07), skin, Vector3(0, -0.01, 0.2))
	for sx in [-0.075, 0.075]:
		Models.part(head, Models.sphere(0.025, 6), dark, Vector3(sx, 0.04, 0.185))
	Models.part(head, Models.cyl(0.44, 0.44, 0.03, 16), straw, Vector3(0, 0.14, 0))
	Models.part(head, Models.cyl(0.17, 0.21, 0.17, 12), straw, Vector3(0, 0.23, 0))
	Models.part(head, Models.cyl(0.215, 0.215, 0.045, 12), band, Vector3(0, 0.17, 0))
	arm_l = _arm(-1.0, shirt, skin)
	arm_r = _arm(1.0, shirt, skin)
	leg_l = _leg(-1.0, pants, shoe)
	leg_r = _leg(1.0, pants, shoe)
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
	shirt_mat.albedo_color = c


func _arm(side: float, shirt: Material, skin: Material) -> Dictionary:
	var sh := Node3D.new()
	sh.position = Vector3(side * 0.29, 0.52, 0)
	torso.add_child(sh)
	Models.part(sh, Models.cyl(0.075, 0.068, 0.3, 7), shirt, Vector3(0, -0.15, 0))
	var el := Node3D.new()
	el.position.y = -0.3
	sh.add_child(el)
	Models.part(el, Models.cyl(0.062, 0.056, 0.27, 7), skin, Vector3(0, -0.135, 0))
	Models.part(el, Models.sphere(0.07, 7), skin, Vector3(0, -0.3, 0))
	sh.rotation.z = -side * 0.08
	return {"sh": sh, "el": el}


func _leg(side: float, pants: Material, shoe: Material) -> Dictionary:
	var hip := Node3D.new()
	hip.position = Vector3(side * 0.11, -0.06, 0)
	hips.add_child(hip)
	Models.part(hip, Models.cyl(0.1, 0.088, 0.36, 7), pants, Vector3(0, -0.18, 0))
	var knee := Node3D.new()
	knee.position.y = -0.36
	hip.add_child(knee)
	Models.part(knee, Models.cyl(0.083, 0.072, 0.32, 7), pants, Vector3(0, -0.16, 0))
	Models.part(knee, Models.box(0.13, 0.08, 0.25), shoe, Vector3(0, -0.34, 0.05))
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
