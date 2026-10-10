extends TestCase
## project.godot contract (§2), autoload order/process modes (§2.3, §3.1), Events signal list (§3.2),
## Game / GameSettings basics (§3.4) and UiTheme (§3.9).

const AUTOLOADS: PackedStringArray = ["Events", "DB", "Game", "Show", "Save", "Router", "Sfx"]
const SIGNALS: Dictionary = {
	"scene_changed": 1, "new_game_started": 1, "game_loaded": 1, "game_saved": 2, "settings_changed": 0,
	"input_scheme_changed": 1, "overlay_mode_requested": 1, "pause_menu_toggled": 1, "floor_entered": 1,
	"floor_timer_started": 0, "floor_timer_changed": 1, "floor_timer_warning": 1, "floor_timer_expired": 0,
	"floor_completed": 1, "room_entered": 3, "enemy_alerted": 1, "encounter_triggered": 3, "chest_opened": 2,
	"gate_opened": 2, "stray_spawn_requested": 3, "camera_drag": 1, "camera_zoom": 1, "battle_started": 2,
	"battle_turn_started": 2, "battle_ended": 2, "enemy_killed": 1, "battle_won": 1, "battle_fled": 1,
	"stunt_resolved": 1, "combo": 1, "party_ko": 1, "boss_defeated": 1, "boss_hp_changed": 1, "item_bought": 1,
	"event_completed": 1, "explore_tick": 1, "level_up": 1,
	"viewers_changed": 1, "followers_changed": 2, "hype_changed": 3, "achievement_unlocked": 1, "milestone_reached": 1,
	"sponsor_gift_triggered": 1, "mod_said": 4, "dialog_finished": 1, "chat_posted": 3, "party_changed": 0,
	"member_leveled": 3, "inventory_changed": 0, "credits_changed": 2, "lootbox_earned": 1, "lootbox_opened": 2,
	"run_started": 2, "run_finished": 1, "quest_progress": 1, "quest_completed": 0, "gift_received": 1,
	"gift_rejected": 2, "toast_requested": 2, "dialog_reserve_requested": 3,
	"sponsor_window_opened": 1, "sponsor_window_closed": 2,
	"sponsor_window_updated": 1,
	"hero_changed": 1, "field_ability_used": 3, "secret_opened": 1,          # 06 package A
	"talent_pending": 2, "talent_picked": 2,              # 06 package B
	"marotten_announced": 1, "marotte_progress": 3, "marotte_won": 1, "liga_changed": 1,   # 06-C
}
const ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "cam_left", "cam_right",
	"cam_up", "cam_down", "sneak", "action", "pause", "map", "tab_prev", "tab_next", "toggle_auto", "toggle_speed",
	"toggle_fullscreen", "debug_overlay", "ui_accept", "ui_cancel"]


func test_project_settings_contract() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/boot/boot.tscn")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")
	assert_eq(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_d3d12"), false)
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "interact")
	assert_eq(ProjectSettings.get_setting("internationalization/locale/fallback"), "de")
	assert_eq(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), true)


func test_input_map() -> void:
	for a: String in ACTIONS:
		assert_true(InputMap.has_action(a), "action " + a)
	assert_almost(InputMap.action_get_deadzone(&"move_forward"), 0.25)
	assert_almost(InputMap.action_get_deadzone(&"cam_left"), 0.2)
	assert_eq(_joy_buttons(&"ui_accept"), [JOY_BUTTON_A], "ui_accept override has gamepad A")
	assert_eq(_joy_buttons(&"ui_cancel"), [JOY_BUTTON_B], "ui_cancel override has gamepad B")
	assert_eq(_keys(&"ui_cancel"), [KEY_ESCAPE], "no Backspace in ui_cancel")
	assert_eq(_keys(&"action"), [KEY_F, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	assert_eq(_joy_buttons(&"sneak"), [JOY_BUTTON_LEFT_STICK])
	assert_eq(_joy_buttons(&"toggle_speed"), [JOY_BUTTON_RIGHT_STICK])
	assert_eq(_joy_buttons(&"map"), [JOY_BUTTON_BACK])
	for a: String in ACTIONS:
		for e: InputEvent in InputMap.action_get_events(a):
			assert_eq(e.device, -1, "%s: all devices" % a)
			if e is InputEventKey:
				assert_eq((e as InputEventKey).keycode, KEY_NONE, "%s uses physical_keycode" % a)


func _joy_buttons(action: StringName) -> Array:
	var out: Array = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			out.append((e as InputEventJoypadButton).button_index)
	return out


func _keys(action: StringName) -> Array:
	var out: Array = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append((e as InputEventKey).physical_keycode)
	return out


func test_autoload_order_and_process_modes() -> void:
	var names: Array[String] = []
	for n: Node in tree.root.get_children():
		if AUTOLOADS.has(String(n.name)):
			names.append(String(n.name))
	assert_eq(names, AUTOLOADS, "autoload order Events → DB → Game → Show → Save → Router → Sfx")
	assert_eq(Router.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(Sfx.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(Game.process_mode, Node.PROCESS_MODE_INHERIT, "Game stays pausable")
	var watcher: Node = Game.get_node_or_null("InputSchemeWatcher")
	assert_not_null(watcher)
	if watcher != null:
		assert_eq(watcher.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_events_signal_list() -> void:
	var have: Dictionary = {}
	for s: Dictionary in Events.get_signal_list():
		have[str(s["name"])] = (s["args"] as Array).size()
	for sig: String in SIGNALS.keys():
		assert_true(have.has(sig), "signal " + sig)
		if have.has(sig):
			assert_eq(have[sig], SIGNALS[sig], "arg count of " + sig)
	assert_eq(Events.get_script().get_script_signal_list().size(), SIGNALS.size(), "no extra signals")


func test_game_defaults_and_ephemeral() -> void:
	assert_true(Game.ephemeral, "runner sets ephemeral")
	assert_true(Game.settings.ephemeral)
	assert_eq(Game.TICKS_PER_SEC, 30)
	assert_eq(Game.settings.save_to_disk(), OK, "ephemeral save is a no-op")
	assert_eq(Game.settings.master_volume, 0.8)
	assert_eq(Game.settings.quality, &"high")
	assert_eq(Game.mode, &"campaign")
	assert_eq(Game.InputScheme.TOUCH, 2)


func test_game_settings_dict_and_defaults() -> void:
	var s: GameSettings = GameSettings.new()
	s.ephemeral = true
	s.master_volume = 0.1
	s.load_from_disk()
	assert_almost(s.master_volume, 0.1, 0.0001, "ephemeral load keeps values")
	s.reset_defaults()
	var d: Dictionary = s.to_dict()
	for key: String in ["master_volume", "music_volume", "sfx_volume", "battle_speed", "text_speed",
			"auto_battle_default", "fullscreen", "quality", "touch_controls", "show_fps", "camera_invert_x",
			"camera_invert_y", "camera_sensitivity", "show_bets_hud"]:
		assert_true(d.has(key), "settings key " + key)
	assert_eq(d["music_volume"], 0.6)
	assert_eq(d["battle_speed"], 1.0)
	assert_eq(d["text_speed"], 1)
	assert_eq(d["touch_controls"], &"auto")
	assert_eq(d["show_bets_hud"], true, "06-C: the show chip is on by default")


func test_game_without_state_is_safe() -> void:
	var saved: Array = [Game.state, Game.sim, Game.run_log]
	Game.state = null                         # the precondition is set here, not hoped for (no conditional skip)
	Game.sim = null
	Game.run_log = null
	assert_false(Game.has_state())
	assert_null(Game.floor_def())
	assert_false(Game.is_timer_ticking())
	assert_eq(Game.time_left(), 0.0)
	Game.record({"t": "rest"})
	assert_null(Game.get_flag("x"))
	assert_eq(Game.get_flag("x", 3), 3)
	assert_eq(Game.enter_safe_room("sr_kiosk")["safe_room_id"], "sr_kiosk")
	assert_null(Game.next_scene({}))
	assert_false(Game.set_difficulty(&"vorabend"))
	assert_len(Game.open_lootbox("box_bronze"), 0)
	assert_eq(Game.replay_log(null)["mismatch_at"], -1)
	Game.state = saved[0]
	Game.sim = saved[1]
	Game.run_log = saved[2]


func test_input_scheme_detection() -> void:
	var seen: Array[int] = []
	var cb: Callable = func(s: int) -> void: seen.append(s)
	Events.input_scheme_changed.connect(cb)
	var before: int = Game.input_scheme
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	await wait_frames(2)
	assert_eq(Game.input_scheme, Game.InputScheme.GAMEPAD)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await wait_frames(2)
	assert_eq(Game.input_scheme, Game.InputScheme.KEYBOARD_MOUSE)
	var key_up: InputEventKey = key.duplicate() as InputEventKey
	key_up.pressed = false
	Input.parse_input_event(key_up)
	var joy_up: InputEventJoypadButton = joy.duplicate() as InputEventJoypadButton
	joy_up.pressed = false
	Input.parse_input_event(joy_up)
	await wait_frames(1)
	Events.input_scheme_changed.disconnect(cb)
	assert_has(seen, Game.InputScheme.GAMEPAD)
	Game.set_input_scheme(before)


func test_ui_theme() -> void:
	var t: Theme = UiTheme.get_theme()
	assert_not_null(t)
	assert_eq(t, UiTheme.get_theme(), "cached")
	assert_eq(t.default_font_size, UiTheme.FONT_SIZE)
	var bases: Dictionary = {"ButtonBig": "Button", "ButtonFlat": "Button", "PanelShow": "PanelContainer",
		"PanelDialog": "PanelContainer", "PanelMenu": "PanelContainer", "LabelTitle": "Label", "LabelHeader": "Label",
		"LabelSmall": "Label", "LabelTimer": "Label", "LabelLive": "Label", "BarHp": "ProgressBar", "BarMp": "ProgressBar",
		"BarHype": "ProgressBar"}
	for v: String in bases.keys():
		assert_eq(t.get_type_variation_base(v), StringName(bases[v]), "variation " + v)
	assert_eq(t.get_font_size("font_size", "LabelTitle"), 56)
	assert_eq(t.get_font_size("font_size", "LabelHeader"), 30)
	assert_eq(t.get_font_size("font_size", "LabelSmall"), 16)
	assert_eq(t.get_font_size("font_size", "LabelTimer"), 34)
	var focus: StyleBoxFlat = t.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_not_null(focus)
	if focus != null:
		assert_eq(focus.border_width_top, 3)
		assert_eq(focus.border_color, UiTheme.C_ACCENT_2)
	assert_not_null(UiTheme.font_mono())
	var show_box: StyleBoxFlat = t.get_stylebox("panel", "PanelShow") as StyleBoxFlat
	assert_ne(show_box.skew, Vector2.ZERO, "PanelShow is skewed")


func test_button_big_min_height() -> void:
	var b: Button = Button.new()
	b.theme_type_variation = &"ButtonBig"
	b.text = "Neues Spiel"
	add_to_tree(b)
	await wait_frames(1)
	assert_gt(b.get_combined_minimum_size().y, UiTheme.BUTTON_BIG_MIN_HEIGHT - 1, "ButtonBig >= 72 px")


func test_ensure_hit_area() -> void:
	var b: Button = Button.new()
	b.text = "A"
	add_to_tree(b)
	UiTheme.ensure_hit_area(b)
	UiTheme.ensure_hit_area(b)
	assert_gt(b.custom_minimum_size.x, UiTheme.TOUCH_HIT - 1)
	assert_gt(b.custom_minimum_size.y, UiTheme.TOUCH_HIT - 1)
	var visual: Control = b.get_node_or_null("HitVisual") as Control
	assert_not_null(visual)
	if visual != null:
		assert_gt(visual.offset_right - visual.offset_left, UiTheme.MIN_TOUCH - 1, "visible part >= MIN_TOUCH")
		assert_eq(visual.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(b.get_child_count(), 2, "idempotent")
	assert_true(b.get_theme_stylebox("normal") is StyleBoxEmpty, "own styleboxes empty")
	var big: Button = Button.new()
	big.custom_minimum_size = Vector2(200, 64)
	add_to_tree(big)
	UiTheme.ensure_hit_area(big)
	assert_eq(big.custom_minimum_size, Vector2(200, 88), "battle button: 200×64 visible, 88 hit")
