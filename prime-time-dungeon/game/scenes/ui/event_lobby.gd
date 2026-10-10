extends Control
## Event run lobby (05 CR-10, S0): event card with name, kind, quest text, rules (timer, Pur-Liga, fixed seed), local
## top 10 (Save.load_leaderboard → Leaderboard) and "Sendung starten" → Game.start_event_run(id) → exploration.
## Several offline events: list on the left. "Zurück" → title.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const EventInfo := preload("res://scenes/ui/event_info.gd")
const DEMO_BOARD: Array[Dictionary] = [
	{"score": 17340, "players": [{"display_name": "Kai_der_Pfleger"}], "quest_complete": true,
		"floor_timer_left_sec": 828},
	{"score": 15210, "players": [{"display_name": "MopsMagie"}], "quest_complete": true, "floor_timer_left_sec": 512},
	{"score": 9875, "players": [{"display_name": "Pendlerin_42"}], "quest_complete": false, "floor_timer_left_sec": 0},
]

var events: Array[Dictionary] = []
var selected: int = 0

var _params: Dictionary = {}
var _start: Button
var _back: Button
var _event_buttons: Array[Control] = []
var _name: Label
var _kind: Label
var _quest: Label
var _rules: VBoxContainer
var _board: VBoxContainer
var _busy: bool = false


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	events = EventInfo.offline_events()
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"title")
	_build()
	if events.is_empty():
		UiUtil.focus_later(_back)
	else:
		UiUtil.focus_later(_start)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func select(i: int) -> void:
	if events.is_empty():
		return
	selected = clampi(i, 0, events.size() - 1)
	_show(events[selected])


func start() -> void:
	if _busy or events.is_empty():
		return
	var id: String = str(events[selected].get("id", ""))
	Game.start_event_run(id)
	if Game.mode == &"event_offline" and Game.has_state():
		_busy = true
		Sfx.play_ui(&"stunt_success")
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
	else:
		Sfx.play_ui(&"ui_error")
		Events.toast_requested.emit("Dieses Event kann gerade nicht starten (Event-Daten fehlen).", &"warning")


func back() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_cancel")
	Router.goto(Router.SCENE_TITLE)


func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 16
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(14)
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	var badge: PanelContainer = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiUtil.box_style(UiUtil.C_LIVE, Color(0, 0, 0, 0), 0, 0.21, 16, 2))
	head.add_child(badge)
	var bl: Label = UiUtil.label("SHOWRUN", &"LabelHeader", 26, UiUtil.C_PAPER)
	badge.add_child(bl)
	head.add_child(UiUtil.label("EVENT-LAUF", &"LabelHeader", 30))
	head.add_child(UiUtil.spacer(0, 0, true))
	head.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 16))
	var body: HBoxContainer = UiUtil.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# Left: event list (+ buttons).
	var left: VBoxContainer = UiUtil.vbox(12)      # 12 px between the 88 px hit areas
	left.custom_minimum_size = Vector2(300, 0)
	body.add_child(left)
	left.add_child(UiUtil.label("SENDUNGEN", &"", 15, UiTheme.C_ACCENT))
	for i in events.size():
		var e: Dictionary = events[i]
		var b: Button = UiUtil.button(str(e.get("name", "Event")), &"ButtonFlat")
		UiUtil.touch_pad(b)
		var idx: int = i
		b.focus_entered.connect(func() -> void: select(idx))
		b.pressed.connect(func() -> void:
			select(idx)
			_start.grab_focus())
		left.add_child(b)
		_event_buttons.append(b)
	if events.is_empty():
		left.add_child(UiUtil.label("Keine Offline-Events in den Daten.", &"LabelSmall", 16))
	left.add_child(UiUtil.spacer(0, 0, true))
	_start = UiUtil.button("Sendung starten", &"ButtonBig")
	_start.name = "Start"
	UiUtil.touch_pad(_start, 72.0)
	_start.pressed.connect(start)
	_start.disabled = events.is_empty()
	left.add_child(_start)
	_back = UiUtil.button("Zurück", &"ButtonBig")
	_back.name = "Back"
	UiUtil.touch_pad(_back)
	_back.pressed.connect(back)
	left.add_child(_back)
	var chain: Array[Control] = []
	chain.append_array(_event_buttons)
	chain.append(_start)
	chain.append(_back)
	UiUtil.wire_vertical(chain)
	# Center: event card.
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.92), UiTheme.C_ACCENT, 2, 0.0,
		24, 18))
	body.add_child(card)
	var cc: VBoxContainer = UiUtil.vbox(10)
	card.add_child(cc)
	_kind = UiUtil.label("", &"", 15, UiTheme.C_ACCENT_2)
	_kind.add_theme_font_override("font", UiTheme.font_bold())
	cc.add_child(_kind)
	_name = UiUtil.label("", &"LabelTitle", 44)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cc.add_child(_name)
	var ql: Label = UiUtil.label("QUEST", &"", 15, UiTheme.C_GOLD)
	ql.add_theme_font_override("font", UiTheme.font_bold())
	cc.add_child(ql)
	_quest = UiUtil.label("", &"", 24)
	_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cc.add_child(_quest)
	cc.add_child(UiUtil.spacer(4))
	var rl: Label = UiUtil.label("REGELN", &"", 15, UiTheme.C_GOLD)
	rl.add_theme_font_override("font", UiTheme.font_bold())
	cc.add_child(rl)
	_rules = UiUtil.vbox(4)
	cc.add_child(_rules)
	cc.add_child(UiUtil.spacer(0, 0, true))
	var fair: Label = UiUtil.label("Keine Echtgeld-Inhalte. Lauf-Zustand verfällt nach der Sendung; nur die Bestenliste "
		+ "bleibt.", &"LabelSmall", 14)
	fair.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cc.add_child(fair)
	# Right: leaderboard.
	var lb: PanelContainer = PanelContainer.new()
	lb.custom_minimum_size = Vector2(330, 0)
	lb.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.88), Color(UiTheme.C_GOLD, 0.6),
		1, 0.0, 16, 14))
	body.add_child(lb)
	var lc: VBoxContainer = UiUtil.vbox(6)
	lb.add_child(lc)
	var lh: HBoxContainer = UiUtil.hbox(8)
	lc.add_child(lh)
	lh.add_child(UiIcon.make(&"trophy", UiTheme.C_GOLD, 24))
	lh.add_child(UiUtil.label("LOKALE TOP 10", &"", 18, UiTheme.C_GOLD))
	_board = UiUtil.vbox(4)
	lc.add_child(_board)
	if not events.is_empty():
		select(0)


func _show(e: Dictionary) -> void:
	_kind.text = "%s · ETAGE %d" % [str(e.get("kind_name", "Event")).to_upper(), int(e.get("floor", 1))]
	_name.text = UiUtil.glyph_safe(str(e.get("name", "Event")))
	_quest.text = UiUtil.glyph_safe(EventInfo.quest_text(e.get("quest", {}) as Dictionary))
	for c: Node in _rules.get_children():
		c.queue_free()
	for line: String in EventInfo.rule_lines(e):
		var r: HBoxContainer = UiUtil.hbox(10)
		var dot: Control = UiIcon.make(&"diamond", UiTheme.C_ACCENT_2, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(dot)
		var l: Label = UiUtil.label(UiUtil.glyph_safe(line), &"", 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		_rules.add_child(r)
	for c: Node in _board.get_children():
		c.queue_free()
	var board: Array[Dictionary] = EventInfo.leaderboard(str(e.get("id", "")))
	if board.is_empty() and bool(_params.get("capture", false)):
		board = DEMO_BOARD.duplicate(true)
	if board.is_empty():
		var empty: Label = UiUtil.label("Noch keine Einträge – die erste Sendung gehört dir.", &"LabelSmall", 16)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_board.add_child(empty)
		return
	for i in board.size():
		var be: Dictionary = board[i]
		var r: HBoxContainer = UiUtil.hbox(8)
		var pos: Label = UiUtil.label("%d." % (i + 1), &"", 18, UiTheme.C_GOLD if i < 3 else UiTheme.C_TEXT_DIM)
		pos.custom_minimum_size = Vector2(34, 0)
		r.add_child(pos)
		var n: Label = UiUtil.label(UiUtil.glyph_safe(EventInfo.entry_name(be)), &"", 18)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_child(n)
		if bool(be.get("quest_complete", false)):
			r.add_child(UiIcon.make(&"check", UiTheme.C_OK, 16))
		var s: Label = UiUtil.label(UiUtil.fmt_int(int(be.get("score", 0))), &"", 18)
		s.add_theme_font_override("font", UiTheme.font_mono())
		r.add_child(s)
		_board.add_child(r)
