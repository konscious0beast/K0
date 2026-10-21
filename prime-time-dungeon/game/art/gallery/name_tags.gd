extends CanvasLayer
## Screen-space name tags of the art galleries (private, no class_name): 2D labels anchored to 3D points of the figures,
## same UI font as the game, nudged apart vertically when two tags would overlap. Replaces the billboard Label3D tags of
## the cast sheet, which overlapped each other and the figures behind them in the CI shots (visual pass).

const GAP: float = 4.0
const MAX_NUDGES: int = 6

var camera: Camera3D = null

var _root: Control
var _tags: Array[Dictionary] = []         # {"target", "offset": Vector3, "label": Label, "below": bool, "head": bool}


func _init() -> void:
	layer = 10


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for t: Dictionary in _tags:
		_root.add_child(t["label"] as Label)


## Tag under (`below`) or above the point `offset` (added to the target's position) of `target`; `head`: the anchor is
## the top of the figure (CharacterRig.height) + `offset`.
func add_tag(target: Node3D, text: String, offset: Vector3, color: Color, font_size: int = 19,
		below: bool = true, head: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font_bold())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UiTheme.C_BG)
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tags.append({"target": target, "offset": offset, "label": l, "below": below, "head": head})
	if _root != null:
		_root.add_child(l)
	return l


func tag_count() -> int:
	return _tags.size()


func _process(_delta: float) -> void:
	layout()


## Places every tag at its projected anchor; a tag that would overlap an earlier one moves away from its anchor
## (down for tags under the feet, up for tags over the head) in steps of its own height.
func layout() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var placed: Array[Rect2] = []
	for t: Dictionary in _tags:
		var target: Node3D = t["target"] as Node3D
		var l: Label = t["label"] as Label
		if target == null or not is_instance_valid(target) or not target.is_inside_tree():
			l.visible = false
			continue
		var p: Vector3 = target.global_position + (t["offset"] as Vector3)
		if bool(t["head"]):
			p = target.to_global(Vector3(0.0, float(target.get("height")), 0.0)) + (t["offset"] as Vector3)
		if camera.is_position_behind(p):
			l.visible = false
			continue
		l.visible = true
		var sz: Vector2 = l.get_combined_minimum_size()
		var sp: Vector2 = camera.unproject_position(p)
		var below: bool = bool(t["below"])
		var r: Rect2 = Rect2(Vector2(sp.x - sz.x * 0.5, sp.y if below else sp.y - sz.y), sz)
		for i in MAX_NUDGES:
			var hit: bool = false
			for q: Rect2 in placed:
				if q.grow(GAP * 0.5).intersects(r.grow(GAP * 0.5)):
					hit = true
					break
			if not hit:
				break
			r.position.y += (sz.y + GAP) * (1.0 if below else -1.0)
		placed.append(r)
		l.position = r.position.round()
		l.size = sz
