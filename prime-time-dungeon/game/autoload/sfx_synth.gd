class_name SfxSynth extends RefCounted
## Procedural placeholder audio (02_TECH §3.8): AudioStreamWAV, 22050 Hz, 16 bit mono.
## SFX are short tone/noise sequences, music ids are 4–8 s loops (loop_end = frame count, see make_music()).
## Deterministic: noise uses a fixed-seed RNG.

const MIX_RATE: int = 22050
const SFX_IDS: PackedStringArray = ["ui_move", "ui_confirm", "ui_cancel", "ui_error", "step", "swing", "hit", "hit_crit",
	"hit_weak", "miss", "magic", "fire", "ice", "shock", "toxic", "light", "dark", "heal", "buff", "debuff", "ko", "defend",
	"flee", "stunt_success", "stunt_fail", "level_up", "chest_open", "coin", "lootbox_shake", "lootbox_open", "lootbox_rare",
	"sponsor", "achievement", "timer_warn", "stairs", "swirl", "door", "mod_blip", "chat_pop", "vending"]
const MUSIC_IDS: PackedStringArray = ["title", "explore", "battle", "boss", "safe_room", "victory", "game_over", "credits"]

## Tone: [wave, f0, f1, duration s, volume, start s (-1 = after previous)]. Waves: sin sq saw tri noise.
const SFX: Dictionary = {
	"ui_move": [["sq", 880.0, 880.0, 0.04, 0.18, -1.0]],
	"ui_confirm": [["sq", 660.0, 660.0, 0.05, 0.2, -1.0], ["sq", 990.0, 990.0, 0.08, 0.2, -1.0]],
	"ui_cancel": [["sq", 440.0, 300.0, 0.09, 0.2, -1.0]],
	"ui_error": [["sq", 180.0, 180.0, 0.07, 0.25, -1.0], ["sq", 150.0, 150.0, 0.1, 0.25, 0.1]],
	"step": [["noise", 600.0, 300.0, 0.05, 0.15, -1.0]],
	"swing": [["noise", 800.0, 3000.0, 0.16, 0.3, -1.0]],
	"hit": [["noise", 2000.0, 500.0, 0.08, 0.45, -1.0], ["sin", 140.0, 60.0, 0.12, 0.5, 0.0]],
	"hit_crit": [["noise", 3000.0, 600.0, 0.12, 0.5, -1.0], ["sq", 240.0, 90.0, 0.18, 0.35, 0.0],
		["sin", 1320.0, 1320.0, 0.08, 0.25, 0.02]],
	"hit_weak": [["tri", 320.0, 140.0, 0.14, 0.45, -1.0], ["noise", 2500.0, 800.0, 0.08, 0.3, 0.0]],
	"miss": [["sin", 640.0, 280.0, 0.14, 0.25, -1.0]],
	"magic": [["tri", 400.0, 1300.0, 0.32, 0.35, -1.0], ["sin", 800.0, 2000.0, 0.3, 0.15, 0.03]],
	"fire": [["noise", 1500.0, 400.0, 0.38, 0.4, -1.0], ["saw", 90.0, 70.0, 0.32, 0.25, 0.0]],
	"ice": [["sin", 1500.0, 2300.0, 0.26, 0.3, -1.0], ["tri", 2100.0, 2600.0, 0.2, 0.15, 0.05]],
	"shock": [["sq", 60.0, 90.0, 0.26, 0.3, -1.0], ["noise", 4000.0, 4000.0, 0.22, 0.25, 0.0]],
	"toxic": [["sin", 220.0, 140.0, 0.32, 0.4, -1.0], ["noise", 500.0, 300.0, 0.2, 0.15, 0.08]],
	"light": [["sin", 880.0, 1760.0, 0.3, 0.3, -1.0], ["tri", 1320.0, 2640.0, 0.25, 0.12, 0.04]],
	"dark": [["saw", 110.0, 55.0, 0.36, 0.35, -1.0], ["noise", 300.0, 200.0, 0.3, 0.12, 0.0]],
	"heal": [["sin", 523.0, 523.0, 0.1, 0.3, -1.0], ["sin", 659.0, 659.0, 0.1, 0.3, -1.0], ["sin", 784.0, 784.0, 0.16, 0.3, -1.0]],
	"buff": [["tri", 440.0, 880.0, 0.26, 0.35, -1.0]],
	"debuff": [["tri", 880.0, 420.0, 0.26, 0.35, -1.0]],
	"ko": [["sq", 320.0, 55.0, 0.42, 0.3, -1.0], ["noise", 800.0, 200.0, 0.2, 0.2, 0.0]],
	"defend": [["sq", 200.0, 200.0, 0.06, 0.25, -1.0], ["noise", 3000.0, 3000.0, 0.05, 0.2, 0.0]],
	"flee": [["noise", 400.0, 2000.0, 0.3, 0.25, -1.0], ["sin", 800.0, 380.0, 0.3, 0.2, 0.0]],
	"stunt_success": [["sq", 523.0, 523.0, 0.08, 0.25, -1.0], ["sq", 659.0, 659.0, 0.08, 0.25, -1.0],
		["sq", 784.0, 784.0, 0.08, 0.25, -1.0], ["sq", 1046.0, 1046.0, 0.2, 0.25, -1.0]],
	"stunt_fail": [["saw", 300.0, 90.0, 0.42, 0.3, -1.0]],
	"level_up": [["sq", 523.0, 523.0, 0.07, 0.22, -1.0], ["sq", 659.0, 659.0, 0.07, 0.22, -1.0],
		["sq", 784.0, 784.0, 0.07, 0.22, -1.0], ["sq", 1046.0, 1046.0, 0.07, 0.22, -1.0], ["sq", 1318.0, 1318.0, 0.24, 0.22, -1.0]],
	"chest_open": [["tri", 300.0, 620.0, 0.16, 0.35, -1.0], ["sin", 1200.0, 1200.0, 0.22, 0.2, -1.0]],
	"coin": [["sq", 988.0, 988.0, 0.05, 0.2, -1.0], ["sq", 1318.0, 1318.0, 0.16, 0.2, -1.0]],
	"lootbox_shake": [["noise", 1200.0, 800.0, 0.05, 0.3, -1.0], ["noise", 1200.0, 800.0, 0.05, 0.3, 0.09],
		["noise", 1200.0, 800.0, 0.05, 0.3, 0.18]],
	"lootbox_open": [["sin", 400.0, 1600.0, 0.4, 0.3, -1.0], ["noise", 3000.0, 1000.0, 0.15, 0.15, 0.3]],
	"lootbox_rare": [["tri", 784.0, 784.0, 0.08, 0.25, -1.0], ["tri", 988.0, 988.0, 0.08, 0.25, -1.0],
		["tri", 1175.0, 1175.0, 0.08, 0.25, -1.0], ["tri", 1568.0, 1568.0, 0.3, 0.25, -1.0]],
	"sponsor": [["sq", 784.0, 784.0, 0.09, 0.22, -1.0], ["sq", 988.0, 988.0, 0.09, 0.22, -1.0],
		["sq", 784.0, 784.0, 0.09, 0.22, -1.0], ["sq", 1175.0, 1175.0, 0.2, 0.22, -1.0]],
	"achievement": [["tri", 659.0, 659.0, 0.08, 0.3, -1.0], ["tri", 784.0, 784.0, 0.08, 0.3, -1.0],
		["tri", 1046.0, 1046.0, 0.08, 0.3, -1.0], ["tri", 1318.0, 1318.0, 0.25, 0.3, -1.0]],
	"timer_warn": [["sq", 1000.0, 1000.0, 0.1, 0.25, -1.0], ["sq", 1000.0, 1000.0, 0.1, 0.25, 0.18]],
	"stairs": [["sin", 600.0, 200.0, 0.5, 0.3, -1.0], ["tri", 300.0, 100.0, 0.5, 0.15, 0.05]],
	"swirl": [["noise", 300.0, 4000.0, 0.6, 0.2, -1.0], ["sin", 200.0, 1200.0, 0.6, 0.25, 0.0]],
	"door": [["noise", 500.0, 200.0, 0.16, 0.3, -1.0], ["sin", 90.0, 70.0, 0.2, 0.3, 0.0]],
	"mod_blip": [["sin", 1200.0, 1200.0, 0.03, 0.15, -1.0]],
	"chat_pop": [["sin", 900.0, 1100.0, 0.04, 0.15, -1.0]],
	"vending": [["sq", 300.0, 300.0, 0.1, 0.2, -1.0], ["noise", 900.0, 600.0, 0.12, 0.2, -1.0],
		["sq", 988.0, 988.0, 0.05, 0.18, -1.0], ["sq", 1318.0, 1318.0, 0.12, 0.18, -1.0]],
}

## Music loops: bpm, bars (4/4), root (MIDI), minor, bass (scale degree per beat, -99 rest),
## lead (scale degree per 8th, -99 rest), lead wave, drums.
const MUSIC: Dictionary = {
	"title": {"bpm": 120, "bars": 2, "root": 45, "minor": true, "bass": [0, 0, 5, 5, 3, 3, 4, 4],
		"lead": [7, 9, 10, 9, 7, 5, 7, -99, 12, 10, 9, 7, 5, 4, 2, -99], "lw": "sq", "drums": true},
	"explore": {"bpm": 100, "bars": 2, "root": 43, "minor": true, "bass": [0, -99, 0, 3, 5, -99, 4, 3],
		"lead": [7, -99, 9, -99, 10, 9, 7, -99, 5, -99, 7, -99, 4, -99, 2, -99], "lw": "tri", "drums": true},
	"battle": {"bpm": 150, "bars": 4, "root": 40, "minor": true,
		"bass": [0, 0, 0, 0, 5, 5, 5, 5, 3, 3, 3, 3, 4, 4, 6, 6],
		"lead": [7, 7, 9, 10, 9, 7, 9, 5, 7, 7, 9, 10, 12, 10, 9, 7, 10, 10, 9, 7, 9, 10, 12, 14, 11, 9, 7, 6, 7, 9, 11, -99],
		"lw": "sq", "drums": true},
	"boss": {"bpm": 160, "bars": 4, "root": 38, "minor": true,
		"bass": [0, 0, 1, 0, 0, 0, 1, 0, 5, 5, 6, 5, 3, 3, 4, 6],
		"lead": [7, 8, 7, 6, 7, -99, 10, 8, 7, 8, 7, 6, 7, -99, 12, 11, 12, 13, 12, 10, 8, 7, 8, 10, 11, 10, 8, 7, 6, 4, 6, -99],
		"lw": "saw", "drums": true},
	"safe_room": {"bpm": 80, "bars": 2, "root": 48, "minor": false, "bass": [0, -99, 4, -99, 5, -99, 3, 4],
		"lead": [4, -99, 7, 9, 7, -99, 4, -99, 5, -99, 4, 2, 4, -99, -99, -99], "lw": "sin", "drums": false},
	"victory": {"bpm": 120, "bars": 2, "root": 48, "minor": false, "bass": [0, 0, 3, 3, 4, 4, 0, 0],
		"lead": [7, 7, 9, 11, 14, -99, 11, 14, 12, 11, 9, 11, 7, -99, 7, -99], "lw": "sq", "drums": true},
	"game_over": {"bpm": 70, "bars": 2, "root": 45, "minor": true, "bass": [0, -99, 5, -99, 3, -99, 4, -99],
		"lead": [7, -99, 6, -99, 5, -99, 4, -99, 3, -99, 2, -99, 0, -99, -99, -99], "lw": "tri", "drums": false},
	"credits": {"bpm": 110, "bars": 2, "root": 48, "minor": false, "bass": [0, 0, 5, 5, 3, 3, 4, 4],
		"lead": [9, 7, 9, 11, 12, -99, 11, 9, 7, 9, 7, 4, 7, -99, -99, -99], "lw": "tri", "drums": true},
}
const WAVES: PackedStringArray = ["sin", "sq", "saw", "tri", "noise"]
const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]


## SFX stream for `id`; null for unknown ids.
static func make(id: StringName) -> AudioStreamWAV:
	var key: String = String(id)
	if not SFX.has(key):
		return null
	var tones: Array = SFX[key]
	var total: float = 0.0
	var cursor: float = 0.0
	for t: Array in tones:
		var start: float = cursor if float(t[5]) < 0.0 else float(t[5])
		cursor = start + float(t[3])
		total = maxf(total, cursor)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(int(total * MIX_RATE) + 64)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key.hash()
	cursor = 0.0
	for t: Array in tones:
		var start: float = cursor if float(t[5]) < 0.0 else float(t[5])
		_add_tone(buf, int(start * MIX_RATE), str(t[0]), float(t[1]), float(t[2]), float(t[3]), float(t[4]), 0.005,
			0.04, rng)
		cursor = start + float(t[3])
	return _to_wav(buf, false)


## Looping music stream for `id`; null for unknown ids. loop_mode LOOP_FORWARD, loop_begin 0, loop_end = frames.
static func make_music(id: StringName) -> AudioStreamWAV:
	var key: String = String(id)
	if not MUSIC.has(key):
		return null
	var m: Dictionary = MUSIC[key]
	var beat: float = 60.0 / float(m["bpm"])
	var frames: int = int(round(float(m["bars"]) * 4.0 * beat * MIX_RATE))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(frames)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key.hash()
	var scale: Array[int] = MINOR if bool(m["minor"]) else MAJOR
	var root: int = int(m["root"])
	var bass: Array = m["bass"]
	var beats: int = int(m["bars"]) * 4
	for b in beats:
		var deg: int = int(bass[b % bass.size()])
		if deg <= -99:
			continue
		_add_tone(buf, int(b * beat * MIX_RATE), "tri", _freq(root, scale, deg), _freq(root, scale, deg), beat * 0.9, 0.32,
			0.01, beat * 0.3, rng)
	var lead: Array = m["lead"]
	var eighths: int = beats * 2
	for e in eighths:
		var deg2: int = int(lead[e % lead.size()])
		if deg2 <= -99:
			continue
		var f: float = _freq(root + 12, scale, deg2)
		_add_tone(buf, int(e * beat * 0.5 * MIX_RATE), str(m["lw"]), f, f, beat * 0.45, 0.16, 0.005, beat * 0.15, rng)
	if bool(m["drums"]):
		for b in beats:
			var at: int = int(b * beat * MIX_RATE)
			if b % 2 == 0:
				_add_tone(buf, at, "sin", 130.0, 40.0, 0.14, 0.45, 0.002, 0.06, rng)
			else:
				_add_tone(buf, at, "noise", 2500.0, 1500.0, 0.1, 0.18, 0.002, 0.05, rng)
			_add_tone(buf, at + int(beat * 0.5 * MIX_RATE), "noise", 6000.0, 6000.0, 0.03, 0.06, 0.001, 0.02, rng)
	return _to_wav(buf, true)


static func _freq(root: int, scale: Array[int], degree: int) -> float:
	var octave: int = floori(degree / 7.0)
	var idx: int = degree - octave * 7
	var midi: int = root + octave * 12 + scale[idx]
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Mixes one tone into `buf` (clipped at the buffer end).
static func _add_tone(buf: PackedFloat32Array, start: int, wave: String, f0: float, f1: float, dur: float, vol: float,
		attack: float, release: float, rng: RandomNumberGenerator) -> void:
	var n: int = int(dur * MIX_RATE)
	var phase: float = 0.0
	var hold: float = 0.0
	var hold_left: int = 0
	var size: int = buf.size()
	var w: int = WAVES.find(wave)
	for i in n:
		var idx: int = start + i
		if idx >= size:
			break
		var t: float = float(i) / MIX_RATE
		var f: float = f0 + (f1 - f0) * (float(i) / float(n))
		phase += f / MIX_RATE
		phase -= floorf(phase)
		var s: float = 0.0
		match w:
			0:
				s = sin(phase * TAU)
			1:
				s = 1.0 if phase < 0.5 else -1.0
			2:
				s = phase * 2.0 - 1.0
			3:
				s = 4.0 * absf(phase - 0.5) - 1.0
			4:
				# sample & hold noise: f controls the "pitch" of the noise
				if hold_left <= 0:
					hold = rng.randf_range(-1.0, 1.0)
					hold_left = maxi(1, int(MIX_RATE / maxf(f, 1.0)))
				hold_left -= 1
				s = hold
		var env: float = minf(1.0, t / maxf(attack, 0.0001)) * minf(1.0, (dur - t) / maxf(release, 0.0001))
		buf[idx] += s * vol * env


static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = bytes.size() / 2   # 16 bit mono = frame count (without it the stream stops at once, §3.8)
	return wav
