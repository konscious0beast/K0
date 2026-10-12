extends TestCase
## R3 settings (07 §7.6, §7.8, §12.1, §12.4): the section "Kampf" of the settings menu writes every GameSettings field
## of 07 §7.8 (Spieltempo 100/85/70 % "Zeitlupe", Kampf-Hinweise, Assist, Kamera folgt dem Ziel, Auto-Angriff, neues
## Ziel automatisch, Kontrast-Telegraphen, Kampftext-Größe, Kamerawackeln); in the real-time mode the CTB rows
## ("Kampftempo", "Auto-Kampf", "Partner automatisch") are hidden; CTB runs keep their menu (plus the debug-only
## "Kampfmodus" switch in debug builds).

const SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const RT_KEYS: PackedStringArray = ["combat_speed_pm", "combat_hints", "combat_assist", "combat_camera_assist",
	"auto_attack_default", "auto_retarget", "telegraph_contrast", "floating_text_scale", "camera_shake"]

var _saved: Dictionary = {}


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	var s: GameSettings = Game.settings
	_saved = {"speed": s.combat_speed_pm, "hints": s.combat_hints, "assist": s.combat_assist,
		"cam": s.combat_camera_assist, "auto": s.auto_attack_default, "retarget": s.auto_retarget,
		"contrast": s.telegraph_contrast, "scale": s.floating_text_scale, "shake": s.camera_shake,
		"mode": s.combat_mode}


func after_each() -> void:
	var s: GameSettings = Game.settings
	s.combat_speed_pm = int(_saved["speed"])
	s.combat_hints = bool(_saved["hints"])
	s.combat_assist = int(_saved["assist"])
	s.combat_camera_assist = int(_saved["cam"])
	s.auto_attack_default = bool(_saved["auto"])
	s.auto_retarget = bool(_saved["retarget"])
	s.telegraph_contrast = _saved["contrast"] as StringName
	s.floating_text_scale = int(_saved["scale"])
	s.camera_shake = bool(_saved["shake"])
	s.combat_mode = _saved["mode"] as StringName
	Game.apply_settings()


## The settings page as the pause menu embeds it (framed = false → the run's combat mode decides).
func _menu() -> Control:
	var sm: Control = (load(SETTINGS) as PackedScene).instantiate() as Control
	sm.call("setup", {"framed": false})
	var holder: Control = Control.new()
	add_to_tree(holder)
	holder.add_child(sm)
	return sm


func test_realtime_run_shows_the_combat_section() -> void:
	Game.state.combat_mode = &"realtime"
	var sm: Control = _menu()
	await wait_frames(2)
	var rows: Dictionary = sm.get("rows")
	assert_true(bool(sm.call("rt_mode")), "a real-time run")
	for key: String in RT_KEYS:
		assert_true(rows.has(key), "row %s (07 §7.6)" % key)
		assert_true(bool(sm.call("row_visible", key)), "%s shown" % key)
	for key2: String in ["battle_speed", "auto_battle_default", "partner_auto"]:
		assert_true(rows.has(key2), "%s still built" % key2)
		assert_false(bool(sm.call("row_visible", key2)), "%s hidden in the real-time mode (07 §7.8, §12.4)" % key2)
		assert_false((sm.get("_controls") as Array).has(rows[key2]), "%s out of the focus chain" % key2)


func test_rows_write_game_settings() -> void:
	Game.state.combat_mode = &"realtime"
	var sm: Control = _menu()
	await wait_frames(2)
	var rows: Dictionary = sm.get("rows")
	var changed: Array[int] = [0]
	var cb: Callable = func() -> void: changed[0] += 1
	Events.settings_changed.connect(cb)
	var s: GameSettings = Game.settings
	s.combat_speed_pm = 1000
	(rows["combat_speed_pm"] as Button).call("set_options", ["100 %", "85 % · Zeitlupe", "70 % · Zeitlupe"], 0)
	(rows["combat_speed_pm"] as Button).call("step", 1)
	assert_eq(s.combat_speed_pm, 850, "Spieltempo 85 % (Zeitlupe)")
	(rows["combat_speed_pm"] as Button).call("step", 1)
	assert_eq(s.combat_speed_pm, 700, "70 %")
	(rows["combat_speed_pm"] as Button).call("step", 1)
	assert_eq(s.combat_speed_pm, 1000, "back to 100 %")
	var hints_before: bool = s.combat_hints
	(rows["combat_hints"] as Button).call("step", 1)
	assert_eq(s.combat_hints, not hints_before, "Kampf-Hinweise")
	var tri: Dictionary = {"combat_assist": "combat_assist", "combat_camera_assist": "combat_camera_assist"}
	for key: String in tri.keys():
		var c: Button = rows[key]
		c.call("set_options", ["Automatisch", "An", "Aus"], 0)
		s.set(key, -1)
		c.call("step", 1)
		assert_eq(int(s.get(key)), 1, "%s: Automatisch → An" % key)
		c.call("step", 1)
		assert_eq(int(s.get(key)), 0, "%s: An → Aus" % key)
	(rows["telegraph_contrast"] as Button).call("set_options", ["Normal", "Hoch"], 0)
	(rows["telegraph_contrast"] as Button).call("step", 1)
	assert_eq(s.telegraph_contrast, &"high", "Kontrast-Telegraphen hoch")
	(rows["floating_text_scale"] as Button).call("set_options", ["100 %", "125 %", "150 %"], 0)
	(rows["floating_text_scale"] as Button).call("step", 1)
	assert_eq(s.floating_text_scale, 125, "Kampftext-Größe")
	for key2: String in ["auto_attack_default", "auto_retarget", "camera_shake"]:
		var before: bool = bool(s.get(key2))
		(rows[key2] as Button).call("step", 1)
		assert_eq(bool(s.get(key2)), not before, key2)
	assert_gt(changed[0], 8, "every change applies live (settings_changed)")
	Events.settings_changed.disconnect(cb)


func test_ctb_run_keeps_its_menu() -> void:
	Game.state.combat_mode = &"ctb"
	var sm: Control = _menu()
	await wait_frames(2)
	var rows: Dictionary = sm.get("rows")
	assert_false(bool(sm.call("rt_mode")))
	for key: String in RT_KEYS:
		assert_false(rows.has(key), "CTB: no %s row" % key)
	assert_true(bool(sm.call("row_visible", "partner_auto")), "CTB: Partner automatisch stays")
	assert_true(bool(sm.call("row_visible", "battle_speed")), "CTB: Kampftempo stays")
	assert_eq(rows.has("combat_mode"), OS.is_debug_build(), "Kampfmodus switch only in debug builds (07 §12.1)")


func test_debug_combat_mode_switch_for_new_games() -> void:
	if not OS.is_debug_build():
		return
	var sm: Control = _menu()
	await wait_frames(2)
	var c: Button = (sm.get("rows") as Dictionary)["combat_mode"]
	assert_eq(Game.state.combat_mode, &"realtime", "the new game fights in real time (07 E33)")
	Game.settings.combat_mode = &"realtime"
	c.call("set_options", ["Rundenkampf", "Echtzeit"], 1)
	c.call("step", 1)
	assert_eq(Game.settings.combat_mode, &"ctb", "new games take it (07 §12.1)")
	assert_eq(Game.state.combat_mode, &"realtime", "the running game keeps its mode")
	c.call("step", 1)
	assert_eq(Game.settings.combat_mode, &"realtime", "and back")


func test_skills_page_shows_the_combat_bar_in_real_time_runs() -> void:
	Game.state.combat_mode = &"realtime"
	Game.state.member("kai").level = 4
	var page: Control = (load("res://scenes/ui/skills_menu.gd") as GDScript).new() as Control
	page.set("member_id", "kai")
	var holder: Control = Control.new()
	add_to_tree(holder)
	holder.add_child(page)
	await wait_frames(2)
	var list: VBoxContainer = page.get("_list") as VBoxContainer
	var names: PackedStringArray = []
	for c: Node in list.get_children():
		names.append(str(c.name))
	for sid: String in ["skl_kai_heavy_swing", "skl_kai_taunt", "skl_kai_leash_trip", "skl_kai_sweep",
			"skl_stunt_kai_suplex", "skl_kai_prime_finisher", "skl_kai_first_aid"]:
		assert_true(names.has("RtSkill_" + sid), "bar row %s (07 §4.2)" % sid)
	assert_true(names.has("RtTactic"), "the partner tactic")
	var finale: Button = list.get_node("RtSkill_skl_kai_prime_finisher") as Button
	assert_true((finale.find_child("Text", true, false) as Label).text.begins_with("FINALE: "), "FINALE row")
	Game.state.combat_mode = &"ctb"
	page.call("refresh")
	await wait_frames(1)
	assert_null(list.get_node_or_null("RtTactic"), "CTB runs keep the learnset page")
