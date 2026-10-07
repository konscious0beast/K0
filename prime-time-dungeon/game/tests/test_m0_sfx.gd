extends TestCase
## Sfx / SfxSynth (02_TECH §3.8): buses, every id builds, music loops keep playing (loop_end), unknown ids never crash.


func test_buses_exist() -> void:
	for bus: StringName in [Sfx.BUS_MUSIC, Sfx.BUS_SFX, Sfx.BUS_UI]:
		var idx: int = AudioServer.get_bus_index(bus)
		assert_ne(idx, -1, "bus %s" % bus)
		if idx != -1:
			assert_eq(AudioServer.get_bus_send(idx), &"Master")


func test_music_loop_settings() -> void:
	var wav: AudioStreamWAV = SfxSynth.make_music(&"explore")
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, 22050)
	assert_false(wav.stereo)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(wav.loop_begin, 0)
	assert_eq(wav.loop_end, wav.data.size() / 2, "loop_end = frame count (16 bit mono)")
	assert_between(wav.get_length(), 4.0, 8.0, "loop length 4–8 s")


func test_every_music_id_builds_a_loop() -> void:
	for id: String in SfxSynth.MUSIC_IDS:
		var wav: AudioStreamWAV = SfxSynth.make_music(StringName(id))
		assert_not_null(wav, "music " + id)
		if wav != null:
			assert_eq(wav.loop_end, wav.data.size() / 2, "loop_end " + id)
			assert_between(wav.get_length(), 4.0, 8.0, "length " + id)


func test_every_sfx_id_builds() -> void:
	assert_len(SfxSynth.SFX_IDS, 40)
	for id: String in SfxSynth.SFX_IDS:
		var wav: AudioStreamWAV = SfxSynth.make(StringName(id))
		assert_not_null(wav, "sfx " + id)
		if wav != null:
			assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "sfx do not loop: " + id)
			assert_between(wav.get_length(), 0.02, 1.5, "length " + id)


func test_music_keeps_playing_after_stream_end() -> void:
	# Pflichttest §3.8: player with make_music(&"explore") in the tree, still playing after 1.5 × stream length.
	# pitch_scale 4 shortens the real time (same loop semantics: a non-looping stream would stop after length / 4).
	var wav: AudioStreamWAV = SfxSynth.make_music(&"explore")
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = wav
	p.pitch_scale = 4.0
	p.volume_db = -80.0
	add_to_tree(p)
	p.play()
	var wait_ms: int = int(wav.get_length() / p.pitch_scale * 1.5 * 1000.0)
	var deadline: int = Time.get_ticks_msec() + wait_ms
	var reached: bool = await wait_until(func() -> bool: return Time.get_ticks_msec() >= deadline, 5000)
	assert_true(reached)
	assert_true(p.playing, "looping music still playing after 1.5 × length")
	p.stop()
	await wait_frames(3)


func test_non_looping_stream_stops_control() -> void:
	# Control experiment for the loop test: an SFX (no loop) stops by itself.
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = SfxSynth.make(&"coin")
	p.volume_db = -80.0
	add_to_tree(p)
	p.play()
	var stopped: bool = await wait_until(func() -> bool: return not p.playing, 3000)
	assert_true(stopped, "non-looping stream ends")


func test_unknown_ids_do_not_crash() -> void:
	assert_null(SfxSynth.make(&"does_not_exist"))
	assert_null(SfxSynth.make_music(&"does_not_exist"))
	Sfx.play(&"does_not_exist")
	Sfx.play(&"does_not_exist")
	Sfx.play_ui(&"does_not_exist")
	Sfx.music(&"does_not_exist")
	assert_eq(Sfx.current_music(), &"")
	Sfx.set_volume(&"NoSuchBus", 0.5)
	assert_eq(Sfx.get_volume(&"NoSuchBus"), 0.0)


func test_play_and_music_api() -> void:
	Sfx.play(&"hit")
	Sfx.play_ui(&"ui_confirm")
	Sfx.music(&"title", 0.0)
	assert_eq(Sfx.current_music(), &"title")
	Sfx.music(&"battle", 0.05)
	assert_eq(Sfx.current_music(), &"battle")
	Sfx.music(&"", 0.0)
	assert_eq(Sfx.current_music(), &"")
	await wait_frames(30)


func test_volume_roundtrip() -> void:
	var before: float = Sfx.get_volume(Sfx.BUS_SFX)
	Sfx.set_volume(Sfx.BUS_SFX, 0.25)
	assert_almost(Sfx.get_volume(Sfx.BUS_SFX), 0.25)
	Sfx.set_volume(Sfx.BUS_SFX, 2.0)
	assert_almost(Sfx.get_volume(Sfx.BUS_SFX), 1.0, 0.0001, "clamped")
	Sfx.set_volume(Sfx.BUS_SFX, before)
	Sfx.set_volume(&"Master", Sfx.get_volume(&"Master"))
