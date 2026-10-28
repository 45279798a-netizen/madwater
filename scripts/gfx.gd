class_name Gfx
extends RefCounted
## Graphics settings: four presets and the individual knobs behind them, saved in
## user://settings.cfg (browser storage on the web build).

const PATH := "user://settings.cfg"
const PRESETS := {
	"low":    {"scale": 0, "shadows": 0, "ocean": 0, "clouds": 0, "bumps": 0, "msaa": 0, "glow": 0, "fps": 0},
	"medium": {"scale": 1, "shadows": 1, "ocean": 1, "clouds": 1, "bumps": 0, "msaa": 0, "glow": 0, "fps": 1},
	"high":   {"scale": 2, "shadows": 2, "ocean": 2, "clouds": 2, "bumps": 1, "msaa": 1, "glow": 0, "fps": 1},
	"ultra":  {"scale": 3, "shadows": 3, "ocean": 3, "clouds": 3, "bumps": 1, "msaa": 2, "glow": 1, "fps": 2},
}
const PRESET_NAME := {"low": "低", "medium": "中", "high": "高", "ultra": "極高", "custom": "自訂"}
## knob -> [label, description, value names]
const KNOBS := {
	"scale": ["解析度", "3D 畫面的清晰度；越低越模糊但越順", ["50%", "70%", "85%", "100%"]],
	"shadows": ["陰影", "人和東西的影子；關掉最省電", ["關", "低", "中", "高"]],
	"ocean": ["海面細緻度", "浪的網格密度，越高海浪越圓滑", ["低", "中", "高", "極高"]],
	"clouds": ["雲", "天空雲層的細節", ["簡單", "一般", "細緻", "非常細緻"]],
	"bumps": ["材質細節", "木紋、石頭的凹凸感；關掉比較順", ["簡單", "精細"]],
	"msaa": ["反鋸齒", "讓邊緣不會一格一格的", ["關", "2 倍", "4 倍"]],
	"glow": ["光暈", "太陽和火光的柔光效果", ["關", "開"]],
	"fps": ["幀率上限", "限制每秒畫面數；30 比較省電", ["30", "60", "不限"]],
	"show_fps": ["顯示 FPS", "在畫面上方顯示每秒畫面數", ["關", "開"]],
}

var preset := "medium"
var v := {}


func _init() -> void:
	preset = "medium" if Hud.is_touch() or OS.has_feature("web") else "ultra"
	v = PRESETS[preset].duplicate()
	v["show_fps"] = 0
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		preset = str(cf.get_value("gfx", "preset", preset))
		for k in KNOBS:
			v[k] = int(cf.get_value("gfx", k, v.get(k, 0)))
		if not cf.has_section_key("gfx", "bumps") and PRESETS.has(preset):
			v["bumps"] = PRESETS[preset].bumps   # settings saved before this knob existed


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "preset", preset)
	for k in v:
		cf.set_value("gfx", k, v[k])
	cf.save(PATH)


func use_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	preset = name
	var keep: int = v.get("show_fps", 0)
	v = PRESETS[name].duplicate()
	v["show_fps"] = keep
	save()


## Step one knob to its next value (wraps around).
func cycle(k: String) -> void:
	if not KNOBS.has(k):
		return
	v[k] = (int(v.get(k, 0)) + 1) % (KNOBS[k][2] as Array).size()
	if k != "show_fps":
		preset = "custom"
		for p in PRESETS:
			var same := true
			for kk in PRESETS[p]:
				if int(PRESETS[p][kk]) != int(v[kk]):
					same = false
			if same:
				preset = p
	save()


func value_name(k: String) -> String:
	return (KNOBS[k][2] as Array)[clampi(int(v.get(k, 0)), 0, (KNOBS[k][2] as Array).size() - 1)]


## Push the settings into the running game.
func apply(g) -> void:
	var vp: Viewport = g.get_viewport()
	vp.scaling_3d_scale = [0.5, 0.7, 0.85, 1.0][int(v.scale)]
	var sh := int(v.shadows)
	g.sun.shadow_enabled = sh > 0
	if sh > 0:
		RenderingServer.directional_shadow_atlas_set_size([1024, 1024, 2048, 4096][sh], true)
		g.sun.directional_shadow_max_distance = [0.0, 28.0, 45.0, 75.0][sh]
		# each shadow split draws every caster again: phones get one, the top setting four
		g.sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_ORTHOGONAL,
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][sh]
	g.ocean.set_detail(int(v.ocean))
	g.sky_mat.mat.set_shader_parameter("octaves", [3, 4, 5, 6][int(v.clouds)])
	g.sky_mat.mat.set_shader_parameter("quality", [0, 1, 2, 2][int(v.clouds)])
	Models.set_bumps(int(v.get("bumps", 1)) == 1)
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(v.msaa)]
	g.env.glow_enabled = int(v.glow) == 1
	Engine.max_fps = [30, 60, 0][int(v.fps)]
	g.hud.fps_label.visible = int(v.show_fps) == 1
