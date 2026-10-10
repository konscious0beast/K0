extends CanvasLayer
## Yes/No dialog (02_TECH §1.6, modal layer 60) — used by the stairs (M3, §7.3), "Zum Titel", slot overwrite, mode
## change.
## Usage: `var d := load("res://scenes/ui/confirm_dialog.tscn").instantiate()`; `d.setup({"text": "…", "yes": "Abstieg",
## "no": "Noch nicht"})`; add it anywhere (it is its own CanvasLayer); listen to `confirmed` / `cancelled` /
## `closed(bool)`
## or pass callables "on_yes" / "on_no". Default focus: "no" when params.default_no (destructive questions), else "yes".
## ui_cancel / pause = no. Frees itself after answering. process_mode ALWAYS (works paused and unpaused); hosts inside
## the PauseMenu switch it to WHEN_PAUSED (§9.4). No class_name (§13.2 rule 1: not listed as public class in §1);
## other modules load the scene by path and use it duck-typed (setup / signals above).

signal confirmed()
signal cancelled()
signal closed(accepted: bool)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")

var answered: bool = false
var result: bool = false

var _params: Dictionary = {}
var _root: Control
var _panel: PanelContainer
var _title: Label
var _text: Label
var _yes: Button
var _no: Button


## {"title", "text" (alias "message"), "yes" (alias "confirm_text"), "no" (alias "cancel_text"), "default_no": bool,
##  "danger": bool, "on_yes": Callable, "on_no": Callable, "capture": bool}
func setup(params: Dictionary) -> void:
	_params = params
	if _root != null:
		_apply_params()


## Convenience: set texts after instancing.
func open(text: String, yes: String = "Ja", no: String = "Nein", title: String = "") -> void:
	var p: Dictionary = _params.duplicate()
	p["text"] = text
	p["yes"] = yes
	p["no"] = no
	if title != "":
		p["title"] = title
	setup(p)


func _init() -> void:
	layer = 60


func _ready() -> void:
	_build()
	_apply_params()
	var target: Button = _no if bool(_params.get("default_no", false)) else _yes
	UiUtil.focus_later(target)
	UiUtil.slide_in(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if answered:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		Sfx.play_ui(&"ui_cancel")
		answer(false)


func answer(yes: bool) -> void:
	if answered:
		return
	answered = true
	result = yes
	var cb: Variant = _params.get("on_yes" if yes else "on_no", null)
	if yes:
		confirmed.emit()
	else:
		cancelled.emit()
	closed.emit(yes)
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	queue_free()


func yes_button() -> Button:
	return _yes


func no_button() -> Button:
	return _no


func _apply_params() -> void:
	var title: String = str(_params.get("title", "Bestätigen"))
	var text: String = str(_params.get("text", _params.get("message", "Bist du sicher?")))
	_title.text = UiUtil.glyph_safe(title)
	_text.text = UiUtil.glyph_safe(text)
	_yes.text = UiUtil.glyph_safe(str(_params.get("yes", _params.get("confirm_text", "Ja"))))
	_no.text = UiUtil.glyph_safe(str(_params.get("no", _params.get("cancel_text", "Nein"))))
	var danger: bool = bool(_params.get("danger", false))
	var sb: StyleBoxFlat = UiUtil.box_style(UiTheme.C_PANEL, UiTheme.C_DANGER if danger else UiTheme.C_ACCENT_2, 3, 0.0,
		28, 22)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.7)
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(14)
	_panel.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(10)
	col.add_child(head)
	var icon: Control = UiIcon.make(&"drone", UiTheme.C_ACCENT_2, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	_title = UiUtil.label("", &"LabelHeader")
	head.add_child(_title)
	_text = UiUtil.label("", &"", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(500, 0)
	col.add_child(_text)
	col.add_child(UiUtil.spacer(4))
	var row: HBoxContainer = UiUtil.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	_no = UiUtil.button("Nein", &"ButtonBig")
	_no.name = "No"
	_no.custom_minimum_size = Vector2(200, 72)
	_no.pressed.connect(func() -> void: answer(false))
	row.add_child(_no)
	_yes = UiUtil.button("Ja", &"ButtonBig")
	_yes.name = "Yes"
	_yes.custom_minimum_size = Vector2(200, 72)
	_yes.pressed.connect(func() -> void: answer(true))
	row.add_child(_yes)
	UiUtil.wire_horizontal([_no, _yes] as Array[Control])
	_no.focus_neighbor_top = _no.get_path_to(_no)
	_no.focus_neighbor_bottom = _no.get_path_to(_no)
	_yes.focus_neighbor_top = _yes.get_path_to(_yes)
	_yes.focus_neighbor_bottom = _yes.get_path_to(_yes)
