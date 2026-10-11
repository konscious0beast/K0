extends CanvasLayer
## Achievement / hint toasts (02_TECH §1.6, layer 45). Sources: Events.toast_requested(text, icon) (Show sends one per
## achievement), lootbox_earned, milestone_reached, game_saved. Left edge below the LIVE block and the exploration
## party status (y 240), fade in, 3.2 s, max 3 (the battle command menu starts further down on the left).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const HOLD_SEC: float = 3.2
const MAX_VISIBLE: int = 3
const WIDTH: float = 380.0
## icon → [title, icon kind, color]
const STYLES: Dictionary = {
	&"achievement": ["ACHIEVEMENT FREIGESCHALTET", &"trophy", Color("#ffc93c")],
	&"lootbox": ["LOOTBOX ERHALTEN", &"box", Color("#cd7f32")],
	&"save": ["GESPEICHERT", &"floppy", Color("#4ade80")],
	&"warning": ["ACHTUNG", &"cross", Color("#ff4d4d")],
	&"item": ["ITEM", &"potion", Color("#22d3ee")],
	&"gift": ["GESCHENK", &"gift", Color("#ff2e88")],
	&"level": ["LEVEL UP", &"star", Color("#ffc93c")],
	&"credits": ["CREDITS", &"coin", Color("#ffc93c")],
	&"milestone": ["FOLLOWER-MEILENSTEIN", &"heart", Color("#ff2e88")],
	&"info": ["HINWEIS", &"dot", Color("#22d3ee")],
	# 06-C: show bets (hearts) and the Unterhosen-Liga (06 §4.7)
	&"marotte": ["M.O.D. MAG DAS", &"heart", Color("#ff2e88")],
	&"liga": ["UNTERHOSEN-LIGA", &"star", Color("#ff2e88")],
	&"liga_duo": ["DUO-LIGA", &"star", Color("#ffc93c")],
}

var _root: Control
var _list: VBoxContainer


func _init() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
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
	_list = UiUtil.vbox(8)
	_list.name = "Toasts"
	_list.position = Vector2(0, 224)
	_list.custom_minimum_size = Vector2(WIDTH, 0)
	frame.add_child(_list)
	Events.toast_requested.connect(func(text: String, icon: StringName) -> void: push_toast(text, icon))
	Events.lootbox_earned.connect(_on_lootbox_earned)
	Events.milestone_reached.connect(_on_milestone)
	Events.game_saved.connect(_on_game_saved)


func count() -> int:
	var n: int = 0
	for c: Node in _list.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## Screen rect (canvas coordinates) of the visible toasts, empty without any (M5 CR 1: battle UI avoids it).
func stack_rect() -> Rect2:
	var r: Rect2 = Rect2()
	for c: Node in _list.get_children():
		var ctl: Control = c as Control
		if ctl == null or c.is_queued_for_deletion() or not ctl.is_visible_in_tree() or ctl.modulate.a <= 0.01:
			continue
		r = ctl.get_global_rect() if r.size == Vector2.ZERO else r.merge(ctl.get_global_rect())
	return r


## Adds a toast. `icon` picks title/icon/color from STYLES (unknown → info).
func push_toast(text: String, icon: StringName = &"info", color_override: Color = Color(0, 0, 0, 0)) -> Control:
	if Game.replaying:
		return null
	var style: Array = STYLES.get(icon, STYLES[&"info"])
	var col: Color = color_override if color_override.a > 0.0 else (style[2] as Color)
	var toast: PanelContainer = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.custom_minimum_size = Vector2(WIDTH, 0)
	toast.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.94), col, 2, 0.21, 16, 6))
	var row: HBoxContainer = UiUtil.hbox(10)
	toast.add_child(row)
	var ic: Control = UiIcon.make(style[1] as StringName, col, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col_box: VBoxContainer = UiUtil.vbox(0)
	col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col_box)
	var title: Label = UiUtil.label(str(style[0]), &"", 15, col)
	title.add_theme_font_override("font", UiTheme.font_bold())
	col_box.add_child(title)
	var body: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col_box.add_child(body)
	_list.add_child(toast)
	while _list.get_child_count() > MAX_VISIBLE:
		var old: Node = _list.get_child(0)
		_list.remove_child(old)
		old.queue_free()
	if icon == &"achievement":
		Sfx.play_ui(&"achievement")
	if is_inside_tree():
		toast.modulate.a = 0.0
		var tw: Tween = toast.create_tween()
		tw.tween_property(toast, "modulate:a", 1.0, 0.18)
		tw.tween_interval(HOLD_SEC)
		tw.tween_property(toast, "modulate:a", 0.0, 0.3)
		tw.tween_callback(toast.queue_free)
	return toast


func _on_lootbox_earned(box_id: String) -> void:
	var name_text: String = box_id
	if DB.has_id("lootboxes", box_id):
		name_text = UiUtil.tr_text(DB.lootbox(box_id).name)
	push_toast(name_text + " – öffnen im Safe Room", &"lootbox", UiUtil.box_color(box_id))


func _on_milestone(milestone_id: String) -> void:
	var text: String = milestone_id
	if DB.has_id("milestones", milestone_id):
		text = UiUtil.fmt_int(DB.milestone(milestone_id).followers) + " Follower erreicht!"
	push_toast(text, &"milestone")


func _on_game_saved(slot: int, ok: bool) -> void:
	if ok:
		push_toast("Slot %d gesichert." % slot, &"save")
	else:
		push_toast("Speichern fehlgeschlagen: " + Save.last_error(), &"warning")
