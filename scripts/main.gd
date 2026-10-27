extends Node3D
## 瘋狂水世界 — survival prototype.
## Hook debris, desalinate water, fish and grill, expand the raft, sail to islands, fend off the shark.
## Controls: WASD move (A/D steer at the helm) · drag mouse to orbit · wheel zoom · left click to interact
##           E eat · Q drink · R reel in · C craft · B build · Esc close · K shark on/off (creative)

const TILE := 2.0
const HOOK_RANGE := 14.0
const FISH_RANGE := 9.0
const REACH := 4.5
const SPEAR_REACH := 6.5
const DAY_LEN := 240.0
const THIRST_SEC := 240.0
const HUNGER_SEC := 420.0
const CURRENT := Vector2(0.0, 0.95)
const ARROWS := ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
const SAVE_PATH := "user://madwater_save.json"
const AUTOSAVE_SEC := 30.0
const SWIM_SPEED := 2.4
const DIVE_SPEED := 2.0
const O2_BASE := 30.0
const SEA_FLOOR := -45.0
const SEABED_GIVE := {"sand": {"sand": 2}, "clay": {"clay": 2}, "ore": {"ore": 1}, "kelp": {"kelp": 2}}
const WRECK_GIVE := {"ore": 4, "rope": 3, "plastic": 4, "seed_melon": 2, "shell": 10}

const ITEMS := {
	"wood": "木板", "plastic": "塑膠", "palm": "棕櫚葉", "rope": "繩子", "coconut": "椰子",
	"rawfish": "生魚", "cooked": "烤魚", "cup": "塑膠杯", "water": "淡水", "spear": "木矛", "rod": "釣竿",
	"sand": "沙", "clay": "黏土", "ore": "金屬礦", "goggles": "潛水鏡", "mspear": "金屬矛",
	"potato": "馬鈴薯", "tomato": "番茄", "melon": "西瓜", "kelp": "海帶", "egg": "蛋", "milk": "羊奶",
	"bpotato": "烤馬鈴薯", "fegg": "荷包蛋", "tjuice": "番茄汁", "mjuice": "西瓜汁",
	"seed_potato": "馬鈴薯種子", "seed_tomato": "番茄種子", "seed_melon": "西瓜種子", "chicken": "雞", "goat": "山羊",
	"shell": "貝殼幣", "bait": "魚餌", "rod2": "好釣竿",
}
const ORDER := ["shell", "bait", "rod2", "seed_potato", "seed_tomato", "seed_melon", "potato", "tomato", "melon", "kelp", "egg", "milk",
	"bpotato", "fegg", "tjuice", "mjuice", "chicken", "goat", "wood", "plastic", "palm", "rope", "sand", "clay", "ore", "coconut", "rawfish", "cooked", "cup", "water", "spear", "mspear", "rod", "goggles"]
const CRAFT := [
	{"id": "rope", "name": "繩子", "desc": "用來做工具和設備", "cost": {"palm": 2}, "give": {"rope": 1}},
	{"id": "cup", "name": "塑膠杯", "desc": "裝 1 杯淡水，杯子越多能帶越多水", "cost": {"plastic": 2}, "give": {"cup": 1}},
	{"id": "spear", "name": "木矛", "desc": "點擊靠近的鯊魚刺牠，刺 3 下就會逃走", "cost": {"wood": 6, "rope": 2}, "give": {"spear": 1}, "once": true},
	{"id": "rod", "name": "釣竿", "desc": "點木筏旁的海面拋竿，浮標下沉時按 R 收竿", "cost": {"wood": 4, "rope": 3}, "give": {"rod": 1}, "once": true},
	{"id": "goggles", "name": "潛水鏡", "desc": "水裡看得清楚，才能挖沙、黏土和金屬礦", "cost": {"plastic": 4, "rope": 1}, "give": {"goggles": 1}, "once": true},
	{"id": "mspear", "name": "金屬矛", "desc": "刺一下的傷害是木矛的 2 倍", "cost": {"ore": 3, "wood": 2, "rope": 1}, "give": {"mspear": 1}, "once": true},
	{"id": "tjuice", "name": "番茄汁", "desc": "口渴 +15、飢餓 +5", "cost": {"tomato": 2}, "give": {"tjuice": 1}},
	{"id": "mjuice", "name": "西瓜汁", "desc": "口渴 +40", "cost": {"melon": 1}, "give": {"mjuice": 2}},
	{"id": "bag30", "name": "帆布背包", "desc": "背包從 20 格擴到 30 格", "cost": {"palm": 10, "rope": 4}, "give": {}, "bag": 30},
	{"id": "bag40", "name": "防水背包", "desc": "擴到 40 格；去過 2 座小島才會做", "cost": {"plastic": 10, "rope": 6, "wood": 2}, "give": {}, "bag": 40},
]
const BUILD := [
	{"id": "floor", "name": "地板", "desc": "擴建木筏 1 格", "cost": {"wood": 4, "plastic": 2}},
	{"id": "wall", "name": "牆", "desc": "立在地板邊上，擋風擋浪，人走不過去", "cost": {"wood": 4, "rope": 1}},
	{"id": "window", "name": "窗牆", "desc": "有窗的牆，看得到外面", "cost": {"wood": 3, "rope": 1}},
	{"id": "door", "name": "門", "desc": "開著的門，可以走過去", "cost": {"wood": 4, "rope": 2}},
	{"id": "pillar", "name": "支柱", "desc": "立在地板的角落，撐住二樓或屋頂", "cost": {"wood": 2, "rope": 1}},
	{"id": "upper", "name": "二樓地板", "desc": "鋪在有牆或支柱撐著的地板上方，可以往外多伸 1 格", "cost": {"wood": 4, "plastic": 2}},
	{"id": "stairs", "name": "樓梯", "desc": "放在二樓地板旁邊的空地板上，點它上下樓", "cost": {"wood": 6, "rope": 2}},
	{"id": "rail", "name": "欄杆", "desc": "圍在二樓邊緣", "cost": {"wood": 2}},
	{"id": "roof", "name": "屋頂", "desc": "蓋在牆或支柱上，一格一格鋪，連成一片", "cost": {"palm": 4, "wood": 2}},
	{"id": "still", "name": "塑膠蒸餾杯", "desc": "放木板當柴火，每 20 秒蒸出 1 杯淡水", "cost": {"plastic": 6, "wood": 4, "rope": 2}},
	{"id": "grill", "name": "簡易烤架", "desc": "放上生魚和 1 塊木板，15 秒烤好，一次最多 2 條", "cost": {"wood": 6, "rope": 2}},
	{"id": "sail", "name": "船帆", "desc": "點它升帆或收帆，順風最快；沒有船舵時會順著風漂", "cost": {"wood": 4, "palm": 6, "rope": 3}},
	{"id": "helm", "name": "船舵", "desc": "站到船舵旁點它，用 A / D 操控航向", "cost": {"wood": 6, "rope": 2}},
	{"id": "chest", "name": "儲物箱", "desc": "放在木筏上，背包容量 +12 格", "cost": {"wood": 6, "rope": 2}},
	{"id": "field", "name": "菜田（每格）", "desc": "一格種 4 株，相鄰的菜田連成一片，要澆淡水", "cost": {"clay": 3, "wood": 2}},
	{"id": "kelpfarm", "name": "海藻養殖架（每格）", "desc": "一格養 1 條海帶，連成一排一起收，不用淡水", "cost": {"rope": 3, "wood": 2, "plastic": 2}},
	{"id": "coop", "name": "雞舍（每格）", "desc": "一格住 2 隻雞，連起來的雞舍共用飼料，2 隻以上會孵小雞", "cost": {"wood": 4, "palm": 3, "rope": 1}},
	{"id": "pen", "name": "山羊圍欄（每格）", "desc": "一格住 1 隻山羊，2 隻以上有空位會生小羊", "cost": {"wood": 4, "rope": 2}},
	{"id": "gullnest", "name": "海鷗巢", "desc": "收服的海鷗休息的地方", "cost": {"palm": 4, "wood": 2}},
	{"id": "dolphinpost", "name": "海豚韁繩柱", "desc": "海豚休息的地方；跟著你的海豚會綁上韁繩幫你拉船", "cost": {"wood": 4, "rope": 3}},
	{"id": "turtletank", "name": "海龜水槽", "desc": "收服的海龜休息的地方", "cost": {"plastic": 4, "wood": 2, "clay": 2}},
	{"id": "catcher", "name": "集雨布", "desc": "下雨時接雨水，最多存 4 杯；要放在沒有屋頂的地方", "cost": {"plastic": 4, "wood": 4, "rope": 2}},
	{"id": "filter", "name": "陶瓷濾水缸", "desc": "不用柴火，每 30 秒濾出 1 杯淡水，最多存 3 杯", "cost": {"clay": 6, "sand": 4, "wood": 2}},
]
const OBJ_NAME := {"still": "蒸餾杯", "grill": "烤架", "sail": "船帆", "helm": "船舵", "chest": "儲物箱", "filter": "陶瓷濾水缸", "field": "菜田", "kelpfarm": "海藻養殖架", "coop": "雞舍", "pen": "山羊圍欄", "stairs": "樓梯", "catcher": "集雨布", "gullnest": "海鷗巢", "dolphinpost": "海豚韁繩柱", "turtletank": "海龜水槽",
	"wall": "牆", "window": "窗牆", "door": "門", "pillar": "支柱", "upper": "二樓地板", "rail": "欄杆", "roof": "屋頂"}
## crop: [seed item, grow seconds (prototype speed), harvest item, harvest count]
const CROPS := {"potato": ["seed_potato", 120.0, "potato", 3], "tomato": ["seed_tomato", 90.0, "tomato", 4], "melon": ["seed_melon", 180.0, "melon", 1]}
const CROP_NAME := {"potato": "馬鈴薯", "tomato": "番茄", "melon": "西瓜"}
## raw item -> [grilled item, its name]
const GRILL := {"rawfish": ["cooked", "烤魚"], "potato": ["bpotato", "烤馬鈴薯"], "egg": ["fegg", "荷包蛋"]}
## food: [hunger, thirst]
const FOOD := {"cooked": [38, 0], "fegg": [25, 0], "coconut": [22, 8], "bpotato": [20, 0], "rawfish": [12, 0], "potato": [8, 0], "tomato": [6, 4]}
## drink: [thirst, hunger]
const DRINK := {"water": [35, 0], "mjuice": [40, 0], "milk": [20, 15], "tjuice": [15, 5]}
## skill id: [name, how it is trained, what each level gives]
const SKILLS := {
	"hook": ["打撈", "用鉤子撿漂流物", "鉤子範圍每級 +0.5 公尺，收線每級快 5%"],
	"swim": ["游泳與潛水", "在水裡潛水、挖海底資源", "氧氣每級 +3 秒，游速每級快 5%"],
	"fish": ["釣魚", "釣到魚", "上鉤更快、收竿時間更寬、大魚機率提高"],
	"build": ["建造", "蓋地板和設備", "建造材料每級 -2%（最多 -20%）"],
	"cook": ["料理", "烤魚、吃東西", "食物回復每級 +3%"],
	"water": ["淨水", "從蒸餾杯裝水", "蒸餾時間每級 -3%"],
	"combat": ["戰鬥", "用木矛刺鯊魚", "每級 8% 機率一次刺出 2 下"],
}
## how many of an item fit in one backpack slot (water lives in the cups, so it takes none)
const STACK := {"shell": 999, "bait": 20, "rod2": 1, "potato": 10, "tomato": 10, "melon": 5, "kelp": 20, "egg": 10, "milk": 5, "bpotato": 10, "fegg": 10,
	"tjuice": 5, "mjuice": 5, "seed_potato": 20, "seed_tomato": 20, "seed_melon": 20, "chicken": 6, "goat": 3, "sand": 20, "clay": 20, "ore": 20, "goggles": 1, "mspear": 1, "wood": 20, "plastic": 20, "palm": 20, "rope": 20, "coconut": 10, "rawfish": 10, "cooked": 10, "cup": 10, "spear": 1, "rod": 1}
const MODES := {"peaceful": "和平", "standard": "標準", "hardcore": "硬派", "creative": "創造"}
const BAG_TTL := 600.0
const DEBRIS := {
	"plank": {"w": 40, "give": {"wood": 2}},
	"plastic": {"w": 30, "give": {"plastic": 1}},
	"palm": {"w": 20, "give": {"palm": 2}},
	"coconut": {"w": 7, "give": {"coconut": 1}},
	"barrel": {"w": 3, "give": {"wood": 3, "plastic": 2, "palm": 2}},
	"cage": {"w": 2, "give": {"chicken": 1}},
}

var ocean: Ocean
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var cam: Camera3D
var hud: Hud
var sfx: Sfx
var raft: Node3D
var player: PlayerRig
var shark_rig: SharkRig
var hook_line: MeshInstance3D
var hook_ball: MeshInstance3D
var bobber: Node3D
var ring: MeshInstance3D

var raft_pos := Vector2.ZERO
var raft_vel := Vector2.ZERO
var heading := 0.0
var wind := 0.0
var tiles := {}
var objs: Array = []
var debris: Array = []
var ghosts: Array = []
var islands: Array = []
var inv := {}
var S := {}
var P := {}
var hook = null
var fishing = null
var steer = null
var shark := {}
var swim = null
var seabed_nodes: Array = []
var seaweeds: Array = []
var seabed_mat: ShaderMaterial
var uw_overlay: ColorRect
var wreck_node: Dictionary = {}
var cam_yaw := 0.7
var cam_pitch := 0.55
var cam_dist := 11.0
var cam_target := Vector3(1, 1, 1)

var paused := true
var over := false
var creative := false
var farm: Farm
var traders: Traders
var shelter: Shelter
var weather: Weather
var companions: Companions
var net: Net
var _host_after_start := false
var _mp_menu := false
var _nid := 0
var _nt_have := false
var _nt_raft := Vector2.ZERO
var _nt_vel := Vector2.ZERO
var _nt_heading := 0.0
var _nt_shark: Array = []
var _steer_quiet := 0.0
var _js_cb = null          ## browser test hook (?mwtest): window.mwAction(id), window.mwInfo
var _js_info_t := 0.0
var _code_entry := ""      ## room code being typed on the number pad
var _screen_t := 0.0
var _screen_cache := {}
var mode := "standard"
var skills := {}
var shark_on := true
var game_t := 0.0
var wall_t := 0.0
var spawn_t := 0.0
var goal_t := 0.0
var wake_t := 0.0
var build_mode := ""
var sheet_mode := ""
var goals_done := 0
var _drag := {}
var _touches := {}       ## finger index -> {start, pos, t, moved, multi}
var _pinch := 0.0
var _ghost_mat: StandardMaterial3D
var _demo_mat: StandardMaterial3D
var _font: Font
var _steer_text := ""
var _autosave_t := AUTOSAVE_SEC


# ---------------------------------------------------------------- setup

func _ready() -> void:
	randomize()
	farm = Farm.new(self)
	traders = Traders.new(self)
	shelter = Shelter.new(self)
	weather = Weather.new(self)
	companions = Companions.new(self)
	_font = load("res://fonts/ui.otf")
	_setup_world()
	weather.setup(self)
	_setup_actors()
	_setup_islands()
	_setup_seabed()
	companions.setup()
	hud = Hud.new()
	add_child(hud)
	hud.action.connect(_on_action)
	hud.recipe.connect(_on_recipe)
	sfx = Sfx.new()
	add_child(sfx)
	net = Net.new(self)
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("mwtest"):
		_js_cb = JavaScriptBridge.create_callback(func(args): _on_action(str(args[0])))
		JavaScriptBridge.get_interface("window").mwAction = _js_cb
	_reset()
	_show_start()


func _setup_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.12
	env.glow_enabled = true
	env.glow_intensity = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	if OS.has_feature("web"):
		# browsers (and phones) run the lighter GL renderer: trim the expensive bits
		env.glow_enabled = false
		env.tonemap_exposure = 0.88
		sun.directional_shadow_max_distance = 40.0
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		Ocean.lite = true
	if Hud.is_touch():
		get_viewport().scaling_3d_scale = 0.7
		Ocean.lite = true
	ocean = Ocean.new()
	add_child(ocean)
	var uw := CanvasLayer.new()
	uw.layer = -1
	add_child(uw)
	uw_overlay = ColorRect.new()
	uw_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	uw_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uw_overlay.color = Color(0.04, 0.3, 0.36, 0.2)
	uw_overlay.visible = false
	uw.add_child(uw_overlay)
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	wind = ocean.wind


func _setup_actors() -> void:
	raft = Node3D.new()
	add_child(raft)
	player = PlayerRig.new()
	raft.add_child(player)
	shark_rig = SharkRig.new()
	add_child(shark_rig)
	hook_ball = Models.part(self, Models.sphere(0.12, 8), Models.mat(Color("3a3f44")))
	hook_ball.visible = false
	bobber = Models.bobber()
	bobber.visible = false
	add_child(bobber)
	hook_line = MeshInstance3D.new()
	hook_line.mesh = ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color("f4ecd6")
	hook_line.material_override = lm
	add_child(hook_line)
	var torus := TorusMesh.new()
	torus.inner_radius = HOOK_RANGE - 0.08
	torus.outer_radius = HOOK_RANGE
	torus.rings = 96
	torus.ring_segments = 4
	var rm := Models.ghost(Color(1, 1, 1), 0.28)
	rm.no_depth_test = true
	ring = Models.part(self, torus, rm)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_mat = Models.ghost(Color("ff9f1c"), 0.4)
	_demo_mat = Models.ghost(Color("ef5b5b"), 0.45)


func _setup_islands() -> void:
	for spec in [[78.0, 0.35, 7.0], [135.0, -0.75, 9.0], [195.0, 1.45, 8.0], [255.0, 2.9, 10.0]]:
		var ang: float = ocean.wind + spec[1]
		var r: float = spec[2]
		var m := Models.island(r)
		var node: Node3D = m.node
		node.position = Vector3(1.0 + cos(ang) * spec[0], 0.0, 1.0 + sin(ang) * spec[0])
		add_child(node)
		var isl := {"x": node.position.x, "z": node.position.z, "r": r, "node": node, "nodes": m.nodes, "visited": false, "bump": 0.0}
		for n in isl.nodes:
			n["island"] = isl
		islands.append(isl)
	var gi: Dictionary = islands[2]
	var gn := Models.goat()
	gn.position = Vector3(-gi.r * 0.35, 0.65, gi.r * 0.3)
	gn.rotation.y = 0.8
	gi.node.add_child(gn)
	gi.nodes.append({"kind": "goat", "node": gn, "used": false, "hit": Vector3(0, 0.6, 0), "island": gi})


## Sea-floor height: shallow shelves around each island, open ocean far below.
func seabed_h(x: float, z: float) -> float:
	var h := SEA_FLOOR
	for isl in islands:
		var d := Vector2(x - isl.x, z - isl.z).length()
		var base: float = isl.r * 1.75
		var hi: float
		if d < base + 42.0:
			var k := clampf((d - base) / 42.0, 0.0, 1.0)
			hi = lerpf(-2.5, -15.0, k * k * (3.0 - 2.0 * k))
		else:
			var k2 := clampf((d - base - 42.0) / 50.0, 0.0, 1.0)
			hi = lerpf(-15.0, SEA_FLOOR, k2 * k2 * (3.0 - 2.0 * k2))
		h = maxf(h, hi)
	return h + sin(x * 0.31) * sin(z * 0.27) * 0.35 + sin((x + z) * 0.13) * 0.25


func _setup_seabed() -> void:
	seabed_mat = ShaderMaterial.new()
	seabed_mat.shader = load("res://shaders/seabed.gdshader")
	for isl in islands:
		var mi := MeshInstance3D.new()
		mi.mesh = _seabed_patch(isl)
		mi.material_override = seabed_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	Models.part(self, Models.box(1400, 1, 1400), Models.mat(Color("23343a"), 1.0), Vector3(1, SEA_FLOOR - 0.6, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for isl in islands:
		var base: float = isl.r * 1.75
		for k in 30:
			var a := rng.randf() * TAU
			var d := base + rng.randf_range(2.0, 40.0)
			var x: float = isl.x + cos(a) * d
			var z: float = isl.z + sin(a) * d
			var h := seabed_h(x, z)
			if h < -15.5:
				continue
			var roll := rng.randf()
			var kind := "sand" if roll < 0.4 else ("clay" if roll < 0.75 else "ore")
			if kind == "ore" and h > -7.0:
				kind = "clay"
			var node: Node3D
			match kind:
				"sand":
					node = Models.sand_mound(rng)
				"clay":
					node = Models.clay_lump(rng)
				_:
					node = Models.ore_rock(rng)
			node.position = Vector3(x, h, z)
			node.rotation.y = rng.randf() * TAU
			add_child(node)
			seabed_nodes.append({"kind": kind, "node": node, "pos": Vector3(x, h, z), "cd": 0.0})
		for k in 24:
			var a := rng.randf() * TAU
			var d := base + rng.randf_range(1.0, 38.0)
			var x: float = isl.x + cos(a) * d
			var z: float = isl.z + sin(a) * d
			var w := Models.seaweed(rng) if k % 3 != 0 else Models.coral(rng)
			w.position = Vector3(x, seabed_h(x, z), z)
			w.rotation.y = rng.randf() * TAU
			add_child(w)
			if k % 3 != 0:
				seaweeds.append([w, rng.randf() * TAU])
				seabed_nodes.append({"kind": "kelp", "node": w, "pos": w.position, "cd": 0.0})
	# a sunken boat off the second island
	var isl2: Dictionary = islands[1]
	var wa := 2.0
	var wd: float = isl2.r * 1.75 + 24.0
	var wx: float = isl2.x + cos(wa) * wd
	var wz: float = isl2.z + sin(wa) * wd
	var wm := Models.wreck()
	var wn: Node3D = wm.node
	wn.position = Vector3(wx, seabed_h(wx, wz) - 0.2, wz)
	wn.rotation.y = wa + 1.3
	add_child(wn)
	var chest: Node3D = wm.chest
	wreck_node = {"kind": "wreck", "node": chest, "pos": chest.global_position, "used": false}
	seabed_nodes.append(wreck_node)


func _seabed_patch(isl: Dictionary) -> ArrayMesh:
	var half: float = isl.r * 1.75 + 95.0
	var step := 2.5
	var n := int(half * 2.0 / step)
	var x0: float = isl.x - half
	var z0: float = isl.z - half
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			hs[j * (n + 1) + i] = seabed_h(x0 + i * step, z0 + j * step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var shallow := Color("d9c48c")
	var deep := Color("5f6f66")
	for j in n + 1:
		for i in n + 1:
			var h := hs[j * (n + 1) + i]
			verts.append(Vector3(x0 + i * step, h, z0 + j * step))
			var hl := hs[j * (n + 1) + maxi(i - 1, 0)]
			var hr := hs[j * (n + 1) + mini(i + 1, n)]
			var hd := hs[maxi(j - 1, 0) * (n + 1) + i]
			var hu := hs[mini(j + 1, n) * (n + 1) + i]
			norms.append(Vector3(hl - hr, 2.0 * step, hd - hu).normalized())
			var t := clampf((-h - 2.0) / 14.0, 0.0, 1.0)
			var spot := 0.5 + 0.5 * sin(i * 0.9 + j * 0.4) * sin(j * 0.7 - i * 0.3)
			cols.append(shallow.lerp(deep, t).darkened(0.12 * spot))
	var ind := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			ind.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = ind
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _reset() -> void:
	if swim != null:
		_leave_water(null, true)
	for t in tiles.values():
		t.node.queue_free()
	tiles.clear()
	for o in objs:
		if Farm.is_farm(o.kind):
			farm.forget(o)
	objs.clear()
	if shelter != null:
		shelter.clear()
	for d in debris:
		d.node.queue_free()
	debris.clear()
	if traders != null:
		traders.reset()
	if weather != null:
		weather.reset()
	if companions != null and not companions.pets.is_empty():
		companions.reset()
	_clear_ghosts()
	for k in ITEMS:
		inv[k] = 0
	inv["wood"] = 2
	inv["plastic"] = 1
	S = {"thirst": 75.0, "hunger": 85.0, "health": 100.0, "wood_hooked": 0, "rope_made": 0,
		"still_built": 0, "drank": 0, "fished": 0, "ate_cooked": 0, "repelled": 0, "islands": 0, "bag": 20, "dug": 0, "harvested": 0, "eggs": 0, "bred": 0, "trades": 0, "built_house": 0, "pets": 0}
	skills = {}
	for k in SKILLS:
		skills[k] = {"lv": 0, "xp": 0}
	raft_pos = Vector2.ZERO
	raft_vel = Vector2.ZERO
	heading = ocean.wind
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_add_tile(c)
	P = {"x": 1.0, "z": 1.0, "face": 0.0, "moving": false, "level": 0}
	shark = {"x": 1.0, "z": 16.0, "head": 0.0, "state": "circle", "timer": 80.0, "ang": PI / 2,
		"hp": 3, "bite": 0.0, "target": null, "flash": 0.0, "warned": false, "rip_t": 0.0, "dep": 0.42, "hpitch": 0.0, "hunt_t": 9.0,
		"side": Vector2.RIGHT, "lunge": false, "jaw": 0.0, "pitch": 0.0, "tpeer": ""}
	for isl in islands:
		isl.visited = false
		for n in isl.nodes:
			n.node.visible = true
			if n.kind == "tree":
				n.cd = 0.0
				n.nuts.visible = true
			else:
				n.used = false
	hook = null
	hook_ball.visible = false
	_end_fishing()
	steer = null
	for n in seabed_nodes:
		n.node.visible = true
		if n.kind == "wreck":
			n.used = false
		else:
			n.cd = 0.0
	game_t = 0.0
	over = false
	goals_done = 0
	_set_build("")
	_close_sheet()
	for k in 14:
		_spawn_debris(true)
	_refresh_inv()


## Pick the keyboard or the touch wording for a hint.
func _k(keys: String, touch: String) -> String:
	return touch if hud != null and hud.touch_mode else keys


func _show_start() -> void:
	paused = true
	hud.show_menu("開房間 · 選一個模式（朋友會跟你玩同一個世界）" if _host_after_start else "試玩原型 · Godot 4 版", "瘋狂水世界",
		"你醒來時只有一塊 2×2 的木筏。打撈漂流物、把海水變成淡水、釣魚烤魚、擴建木筏，再揚帆去找小島。小心那隻鯊魚。\n\n"
		+ _k("WASD 移動　拖曳滑鼠轉視角　滾輪縮放　左鍵點擊互動　F 下水 / 上船（Shift 下潛、Space 上浮）\nE 吃東西　Q 喝水　R 收竿　C 合成　B 建造　J 熟練度　F5 存檔　Esc 關閉\n\n",
			"左下搖桿移動　單指拖曳轉視角　兩指縮放　點東西互動\n下水後右邊有上浮 / 下潛鍵　每 30 秒自動存檔\n\n")
		+ "標準：昏倒時背包掉進海裡，10 分鐘內撈回來。　和平：沒有鯊魚，昏倒不掉東西。\n"
		+ "硬派：死了就刪檔，口渴飢餓掉更快，鯊魚更常來。　創造：材料無限、不會餓" + _k("，按 K 開關鯊魚。", "。")
		+ "\n\n模型：Flying Seagull © The lighthouse keeper（CC BY-SA 4.0）· Hawksbill Sea Turtle © DigitalLife3D（CC BY-NC 4.0，重新上色）",
		([["continue", "繼續遊戲", true]] if FileAccess.file_exists(SAVE_PATH) else [])
		+ [["start_standard", "標準", not FileAccess.file_exists(SAVE_PATH)], ["start_peaceful", "和平", false],
			["start_hardcore", "硬派", false], ["start_creative", "創造", false]]
		+ ([["mp_back", "取消開房間", false]] if _host_after_start else [["mp", "跟朋友玩", false]])
		+ ([["fullscreen", "全螢幕", false]] if _screen().get("can", false) and not _screen().get("full", false) else []))
	if _screen().get("ios", false) and not _screen().get("standalone", false) and net.kind() == "peer":
		hud.toast("iPhone 想全螢幕：用 Safari 按「分享」→「加入主畫面」，從主畫面打開")


# ---------------------------------------------------------------- raft & props

func _add_tile(c: Vector2i) -> void:
	var node := Node3D.new()
	node.position = Vector3(c.x * TILE, 0, c.y * TILE)
	raft.add_child(node)
	var mats := Models.raft_tile(node, c.x, c.y)
	var bases := []
	for m in mats:
		bases.append(m.albedo_color)
	tiles[c] = {"cell": c, "node": node, "mats": mats, "bases": bases, "hp": 3, "obj": null, "shake": 0.0}
	_update_mask()


func _remove_tile(t: Dictionary, quiet := false) -> void:
	if t.obj != null:
		if Farm.is_farm(t.obj.kind) and not quiet:
			var pets := farm.animals_on(t.obj)
			for who in pets:
				var tw := Vector2(raft_pos.x + t.cell.x * TILE, raft_pos.y + t.cell.y * TILE)
				_drop_floating({who: pets[who]}, tw.x, tw.y, "掉進海裡的" + ITEMS[who], Models.chicken() if who == "chicken" else Models.goat())
				if hud != null:
					hud.toast("%d 隻%s掉進海裡了！快用鉤子撈或下水救牠們" % [pets[who], ITEMS[who]])
		_remove_obj(t.obj)
	t.node.queue_free()
	tiles.erase(t.cell)
	_update_mask()
	if shelter != null and shelter.settle() > 0 and hud != null:
		hud.toast("木筏少了一格，上面的牆和屋頂也掉進海裡了")
	if shelter != null:
		_after_shelter_change()
	if not _on_raft(P["x"], P["z"]):
		var best = null
		var bd := INF
		for o in tiles.values():
			var dd := Vector2(o.cell.x * TILE - P["x"], o.cell.y * TILE - P["z"]).length()
			if dd < bd:
				bd = dd
				best = o
		if best != null:
			P["x"] = best.cell.x * TILE
			P["z"] = best.cell.y * TILE


func _update_mask() -> void:
	ocean.set_raft_mask(tiles.keys(), raft_pos)


func _tint(t: Dictionary) -> void:
	for i in t.mats.size():
		t.mats[i].albedo_color = (t.bases[i] as Color).lerp(Color("2a1e15"), (3 - t.hp) * 0.24)


func _tile_at(x: float, z: float) -> Variant:
	return tiles.get(Vector2i(roundi(x / TILE), roundi(z / TILE)))


func _on_raft(x: float, z: float) -> bool:
	var m := 0.22
	return _tile_at(x - m, z - m) != null and _tile_at(x + m, z - m) != null \
		and _tile_at(x - m, z + m) != null and _tile_at(x + m, z + m) != null


func _raft_center() -> Dictionary:
	var x := 0.0
	var z := 0.0
	for t in tiles.values():
		x += t.cell.x * TILE
		z += t.cell.y * TILE
	var n := maxi(tiles.size(), 1)
	x /= n
	z /= n
	var r := 0.0
	for t in tiles.values():
		r = maxf(r, Vector2(t.cell.x * TILE - x, t.cell.y * TILE - z).length())
	return {"x": x + raft_pos.x, "z": z + raft_pos.y, "r": r + 1.5}


func _edge_tiles() -> Array:
	var out := []
	for t in tiles.values():
		var n := 0
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if tiles.has(t.cell + o):
				n += 1
		if n < 4:
			out.append(t)
	return out


func _connected_without(skip: Dictionary) -> bool:
	var rest := []
	for t in tiles.values():
		if t != skip:
			rest.append(t)
	if rest.is_empty():
		return false
	var seen := {rest[0].cell: true}
	var stack := [rest[0]]
	while not stack.is_empty():
		var t = stack.pop_back()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = t.cell + o
			if tiles.has(c) and tiles[c] != skip and not seen.has(c):
				seen[c] = true
				stack.append(tiles[c])
	return seen.size() == rest.size()


func _objs_of(kind: String) -> Array:
	return objs.filter(func(o): return o.kind == kind)


func _place(kind: String, t: Dictionary) -> void:
	var m: Dictionary
	match kind:
		"still":
			m = Models.still()
		"grill":
			m = Models.grill()
		"sail":
			m = Models.sail()
		"chest":
			m = Models.chest()
		"filter":
			m = Models.filter()
		"field":
			m = Models.field_tile()
		"kelpfarm":
			m = Models.kelp_tile()
		"coop":
			m = Models.coop_tile()
		"pen":
			m = Models.pen_tile()
		"stairs":
			m = Models.stairs()
		"catcher":
			m = Models.rain_catcher()
		"gullnest":
			m = Models.gull_nest()
		"dolphinpost":
			m = Models.dolphin_post()
		"turtletank":
			m = Models.turtle_tank()
		_:
			m = Models.helm()
	var node: Node3D = m.node
	node.position = Vector3(t.cell.x * TILE, 0.07, t.cell.y * TILE)
	raft.add_child(node)
	var o := m.duplicate()
	o["kind"] = kind
	o["tile"] = t
	match kind:
		"still":
			o["fuel"] = 0.0
			o["water"] = 0
			o["prog"] = 0.0
			o["label"] = _label3d(node)
		"filter", "catcher":
			o["water"] = 0
			o["prog"] = 0.0
			o["label"] = _label3d(node)
		"grill":
			o["slots"] = []
			o["done"] = {}
			o["label"] = _label3d(node)
		"sail":
			o["up"] = false
	t.obj = o
	objs.append(o)
	if Farm.is_farm(kind):
		farm.setup(o)


func _label3d(parent: Node3D) -> Label3D:
	var label := Label3D.new()
	label.font = _font
	label.font_size = 44
	label.pixel_size = 0.004
	label.outline_size = 12
	label.outline_modulate = Color(0.03, 0.1, 0.13, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 1.35
	parent.add_child(label)
	return label


func _remove_obj(o: Dictionary) -> void:
	if steer == o:
		_exit_steer()
	if Farm.is_farm(o.kind):
		farm.forget(o)
	o.node.queue_free()
	o.tile.obj = null
	objs.erase(o)


# ---------------------------------------------------------------- debris & hook

func _flow() -> Vector2:
	return CURRENT - raft_vel


func _spawn_debris(initial: bool) -> void:
	var total := 0
	for k in DEBRIS:
		total += DEBRIS[k].w
	var r := randf() * total
	var type := "plank"
	for k in DEBRIS:
		r -= DEBRIS[k].w
		if r < 0.0:
			type = k
			break
	var c := _raft_center()
	var dir := _flow()
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(0, 1)
	var side := randf_range(-24.0, 24.0)
	var along := randf_range(-50.0, 22.0) if initial else -52.0
	var node := Models.cage() if type == "cage" else Models.debris(type)
	node.rotation.y = randf() * TAU
	add_child(node)
	debris.append({"node": node, "type": type, "x": c.x + dir.x * along - dir.y * side,
		"z": c.z + dir.y * along + dir.x * side, "seed": randf() * 10.0, "spin": randf_range(-0.3, 0.3), "state": "drift"})


func _remove_debris(d: Dictionary) -> void:
	if is_client() and d.has("nid") and not d.get("claim_sent", false):
		net.event({"a": "claim", "id": d.nid})
	d.node.queue_free()
	debris.erase(d)


func _collect(d: Dictionary) -> void:
	var give: Dictionary = d.give if d.type == "bag" else DEBRIS[d.type].give
	if d.type != "bag" and not _fits(give):
		_full_toast()
		d.state = "drift"
		return
	if d.type == "bag":
		hud.toast("撈回%s：" % d.get("what", "背包") + _give(give))
		sfx.play("catch")
		_remove_debris(d)
		_refresh_inv()
		return
	_gain("hook", 1)
	hud.toast("+ " + _give(give))
	sfx.play("pickup")
	if give.has("wood"):
		S["wood_hooked"] += give["wood"]
	_remove_debris(d)
	_refresh_inv()


func _slots_used(extra := {}) -> int:
	var n := 0
	for k in STACK:
		var c: int = inv[k] + int(extra.get(k, 0))
		if c > 0:
			n += ceili(float(c) / STACK[k])
	return n


func _capacity() -> int:
	return int(S["bag"]) + 12 * _objs_of("chest").size()


func _fits(items: Dictionary) -> bool:
	return creative or _slots_used(items) <= _capacity()


func _full_toast() -> void:
	hud.toast("背包滿了（%d / %d 格）：蓋儲物箱或做更大的背包" % [_slots_used(), _capacity()])


func _give(items: Dictionary) -> String:
	var parts := []
	for k in items:
		inv[k] += items[k]
		parts.append("%s×%d" % [ITEMS[k], items[k]])
	return "、".join(parts)


# ---------------------------------------------------------------- fishing

func _try_cast(o: Vector3, d: Vector3, pw: Vector3) -> void:
	if build_mode != "" or inv["rod"] < 1 or steer != null:
		return
	if fishing != null:
		hud.toast("浮標已經在水裡了，等魚上鉤或" + _k("按 R 收竿", "按收竿"))
		return
	if hook != null or absf(d.y) < 0.0001:
		return
	var tt := (-0.25 - o.y) / d.y
	if tt <= 0.0:
		return
	var pt := o + d * tt
	if _tile_at(pt.x - raft_pos.x, pt.z - raft_pos.y) != null:
		return
	if _flat(pw, pt.x, pt.z) > FISH_RANGE:
		hud.toast("拋不到那麼遠（釣竿範圍 %d 公尺）" % int(FISH_RANGE))
		return
	fishing = {"x": pt.x, "z": pt.z, "phase": "cast", "t": 0.0, "wait": _bite_wait(), "bite": 0.0}
	if inv["bait"] > 0:
		inv["bait"] -= 1
		fishing.wait *= 0.5
		hud.toast("掛上魚餌，魚很快就會上鉤（剩 %d 個）" % inv["bait"])
		_refresh_inv()
	sfx.play("whoosh", null, -3.0)
	bobber.visible = true
	P["face"] = atan2(pt.x - pw.x, pt.z - pw.z)
	_update_reel()


func _reel() -> void:
	if fishing == null or paused:
		return
	if fishing.phase == "bite":
		var n := 2 if randf() < 0.15 + 0.015 * _lv("fish") else 1
		if not _fits({"rawfish": n}):
			_full_toast()
			_end_fishing()
			return
		_gain("fish", 3)
		inv["rawfish"] += n
		S["fished"] += 1
		hud.toast("釣到一條大魚！生魚 ×2" if n == 2 else "釣到一條魚！生魚 ×1")
		sfx.play("catch")
		ocean.ripple(fishing.x, fishing.z, 0.8)
		_end_fishing()
		_refresh_inv()
	else:
		hud.toast("收線了")
		sfx.play("reel")
		_end_fishing()


func _end_fishing() -> void:
	fishing = null
	bobber.visible = false
	_update_reel()


func _update_reel() -> void:
	if hud == null:
		return
	var b: Button = hud.btn["reel"]
	b.visible = fishing != null
	if fishing != null:
		b.text = "上鉤了！收竿 (R)" if fishing.phase == "bite" else "收竿 (R)"


# ---------------------------------------------------------------- inventory, goals, UI

func _refill() -> void:
	if not creative:
		return
	for k in ["wood", "plastic", "palm", "rope", "coconut", "rawfish", "cooked", "cup", "sand", "clay", "ore", "kelp",
			"seed_potato", "seed_tomato", "seed_melon"]:
		inv[k] = 99
	inv["goggles"] = 1
	inv["water"] = maxi(inv["water"], 20)
	inv["spear"] = 1
	inv["rod"] = 1


func _has(cost: Dictionary) -> bool:
	if creative:
		return true
	for k in cost:
		if inv[k] < cost[k]:
			return false
	return true


func _pay(cost: Dictionary) -> void:
	if creative:
		return
	for k in cost:
		inv[k] -= cost[k]


func _lv(k: String) -> int:
	return int(skills[k].lv)


func _xp_need(lv: int) -> int:
	return 6 + lv * 6


func _gain(k: String, xp: int) -> void:
	var sk: Dictionary = skills[k]
	if sk.lv >= 10:
		return
	sk.xp += xp
	if sk.xp >= _xp_need(sk.lv):
		sk.xp -= _xp_need(sk.lv)
		sk.lv += 1
		hud.toast("%s熟練度升到 %d 級！" % [SKILLS[k][0], sk.lv])
		sfx.play("catch", null, -6.0, 0.0)


func _hook_range() -> float:
	return HOOK_RANGE + 0.5 * _lv("hook")


func _bite_wait() -> float:
	return randf_range(4.0, 9.0) * (1.0 - 0.04 * _lv("fish")) * (0.7 if inv["rod2"] > 0 else 1.0)


func _cook_k() -> float:
	return 1.0 + 0.03 * _lv("cook")


func _build_cost(cost: Dictionary) -> Dictionary:
	var k := 1.0 - 0.02 * mini(_lv("build"), 10)
	var out := {}
	for item in cost:
		out[item] = maxi(1, roundi(cost[item] * k))
	return out


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%s×%d" % [ITEMS[k], cost[k]])
	return "、".join(parts)


func _next_food() -> String:
	for k in ["cooked", "fegg", "coconut", "bpotato", "rawfish", "potato", "tomato"]:
		if inv[k] > 0:
			return k
	return ""


func _next_drink() -> String:
	for k in ["water", "mjuice", "milk", "tjuice"]:
		if inv[k] > 0:
			return k
	return ""


func _refresh_inv() -> void:
	_refill()
	var parts := []
	for k in ORDER:
		if not k in ["wood", "plastic", "palm", "rope", "coconut", "cup", "water"] and inv[k] == 0:
			continue
		if creative and inv[k] >= 99:
			continue
		var v: String = ("%d/%d" % [inv["water"], inv["cup"]]) if k == "water" else str(inv[k])
		parts.append("%s\u00a0%s" % [ITEMS[k], v])
	var head := ("背包\u00a0%d/%d\u00a0格" % [_slots_used(), _capacity()]) if not creative else "創造模式：基本材料無限"
	hud.inv_label.text = "   ".join([head] + parts)
	hud.btn["skills"].text = "夥伴" if companions.any_tamed() else "熟練度"
	var dr := _next_drink()
	hud.btn["drink"].text = ("喝%s (%d)" % [ITEMS[dr], inv[dr]]) if dr != "" else "喝水 (0)"
	hud.btn["drink"].disabled = dr == ""
	var food := _next_food()
	hud.btn["eat"].text = ("吃%s (%d)" % [ITEMS[food], inv[food]]) if food != "" else "沒有食物"
	hud.btn["eat"].disabled = food == ""
	_update_reel()
	if sheet_mode != "":
		_open_sheet(sheet_mode)
	_refresh_goals()


func _goals() -> Array:
	var has_rig := not _objs_of("sail").is_empty() and not _objs_of("helm").is_empty()
	return [
		["用鉤子撿到 6 塊木板", "已撿 %d / 6" % mini(S["wood_hooked"], 6), S["wood_hooked"] >= 6],
		["用棕櫚葉做出繩子", "合成 → 繩子（棕櫚葉 ×2）", S["rope_made"] >= 1],
		["蓋一座塑膠蒸餾杯", "建造 → 塑膠蒸餾杯", S["still_built"] >= 1],
		["喝下第一杯淡水", "添柴、等水蒸好，用塑膠杯裝起來喝", S["drank"] >= 1],
		["做釣竿，釣到一條魚", "合成 → 釣竿，再點木筏旁的海面拋竿", S["fished"] >= 1],
		["蓋烤架，吃下一條烤魚", "建造 → 簡易烤架，放生魚烤 15 秒", S["ate_cooked"] >= 1],
		["把木筏擴建到 8 格", "目前 %d / 8 格" % tiles.size(), tiles.size() >= 8],
		["做把木矛，擊退一次鯊魚", "鯊魚來咬木筏時，靠近點牠", S["repelled"] >= 1],
		["做潛水鏡，潛到海底挖到資源", _k("合成 → 潛水鏡，按 F 下水、Shift 下潛", "合成 → 潛水鏡，按下水、按住下潛"), S["dug"] >= 1],
		["種下種子並收成一次", "建造 → 菜田（要黏土），一格一格鋪，種下種子、澆淡水", S["harvested"] >= 1],
		["蓋一間有屋頂的小屋", "建造 → 牆、門、屋頂：讓 2 格以上的地板有東西遮著", S["built_house"] >= 1],
		["收服一隻海洋夥伴", "第一座小島上空有海鷗：開船過去，餵牠 3 次生魚", S["pets"] >= 1],
		["跟商船做一次交易", "商船會不定時靠過來，點它用貝殼幣買賣（貝殼幣：賣東西、潛水挖、開木箱）", S["trades"] >= 1],
		["養雞撿到第一顆蛋", "用鉤子撈漂來的雞籠，蓋雞舍、餵海帶", S["eggs"] >= 1],
		["揚帆航行到第一座小島", "升帆、掌舵，跟著左上角的箭頭走" if has_rig else "建造 → 船帆和船舵", S["islands"] >= 1],
	]


func _refresh_goals() -> void:
	var g := _goals()
	var done := 0
	var cur = null
	for x in g:
		if x[2]:
			done += 1
		elif cur == null:
			cur = x
	if done > goals_done and not paused:
		var last_done := ""
		for x in g:
			if x[2]:
				last_done = x[0]
		hud.toast("目標完成：" + last_done)
	goals_done = done
	if cur == null:
		hud.goal_eyebrow.text = "目標全部完成"
		hud.goal_now.text = "核心循環完成，繼續撐下去吧"
		hud.goal_sub.text = "已存活 %d 天" % (int(game_t / DAY_LEN) + 1)
	else:
		hud.goal_eyebrow.text = "目標 %d / %d" % [done + 1, g.size()]
		hud.goal_now.text = cur[0]
		hud.goal_sub.text = cur[1]


func _open_sheet(mode: String) -> void:
	sheet_mode = mode
	var rows := []
	if mode == "craft":
		for r in CRAFT:
			var owned: bool = (r.get("once", false) and inv[r.id] > 0) or (r.has("bag") and int(S["bag"]) >= r.bag)
			var locked: bool = r.get("bag", 0) == 40 and (S["islands"] < 2 or int(S["bag"]) < 30)
			rows.append({"id": r.id, "name": r.name, "desc": r.desc, "cost_text": _cost_text(r.cost),
				"ok": _has(r.cost) and not owned and not locked, "label": "已擁有" if owned else ("未解鎖" if locked else "合成")})
		hud.show_sheet("合成", rows)
	elif mode == "trade":
		if traders.boat == null:
			return
		hud.show_sheet(traders.title(), traders.sheet())
	elif mode == "plant":
		for crop in CROPS:
			var seed: String = CROPS[crop][0]
			rows.append({"id": crop, "name": CROP_NAME[crop], "desc": "%d 秒成熟，收成 %s ×%d" % [int(CROPS[crop][1]), ITEMS[CROPS[crop][2]], CROPS[crop][3]],
				"cost_text": "%s %d 顆" % [ITEMS[seed], inv[seed]], "ok": inv[seed] > 0 or creative, "label": "種"})
		hud.show_sheet("種什麼？（種滿這片菜田的空位）", rows)
	elif mode == "skills":
		for k in SKILLS:
			var sk: Dictionary = skills[k]
			var prog := "已滿級" if sk.lv >= 10 else "經驗 %d / %d" % [sk.xp, _xp_need(sk.lv)]
			rows.append({"id": k, "name": "%s　Lv %d" % [SKILLS[k][0], sk.lv], "desc": "%s。練法：%s。" % [SKILLS[k][2], SKILLS[k][1]],
				"cost_text": prog, "ok": false, "label": "", "cost_color": Color("ff9f1c")})
		if companions.any_tamed():
			rows = companions.sheet_rows() + rows
		hud.show_sheet("夥伴與熟練度" if companions.any_tamed() else "熟練度", rows)
	elif mode == "room":
		rows.append({"id": "", "name": "你（%s）" % net.nick + ("・房主" if net.is_host() else ""), "desc": "房號 %s" % net.code, "cost_text": "", "ok": false, "label": ""})
		for k in net.peers:
			var pp: Dictionary = net.peers[k]
			var ppl = pp.p.get("pl", [0])
			var wet: bool = typeof(ppl) == TYPE_ARRAY and not ppl.is_empty() and int(ppl[0]) == 1
			rows.append({"id": "", "name": pp.name + ("（房主）" if k == net.host_peer else ""), "desc": "在水裡" if wet else "在木筏上",
				"cost_text": "", "ok": false, "label": ""})
		rows.append({"id": "leave_room", "name": "離開房間", "desc": "房主離開時房間會關掉，大家回到開始畫面（房主的存檔還在）" if net.is_host() else "回到開始畫面，你這次的背包不會留下", "cost_text": "", "ok": true, "label": "離開"})
		hud.show_sheet("房間 %s · %d 人" % [net.code, net.player_count()], rows)
	elif mode == "pets":
		rows = companions.sheet_rows()
		if rows.is_empty():
			rows.append({"id": "", "name": "還沒有夥伴", "desc": "第一座小島上空的海鷗、第二座小島外的海豚、沉船旁被漁網纏住的海龜，都可以收服", "cost_text": "", "ok": false, "label": ""})
		hud.show_sheet("海洋夥伴", rows)
	else:
		for r in BUILD:
			var cost := _build_cost(r.cost)
			rows.append({"id": r.id, "name": r.name, "desc": r.desc, "cost_text": _cost_text(cost),
				"ok": _has(cost), "label": "放置"})
		rows.append({"id": "demolish", "name": "拆除", "desc": "拆掉設備或地板，退回一半材料", "cost_text": "", "ok": true, "label": "拆除"})
		hud.show_sheet("建造", rows)


func _close_sheet() -> void:
	sheet_mode = ""
	hud.sheet.visible = false


func _on_action(id: String) -> void:
	match id:
		"start_survival", "start_standard", "start_peaceful", "start_hardcore", "start_creative":
			mode = "standard" if id == "start_survival" else id.trim_prefix("start_")
			creative = mode == "creative"
			shark_on = mode in ["standard", "hardcore"]
			_reset()
			hud.hide_menu()
			paused = false
			if creative:
				hud.toast(_k("創造模式：按 K 開關鯊魚", "創造模式：鯊魚關著"))
			_start_hosting()
		"continue":
			_reset()
			if _load_game():
				hud.hide_menu()
				paused = false
				hud.toast("讀取存檔：第 %d 天" % (int((game_t + DAY_LEN * 0.09) / DAY_LEN) + 1))
				_start_hosting()
			else:
				hud.toast("存檔讀取失敗，請開新遊戲")
		"mp":
			_show_mp_menu()
		"mp_host":
			_mp_menu = false
			_host_after_start = true
			_show_start()
		"mp_back":
			_mp_menu = false
			_host_after_start = false
			_show_start()
		"mp_cancel":
			net.leave()
			_show_mp_menu()
		"mp_code":
			_code_entry = ""
			_show_code_menu()
		"code_del":
			_code_entry = _code_entry.substr(0, maxi(0, _code_entry.length() - 1))
			_show_code_menu()
		"code_go":
			if _code_entry.length() == 4:
				_mp_menu = false
				net.join(_code_entry)
				hud.show_menu("跟朋友玩", "連線中…", "正在連到房號 %s 的房間，等幾秒鐘。" % _code_entry, [["mp_cancel", "取消", false]])
		"fs", "fullscreen":
			if OS.has_feature("web"):
				JavaScriptBridge.eval("MWNet.fullscreen()", true)
		"room":
			if sheet_mode == "room":
				_close_sheet()
			else:
				_set_build("")
				_open_sheet("room")
		"retry":
			_reset()
			hud.hide_menu()
			paused = false
		"eat":
			_eat()
		"drink":
			_drink()
		"reel":
			_reel()
		"swim":
			_toggle_swim()
		"skills":
			if sheet_mode == "skills":
				_close_sheet()
			else:
				_set_build("")
				_open_sheet("skills")
		"craft":
			if sheet_mode == "craft":
				_close_sheet()
			else:
				_set_build("")
				_open_sheet("craft")
		"build":
			if sheet_mode == "build":
				_close_sheet()
			else:
				_set_build("")
				_open_sheet("build")
		"build_done":
			_set_build("")
		"steer_done":
			_exit_steer()
		_:
			if id.begins_with("code_") and id.length() == 6:
				if _code_entry.length() < 4:
					_code_entry += id.substr(5)
				_show_code_menu()
			elif id.begins_with("mp_join_"):
				_mp_menu = false
				net.join(id.substr(8))
				hud.show_menu("跟朋友玩", "連線中…", "正在跟房主拿世界的資料，等幾秒鐘。", [["mp_cancel", "取消", false]])


func _on_recipe(id: String) -> void:
	if sheet_mode == "room":
		if id == "leave_room":
			_leave_room()
		return
	if id.begins_with("pet_"):
		companions.sheet_action(id)
		_open_sheet(sheet_mode)
		return
	if sheet_mode == "skills":
		return
	if sheet_mode == "trade":
		traders.trade(id)
		return
	if sheet_mode == "plant":
		if has_meta("planting"):
			farm.plant(get_meta("planting"), id)
		return
	if sheet_mode == "craft":
		for r in CRAFT:
			if r.id == id and _has(r.cost):
				_pay(r.cost)
				for k in r.give:
					inv[k] += r.give[k]
				if r.has("bag"):
					S["bag"] = r.bag
				if id == "rope":
					S["rope_made"] += 1
				hud.toast("做好了：" + r.name)
				sfx.play("craft")
				_refresh_inv()
	else:
		_close_sheet()
		_set_build(id)


func _eat() -> void:
	var food := _next_food()
	if food == "" or paused:
		return
	sfx.play("eat")
	_gain("cook", 1)
	inv[food] -= 1
	var fv: Array = FOOD[food]
	var h := roundi(fv[0] * _cook_k())
	S["hunger"] = minf(100.0, S["hunger"] + h)
	S["thirst"] = minf(100.0, S["thirst"] + fv[1])
	if food == "cooked":
		S["ate_cooked"] += 1
	if food == "rawfish" and randf() < 0.35:
		S["thirst"] = maxf(0.0, S["thirst"] - 15.0)
		hud.toast("生魚吃壞肚子了：飢餓 +%d、口渴 -15" % h)
	else:
		hud.toast("%s：飢餓 +%d%s" % [ITEMS[food], h, ("、口渴 +%d" % fv[1]) if fv[1] > 0 else ""] + ("（烤過會更好）" if food in ["rawfish", "potato"] else ""))
	_refresh_inv()


func _drink(kind := "") -> void:
	var d := kind if kind != "" else _next_drink()
	if d == "" or inv[d] < 1 or paused:
		return
	inv[d] -= 1
	var dv: Array = DRINK[d]
	S["thirst"] = minf(100.0, S["thirst"] + dv[0])
	S["hunger"] = minf(100.0, S["hunger"] + dv[1])
	if d == "water":
		S["drank"] += 1
	sfx.play("drink")
	hud.toast("咕嚕，%s：口渴 +%d%s" % [ITEMS[d], dv[0], ("、飢餓 +%d" % dv[1]) if dv[1] > 0 else ""])
	_refresh_inv()


# ---------------------------------------------------------------- build mode

func _build_def(id: String) -> Dictionary:
	for r in BUILD:
		if r.id == id:
			return r
	return {}


func _set_build(mode: String) -> void:
	build_mode = mode
	_refresh_ghosts()
	if mode == "":
		hud.show_build_bar("")
	elif mode == "floor":
		hud.show_build_bar("點橘色格子蓋地板（%s）" % _cost_text(BUILD[0].cost))
	elif mode == "demolish":
		hud.show_build_bar("點紅色的設備或地板拆除，退回一半材料")
	else:
		var r := _build_def(mode)
		if Shelter.is_mode(mode):
			hud.show_build_bar("點白色的位置蓋%s（每個 %s）%s" % [r.name, _cost_text(r.cost),
				"，現在蓋在二樓" if int(P["level"]) == 1 else ""])
		elif Farm.is_farm(mode):
			hud.show_build_bar("點空地板一格一格鋪%s（每格 %s），相鄰的會連成一片" % [OBJ_NAME[mode], _cost_text(r.cost)])
		else:
			hud.show_build_bar("點一格空地板放%s（%s）" % [r.name, _cost_text(r.cost)])


func _clear_ghosts() -> void:
	if shelter != null:
		shelter.clear_ghosts()
	for g in ghosts:
		g.node.queue_free()
	ghosts.clear()


func _add_ghost(c: Vector2i, mat: Material, tall: bool) -> void:
	var node := Models.part(raft, Models.box(1.5, 1.6, 1.5) if tall else Models.box(1.9, 0.1, 1.9), mat,
		Vector3(c.x * TILE, 0.85 if tall else 0.12, c.y * TILE))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghosts.append({"node": node, "cell": c})


func _refresh_ghosts() -> void:
	_clear_ghosts()
	if build_mode == "floor":
		var seen := {}
		for t in tiles.values():
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c: Vector2i = t.cell + o
				if not tiles.has(c) and not seen.has(c):
					seen[c] = true
					_add_ghost(c, _ghost_mat, false)
	elif build_mode == "demolish":
		for t in tiles.values():
			if t.obj != null:
				_add_ghost(t.cell, _demo_mat, true)
			elif tiles.size() > 1:
				_add_ghost(t.cell, _demo_mat, false)
	elif Shelter.is_mode(build_mode):
		shelter.show_ghosts(build_mode, P["level"], _ghost_mat)
	elif build_mode == "stairs":
		for t in tiles.values():
			if t.obj == null and _stairs_dir(t.cell) != Vector2i.ZERO:
				_add_ghost(t.cell, _ghost_mat, false)
	elif build_mode != "":
		for t in tiles.values():
			if t.obj == null:
				_add_ghost(t.cell, _ghost_mat, false)


func _refund_half(cost: Dictionary) -> String:
	var back := {}
	for k in cost:
		back[k] = ceili(cost[k] / 2.0)
	return _give(back)


func _tap_ghost(c: Vector2i) -> void:
	if build_mode == "demolish":
		var t: Dictionary = tiles[c]
		if t.obj != null:
			var kind: String = t.obj.kind
			var pets: Dictionary = farm.animals_on(t.obj) if Farm.is_farm(kind) else {}
			if not _fits(pets):
				hud.toast("背包放不下這格的動物，先清出空間")
				return
			var back := ""
			if not pets.is_empty():
				back = "，動物收回背包：" + _give(pets)
			_remove_obj(t.obj)
			hud.toast("拆掉%s，退回 %s%s" % [OBJ_NAME[kind], _refund_half(_build_def(kind).cost), back])
			sfx.play("build")
		else:
			if not _connected_without(t):
				hud.toast("拆掉這格會讓木筏斷成兩半")
				return
			_remove_tile(t)
			hud.toast("拆掉 1 格地板，退回 " + _refund_half(BUILD[0].cost))
			sfx.play("build")
		_refresh_ghosts()
		_refresh_inv()
		return
	var r := _build_def(build_mode)
	var cost := _build_cost(r.cost)
	if not _has(cost):
		hud.toast("材料不足：需要 " + _cost_text(cost))
		return
	if build_mode == "stairs" and _stairs_dir(c) == Vector2i.ZERO:
		hud.toast("樓梯要放在二樓地板旁邊，而且上面不能有二樓地板")
		return
	_pay(cost)
	_gain("build", 2)
	sfx.play("build")
	if build_mode == "floor":
		_add_tile(c)
		hud.toast("蓋好 1 格地板")
		_refresh_ghosts()
	else:
		_place(build_mode, tiles[c])
		match build_mode:
			"still":
				S["still_built"] += 1
				hud.toast("蒸餾杯蓋好了，點它添柴火")
			"grill":
				hud.toast("烤架蓋好了，點它放生魚")
			"sail":
				hud.toast("船帆裝好了，點它升帆")
			"helm":
				hud.toast("船舵裝好了，站過去點它掌舵")
			"chest":
				hud.toast("儲物箱放好了，背包容量 +12 格")
			"gullnest", "dolphinpost", "turtletank":
				hud.toast("%s蓋好了，點它管理夥伴" % OBJ_NAME[build_mode])
			"catcher":
				hud.toast("集雨布放好了，下雨時會接雨水（上面不能有屋頂）")
			"filter":
				hud.toast("陶瓷濾水缸放好了，每 30 秒濾出 1 杯淡水")
		if build_mode == "stairs":
			_aim_stairs(tiles[c].obj)
			hud.toast("樓梯蓋好了，點它上樓")
		if Farm.is_farm(build_mode):
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb = tiles.get(c + d)
				if nb != null and nb.obj != null and nb.obj.kind == build_mode:
					n += 1
			hud.toast("%s +1 格%s，繼續點空地板擴大，按完成結束" % [OBJ_NAME[build_mode], "，跟旁邊的連成一片" if n > 0 else ""])
			_refresh_ghosts()
		else:
			_set_build("")
	_refresh_inv()


# ---------------------------------------------------------------- input & picking

func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and e.device == InputEvent.DEVICE_ID_EMULATION:
		return   # fingers are handled as touches below, not as a fake mouse
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_touch_input(e)
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_drag = {"start": mb.position, "moved": 0.0, "t": Time.get_ticks_msec(), "btn": mb.button_index}
			else:
				if not _drag.is_empty() and _drag.moved < 8.0 and _drag.btn == MOUSE_BUTTON_LEFT \
						and Time.get_ticks_msec() - _drag.t < 500:
					_tap(mb.position)
				_drag = {}
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(5.0, cam_dist - 0.8)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(20.0, cam_dist + 0.8)
	elif e is InputEventMouseMotion and not _drag.is_empty():
		var mm := e as InputEventMouseMotion
		_drag.moved = maxf(_drag.moved, (mm.position - _drag.start).length())
		if _drag.moved > 6.0:
			cam_yaw -= mm.relative.x * 0.006
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.005, 0.12, 1.25)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_E:
				_eat()
			KEY_Q:
				_drink()
			KEY_R:
				_reel()
			KEY_C:
				_on_action("craft")
			KEY_J:
				_on_action("skills")
			KEY_F:
				_toggle_swim()
			KEY_B:
				_on_action("build")
			KEY_ESCAPE:
				_close_sheet()
				_set_build("")
				_exit_steer()
			KEY_F5:
				if not paused and not over:
					_save_game()
					hud.toast("已存檔")
			KEY_K:
				if creative:
					shark_on = not shark_on
					hud.toast("鯊魚：" + ("開" if shark_on else "關"))


## One finger: drag to look around, quick tap to act. Two fingers: pinch to zoom.
func _touch_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			if (hud.touch != null and hud.touch.claimed.has(st.index)) or hud.over_ui(st.position):
				return
			_touches[st.index] = {"start": st.position, "pos": st.position, "t": Time.get_ticks_msec(), "moved": 0.0, "multi": _touches.size() > 0}
			if _touches.size() > 1:
				for k in _touches:
					_touches[k].multi = true
			_pinch = 0.0
		elif _touches.has(st.index):
			var t: Dictionary = _touches[st.index]
			_touches.erase(st.index)
			if not t.multi and t.moved < 14.0 and Time.get_ticks_msec() - t.t < 450:
				_tap(st.position)
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		var t: Dictionary = _touches[sd.index]
		# Measure the move from this finger's own last position. The web build's `relative` is
		# computed against whichever finger came first in the browser event, so with the stick
		# held it can be the distance between two fingers and the view jumps.
		var delta: Vector2 = sd.position - t.pos
		t.pos = sd.position
		if delta.length() > 90.0:
			delta = Vector2.ZERO   # a glitch, not a real swipe within one frame
		t.moved = maxf(t.moved, (sd.position - t.start).length())
		if _touches.size() == 1:
			if t.moved > 10.0:
				cam_yaw -= delta.x * 0.008
				cam_pitch = clampf(cam_pitch + delta.y * 0.0065, 0.12, 1.25)
		else:
			var ks := _touches.keys()
			var d: float = (_touches[ks[0]].pos as Vector2).distance_to(_touches[ks[1]].pos)
			if _pinch > 0.0:
				cam_dist = clampf(cam_dist * _pinch / maxf(d, 1.0), 5.0, 20.0)
			_pinch = d


func _pick(screen: Vector2) -> Dictionary:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if Shelter.is_mode(build_mode):
		var k := shelter.pick_ghost(o, d)
		return {"kind": "shelter_ghost", "ref": k} if k != "" else {"kind": "none"}
	if build_mode == "demolish":
		var piece := shelter.pick_piece(o, d)
		if not piece.is_empty():
			return {"kind": "shelter_piece", "ref": piece}
	if build_mode != "" and absf(d.y) > 0.0001:
		var tt := (raft.global_position.y + 0.1 - o.y) / d.y
		if tt > 0.0:
			var hp := raft.to_local(o + d * tt)
			var cell := Vector2i(roundi(hp.x / TILE), roundi(hp.z / TILE))
			for g in ghosts:
				if g.cell == cell:
					return {"kind": "ghost", "ref": cell}
	var cands := []
	if shark_rig.visible:
		cands.append(["shark", null, shark_rig.global_position + Vector3(0, 0.3, 0), 1.7])
	if swim != null:
		for n in seabed_nodes:
			if n.node.visible:
				cands.append(["seabed", n, n.pos + Vector3(0, 0.3, 0), 1.0])
		for dd in debris:
			if dd.state != "hooked":
				cands.append(["debris", dd, (dd.node as Node3D).global_position, 1.0])
		cands += companions.pick_cands(true)
		return _nearest_hit(cands, o, d)
	cands += companions.pick_cands(false)
	if traders.boat != null:
		cands.append(["trader", traders.boat, (traders.boat.node as Node3D).global_position + Vector3(0, 1.0, 0), 2.6])
	for ob in objs:
		var base: Vector3 = (ob.node as Node3D).global_position
		match ob.kind:
			"sail":
				cands.append(["sail", ob, base + Vector3(0, 1.6, 0), 1.1])
			"helm":
				cands.append(["helm", ob, base + Vector3(0, 0.8, 0), 0.8])
			_:
				cands.append([ob.kind, ob, base + Vector3(0, 0.5, 0), 0.85])
	for isl in islands:
		for n in isl.nodes:
			if n.node.visible:
				cands.append(["island", n, (n.node as Node3D).to_global(n.hit), 1.6 if n.kind == "tree" else 0.9])
	for dd in debris:
		if dd.state == "drift" or (dd.type == "bag" and dd.state != "hooked"):
			cands.append(["debris", dd, (dd.node as Node3D).global_position, 0.95])
	var hit := _nearest_hit(cands, o, d)
	if hit.kind == "none":
		hit = {"kind": "water", "o": o, "d": d}
	return hit


func _nearest_hit(cands: Array, o: Vector3, d: Vector3) -> Dictionary:
	var best := {}
	var best_t := INF
	for c in cands:
		var cp: Vector3 = c[2]
		var tt := (cp - o).dot(d)
		if tt <= 0.0:
			continue
		var miss := (o + d * tt - cp).length()
		if miss < c[3] and tt < best_t:
			best_t = tt
			best = {"kind": c[0], "ref": c[1]}
	if best.is_empty():
		best = {"kind": "none"}
	return best


func _tap(pos: Vector2) -> void:
	if paused or over:
		return
	var hit := _pick(pos)
	var pw: Vector3 = swim.pos if swim != null else player.global_position
	if swim != null:
		match hit.kind:
			"seabed":
				_tap_seabed(hit.ref, pw)
			"shark":
				_tap_shark(pw)
			"debris":
				_grab_debris(hit.ref, pw)
			"companion":
				companions.tap(hit.ref, pw)
		return
	if build_mode == "demolish" and hit.kind in ["still", "grill", "sail", "helm", "chest", "filter", "catcher", "field", "kelpfarm", "coop", "pen", "stairs", "gullnest", "dolphinpost", "turtletank"]:
		_tap_ghost(hit.ref.tile.cell)
		return
	match hit.kind:
		"ghost":
			_tap_ghost(hit.ref)
		"still":
			_tap_still(hit.ref, pw)
		"grill":
			_tap_grill(hit.ref, pw)
		"filter", "catcher":
			_tap_filter(hit.ref, pw)
		"field", "kelpfarm", "coop", "pen":
			farm.tap(hit.ref, pw)
		"trader":
			traders.tap(pw)
		"companion":
			companions.tap(hit.ref, pw)
		"gullnest", "dolphinpost", "turtletank":
			_open_sheet("pets")
		"shelter_ghost":
			_place_shelter(hit.ref)
		"shelter_piece":
			_demolish_shelter(hit.ref)
		"stairs":
			_tap_stairs(hit.ref, pw)
		"sail":
			_tap_sail(hit.ref, pw)
		"helm":
			_tap_helm(hit.ref, pw)
		"island":
			_tap_island(hit.ref, pw)
		"shark":
			_tap_shark(pw)
		"debris":
			_tap_debris(hit.ref, pw)
		"water":
			_try_cast(hit.o, hit.d, pw)


func _flat(a: Vector3, x: float, z: float) -> float:
	return Vector2(a.x - x, a.z - z).length()


func _near(o: Dictionary, pw: Vector3, what: String) -> bool:
	var w: Vector3 = (o.node as Node3D).global_position
	if _flat(pw, w.x, w.z) > REACH:
		hud.toast("走近一點才能" + what)
		return false
	return true


func _tap_still(s: Dictionary, pw: Vector3) -> void:
	if not _near(s, pw, "操作蒸餾杯"):
		return
	if s.water > 0:
		if inv["cup"] < 1:
			hud.toast("需要塑膠杯才能裝水（合成 → 塑膠杯）")
			return
		if inv["water"] >= inv["cup"]:
			hud.toast("杯子都裝滿了，先喝一杯或多做幾個杯子")
			return
		s.water -= 1
		inv["water"] += 1
		_gain("water", 1)
		hud.toast("+1 淡水")
		_refresh_inv()
		return
	if s.fuel > 80.0:
		hud.toast("柴火還夠，等水蒸好")
		return
	if inv["wood"] < 1:
		hud.toast("需要 1 塊木板當柴火")
		return
	if not creative:
		inv["wood"] -= 1
	s.fuel += 40.0
	hud.toast("添了柴火（+40 秒）")
	_refresh_inv()


func _tap_grill(g: Dictionary, pw: Vector3) -> void:
	if not _near(g, pw, "用烤架"):
		return
	if not g.done.is_empty():
		if not _fits(g.done):
			_full_toast()
			return
		_gain("cook", 2)
		hud.toast("拿到 " + _give(g.done))
		g.done = {}
		_refresh_inv()
		return
	if g.slots.size() >= 2:
		hud.toast("烤架滿了，等東西烤好")
		return
	var raw := ""
	for k in ["rawfish", "potato", "egg"]:
		if inv[k] > 0:
			raw = k
			break
	if raw == "":
		hud.toast("需要生魚、馬鈴薯或蛋")
		return
	if inv["wood"] < 1:
		hud.toast("需要 1 塊木板當柴火")
		return
	if not creative:
		inv[raw] -= 1
		inv["wood"] -= 1
	g.slots.append([15.0, raw])
	hud.toast("開始烤%s（15 秒）" % ITEMS[raw])
	_refresh_inv()


func _tap_sail(s: Dictionary, pw: Vector3) -> void:
	if not _near(s, pw, "操作船帆"):
		return
	s.up = not s.up
	sfx.play("whoosh", null, 0.0, 0.2)
	if s.up:
		hud.toast("升起船帆，去船舵掌舵" if not _objs_of("helm").is_empty() else "升起船帆，沒有船舵會順著風漂")
	else:
		hud.toast("收起船帆")


func _tap_helm(h: Dictionary, pw: Vector3) -> void:
	if steer == h:
		_exit_steer()
		return
	if not _near(h, pw, "掌舵"):
		return
	if _objs_of("sail").filter(func(x): return x.up).is_empty():
		hud.toast("先升起船帆，木筏才會動")
	_end_fishing()
	steer = h
	_steer_text = ""


func _exit_steer() -> void:
	if steer == null:
		return
	steer = null
	hud.show_build_bar("")


func _tap_island(n: Dictionary, pw: Vector3) -> void:
	var w: Vector3 = (n.node as Node3D).global_position
	if _flat(pw, w.x, w.z) > 17.0:
		hud.toast("再靠近小島一點才搆得到")
		return
	if n.kind == "tree":
		if n.cd > 0.0:
			hud.toast("椰子還沒長回來（%d 秒）" % ceili(n.cd))
			return
		if not _fits({"coconut": 2, "palm": 3}):
			_full_toast()
			return
		n.cd = 120.0
		n.nuts.visible = false
		var loot := {"coconut": 2, "palm": 3}
		if randf() < 0.3:
			loot["seed_tomato" if randf() < 0.5 else "seed_potato"] = 1
		hud.toast("搖下 " + _give(loot))
		sfx.play("pickup")
	elif n.kind == "goat":
		if n.used:
			return
		if inv["kelp"] < 1:
			hud.toast("山羊不讓你靠近。帶點海帶來給牠吃（潛水採）")
			return
		if not _fits({"goat": 1}):
			_full_toast()
			return
		inv["kelp"] -= 1
		n.used = true
		n.node.visible = false
		inv["goat"] += 1
		hud.toast("山羊吃了海帶，願意跟你走了！蓋山羊圍欄給牠住")
		sfx.play("catch")
	elif not n.used:
		if not _fits({"wood": 5, "plastic": 3, "rope": 2, "seed_potato": 2, "seed_tomato": 2, "shell": 3}):
			_full_toast()
			return
		n.used = true
		n.node.visible = false
		hud.toast("打開木箱：" + _give({"wood": 5, "plastic": 3, "rope": 2, "seed_potato": 2, "seed_tomato": 2, "shell": 3}))
		sfx.play("build")
	_refresh_inv()


func _tap_shark(pw: Vector3) -> void:
	if inv["spear"] < 1 and inv["mspear"] < 1:
		hud.toast("你需要木矛才能反擊（合成 → 木矛）")
		return
	if shark.state == "circle" or shark.state == "flee":
		hud.toast("牠還在繞圈，等牠靠近再刺")
		return
	if _flat(pw, shark.x, shark.z) > SPEAR_REACH:
		hud.toast("再靠近一點才刺得到")
		return
	var double := randf() < 0.08 * _lv("combat")
	var dmg := (2 if inv["mspear"] > 0 else 1) + (1 if double else 0)
	_gain("combat", 2)
	if double:
		hud.toast("用力一刺！")
	sfx.play("splash", Vector3(shark.x, 0, shark.z))
	shark.flash = 0.25
	if is_client():
		net.event({"a": "shark_hit", "dmg": dmg})
		if not double:
			hud.toast("刺中了！")
		return
	_shark_hit(dmg, "")


## The shark takes a spear hit (from this player, or from a friend: peer != "").
func _shark_hit(dmg: int, peer: String) -> void:
	shark.hp -= dmg
	shark.flash = 0.25
	if shark.hp <= 0:
		if peer != "":
			net.send_to(peer, {"e": "repelled"})
		shark.jaw = 0.0
		shark.state = "flee"
		shark.timer = 45.0
		shark.hunt_t = randf_range(18.0, 26.0)
		shark.hp = 3
		if peer == "":
			S["repelled"] += 1
			hud.toast("鯊魚被你趕跑了！")
			_refresh_inv()
		else:
			hud.toast("朋友把鯊魚趕跑了！")
	elif peer == "":
		hud.toast("刺中了！再 %d 下" % shark.hp)


func _tap_filter(o: Dictionary, pw: Vector3) -> void:
	if not _near(o, pw, "裝水"):
		return
	if o.water < 1 and o.kind == "catcher":
		hud.toast("還沒有雨水" + ("（上面有屋頂，接不到雨）" if weather.covered(o.tile.cell) else "，等下雨"))
		return
	if o.water < 1:
		hud.toast("還在過濾，%d 秒後有一杯" % ceili(30.0 * (1.0 - 0.03 * _lv("water")) - o.prog))
		return
	if inv["cup"] < 1:
		hud.toast("需要塑膠杯才能裝水（合成 → 塑膠杯）")
		return
	if inv["water"] >= inv["cup"]:
		hud.toast("杯子都裝滿了，先喝一杯或多做幾個杯子")
		return
	o.water -= 1
	inv["water"] += 1
	_gain("water", 1)
	sfx.play("drink", null, -8.0)
	hud.toast("+1 淡水")
	_refresh_inv()


# ---------------------------------------------------------------- houses

func _place_shelter(key: String) -> void:
	var r := _build_def(build_mode)
	var cost := _build_cost(r.cost)
	if not _has(cost):
		hud.toast("材料不足：需要 " + _cost_text(cost))
		return
	if not shelter.place(build_mode, key):
		hud.toast("這裡蓋不了%s（要有牆或支柱撐著）" % r.name)
		return
	_pay(cost)
	_gain("build", 1)
	sfx.play("build")
	hud.toast("蓋好%s" % r.name)
	if shelter.covered_count() >= 2:
		S["built_house"] = 1
	_refresh_ghosts()
	_refresh_inv()


func _demolish_shelter(piece: Array) -> void:
	var kind: String = piece[0]
	shelter.remove(kind, piece[1])
	var msg := "拆掉%s，退回 %s" % [Shelter.NAME[kind], _refund_half(_build_def(kind).cost)]
	var fell := shelter.settle()
	if fell > 0:
		msg += "（%d 個沒有支撐的部分也掉下來了）" % fell
	_after_shelter_change()
	hud.toast(msg)
	sfx.play("build")
	_refresh_ghosts()
	_refresh_inv()


## After pieces vanish: a player standing on a missing upper floor drops to the deck, stairs re-aim.
func _after_shelter_change() -> void:
	if int(P["level"]) == 1 and not shelter.uppers.has(Vector2i(roundi(P["x"] / TILE), roundi(P["z"] / TILE))):
		P["level"] = 0
		if not _on_raft(P["x"], P["z"]):
			var any: Dictionary = tiles.values()[0]
			P["x"] = any.cell.x * TILE
			P["z"] = any.cell.y * TILE
	for o in _objs_of("stairs"):
		_aim_stairs(o)


## Which neighbour an upper floor is on, for stairs placed at c (ZERO if none, or c is covered).
func _stairs_dir(c: Vector2i) -> Vector2i:
	if shelter.uppers.has(c):
		return Vector2i.ZERO
	for d in Shelter.DIRS:
		if not shelter.uppers.has(c + d):
			continue
		var blocked := false
		for lv in [0, 1]:
			var k := Shelter.edge_key(c, c + d, lv)
			if shelter.edges.has(k) and shelter.edges[k].kind in Shelter.BLOCKS:
				blocked = true
		if not blocked:
			return d
	return Vector2i.ZERO


func _aim_stairs(o: Dictionary) -> void:
	var d := _stairs_dir(o.tile.cell)
	if d != Vector2i.ZERO:
		o["dir"] = d
		o.node.rotation.y = atan2(float(d.x), float(d.y))
	elif not o.has("dir"):
		o["dir"] = Vector2i(0, 1)


func _tap_stairs(o: Dictionary, pw: Vector3) -> void:
	if not _near(o, pw, "走樓梯"):
		return
	var c: Vector2i = o.tile.cell
	var d: Vector2i = o.get("dir", Vector2i(0, 1))
	if int(P["level"]) == 0:
		if not shelter.uppers.has(c + d):
			hud.toast("樓梯上面還沒有二樓地板")
			return
		P["level"] = 1
		P["x"] = (c.x + d.x * 0.7) * TILE
		P["z"] = (c.y + d.y * 0.7) * TILE
		hud.toast("上到二樓")
	else:
		P["level"] = 0
		P["x"] = (c.x - d.x * 0.15) * TILE
		P["z"] = (c.y - d.y * 0.15) * TILE
		hud.toast("下到甲板")
	sfx.play("build", null, -12.0)
	if Shelter.is_mode(build_mode):
		_refresh_ghosts()


func _tap_seabed(n: Dictionary, pw: Vector3) -> void:
	if pw.distance_to(n.pos) > 3.5:
		hud.toast("游近一點才拿得到")
		return
	if inv["goggles"] < 1:
		hud.toast("水裡太模糊了，需要潛水鏡才看得清楚（合成 → 潛水鏡）")
		return
	var give: Dictionary = WRECK_GIVE if n.kind == "wreck" else SEABED_GIVE[n.kind]
	if not _fits(give):
		_full_toast()
		return
	if n.kind == "wreck":
		if n.used:
			return
		n.used = true
		n.node.visible = false
		hud.toast("打開沉船裡的箱子：" + _give(give))
		sfx.play("catch")
	else:
		n.cd = 180.0
		n.node.visible = false
		var got := give.duplicate()
		if randf() < 0.35:
			got["shell"] = randi_range(1, 2)
		hud.toast(("採到 " if n.kind == "kelp" else "挖到 ") + _give(got))
		sfx.play("pickup", null, -4.0)
	S["dug"] += 1
	_gain("swim", 2)
	_refresh_inv()


func _grab_debris(d: Dictionary, pw: Vector3) -> void:
	if Vector2(pw.x - d.x, pw.z - d.z).length() > 2.8 or pw.y < ocean.height(d.x, d.z) - 2.5:
		hud.toast("游近一點才抓得到")
		return
	_collect(d)


func _o2_max() -> float:
	return O2_BASE + 3.0 * _lv("swim")


func _toggle_swim() -> void:
	if paused or over:
		return
	if swim == null and int(P["level"]) > 0:
		hud.toast("先走樓梯下樓才能下水")
		return
	if swim == null:
		_enter_water()
	else:
		_try_climb()


func _enter_water() -> void:
	_exit_steer()
	_end_fishing()
	_set_build("")
	_close_sheet()
	if hook != null:
		hook.d.state = "drift"
		hook = null
		hook_ball.visible = false
	var c := _raft_center()
	var pw := player.global_position
	var dir := Vector2(pw.x - c.x, pw.z - c.z)
	if dir.length() < 0.2:
		dir = Vector2(sin(cam_yaw), cos(cam_yaw)) * -1.0
	dir = dir.normalized()
	var p2 := Vector2(pw.x, pw.z)
	for i in 60:
		p2 += dir * 0.25
		if _tile_at(p2.x - raft_pos.x, p2.y - raft_pos.y) == null:
			break
	p2 += dir * 1.0
	swim = {"pos": Vector3(p2.x, ocean.height(p2.x, p2.y) - 0.7, p2.y), "o2": _o2_max(), "face": atan2(dir.x, dir.y),
		"under": false, "moving": false, "xp_t": 0.0, "pitch": 0.0, "splash_t": 0.0, "warned": false}
	raft.remove_child(player)
	add_child(player)
	sfx.play("splash", swim.pos)
	ocean.ripple(p2.x, p2.y, 1.0)
	shark.hunt_t = 5.0 if mode == "hardcore" else 9.0
	hud.btn["swim"].text = "上船 (F)"
	hud.show_oxygen(true)
	hud.toast(_k("下水了：Shift 下潛、Space 上浮，游到木筏旁按 F 上船", "下水了：按住右邊的下潛 / 上浮，游到木筏旁按上船"))


func _try_climb() -> void:
	var best = null
	var bd := INF
	for t in tiles.values():
		var tw := Vector2(raft_pos.x + t.cell.x * TILE, raft_pos.y + t.cell.y * TILE)
		var dd := tw.distance_to(Vector2(swim.pos.x, swim.pos.z))
		if dd < bd:
			bd = dd
			best = t
	if bd > 2.9 or swim.pos.y < ocean.height(swim.pos.x, swim.pos.z) - 1.6:
		hud.toast("游到木筏旁邊、浮到水面才能上船")
		return
	_leave_water(best, false)


## Back onto the raft (tile t), or just out of swimming state when t is null.
func _leave_water(t, quiet: bool) -> void:
	if swim == null:
		return
	if not quiet:
		sfx.play("splash_small", swim.pos)
	swim = null
	remove_child(player)
	raft.add_child(player)
	player.rotation = Vector3.ZERO
	player.bubbles.emitting = false
	if t != null:
		P["x"] = t.cell.x * TILE
		P["z"] = t.cell.y * TILE
	hud.btn["swim"].text = "下水 (F)"
	hud.show_oxygen(false)
	hud.set_warn("")
	sfx.set_underwater(false)


func _simulate_swim(dt: float, ix: float, iy: float) -> void:
	var up := 1.0 if Input.is_physical_key_pressed(KEY_SPACE) or (hud.touch != null and hud.touch.up) else 0.0
	var down := 1.0 if Input.is_physical_key_pressed(KEY_SHIFT) or (hud.touch != null and hud.touch.down) else 0.0
	var spd := SWIM_SPEED * (1.0 + 0.05 * _lv("swim"))
	var mag := Vector2(ix, iy).length()
	swim.moving = mag > 0.08
	var mv := Vector3.ZERO
	if swim.moving:
		ix /= maxf(1.0, mag)
		iy /= maxf(1.0, mag)
		var fx := -sin(cam_yaw)
		var fz := -cos(cam_yaw)
		var rx := cos(cam_yaw)
		var rz := -sin(cam_yaw)
		mv = Vector3(fx * iy + rx * ix, 0.0, fz * iy + rz * ix) * spd
		swim.face = atan2(mv.x, mv.z)
	var surf := ocean.height(swim.pos.x, swim.pos.z)
	var vy := (up - down) * DIVE_SPEED
	if up == 0.0 and down == 0.0 and surf - swim.pos.y > 0.8:
		vy = 0.35
	swim.pos += Vector3(mv.x, vy, mv.z) * dt
	surf = ocean.height(swim.pos.x, swim.pos.z)
	swim.pos.y = minf(swim.pos.y, surf - 0.7)
	swim.pos.y = maxf(swim.pos.y, seabed_h(swim.pos.x, swim.pos.z) + 0.45)
	for isl in islands:
		var dv := Vector2(swim.pos.x - isl.x, swim.pos.z - isl.z)
		var d := dv.length()
		var lim: float = isl.r * 1.3
		if d < lim and d > 0.01 and swim.pos.y > -2.6:
			var pushed := Vector2(isl.x, isl.z) + dv / d * lim
			swim.pos.x = pushed.x
			swim.pos.z = pushed.y
	if _tile_at(swim.pos.x - raft_pos.x, swim.pos.z - raft_pos.y) != null:
		swim.pos.y = minf(swim.pos.y, surf - 1.3)
	var depth: float = surf - swim.pos.y
	swim.under = depth > 1.0
	if swim.under:
		swim.o2 -= dt
		swim.xp_t += dt
		if swim.xp_t >= 4.0:
			swim.xp_t = 0.0
			_gain("swim", 1)
		if swim.o2 <= 0.0:
			swim.o2 = 0.0
			S["health"] -= dt * 10.0
			hud.set_warn("沒有氧氣了！快浮上去")
		elif swim.o2 < 8.0:
			hud.set_warn("氧氣快用完了")
		elif shark.state != "hunt":
			hud.set_warn("")
	else:
		swim.o2 = minf(_o2_max(), swim.o2 + dt * 12.0)
		if shark.state != "hunt":
			hud.set_warn("")
		swim.splash_t -= dt
		if swim.moving and swim.splash_t <= 0.0:
			swim.splash_t = 0.55
			ocean.ripple(swim.pos.x, swim.pos.z, 0.5)
			sfx.play("splash_small", swim.pos, -14.0)
	if creative:
		swim.o2 = _o2_max()


func _tap_debris(d: Dictionary, pw: Vector3) -> void:
	if hook != null:
		hud.toast("鉤子還在收線")
		return
	if d.type != "bag" and not _fits(DEBRIS[d.type].give):
		_full_toast()
		return
	if fishing != null:
		hud.toast("先收竿才能丟鉤子")
		return
	var dist := _flat(pw, d.x, d.z)
	if dist > _hook_range():
		hud.toast("太遠了，等它漂近（鉤子範圍 %.1f 公尺）" % _hook_range())
		return
	d.state = "hooked"
	if is_client() and d.has("nid"):
		d["claimed"] = true
		d["claim_sent"] = true
		net.event({"a": "claim", "id": d.nid})
	hook = {"d": d, "phase": "out", "t": 0.0, "dur": 0.18 + dist * 0.025}
	sfx.play("whoosh")
	hook_ball.visible = true
	P["face"] = atan2(d.x - pw.x, d.z - pw.z)


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	net.update(delta)
	_screen_t -= delta
	if _screen_t <= 0.0 and hud != null:
		_screen_t = 1.0
		_screen_cache = {}
		var sc := _screen()
		hud.btn["fs"].visible = bool(sc.get("can", false)) and not bool(sc.get("full", false)) and not paused
	if _js_cb != null:
		_js_info_t -= delta
		if _js_info_t <= 0.0:
			_js_info_t = 0.5
			var info := {"role": net.role, "code": net.code, "synced": net.synced, "rooms": net.rooms.size(), "peers": net.peers.size(),
				"tiles": tiles.size(), "paused": paused, "debris": debris.size(), "raft": [raft_pos.x, raft_pos.y]}
			JavaScriptBridge.eval("window.mwInfo = " + JSON.stringify(info), true)
	wall_t += dt
	ocean.t = wall_t
	var c := _raft_center()
	ocean.calm = Vector3(c.x, c.z, c.r)

	# raft rides the swell and tilts with its slope
	var sx := (ocean.height(c.x + 1.5, c.z) - ocean.height(c.x - 1.5, c.z)) / 3.0
	var sz := (ocean.height(c.x, c.z + 1.5) - ocean.height(c.x, c.z - 1.5)) / 3.0
	raft.position = Vector3(raft_pos.x, ocean.height(c.x, c.z) + 0.3, raft_pos.y)
	raft.rotation.z = lerpf(raft.rotation.z, atan(sx) * 0.8, minf(1.0, dt * 3.0))
	raft.rotation.x = lerpf(raft.rotation.x, -atan(sz) * 0.8, minf(1.0, dt * 3.0))
	ocean.mat.set_shader_parameter("raft_off", raft_pos)
	for t in tiles.values():
		if t.shake > 0.0:
			t.shake -= dt
			t.node.position.y = sin(t.shake * 60.0) * 0.06
		else:
			t.node.position.y = 0.0

	if not paused:
		_simulate(dt, c)

	# player
	var pose := ""
	if swim != null:
		var want := 1.35 if swim.moving else (0.6 if swim.under else 0.12)
		swim.pitch = lerpf(swim.pitch, want, minf(1.0, dt * 4.0))
		player.rotation = Vector3(swim.pitch, lerp_angle(player.rotation.y, swim.face, minf(1.0, dt * 8.0)), 0.0)
		var bob: float = 0.0 if swim.under else sin(wall_t * 2.0) * 0.04
		player.position = swim.pos - player.basis * Vector3(0, 0.7, 0) + Vector3(0, bob, 0)
		pose = "swim" if swim.moving else "tread"
		player.bubbles.emitting = swim.under
	else:
		player.position = Vector3(P["x"], 0.1 + (Shelter.FLOOR_Y[1] - Shelter.FLOOR_Y[0]) * int(P["level"]), P["z"])
		shelter.update_view(P["level"], P["x"], P["z"])
		player.rotation.y = lerp_angle(player.rotation.y, P["face"], minf(1.0, dt * 10.0))
	if swim != null:
		pass
	elif steer != null:
		pose = "steer"
	elif fishing != null:
		pose = "fish_bite" if fishing.phase == "bite" else "fish"
	elif hook != null:
		pose = "hook_out" if hook.phase == "out" else "hook_reel"
	player.animate(dt, P["moving"] or (swim != null and swim.moving), pose, wall_t)
	var pw: Vector3 = swim.pos if swim != null else player.global_position
	ring.visible = swim == null
	ring.position = Vector3(pw.x, -0.15, pw.z)
	for sw in seaweeds:
		(sw[0] as Node3D).rotation.z = sin(wall_t * 1.2 + sw[1]) * 0.12
	ring.scale = Vector3.ONE * (_hook_range() / HOOK_RANGE)

	var im := hook_line.mesh as ImmediateMesh
	im.clear_surfaces()
	_update_hook(dt, pw, im)
	_update_bobber(pw, im)

	# shark
	shark_rig.visible = shark_on
	var biting: bool = shark.state == "bite"
	var sy: float = ocean.height(shark.x, shark.z) - (0.12 if biting else shark.dep)
	shark.pitch = lerpf(shark.pitch, (0.18 + shark.jaw * 0.2) if biting else shark.hpitch, minf(1.0, dt * 6.0))
	var thrash := sin(wall_t * 16.0) * 0.1 if biting and shark.jaw < 0.3 else 0.0
	shark_rig.position = Vector3(shark.x, sy, shark.z)
	shark_rig.rotation = Vector3(sin(wall_t * 3.0) * 0.05, shark.head + thrash, shark.pitch)
	shark_rig.swim(wall_t, shark.state != "circle")
	shark_rig.set_jaw(shark.jaw)
	if shark.flash > 0.0:
		shark.flash -= dt
	shark_rig.flash(shark.flash > 0.0)

	# props that animate even when paused
	for o in objs:
		match o.kind:
			"sail":
				o.rig.rotation.y = atan2(cos(wind), sin(wind))
				var k := 1.0 if o.up else 0.12
				o.cloth.scale.y = lerpf(o.cloth.scale.y, k, minf(1.0, dt * 3.0))
				o.cloth.position.y = 3.15 - 1.1 * o.cloth.scale.y
				o.cloth.scale.z = (1.0 + sin(wall_t * 3.0) * 0.08) if o.up else 0.3

	_update_sky_and_camera(dt, pw)
	_update_hud(c)
	sfx.listener = pw
	var fire_k := 0.0
	for o in objs:
		if o.has("fire") and o.fire.visible:
			fire_k = maxf(fire_k, clampf(1.0 - pw.distance_to((o.node as Node3D).global_position) / 7.0, 0.0, 1.0))
	var sailing := not _objs_of("sail").filter(func(x): return x.up).is_empty()
	sfx.set_ambience(0.12 + (clampf(raft_vel.length() / 2.5, 0.0, 1.0) * 0.6 if sailing else 0.0), fire_k * 0.8, dt)


func _update_sky_and_camera(dt: float, pw: Vector3) -> void:
	var phase := fmod(game_t + DAY_LEN * 0.09, DAY_LEN) / DAY_LEN
	var elev := sin(phase * TAU)
	var b := clampf((elev + 0.15) / 0.4, 0.0, 1.0)
	var dusk := maxf(0.0, 1.0 - absf(elev) / 0.3) * 0.75
	var hor := Color("122239").lerp(Color("a9c8dc"), b).lerp(Color("e9a26e"), dusk)
	sky_mat.sky_top_color = Color("050b1a").lerp(Color("2c6cb0"), b).lerp(Color("3f5690"), dusk * 0.5)
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = Color("03121f").lerp(Color("0b2a40"), b)
	env.fog_light_color = hor
	var sun_dir := Vector3(cos(phase * TAU), elev, 0.45).normalized()
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
	sun.light_energy = 0.05 + 1.15 * b
	sun.light_color = Color("fff1d6").lerp(Color("ff9a52"), dusk)
	weather.apply_sky()
	var hours := fmod(6.0 + phase * 24.0, 24.0)
	var hh := int(hours)
	var mm := int((hours - hh) * 6.0) * 10
	hud.clock.text = MODES[mode] + " · " + "第 %d 天 · %02d:%02d · %s" % [int((game_t + DAY_LEN * 0.09) / DAY_LEN) + 1, hh, mm, weather.name_now()]
	if net.in_room():
		hud.clock.text += "\n房間 %s · %d 人%s" % [net.code, net.player_count(), "（你是房主）" if net.is_host() else ""]
	hud.btn["room"].visible = net.in_room()
	cam_target = cam_target.lerp(pw + Vector3(0, 0.3 if swim != null else 1.1, 0), minf(1.0, dt * 6.0))
	var dist := cam_dist * (0.6 if swim != null and swim.under else 1.0)
	var cp := cam_target + Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * dist
	if swim != null and swim.under:
		cp.y = minf(cp.y, ocean.height(cp.x, cp.z) - 0.4)
		cp.y = maxf(cp.y, seabed_h(cp.x, cp.z) + 0.4)
	cam.global_position = cp
	cam.look_at(cam_target, Vector3.UP)
	var cam_under := cp.y < ocean.height(cp.x, cp.z) - 0.05
	if cam_under:
		var clear: bool = inv["goggles"] > 0
		env.fog_density = 0.035 if clear else 0.12
		env.fog_light_color = Color("0e5866").lerp(Color("031820"), 1.0 - b)
		env.fog_aerial_perspective = 0.0
		env.fog_sky_affect = 1.0
		uw_overlay.color = Color(0.04, 0.3, 0.36, 0.12 if clear else 0.3)
	else:
		env.fog_density = 0.0045 + weather.fog_extra()
		env.fog_aerial_perspective = 0.6
		env.fog_sky_affect = 0.12
	uw_overlay.visible = cam_under
	sfx.set_underwater(cam_under)
	seabed_mat.set_shader_parameter("time_s", wall_t)
	seabed_mat.set_shader_parameter("light_k", 0.15 + 0.85 * b)
	ocean.update_frame(cam_target, sun_dir, 0.15 + 0.85 * b)


func _arrow_to(dx: float, dz: float) -> String:
	var fwd := Vector2(-sin(cam_yaw), -cos(cam_yaw))
	var right := Vector2(cos(cam_yaw), -sin(cam_yaw))
	var v := Vector2(dx, dz)
	var a := atan2(v.dot(right), v.dot(fwd))
	return ARROWS[posmod(roundi(a / (PI / 4.0)), 8)]


func _update_hud(c: Dictionary) -> void:
	hud.set_stat("thirst", S["thirst"], "%d%%" % ceili(S["thirst"]))
	hud.set_stat("hunger", S["hunger"], "%d%%" % ceili(S["hunger"]))
	hud.set_stat("health", S["health"], "%d" % ceili(S["health"]))
	if swim != null:
		hud.set_stat("oxygen", swim.o2 / _o2_max() * 100.0, "%d 秒" % ceili(swim.o2))
	var best = null
	var bd := INF
	for pass_visited in [false, true]:
		for isl in islands:
			if isl.visited != pass_visited and not pass_visited:
				continue
			var d: float = Vector2(isl.x - c.x, isl.z - c.z).length() - isl.r
			if d < bd:
				bd = d
				best = isl
		if best != null:
			break
	var speed := raft_vel.length()
	hud.nav.text = "%s %s %d m　風 %s%s" % [_arrow_to(best.x - c.x, best.z - c.z), "小島" if best.visited else "未探索小島",
		maxi(0, roundi(bd)), _arrow_to(cos(wind), sin(wind)), ("　%.1f m/s" % speed) if speed > 0.15 else ""]
	var hint := companions.nav_hint(c)
	if hint != "":
		hud.nav.text += "\n" + hint
	var tb = traders.nav_target()
	if tb != null:
		hud.nav.text += "\n%s 商船 %d m" % [_arrow_to(tb.x - c.x, tb.y - c.z), roundi(Vector2(tb.x - c.x, tb.y - c.z).length())]
	for o in objs:
		match o.kind:
			"still":
				var ready: bool = o.water > 0
				o.label.modulate = Color("5bc8f0") if ready else Color("f4ecd6")
				if ready:
					o.label.text = "淡水 %d/2 · 點我裝水" % o.water
				elif o.fuel > 0.0:
					o.label.text = "蒸餾中 %d 秒 · 柴火 %d 秒" % [ceili(20.0 - o.prog), ceili(o.fuel)]
				else:
					o.label.text = "沒有柴火 · 點我添木板"
			"catcher":
				var wet: bool = o.water > 0
				o.label.modulate = Color("5bc8f0") if wet else Color("f4ecd6")
				if weather.covered(o.tile.cell):
					o.label.text = "集雨布 · 上面有屋頂，接不到雨"
				elif wet:
					o.label.text = "雨水 %d/4 · 點我裝水" % o.water
				elif weather.raining():
					o.label.text = "接雨中…"
				else:
					o.label.text = "集雨布 · 等下雨"
				o.level_node.position.y = 0.05 + 0.12 * o.water
			"filter":
				var full: bool = o.water > 0
				o.label.modulate = Color("5bc8f0") if full else Color("f4ecd6")
				o.label.text = ("淡水 %d/3 · 點我裝水" % o.water) if full else ("過濾中 %d 秒" % ceili(30.0 * (1.0 - 0.03 * _lv("water")) - o.prog))
			"grill":
				o.label.modulate = Color("f0a548") if not o.done.is_empty() else Color("f4ecd6")
				if not o.done.is_empty():
					o.label.text = "烤好了 · 點我拿"
				elif not o.slots.is_empty():
					o.label.text = "烤%s中 %d 秒" % [ITEMS[o.slots[0][1]], ceili(o.slots[0][0])]
				else:
					o.label.text = "放生魚 / 馬鈴薯 / 蛋＋木板 · 點我"

	if steer != null:
		var up := not _objs_of("sail").filter(func(x): return x.up).is_empty()
		var txt := "掌舵中 · " + _k("A / D", "搖桿左右") + " 轉向 · 航速 %.1f m/s%s" % [speed, "" if up else "（帆沒升）"]
		if txt != _steer_text:
			_steer_text = txt
			hud.show_build_bar(txt, "離開船舵", "steer_done")


func _simulate(dt: float, c: Dictionary) -> void:
	game_t += dt
	var ix := (1.0 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) else 0.0)
	var iy := (1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else 0.0)
	if hud.touch != null:
		ix = clampf(ix + hud.touch.stick.x, -1.0, 1.0)
		iy = clampf(iy + hud.touch.stick.y, -1.0, 1.0)
		hud.touch.show_dive = swim != null
	P["moving"] = false
	if swim != null:
		_simulate_swim(dt, ix, iy)
	elif steer != null:
		heading += ix * 0.85 * dt
		if absf(ix) > 0.01:
			_steer_quiet = 1.5
		steer.wheel.rotation.z -= ix * dt * 3.0
		P["x"] = steer.tile.cell.x * TILE
		P["z"] = steer.tile.cell.y * TILE - 0.62
		P["level"] = 0
		P["face"] = atan2(cos(heading), sin(heading))
	else:
		var mag := Vector2(ix, iy).length()
		if mag > 0.08:
			ix /= maxf(1.0, mag)
			iy /= maxf(1.0, mag)
			var fx := -sin(cam_yaw)
			var fz := -cos(cam_yaw)
			var rx := cos(cam_yaw)
			var rz := -sin(cam_yaw)
			var mx := (fx * iy + rx * ix) * 3.6 * dt
			var mz := (fz * iy + rz * ix) * 3.6 * dt
			var lv: int = P["level"]
			if shelter.can_walk(P["x"], P["z"], P["x"] + mx, P["z"], lv):
				P["x"] += mx
			if shelter.can_walk(P["x"], P["z"], P["x"], P["z"] + mz, lv):
				P["z"] += mz
			P["face"] = atan2(mx, mz)
			P["moving"] = true

	# needs
	var drain := 1.3 if mode == "hardcore" else 1.0
	S["thirst"] = maxf(0.0, S["thirst"] - dt * 100.0 / THIRST_SEC * drain)
	S["hunger"] = maxf(0.0, S["hunger"] - dt * 100.0 / HUNGER_SEC * drain)
	if S["thirst"] <= 0.0:
		S["health"] -= dt * 1.6
	if S["hunger"] <= 0.0:
		S["health"] -= dt * 1.1
	if S["thirst"] > 30.0 and S["hunger"] > 30.0:
		S["health"] = minf(100.0, S["health"] + dt * 0.6)
	if creative:
		S["thirst"] = 100.0
		S["hunger"] = 100.0
		S["health"] = 100.0
	if S["health"] <= 0.0:
		S["health"] = 0.0
		_on_death()
		if over:
			return

	# a friend's game mirrors the host's world: world timers stand still (sdt = 0), visuals still run
	var client := is_client()
	var sdt := 0.0 if client else dt
	if client:
		_net_client_tick(dt, c)
	else:
		_sail(dt, c)
		traders.update(dt, c)
	weather.update(dt, player.global_position, client)
	if not client:
		companions.update(dt, c)
		companions.shark_watch()
		if swim != null:
			companions.swim_tick(dt)

	# debris drifts with the current, relative to the moving raft
	var flow := _flow()
	var flow_len := maxf(0.01, flow.length())
	spawn_t -= sdt
	if spawn_t <= 0.0 and not client:
		_spawn_debris(false)
		spawn_t = randf_range(1.25, 1.85) * 0.95 / maxf(0.95, flow_len)
	for d in debris.duplicate():
		if client and d.has("nid"):
			continue   # the host's debris: moved by _net_client_tick
		if d.type == "bag":
			d.ttl -= dt
			d.label.text = "%s · 剩 %d 分 %02d 秒" % [d.get("label_text", "你的背包"), int(d.ttl / 60.0), int(fmod(d.ttl, 60.0))]
			if d.ttl <= 0.0:
				hud.toast("%s沉下去了……" % d.get("what", "背包"))
				_remove_debris(d)
				continue
		if d.state == "drift" and d.type != "bag":
			d.x += (CURRENT.x + sin(wall_t * 0.3 + d.seed) * 0.12) * dt
			d.z += CURRENT.y * dt
			var ox: float = d.x - c.x
			var oz: float = d.z - c.z
			if (ox * flow.x + oz * flow.y) / flow_len > 48.0 or Vector2(ox, oz).length() > 85.0:
				_remove_debris(d)
				continue
		d.node.position = Vector3(d.x, ocean.height(d.x, d.z) + 0.06, d.z)
		d.node.rotation.y += d.spin * dt

	farm.update(dt, sdt)
	for o in objs:
		match o.kind:
			"still":
				if sdt <= 0.0:
					pass
				elif o.fuel > 0.0 and o.water < 2:
					o.fuel = maxf(0.0, o.fuel - dt)
					o.prog += dt
					if o.prog >= 20.0 * (1.0 - 0.03 * _lv("water")):
						o.prog = 0.0
						o.water += 1
						if o.water == 1:
							hud.toast("蒸餾杯有一杯淡水了")
				elif o.fuel > 0.0:
					o.fuel = maxf(0.0, o.fuel - dt * 0.25)
				o.fire.visible = o.fuel > 0.0
				if o.fire.visible:
					o.fire.scale = Vector3(1, 0.8 + sin(wall_t * 18.0) * 0.2, 1)
			"filter":
				if o.water < 3:
					o.prog += sdt
					if o.prog >= 30.0 * (1.0 - 0.03 * _lv("water")):
						o.prog = 0.0
						o.water += 1
			"grill":
				for sl in o.slots:
					sl[0] -= sdt
				while not o.slots.is_empty() and o.slots[0][0] <= 0.0:
					var raw: String = o.slots.pop_front()[1]
					var out: String = GRILL[raw][0]
					o.done[out] = int(o.done.get(out, 0)) + 1
					hud.toast("%s好了，去烤架拿" % GRILL[raw][1])
				o.fire.visible = not o.slots.is_empty()
				if o.fire.visible:
					o.fire.scale = Vector3(1, 0.8 + sin(wall_t * 17.0) * 0.2, 1)
				var n_done := 0
				for v in o.done.values():
					n_done += int(v)
				for i in o.fishes.size():
					var f: MeshInstance3D = o.fishes[i]
					f.visible = i < n_done + o.slots.size()
					(f.material_override as StandardMaterial3D).albedo_color = Color("b5652a") if i < n_done else Color("8fa9b8")

	if fishing != null:
		fishing.t += dt
		if fishing.phase == "cast" and fishing.t > 0.45:
			sfx.play("splash_small", Vector3(fishing.x, 0, fishing.z), -4.0)
			fishing.phase = "wait"
			fishing.t = 0.0
			ocean.ripple(fishing.x, fishing.z, 0.7)
		elif fishing.phase == "wait" and fishing.t > fishing.wait:
			fishing.phase = "bite"
			sfx.play("splash", Vector3(fishing.x, 0, fishing.z), -2.0)
			fishing.bite = 1.8 + 0.08 * _lv("fish") + (0.8 if inv["rod2"] > 0 else 0.0)
			ocean.ripple(fishing.x, fishing.z, 1.0)
			hud.toast(_k("上鉤了！快按 R 收竿", "上鉤了！快按收竿"))
			_update_reel()
		elif fishing.phase == "bite":
			fishing.bite -= dt
			if fishing.bite <= 0.0:
				fishing.phase = "wait"
				fishing.t = 0.0
				fishing.wait = _bite_wait()
				hud.toast("魚跑掉了，再等等看")
				_update_reel()

	if client:
		_net_shark_warn()
	else:
		_update_shark(dt, c)

	for n in seabed_nodes:
		if n.kind != "wreck" and n.cd > 0.0 and not client:
			n.cd -= dt
			if n.cd <= 0.0:
				n.node.visible = true

	goal_t -= dt
	if goal_t <= 0.0:
		goal_t = 0.5
		_refresh_goals()
	_autosave_t -= dt
	if _autosave_t <= 0.0:
		_autosave_t = AUTOSAVE_SEC
		_save_game()
	if client:
		net.flush()


func _sail(dt: float, c: Dictionary) -> void:
	wind = ocean.wind + sin(game_t * 0.011) * 0.35 + sin(game_t * 0.027) * 0.15
	var up := _objs_of("sail").filter(func(x): return x.up).size()
	var dir_ang := heading if not _objs_of("helm").is_empty() else wind
	var target := 0.0
	if up > 0:
		var rel := cos(dir_ang - wind)
		var wind_f := (0.3 + 0.7 * maxf(0.0, rel)) if rel > -0.25 else 0.08
		var props := objs.size() - up
		var mass := maxf(0.45, 1.15 - tiles.size() * 0.025 - props * 0.02)
		target = minf(3.8, 2.3 * sqrt(up)) * maxf(wind_f, companions.upwind()) * mass * companions.pull()
	raft_vel = raft_vel.lerp(Vector2(cos(dir_ang), sin(dir_ang)) * target, minf(1.0, dt * 0.5))
	raft_pos += raft_vel * dt
	var speed := raft_vel.length()
	for isl in islands:
		var dv := Vector2(c.x - isl.x, c.z - isl.z)
		var d := dv.length()
		var min_d: float = isl.r * 1.3 + c.r - 1.2
		if d < min_d and d > 0.01:
			var n := dv / d
			raft_pos += n * (min_d - d)
			var into := raft_vel.dot(n)
			if into < 0.0:
				raft_vel -= n * into
			if speed > 0.6 and isl.bump <= 0.0:
				hud.toast("擱淺了，轉個方向")
				isl.bump = 3.0
		if isl.bump > 0.0:
			isl.bump -= dt
		if not isl.visited and d < isl.r + 18.0:
			isl.visited = true
			S["islands"] += 1
			hud.toast("發現小島！點棕櫚樹和木箱搜刮")
			_refresh_inv()
		for n in isl.nodes:
			if n.kind == "tree" and n.cd > 0.0:
				n.cd -= dt
				if n.cd <= 0.0:
					n.nuts.visible = true
	wake_t -= dt
	if speed > 0.5 and wake_t <= 0.0:
		wake_t = 0.35
		var back: Vector2 = raft_vel / speed * c.r
		ocean.ripple(c.x - back.x, c.z - back.y, minf(1.0, speed * 0.35))


func _update_hook(dt: float, pw: Vector3, im: ImmediateMesh) -> void:
	if hook == null:
		hook_ball.visible = false
		return
	var d: Dictionary = hook.d
	var hand := pw + Vector3(0, 0.9, 0)
	var dp: Vector3 = d.node.position
	if hook.phase == "out":
		hook.t += dt
		var k := minf(1.0, hook.t / hook.dur)
		hook_ball.position = hand.lerp(dp, k) + Vector3(0, sin(k * PI) * 2.2, 0)
		if k >= 1.0:
			hook.phase = "reel"
			sfx.play("splash_small", Vector3(d.x, 0, d.z))
			ocean.ripple(d.x, d.z, 1.0)
	else:
		var to := Vector2(pw.x - d.x, pw.z - d.z)
		var dist := to.length()
		var step := minf(dist, 8.0 * (1.0 + 0.05 * _lv("hook")) * dt)
		d.x += to.x / dist * step
		d.z += to.y / dist * step
		hook_ball.position = dp
		if dist < 1.3:
			ocean.ripple(d.x, d.z, 0.6)
			_collect(d)
			hook = null
			hook_ball.visible = false
			return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(hand)
	im.surface_add_vertex(hook_ball.position)
	im.surface_end()


func _update_bobber(pw: Vector3, im: ImmediateMesh) -> void:
	if fishing == null:
		return
	var hand := pw + Vector3(0, 1.0, 0)
	var wy := ocean.height(fishing.x, fishing.z) + 0.04
	if fishing.phase == "cast":
		var k := minf(1.0, fishing.t / 0.45)
		bobber.position = hand.lerp(Vector3(fishing.x, wy, fishing.z), k) + Vector3(0, sin(k * PI) * 2.0, 0)
	else:
		var dip := (-0.12 + sin(wall_t * 22.0) * 0.07) if fishing.phase == "bite" else sin(wall_t * 2.4) * 0.015
		bobber.position = Vector3(fishing.x, wy + dip, fishing.z)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(hand)
	im.surface_add_vertex(bobber.position + Vector3(0, 0.08, 0))
	im.surface_end()
	if _flat(pw, fishing.x, fishing.z) > FISH_RANGE + 2.0:
		hud.toast("離浮標太遠，線斷了")
		_end_fishing()


func _update_shark(dt: float, c: Dictionary) -> void:
	if not shark_on:
		shark.state = "circle"
		shark.timer = 40.0
		shark.x = c.x + 60.0
		shark.z = c.z
		hud.set_warn("")
		return
	if shark.state != "hunt":
		shark.dep = lerpf(shark.dep, 0.42, minf(1.0, dt * 0.8))
		shark.hpitch = lerpf(shark.hpitch, 0.0, minf(1.0, dt * 2.0))
	shark.rip_t -= dt
	if shark.rip_t <= 0.0 and shark.dep < 1.5:
		var calm_swim: bool = shark.state == "circle" or shark.state == "flee"
		shark.rip_t = 0.8 if calm_swim else 0.4
		ocean.ripple(shark.x, shark.z, 0.9 if shark.state == "bite" else (0.4 if calm_swim else 0.6))
	var R: float = c.r + 5.0
	match shark.state:
		"circle":
			shark.jaw = maxf(0.0, shark.jaw - dt * 3.0)
			shark.ang += dt * 0.28
			_steer_shark(c.x + cos(shark.ang) * R, c.z + sin(shark.ang) * R, 4.5, dt)
			shark.timer -= dt * (1.4 if mode == "hardcore" else 1.0)
			if swim != null or not net.remote_swimmers().is_empty():
				shark.hunt_t -= dt
				if shark.hunt_t <= 0.0:
					shark.state = "hunt"
					var prey := _shark_prey()
					shark["tpeer"] = str(prey.get("peer", ""))
					if shark.tpeer == "":
						hud.toast("鯊魚朝你游過來了！快上船或拿矛反擊")
						sfx.play("shark_alert", null, -2.0, 0.0)
					return
			if shark.timer <= 0.0 and tiles.size() > 1:
				shark.target = _edge_tiles().pick_random()
				shark.side = _bite_side(shark.target)
				shark.state = "approach"
				shark.lunge = false
				shark.warned = false
			hud.set_warn("")
		"approach", "bite":
			var t = shark.target
			if t == null or not tiles.has(t.cell) or tiles[t.cell] != t:
				shark.jaw = 0.0
				shark.state = "circle"
				shark.timer = 30.0
				hud.set_warn("")
				return
			if tiles.has(t.cell + Vector2i(roundi(shark.side.x), roundi(shark.side.y))):
				shark.side = _bite_side(t)   # the raft grew over that side; pick another
			var side: Vector2 = shark.side
			var tw := Vector2(raft_pos.x + t.cell.x * TILE, raft_pos.y + t.cell.y * TILE)
			# snout (1.75 m ahead of the body centre) rests on the outer edge of the tile
			var bite_pt := tw + side * (TILE * 0.5 + 1.75)
			var stage_pt := tw + side * 7.0
			if shark.state == "approach":
				if not shark.warned:
					hud.toast("鯊魚朝木筏游過來了！")
					sfx.play("shark_alert", null, -2.0, 0.0)
					shark.warned = true
				hud.set_warn("鯊魚靠近了")
				if not shark.lunge:
					# swim around the raft (never through it) until lined up with the target side
					var ctr := Vector2(c.x, c.z)
					var a_s := (Vector2(shark.x, shark.z) - ctr).angle()
					var a_t := (stage_pt - ctr).angle()
					var diff := angle_difference(a_s, a_t)
					var goal := stage_pt
					if absf(diff) > 0.5:
						var rr := maxf(R, (stage_pt - ctr).length())
						goal = ctr + Vector2.from_angle(a_s + signf(diff) * 0.5) * rr
					if _steer_shark(goal.x, goal.y, 5.5, dt) < 1.0 and absf(diff) <= 0.5:
						shark.lunge = true
				else:
					shark.jaw = lerpf(shark.jaw, 0.8, minf(1.0, dt * 3.0))
					if _steer_shark(bite_pt.x, bite_pt.y, 3.2, dt) < 0.2:
						if companions.shark_bite():
							shark.jaw = 0.0
							shark.state = "flee"
							shark.timer = 45.0
							shark.hp = 3
							S["repelled"] += 1
						else:
							shark.state = "bite"
							shark.bite = 0.9
			else:
				# hold the snout on the edge, face the raft, open wide, then snap shut on each bite
				shark.x = lerpf(shark.x, bite_pt.x, minf(1.0, dt * 6.0))
				shark.z = lerpf(shark.z, bite_pt.y, minf(1.0, dt * 6.0))
				shark.head = lerp_angle(shark.head, atan2(side.y, -side.x), minf(1.0, dt * 6.0))
				shark.bite -= dt
				var since: float = 2.4 - shark.bite
				shark.jaw = clampf((since - 0.5) / 1.2, 0.0, 1.0) if since > 0.25 else maxf(0.0, shark.jaw - dt * 12.0)
				if shark.bite <= 0.0:
					shark.bite = 2.4
					shark.jaw = 1.0
					sfx.play("bite", Vector3(bite_pt.x, 0, bite_pt.y))
					ocean.ripple(bite_pt.x - side.x * 1.75, bite_pt.y - side.y * 1.75, 0.9)
					if tiles.size() > 1:
						t.hp -= 1
					t.shake = 0.35
					_tint(t)
					if t.hp <= 0:
						var lost := ""
						if t.obj != null:
							lost = "，上面的%s也沉了" % OBJ_NAME[t.obj.kind]
						hud.toast("鯊魚咬掉了一格地板" + (lost if lost != "" else "！"))
						_remove_tile(t)
						if build_mode != "":
							_refresh_ghosts()
						_refresh_inv()
						shark.state = "circle"
						shark.timer = 55.0
				hud.set_warn("鯊魚正在咬木筏！靠近點牠反擊" if inv["spear"] > 0 else "鯊魚正在咬木筏！快做木矛")
		"hunt":
			var prey := _shark_prey()
			if prey.is_empty():
				shark.state = "circle"
				shark.timer = maxf(shark.timer, 20.0)
				shark.jaw = 0.0
				shark["tpeer"] = ""
				hud.set_warn("")
				return
			shark["tpeer"] = str(prey.peer)
			var tp: Vector3 = prey.pos
			var surf_s := ocean.height(shark.x, shark.z)
			var fwd := Vector3(cos(shark.head), 0.0, -sin(shark.head))
			var snout := Vector3(shark.x, surf_s - shark.dep, shark.z) + fwd * 1.75
			var to2 := Vector2(tp.x - shark.x, tp.z - shark.z)
			var hd := to2.length()
			var aim := Vector2(tp.x, tp.z) - to2.normalized() * 1.6 if hd > 0.01 else Vector2(shark.x, shark.z)
			_steer_shark(aim.x, aim.y, 6.0, dt)
			shark.dep = lerpf(shark.dep, clampf(surf_s - tp.y, 0.42, 40.0), minf(1.0, dt * 1.5))
			shark.hpitch = clampf(atan2(tp.y - (surf_s - shark.dep), maxf(hd, 0.5)), -0.6, 0.6)
			var sd := snout.distance_to(tp)
			shark.jaw = lerpf(shark.jaw, 0.9 if sd < 5.0 else 0.0, minf(1.0, dt * 4.0))
			hud.set_warn("鯊魚在追你！" if shark.tpeer == "" else "鯊魚在追%s！" % net.peers.get(shark.tpeer, {"name": "朋友"}).name)
			if sd < 1.2:
				var dmg := 35.0 if mode == "hardcore" else 25.0
				shark.jaw = 0.0
				sfx.play("bite", tp)
				ocean.ripple(tp.x, tp.z, 1.0)
				if shark.tpeer == "":
					S["health"] -= dmg
					hud.toast("被鯊魚咬了一口！生命 -%d" % int(dmg))
				else:
					net.send_to(shark.tpeer, {"e": "hurt", "dmg": dmg})
				shark.state = "flee"
				shark.timer = 14.0
				shark.hunt_t = randf_range(10.0, 16.0)
				hud.set_warn("")
		"flee":
			shark.jaw = maxf(0.0, shark.jaw - dt * 3.0)
			var away := Vector2(shark.x - c.x, shark.z - c.z)
			if away.length() < 0.01:
				away = Vector2(1, 0)
			away = away.normalized()
			_steer_shark(c.x + away.x * 40.0, c.z + away.y * 40.0, 7.0, dt)
			shark.timer -= dt
			if shark.timer <= 0.0:
				shark.state = "circle"
				shark.timer = 60.0
				shark.ang = atan2(away.y, away.x)
			hud.set_warn("")


## Outward direction of an exposed side of tile t, preferring the side facing the shark.
func _bite_side(t: Dictionary) -> Vector2:
	var best := Vector2.RIGHT
	var best_dot := -INF
	var to_shark := Vector2(shark.x - (raft_pos.x + t.cell.x * TILE), shark.z - (raft_pos.y + t.cell.y * TILE)).normalized()
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tiles.has(t.cell + o):
			continue
		var v := Vector2(o)
		var dd := v.dot(to_shark)
		if dd > best_dot:
			best_dot = dd
			best = v
	return best


func _steer_shark(tx: float, tz: float, speed: float, dt: float) -> float:
	var to := Vector2(tx - shark.x, tz - shark.z)
	var d := to.length()
	if d > 0.001:
		var step := minf(d, speed * dt)
		shark.x += to.x / d * step
		shark.z += to.y / d * step
		shark.head = lerp_angle(shark.head, atan2(-to.y, to.x), minf(1.0, dt * 4.0))
	return d


func _exit_tree() -> void:
	Models._cache.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not paused and not over:
		_save_game()


# ---------------------------------------------------------------- save / load

func _save_game() -> void:
	if is_client():
		return   # a friend's copy of the host's world is not theirs to save
	var tl := []
	for t in tiles.values():
		tl.append([t.cell.x, t.cell.y, t.hp])
	var ol := []
	for o in objs:
		ol.append(_obj_entry(o))
	var il := []
	for isl in islands:
		var nodes := []
		for n in isl.nodes:
			nodes.append(n.cd if n.kind == "tree" else (1.0 if n.used else 0.0))
		il.append({"visited": isl.visited, "nodes": nodes})
	var data := {
		"version": 1, "creative": creative, "shark_on": shark_on, "game_t": game_t, "mode": mode, "skills": skills,
		"inv": inv, "stats": S, "raft": [raft_pos.x, raft_pos.y, heading], "player": [P["x"], P["z"], P["level"]], "shelter": shelter.save_state(),
		"tiles": tl, "objs": ol, "islands": il, "wreck": wreck_node.used, "traders": traders.save_state(), "weather": weather.save_state(), "pets": companions.save_state(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 1:
		return false
	creative = data.creative
	mode = str(data.get("mode", "creative" if creative else "standard"))
	if data.has("skills"):
		for k in data.skills:
			if skills.has(k):
				skills[k] = {"lv": int(data.skills[k].lv), "xp": int(data.skills[k].xp)}
	shark_on = data.shark_on
	game_t = float(data.game_t)
	for k in data.inv:
		inv[k] = int(data.inv[k])
	for k in data.stats:
		S[k] = float(data.stats[k]) if k in ["thirst", "hunger", "health"] else int(data.stats[k])
	if not S.has("bag"):
		S["bag"] = 20
	for t in tiles.values():
		t.node.queue_free()
	tiles.clear()
	for o in objs:
		if Farm.is_farm(o.kind):
			farm.forget(o)
	objs.clear()
	if shelter != null:
		shelter.clear()
	for e in data.tiles:
		var c := Vector2i(int(e[0]), int(e[1]))
		_add_tile(c)
		tiles[c].hp = int(e[2])
		_tint(tiles[c])
	for e in data.objs:
		var c := Vector2i(int(e.x), int(e.y))
		if not tiles.has(c):
			continue
		var kind: String = "field" if e.kind == "planter" else str(e.kind)
		_place(kind, tiles[c])
		_apply_obj(tiles[c].obj, e)
	raft_pos = Vector2(float(data.raft[0]), float(data.raft[1]))
	heading = float(data.raft[2])
	raft_vel = Vector2.ZERO
	P["x"] = float(data.player[0])
	P["z"] = float(data.player[1])
	if not _on_raft(P["x"], P["z"]):
		var any: Dictionary = tiles.values()[0]
		P["x"] = any.cell.x * TILE
		P["z"] = any.cell.y * TILE
	for i in mini(islands.size(), data.islands.size()):
		var isl: Dictionary = islands[i]
		var saved: Dictionary = data.islands[i]
		isl.visited = bool(saved.visited)
		for j in mini(isl.nodes.size(), saved.nodes.size()):
			var n: Dictionary = isl.nodes[j]
			var v := float(saved.nodes[j])
			if n.kind == "tree":
				n.cd = v
				n.nuts.visible = v <= 0.0
			else:
				n.used = v > 0.5
				n.node.visible = not n.used
	traders.load_state(data.get("traders", {}))
	weather.load_state(data.get("weather", {}))
	companions.load_state(data.get("pets", {}))
	shelter.load_state(data.get("shelter", {}))
	P["level"] = int(data.player[2]) if data.player.size() > 2 else 0
	_after_shelter_change()
	if data.get("wreck", false):
		wreck_node.used = true
		wreck_node.node.visible = false
	shark.state = "circle"
	shark.timer = 40.0
	shark.target = null
	shark.x = raft_pos.x + 1.0
	shark.z = raft_pos.y + 18.0
	_update_mask()
	_refresh_inv()
	goals_done = 0
	for g in _goals():
		if g[2]:
			goals_done += 1
	_autosave_t = AUTOSAVE_SEC
	return true


func _on_death() -> void:
	sfx.play("fail", null, -3.0, 0.0)
	match "standard" if is_client() and mode == "hardcore" else mode:
		"hardcore":
			_game_over()
			return
		"peaceful":
			S["thirst"] = 80.0
			S["hunger"] = 80.0
			S["health"] = 80.0
			hud.toast("你昏倒了，醒來時東西都還在")
		_:
			_drop_bag()
			S["thirst"] = 60.0
			S["hunger"] = 60.0
			S["health"] = 60.0
	_exit_steer()
	_end_fishing()
	_leave_water(null, true)
	shark.state = "flee"
	shark.timer = 20.0
	var cell: Vector2i = tiles.keys()[0]
	P["x"] = cell.x * TILE
	P["z"] = cell.y * TILE
	_refresh_inv()


## Something worth rescuing floats at (x, z) for BAG_TTL seconds; hook it or grab it while swimming.
func _drop_floating(items: Dictionary, x: float, z: float, label_text: String, node: Node3D) -> void:
	add_child(node)
	var label := _label3d(node)
	label.position.y = 1.3
	label.pixel_size = 0.009
	label.modulate = Color("ff9f1c")
	var ang := randf() * TAU
	debris.append({"node": node, "type": "bag", "give": items, "x": x + cos(ang) * 2.5, "z": z + sin(ang) * 2.5,
		"seed": 0.0, "spin": 0.15, "state": "bag", "ttl": BAG_TTL, "label": label, "label_text": label_text,
		"what": label_text.trim_prefix("掉進海裡的")})


## Standard mode: everything in the backpack floats next to the raft for BAG_TTL seconds.
func _drop_bag() -> void:
	var items := {}
	for k in STACK:
		if inv[k] > 0:
			items[k] = inv[k]
			inv[k] = 0
	inv["water"] = 0
	if items.is_empty():
		hud.toast("你昏倒了！")
		return
	var c := _raft_center()
	var ang := randf() * TAU
	var node := Models.lost_bag()
	add_child(node)
	var label := _label3d(node)
	label.position.y = 1.3
	label.pixel_size = 0.009
	label.modulate = Color("ff9f1c")
	debris.append({"node": node, "type": "bag", "what": "背包", "give": items, "x": c.x + cos(ang) * (c.r + 3.5),
		"z": c.z + sin(ang) * (c.r + 3.5), "seed": 0.0, "spin": 0.15, "state": "bag", "ttl": BAG_TTL, "label": label})
	hud.toast("你昏倒了！背包掉進海裡，10 分鐘內用鉤子撈回來")


func _game_over() -> void:
	sfx.play("fail", null, 0.0, 0.0)
	if not creative:
		DirAccess.remove_absolute(SAVE_PATH)
	over = true
	paused = true
	_set_build("")
	_close_sheet()
	_exit_steer()
	_end_fishing()
	var days := int((game_t + DAY_LEN * 0.09) / DAY_LEN) + 1
	var done := 0
	for g in _goals():
		if g[2]:
			done += 1
	hud.show_menu("你沒撐過去", "第 %d 天" % days,
		"存活 %d 分 %02d 秒，完成 %d / %d 個目標，木筏 %d 格。" % [int(game_t / 60.0), int(fmod(game_t, 60.0)), done, _goals().size(), tiles.size()],
		[["retry", "再試一次", true]])


# ---------------------------------------------------------------- co-op (see net.gd)

func is_client() -> bool:
	return net != null and net.is_client()


func _start_hosting() -> void:
	if not _host_after_start:
		return
	_host_after_start = false
	if not net.available():
		hud.toast("連線還沒準備好，這局先自己玩")
		return
	net.host(Net.new_code())
	hud.toast("房間開好了！房號 %s，朋友打開這個遊戲按「跟朋友玩」就能加入" % net.code)


func _show_mp_menu() -> void:
	_mp_menu = true
	paused = true
	_set_build("")
	_close_sheet()
	var st: String = net.tr.state() if net.tr != null else "no"
	if st == "wait":
		hud.show_menu("跟朋友玩", "準備連線中…", "等一兩秒再按一次。", [["mp", "再試一次", true], ["mp_back", "返回", false]])
		return
	if st != "yes":
		hud.show_menu("跟朋友玩", "這裡沒辦法連線",
			"要在 Claude 上打開這個遊戲頁面，而且朋友也要能打開同一個頁面（分享給他們）。", [["mp_back", "返回", true]])
		return
	if net.kind() == "peer":
		hud.show_menu("跟朋友玩", "一起漂流",
			"一個人按「開房間」，會拿到一個四位數房號；把房號告訴朋友，朋友打開這個遊戲網址，按「跟朋友玩」→「輸入房號」。\n大家在同一片海、同一艘木筏上：木筏、鯊魚、天氣跟著房主，背包每人各一個。",
			[["mp_host", "開房間", true], ["mp_code", "輸入房號加入", false], ["mp_back", "返回", false]])
		return
	var body := "一個人開房間，朋友打開同一個遊戲頁面、按「跟朋友玩」就會看到房間。\n大家在同一片海、同一艘木筏上：木筏、鯊魚、天氣跟著房主，背包每人各一個。"
	var bts := [["mp_host", "開房間", true]]
	if net.rooms.is_empty():
		body += "\n\n現在還沒有人開房間。"
	for r in net.rooms:
		bts.append(["mp_join_" + str(r.code), "加入 %s 的房間" % r.name, false])
	bts.append(["mp_back", "返回", false])
	hud.show_menu("跟朋友玩", "一起漂流", body, bts)


## Web page screen state: {"can": fullscreen possible, "full", "standalone" (home-screen app), "ios"}.
func _screen() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	if _screen_cache.is_empty():
		var v = JSON.parse_string(str(JavaScriptBridge.eval("window.MWNet ? MWNet.screen() : '{}'", true)))
		_screen_cache = v if typeof(v) == TYPE_DICTIONARY else {"none": true}
	return _screen_cache


## A number pad for the room code (phones have no keyboard in the game).
func _show_code_menu() -> void:
	var shown := ""
	for i in 4:
		shown += (_code_entry[i] if i < _code_entry.length() else "＿") + " "
	var bts := []
	for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]:
		bts.append(["code_" + d, d, false])
	bts.append(["code_del", "刪除", false])
	bts.append(["code_go", "加入", _code_entry.length() == 4])
	bts.append(["mp", "返回", false])
	hud.show_menu("輸入朋友的房號", shown.strip_edges(), "房主畫面左上角會寫「房間 ____」。", bts)


## The host's room code had to change (someone else had it).
func net_code_changed() -> void:
	hud.toast("房號改成 %s 了，告訴朋友這個號碼" % net.code)


func _leave_room() -> void:
	var was_host: bool = net.is_host()
	if was_host:
		_save_game()
	net.leave()
	_close_sheet()
	if was_host:
		hud.toast("房間關掉了，你可以繼續自己玩")
	else:
		_reset()
		_show_start()


## Rooms in the lobby changed: refresh the list if it is on screen.
func net_rooms_changed() -> void:
	if _mp_menu and hud.menu.visible and not net.in_room():
		_show_mp_menu()


func net_failed(code: String) -> void:
	var msg := "連線失敗（%s），等一下再試。" % code
	match code:
		"not_permitted":
			msg = "沒有權限連線：請分享這個遊戲給你的人把你的權限調高（不能只有「檢視」）。"
		"no_room":
			msg = "找不到房號 %s 的房間：確認號碼，或房主還開著遊戲嗎？" % net.code
		"network":
			msg = "連不上連線伺服器，檢查一下網路再試。"
	if net.is_client() and not net.synced:
		net.leave()
		hud.show_menu("跟朋友玩", "連不上", msg, [["mp", "返回", true]])
	else:
		hud.toast(msg)


func net_host_left() -> void:
	net.leave()
	_reset()
	_show_start()
	hud.toast("房主離開了，房間關掉了")


func net_config() -> Dictionary:
	return {"mode": mode, "creative": creative, "shark_on": shark_on, "game_t": game_t}


## The first full world from the host arrived: start a fresh castaway in it.
func net_begin_client(cfg: Dictionary) -> void:
	mode = str(cfg.get("mode", "standard"))
	creative = bool(cfg.get("creative", false))
	shark_on = bool(cfg.get("shark_on", true))
	_reset()
	for d in debris:
		d.node.queue_free()
	debris.clear()
	game_t = float(cfg.get("game_t", 0.0))
	_nt_have = false
	_mp_menu = false
	hud.hide_menu()
	paused = false
	hud.toast("加入 %s 的房間了！一起活下去吧" % net.host_name())


func _cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _key_cell(k: String) -> Vector2i:
	var p := k.substr(2).split(",")
	return Vector2i(int(p[0]), int(p[1]))


func _obj_entry(o: Dictionary) -> Dictionary:
	var e := {"kind": o.kind, "x": o.tile.cell.x, "y": o.tile.cell.y}
	if Farm.is_farm(o.kind):
		farm.save_state(o, e)
	else:
		for k in ["fuel", "water", "prog", "done", "up"]:
			if o.has(k):
				e[k] = o[k]
	if o.has("slots"):
		e["slots"] = o.slots.duplicate(true)
	return e


func _apply_obj(o: Dictionary, e: Dictionary) -> void:
	if Farm.is_farm(o.kind):
		farm.load_state(o, e)
		return
	for k in ["fuel", "prog"]:
		if e.has(k):
			o[k] = float(e[k])
	if e.has("water"):
		o["water"] = int(e.water)
	if e.has("up"):
		o["up"] = bool(e.up)
	if o.kind == "grill":
		var dn = e.get("done", {})
		o["done"] = {"cooked": int(dn)} if typeof(dn) != TYPE_DICTIONARY else {}
		if typeof(dn) == TYPE_DICTIONARY:
			for dk in dn:
				o.done[dk] = int(dn[dk])
		if o.done.get("cooked", 1) == 0:
			o.done.erase("cooked")
		o["slots"] = []
		for sl in e.get("slots", []):
			o.slots.append([float(sl), "rawfish"] if typeof(sl) != TYPE_ARRAY else [float(sl[0]), str(sl[1])])


## Round the floats a network copy carries, so slow timers don't change the text every frame.
func _quant(v):
	match typeof(v):
		TYPE_FLOAT:
			return snappedf(v, 0.02) if absf(v) <= 1.0 else snappedf(v, 0.5)
		TYPE_ARRAY:
			return (v as Array).map(func(x): return _quant(x))
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _quant(v[k])
			return out
	return v


## The shared world as separate pieces (key -> plain JSON value). net.gd diffs these.
func world_entities() -> Dictionary:
	var e := {}
	for t in tiles.values():
		e["t:" + _cell_key(t.cell)] = t.hp
	for o in objs:
		e["o:" + _cell_key(o.tile.cell)] = _quant(_obj_entry(o))
	e["sh"] = shelter.save_state()
	var il := []
	for isl in islands:
		var nodes := []
		for n in isl.nodes:
			nodes.append(ceili(n.cd / 5.0) if n.kind == "tree" else (1 if n.used else 0))
		il.append([1 if isl.visited else 0, nodes])
	e["is"] = il
	var sb := []
	for n in seabed_nodes:
		sb.append((1 if n.used else 0) if n.kind == "wreck" else ceili(n.cd / 5.0))
	e["sb"] = sb
	e["tr"] = traders.net_state()
	e["pe"] = _quant(companions.save_state())
	return e


## Apply pieces of the world from the network. full = this is the whole world: drop anything else.
func apply_entities(e: Dictionary, full: bool) -> void:
	var gone := []
	var keep_t := {}
	for k in e:
		if not str(k).begins_with("t:"):
			continue
		var c := _key_cell(k)
		if e[k] == null:
			gone.append(c)
			continue
		keep_t[c] = true
		if not tiles.has(c):
			_add_tile(c)
		var hp := int(e[k])
		if tiles[c].hp != hp:
			if hp < tiles[c].hp:
				tiles[c].shake = 0.35
			tiles[c].hp = hp
			_tint(tiles[c])
	if full:
		for c in tiles.keys():
			if not keep_t.has(c):
				gone.append(c)
	var keep_o := {}
	for k in e:
		if not str(k).begins_with("o:"):
			continue
		var c := _key_cell(k)
		var cur = tiles[c].obj if tiles.has(c) else null
		if e[k] == null or typeof(e[k]) != TYPE_DICTIONARY:
			if cur != null:
				_remove_obj(cur)
			continue
		keep_o[c] = true
		var kind := str(e[k].get("kind", ""))
		if not tiles.has(c) or not OBJ_NAME.has(kind):
			continue
		if cur != null and cur.kind != kind:
			_remove_obj(cur)
			cur = null
		if cur == null:
			_place(kind, tiles[c])
			cur = tiles[c].obj
		_apply_obj(cur, e[k])
	if full:
		for o in objs.duplicate():
			if not keep_o.has(o.tile.cell):
				_remove_obj(o)
	for c in gone:
		if tiles.has(c) and tiles.size() > 1:
			_remove_tile(tiles[c], true)
	if e.has("sh") and typeof(e.sh) == TYPE_DICTIONARY:
		shelter.load_state(e.sh)
	if e.has("is") and typeof(e["is"]) == TYPE_ARRAY:
		var il: Array = e["is"]
		for i in mini(islands.size(), il.size()):
			var isl: Dictionary = islands[i]
			var st: Array = il[i]
			if int(st[0]) == 1 and not isl.visited:
				isl.visited = true
				if is_client():
					S["islands"] += 1
					hud.toast("發現小島！點棕櫚樹和木箱搜刮")
			var ns: Array = st[1]
			for j in mini(isl.nodes.size(), ns.size()):
				var n: Dictionary = isl.nodes[j]
				var v := int(ns[j])
				if n.kind == "tree":
					if ceili(n.cd / 5.0) != v:
						n.cd = v * 5.0
					n.nuts.visible = n.cd <= 0.0
				else:
					n.used = v == 1
					n.node.visible = not n.used
	if e.has("sb") and typeof(e.sb) == TYPE_ARRAY:
		var sb: Array = e.sb
		for i in mini(seabed_nodes.size(), sb.size()):
			var n: Dictionary = seabed_nodes[i]
			var v := int(sb[i])
			if n.kind == "wreck":
				n.used = v == 1
				n.node.visible = not n.used
			else:
				if ceili(n.cd / 5.0) != v:
					n.cd = v * 5.0
				n.node.visible = n.cd <= 0.0
	if e.has("tr") and typeof(e.tr) == TYPE_DICTIONARY:
		traders.net_load(e.tr)
	if e.has("pe") and typeof(e.pe) == TYPE_DICTIONARY:
		companions.net_load(e.pe)
	_after_shelter_change()
	if build_mode != "":
		_refresh_ghosts()
	_update_mask()
	_refresh_inv()


## My castaway, for the others: [swimming, x, y, z, yaw, moving, pose, pitch, level].
func net_pose() -> Array:
	var pose := ""
	if swim != null:
		pose = "swim" if swim.moving else "tread"
	elif steer != null:
		pose = "steer"
	elif fishing != null:
		pose = "fish_bite" if fishing.phase == "bite" else "fish"
	elif hook != null:
		pose = "hook_out" if hook.phase == "out" else "hook_reel"
	var p := player.position
	var moving: bool = P["moving"] or (swim != null and swim.moving)
	return [1 if swim != null else 0, snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(player.rotation.y, 0.01),
		1 if moving else 0, pose, snappedf(player.rotation.x, 0.01), int(P["level"])]


## Host: the fast-moving world, sent ten times a second.
func net_fast() -> Dictionary:
	var dl := []
	for d in debris:
		if d.type == "bag" or not d.state in ["drift", "hooked"]:
			continue
		if not d.has("nid"):
			_nid += 1
			d["nid"] = _nid
		dl.append([d.nid, d.type, snappedf(d.x, 0.05), snappedf(d.z, 0.05)])
		if dl.size() >= 45:
			break
	return {
		"r": [snappedf(raft_pos.x, 0.01), snappedf(raft_pos.y, 0.01), snappedf(heading, 0.001), snappedf(raft_vel.x, 0.01), snappedf(raft_vel.y, 0.01)],
		"t": snappedf(game_t, 0.1),
		"wx": weather.net_state(),
		"sk": [snappedf(shark.x, 0.02), snappedf(shark.z, 0.02), snappedf(shark.head, 0.01), snappedf(shark.dep, 0.01), snappedf(shark.pitch, 0.01),
			snappedf(shark.jaw, 0.01), shark.state, 1 if shark.flash > 0.0 else 0, str(shark.get("tpeer", "")), 1 if shark_on else 0],
		"d": dl,
		"tb": traders.net_fast(),
		"pt": companions.net_fast(),
	}


## Client: take the host's fast world (smoothed in _net_client_tick).
func net_apply_fast(w: Dictionary) -> void:
	var r = w.get("r", [])
	if typeof(r) == TYPE_ARRAY and r.size() >= 5:
		_nt_raft = Vector2(float(r[0]), float(r[1]))
		_nt_vel = Vector2(float(r[3]), float(r[4]))
		raft_vel = _nt_vel
		_nt_heading = float(r[2])
		if not _nt_have:
			_nt_have = true
			raft_pos = _nt_raft
			heading = _nt_heading
	if w.has("t"):
		var ht := float(w.t)
		game_t = ht if absf(game_t - ht) > 3.0 else lerpf(game_t, ht, 0.2)
	if typeof(w.get("wx")) == TYPE_ARRAY:
		weather.net_apply(w.wx)
	var sk = w.get("sk", [])
	if typeof(sk) == TYPE_ARRAY and sk.size() >= 10:
		_nt_shark = sk
		shark.state = str(sk[6])
		if int(sk[7]) == 1:
			shark.flash = maxf(shark.flash, 0.12)
		shark["tpeer"] = str(sk[8])
		shark_on = int(sk[9]) == 1
	var have := {}
	for d in debris:
		if d.has("nid"):
			have[int(d.nid)] = d
	var seen := {}
	for it in w.get("d", []):
		if typeof(it) != TYPE_ARRAY or it.size() < 4:
			continue
		var id := int(it[0])
		seen[id] = true
		if have.has(id):
			var d: Dictionary = have[id]
			d["tx"] = float(it[2])
			d["tz"] = float(it[3])
		else:
			var type := str(it[1])
			if not DEBRIS.has(type):
				continue
			var node := Models.cage() if type == "cage" else Models.debris(type)
			node.rotation.y = randf() * TAU
			add_child(node)
			debris.append({"node": node, "type": type, "x": float(it[2]), "z": float(it[3]), "tx": float(it[2]), "tz": float(it[3]),
				"seed": randf() * 10.0, "spin": randf_range(-0.3, 0.3), "state": "drift", "nid": id})
	for d in debris.duplicate():
		if d.has("nid") and not seen.has(int(d.nid)) and not d.get("claimed", false):
			d.node.queue_free()
			debris.erase(d)
	traders.net_apply(w.get("tb"))
	if typeof(w.get("pt")) == TYPE_DICTIONARY:
		companions.net_apply(w.pt)


## Client, every frame: glide the mirrored raft, shark, debris and pets toward the host's.
func _net_client_tick(dt: float, c: Dictionary) -> void:
	wind = ocean.wind + sin(game_t * 0.011) * 0.35 + sin(game_t * 0.027) * 0.15
	_nt_raft += _nt_vel * dt
	raft_pos = _nt_raft if raft_pos.distance_to(_nt_raft) > 8.0 else raft_pos.lerp(_nt_raft, minf(1.0, dt * 4.0))
	_steer_quiet -= dt
	if steer == null or _steer_quiet <= 0.0:
		heading = lerp_angle(heading, _nt_heading, minf(1.0, dt * 4.0))
	if _nt_shark.size() >= 10:
		var sk := _nt_shark
		shark.x = lerpf(shark.x, float(sk[0]), minf(1.0, dt * 8.0))
		shark.z = lerpf(shark.z, float(sk[1]), minf(1.0, dt * 8.0))
		shark.head = lerp_angle(shark.head, float(sk[2]), minf(1.0, dt * 8.0))
		shark.dep = lerpf(shark.dep, float(sk[3]), minf(1.0, dt * 8.0))
		shark.hpitch = float(sk[4])
		shark.jaw = lerpf(shark.jaw, float(sk[5]), minf(1.0, dt * 10.0))
		if shark.state != "bite":
			shark.pitch = lerpf(shark.pitch, shark.hpitch, minf(1.0, dt * 6.0))
	for d in debris.duplicate():
		if not d.has("nid"):
			continue
		if d.get("claimed", false):
			if hook == null or hook.d != d:
				d.node.queue_free()
				debris.erase(d)
				continue
		else:
			d.tx = float(d.tx) + CURRENT.x * dt
			d.tz = float(d.tz) + CURRENT.y * dt
			d.x = lerpf(d.x, d.tx, minf(1.0, dt * 6.0))
			d.z = lerpf(d.z, d.tz, minf(1.0, dt * 6.0))
		d.node.position = Vector3(d.x, ocean.height(d.x, d.z) + 0.06, d.z)
		d.node.rotation.y += d.spin * dt
	traders.net_tick(dt, c)
	companions.net_tick(dt)
	_update_mask()
	var speed := raft_vel.length()
	wake_t -= dt
	if speed > 0.5 and wake_t <= 0.0:
		wake_t = 0.35
		var back: Vector2 = raft_vel / speed * c.r
		ocean.ripple(c.x - back.x, c.z - back.y, minf(1.0, speed * 0.35))


## Client: the shark warning, from the mirrored shark.
func _net_shark_warn() -> void:
	match str(shark.state):
		"bite":
			hud.set_warn("鯊魚正在咬木筏！靠近點牠反擊" if inv["spear"] > 0 or inv["mspear"] > 0 else "鯊魚正在咬木筏！快做木矛")
		"approach":
			hud.set_warn("鯊魚靠近了")
		"hunt":
			if str(shark.get("tpeer", "")) == net.me:
				hud.set_warn("鯊魚在追你！")
			else:
				hud.set_warn("")
		_:
			hud.set_warn("")


## Host: who the shark should go after: {"peer" ("" = me), "pos"}, or {} if nobody is swimming.
func _shark_prey() -> Dictionary:
	var cands := []
	if swim != null:
		cands.append({"peer": "", "pos": swim.pos})
	cands.append_array(net.remote_swimmers())
	if cands.is_empty():
		return {}
	var cur := str(shark.get("tpeer", ""))
	for cd in cands:
		if cd.peer == cur and shark.state == "hunt":
			return cd
	var best: Dictionary = cands[0]
	var bd := INF
	for cd in cands:
		var dd := Vector2(cd.pos.x - shark.x, cd.pos.z - shark.z).length()
		if dd < bd:
			bd = dd
			best = cd
	return best


## Host: a friend did something to the shared world.
func net_client_event(ev: Dictionary, peer: String) -> void:
	match str(ev.get("a", "")):
		"claim":
			var id := int(ev.get("id", -1))
			for d in debris:
				if d.has("nid") and int(d.nid) == id:
					if hook != null and hook.d == d:
						hook = null
						hook_ball.visible = false
					d.node.queue_free()
					debris.erase(d)
					break
		"shark_hit":
			_shark_hit(int(ev.get("dmg", 1)), peer)
		"heading":
			heading = float(ev.get("h", heading))


## Client: the host tells this player something happened to them.
func net_host_event(ev: Dictionary) -> void:
	match str(ev.get("e", "")):
		"hurt":
			var dmg := float(ev.get("dmg", 25.0))
			S["health"] -= dmg
			if swim != null:
				sfx.play("bite", swim.pos)
			else:
				sfx.play("bite")
			hud.toast("被鯊魚咬了一口！生命 -%d" % int(dmg))
		"closed":
			net_host_left()
		"repelled":
			S["repelled"] += 1
			hud.toast("鯊魚被你趕跑了！")
			_refresh_inv()
