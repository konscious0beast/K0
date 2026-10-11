extends PanelContainer
## Party member panel of the battle HUD (02_TECH §1.6, GDD §14.5, 03_ART §9.2): 254×74, portrait, name, HP bar
## (8 px, trailing DANGER segment) + number, MP bar (6 px) + number, status icons, stunt readiness. Values come
## from ActionEvent data during playback (hp_after / mp_after / status events) and are synced from BattleState
## after each playback. Private M5 helper (no class_name).

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
## 03_ART §9.2: 254×74; 244×72 keeps both panels right of the M.O.D. text box (bottom center, x ≤ 1010 px) and
## below the 12-entry CTB bar, with every text ≥ 15 px (03_ART §9.3; HP / MP numbers 16 px).
const SIZE: Vector2 = Vector2(244, 72)

var unit_id: String = ""
var hp: int = 0
var max_hp: int = 1
var mp: int = 0
var max_mp: int = 0
var ko: bool = false
var active: bool = false
var statuses: PackedStringArray = []
var stunt_cooldown: int = 0
var has_stunt: bool = false

var _portrait: TextureRect = null
var _portrait_frame: Panel = null
var _name: Label = null
var _hp_bar: HudStyle.Bar = null
var _mp_bar: HudStyle.Bar = null
var _hp_label: Label = null
var _mp_label: Label = null
var _status_box: HBoxContainer = null
var _stunt_icon: HudStyle.Icon = null
var _stunt_label: Label = null
var _ko_label: Label = null
var _box: StyleBoxFlat = null
var _box_active: StyleBoxFlat = null
var _accent: Color = Color("#22d3ee")
var _role: PanelContainer = null      # 06 package A: "DU" (the controlled character) / "AUTO" (partner plays itself)
var _role_label: Label = null
var role: String = ""                 # "" | "lead" | "auto"


func setup(p_id: String, display_name: String, p_hp: int, p_max_hp: int, p_mp: int, p_max_mp: int,
		portrait: Texture2D, accent: Color, p_has_stunt: bool) -> void:
	unit_id = p_id
	name = "Panel_" + p_id
	_accent = accent
	has_stunt = p_has_stunt
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = HudStyle.show_box(HudStyle.C_PANEL, Color(accent, 0.55), 2, 0.0, Vector4(6, 4, 9, 4))
	_box_active = HudStyle.show_box(HudStyle.C_PANEL_HI, Color("#ff2e88"), 3, 0.0, Vector4(6, 4, 9, 4))
	_box_active.shadow_color = Color(1.0, 0.18, 0.53, 0.35)
	_box_active.shadow_size = 8
	add_theme_stylebox_override("panel", _box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_portrait_frame = Panel.new()
	_portrait_frame.custom_minimum_size = Vector2(52, 52)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pf: StyleBoxFlat = HudStyle.show_box(Color(accent, 0.25), accent, 2, 0.0, Vector4(2, 2, 2, 2))
	pf.shadow_size = 0
	_portrait_frame.add_theme_stylebox_override("panel", pf)
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.texture = portrait
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = 2
	_portrait.offset_top = 2
	_portrait.offset_right = -2
	_portrait.offset_bottom = -2
	_portrait_frame.add_child(_portrait)
	_ko_label = HudStyle.label("K.O.", 18, HudStyle.C_HP_LOW, true, 4)
	_ko_label.set_anchors_preset(Control.PRESET_CENTER)
	_ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ko_label.offset_left = -26
	_ko_label.offset_right = 26
	_ko_label.offset_top = -12
	_ko_label.offset_bottom = 12
	_ko_label.visible = false
	_portrait_frame.add_child(_ko_label)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_role = PanelContainer.new()
	_role.name = "Role"
	_role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_role.visible = false
	top.add_child(_role)
	_role_label = HudStyle.label("", 15, HudStyle.C_INK, true, 0)
	_role_label.add_theme_constant_override("outline_size", 0)
	_role.add_child(_role_label)
	_name = HudStyle.label(display_name, 15, HudStyle.C_PAPER, true, 3)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	top.add_child(_name)
	_status_box = HBoxContainer.new()
	_status_box.add_theme_constant_override("separation", 2)
	_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_status_box)
	_stunt_icon = HudStyle.Icon.new("star", Color("#ffc93c"), 16)
	_stunt_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stunt_icon.visible = has_stunt
	top.add_child(_stunt_icon)
	_stunt_label = HudStyle.mono_label("", 15, Color("#b3a7c9"))
	_stunt_label.visible = false
	top.add_child(_stunt_label)
	var hp_row: HBoxContainer = _bar_row("HP")
	col.add_child(hp_row)
	_hp_bar = HudStyle.Bar.new(HudStyle.C_HP, 8.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_label = HudStyle.mono_label("", 16)
	_hp_label.custom_minimum_size = Vector2(72, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)
	var mp_row: HBoxContainer = _bar_row("MP")
	col.add_child(mp_row)
	_mp_bar = HudStyle.Bar.new(HudStyle.C_MP, 5.0)
	_mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mp_row.add_child(_mp_bar)
	_mp_label = HudStyle.mono_label("", 16, Color("#bcd6ff"))
	_mp_label.custom_minimum_size = Vector2(72, 0)
	_mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_row.add_child(_mp_label)
	max_hp = maxi(1, p_max_hp)
	max_mp = maxi(0, p_max_mp)
	set_hp(p_hp, false)
	set_mp(p_mp, false)
	set_stunt(0)


## 06 §1.4 (package A): `lead` marks the controlled character ("DU", gold), `auto` the partner that AutoPolicy plays
## ("Partner automatisch": "AUTO", cyan); both false hides the pill.
func set_role(lead: bool, auto: bool) -> void:
	role = "auto" if auto else ("lead" if lead else "")
	if _role == null:
		return
	_role.visible = role != ""
	if role == "":
		return
	var col: Color = Color("#22d3ee") if role == "auto" else Color("#ffc93c")
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	_role.add_theme_stylebox_override("panel", sb)
	_role_label.text = "AUTO" if role == "auto" else "DU"


func _bar_row(tag: String) -> HBoxContainer:
	var r: HBoxContainer = HBoxContainer.new()
	r.add_theme_constant_override("separation", 5)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = HudStyle.label(tag, 15, Color("#b3a7c9"), true, 2)
	l.custom_minimum_size = Vector2(26, 0)
	r.add_child(l)
	return r


func set_hp(value: int, animate: bool = true) -> void:
	hp = clampi(value, 0, max_hp)
	_hp_bar.set_ratio(float(hp) / float(max_hp), animate)
	var low: bool = hp > 0 and hp * 4 < max_hp
	_hp_bar.fill = HudStyle.C_HP_LOW if low else HudStyle.C_HP
	_hp_label.text = "%d/%d" % [hp, max_hp]
	_hp_label.add_theme_color_override("font_color", HudStyle.C_HP_LOW if (low or hp == 0) else HudStyle.C_PAPER)
	set_ko(hp <= 0)


func set_mp(value: int, animate: bool = true) -> void:
	mp = clampi(value, 0, maxi(max_mp, value))
	var ratio: float = float(mp) / float(max_mp) if max_mp > 0 else 0.0
	_mp_bar.set_ratio(ratio, animate)
	_mp_label.text = "%d/%d" % [mp, max_mp]


func set_ko(on: bool) -> void:
	ko = on
	_ko_label.visible = on
	_portrait.modulate = Color(0.45, 0.4, 0.5, 1.0) if on else Color.WHITE
	_name.add_theme_color_override("font_color", Color("#9c93ad") if on else HudStyle.C_PAPER)
	if on:
		clear_statuses()


func set_active(on: bool) -> void:
	active = on
	add_theme_stylebox_override("panel", _box_active if on else _box)
	var col: Color = Color("#9c93ad") if ko else HudStyle.C_PAPER
	_name.add_theme_color_override("font_color", Color("#ffc93c") if on else col)


func set_status(status_id: String, on: bool) -> void:
	if on == statuses.has(status_id):
		return
	if on:
		statuses.append(status_id)
	else:
		statuses.remove_at(statuses.find(status_id))
	_rebuild_statuses()


func clear_statuses() -> void:
	if statuses.is_empty():
		return
	statuses.clear()
	_rebuild_statuses()


## Stunt cooldown (0 = ready: lit star; > 0: dim star + number).
func set_stunt(cooldown: int) -> void:
	stunt_cooldown = maxi(0, cooldown)
	if not has_stunt:
		_stunt_icon.visible = false
		_stunt_label.visible = false
		return
	_stunt_icon.visible = true
	_stunt_icon.set_icon("star", Color("#ffc93c") if stunt_cooldown == 0 else Color("#5a5266"))
	_stunt_label.visible = stunt_cooldown > 0
	_stunt_label.text = str(stunt_cooldown)


func _rebuild_statuses() -> void:
	for c: Node in _status_box.get_children():
		c.queue_free()
	for sid: String in statuses:
		var ic: HudStyle.Icon = HudStyle.Icon.new(HudStyle.status_icon(sid), HudStyle.status_color(sid), 16)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.tooltip_text = tr(DB.status(sid).name) if DB.has_id("statuses", sid) else sid
		_status_box.add_child(ic)
