class_name Hud
extends CanvasLayer
## Screen UI built in code: stats plate, goal card, inventory strip, action buttons,
## craft/build sheet, build bar, toast, shark warning, start / game-over menu.

signal action(id: String)
signal recipe(id: String)

const INK := Color("f4ecd6")
const DIM := Color(0.957, 0.925, 0.839, 0.66)
const BUOY := Color("ff9f1c")
const PANEL := Color(0.035, 0.12, 0.15, 0.88)

var font: Font
var touch_mode := false
var touch: TouchPad
var _bottom: Control
var _turn_label: Label
var _key_hint := RegEx.create_from_string("\\s*\\([A-Z]\\)$")
var clock: Label
var nav: Label
var build_btn: Button
var _build_action := "build_done"
var bars := {}
var goal_eyebrow: Label
var goal_now: Label
var goal_sub: Label
var inv_label: Label
var btn := {}
var toast_label: Label
var fps_label: Label
var warn_label: Label
var sheet: PanelContainer
var sheet_title: Label
var sheet_list: VBoxContainer
var sheet_scroll: ScrollContainer
var build_bar: PanelContainer
var build_text: Label
var menu: PanelContainer
var menu_box: VBoxContainer
var _toast_t := 0.0


func _ready() -> void:
	# bundled subset of Noto Sans CJK TC: web builds can't use the device's own fonts
	font = load("res://fonts/ui.otf")
	touch_mode = is_touch()
	if touch_mode:
		# phones: lay the UI out on an 854×480 canvas scaled up to the screen, so text stays readable
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = Vector2i(854, 480)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 17
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	# stats plate (top-left)
	var stats := _panel(root)
	stats.position = Vector2(14, 14)
	stats.custom_minimum_size = Vector2(250, 0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	stats.add_child(sv)
	clock = _label(sv, "第 1 天 · 08:00", 14, DIM)
	for k in [["thirst", "口渴", Color("5bc8f0")], ["hunger", "飢餓", Color("f0a548")], ["health", "生命", Color("ef5b5b")], ["oxygen", "氧氣", Color("bdf3ff")]]:
		var row := HBoxContainer.new()
		sv.add_child(row)
		var name_l := _label(row, k[1], 15, INK)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := _label(row, "100", 15, INK)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 7)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.12)
		bg.set_corner_radius_all(3)
		var fg := StyleBoxFlat.new()
		fg.bg_color = k[2]
		fg.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		sv.add_child(bar)
		bars[k[0]] = {"bar": bar, "val": val, "name": name_l, "row": row}
	nav = _label(sv, "", 14, DIM)
	show_oxygen(false)

	# goal card (top-right)
	var goal := _panel(root)
	goal.custom_minimum_size = Vector2(300, 0)
	goal.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	goal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	var gv := VBoxContainer.new()
	goal.add_child(gv)
	goal_eyebrow = _label(gv, "目標 1 / 6", 13, BUOY)
	goal_now = _label(gv, "", 18, INK)
	goal_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_sub = _label(gv, "", 14, DIM)
	goal_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# shark warning + toast
	warn_label = _label(root, "", 18, Color("2b0507"))
	var ws := StyleBoxFlat.new()
	ws.bg_color = Color("ef5b5b")
	ws.set_corner_radius_all(16)
	ws.content_margin_left = 16; ws.content_margin_right = 16; ws.content_margin_top = 6; ws.content_margin_bottom = 6
	warn_label.add_theme_stylebox_override("normal", ws)
	warn_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warn_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	warn_label.visible = false
	toast_label = _label(root, "", 18, INK)
	var ts := StyleBoxFlat.new()
	ts.bg_color = PANEL
	ts.set_corner_radius_all(8)
	ts.content_margin_left = 14; ts.content_margin_right = 14; ts.content_margin_top = 8; ts.content_margin_bottom = 8
	toast_label.add_theme_stylebox_override("normal", ts)
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	toast_label.offset_top -= 150
	toast_label.offset_bottom -= 150
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.modulate.a = 0.0

	# bottom: inventory + actions
	var bottom := VBoxContainer.new()
	_bottom = bottom
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	inv_label = _label(bottom, "", 16, INK)
	var ist := StyleBoxFlat.new()
	ist.bg_color = PANEL
	ist.set_corner_radius_all(10)
	ist.content_margin_left = 12; ist.content_margin_right = 12; ist.content_margin_top = 6; ist.content_margin_bottom = 6
	inv_label.add_theme_stylebox_override("normal", ist)
	# wraps onto a second line instead of pushing the action buttons off-screen
	inv_label.size_flags_horizontal = Control.SIZE_FILL
	inv_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# flows onto a second row on narrow screens instead of running off the edge
	var acts := HFlowContainer.new()
	acts.alignment = FlowContainer.ALIGNMENT_END
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 8)
	bottom.add_child(acts)
	for b in [["fs", "全螢幕"], ["settings", "設定"], ["room", "房間"], ["reel", "收竿"], ["skills", "熟練度"], ["swim", "下水 (F)"], ["eat", "吃東西"], ["drink", "喝水"], ["build", "建造"], ["craft", "合成"]]:
		var bt := _button(acts, b[1], b[0] == "craft")
		var id: String = b[0]
		bt.pressed.connect(func(): action.emit(id))
		btn[id] = bt
	btn["fs"].visible = false
	btn["room"].visible = false

	fps_label = _label(root, "", 13, INK)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 4)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = false

	# craft/build sheet
	sheet = _panel(root)
	sheet.custom_minimum_size = Vector2(460, 0)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)
	var shv := VBoxContainer.new()
	shv.add_theme_constant_override("separation", 8)
	sheet.add_child(shv)
	var head := HBoxContainer.new()
	shv.add_child(head)
	sheet_title = _label(head, "合成", 18, INK)
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(head, "關閉", false)
	close.pressed.connect(func(): sheet.visible = false)
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shv.add_child(sheet_scroll)
	sheet_list = VBoxContainer.new()
	sheet_list.add_theme_constant_override("separation", 6)
	sheet_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.add_child(sheet_list)
	sheet.visible = false

	# build bar
	build_bar = _panel(root)
	build_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	build_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 12)
	build_bar.add_child(bb)
	build_text = _label(bb, "", 16, INK)
	build_btn = _button(bb, "完成", true)
	build_btn.pressed.connect(func(): action.emit(_build_action))
	build_bar.visible = false

	# menu
	menu = _panel(root)
	menu.custom_minimum_size = Vector2(520, 0)
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu.add_child(menu_box)


	if touch_mode:
		touch = TouchPad.new()
		touch.font = font
		root.add_child(touch)
		root.move_child(touch, 0)   # under the panels, so menus draw on top
		_turn_label = _label(root, "請把手機橫過來玩 ↻", 26, INK)
		_turn_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var tb := StyleBoxFlat.new()
		tb.bg_color = Color(0.02, 0.08, 0.1, 0.96)
		_turn_label.add_theme_stylebox_override("normal", tb)
		_turn_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_turn_label.visible = false


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(0.957, 0.925, 0.839, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	var states := {"normal": 1.0, "hover": 1.12, "pressed": 0.85, "disabled": 0.5}
	for st in states:
		var sb := StyleBoxFlat.new()
		var base := BUOY if primary else PANEL
		sb.bg_color = Color(base.r * states[st], base.g * states[st], base.b * states[st], base.a if st != "disabled" else 0.4)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 16; sb.content_margin_right = 16
		if not primary:
			sb.border_color = Color(0.957, 0.925, 0.839, 0.16)
			sb.set_border_width_all(1)
		b.add_theme_stylebox_override(st, sb)
	var fc := Color("2a1700") if primary else INK
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.add_theme_font_size_override("font_size", 17)
	parent.add_child(b)
	return b


func set_stat(id: String, v: float, text: String) -> void:
	bars[id].bar.value = v
	bars[id].val.text = text
	var low := v < 25.0
	bars[id].name.add_theme_color_override("font_color", Color("ef5b5b") if low else INK)


func _recenter(c: Control, preset: int, margin: int, yoff: float) -> void:
	c.reset_size()
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.offset_top += yoff
	c.offset_bottom += yoff


func show_oxygen(on: bool) -> void:
	bars.oxygen.row.visible = on
	bars.oxygen.bar.visible = on


func toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	_toast_t = 2.0
	_recenter.call_deferred(toast_label, Control.PRESET_CENTER, 0, -150.0)


func set_warn(msg: String) -> void:
	if warn_label.text == msg:
		return
	warn_label.visible = msg != ""
	warn_label.text = msg
	_recenter.call_deferred(warn_label, Control.PRESET_CENTER_TOP, 16, 0.0)


func _process(delta: float) -> void:
	_bottom.visible = not menu.visible
	if touch_mode:
		# no keyboard on a phone: drop the "(F)" style key hints from button labels
		for b in btn.values():
			var t: String = b.text
			var m := _key_hint.search(t)
			if m != null:
				b.text = t.substr(0, m.get_start())
		touch.visible = not menu.visible and not sheet.visible
		var vs := get_viewport().get_visible_rect().size
		_turn_label.visible = vs.x < vs.y
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.3:
			toast_label.modulate.a = maxf(0.0, _toast_t / 0.3)


## rows: [{id, name, desc, cost_text, ok, label}]
func show_sheet(title: String, rows: Array) -> void:
	sheet_title.text = title
	for c in sheet_list.get_children():
		sheet_list.remove_child(c)
		c.queue_free()
	for r in rows:
		if r.get("header", false):
			# a stage heading: a coloured line, then what unlocks it (if still locked)
			var hb := VBoxContainer.new()
			hb.add_theme_constant_override("separation", 2)
			sheet_list.add_child(hb)
			var gap := Control.new()
			gap.custom_minimum_size.y = 4
			hb.add_child(gap)
			_label(hb, r.name, 16, BUOY if r.ok else DIM)
			if r.desc != "":
				var hd := _label(hb, r.desc, 13, Color("ef9b5b"))
				hd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				hd.custom_minimum_size.x = 300
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(0, 2)
			line.color = Color(BUOY, 0.5) if r.ok else Color(DIM, 0.35)
			hb.add_child(line)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sheet_list.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		if r.get("dim", false):
			row.modulate = Color(1, 1, 1, 0.55)
		_label(col, r.name, 17, INK)
		var d := _label(col, r.desc, 13, DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 300
		if r.cost_text != "":
			var cc: Color = r.get("cost_color", Color("ef5b5b") if not r.ok else Color("7fd88a"))
			_label(col, r.cost_text, 13, cc)
		if r.label == "":
			continue
		var b := _button(row, r.label, true)
		b.disabled = not r.ok
		var id: String = r.id
		b.pressed.connect(func(): recipe.emit(id))
	# rows are ~80 px tall; cap the list so long sheets scroll instead of leaving the screen
	# ...and never taller than the screen leaves room for (phones are only 480 UI px tall)
	var room := get_viewport().get_visible_rect().size.y - 200.0
	sheet_scroll.custom_minimum_size = Vector2(440, minf(rows.size() * 82.0, clampf(room, 160.0, 400.0)))
	sheet_scroll.scroll_vertical = 0
	sheet.size = Vector2.ZERO
	sheet.visible = true
	_recenter.call_deferred(sheet, Control.PRESET_CENTER_BOTTOM, 120, 0.0)


func show_build_bar(text: String, btn_text := "完成", action_id := "build_done") -> void:
	build_text.text = text
	build_btn.text = btn_text
	_build_action = action_id
	build_bar.visible = text != ""
	_recenter.call_deferred(build_bar, Control.PRESET_CENTER_BOTTOM, 120, 0.0)


func show_menu(kicker: String, title: String, body: String, buttons: Array) -> void:
	for c in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	_label(menu_box, kicker, 14, BUOY)
	_label(menu_box, title, 44, INK)
	var b := _label(menu_box, body, 16, DIM)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 480
	# flows onto more rows (a long list of friends' rooms, narrow phones)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	menu_box.add_child(row)
	for bt in buttons:
		var x := _button(row, bt[1], bt[2])
		var id: String = bt[0]
		x.pressed.connect(func(): action.emit(id))
	menu.visible = true
	_recenter.call_deferred(menu, Control.PRESET_CENTER, 0, 0.0)


func hide_menu() -> void:
	menu.visible = false


## Phones and tablets (or FORCE_TOUCH=1 when testing on a desktop).
static func is_touch() -> bool:
	return OS.get_environment("FORCE_TOUCH") == "1" or OS.has_feature("mobile") or OS.has_feature("web_android") \
		or OS.has_feature("web_ios") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())


func over_ui(pos: Vector2) -> bool:
	for c in [sheet, build_bar, menu]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	for b in btn.values():
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	if inv_label.get_global_rect().has_point(pos):
		return true
	return false
