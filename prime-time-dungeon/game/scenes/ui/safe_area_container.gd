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
	var ins: Dictionary = device_insets(get_viewport() if is_inside_tree() else null)
	var m: Dictionary = {}
	for side: String in ["left", "top", "right", "bottom"]:
		m[side] = int(ins[side]) + EDGE + extra
	return m


## Display cutout / rounded-corner insets in canvas pixels WITHOUT the 24 px edge (0 on desktop). Layers that place
## controls with absolute offsets (touch buttons, joystick) shift by these (02_TECH §10.4).
static func device_insets(vp: Viewport) -> Dictionary:
	var m: Dictionary = {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if vp == null or not OS.has_feature("mobile"):
		return m
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return m
	var sc: Vector2 = vp.get_visible_rect().size / Vector2(win)
	m["left"] = maxi(0, roundi(safe.position.x * sc.x))
	m["top"] = maxi(0, roundi(safe.position.y * sc.y))
	m["right"] = maxi(0, roundi((win.x - safe.end.x) * sc.x))
	m["bottom"] = maxi(0, roundi((win.y - safe.end.y) * sc.y))
	return m


func update_margins() -> void:
	var m: Dictionary = compute_margins()
	add_theme_constant_override("margin_left", int(m["left"]))
	add_theme_constant_override("margin_top", int(m["top"]))
	add_theme_constant_override("margin_right", int(m["right"]))
	add_theme_constant_override("margin_bottom", int(m["bottom"]))
