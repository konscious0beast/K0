extends CanvasLayer
## DebugOverlay (02_TECH §1.6, layer 90; 05 §11.3): F3 (action debug_overlay, debug builds only) toggles FPS, draw calls,
## primitives, seed, floor/room, timer, show values, input scheme, router stack. "Test-Geschenk" (button / F4) sends
## Show.receive_gift(Gift.make_dev("chest", "bronze", 0)). settings.show_fps shows a compact FPS line when closed.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const REFRESH_SEC: float = 0.25

var open: bool = false

var _root: Control
var _panel: PanelContainer
var _text: Label
var _fps_line: Label
var _gift_btn: Button
var _acc: float = 0.0


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = Vector2(12, 150)
	_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(0, 0, 0, 0.72), UiTheme.C_ACCENT_2, 1, 0.0,
		10, 8))
	_root.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(6)
	_panel.add_child(col)
	var title: Label = UiUtil.label("DEBUG (F3)", &"", 15, UiTheme.C_ACCENT_2)
	col.add_child(title)
	_text = UiUtil.label("", &"", 15)
	_text.add_theme_font_override("font", UiTheme.font_mono())
	col.add_child(_text)
	_gift_btn = UiUtil.button("Test-Geschenk (F4)", &"", 0)
	_gift_btn.add_theme_font_size_override("font_size", 15)
	_gift_btn.pressed.connect(send_test_gift)
	col.add_child(_gift_btn)
	_fps_line = UiUtil.label("", &"", 15, UiTheme.C_OK)
	_fps_line.add_theme_font_override("font", UiTheme.font_mono())
	_fps_line.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_line.position = Vector2(-120, 4)
	_fps_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_fps_line)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_overlay"):
		toggle()
		get_viewport().set_input_as_handled()
	elif open and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_F4:
		send_test_gift()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	open = not open
	_apply()


func _process(delta: float) -> void:
	_acc += delta
	if _acc < REFRESH_SEC:
		return
	_acc = 0.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	_fps_line.text = "%d FPS" % roundi(fps)
	_fps_line.visible = not open and Game.settings != null and Game.settings.show_fps
	if open:
		_text.text = info_text()


## Multi-line status text (FPS, draw calls, primitives, seed, room …).
func info_text() -> String:
	var lines: PackedStringArray = []
	lines.append("FPS        %d" % roundi(Performance.get_monitor(Performance.TIME_FPS)))
	lines.append("Draw Calls %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	lines.append("Primitives %s" % UiUtil.fmt_int(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))))
	lines.append("Objekte    %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	lines.append("RAM        %.0f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	if Game.state != null:
		lines.append("Seed       %d" % Game.state.seed)
		if Game.state.floor_run != null:
			var fr: FloorRun = Game.state.floor_run
			lines.append("Etage      %d  (%s)" % [fr.index, String(fr.location)])
			lines.append("Timer      %s  %s" % [UiUtil.fmt_time(floori(Game.time_left())),
				"läuft" if Game.is_timer_ticking() else "steht"])
	var cur: Node = Router.current
	if cur != null and cur.has_method("get_player_cell"):
		var cell: Vector2i = cur.call("get_player_cell")
		lines.append("Raum       (%d, %d)" % [cell.x, cell.y])
	lines.append("Hype       %.1f   Zuschauer %s" % [Show.hype(), UiUtil.fmt_int(Show.viewers())])
	lines.append("Eingabe    %s" % ["Tastatur/Maus", "Gamepad", "Touch"][clampi(Game.input_scheme, 0, 2)])
	lines.append("Screen     %s  (Stapel %d)" % [cur.name if cur != null else "-", Router.stack_size()])
	lines.append("Modus      %s%s" % [String(Game.mode), "  AUTOPLAY" if Game.autoplay else ""])
	return "\n".join(lines)


func send_test_gift() -> Dictionary:
	var gift: Dictionary = Gift.make_dev("chest", "bronze", 0)
	if gift.is_empty():
		gift = {"schema": 1, "gift_id": "g_dev_ui_%d" % Time.get_ticks_msec(), "source": "dev", "kind": "chest",
			"tier": "bronze", "amount": 0, "sponsor_id": "", "sender": {"display_name": "", "anon": true,
			"sender_ref": ""}, "message_key": "", "target": {"player_id": "local", "run_id": ""}, "event_id": "",
			"window_id": "", "league": "show", "effect_pm": 1000, "load_half": 0, "run_bound": true,
			"deliver_by_tick": 0, "issued_at": ""}
	var res: Dictionary = Show.receive_gift(gift)
	Events.toast_requested.emit("Test-Geschenk: %s" % ("angenommen" if bool(res.get("accepted", res.get("ok", false)))
		else "abgelehnt (%s)" % str(res.get("reason", "?"))), &"gift")
	return res


func _apply() -> void:
	if _panel == null:
		return
	_panel.visible = open
	if open:
		_text.text = info_text()
