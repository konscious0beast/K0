extends Node
## The duel's sounds (10 §4.9): the procedural Stempelduell section of SfxSynth (make_sd / make_sd_music) on the
## buses of the Sfx autoload (SFX, Music — the player's volume settings apply). Sfx.play only knows the campaign ids,
## so this node owns a small player pool and the waiting-room loop (the title music fades out while it runs and comes
## back with the title). Every sound has a visible counterpart on the table (10 §4.8: gong ↔ the ticket lights up).

const POOL: int = 4

var muted: bool = false
var played: PackedStringArray = []                 # every sound id played (tests)

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer = null
var _music_id: StringName = &""
static var _cache: Dictionary = {}                 # synthesized once per session, shared by the hall and the table


func _ready() -> void:
	for i in POOL:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Sd%d" % i
		p.bus = Sfx.BUS_SFX
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.name = "SdMusic"
	_music.bus = Sfx.BUS_MUSIC
	add_child(_music)


func play(id: StringName, pitch: float = 1.0) -> void:
	played.append(String(id))
	if muted or _pool.is_empty():
		return
	var s: AudioStreamWAV = _stream(id, false)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = pitch
	p.play()


## The waiting-room loop (&"sd_wartezimmer"; &"sd_wartezimmer_eilig" from the Stempelmeister's phase 2); &"" stops.
func music(id: StringName) -> void:
	if id == _music_id or _music == null:
		return
	_music_id = id
	if id == &"" or muted:
		_music.stop()
		return
	Sfx.music(&"", 0.4)                            # the title / campaign music fades out
	var s: AudioStreamWAV = _stream(id, true)
	if s == null:
		return
	_music.stream = s
	_music.volume_db = -6.0
	_music.play()


func current_music() -> StringName:
	return _music_id


func stop_all() -> void:
	for p: AudioStreamPlayer in _pool:
		p.stop()
	if _music != null:
		_music.stop()
	_music_id = &""


func _exit_tree() -> void:
	stop_all()


## Closing the window quits at once (auto-accept): stop and give the mix thread the Sfx autoload's drain time, so no
## playback is still registered when the AudioServer goes ("ObjectDB instances were leaked at exit", 02_TECH §3.8 —
## the Sfx drain only covers its own players).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _busy():
		stop_all()
		OS.delay_msec(Sfx.SHUTDOWN_DRAIN_MS)


func _busy() -> bool:
	if _music != null and _music.playing:
		return true
	for p: AudioStreamPlayer in _pool:
		if p.playing:
			return true
	return false


func _stream(id: StringName, loop: bool) -> AudioStreamWAV:
	var key: String = ("m:" if loop else "s:") + String(id)
	if not _cache.has(key):
		_cache[key] = SfxSynth.make_sd_music(id) if loop else SfxSynth.make_sd(id)
	return _cache[key] as AudioStreamWAV
