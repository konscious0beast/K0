extends CanvasLayer
## DebugOverlay (02_TECH §1.6, layer 90; 05 §11.3): F3 (action debug_overlay, debug builds only) toggles FPS, draw calls,
## primitives, seed, floor/room, timer, show values, Sponsor-Fenster, input scheme, router stack. "Test-Geschenk"
## (button / F4) simulates a viewer gift: Show.receive_gift(Gift.make_dev("chest", "bronze", 0, <new test viewer>)) —
## it respects the Sponsor-Fenster like every viewer gift (05 §6.13; refusal toast names the reason and the next
## window). "Fenster öffnen" (button / F5) opens a QA window (Game.open_dev_sponsor_window, recorded; only where
## rules.sponsor_windows.dev_open allows it). settings.show_fps shows a compact FPS line when closed.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const REFRESH_SEC: float = 0.25

var open: bool = false

var _root: Control
var _panel: PanelContainer
var _text: Label
var _fps_line: Label
var _gift_btn: Button
var _window_btn: Button
var _acc: float = 0.0
var _viewer_n: int = 0
## German texts of the gift refusals the dev tool shows (05 §6.5 / §6.13 reason codes).
const REASON_TEXT: Dictionary = {"window_closed": "Sponsor-Fenster zu", "window_full": "Sponsor-Fenster voll",
	"window_sender_limit": "Zuschauer-Limit im Fenster erreicht", "league_pur": "Pur-Liga – keine Geschenke",
	"cap_reached": "Geschenk-Kontingent erreicht", "not_accepting": "Geschenke abgelehnt",
	"chest_blocked": "Kisten gesperrt (Wirkung)", "run_not_active": "kein Lauf aktiv"}


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
	_window_btn = UiUtil.button("Fenster öffnen (F5)", &"", 0)
	_window_btn.add_theme_font_size_override("font_size", 15)
	_window_btn.pressed.connect(open_test_window)
	col.add_child(_window_btn)
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
	elif open and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_F5:
		open_test_window()
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
	lines.append("Sponsor    %s" % window_text(Show.sponsor_window_view()))
	lines.append("Eingabe    %s" % ["Tastatur/Maus", "Gamepad", "Touch"][clampi(Game.input_scheme, 0, 2)])
	lines.append("Screen     %s  (Stapel %d)" % [cur.name if cur != null else "-", Router.stack_size()])
	lines.append("Modus      %s%s" % [String(Game.mode), "  AUTOPLAY" if Game.autoplay else ""])
	return "\n".join(lines)


## One line about the Sponsor-Fenster: "offen 0:45 · 2/3 Plätze (boss)" / "zu · nächstes in 3:12" / "aus".
static func window_text(v: Dictionary) -> String:
	if not bool(v.get("tracked", false)):
		return "aus"
	if bool(v.get("open", false)):
		return "%s %s · %d/%d Plätze (%s)" % ["voll" if bool(v.get("full", false)) else "offen",
			_mmss(int(v.get("left_sec", 0))), int(v.get("slots", 0)) - int(v.get("free", 0)), int(v.get("slots", 0)),
			str(v.get("kind", ""))]
	var next: int = int(v.get("next_in_sec", -1))
	return "zu · nächstes in %s" % _mmss(next) if next >= 0 else "zu"


static func _mmss(sec: int) -> String:
	var s: int = maxi(0, sec)
	return "%d:%02d" % [s / 60, s % 60]


## QA window (Game.open_dev_sponsor_window: 60 s, 3 slots); toast with the result.
func open_test_window() -> bool:
	var ok: bool = Game.open_dev_sponsor_window(60, 3)
	Events.toast_requested.emit("Sponsor-Fenster (Test): %s" % ("geöffnet" if ok else "nicht erlaubt"), &"gift")
	return ok


func send_test_gift() -> Dictionary:
	_viewer_n += 1
	var gift: Dictionary = Gift.make_dev("chest", "bronze", 0, "dev_viewer_%d" % _viewer_n)
	if gift.is_empty():
		gift = {"schema": 1, "gift_id": "g_dev_ui_%d" % Time.get_ticks_msec(), "source": "dev", "kind": "chest",
			"tier": "bronze", "amount": 0, "sponsor_id": "", "sender": {"display_name": "", "anon": true,
			"sender_ref": ""}, "message_key": "", "target": {"player_id": "local", "run_id": ""}, "event_id": "",
			"window_id": "", "league": "show", "effect_pm": 1000, "load_half": 0, "run_bound": true,
			"deliver_by_tick": 0, "issued_at": ""}
	var res: Dictionary = Show.receive_gift(gift)
	Events.toast_requested.emit("Test-Geschenk: %s" % ("angenommen" if bool(res.get("accepted", res.get("ok", false)))
		else "abgelehnt – " + refusal_text(str(res.get("reason", "?")), Show.sponsor_window_view())), &"gift")
	return res


## German refusal text; window refusals name the next window ("Sponsor-Fenster zu – nächstes in 3:12").
static func refusal_text(reason: String, v: Dictionary) -> String:
	var text: String = str(REASON_TEXT.get(reason, reason))
	if reason.begins_with("window_") and int(v.get("next_in_sec", -1)) >= 0:
		text += " – nächstes in " + _mmss(int(v["next_in_sec"]))
	return text


func _apply() -> void:
	if _panel == null:
		return
	_panel.visible = open
	if open:
		_text.text = info_text()
