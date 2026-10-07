class_name SafeAreaContainer extends MarginContainer
## Root of all HUD/menu layouts (02_TECH §10.4): margins = display safe area (mobile) + 24 px edge, recomputed on
## viewport size changes. Desktop: 24 px only. Mouse passes through (HUDs must not block the game view).

const EDGE: int = 24

## Extra margin added on every side (e.g. menus that want more air); never negative, so every margin stays >= EDGE.
@export var extra: int = 0:
	set(v):
		extra = maxi(v, 0)
		update_margins()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	update_margins()
	get_viewport().size_changed.connect(update_margins)


## {"left", "top", "right", "bottom"} in canvas pixels (each >= EDGE).
func compute_margins() -> Dictionary:
	var m: Dictionary = {"left": EDGE + extra, "top": EDGE + extra, "right": EDGE + extra, "bottom": EDGE + extra}
	if not OS.has_feature("mobile") or not is_inside_tree():
		return m
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return m
	var sc: Vector2 = get_viewport().get_visible_rect().size / Vector2(win)
	m["left"] = maxi(0, roundi(safe.position.x * sc.x)) + EDGE + extra
	m["top"] = maxi(0, roundi(safe.position.y * sc.y)) + EDGE + extra
	m["right"] = maxi(0, roundi((win.x - safe.end.x) * sc.x)) + EDGE + extra
	m["bottom"] = maxi(0, roundi((win.y - safe.end.y) * sc.y)) + EDGE + extra
	return m


func update_margins() -> void:
	var m: Dictionary = compute_margins()
	add_theme_constant_override("margin_left", int(m["left"]))
	add_theme_constant_override("margin_top", int(m["top"]))
	add_theme_constant_override("margin_right", int(m["right"]))
	add_theme_constant_override("margin_bottom", int(m["bottom"]))
