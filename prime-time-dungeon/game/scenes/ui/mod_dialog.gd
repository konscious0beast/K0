extends CanvasLayer
## ModDialog (02_TECH §1.6, §9.4 layer 45; 03_ART §9.2): M.O.D. / Mopsula / Kai text box with a queue, typewriter
## (45 chars/s, settings.text_speed), M.O.D. drone icon (live SubViewport, F9) and dialog presenter registration:
## Game.set_dialog_presenter(true) in _ready, false in _exit_tree. Fed by Events.mod_said(text, voice, tag, blocking);
## voice &"chat" goes to the ticker (ShowOverlay), not here.
## Blocking lines wait for ui_accept/action/tap and end with Events.dialog_finished(tag). A blocking line that is never
## shown (empty text, voice &"chat") is balanced with a deferred dialog_finished(tag), so Game's counter never sticks.
## Non-blocking lines advance on their own after a reading time and never consume input.
##
## DEVIATION from 02_TECH §9.4 ("jede Zeile endet … mit Events.dialog_finished(tag)"), API change requested for
## §9.4/§3.4: ONLY BLOCKING lines emit dialog_finished. Game._on_mod_said counts only blocking lines and
## _on_dialog_finished decrements for every emission, so a dialog_finished for a non-blocking line would release a
## pending blocking line early (the floor countdown would run while a blocking line is still on screen). M3/M5 code
## must therefore wait for dialog_finished only after emitting a line with blocking = true (e.g. boss intros:
## say(tag, ctx, true)); for non-blocking lines use the private M6 signal `line_finished(tag, blocking)` of
## ModDialog.current instead.
## Input: the box only takes ui_accept/action/tap while no menu above it (CanvasLayer > 45, e.g. PauseMenu) owns the
## focus and the tree is not paused, so menus opened over a waiting line keep their own confirm input.

signal line_started(text: String, voice: StringName, tag: String)
## Every shown line, blocking or not (M6-internal; Events.dialog_finished stays blocking-only, see header).
signal line_finished(tag: String, blocking: bool)
signal queue_finished()

## Private M6 accessor for scenes that play scripted lines (safe room scenes, intro). Set while in the tree.
static var current: Node = null

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const MENU_LAYER_ABOVE: int = 45                    # focus inside a CanvasLayer above this = a menu owns the input
const CPS: Array[float] = [25.0, 45.0, 0.0]        # text_speed 0 slow / 1 normal / 2 instant
const READ_BASE: float = 1.4
const READ_PER_CHAR: float = 0.045
const MAX_PENDING_SOFT: int = 3                     # queued non-blocking lines kept (older ones are dropped)
const AUTOPLAY_HOLD: float = 0.4
const BOX_SIZE: Vector2 = Vector2(740, 108)
const SPEAKERS: Dictionary = {&"mod": "M.O.D.", &"mopsula": "Graf Mopsula", &"kai": ""}
const MOOD_HYPE: PackedStringArray = ["achievement", "stunt_success", "kill_streak", "crit", "overkill", "boss_defeated",
	"level_up", "follower_milestone", "lootbox", "intro", "sponsor_gift"]
const MOOD_DANGER: PackedStringArray = ["death", "low_hp", "timer", "kai_ko", "mopsula_ko", "boss_intro", "boss_phase",
	"flee", "boring_fight", "stunt_fail"]
const MOOD_WARM: PackedStringArray = ["revive", "safe_room_enter", "scene", "mopsula"]

var _queue: Array[Dictionary] = []
var _cur: Dictionary = {}
var _shown_chars: float = 0.0
var _hold: float = 0.0
var _time: float = 0.0
var _root: Control
var _box: PanelContainer
var _speaker_panel: PanelContainer
var _speaker: Label
var _text: Label
var _next_hint: Control
var _glyph: Control
var _drone_view: SubViewportContainer
var _drone: Node3D
var _portrait: PanelContainer
var _portrait_icon: Control
var _fade: Tween = null
var _params: Dictionary = {}
var _align_right: bool = false


## Optional: {"capture": true} → shows a sample M.O.D. line (standalone still).
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	current = self
	Game.set_dialog_presenter(true)
	Events.mod_said.connect(_on_mod_said)
	Events.overlay_mode_requested.connect(_on_overlay_mode)
	_box.visible = false
	_speaker_panel.visible = false
	if bool(_params.get("capture", false)):
		enqueue(UiUtil.format_line("Kandidat:in {name}, Sie sind live. Bitte nicht in die Kamera weinen, das spiegelt."),
			&"mod", "intro", true)
		_shown_chars = float(_text.text.length())
		_text.visible_characters = -1


func _exit_tree() -> void:
	if current == self:
		current = null
	Game.set_dialog_presenter(false)


## Enqueues lines like Events.mod_said would (used by tests and scripted scenes through the signal). Returns false for
## lines that are never shown (voice &"chat" goes to the ticker, empty text).
func enqueue(text: String, voice: StringName, tag: String, blocking: bool) -> bool:
	if voice == &"chat" or text.strip_edges() == "":
		return false
	var line: Dictionary = {"text": UiUtil.glyph_safe(text), "voice": voice, "tag": tag, "blocking": blocking}
	_queue.append(line)
	_trim_soft_queue()
	if blocking and not _cur.is_empty() and not bool(_cur["blocking"]):
		_hold = minf(_hold, 0.25)   # a waiting blocking line cuts the current non-blocking chatter short
	if _cur.is_empty():
		_next()
	return true


## Box position: false = bottom center (03_ART §9.2), true = right-aligned (safe room: the menu column sits left).
func set_align_right(on: bool) -> void:
	_align_right = on
	if _box != null:
		_layout_box()


func is_align_right() -> bool:
	return _align_right


func is_busy() -> bool:
	return not _cur.is_empty() or not _queue.is_empty()


func current_line() -> Dictionary:
	return _cur.duplicate()


func pending() -> int:
	return _queue.size()


## Screen rect of the visible text box incl. the speaker tab (canvas coordinates), empty while hidden. ShowOverlay
## lifts the sponsor lower third above it so both stay readable.
func box_rect() -> Rect2:
	if _box == null or not _box.visible or _root.modulate.a <= 0.01:
		return Rect2()
	var r: Rect2 = _box.get_global_rect()
	if _speaker_panel.visible:
		r = r.merge(_speaker_panel.get_global_rect())
	return r


## Shows the full text, or ends the line when it is already complete (blocking lines only).
func advance() -> void:
	if _cur.is_empty():
		return
	var total: int = str(_cur["text"]).length()
	if _shown_chars < total:
		_shown_chars = total
		_text.visible_characters = -1
		return
	_finish_line()


func _process(delta: float) -> void:
	_time += delta
	if _drone != null and _drone_view.visible:
		SceneKit.animate_drone(_drone, _time)
	if _cur.is_empty():
		return
	var total: int = str(_cur["text"]).length()
	if _shown_chars < total:
		var cps: float = _cps()
		var before: int = int(_shown_chars)
		_shown_chars = float(total) if cps <= 0.0 else minf(float(total), _shown_chars + cps * delta)
		_text.visible_characters = -1 if _shown_chars >= total else int(_shown_chars)
		if int(_shown_chars) / 2 != before / 2 and _drone != null:
			_drone.scale = Vector3.ONE * 1.08
		if _shown_chars >= total:
			_hold = _read_time(total)
	elif _drone != null:
		_drone.scale = _drone.scale.lerp(Vector3.ONE, 1.0 - exp(-delta * 18.0))
	if _shown_chars >= total:
		_next_hint.visible = bool(_cur["blocking"])
		_next_hint.modulate.a = 0.55 + 0.45 * sin(_time * TAU * 1.5)
		if not bool(_cur["blocking"]) or Game.autoplay:
			_hold -= delta
			if _hold <= 0.0:
				_finish_line()


func _input(event: InputEvent) -> void:
	if _cur.is_empty() or not bool(_cur["blocking"]) or not _box.visible:
		return
	if _menu_owns_input():
		return
	# One tap = one advance: with pointing/emulate_mouse_from_touch (project.godot) Input itself creates a second,
	# emulated InputEventMouseButton for every touch (and emulate_touch_from_mouse would do the reverse), so
	# set_input_as_handled() on the first one cannot stop it. Emulated pointer events are ignored here.
	if (event is InputEventMouseButton or event is InputEventScreenTouch) \
			and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var hit: bool = false
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"action"):
		hit = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		hit = _box.get_global_rect().grow(16).has_point((event as InputEventMouseButton).position)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		hit = _box.get_global_rect().grow(16).has_point((event as InputEventScreenTouch).position)
	if hit:
		advance()
		get_viewport().set_input_as_handled()


# --- internals --------------------------------------------------------------------------------------------------------

func _on_mod_said(text: String, voice: StringName, tag: String, blocking: bool) -> void:
	if Game.replaying:
		return      # Game restores its blocking counter after a replay (_restore_context)
	if not enqueue(text, voice, tag, blocking) and blocking:
		# Game._on_mod_said already counted this blocking line; it is never shown → balance it (deferred, so the
		# emitter finishes its own bookkeeping first).
		Events.dialog_finished.emit.call_deferred(tag)


func _on_overlay_mode(mode: StringName) -> void:
	set_align_right(mode == &"safe_room")


## True while the tree is paused or a control on a CanvasLayer above the dialog (menus, layer 60) has the focus: then
## ui_accept / action belong to that menu, never to the line waiting behind it.
func _menu_owns_input() -> bool:
	if not is_inside_tree():
		return true
	if get_tree().paused:
		return true
	var f: Control = get_viewport().gui_get_focus_owner()
	if f == null:
		return false
	var n: Node = f.get_parent()
	while n != null:
		if n is CanvasLayer:
			return (n as CanvasLayer).layer > MENU_LAYER_ABOVE
		n = n.get_parent()
	return false


func _cps() -> float:
	if Game.fast_text:
		return 0.0
	var speed: int = Game.settings.text_speed if Game.settings != null else 1
	return CPS[clampi(speed, 0, CPS.size() - 1)]


func _read_time(chars: int) -> float:
	if Game.autoplay:
		return AUTOPLAY_HOLD
	var t: float = READ_BASE + READ_PER_CHAR * chars
	if not _queue.is_empty():
		t *= 0.6
	return t


func _trim_soft_queue() -> void:
	var soft: int = 0
	for l: Dictionary in _queue:
		if not bool(l["blocking"]):
			soft += 1
	while soft > MAX_PENDING_SOFT:
		for i in _queue.size():
			if not bool(_queue[i]["blocking"]):
				_queue.remove_at(i)
				soft -= 1
				break


func _next() -> void:
	if _queue.is_empty():
		_cur = {}
		_hide_box()
		queue_finished.emit()
		return
	_cur = _queue.pop_front()
	_shown_chars = 0.0
	_hold = 0.0
	_text.text = str(_cur["text"])
	_text.visible_characters = 0
	if _cps() <= 0.0:
		_shown_chars = float(_text.text.length())
		_text.visible_characters = -1
		_hold = _read_time(_text.text.length())
	_next_hint.visible = false
	_apply_speaker(_cur["voice"] as StringName, str(_cur["tag"]))
	_show_box()
	if _cur["voice"] == &"mod":
		Sfx.play_ui(&"mod_blip")
	line_started.emit(str(_cur["text"]), _cur["voice"] as StringName, str(_cur["tag"]))


func _finish_line() -> void:
	if _cur.is_empty():
		return
	var tag: String = str(_cur["tag"])
	var blocking: bool = bool(_cur["blocking"])
	_cur = {}
	if blocking:
		Events.dialog_finished.emit(tag)
	line_finished.emit(tag, blocking)
	_next()


func _apply_speaker(voice: StringName, tag: String) -> void:
	var col: Color = UiTheme.C_ACCENT_2
	var who: String = str(SPEAKERS.get(voice, "M.O.D."))
	match voice:
		&"mopsula":
			col = UiUtil.member_color("mopsula")
		&"kai":
			col = UiUtil.member_color("kai")
			who = UiUtil.player_name()
	_speaker.text = who
	_speaker_panel.add_theme_stylebox_override("panel", UiUtil.box_style(col, Color(0, 0, 0, 0), 0, 0.21, 14, 2))
	_speaker.add_theme_color_override("font_color", UiUtil.C_INK if col.get_luminance() > 0.45 else UiUtil.C_PAPER)
	var is_mod: bool = voice == &"mod"
	_drone_view.visible = is_mod
	_portrait.visible = not is_mod
	if is_mod:
		SceneKit.set_drone_mood(_drone, _mood_color(tag))
	else:
		_portrait_icon.set("kind", &"paw" if voice == &"mopsula" else &"person")
		_portrait.add_theme_stylebox_override("panel", _round_style(col))
	var sb: StyleBoxFlat = UiTheme.get_theme().get_stylebox("panel", "PanelDialog").duplicate() as StyleBoxFlat
	sb.border_color = UiTheme.C_ACCENT_2 if is_mod else col
	_box.add_theme_stylebox_override("panel", sb)


func _mood_color(tag: String) -> Color:
	for p: String in MOOD_DANGER:
		if tag.begins_with(p):
			return UiTheme.C_DANGER
	for p: String in MOOD_WARM:
		if tag.begins_with(p):
			return UiTheme.C_GOLD
	for p: String in MOOD_HYPE:
		if tag.begins_with(p):
			return UiTheme.C_ACCENT
	return UiTheme.C_ACCENT_2


func _show_box() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var was_visible: bool = _box.visible and _root.modulate.a > 0.99
	_box.visible = true
	_speaker_panel.visible = true
	if was_visible or not is_inside_tree():
		_root.modulate.a = 1.0
		return
	_root.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_root, "modulate:a", 1.0, 0.15)


func _hide_box() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not is_inside_tree():
		_box.visible = false
		_speaker_panel.visible = false
		return
	_fade = create_tween()
	_fade.tween_property(_root, "modulate:a", 0.0, 0.15)
	_fade.tween_callback(func() -> void:
		if _cur.is_empty():
			_box.visible = false
			_speaker_panel.visible = false)


func _round_style(col: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.25)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(32)
	return sb


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	_root.add_child(safe)
	var frame: Control = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_box = PanelContainer.new()
	_box.name = "Box"
	_box.theme_type_variation = &"PanelDialog"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_box)
	var row: HBoxContainer = UiUtil.hbox(14)
	_box.add_child(row)
	_drone_view = SubViewportContainer.new()
	_drone_view.name = "DroneIcon"
	_drone_view.custom_minimum_size = Vector2(64, 64)
	_drone_view.stretch = true
	_drone_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drone_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_drone_view)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_drone_view.add_child(vp)
	_drone = SceneKit.build_drone(1.0)
	vp.add_child(_drone)
	var cam: Camera3D = SceneKit.camera(Vector3(0, 0.1, 1.75), Vector3.ZERO, 40.0)
	vp.add_child(cam)
	vp.add_child(SceneKit.omni(Color.WHITE, 1.0, 6.0, Vector3(1, 1, 2)))
	_portrait = PanelContainer.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.visible = false
	row.add_child(_portrait)
	_portrait_icon = UiIcon.make(&"paw", UiUtil.C_PAPER, 40)
	_portrait.add_child(_portrait_icon)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text.add_theme_font_size_override("font_size", 19)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text)
	var hint_col: VBoxContainer = UiUtil.vbox(4)
	hint_col.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(hint_col)
	_next_hint = UiIcon.make(&"arrow_down", UiTheme.C_ACCENT_2, 14)
	_next_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_col.add_child(_next_hint)
	_glyph = InputGlyph.make(&"ui_accept", "", 15)
	hint_col.add_child(_glyph)
	_next_hint.visible = false
	_speaker_panel = PanelContainer.new()
	_speaker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.add_child(_speaker_panel)
	_speaker = UiUtil.label("M.O.D.", &"", 16)
	_speaker.add_theme_font_override("font", UiTheme.font_bold())
	_speaker.add_theme_constant_override("outline_size", 0)
	_speaker_panel.add_child(_speaker)
	_layout_box()


## Bottom center (default) or right-aligned in the safe room (set_align_right), always above the chat ticker.
func _layout_box() -> void:
	var bottom: float = -22.0 - 14.0
	if _align_right:
		_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_box.offset_right = 0.0
		_box.offset_left = -BOX_SIZE.x
		_speaker_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_speaker_panel.offset_left = -BOX_SIZE.x + 18.0
		_speaker_panel.offset_right = -BOX_SIZE.x + 18.0 + 220.0
	else:
		_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_box.offset_left = -BOX_SIZE.x * 0.5
		_box.offset_right = BOX_SIZE.x * 0.5
		_speaker_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_speaker_panel.offset_left = -BOX_SIZE.x * 0.5 + 18.0
		_speaker_panel.offset_right = -BOX_SIZE.x * 0.5 + 18.0 + 220.0
	_box.offset_bottom = bottom
	_box.offset_top = bottom - BOX_SIZE.y
	_speaker_panel.offset_bottom = bottom - BOX_SIZE.y + 4.0
	_speaker_panel.offset_top = bottom - BOX_SIZE.y - 24.0
