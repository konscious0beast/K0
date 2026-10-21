extends Control
## Combat banners (07 §2.8, §8.1, §8.8): a skewed broadcast lower third at the top centre, y 150 of the 1280 × 720
## reference (below the target / boss frames), 1.2 s, never blocking: "KAMPF!", "Erstschlag!", "Hinterhalt!", boss
## phases, control switch ("Kai ist K.O. — du spielst jetzt Graf Mopsula!"), enrage, the story banner of the encounter
## (story_battle:<encounter_id>, 07 §12.9 Nr. 9) and the show-boss rule (showboss_rule, 07 §9.6). Queued, one at a time.
## Private R3 script.

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")

const TOP: float = 126.0                    # abs y 150 minus the 24 px safe edge
const HOLD: float = 1.2
const IN_SEC: float = 0.18
const OUT_SEC: float = 0.2

## Top edge (frame-local): TOP, or lower while a boss frame + target frame fill the top centre (set by the HUD).
var top: float = TOP

var _queue: Array[Dictionary] = []
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _t: float = -1.0
var _cur: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.name = "Banner"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_title = CombatStyle.label("", 30, CombatStyle.C_INK, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_sub = CombatStyle.label("", 16, CombatStyle.C_PAPER, false)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)


## Queues a banner: `title` big on the accent colour, optional `sub` line; `hold` seconds on screen.
func show_banner(title: String, sub: String = "", color: Color = CombatStyle.C_GOLD, hold: float = HOLD) -> void:
	_queue.append({"title": title, "sub": sub, "color": color, "hold": hold})
	if _cur.is_empty():
		_next()


func is_showing() -> bool:
	return not _cur.is_empty()


func current_title() -> String:
	return str(_cur.get("title", ""))


func queued() -> int:
	return _queue.size()


## Canvas rect of the shown banner (layout tests), Rect2() while none shows.
func banner_rect() -> Rect2:
	return _panel.get_global_rect() if _panel.visible else Rect2()


func _next() -> void:
	if _queue.is_empty():
		_cur = {}
		_panel.visible = false
		return
	_cur = _queue.pop_front()
	_title.text = UiUtilRef.glyph_safe(str(_cur["title"]))
	_sub.text = UiUtilRef.glyph_safe(str(_cur["sub"]))
	_sub.visible = _sub.text != ""
	var sb: StyleBoxFlat = CombatStyle.panel_box(_cur["color"] as Color, Color(0, 0, 0, 0), 0, 0.21)
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 6.0
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", sb)
	_title.add_theme_color_override("font_color", CombatStyle.C_INK if (_cur["color"] as Color).get_luminance() > 0.45
		else CombatStyle.C_PAPER)
	_sub.add_theme_color_override("font_color", _title.get_theme_color("font_color"))
	_sub.custom_minimum_size = Vector2(0, 0)
	_sub.autowrap_mode = TextServer.AUTOWRAP_OFF              # one line unless it is too wide
	_panel.visible = true
	_panel.reset_size()
	var w: float = maxf(_panel.get_combined_minimum_size().x, 260.0)
	if w > 640.0:
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub.custom_minimum_size = Vector2(560, 0)
		_panel.reset_size()
		w = maxf(_panel.get_combined_minimum_size().x, 260.0)
	_panel.size = Vector2(w, _panel.get_combined_minimum_size().y)
	_panel.position = Vector2((size.x - w) * 0.5, top)
	_t = 0.0


func _process(delta: float) -> void:
	if _cur.is_empty():
		return
	_t += delta
	var hold: float = float(_cur["hold"])
	var a: float = 1.0
	var dx: float = 0.0
	if _t < IN_SEC:
		a = _t / IN_SEC
		dx = -16.0 * (1.0 - a)
	elif _t > IN_SEC + hold:
		a = 1.0 - (_t - IN_SEC - hold) / OUT_SEC
	_panel.modulate.a = clampf(a, 0.0, 1.0)
	_panel.position.x = (size.x - _panel.size.x) * 0.5 + dx
	_panel.position.y = top
	if _t >= IN_SEC + hold + OUT_SEC:
		_next()


const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
