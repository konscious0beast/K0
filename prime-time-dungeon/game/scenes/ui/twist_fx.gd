extends CanvasLayer
## TwistFx (06-D, child of GlobalUi, layer 41 — over the ShowOverlay, under ModDialog): what a running M.O.D. twist
## looks like. Kept deliberately simple (06 §0.2 L-1: one sentence per system, HUD budget):
##   · ONE chip under the floor timer: "REGIE" pill + twist name + what is left ("0:42", "noch 2 Kämpfe", "nächster
##     Safe Room") and a thin bar that empties — no urgency wording, no purchase context (06 §6 Nr. 1 style)
##   · tw_lights_out: a dark vignette (exploration only) · tw_confetti_gravity: confetti rising from the bottom
## Reads TwistApplier.view(Game.state) a few times per second (robust against loads, replays and floor changes);
## Events.twist_applied pops the chip. Display only — nothing here changes game state.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const REFRESH_SEC: float = 0.2
const CHIP_TOP: float = 112.0
const MODES_CHIP: Array[StringName] = [&"explore", &"battle", &"safe_room"]
## Source → pill text (who intervened).
const SOURCE_TEXT: Dictionary = {"regie": "REGIE", "mod_brain": "M.O.D. LIVE", "vote": "PUBLIKUM",
	"schedule": "SENDEPLAN", "dev": "TEST"}

var mode: StringName = &"explore"

var _root: Control
var _chip: PanelContainer
var _pill: Label
var _name: Label
var _left: Label
var _bar: ProgressBar
var _vignette: ColorRect
var _confetti: CPUParticles2D
var _acc: float = 0.0
var _shown_id: String = ""


func _init() -> void:
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	UiUtil.full_rect(_vignette)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_material()
	_vignette.visible = false
	_root.add_child(_vignette)
	_confetti = _make_confetti()
	_root.add_child(_confetti)
	_build_chip()
	Events.overlay_mode_requested.connect(set_mode)
	Events.twist_applied.connect(_on_twist_applied)
	Events.twist_ended.connect(func(_id: String) -> void: refresh())
	refresh()


func _process(delta: float) -> void:
	_acc += delta
	if _acc < REFRESH_SEC:
		return
	_acc = 0.0
	refresh()


func set_mode(p_mode: StringName) -> void:
	mode = p_mode
	refresh()


## Rebuilds the chip / effects from the run state now.
func refresh() -> void:
	if _chip == null:
		return
	var views: Array[Dictionary] = []
	if Game.state != null:
		views = TwistApplier.view(Game.state, DB.data)
	var main: Dictionary = {}
	for v: Dictionary in views:
		if main.is_empty() or (bool(v.get("gameplay", false)) and not bool(main.get("gameplay", false))):
			main = v
	_chip.visible = not main.is_empty() and MODES_CHIP.has(mode)
	if not main.is_empty():
		_pill.text = str(SOURCE_TEXT.get(str(main.get("src", "")), "REGIE"))
		_name.text = str(main.get("name", ""))
		_left.text = left_text(main)
		_bar.value = float(int(main.get("left_pm", 1000))) / 10.0
		_bar.visible = str(main.get("unit", "")) == "sec"
		_shown_id = str(main.get("id", ""))
	var ids: PackedStringArray = []
	for v: Dictionary in views:
		ids.append(str(v.get("id", "")))
	_vignette.visible = ids.has("tw_lights_out") and mode == &"explore"
	var conf: bool = ids.has("tw_confetti_gravity") and mode == &"explore"
	if _confetti.emitting != conf:
		var vp: Vector2 = _root.get_viewport_rect().size
		_confetti.position = Vector2(vp.x * 0.5, vp.y + 20.0)
		_confetti.emission_rect_extents = Vector2(vp.x * 0.5 + 20.0, 8.0)
		_confetti.emitting = conf
	_layout()


## "0:42" (seconds), "noch 2 Kämpfe" / "noch 1 Kampf", "nächster Safe Room" / "im Safe Room" (visits), "" otherwise.
static func left_text(v: Dictionary) -> String:
	var left: int = int(v.get("left", 0))
	match str(v.get("unit", "")):
		"sec":
			return "%d:%02d" % [left / 60, left % 60]
		"battles":
			return "noch 1 Kampf" if left == 1 else "noch %d Kämpfe" % left
		"visits":
			return "nächster Safe Room"
	return ""


## Chip rect in canvas coordinates (tests / layout checks); empty when hidden.
func chip_rect() -> Rect2:
	if _chip == null or not _chip.visible:
		return Rect2()
	return _chip.get_global_rect()


func _on_twist_applied(_tv: Dictionary) -> void:
	refresh()
	if _chip != null and _chip.visible:
		_chip.pivot_offset = _chip.size * 0.5
		_chip.scale = Vector2(1.25, 1.25)
		var tw: Tween = create_tween()
		tw.tween_property(_chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_chip() -> void:
	_chip = PanelContainer.new()
	_chip.name = "TwistChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override("panel", UiUtil.box_style(Color(0.08, 0.05, 0.13, 0.86), UiTheme.C_GOLD, 2,
		0.0, 12, 5))
	_root.add_child(_chip)
	var col: VBoxContainer = UiUtil.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(col)
	var row: HBoxContainer = UiUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.0, 8, 1))
	row.add_child(pill)
	_pill = UiUtil.label("REGIE", &"", 15, UiUtil.C_INK)
	_pill.add_theme_font_override("font", UiTheme.font_bold())
	pill.add_child(_pill)
	_name = UiUtil.label("", &"", 18, UiTheme.C_TEXT)
	_name.add_theme_font_override("font", UiTheme.font_bold())
	row.add_child(_name)
	_left = UiUtil.label("", &"", 16, UiTheme.C_TEXT_DIM)
	_left.add_theme_font_override("font", UiTheme.font_mono())
	row.add_child(_left)
	_bar = ProgressBar.new()
	_bar.name = "Left"
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 4)
	_bar.max_value = 100.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", UiUtil.box_style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 0.0,
		0, 0))
	_bar.add_theme_stylebox_override("fill", UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.0, 0, 0))
	col.add_child(_bar)
	_chip.visible = false


## Centered under the floor timer (inside the viewport).
func _layout() -> void:
	if _chip == null or not _chip.visible:
		return
	_chip.reset_size()
	var vp: Vector2 = _root.get_viewport_rect().size
	_chip.position = Vector2(roundf((vp.x - _chip.size.x) * 0.5), CHIP_TOP)


static func _vignette_material() -> ShaderMaterial:
	var sh: Shader = Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.82;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.6, 1.0);
	float r = length(d);
	float a = smoothstep(0.32, 0.95, r) * strength;
	COLOR = vec4(0.02, 0.01, 0.06, a);
}
"""
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	return m


func _make_confetti() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = "ConfettiUp"
	p.emitting = false
	p.amount = 90
	p.lifetime = 3.2
	p.position = Vector2(640, 740)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(660, 8)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, UiTheme.C_ACCENT)
	ramp.set_color(1, UiTheme.C_GOLD)
	ramp.add_point(0.5, UiTheme.C_ACCENT_2)
	p.color_initial_ramp = ramp
	return p
