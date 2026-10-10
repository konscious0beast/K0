class_name ExplorationHud extends CanvasLayer
## Exploration HUD (02_TECH §9.5, layer 5), instanced by ExplorationScene: floor timer (mm:ss, 38 px mono; hidden until
## the countdown starts; < 5:00 orange, < 1:00 red pulsing + light screenshake every 10 s, ≤ 0:10 beep per second),
## floor name, quest line (event runs), minimap (+ big map on `map`), party mini status, interaction prompt with input
## glyph, control hints, touch layer (layer 20). `pause` opens the PauseMenu (tree paused, §9.4).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const MinimapScript := preload("res://scenes/ui/minimap.gd")
const EventInfo := preload("res://scenes/ui/event_info.gd")
const PAUSE_MENU: String = "res://scenes/ui/pause_menu.tscn"
const TOUCH_CONTROLS: String = "res://scenes/ui/touch_controls.tscn"
const WARN_ORANGE_SEC: int = 300
const WARN_RED_SEC: int = 60
const BEEP_FROM_SEC: int = 10
const SHAKE_EVERY_SEC: int = 10
const SHAKE_DURATION: float = 0.3
const SHAKE_STRENGTH: float = 0.15
const MINIMAP_SIZE: float = 136.0
const POP_SCALE: float = 1.3                 # timer panel scale when the countdown starts …
const POP_SEC: float = 0.3                   # … back to 1.0 within this time
## World-anchored prompt (set_prompt_anchor): gap above the anchor point and the band it is kept in (below the timer /
## hype meter, above the M.O.D. box incl. tab and the chat ticker; safe-frame px).
const PROMPT_ANCHOR_GAP: float = 12.0
const PROMPT_TOP_MIN: float = 112.0
const PROMPT_BOTTOM_CLEAR: float = 190.0


## Full-screen map (layer 60, tree paused): every visited cell, legend (same swatches as the map), zone names. Closes on
## map / ui_cancel / pause or the "Schließen" button (touch: the only way out, §10.3). Opaque backdrop: the HUD and the
## show overlay underneath never shine through.
class BigMap extends CanvasLayer:
	const UiUtilB := preload("res://scenes/ui/ui_util.gd")
	const MinimapB := preload("res://scenes/ui/minimap.gd")
	const UiIconB := preload("res://scenes/ui/ui_icon.gd")
	const InputGlyphB := preload("res://scenes/ui/input_glyph.gd")
	signal closed()
	var map: Control
	var close_button: Button
	var floor_title: String = ""
	var _closing: bool = false

	func _ready() -> void:
		layer = 60
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		var root: Control = Control.new()
		UiUtilB.full_rect(root)
		UiUtilB.apply_theme(root)
		add_child(root)
		var dim: ColorRect = ColorRect.new()
		UiUtilB.full_rect(dim)
		dim.color = UiTheme.C_BG
		root.add_child(dim)
		var safe: SafeAreaContainer = SafeAreaContainer.new()
		safe.extra = 16
		safe.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(safe)
		var row: HBoxContainer = UiUtilB.hbox(24)
		safe.add_child(row)
		map = MinimapB.new()
		map.set("big", true)
		map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(map)
		var side: VBoxContainer = UiUtilB.vbox(10)
		side.custom_minimum_size = Vector2(300, 0)
		row.add_child(side)
		var head: HBoxContainer = UiUtilB.hbox(10)
		side.add_child(head)
		var title: Label = UiUtilB.label("KARTE", &"LabelHeader")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title)
		close_button = UiUtilB.close_button("Schließen")
		close_button.pressed.connect(close)
		head.add_child(close_button)
		side.add_child(UiUtilB.label(floor_title, &"LabelSmall", 18))
		side.add_child(UiUtilB.spacer(4))
		for entry: Array in [["player", "Kandidat:in"], ["start", "Start"], ["safe", "Safe Room"],
				["stairs", "Treppe"], ["boss", "Boss"], ["gate", "Verschlossenes Tor"]]:
			var r: HBoxContainer = UiUtilB.hbox(12)
			r.add_child(MinimapB.swatch(str(entry[0]), 30.0))
			var l: Label = UiUtilB.label(str(entry[1]), &"", 18)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(l)
			side.add_child(r)
		side.add_child(UiUtilB.spacer(0, 0, true))
		var hint: HBoxContainer = UiUtilB.hbox(12)
		hint.add_child(InputGlyphB.make(&"map", "Schließen", 16))
		side.add_child(hint)
		UiUtilB.focus_later(close_button)

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"map") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			close()

	func close() -> void:
		if _closing:
			return
		_closing = true
		Sfx.play_ui(&"ui_cancel")
		get_tree().paused = false
		Events.pause_menu_toggled.emit(false)
		closed.emit()
		queue_free()


var minimap: Control
var touch: CanvasLayer

var _params: Dictionary = {}
var _root: Control
var _safe: SafeAreaContainer
var _frame: Control
var _floor_label: Label
var _timer_panel: PanelContainer
var _timer_label: Label
var _timer_icon: Control
var _quest_panel: PanelContainer
var _quest_label: Label
var _quest_bar: ProgressBar
var _party_box: VBoxContainer
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_glyph: Control
var _prompt_anchor: Vector2 = Vector2.INF
var _hints: HBoxContainer
var _seconds: int = -1
var _timer_started: bool = false
var _last_beep: int = -1
var _last_shake: int = -1
var _pulse_t: float = 0.0
var _shake_left: float = 0.0
var _pop_left: float = 0.0                   # countdown start pop still running (s)
var _shake_cam_offset: Vector2 = Vector2.ZERO
var _party_refresh: float = 0.0
var _modal: Node = null
var _prompt_text: String = ""
var _quest_text: String = ""
var _demo: bool = false
var _dirty: Dictionary = {}                 # handler → pending while detached (§13.3); applied on re-attach
var _quest_progress_pending: float = -1.0


## Optional (captures): {"capture": true} → standalone still with floor map, timer, prompt and quest line.
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 5


func _ready() -> void:
	_build()
	Events.floor_timer_changed.connect(_on_timer_changed)
	Events.floor_timer_started.connect(_on_timer_started)
	Events.floor_timer_warning.connect(_on_timer_warning)
	Events.floor_timer_expired.connect(_on_timer_expired)
	Events.party_changed.connect(_on_party_changed)
	Events.quest_progress.connect(_on_quest_progress)
	Events.quest_completed.connect(_on_quest_completed)
	Events.floor_entered.connect(_on_floor_entered)
	_refresh_floor()
	_refresh_party()
	if Game.state != null and Game.state.floor_run != null:
		_timer_started = Game.state.floor_run.timer_started
		_set_seconds(floori(Game.time_left()))
	_update_timer_visibility()
	set_prompt("")
	_auto_quest()
	if bool(_params.get("capture", false)):
		_start_demo()


## Detached stack screen (ExplorationScene during battles / safe room, §9.2): handlers only mark work as dirty; it is
## applied when the HUD is attached again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and not _dirty.is_empty():
		_apply_dirty.call_deferred()


func _apply_dirty() -> void:
	if not is_inside_tree():
		return
	var d: Dictionary = _dirty
	_dirty = {}
	if d.has("floor"):
		_refresh_floor()
	if d.has("party"):
		_refresh_party()
	if d.has("quest_progress"):
		_on_quest_progress(_quest_progress_pending)
	if d.has("quest_completed"):
		_on_quest_completed()
	if d.has("timer_started"):
		_on_timer_started()


func _process(delta: float) -> void:
	_pulse_t += delta
	_party_refresh += delta
	if _party_refresh > 0.5:
		_party_refresh = 0.0
		_refresh_party_values()
	if _pop_left > 0.0:
		# Countdown start pop (1.3 → 1.0). Driven here, not by a tween: the reset below ran before a tween's first step
		# and the tween then animated from 1.0 to 1.0 (the pop never showed).
		_pop_left = maxf(0.0, _pop_left - delta)
		var p: float = 1.0 + (POP_SCALE - 1.0) * ease(_pop_left / POP_SEC, 2.0)
		_timer_panel.pivot_offset = _timer_panel.size * 0.5
		_timer_panel.scale = Vector2(p, p)
	elif _timer_started and _seconds >= 0 and _seconds < WARN_RED_SEC:
		var s: float = 1.0 + 0.08 * (0.5 + 0.5 * sin(_pulse_t * TAU * 2.0))
		_timer_panel.pivot_offset = _timer_panel.size * 0.5
		_timer_panel.scale = Vector2(s, s)
	elif _timer_panel.scale != Vector2.ONE:
		_timer_panel.scale = Vector2.ONE
	if _shake_left > 0.0:
		_shake_left -= delta
		var amp: float = SHAKE_STRENGTH * 22.0
		offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) if _shake_left > 0.0 else Vector2.ZERO
		_shake_camera(_shake_left > 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	if Router.busy or _world_blocks_menus():
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open_pause_menu()
	elif event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		open_big_map()


# --- public API (02_TECH §9.5)
# ------------------------------------------------------------------------------------------

func bind_layout(layout: FloorLayout, visited: Array[Vector2i]) -> void:
	minimap.call("bind", layout, visited)


func set_player(cell: Vector2i, yaw_rad: float) -> void:
	minimap.call("set_player", cell, yaw_rad)


func mark_visited(cell: Vector2i) -> void:
	minimap.call("mark_visited", cell)


## "" hides; the touch "action" button shows the interact icon while a prompt is set.
func set_prompt(text: String) -> void:
	_prompt_text = text
	var show_it: bool = text != ""
	if show_it:
		_prompt_label.text = UiUtil.glyph_safe(text)
		if not _prompt_panel.visible:
			_prompt_panel.visible = true
			UiUtil.fade_in(_prompt_panel, 0.12)
	else:
		_prompt_panel.visible = false
	if touch != null:
		touch.call("set_prompt_active", show_it)
	_place_prompt()


## Canvas point the prompt sits centred above (the focused object's marker, projected by the exploration scene) so the
## prompt never covers the object right in front of Kai (GDD §14.3 "Interaktionsprompt über Objekt"); Vector2.INF →
## default slot bottom centre. The panel stays inside the band between the top HUD and the M.O.D. box.
func set_prompt_anchor(canvas_pos: Vector2) -> void:
	if canvas_pos == _prompt_anchor:
		return
	_prompt_anchor = canvas_pos
	_place_prompt()


func prompt_rect() -> Rect2:
	return _prompt_panel.get_global_rect() if _prompt_panel.visible else Rect2()


func _place_prompt() -> void:
	if _prompt_panel == null:
		return
	var anchored: bool = _prompt_anchor.is_finite() and _frame.size.x > 0.0
	if not anchored:
		_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt_panel.offset_left = -200
		_prompt_panel.offset_right = 200
		_prompt_panel.offset_bottom = -22 - 14 - 108 - 40
		_prompt_panel.offset_top = -22 - 14 - 108 - 40 - 44
		return
	var sz: Vector2 = Vector2(maxf(240.0, _prompt_panel.get_combined_minimum_size().x), 44.0)
	var local: Vector2 = _prompt_anchor - _frame.get_global_rect().position
	var pos: Vector2 = Vector2(local.x - sz.x * 0.5, local.y - sz.y - PROMPT_ANCHOR_GAP)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, _frame.size.x - sz.x - 8.0))
	pos.y = clampf(pos.y, PROMPT_TOP_MIN, maxf(PROMPT_TOP_MIN, _frame.size.y - PROMPT_BOTTOM_CLEAR - sz.y))
	_prompt_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_prompt_panel.position = pos.round()
	_prompt_panel.size = sz


## Event runs only (Game.mode == &"event_offline"); "" hides.
func set_quest(text: String, progress: float) -> void:
	_quest_text = text
	_quest_panel.visible = text != ""
	_quest_label.text = UiUtil.glyph_safe(text)
	_quest_bar.value = clampf(progress, 0.0, 1.0) * 100.0


# --- M6-internal helpers (tests, touch)
# ---------------------------------------------------------------------------------

func prompt_text() -> String:
	return _prompt_text


func quest_text() -> String:
	return _quest_text


func timer_text() -> String:
	return _timer_label.text


func timer_color() -> Color:
	return _timer_label.get_theme_color("font_color")


func is_timer_visible() -> bool:
	return _timer_panel.visible


func is_modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)


## The exploration this HUD belongs to (its parent, duck-typed) blocks pause / map while its choice dialog is open
## (the dialog owns the focus — a BigMap / PauseMenu over it would leave it without one after closing; 02_TECH §10:
## exploration input only without an open menu) or while a battle is about to start. Event reveals stay pausable.
func _world_blocks_menus() -> bool:
	var ex: Node = get_parent()
	if ex == null:
		return false
	if ex.has_method("active_dialog") and ex.call("active_dialog") != null:
		return true
	return ex.has_method("is_encounter_pending") and bool(ex.call("is_encounter_pending"))


func open_pause_menu(tab: String = "party") -> Node:
	if is_modal_open() or _world_blocks_menus() or not ResourceLoader.exists(PAUSE_MENU):
		return null
	var pm: Node = (load(PAUSE_MENU) as PackedScene).instantiate()
	pm.call("setup", {"tab": tab, "context": "explore"})
	add_child(pm)
	_modal = pm
	return pm


func open_big_map() -> Node:
	if is_modal_open() or _world_blocks_menus():
		return null
	var bm: BigMap = BigMap.new()
	var def: FloorDef = Game.floor_def()
	bm.floor_title = UiUtil.tr_text(def.name) if def != null else ""
	add_child(bm)
	bm.map.call("bind", minimap.get("layout"), minimap.get("visited"))
	bm.map.call("set_player", minimap.get("player_cell"), float(minimap.get("player_yaw")))
	get_tree().paused = true
	Events.pause_menu_toggled.emit(true)
	Sfx.play_ui(&"ui_confirm")
	_modal = bm
	return bm


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	_safe = SafeAreaContainer.new()
	_safe.extra = 0
	_root.add_child(_safe)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_frame)
	_build_top_center()
	_build_minimap()
	_build_party()
	_build_prompt()
	_build_hints()
	if ResourceLoader.exists(TOUCH_CONTROLS):
		touch = (load(TOUCH_CONTROLS) as PackedScene).instantiate() as CanvasLayer
		touch.name = "TouchControls"
		add_child(touch)
		touch.connect("shown_changed", _layout_for_touch)
		_layout_for_touch(bool(touch.call("is_shown")))
		# Display insets (notch) can change with the window size / rotation: re-measure the pause/map clearance.
		get_viewport().size_changed.connect(_on_viewport_resized)


## While the touch layer is shown, the pause/map buttons (88 px hit areas at x = 1227) own the top-right corner:
## the minimap moves left of them (02_TECH §10.2 rule 5: hit areas never overlap other controls). The clearance is
## measured against the buttons' real position (display insets included), see TouchControls.right_clearance().
func _layout_for_touch(shown: bool) -> void:
	var right: float = -float(touch.call("right_clearance", _safe)) if shown and touch != null else 0.0
	minimap.offset_right = right
	minimap.offset_left = right - MINIMAP_SIZE
	var hint: Control = _frame.get_node_or_null("MapHint") as Control
	if hint != null:
		hint.offset_right = right
		hint.offset_left = right - MINIMAP_SIZE


func _on_viewport_resized() -> void:
	if touch != null and is_instance_valid(touch):
		_layout_for_touch(bool(touch.call("is_shown")))


func minimap_rect() -> Rect2:
	return minimap.get_global_rect()


func _build_top_center() -> void:
	var col: VBoxContainer = UiUtil.vbox(4)
	col.name = "TopCenter"
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.offset_left = -220
	col.offset_right = 220
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_frame.add_child(col)
	_floor_label = UiUtil.label("", &"", 16, UiTheme.C_TEXT_DIM)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.add_theme_font_override("font", UiTheme.font_bold())
	col.add_child(_floor_label)
	_timer_panel = PanelContainer.new()
	_timer_panel.name = "Timer"
	_timer_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.88),
		Color(UiTheme.C_ACCENT_2, 0.6), 2, 0.21, 22, 0))
	col.add_child(_timer_panel)
	var trow: HBoxContainer = UiUtil.hbox(10)
	_timer_panel.add_child(trow)
	_timer_icon = UiIcon.make(&"clock", UiTheme.C_TEXT, 26)
	_timer_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(_timer_icon)
	_timer_label = UiUtil.label("20:00", &"LabelTimer", 38)
	_timer_label.name = "TimerLabel"
	trow.add_child(_timer_label)
	_quest_panel = PanelContainer.new()
	_quest_panel.name = "Quest"
	_quest_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.85),
		Color(UiTheme.C_GOLD, 0.7), 1, 0.0, 12, 4))
	_quest_panel.visible = false
	col.add_child(_quest_panel)
	var qcol: VBoxContainer = UiUtil.vbox(3)
	_quest_panel.add_child(qcol)
	var qrow: HBoxContainer = UiUtil.hbox(8)
	qcol.add_child(qrow)
	var qtag: Label = UiUtil.label("QUEST", &"", 15, UiTheme.C_GOLD)
	qtag.add_theme_font_override("font", UiTheme.font_bold())
	qrow.add_child(qtag)
	_quest_label = UiUtil.label("", &"", 16)
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_quest_label)
	_quest_bar = UiUtil.bar(&"BarHype", 0.0, 100.0, 6.0)
	qcol.add_child(_quest_bar)


func _build_minimap() -> void:
	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -MINIMAP_SIZE
	minimap.offset_right = 0
	minimap.offset_top = 50
	minimap.offset_bottom = 50 + MINIMAP_SIZE
	_frame.add_child(minimap)
	var hint: Control = InputGlyph.make(&"map", "Karte", 15)
	hint.name = "MapHint"
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -MINIMAP_SIZE
	hint.offset_right = 0
	hint.offset_top = 54 + MINIMAP_SIZE
	hint.offset_bottom = 78 + MINIMAP_SIZE
	_frame.add_child(hint)


func _build_party() -> void:
	_party_box = UiUtil.vbox(6)
	_party_box.name = "Party"
	# Top left under the show bar (LIVE/viewers/followers): the bottom left belongs to the sponsor lower third
	# (03_ART §9.2) and the touch joystick (02_TECH §10.3).
	_party_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_party_box.grow_vertical = Control.GROW_DIRECTION_END
	_party_box.offset_left = 0
	_party_box.offset_right = 260
	_party_box.offset_top = 64
	_party_box.offset_bottom = 64 + 150
	_party_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_frame.add_child(_party_box)


func _build_prompt() -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "Prompt"
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.offset_left = -200
	_prompt_panel.offset_right = 200
	_prompt_panel.offset_bottom = -22 - 14 - 108 - 40
	_prompt_panel.offset_top = -22 - 14 - 108 - 40 - 44
	_prompt_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.9), UiTheme.C_GOLD, 2,
		0.21, 18, 6))
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_prompt_panel)
	var row: HBoxContainer = UiUtil.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_panel.add_child(row)
	_prompt_glyph = InputGlyph.make(&"action", "", 18)
	row.add_child(_prompt_glyph)
	_prompt_label = UiUtil.label("", &"", 20)
	row.add_child(_prompt_label)


func _build_hints() -> void:
	_hints = UiUtil.hbox(16)
	_hints.name = "Hints"
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hints.offset_left = -420
	_hints.offset_right = 0
	_hints.offset_bottom = -22 - 14
	_hints.offset_top = -22 - 14 - 26
	_hints.alignment = BoxContainer.ALIGNMENT_END
	_frame.add_child(_hints)
	_hints.add_child(InputGlyph.make(&"sneak", "Schleichen", 16))
	var field: Control = InputGlyph.make(&"action", field_hint(), 16)
	field.name = "FieldHint"
	_hints.add_child(field)
	_hints.add_child(InputGlyph.make(&"pause", "Menü", 16))


## 06 package A: the control hint of the hero's field ability ("Schlag" for Kai, "Bellen" for Graf Mopsula).
static func field_hint() -> String:
	return "Bellen" if Game.hero() == "mopsula" else "Schlag"


## 06 package A: after a hero switch (ExplorationScene.refresh_hero): hint text and touch action icon.
func refresh_hero() -> void:
	var field: Node = _hints.get_node_or_null("FieldHint") if _hints != null else null
	if field != null:
		field.set("caption", field_hint())
	if touch != null:
		touch.call("refresh_hero")


# --- timer ------------------------------------------------------------------------------------------------------------

func _set_seconds(sec: int) -> void:
	_seconds = maxi(sec, 0)
	_timer_label.text = UiUtil.fmt_time(_seconds)
	var col: Color = UiTheme.C_TEXT
	if _seconds < WARN_RED_SEC:
		col = UiUtil.C_LIVE
	elif _seconds < WARN_ORANGE_SEC:
		col = UiUtil.C_SODIUM
	_timer_label.add_theme_color_override("font_color", col)
	_timer_icon.set("color", col)
	var border: Color = Color(UiTheme.C_ACCENT_2, 0.6) if _seconds >= WARN_ORANGE_SEC else col
	_timer_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.88), border, 2, 0.21,
		22, 0))


func _on_timer_changed(seconds_left: int) -> void:
	if not is_inside_tree():
		return
	if not _timer_started:
		_timer_started = true
		_update_timer_visibility()
	_set_seconds(seconds_left)
	if seconds_left <= BEEP_FROM_SEC and seconds_left >= 0 and seconds_left != _last_beep:
		_last_beep = seconds_left
		Sfx.play_ui(&"timer_warn")
	if seconds_left < WARN_RED_SEC and seconds_left > 0 and seconds_left % SHAKE_EVERY_SEC == 0 \
			and seconds_left != _last_shake:
		_last_shake = seconds_left
		_shake_left = SHAKE_DURATION


func _on_timer_started() -> void:
	if not is_inside_tree():
		# The tutorial victory starts the countdown while the exploration (and this HUD) is detached for the battle:
		# show the timer with its pop as soon as the HUD is back, not one second later on the first tick.
		_dirty["timer_started"] = true
		return
	_timer_started = true
	if Game.state != null:
		_set_seconds(floori(Game.time_left()))
	_update_timer_visibility()
	_timer_panel.pivot_offset = _timer_panel.size * 0.5
	_timer_panel.scale = Vector2(POP_SCALE, POP_SCALE)
	_pop_left = POP_SEC


func _on_timer_warning(seconds_left: int) -> void:
	if not is_inside_tree():
		return
	_set_seconds(seconds_left)
	Sfx.play_ui(&"timer_warn")
	_timer_panel.modulate = Color(2, 2, 2, 1)
	create_tween().tween_property(_timer_panel, "modulate", Color.WHITE, 0.5)


func _on_timer_expired() -> void:
	if not is_inside_tree():
		return
	_set_seconds(0)


func _update_timer_visibility() -> void:
	_timer_panel.visible = _timer_started


## Light screenshake: HUD layer offset + active camera h/v offset (restored afterwards).
func _shake_camera(on: bool) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	cam.h_offset -= _shake_cam_offset.x
	cam.v_offset -= _shake_cam_offset.y
	_shake_cam_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH * 0.4 if on \
		else Vector2.ZERO
	cam.h_offset += _shake_cam_offset.x
	cam.v_offset += _shake_cam_offset.y


# --- party / floor / quest ------------------------------------------------------------------------------------------

func _on_floor_entered(_index: int) -> void:
	if not is_inside_tree():
		_dirty["floor"] = true
		return
	_refresh_floor()


func _on_party_changed() -> void:
	if not is_inside_tree():
		_dirty["party"] = true      # apply_battle_result / safe-room heal fire while the HUD is detached
		return
	_refresh_party()


func _refresh_floor() -> void:
	var def: FloorDef = Game.floor_def()
	_floor_label.text = UiUtil.tr_text(def.name).to_upper() if def != null else ""


func _refresh_party() -> void:
	for c: Node in _party_box.get_children():
		_party_box.remove_child(c)
		c.queue_free()
	for m: PartyMember in UiUtil.party():
		var panel: PanelContainer = PanelContainer.new()
		panel.name = "Member_" + m.id
		var sb: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_PANEL, 0.82), UiUtil.member_color(m.id), 0, 0.0, 10, 4)
		sb.border_width_left = 4
		panel.add_theme_stylebox_override("panel", sb)
		_party_box.add_child(panel)
		var col: VBoxContainer = UiUtil.vbox(2)
		panel.add_child(col)
		var top: HBoxContainer = UiUtil.hbox(6)
		col.add_child(top)
		var n: Label = UiUtil.label(UiUtil.member_name(m), &"", 15)
		n.add_theme_font_override("font", UiTheme.font_bold())
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(n)
		var lv: Label = UiUtil.label("Lv %d" % m.level, &"LabelSmall", 15)
		top.add_child(lv)
		var hp_row: HBoxContainer = UiUtil.hbox(6)
		col.add_child(hp_row)
		var hp: ProgressBar = UiUtil.bar(&"BarHp", m.hp, UiUtil.max_hp(m), 8.0)
		hp.name = "Hp"
		hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp_row.add_child(hp)
		var hp_l: Label = UiUtil.label("", &"", 15)
		hp_l.name = "HpText"
		hp_l.custom_minimum_size = Vector2(80, 0)
		hp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_l.add_theme_font_override("font", UiTheme.font_mono())
		hp_row.add_child(hp_l)
		var mp_row: HBoxContainer = UiUtil.hbox(6)
		col.add_child(mp_row)
		var mp: ProgressBar = UiUtil.bar(&"BarMp", m.mp, maxi(UiUtil.max_mp(m), 1), 5.0)
		mp.name = "Mp"
		mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mp_row.add_child(mp)
		var mp_l: Label = UiUtil.label("", &"", 15, UiTheme.C_MANA)
		mp_l.name = "MpText"
		mp_l.custom_minimum_size = Vector2(80, 0)
		mp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mp_l.add_theme_font_override("font", UiTheme.font_mono())
		mp_row.add_child(mp_l)
		panel.set_meta("member_id", m.id)
	_refresh_party_values()


func _refresh_party_values() -> void:
	for panel: Node in _party_box.get_children():
		if not panel.has_meta("member_id") or Game.state == null:
			continue
		var m: PartyMember = Game.state.member(str(panel.get_meta("member_id")))
		if m == null:
			continue
		var hp: ProgressBar = panel.find_child("Hp", true, false) as ProgressBar
		var mp: ProgressBar = panel.find_child("Mp", true, false) as ProgressBar
		var hp_l: Label = panel.find_child("HpText", true, false) as Label
		var mp_l: Label = panel.find_child("MpText", true, false) as Label
		var mhp: int = UiUtil.max_hp(m)
		hp.max_value = mhp
		hp.value = m.hp
		mp.max_value = maxi(UiUtil.max_mp(m), 1)
		mp.value = m.mp
		mp_l.text = "%d/%d MP" % [m.mp, UiUtil.max_mp(m)]
		hp_l.text = "KO" if m.hp <= 0 else "%d/%d" % [m.hp, mhp]
		var low: bool = m.hp > 0 and float(m.hp) / float(maxi(mhp, 1)) < 0.25
		hp.modulate = Color(1.0, 0.45, 0.45) if low else Color.WHITE
		hp_l.add_theme_color_override("font_color", UiTheme.C_DANGER if (low or m.hp <= 0) else UiTheme.C_TEXT)


## Event runs: the quest line of the live tracker (Game.quest) — its translated label_key, else the text EventInfo
## builds from the definition; without a tracker the event of the run log header.
func _auto_quest() -> void:
	if Game.mode != &"event_offline":
		return
	if Game.quest != null:
		set_quest(quest_line(Game.quest), Game.quest.progress())
		return
	if Game.run_log == null:
		return
	var info: Dictionary = EventInfo.find(str(Game.run_log.header.get("event_id", "")))
	if not info.is_empty():
		set_quest(EventInfo.quest_text(info.get("quest", {}) as Dictionary), 0.0)


## Translated QuestTracker.label() when a translation exists, else EventInfo.quest_text(tracker.to_def()).
static func quest_line(q: QuestTracker) -> String:
	if q == null:
		return ""
	var key: String = q.label()
	if key != "" and UiUtil.tr_text(key) != key:
		return UiUtil.tr_text(key)
	return EventInfo.quest_text(q.to_def())


func _on_quest_progress(progress: float) -> void:
	if not is_inside_tree():
		_dirty["quest_progress"] = true
		_quest_progress_pending = progress
		return
	if _quest_panel.visible:
		_quest_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func _on_quest_completed() -> void:
	if not is_inside_tree():
		_dirty["quest_completed"] = true
		return
	if not _quest_panel.visible:
		return
	_quest_bar.value = 100.0
	_quest_label.text = "ERFÜLLT – " + _quest_text
	_quest_label.add_theme_color_override("font_color", UiTheme.C_OK)


# --- capture still --------------------------------------------------------------------------------------------------

func _start_demo() -> void:
	_demo = true
	Game.ensure_state()
	Events.overlay_mode_requested.emit.call_deferred(&"explore")
	_refresh_floor()
	_refresh_party()
	var def: FloorDef = Game.floor_def()
	var layout: FloorLayout = null
	if def != null:
		layout = DungeonGenerator.generate(def, Game.state.floor_run.seed if Game.state.floor_run != null else 1)
		if layout == null or layout.cells.is_empty():
			layout = MinimapScript.layout_from_def(def)
	if layout != null:
		var visited: Array[Vector2i] = []
		for key: Variant in layout.cells.keys():
			visited.append(key as Vector2i)
		bind_layout(layout, visited)
		var start: Vector2i = layout.start
		set_player(start + Vector2i(0, -1) if layout.cells.has(start + Vector2i(0, -1)) else start, 0.6)
	_timer_started = true
	_set_seconds(14 * 60 + 32)
	_update_timer_visibility()
	set_prompt("Truhe öffnen")
	set_quest("Erreiche die Treppe von Etage 1.", 0.35)
