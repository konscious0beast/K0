extends Node
## Autoload `Sfx` (02_TECH §3.8): audio buses, SFX player pool, music crossfade.
## Buses are created in _init() via AudioServer (no .tres). Streams are created lazily by SfxSynth and cached.
## Unknown ids warn once and never crash.

const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const POOL_SIZE: int = 12
const UI_POOL_SIZE: int = 4
const PITCH_JITTER: float = 0.04
const SILENT_DB: float = -60.0
## Exit drain (02_TECH §3.8): the AudioServer releases stopped playbacks on its mix thread one or two mix steps
## (≈ 10–25 ms each) later; 120 ms covers that with margin on a loaded machine.
const SHUTDOWN_DRAIN_MS: int = 120

var _pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _ui_next: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_id: StringName = &""
var _music_tween: Tween = null
var _cache: Dictionary = {}               # StringName → AudioStreamWAV
var _music_cache: Dictionary = {}
var _warned: Dictionary = {}
var _volumes: Dictionary = {}             # bus name → linear volume as set
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()   # presentation-only pitch jitter


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		_ensure_bus(bus)
	_rng.randomize()
	for i in POOL_SIZE:
		_pool.append(_make_player("Sfx%d" % i, BUS_SFX))
	for i in UI_POOL_SIZE:
		_ui_pool.append(_make_player("Ui%d" % i, BUS_UI))
	for i in 2:
		_music_players.append(_make_player("Music%d" % i, BUS_MUSIC))


## Sfx leaves the tree only when the process quits (it is the last autoload, so every screen has left before). The
## AudioServer is torn down right after the scene tree; a playback that is still registered then is never freed and
## Godot reports "ObjectDB instances were leaked at exit" (AudioStreamPlaybackWAV + its AudioStreamWAV, measured 4.7.2
## in tests and the autoplay smoke). So: stop everything and give the mix thread time to release the playbacks.
func _exit_tree() -> void:
	if stop_all():
		OS.delay_msec(SHUTDOWN_DRAIN_MS)


## Stops the music and every SFX/UI player at once (no fade). Returns true if any player had a playback.
func stop_all() -> bool:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	_music_id = &""
	var had: bool = false
	for p: AudioStreamPlayer in _pool + _ui_pool + _music_players:
		if is_instance_valid(p) and p.has_stream_playback():
			had = true
			p.stop()
	return had


func _make_player(node_name: String, bus: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, &"Master")


## SFX bus; ±4 % pitch jitter; pool of 12 players.
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _get_sfx(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.01, pitch * (1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)))
	p.play()


## UI bus, no jitter.
func play_ui(id: StringName) -> void:
	var stream: AudioStreamWAV = _get_sfx(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _ui_pool[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_pool.size()
	p.stream = stream
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.play()


## &"" stops; crossfade over 2 players. Same id → nothing.
func music(id: StringName, fade_sec: float = 0.8) -> void:
	if id == _music_id:
		return
	var old: AudioStreamPlayer = _music_players[_music_active]
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	var other: AudioStreamPlayer = _music_players[1 - _music_active]
	if other.playing:
		other.stop()
	if id == &"":
		_music_id = &""
		_fade_out_and_stop(old, fade_sec)
		return
	var stream: AudioStreamWAV = _get_music(id)
	if stream == null:
		return
	_music_id = id
	_music_active = 1 - _music_active
	var incoming: AudioStreamPlayer = _music_players[_music_active]
	incoming.stream = stream
	incoming.pitch_scale = 1.0
	if fade_sec <= 0.0 or not is_inside_tree():
		incoming.volume_db = 0.0
		incoming.play()
		old.stop()
		return
	incoming.volume_db = SILENT_DB
	incoming.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, fade_sec)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, fade_sec)
		_music_tween.chain().tween_callback(old.stop)


## Currently requested music id (&"" = none).
func current_music() -> StringName:
	return _music_id


## bus &"Master" allowed. linear 0..1.
func set_volume(bus: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		_warn_once("bus:" + String(bus), "[Sfx] unknown bus '%s'" % bus)
		return
	var v: float = clampf(linear, 0.0, 1.0)
	_volumes[bus] = v
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.0001)


func get_volume(bus: StringName) -> float:
	if _volumes.has(bus):
		return float(_volumes[bus])
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _fade_out_and_stop(p: AudioStreamPlayer, fade_sec: float) -> void:
	if not p.playing:
		return
	if fade_sec <= 0.0 or not is_inside_tree():
		p.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(p, "volume_db", SILENT_DB, fade_sec)
	_music_tween.tween_callback(p.stop)


func _get_sfx(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStreamWAV = SfxSynth.make(id)
	if stream == null:
		_warn_once("sfx:" + String(id), "[Sfx] unknown sfx id '%s'" % id)
		return null
	_cache[id] = stream
	return stream


func _get_music(id: StringName) -> AudioStreamWAV:
	if _music_cache.has(id):
		return _music_cache[id]
	var stream: AudioStreamWAV = SfxSynth.make_music(id)
	if stream == null:
		_warn_once("music:" + String(id), "[Sfx] unknown music id '%s'" % id)
		return null
	_music_cache[id] = stream
	return stream


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(msg)
