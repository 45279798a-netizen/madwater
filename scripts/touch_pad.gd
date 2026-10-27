class_name TouchPad
extends Control
## On-screen controls for phones: a move stick (bottom-left) and hold buttons for diving / surfacing.
## Works on raw touch indices, so walking with one thumb while looking around or holding
## 上浮 with the other is fine. Fingers it owns are listed in `claimed` so the game ignores them.

const STICK_R := 58.0
const KNOB_R := 26.0
const HOLD_R := 34.0

var stick := Vector2.ZERO        ## x right, y forward, length ≤ 1
var up := false
var down := false
var show_dive := false
var claimed := {}                ## touch index -> "stick" | "up" | "down"
var font: Font
var _stick_centre := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _home() -> Vector2:
	return Vector2(STICK_R + 30.0, size.y - STICK_R - 100.0)


func _hold_pos(which: String) -> Vector2:
	var x := size.x - HOLD_R - 26.0
	return Vector2(x, size.y - 150.0 - (HOLD_R * 2.0 + 18.0 if which == "up" else 0.0))


## Where a finger has to land to grab the stick: the lower-left quarter, above the inventory strip.
func _stick_zone(p: Vector2) -> bool:
	return p.x < size.x * 0.38 and p.y > size.y * 0.38 and p.y < size.y - 70.0


func owns(p: Vector2) -> bool:
	if _stick_zone(p):
		return true
	if show_dive:
		for w in ["up", "down"]:
			if p.distance_to(_hold_pos(w)) < HOLD_R + 10.0:
				return true
	return false


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		var p := _to_local(st.position)
		if st.pressed:
			if _stick_zone(p) and not claimed.values().has("stick"):
				claimed[st.index] = "stick"
				_stick_centre = p
				_move_knob(p)
			elif show_dive:
				for w in ["up", "down"]:
					if p.distance_to(_hold_pos(w)) < HOLD_R + 10.0:
						claimed[st.index] = w
						set(w, true)
		elif claimed.has(st.index):
			var what: String = claimed[st.index]
			claimed.erase(st.index)
			if what == "stick":
				stick = Vector2.ZERO
				_knob = Vector2.ZERO
			else:
				set(what, false)
		queue_redraw()
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if claimed.get(sd.index, "") == "stick":
			_move_knob(_to_local(sd.position))
			queue_redraw()


func _to_local(screen: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen


func _move_knob(p: Vector2) -> void:
	var d := p - _stick_centre
	if d.length() > STICK_R:
		# drag the base along so the stick never "runs out"
		_stick_centre += d - d.normalized() * STICK_R
		d = p - _stick_centre
	_knob = d
	var v := d / STICK_R
	stick = Vector2(v.x, -v.y) if v.length() > 0.12 else Vector2.ZERO


func release_all() -> void:
	claimed.clear()
	stick = Vector2.ZERO
	_knob = Vector2.ZERO
	up = false
	down = false
	queue_redraw()


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := _stick_centre if claimed.values().has("stick") else _home()
	draw_circle(c, STICK_R, Color(0.035, 0.12, 0.15, 0.45))
	draw_arc(c, STICK_R, 0.0, TAU, 48, Color(0.96, 0.93, 0.84, 0.5), 2.0, true)
	draw_circle(c + _knob, KNOB_R, Color(0.96, 0.93, 0.84, 0.75))
	if show_dive and font != null:
		for w in ["up", "down"]:
			var p := _hold_pos(w)
			var on: bool = get(w)
			draw_circle(p, HOLD_R, Color(1.0, 0.62, 0.11, 0.95) if on else Color(0.035, 0.12, 0.15, 0.7))
			draw_arc(p, HOLD_R, 0.0, TAU, 40, Color(0.96, 0.93, 0.84, 0.55), 2.0, true)
			var txt := "上浮" if w == "up" else "下潛"
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string(font, p + Vector2(-sz.x / 2.0, 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4ecd6"))
