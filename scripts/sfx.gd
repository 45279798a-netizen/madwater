class_name Sfx
extends Node
## Sound: looping ambience (sea, wind, fire) plus a pool of one-shot players.
## Clips are synthesised by tools/gen_audio.py into res://audio/.

const ONE_SHOTS := ["splash", "splash_small", "whoosh", "pickup", "bite", "craft", "build",
	"drink", "eat", "reel", "catch", "shark_alert", "fail", "thunder"]

var listener := Vector3.ZERO
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ocean: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _lp_idx := -1
var _under := false


func _ready() -> void:
	for n in ONE_SHOTS:
		_streams[n] = load("res://audio/%s.wav" % n)
	_ocean = _loop("ocean_loop", -9.0)
	_wind = _loop("wind_loop", -80.0)
	_fire = _loop("fire_loop", -80.0)
	_rain = _loop("rain_loop", -80.0)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 650.0
	AudioServer.add_bus_effect(0, lp)
	_lp_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _lp_idx, false)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _loop(clip: String, db: float) -> AudioStreamPlayer:
	var s: AudioStreamWAV = (load("res://audio/%s.wav" % clip) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	p.play()
	return p


## Play a clip; when `at` is given the volume falls off with distance from the listener.
func play(clip: String, at = null, db := 0.0, pitch_jitter := 0.08) -> void:
	if not _streams.has(clip):
		return
	var vol := db
	if at is Vector3:
		vol -= clampf(listener.distance_to(at) * 0.7, 0.0, 30.0)
	if vol < -40.0:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[clip]
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## 0..1 loudness for the wind (sailing) and fire (nearby burning still or grill) loops.
func set_ambience(wind_k: float, fire_k: float, dt: float) -> void:
	_wind.volume_db = lerpf(_wind.volume_db, _to_db(wind_k) - 6.0, minf(1.0, dt * 2.0))
	_fire.volume_db = lerpf(_fire.volume_db, _to_db(fire_k) - 8.0, minf(1.0, dt * 4.0))


## Rain on the deck: 0 = dry, 1 = downpour.
func set_rain(k: float, dt: float) -> void:
	_rain.volume_db = lerpf(_rain.volume_db, _to_db(k) - 4.0, minf(1.0, dt * 1.5))


## Muffle everything while the camera is under water.
func set_underwater(on: bool) -> void:
	if on == _under or _lp_idx < 0:
		return
	_under = on
	AudioServer.set_bus_effect_enabled(0, _lp_idx, on)


func _exit_tree() -> void:
	if _lp_idx >= 0 and _lp_idx < AudioServer.get_bus_effect_count(0):
		AudioServer.remove_bus_effect(0, _lp_idx)


func _to_db(k: float) -> float:
	return linear_to_db(maxf(k, 0.0001))
